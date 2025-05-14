extends Node

signal parkour_action_available(action_type, obstacle_data)
signal parkour_action_performed(action_type)
signal parkour_action_completed(action_type)
signal parkour_action_failed(action_type, reason)

enum ParkourAction {
	CLIMB,
	VAULT,
	SLIDE,
	WALL_RUN,
	LEDGE_GRAB,
	WALL_JUMP
}

const ACTION_PROPERTIES = {
	ParkourAction.CLIMB: {
		"duration": 1.2,
		"stamina_cost": 15.0,
		"animation": "climb",
		"detection_distance": 30.0,
		"min_height": 20.0,
		"max_height": 100.0,
		"cooldown": 0.5
	},
	ParkourAction.VAULT: {
		"duration": 0.7,
		"stamina_cost": 8.0,
		"animation": "vault",
		"detection_distance": 40.0,
		"min_height": 10.0,
		"max_height": 50.0,
		"cooldown": 0.3
	},
	ParkourAction.SLIDE: {
		"duration": 0.6,
		"stamina_cost": 5.0,
		"animation": "slide",
		"detection_distance": 50.0,
		"min_height": 0.0,
		"max_height": 60.0,
		"cooldown": 0.2
	},
	ParkourAction.WALL_RUN: {
		"duration": 1.5,
		"stamina_cost": 12.0,
		"animation": "wall_run",
		"detection_distance": 20.0,
		"min_height": 0.0,
		"max_height": 0.0,
		"cooldown": 0.5
	},
	ParkourAction.LEDGE_GRAB: {
		"duration": 1.0,
		"stamina_cost": 10.0,
		"animation": "ledge_grab",
		"detection_distance": 35.0,
		"min_height": 40.0,
		"max_height": 80.0,
		"cooldown": 0.4
	},
	ParkourAction.WALL_JUMP: {
		"duration": 0.5,
		"stamina_cost": 15.0,
		"animation": "wall_jump",
		"detection_distance": 25.0,
		"min_height": 0.0,
		"max_height": 0.0,
		"cooldown": 0.6
	}
}

var player = null
var current_action = null
var action_timer = 0.0
var cooldowns = {}
var detected_obstacles = {}
var available_actions = []

func _ready():
	SignalBus.player_event.connect(_on_player_event)
	initialize_cooldowns()

func _process(delta):
	if current_action:
		process_current_action(delta)
	else:
		detect_obstacles()
		check_input()

func initialize_cooldowns():
	for action in ParkourAction.values():
		cooldowns[action] = 0.0

func _on_player_event(event_type, data):
	if event_type == "parkour_action_triggered":
		var action_type = data.action if "action" in data else null
		var obstacle_id = data.obstacle_id if "obstacle_id" in data else null
		
		if action_type != null and obstacle_id != null:
			perform_parkour_action(action_type, obstacle_id)

func update_cooldowns(delta):
	for action in cooldowns.keys():
		if cooldowns[action] > 0.0:
			cooldowns[action] = max(0.0, cooldowns[action] - delta)

func detect_obstacles():
	if not player or current_action != null:
		return
	
	detected_obstacles.clear()
	available_actions.clear()
	
	var player_facing = player.player_facing()
	var space_state = player.get_world_2d().direct_space_state
	
	for action_type in ParkourAction.values():
		var props = ACTION_PROPERTIES[action_type]
		var detection_distance = props.detection_distance
		
		var query = PhysicsRayQueryParameters2D.new()
		query.from = player.global_position
		query.to = player.global_position + player_facing * detection_distance
		query.collision_mask = 1
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		
		if result and is_valid_obstacle_for_action(result.collider, action_type):
			var obstacle_id = result.collider.get_instance_id()
			var obstacle_data = {
				"id": obstacle_id,
				"node": result.collider,
				"position": result.position,
				"normal": result.normal,
				"distance": player.global_position.distance_to(result.position)
			}
			
			detected_obstacles[obstacle_id] = obstacle_data
			available_actions.append(action_type)
			
			parkour_action_available.emit(action_type, obstacle_data)

