extends Area2D

@export var territory_id: String = "Unknown Territory"
@export var display_name: String = ""
@export var territory_influence: float = 100.0
@export var territory_type: String = "Neutral"
@export var allowed_customer_types: Array[String] = []
@export var customer_spawn_rate: float = 0.5
@export var territory_heat: float = 0.0
@export var police_response_time: float = 10.0
@export var danger_level: int = 1

var active_dealers = []
var active_customers = []
var street_dealing = null
var tension_manager = null
var player_in_territory = false
var territory_timer = null
var police_timer = null
var spawn_points = []

func _ready():
	connect("body_entered", _on_territory_area_body_entered)
	connect("body_exited", _on_territory_area_body_exited)
	
	street_dealing = get_node_or_null("/root/StreetDealing")
	tension_manager = get_node_or_null("/root/TensionManager")
	
	if display_name.is_empty():
		display_name = territory_id
	
	territory_timer = Timer.new()
	territory_timer.one_shot = false
	territory_timer.wait_time = 5.0
	territory_timer.timeout.connect(_on_territory_timer_timeout)
	add_child(territory_timer)
	territory_timer.start()
	
	police_timer = Timer.new()
	police_timer.one_shot = true
	police_timer.wait_time = police_response_time
	police_timer.timeout.connect(_on_police_timer_timeout)
	add_child(police_timer)
	
	find_spawn_points()

func _on_territory_area_body_entered(body):
	if body.is_in_group("player"):
		player_in_territory = true
		
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus:
			signal_bus.emit_signal("player_entered_territory", territory_id, territory_type)
		
		if street_dealing:
			street_dealing.player_entered_territory(territory_id)
			
	if body.is_in_group("dealer"):
		if !active_dealers.has(body):
			active_dealers.append(body)
			update_territory_state()
			
	if body.is_in_group("customer"):
		if !active_customers.has(body):
			var customer_type = body.get("customer_type") if body.has("customer_type") else "standard"
			if allowed_customer_types.size() == 0 || allowed_customer_types.has(customer_type):
				active_customers.append(body)
				update_territory_state()

func _on_territory_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_territory = false
		
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus:
			signal_bus.emit_signal("player_exited_territory", territory_id)
			
		if street_dealing:
			street_dealing.player_exited_territory(territory_id)
			
	if body.is_in_group("dealer"):
		active_dealers.erase(body)
		update_territory_state()
		
	if body.is_in_group("customer"):
		active_customers.erase(body)
		update_territory_state()

func update_territory_state():
	if street_dealing:
		street_dealing.update_territory_state(territory_id, active_dealers.size(), active_customers.size(), territory_heat)

func _on_territory_timer_timeout():
	cleanup_invalid_references()
	update_territory_state()
	
	if tension_manager && territory_heat > 0:
		if player_in_territory:
			tension_manager.add_tension(territory_heat * 0.01)

func _on_police_timer_timeout():
	if tension_manager:
		tension_manager.police_response(global_position, territory_heat)
		territory_heat = max(0, territory_heat - 20)
		police_timer.wait_time = police_response_time
		
	if territory_heat > 50:
		police_timer.start()

func cleanup_invalid_references():
	for i in range(active_dealers.size() - 1, -1, -1):
		if !is_instance_valid(active_dealers[i]):
			active_dealers.remove_at(i)
			
	for i in range(active_customers.size() - 1, -1, -1):
		if !is_instance_valid(active_customers[i]):
			active_customers.remove_at(i)

func add_heat(amount):
	territory_heat = min(territory_heat + amount, 100)
	
	if territory_heat > 50 && !police_timer.is_stopped():
		police_timer.start()
		
	update_territory_state()

func reduce_heat(amount):
	territory_heat = max(territory_heat - amount, 0)
	update_territory_state()

func find_spawn_points():
	spawn_points = []
	for child in get_children():
		if child.is_in_group("spawn_point"):
			spawn_points.append(child)

func get_random_spawn_point():
	if spawn_points.size() > 0:
		return spawn_points[randi() % spawn_points.size()]
	return null

func get_dealers_count():
	return active_dealers.size()
	
func get_customers_count():
	return active_customers.size()
	
func get_heat_level():
	return territory_heat
