extends Node

@export_category("Tension Settings")
@export var enable_tension: bool = true
@export var default_tension: float = 0.0
@export var tension_decay_rate: float = 0.05
@export var tension_rise_rate: float = 0.1
@export var min_tension: float = 0.0
@export var max_tension: float = 1.0

@export_category("Thresholds")
@export var minimal_threshold: float = 0.1
@export var low_threshold: float = 0.3
@export var medium_threshold: float = 0.5
@export var high_threshold: float = 0.7
@export var critical_threshold: float = 0.9

enum LEVEL {MINIMAL, LOW, MEDIUM, HIGH, CRITICAL}

var signal_bus = null
var current = 0.0
var target = 0.0
var locked = false
var active_modifiers = {}
var last_level = LEVEL.MINIMAL
var thresholds = {}

signal tension_changed(current, old)
@warning_ignore("unused_signal") signal heat_level_changed(new_level, old_level)
signal threshold_crossed(threshold_name, direction, threshold_value, current_value)

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")
	initialize_thresholds()
	reset()
	set_process(true)

func initialize_thresholds():
	thresholds = {
		"MINIMAL": minimal_threshold,
		"LOW": low_threshold,
		"MEDIUM": medium_threshold,
		"HIGH": high_threshold,
		"CRITICAL": critical_threshold
	}

func _process(delta):
	if !enable_tension || locked:
		return
		
	update_tension(delta)

func update_tension(delta):
	var old_tension = current
	
	if current < target:
		current = min(current + tension_rise_rate * delta, target)
	elif current > target:
		current = max(current - tension_decay_rate * delta, target)
	
	current = clamp(current, min_tension, max_tension)
	
	if current != old_tension:
		check_tension_level()
		emit_tension_signals(old_tension)

func emit_tension_signals(old_tension):
	if signal_bus and signal_bus.has_signal("tension_changed"):
		signal_bus.emit_signal("tension_changed", current, old_tension)
		
	if current >= max_tension && old_tension < max_tension:
		if signal_bus and signal_bus.has_signal("max_tension_reached"):
			signal_bus.emit_signal("max_tension_reached")
			
	if current <= min_tension && old_tension > min_tension:
		if signal_bus and signal_bus.has_signal("min_tension_reached"):
			signal_bus.emit_signal("min_tension_reached")

func add(amount: float) -> void:
	if !enable_tension:
		return
	
	modify_tension(amount)

func reduce(amount: float) -> void:
	if !enable_tension:
		return
	
	modify_tension(-amount)

func modify_tension(amount: float):
	var old_tension = current
	current = clamp(current + amount, min_tension, max_tension)
	
	if old_tension != current:
		emit_signal("tension_changed", current, old_tension)
		check_threshold_crossed(old_tension, current)
		update_level()

func set_tension(value: float) -> void:
	if !enable_tension:
		return
		
	var old_tension = current
	current = clamp(value, min_tension, max_tension)
	
	if old_tension != current:
		emit_signal("tension_changed", current, old_tension)
		check_threshold_crossed(old_tension, current)
		update_level()

func lock_tension():
	locked = true

func unlock_tension():
	locked = false

func reset():
	current = default_tension
	target = default_tension
	last_level = get_tension_level()
	active_modifiers.clear()

func get_tension_value():
	return current

func get_normalized():
	return (current - min_tension) / (max_tension - min_tension) if max_tension > min_tension else 0.0

func get_tension_level():
	if current >= critical_threshold:
		return LEVEL.CRITICAL
	elif current >= high_threshold:
		return LEVEL.HIGH
	elif current >= medium_threshold:
		return LEVEL.MEDIUM
	elif current >= low_threshold:
		return LEVEL.LOW
	else:
		return LEVEL.MINIMAL

func get_tension_name():
	match get_tension_level():
		LEVEL.MINIMAL: return "MINIMAL"
		LEVEL.LOW: return "LOW"
		LEVEL.MEDIUM: return "MEDIUM"
		LEVEL.HIGH: return "HIGH"
		LEVEL.CRITICAL: return "CRITICAL"
		_: return "UNKNOWN"

func check_tension_level():
	var level = get_tension_level()
	
	if level != last_level and signal_bus:
		if signal_bus.has_signal("tension_level_changed"):
			signal_bus.emit_signal("tension_level_changed", get_tension_name(), LEVEL.keys()[last_level])
		
		check_threshold_signals(level)
		last_level = level

func check_threshold_signals(level):
	for threshold_name in thresholds:
		var threshold_value = thresholds[threshold_name]
		
		if last_level < level:
			if current >= threshold_value && current - tension_rise_rate < threshold_value:
				emit_threshold_crossed(threshold_name, "up", threshold_value)
		else:
			if current <= threshold_value && current + tension_decay_rate > threshold_value:
				emit_threshold_crossed(threshold_name, "down", threshold_value)

func emit_threshold_crossed(threshold_name, direction, threshold_value):
	if signal_bus and signal_bus.has_signal("threshold_crossed"):
		signal_bus.emit_signal("threshold_crossed", threshold_name, direction, threshold_value, current)

func add_modifier(id: String, value: float):
	active_modifiers[id] = value
	add(value)

func remove_modifier(id: String):
	if active_modifiers.has(id):
		var value = active_modifiers[id]
		active_modifiers.erase(id)
		reduce(value)

func has_modifier(id: String):
	return active_modifiers.has(id)

func get_modifier(id: String):
	return active_modifiers.get(id, 0.0)

func get_level_from_value(value: float):
	if value >= critical_threshold:
		return LEVEL.CRITICAL
	elif value >= high_threshold:
		return LEVEL.HIGH
	elif value >= medium_threshold:
		return LEVEL.MEDIUM
	elif value >= low_threshold:
		return LEVEL.LOW
	else:
		return LEVEL.MINIMAL

func check_threshold_crossed(old_value: float, new_value: float):
	check_single_threshold(old_value, new_value, "low", low_threshold)
	check_single_threshold(old_value, new_value, "medium", medium_threshold)
	check_single_threshold(old_value, new_value, "high", high_threshold)

func check_single_threshold(old_value: float, new_value: float, threshold_name: String, threshold_value: float):
	if old_value < threshold_value and new_value >= threshold_value:
		emit_signal("threshold_crossed", threshold_name, "up", threshold_value, new_value)
	elif old_value >= threshold_value and new_value < threshold_value:
		emit_signal("threshold_crossed", threshold_name, "down", threshold_value, new_value)

func update_level():
	var last_level_name = get_tension_name()
	var level_name = get_level_name_from_current()
	
	if level_name != last_level_name and signal_bus:
		signal_bus.emit_signal("tension_level_changed", level_name, last_level_name)

func get_level_name_from_current():
	if current < low_threshold:
		return "low"
	elif current < medium_threshold:
		return "medium"
	elif current < high_threshold:
		return "high"
	else:
		return "extreme"

func add_tension(amount: float):
	add(amount)

func set_decaying(decaying: bool):
	if !decaying:
		current = target

func set_decay_rate(rate: float):
	tension_decay_rate = max(rate, 0.0)
