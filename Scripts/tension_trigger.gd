extends Area2D

@export var one_shot: bool = true
@export var auto_trigger: bool = false
@export var tension_amount: float = 0.2
@export var alert_police: bool = false
@export var trigger_group: String = ""
@export var trigger_message: String = ""

var manager
var signal_bus
var triggered = false

func _ready():
	manager = get_node_or_null("/root/TensionManager")
	signal_bus = get_node_or_null("/root/SignalBus")
	
	collision_mask = 2
	
	if auto_trigger:
		call_deferred("trigger")
	else:
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		trigger()

func trigger():
	if one_shot and triggered:
		return
		
	triggered = true
	
	if manager:
		if tension_amount > 0:
			manager.add_tension(tension_amount)
			
		if alert_police:
			manager.alert_police(global_position)
	
	if signal_bus and trigger_message != "":
		signal_bus.emit_signal("show_alert_message", trigger_message)
	
	if trigger_group != "":
		get_tree().call_group(trigger_group, "on_tension_trigger", self)
	
	if one_shot:
		monitoring = false

func reset():
	triggered = false
	monitoring = true
