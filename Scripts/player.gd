extends CharacterBody2D

@export var speed: float = 130.0
@export var acceleration: float = 2000.0
@export var friction: float = 2000.0
@export var sprint_multiplier: float = 1.5
@export var dash_power: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.8
@export var starting_health: float = 100.0
@export var damage_cooldown: float = 1.0
@export var max_heat_level: float = 100.0
@export var heat_decay_rate: float = 0.5
@export var interaction_distance: float = 50.0
@export_flags_2d_physics var interaction_mask: int = 0
@export var use_player_camera: bool = false
@export var camera_offset: Vector2 = Vector2.ZERO

var current_health: float = starting_health
var can_be_damaged: bool = true
var damage_timer: Timer = null
var dash_timer: Timer = null
var dash_cooldown_timer: Timer = null

var direction: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.RIGHT
var is_sprinting: bool = false
var is_dashing: bool = false
var can_dash: bool = true

var heat_level: float = 0.0

var is_hiding: bool = false
var in_interaction_area: bool = false
var current_interactable: Node2D = null
var nearest_interactables: Array[Node2D] = []

var evidence_items: Array[Dictionary] = []
var body_parts_damaged: Dictionary = {
	"head": 0.0,
	"torso": 0.0,
	"left_arm": 0.0,
	"right_arm": 0.0,
	"left_leg": 0.0,
	"right_leg": 0.0
}

enum PlayerState {
	IDLE,
	WALKING,
	RUNNING,
	HIDING,
	INTERACTING,
	INJURED,
	DEAD
}

var current_state: PlayerState = PlayerState.IDLE

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_ray: RayCast2D = $InteractionRay
@onready var hud: CanvasLayer = $HUD
@onready var heat_bar: ProgressBar = $HUD/HeatBar
@onready var camera: Camera2D = null

func _ready() -> void:
	Log.info("Player ready")
	
	hud.show()
	current_health = starting_health
	
	setup_normal_mapping()
	
	setup_damage_timer()
	setup_dash_timers()
	setup_interaction_ray()
	
	if use_player_camera and not has_node("Camera2D"):
		setup_camera()
	
	SignalBus.health_changed.emit(current_health, starting_health)
	SignalBus.heat_changed.emit(heat_level, max_heat_level)
	set_state(PlayerState.IDLE)
	
	emit_signal("player_position_changed", global_position)

func setup_damage_timer() -> void:
	damage_timer = Timer.new()
	damage_timer.one_shot = true
	damage_timer.wait_time = damage_cooldown
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)

func setup_dash_timers() -> void:
	dash_timer = Timer.new()
	dash_timer.one_shot = true
	dash_timer.wait_time = dash_duration
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	add_child(dash_timer)
	
	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)
	add_child(dash_cooldown_timer)

func setup_interaction_ray() -> void:
	if interaction_ray:
		interaction_ray.collision_mask = interaction_mask
		interaction_ray.target_position = Vector2(interaction_distance, 0)

func setup_shadow() -> void:
	pass

func setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "PlayerCamera"
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	camera.drag_horizontal_offset = 0.05
	camera.drag_vertical_offset = 0.05
	camera.offset = camera_offset
	add_child(camera)

func _physics_process(delta: float) -> void:
	handle_input()
	handle_movement(delta)
	update_interaction_ray()
	handle_animation()
	
	if camera and use_player_camera:
		update_camera(delta)
		
	move_and_slide()
	
	if heat_level > 0:
		reduce_heat(heat_decay_rate * delta)
	
	update_damaged_body_parts(delta)

func handle_input() -> void:
	var x_input = Input.get_axis("ui_left", "ui_right")
	var y_input = Input.get_axis("ui_up", "ui_down")
	
	direction = Vector2(x_input, y_input)
	if direction.length() > 1.0:
		direction = direction.normalized()
	
	is_sprinting = Input.is_action_pressed("Sprint")
	
	if Input.is_action_just_pressed("ui_accept") and can_dash and direction.length() > 0:
		start_dash()
	
	if Input.is_action_just_pressed("Interact"):
		handle_interaction()

