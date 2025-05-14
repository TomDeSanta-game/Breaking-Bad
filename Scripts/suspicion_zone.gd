extends Area2D

signal player_entered(zone_name)
signal player_exited(zone_name)

@export var zone_name: String = "Suspicion Zone"
@export var detection_multiplier: float = 1.0
@export var alert_on_enter: bool = false
@export var tension_on_enter: float = 0.0
@export var alert_message: String = "You entered a suspicion zone"

var manager = null
var signal_bus = null
var player_in_zone: bool = false
var original_detection_rate: float = 1.0

func _ready():
	original_detection_rate = detection_multiplier
	
	manager = get_node_or_null("/root/TensionManager")
	if manager:
		manager.register_suspicion_zone(self)
		
	signal_bus = get_node_or_null("/root/SignalBus")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if !body.is_in_group("player"):
		return
	
	player_in_zone = true
	player_entered.emit(zone_name)
	
	if manager:
		manager.set_suspicion_active(true)
	
	if tension_on_enter > 0:
		manager.add_tension(tension_on_enter)
	
	if alert_on_enter and signal_bus:
		signal_bus.emit_signal("show_alert_message", alert_message)

func _on_body_exited(body: Node2D) -> void:
	if !body.is_in_group("player"):
		return
		
	player_in_zone = false
	player_exited.emit(zone_name)
	
	if manager:
		manager.set_suspicion_active(false)

func increase_detection_rate(multiplier: float = 2.0) -> void:
	detection_multiplier = multiplier

func reset_detection_rate() -> void:
	detection_multiplier = original_detection_rate

func _exit_tree() -> void:
	if manager:
		manager.unregister_suspicion_zone(self)
