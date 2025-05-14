extends Node

var status_indicator_scene_path = "res://UI/Scenes/StatusIndicator.tscn"
var objective_indicator_scene_path = "res://UI/Scenes/ObjectiveIndicator.tscn"

var status_indicator: Node
var objective_indicator: Node
var notification_manager: Node

func _ready() -> void:
	create_managers()
	create_indicators()
	connect_signals()

func create_managers() -> void:
	notification_manager = Node.new()
	notification_manager.name = "NotificationManager"
	
	
	var script_path = "res://Scripts/notification_manager.gd"
	var script = load(script_path)
	if script:
		notification_manager.set_script(script)
	else:
		push_warning("Failed to load notification manager script: " + script_path)
	
	add_child(notification_manager)

func create_indicators() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "UIIndicators"
	canvas_layer.layer = 10
	add_child(canvas_layer)
	
	
	var status_scene = load(status_indicator_scene_path)
	if status_scene:
		status_indicator = status_scene.instantiate()
		status_indicator.name = "StatusIndicator"
		status_indicator.position = Vector2(20, 20)
		canvas_layer.add_child(status_indicator)
	else:
		push_warning("Failed to load status indicator scene: " + status_indicator_scene_path)
	
	
	var objective_scene = load(objective_indicator_scene_path)
	if objective_scene:
		objective_indicator = objective_scene.instantiate()
		objective_indicator.name = "ObjectiveIndicator"
		canvas_layer.add_child(objective_indicator)
	else:
		push_warning("Failed to load objective indicator scene: " + objective_indicator_scene_path)

func connect_signals() -> void:
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		if signal_bus.has_signal("player_objective_updated"):
			signal_bus.connect("player_objective_updated", _on_player_objective_updated)
		if signal_bus.has_signal("player_state_changed"):
			signal_bus.connect("player_state_changed", _on_player_state_changed)

func _on_player_objective_updated(title: String, description: String, objective_type: String, progress: float) -> void:
	if objective_indicator:
		objective_indicator.show_objective(title, description, objective_type, progress)

func _on_player_state_changed(state_name: String, value: float) -> void:
	match state_name:
		"low_stamina":
			notify_low_stamina()
		"tension_change":
			if value >= 0.7:
				notify_high_tension(value)

func show_notification(message: String, notification_type: String = "info", duration: float = 3.0) -> int:
	if notification_manager and notification_manager.has_method("show_notification"):
		return notification_manager.show_notification(message, notification_type, duration)
	print("Notification: " + message)  
	return -1

func show_objective(title: String, description: String = "", objective_type: String = "story", progress: float = 0.0, duration: float = 0.0) -> void:
	if objective_indicator and objective_indicator.has_method("show_objective"):
		objective_indicator.show_objective(title, description, objective_type, progress, duration)
	else:
		print("Objective: " + title + " - " + description)  

func update_objective(progress: float, description: String = "") -> void:
	if objective_indicator and objective_indicator.has_method("update_objective"):
		objective_indicator.update_objective(progress, description)

func complete_objective() -> void:
	if objective_indicator and objective_indicator.has_method("complete_objective"):
		objective_indicator.complete_objective()

func notify_low_stamina() -> void:
	show_notification("Low stamina! Slow down to recover.", "warning", 2.0)

func notify_high_tension(tension_value: float) -> void:
	var message = "High suspicion level! Be careful."
	if tension_value > 0.9:
		message = "EXTREME suspicion level! Take cover immediately!"
	show_notification(message, "error", 3.0)

func notify_item_pickup(item_name: String) -> void:
	show_notification("Picked up " + item_name, "info", 2.0)

func notify_objective_complete(objective_name: String) -> void:
	show_notification("Objective complete: " + objective_name, "success", 3.0) 
