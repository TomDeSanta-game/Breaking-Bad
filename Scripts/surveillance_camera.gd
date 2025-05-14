extends Node2D

signal camera_activated(camera_id)
signal show_interaction_prompt(text)
signal hide_interaction_prompt

@export var camera_id: String = "camera_01"
@export var camera_label: String = "Surveillance Camera 1"
@export var initial_zoom: Vector2 = Vector2(1.0, 1.0)
@export var restricted_area: bool = false

@onready var camera: Camera2D = $Camera2D
@onready var label: Label = $Label
@onready var interaction_area: Area2D = $InteractionArea

var player = null

func _ready():
	if label:
		label.text = camera_label
	
	if camera:
		camera.zoom = initial_zoom
		camera.current = false
	
	add_to_group("surveillance_cameras")
	
	var surveillance_system = get_node_or_null("/root/SurveillanceCameraSystem")
	if surveillance_system and surveillance_system.has_method("register_camera"):
		surveillance_system.register_camera(camera, camera_id)

func _on_interaction_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		show_prompt("Press E to access camera")

func _on_interaction_area_body_exited(body):
	if body.is_in_group("player"):
		player = null
		hide_prompt()

func show_prompt(text):
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("show_interaction_prompt"):
		signal_bus.emit_signal("show_interaction_prompt", text)
	else:
		show_interaction_prompt.emit(text)

func hide_prompt():
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("hide_interaction_prompt"):
		signal_bus.emit_signal("hide_interaction_prompt")
	else:
		hide_interaction_prompt.emit()

func _unhandled_input(event):
	if event.is_action_pressed("interact") and player:
		activate_camera()
		get_viewport().set_input_as_handled()

func activate_camera():
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("camera_activated"):
		signal_bus.emit_signal("camera_activated", camera_id)
	else:
		camera_activated.emit(camera_id)

func get_camera_data():
	return {
		"id": camera_id,
		"label": camera_label,
		"node": self,
		"restricted": restricted_area
	} 