func handle_movement(delta: float) -> void:
	var target_speed = speed
	
	if is_dashing:
		return
		
	if is_sprinting:
		target_speed *= sprint_multiplier
	
	var target_velocity = direction * target_speed
	
	if direction.length() > 0:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
		last_direction = direction.normalized()
		
		if is_sprinting and current_state != PlayerState.RUNNING:
			set_state(PlayerState.RUNNING)
		elif not is_sprinting and current_state != PlayerState.WALKING:
			set_state(PlayerState.WALKING)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		
		if velocity.length() < 5 and current_state != PlayerState.INTERACTING and current_state != PlayerState.HIDING and current_state != PlayerState.INJURED:
			set_state(PlayerState.IDLE)

func start_dash() -> void:
	if is_dashing or not can_dash:
		return
		
	is_dashing = true
	can_dash = false
	
	var dash_direction = direction.normalized()
	if dash_direction.length() < 0.1:
		dash_direction = last_direction
		
	velocity = dash_direction * dash_power
	
	dash_timer.start()
	dash_cooldown_timer.start()
	
	if camera:
		camera.offset += dash_direction * 20.0

func _on_dash_timer_timeout() -> void:
	is_dashing = false

func _on_dash_cooldown_timeout() -> void:
	can_dash = true

func handle_animation() -> void:
	if not sprite:
		return
	
	var animation_prefix = ""
	
	if abs(direction.y) > abs(direction.x) * 1.2:
		if direction.y < 0:
			animation_prefix = "Up"
		else:
			animation_prefix = "Down"
	else:
		animation_prefix = "Right"
		
		if velocity.x < 0 or (velocity.length() < 10 and last_direction.x < 0):
			sprite.flip_h = true
		else:
			sprite.flip_h = false
	
	var state_suffix = "_Idle"
	if is_dashing:
		state_suffix = "_Run"
		sprite.speed_scale = 2.0
	elif velocity.length() > 10:
		state_suffix = "_Run"
		
		var animation_speed = 1.0
		if is_sprinting:
			animation_speed = 1.6
		else:
			animation_speed = 1.2
			
		sprite.speed_scale = animation_speed
	else:
		sprite.speed_scale = 1.0
	
	sprite.play(animation_prefix + state_suffix)

func update_shadow() -> void:
	pass

func update_camera(delta: float) -> void:
	if camera:
		var look_direction = direction.normalized() * 20.0
		var target_offset = camera_offset + look_direction
		
		if is_dashing:
			camera.offset = camera.offset.lerp(target_offset, delta * 16.0)
		else:
			camera.offset = camera.offset.lerp(target_offset, delta * 8.0)

func update_interaction_ray() -> void:
	if not interaction_ray:
		return
	
	var facing = player_facing()
	interaction_ray.target_position = facing * interaction_distance
	interaction_ray.force_raycast_update()
	
	var previous_interactable = current_interactable
	current_interactable = null
	
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.is_in_group("interactable"):
			current_interactable = collider
	
	if nearest_interactables.size() > 0:
		for interactable in nearest_interactables:
			if is_instance_valid(interactable) and interactable.global_position.distance_to(global_position) < interaction_distance:
				if not current_interactable or interactable.global_position.distance_to(global_position) < current_interactable.global_position.distance_to(global_position):
					current_interactable = interactable
	
	if current_interactable != previous_interactable:
		if previous_interactable and is_instance_valid(previous_interactable):
			if previous_interactable.has_method("on_interaction_end"):
				previous_interactable.on_interaction_end(self)
			SignalBus.hide_interaction_prompt.emit()
		
		if current_interactable:
			if current_interactable.has_method("on_interaction_begin"):
				current_interactable.on_interaction_begin(self)
			
			var prompt = "Interact"
			if current_interactable.has_method("get_interaction_prompt"):
				prompt = current_interactable.get_interaction_prompt()
			
			SignalBus.show_interaction_prompt.emit(prompt)

func handle_interaction() -> void:
	if current_interactable and is_instance_valid(current_interactable):
		set_state(PlayerState.INTERACTING)
		
		if current_interactable.has_method("interact"):
			current_interactable.interact(self)
			
			if current_interactable.is_in_group("evidence"):
				collect_evidence(current_interactable)
			elif current_interactable.is_in_group("door"):
				if current_interactable.has_method("is_open") and current_interactable.has_method("get_door_id"):
					var door_id = current_interactable.get_door_id()
					if current_interactable.is_open():
						SignalBus.door_closed.emit(door_id)
					else:
						SignalBus.door_opened.emit(door_id)

