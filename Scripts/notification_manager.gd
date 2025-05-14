extends Node

var NotificationScene = preload("res://Scenes/Notification.tscn")

var notification_container: Control
var id_counter: int = 0
var notifications = {}
var max_notifications: int = 5

var chemical_prefixes = {
	"info": "In - Indium",
	"success": "Br - Bromine",
	"warning": "Cr - Chromium",
	"error": "Hg - Mercury"
}

func _ready():
	setup_container()
	SignalBus.notification_requested.connect(_on_notification_requested)

func setup_container():
	notification_container = Control.new()
	notification_container.name = "NotificationContainer"
	notification_container.anchors_preset = Control.PRESET_TOP_RIGHT
	notification_container.anchor_right = 1.0
	notification_container.anchor_bottom = 0.0
	notification_container.offset_left = -400
	notification_container.offset_top = 20
	notification_container.offset_right = -20
	notification_container.offset_bottom = 500
	notification_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(notification_container)
	
	var vbox = VBoxContainer.new()
	vbox.name = "NotificationsVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	notification_container.add_child(vbox)

func show_notification(title: String, message: String, type: String = "info", duration: float = 4.0) -> int:
	var n = NotificationScene.instantiate()
	n.id = id_counter
	n.notification_type = type
	n.set_title(title)
	n.set_message(message)
	n.set_lifetime(duration)
	n.closed.connect(_on_notification_closed)
	
	var vbox = notification_container.get_node("NotificationsVBox")
	vbox.add_child(n)
	
	if vbox.get_child_count() > max_notifications:
		var oldest = vbox.get_child(0)
		hide_notification(oldest.id)
	
	notifications[id_counter] = n
	id_counter += 1
	
	return n.id

func _on_notification_requested(title: String, message: String, type: String = "info", duration: float = 4.0):
	show_notification(title, message, type, duration)

func _on_notification_closed(id: int):
	remove_notification(id)

func hide_notification(id: int):
	if notifications.has(id):
		notifications[id].close()

func remove_notification(id: int):
	if notifications.has(id):
		notifications.erase(id)

func show_info(title: String, message: String, duration: float = 4.0) -> int:
	return show_notification(title, message, "info", duration)

func show_success(title: String, message: String, duration: float = 4.0) -> int:
	return show_notification(title, message, "success", duration)

func show_warning(title: String, message: String, duration: float = 4.0) -> int:
	return show_notification(title, message, "warning", duration)

func show_error(title: String, message: String, duration: float = 4.0) -> int:
	return show_notification(title, message, "error", duration)

func show_objective(objective_text: String, duration: float = 5.0) -> int:
	return show_notification("New Objective", objective_text, "success", duration)

func show_phone_message(sender: String, message: String, duration: float = 4.0) -> int:
	return show_notification("Phone: " + sender, message, "info", duration)

func show_drug_effect(effect_name: String, effect_description: String, duration: float = 3.0) -> int:
	return show_notification("Drug Effect: " + effect_name, effect_description, "warning", duration)

func show_illegal_action(action_name: String, consequence: String, duration: float = 4.0) -> int:
	return show_notification("Illegal Activity: " + action_name, consequence, "error", duration) 