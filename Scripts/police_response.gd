extends Node

enum ALERT_LEVEL {NONE, SUSPICIOUS, SEARCHING, PURSUIT, MANHUNT}
enum RESPONSE_TYPE {PATROL, INVESTIGATION, SEARCH, CHASE, SWAT}

@export_category("Police Response")
@export var enable_police_response: bool = true
@export var response_cooldown: float = 30.0
@export var initial_response_delay: float = 5.0
@export var max_units_per_response: int = 3
@export var spawn_distance: float = 600.0

@export var max_wanted_level: int = 5
@export var wanted_decay_rate: float = 0.02
@export var wanted_decay_delay: float = 10.0
@export var crime_report_chance: float = 0.4

@export_category("Police Units")
@export var patrol_unit_scene: PackedScene
@export var investigation_unit_scene: PackedScene
@export var search_unit_scene: PackedScene
@export var chase_unit_scene: PackedScene
@export var swat_unit_scene: PackedScene

var manager = null
var signal_bus = null
var current_alert_level = ALERT_LEVEL.NONE
var current_wanted_level: int = 0
var wanted_points: float = 0.0
var wanted_decay_timer: float = 0.0
var response_timer: float = 0.0
var active_response: bool = false
var last_player_position: Vector2
var player = null
var active_units = []
var spawn_points = []

func _ready():
	manager = get_node_or_null("/root/TensionManager")
	signal_bus = get_node_or_null("/root/SignalBus")
	
	if signal_bus:
		signal_bus.threshold_crossed.connect(_on_tension_threshold_crossed)
	
	if manager:
		manager.player_detected.connect(_on_player_detected)
	
	await get_tree().process_frame
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		player = player_nodes[0]
		
	for point in get_tree().get_nodes_in_group("police_spawn"):
		spawn_points.append(point)

func _process(_delta):
	if !enable_police_response || !player:
		return
		
	last_player_position = player.global_position
	
	if current_wanted_level > 0 && current_alert_level < ALERT_LEVEL.PURSUIT:
		wanted_decay_timer -= _delta
		if wanted_decay_timer <= 0:
			wanted_points -= wanted_decay_rate * _delta
			if wanted_points < 0:
				reduce_wanted_level()
	
	if active_response:
		response_timer -= _delta
		if response_timer <= 0:
			active_response = false
	
	for i in range(active_units.size() - 1, -1, -1):
		if !is_instance_valid(active_units[i]):
			active_units.remove_at(i)

func add_crime_points(points: float, position: Vector2 = Vector2.ZERO):
	if randf() > crime_report_chance:
		return
		
	wanted_points += points
	wanted_decay_timer = wanted_decay_delay
	
	if position != Vector2.ZERO:
		report_crime_at_location(position)
		
	var target_level = int(min(wanted_points, max_wanted_level))
	if target_level > current_wanted_level:
		set_wanted_level(target_level)

func set_wanted_level(level: int):
	var old_level = current_wanted_level
	current_wanted_level = clamp(level, 0, max_wanted_level)
	
	if current_wanted_level != old_level:
		if signal_bus:
			signal_bus.wanted_level_changed.emit(current_wanted_level, old_level)
		
		if current_wanted_level > old_level:
			var target_alert = ALERT_LEVEL.NONE
			match current_wanted_level:
				1: target_alert = ALERT_LEVEL.SUSPICIOUS
				2: target_alert = ALERT_LEVEL.SEARCHING
				3: target_alert = ALERT_LEVEL.PURSUIT
				4, 5: target_alert = ALERT_LEVEL.MANHUNT
			
			set_alert_level(target_alert)
			trigger_police_response()

func reduce_wanted_level():
	if current_wanted_level <= 0:
		return
		
	wanted_points = max(0, wanted_points - 1.0)
	set_wanted_level(int(wanted_points))
	
	if current_wanted_level == 0:
		set_alert_level(ALERT_LEVEL.NONE)

func set_alert_level(level: ALERT_LEVEL):
	var old_level = current_alert_level
	current_alert_level = level
	
	if current_alert_level != old_level:
		if signal_bus:
			signal_bus.police_alert_changed.emit(current_alert_level, old_level)
		
		if current_alert_level > old_level:
			trigger_police_response()
		elif current_alert_level == ALERT_LEVEL.NONE:
			for unit in active_units:
				if is_instance_valid(unit) && unit.has_method("return_to_station"):
					unit.return_to_station()