func collect_evidence(evidence_item: Node2D) -> void:
	if evidence_item.has_method("get_evidence_data"):
		var evidence_data = evidence_item.get_evidence_data()
		evidence_items.append(evidence_data)
		SignalBus.item_picked_up.emit("evidence", evidence_data)

func clear_evidence(evidence_type: String = "") -> void:
	if evidence_type.is_empty():
		evidence_items.clear()
	else:
		evidence_items = evidence_items.filter(func(item): return item.type != evidence_type)
	
	SignalBus.item_used.emit("evidence_cleanup", "")

func has_evidence() -> bool:
	return evidence_items.size() > 0

func update_damaged_body_parts(delta: float) -> void:
	var total_recovery = 0.05 * delta
	
	for part in body_parts_damaged.keys():
		if body_parts_damaged[part] > 0.0:
			body_parts_damaged[part] = max(0.0, body_parts_damaged[part] - total_recovery)
			
			if body_parts_damaged[part] <= 0.0:
				SignalBus.player_event.emit("body_part_healed", part)

func take_locational_damage(body_part: String, damage_amount: float) -> void:
	if body_parts_damaged.has(body_part):
		body_parts_damaged[body_part] = min(1.0, body_parts_damaged[body_part] + damage_amount / 100.0)
		
		var modifier = 1.0
		match body_part:
			"head":
				modifier = 2.0
			"torso":
				modifier = 1.5
			"left_arm", "right_arm":
				modifier = 0.7
			"left_leg", "right_leg":
				modifier = 0.8
		
		var damage = damage_amount * modifier
		take_damage(damage)
		
		var data = {
			"part": body_part,
			"amount": body_parts_damaged[body_part]
		}
		SignalBus.player_event.emit("body_part_damaged", data)
		SignalBus.player_damaged.emit(damage, Vector2.ZERO)
		
		apply_injury_effects(body_part)
		
		if has_severe_injuries():
			set_state(PlayerState.INJURED)

func has_severe_injuries() -> bool:
	for part in body_parts_damaged:
		if body_parts_damaged[part] > 0.6:
			return true
	return false

func apply_injury_effects(body_part: String) -> void:
	var severity = body_parts_damaged[body_part]
	
	match body_part:
		"head":
			if severity > 0.7:
				SignalBus.camera_effect_started.emit("heavy_head_injury")
				SignalBus.threshold_crossed.emit("head_injury", "above", 0.7, severity)
			elif severity > 0.3:
				SignalBus.camera_effect_started.emit("medium_head_injury")
				SignalBus.threshold_crossed.emit("head_injury", "above", 0.3, severity)
		"left_leg", "right_leg":
			if severity > 0.5:
				speed = max(speed * 0.6, 40.0)
				SignalBus.threshold_crossed.emit("leg_injury", "above", 0.5, severity)
			elif severity > 0.2:
				speed = max(speed * 0.8, 60.0)
				SignalBus.threshold_crossed.emit("leg_injury", "above", 0.2, severity)

func take_damage(damage_amount: float) -> void:
	if not can_be_damaged or current_health <= 0.0:
		return
		
	current_health = max(0.0, current_health - damage_amount)
	SignalBus.health_changed.emit(current_health, starting_health)
	SignalBus.player_damaged.emit(damage_amount, Vector2.ZERO)
	
	if current_health < starting_health * 0.25:
		SignalBus.threshold_crossed.emit("health", "below", starting_health * 0.25, current_health)
	
	can_be_damaged = false
	damage_timer.start()
	
	if current_health <= 0.0:
		die()

func die() -> void:
	set_physics_process(false)
	set_process_input(false)
	set_state(PlayerState.DEAD)
	
	SignalBus.player_died.emit()

func heal(amount: float) -> void:
	var previous_health = current_health
	current_health = min(starting_health, current_health + amount)
	SignalBus.health_changed.emit(current_health, starting_health)
	SignalBus.player_damaged.emit(amount, Vector2.ZERO)
	
	if previous_health < starting_health * 0.25 and current_health >= starting_health * 0.25:
		SignalBus.threshold_crossed.emit("health", "above", starting_health * 0.25, current_health)
		
	set_state(calculate_state())

func add_heat(amount: float) -> void:
	var previous_heat = heat_level
	var previous_level = get_heat_level(previous_heat)
	
	heat_level = min(max_heat_level, heat_level + amount)
	SignalBus.heat_changed.emit(heat_level, max_heat_level)
	
	var new_level = get_heat_level(heat_level)
	if new_level != previous_level:
		SignalBus.heat_level_changed.emit(new_level, previous_level)
	
	if heat_level >= max_heat_level:
		alert_police()

