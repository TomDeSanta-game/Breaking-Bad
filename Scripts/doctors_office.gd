extends Node2D

@onready var player = $Player
@onready var doctor = $Doctor
@onready var fade_rect = $ColorRect

var scene_initialized = false
var objective_shown = false
var dialogue_started = false

func _ready():
	if player:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		player.hide_ui(true)
		
	await get_tree().create_timer(1.0).timeout
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 1.5)
	await tween.finished
	
	if player:
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
		scene_initialized = true

func _process(_delta):
	if scene_initialized and !objective_shown:
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus:
			signal_bus.emit_signal("show_mission_text", "Doctor's Appointment", "The doctor should have my test results today...")
			objective_shown = true
	
	if doctor and player and scene_initialized and !dialogue_started:
		var distance = doctor.global_position.distance_to(player.global_position)
		if distance < 50:
			start_diagnosis_scene()
			dialogue_started = true

func start_diagnosis_scene():
	if player:
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		player.hide_ui(true)
	
	var dialogic = get_node_or_null("/root/Dialogic")
	if dialogic:
		dialogic.start("diagnosis")
		await dialogic.timeline_ended
		transition_to_next_scene()

func transition_to_next_scene():
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 1.5)
	await tween.finished
	
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager:
		scene_manager.change_scene("res://Scenes/House.tscn")