func is_valid_obstacle_for_action(obstacle, action_type):
	if not obstacle or not obstacle is PhysicsBody2D:
		return false
	
	var props = ACTION_PROPERTIES[action_type]
	
	match action_type:
		ParkourAction.CLIMB:
			return obstacle.is_in_group("climbable") or has_valid_height(obstacle, props.min_height, props.max_height)
		ParkourAction.VAULT:
			return obstacle.is_in_group("vaultable") or has_valid_height(obstacle, props.min_height, props.max_height)
		ParkourAction.SLIDE:
			return obstacle.is_in_group("slidable") or (obstacle is StaticBody2D and has_valid_height(obstacle, props.min_height, props.max_height))
		ParkourAction.WALL_RUN:
			return obstacle.is_in_group("wall_runnable") or obstacle is StaticBody2D
		ParkourAction.LEDGE_GRAB:
			return obstacle.is_in_group("ledge") or has_valid_height(obstacle, props.min_height, props.max_height)
		ParkourAction.WALL_JUMP:
			return obstacle.is_in_group("wall_jumpable") or obstacle is StaticBody2D
	
	return false

func has_valid_height(obstacle, min_height, max_height):
	if not obstacle or not obstacle is CollisionObject2D:
		return false
	
	var shape = obstacle.get_node_or_null("CollisionShape2D")
	if not shape or not shape.shape:
		return false
	
	var height = 0.0
	
	if shape.shape is RectangleShape2D:
		height = shape.shape.size.y
	elif shape.shape is CapsuleShape2D:
		height = shape.shape.height
	
	return height >= min_height and height <= max_height

func check_input():
	if not player or current_action != null or available_actions.is_empty():
		return
	
	if Input.is_action_just_pressed("parkour"):
		var best_action = get_best_available_action()
		if best_action != null:
			var obstacle_id = detected_obstacles.keys()[0]
			perform_parkour_action(best_action, obstacle_id)

func get_best_available_action():
	if available_actions.is_empty():
		return null
	
	var action_priorities = [
		ParkourAction.SLIDE,
		ParkourAction.VAULT, 
		ParkourAction.CLIMB,
		ParkourAction.LEDGE_GRAB,
		ParkourAction.WALL_RUN,
		ParkourAction.WALL_JUMP
	]
	
	for action in action_priorities:
		if action in available_actions and cooldowns[action] <= 0.0:
			return action
	
	return null

func perform_parkour_action(action_type, obstacle_id):
	if not player or current_action != null:
		return
	
	if not obstacle_id in detected_obstacles:
		return
	
	var obstacle_data = detected_obstacles[obstacle_id]
	var props = ACTION_PROPERTIES[action_type]
	
	if cooldowns[action_type] > 0.0:
		parkour_action_failed.emit(action_type, "Action on cooldown")
		return
	
	if player.has_method("get_current_stamina") and player.get_current_stamina() < props.stamina_cost:
		parkour_action_failed.emit(action_type, "Not enough stamina")
		return
	
	current_action = {
		"type": action_type,
		"obstacle": obstacle_data,
		"properties": props,
		"progress": 0.0
	}
	
	action_timer = 0.0
	
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	if player.has_method("consume_stamina"):
		player.consume_stamina(props.stamina_cost)
	
	position_for_action(action_type, obstacle_data)
	play_action_animation(action_type)
	
	parkour_action_performed.emit(action_type)
	SignalBus.player_state_changed.emit("parkour")

