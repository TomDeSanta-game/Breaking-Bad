extends Node2D

signal show_alert_message(message)
signal surveillance_emergency_triggered(camera_id, level)
signal surveillance_feed_static(intensity)

@export var camera_id: String = "CAM_01"
@export var camera_name: String = "Main Entrance" 
@export var rotation_speed: float = 0.5
@export var can_rotate: bool = false
@export var rotation_angle: float = 45.0
@export var emergency_mode: bool = false
@export var detect_motion: bool = true
@export var auto_trigger: bool = false
@export var view_color_normal: Color = Color(1, 0, 0, 0.2)
@export var view_color_alert: Color = Color(1, 0, 0, 0.5)

var base_rotation: float = 0.0
var surveillance_system: Node
var player_in_area: bool = false
var movement_detected: bool = false
var rotation_direction: int = 1
var initial_view_points: Array
var camera_data = {}
var signal_bus: Node

func _ready():
	add_to_group("surveillance_camera")
	
	base_rotation = rotation
	initial_view_points = $ViewIndicator.points.duplicate()
	signal_bus = get_node_or_null("/root/SignalBus")
	surveillance_system = get_node_or_null("/root/SurveillanceCameraSystem")
	
	$IdLabel.text = camera_id
	$CanvasLayer/CameraUI/CameraInfo.text = camera_id + " - " + camera_name
	
	if surveillance_system and surveillance_system.has_method("register_camera"):
		camera_data = {
			"id": camera_id,
			"name": camera_name,
			"camera_node": $Camera2D,
			"ui_layer": $CanvasLayer,
			"static_overlay": $StaticOverlay,
			"position": global_position,
			"can_rotate": can_rotate,
			"emergency_mode": emergency_mode
		}
		surveillance_system.register_camera($Camera2D, camera_id)
		
	if auto_trigger:
		$InteractionArea.body_entered.connect(_on_auto_trigger)

func _process(delta):
	if can_rotate:
		if rotation_degrees > base_rotation + rotation_angle:
			rotation_direction = -1
		elif rotation_degrees < base_rotation - rotation_angle:
			rotation_direction = 1
			
		rotation_degrees += rotation_speed * rotation_direction * delta

func _on_interaction_area_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = true
		if signal_bus and signal_bus.has_signal("show_alert_message"):
			signal_bus.emit_signal("show_alert_message", "Press E to access camera " + camera_id)
		else:
			show_alert_message.emit("Press E to access camera " + camera_id)
			
		body.connect("interact", _on_player_interact, CONNECT_ONE_SHOT) if body.has_signal("interact") else null

func _on_interaction_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_area = false
		if body.has_signal("interact") and body.is_connected("interact", _on_player_interact):
			body.disconnect("interact", _on_player_interact)

func _on_player_interact():
	if player_in_area and surveillance_system and surveillance_system.has_method("activate_camera"):
		surveillance_system.activate_camera(camera_id)

func _on_auto_trigger(body):
	if body.is_in_group("player") and surveillance_system and surveillance_system.has_method("activate_camera") and auto_trigger:
		surveillance_system.activate_camera(camera_id)

func _on_view_area_body_entered(body):
	if body.is_in_group("player") and detect_motion:
		$ViewIndicator.default_color = view_color_alert
		movement_detected = true
		$MotionSensor.start()
		
		if emergency_mode:
			if signal_bus and signal_bus.has_signal("surveillance_emergency_triggered"):
				signal_bus.emit_signal("surveillance_emergency_triggered", camera_id, 1)
			else:
				surveillance_emergency_triggered.emit(camera_id, 1)

func _on_view_area_body_exited(body):
	if body.is_in_group("player") and detect_motion:
		movement_detected = false

func _on_motion_sensor_timeout():
	if !movement_detected:
		$ViewIndicator.default_color = view_color_normal

func add_static_effect(intensity: float = 0.3):
	$StaticOverlay.visible = true
	$StaticOverlay.modulate.a = intensity
	
	if signal_bus and signal_bus.has_signal("surveillance_feed_static"):
		signal_bus.emit_signal("surveillance_feed_static", intensity)
	else:
		surveillance_feed_static.emit(intensity)
		
	get_tree().create_timer(2.0).timeout.connect(func():
		$StaticOverlay.visible = false
	)

func activate_emergency_mode():
	emergency_mode = true
	$ViewIndicator.default_color = view_color_alert
	add_static_effect(0.5)
	
	if auto_trigger and surveillance_system and surveillance_system.has_method("activate_camera"):
		surveillance_system.activate_camera(camera_id)

func deactivate_emergency_mode():
	emergency_mode = false
	$ViewIndicator.default_color = view_color_normal
	
func set_camera_info(id: String, n: String):
	camera_id = id
	camera_name = n
	$IdLabel.text = camera_id
	$CanvasLayer/CameraUI/CameraInfo.text = camera_id + " - " + camera_name 

func get_camera_data() -> Dictionary:
	return camera_data 
