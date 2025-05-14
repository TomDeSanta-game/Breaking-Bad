extends Node

signal encounter_started(encounter_name)
signal encounter_completed(encounter_name, success)
signal encounter_failed(encounter_name)
signal time_updated(time_remaining, total_time)

@export_category("Encounter Settings")
@export var encounter_name: String = "Tension Encounter"
@export var description: String = "Complete the encounter before time runs out"
@export var auto_start: bool = false
@export var duration: float = 30.0
@export var initial_tension: float = 0.3
@export var failure_tension: float = 0.6
@export var success_tension_reduction: float = 0.2
@export var show_timer: bool = true
@export var show_objective: bool = true
@export var critical_time_threshold: float = 5.0
@export var warning_time_threshold: float = 10.0

@export_category("Failure Conditions")
@export var fail_on_timeout: bool = true
@export var fail_if_detected: bool = false
@export var failure_tension_boost: float = 0.3

var manager
var active: bool = false
var time_remaining: float = 0.0
var objectives_completed: int = 0
var total_objectives: int = 0
var success: bool = false

func _ready():
	manager = get_node_or_null("/root/TensionManager")
	if auto_start:
		start_encounter()

func _process(delta):
	if !active:
		return
		
	if time_remaining > 0:
		time_remaining -= delta
		
		if time_remaining <= warning_time_threshold:
			if manager && manager.tension_engine && manager.tension_engine.current < failure_tension:
				manager.add_tension(delta * 0.1)
		
		if show_timer:
			time_updated.emit(time_remaining, duration)
			
		if time_remaining <= 0 && fail_on_timeout:
			fail_encounter()

func start_encounter():
	if active:
		return
		
	active = true
	time_remaining = duration
	
	if manager:
		manager.add_tension(initial_tension)
		
	encounter_started.emit(encounter_name)
	
	if show_objective && get_node_or_null("/root/SignalBus"):
		get_node("/root/SignalBus").emit_signal("show_mission_text", encounter_name, description)

func complete_encounter():
	if !active:
		return
		
	active = false
	success = true
	
	if manager:
		manager.reduce_tension(success_tension_reduction)
		
	encounter_completed.emit(encounter_name, true)
	
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.emit_signal("hide_mission_text")
		signal_bus.emit_signal("show_mission_complete", encounter_name)

func fail_encounter():
	if !active:
		return
		
	active = false
	success = false
	
	if manager && failure_tension_boost > 0:
		manager.add_tension(failure_tension_boost)
		
	encounter_failed.emit(encounter_name)
	
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.emit_signal("show_mission_text", encounter_name + " (FAILED)", description)
		signal_bus.emit_signal("hide_mission_text")

func set_total_objectives(count: int):
	total_objectives = count
	objectives_completed = 0

func complete_objective():
	objectives_completed += 1
	
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.emit_signal("update_mission_progress", objectives_completed, total_objectives)
	
	if objectives_completed >= total_objectives && total_objectives > 0:
		complete_encounter()

func on_player_detected():
	if active && fail_if_detected:
		fail_encounter()