func report_crime_at_location(position: Vector2):
	if current_alert_level <= ALERT_LEVEL.SUSPICIOUS:
		set_alert_level(ALERT_LEVEL.SUSPICIOUS)
		var timer = get_tree().create_timer(initial_response_delay)
		timer.timeout.connect(func(): spawn_investigation_at(position))

func trigger_police_response():
	if active_response:
		return
		
	active_response = true
	response_timer = response_cooldown
	
	var response_type = RESPONSE_TYPE.PATROL
	match current_alert_level:
		ALERT_LEVEL.SUSPICIOUS:
			response_type = RESPONSE_TYPE.INVESTIGATION
		ALERT_LEVEL.SEARCHING:
			response_type = RESPONSE_TYPE.SEARCH
		ALERT_LEVEL.PURSUIT:
			response_type = RESPONSE_TYPE.CHASE
		ALERT_LEVEL.MANHUNT:
			response_type = RESPONSE_TYPE.SWAT
	
	if signal_bus:
		signal_bus.police_response.emit(response_type)
	
	spawn_response_units(response_type)

func spawn_response_units(response_type: RESPONSE_TYPE):
	var count = int(current_wanted_level) + 1
	count = min(count, max_units_per_response)
	
	for i in range(count):
		var spawn_position = get_spawn_position()
		match response_type:
			RESPONSE_TYPE.PATROL:
				spawn_patrol_at(spawn_position)
			RESPONSE_TYPE.INVESTIGATION:
				spawn_investigation_at(spawn_position)
			RESPONSE_TYPE.SEARCH:
				spawn_search_at(spawn_position)
			RESPONSE_TYPE.CHASE:
				spawn_chase_at(spawn_position)
			RESPONSE_TYPE.SWAT:
				spawn_swat_at(spawn_position)

func get_spawn_position() -> Vector2:
	if spawn_points.size() > 0:
		var point = spawn_points[randi() % spawn_points.size()]
		return point.global_position
		
	var angle = randf() * TAU
	var distance = spawn_distance + randf() * 200.0
	return last_player_position + Vector2(cos(angle), sin(angle)) * distance

func spawn_patrol_at(position: Vector2):
	if !patrol_unit_scene:
		return
	spawn_unit(patrol_unit_scene, position)

func spawn_investigation_at(position: Vector2):
	if !investigation_unit_scene:
		spawn_unit(patrol_unit_scene, position)
		return
	spawn_unit(investigation_unit_scene, position)

func spawn_search_at(position: Vector2):
	if !search_unit_scene:
		spawn_unit(patrol_unit_scene, position)
		return
	spawn_unit(search_unit_scene, position)

func spawn_chase_at(position: Vector2):
	if !chase_unit_scene:
		spawn_unit(patrol_unit_scene, position)
		return
	spawn_unit(chase_unit_scene, position)

func spawn_swat_at(position: Vector2):
	if !swat_unit_scene:
		spawn_unit(chase_unit_scene, position)
		return
	spawn_unit(swat_unit_scene, position)

func spawn_unit(scene: PackedScene, position: Vector2):
	if !scene:
		return
	var unit = scene.instantiate()
	get_tree().current_scene.add_child(unit)
	unit.global_position = position
	
	if unit.has_signal("unit_destroyed"):
		unit.unit_destroyed.connect(_on_unit_destroyed)
	
	if unit.has_method("set_target") && player:
		unit.set_target(player)
	
	active_units.append(unit)

func _on_unit_destroyed(unit):
	for i in range(active_units.size()):
		if active_units[i] == unit:
			active_units.remove_at(i)
			break

func _on_tension_threshold_crossed(_threshold_name, direction, _threshold_value, _current_value):
	if !enable_police_response:
		return
	
	match _threshold_name:
		"HIGH", "CRITICAL":
			if direction == "up" && current_wanted_level < 3:
				add_crime_points(1.0, Vector2.ZERO)

func _on_player_detected(npc_type):
	if !enable_police_response:
		return
		
	if npc_type == "police" || npc_type == "guard":
		if current_alert_level < ALERT_LEVEL.PURSUIT:
			set_alert_level(ALERT_LEVEL.PURSUIT)