func position_for_action(action_type, obstacle_data):
	if not player or not obstacle_data:
		return
	
	var obstacle_position = obstacle_data.position
	var obstacle_normal = obstacle_data.normal
	
	match action_type:
		ParkourAction.CLIMB:
			var start_pos = obstacle_position + obstacle_normal * 5.0
			player.global_position = start_pos
		
		ParkourAction.VAULT:
			var start_pos = obstacle_position - obstacle_normal * 10.0
			player.global_position = start_pos
		
		ParkourAction.SLIDE:
			var start_pos = obstacle_position - obstacle_normal * 20.0
			player.global_position = start_pos
		
		ParkourAction.WALL_RUN:
			var start_pos = obstacle_position + obstacle_normal * 2.0
			player.global_position = start_pos
		
		ParkourAction.LEDGE_GRAB:
			var start_pos = obstacle_position + obstacle_normal * 2.0
			player.global_position = start_pos
		
		ParkourAction.WALL_JUMP:
			var start_pos = obstacle_position + obstacle_normal * 2.0
			player.global_position = start_pos

func play_action_animation(action_type):
	var animation_name = ACTION_PROPERTIES[action_type].animation
	
	if player and player.sprite and player.sprite.has_method("play"):
		player.sprite.play(animation_name)
	
	SignalBus.camera_effect_started.emit("parkour_" + animation_name)

func process_current_action(delta):
	if not current_action or not player:
		return
	
	action_timer += delta
	var progress = action_timer / current_action.properties.duration
	current_action.progress = progress
	
	handle_action_movement(delta, progress)
	
	if progress >= 1.0:
		complete_current_action()

func handle_action_movement(_delta, progress):
	if not current_action or not player:
		return
	
	var action_type = current_action.type
	var obstacle_data = current_action.obstacle
	
	var start_pos = player.global_position
	var end_pos = Vector2.ZERO
	
	match action_type:
		ParkourAction.CLIMB:
			var height = obstacle_data.node.get_node("CollisionShape2D").shape.size.y if obstacle_data.node.get_node_or_null("CollisionShape2D") else 50.0
			end_pos = obstacle_data.position + Vector2(0, -height - 10.0)
		
		ParkourAction.VAULT:
			end_pos = obstacle_data.position + -obstacle_data.normal * 30.0
		
		ParkourAction.SLIDE:
			end_pos = obstacle_data.position + -obstacle_data.normal * 40.0
		
		ParkourAction.WALL_RUN:
			var run_direction = player.player_facing().rotated(PI/2) if Input.is_action_pressed("ui_right") else player.player_facing().rotated(-PI/2)
			end_pos = obstacle_data.position + run_direction * 50.0
		
		ParkourAction.LEDGE_GRAB:
			var height = obstacle_data.node.get_node("CollisionShape2D").shape.size.y if obstacle_data.node.get_node_or_null("CollisionShape2D") else 50.0
			end_pos = obstacle_data.position + Vector2(0, -height - 10.0)
		
		ParkourAction.WALL_JUMP:
			end_pos = obstacle_data.position + obstacle_data.normal * 70.0 + Vector2(0, -50.0)
	
	var current_pos = start_pos.lerp(end_pos, get_movement_curve(progress))
	player.global_position = current_pos

func get_movement_curve(progress):
	var curve_value = 0.0
	
	if progress < 0.3:
		curve_value = progress * 0.5 / 0.3
	elif progress < 0.7:
		curve_value = 0.5 + (progress - 0.3) * 0.4 / 0.4
	else:
		curve_value = 0.9 + (progress - 0.7) * 0.1 / 0.3
	
	return curve_value

func complete_current_action():
	if not current_action or not player:
		return
	
	var action_type = current_action.type
	cooldowns[action_type] = ACTION_PROPERTIES[action_type].cooldown
	
	if player.has_method("set_physics_process"):
		player.set_physics_process(true)
	
	SignalBus.player_state_changed.emit("normal")
	SignalBus.camera_effect_ended.emit("parkour_" + ACTION_PROPERTIES[action_type].animation)
	
	parkour_action_completed.emit(action_type)
	
	current_action = null
	action_timer = 0.0

func cancel_current_action():
	if not current_action:
		return
	
	var action_type = current_action.type
	
	if player.has_method("set_physics_process"):
		player.set_physics_process(true)
	
	parkour_action_failed.emit(action_type, "Action canceled")
	
	current_action = null
	action_timer = 0.0

func setup_player(player_node):
	player = player_node 