func get_heat_level(heat: float) -> int:
	var percentage = heat / max_heat_level
	if percentage >= 0.8:
		return 3
	elif percentage >= 0.5:
		return 2
	elif percentage >= 0.2:
		return 1
	else:
		return 0

func reduce_heat(amount: float) -> void:
	var previous_heat = heat_level
	var previous_level = get_heat_level(previous_heat)
	
	heat_level = max(0.0, heat_level - amount)
	SignalBus.heat_changed.emit(heat_level, max_heat_level)
	
	var new_level = get_heat_level(heat_level)
	if new_level != previous_level:
		SignalBus.heat_level_changed.emit(new_level, previous_level)

func alert_police() -> void:
	SignalBus.police_alerted.emit(global_position, 1.0)

func player_facing() -> Vector2:
	if velocity.length() > 10.0:
		return velocity.normalized()
	elif sprite and sprite.flip_h:
		return Vector2.LEFT
	else:
		return Vector2.RIGHT

func set_state(new_state: PlayerState) -> void:
	if new_state == current_state:
		return
		
	var _old_state = current_state
	current_state = new_state
	
	var state_name = ""
	match current_state:
		PlayerState.IDLE: state_name = "idle"
		PlayerState.WALKING: state_name = "walking"
		PlayerState.RUNNING: state_name = "running"
		PlayerState.HIDING: state_name = "hiding"
		PlayerState.INTERACTING: state_name = "interacting"
		PlayerState.INJURED: state_name = "injured"
		PlayerState.DEAD: state_name = "dead"
	
	SignalBus.player_state_changed.emit(state_name)

func calculate_state() -> PlayerState:
	if current_health <= 0:
		return PlayerState.DEAD
	elif is_hiding:
		return PlayerState.HIDING
	elif has_severe_injuries():
		return PlayerState.INJURED
	elif velocity.length() > speed * 0.8 and is_sprinting:
		return PlayerState.RUNNING
	elif velocity.length() > speed * 0.1:
		return PlayerState.WALKING
	else:
		return PlayerState.IDLE

func enter_hiding() -> void:
	is_hiding = true
	set_state(PlayerState.HIDING)

func exit_hiding() -> void:
	is_hiding = false
	set_state(calculate_state())

func update_objective(objective_id: String, text: String, completed: bool = false) -> void:
	SignalBus.player_objective_updated.emit(objective_id, text, completed)
	
	if completed:
		SignalBus.objective_completed.emit(objective_id)

func _on_damage_timer_timeout() -> void:
	can_be_damaged = true

func _on_interaction_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable") and not nearest_interactables.has(area):
		nearest_interactables.append(area)

func _on_interaction_area_exited(area: Area2D) -> void:
	nearest_interactables.erase(area)
	
	if current_interactable == area:
		if area.has_method("on_interaction_end"):
			area.on_interaction_end(self)
		
		current_interactable = null
		SignalBus.hide_interaction_prompt.emit()

func _on_detected(detector_type: String) -> void:
	SignalBus.player_detected.emit(detector_type)
	
	match detector_type:
		"police", "security_camera", "guard":
			add_heat(20.0)
		"civilian":
			add_heat(5.0)

func show_objective(objective_text: String):
	if objective_text.is_empty():
		return
	
	var ui_controller = get_node_or_null("/root/UIController")
	if ui_controller and ui_controller.has_method("show_objective"):
		ui_controller.show_objective(objective_text)

func complete_objective():
	var ui_controller = get_node_or_null("/root/UIController")
	if ui_controller and ui_controller.has_method("complete_objective"):
		ui_controller.complete_objective()

func hide_ui(should_hide: bool = true):
	var _ui_controller = get_node_or_null("/root/UIController")
	var canvas_layer = get_node_or_null("/root/UIController/UIIndicators")
	
	if canvas_layer:
		canvas_layer.visible = !should_hide

func setup_normal_mapping() -> void:
	var normal_texture = load("res://assets/Prototype_Character/Prototype_Character_n.png")
	if normal_texture:
		var normal_manager = get_node("/root/NormalMappingManager")
		if normal_manager:
			normal_manager.setup_animated_sprite_normal_map($AnimatedSprite2D, normal_texture)