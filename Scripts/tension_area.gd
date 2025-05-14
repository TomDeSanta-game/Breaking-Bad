extends Area2D

signal player_entered_area(area_name)
signal player_exited_area(area_name)

@export var area_name: String = "Tension Area"
@export var base_tension: float = 0.2
@export var tension_multiplier: float = 1.0
@export var heat_modifier: float = 0.2
@export var tension_buildup_rate: float = 0.05
@export var apply_visual_effects: bool = true
@export var show_message_on_enter: bool = false

var manager
var effects
var signal_bus
var player_in_area = false
var original_tension_rate = 0.0
var current_tension = 0.0

func _ready():
	manager = get_node_or_null("/root/TensionManager")
	effects = get_node_or_null("/root/TensionEffects")
	signal_bus = get_node_or_null("/root/SignalBus")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if manager:
		original_tension_rate = manager.tension_engine.rise_rate

func _process(delta):
	if player_in_area && manager:
		if current_tension < base_tension:
			current_tension += tension_buildup_rate * delta
			manager.add_tension(tension_buildup_rate * delta * tension_multiplier)
			
			if apply_visual_effects && effects:
				add_visual_effects()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = true
		player_entered_area.emit(area_name)
		
		if show_message_on_enter && signal_bus:
			signal_bus.emit_signal("show_alert_message", "Entered " + area_name)
			
		if manager:
			manager.tension_engine.rise_rate = original_tension_rate + tension_buildup_rate
			manager.add_tension(base_tension * tension_multiplier)
		
		if apply_visual_effects && effects:
			add_visual_effects()

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_area = false
		player_exited_area.emit(area_name)
		
		if manager:
			manager.tension_engine.rise_rate = original_tension_rate
			
		if apply_visual_effects && effects:
			remove_visual_effects()

func add_visual_effects():
	if !effects:
		return
		
	var effect_level = get_effect_level()
	
	match effect_level:
		0:
			effects.add_effect("slight_desaturation", 0.3)
			effects.add_effect("light_vignette", 0.3)
		1:
			effects.add_effect("medium_desaturation", 0.5)
			effects.add_effect("medium_vignette", 0.5)
		2:
			effects.add_effect("heavy_desaturation", 0.7)
			effects.add_effect("medium_vignette", 0.7)

func remove_visual_effects():
	if !effects:
		return
		
	effects.remove_effect("slight_desaturation")
	effects.remove_effect("medium_desaturation")
	effects.remove_effect("heavy_desaturation")
	effects.remove_effect("light_vignette")
	effects.remove_effect("medium_vignette")

func get_effect_level() -> int:
	if base_tension < 0.3:
		return 0
	elif base_tension < 0.6:
		return 1
	else:
		return 2

func _exit_tree() -> void:
	if player_in_area && manager:
		manager.tension_engine.rise_rate = original_tension_rate
