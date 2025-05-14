extends CharacterBody2D

@export var max_speed: float = 100.0
@export var acceleration: float = 1000.0
@export var friction: float = 1000.0
@export var sprint_multiplier: float = 1.5
@export var starting_health: float = 100.0
@export var damage_cooldown: float = 1.0
@export var max_heat_level: float = 100.0
@export var heat_decay_rate: float = 0.5
@export var momentum_strength: float = 0.3
@export var acceleration_curve: float = 0.3
@export var deceleration_curve: float = 0.2
@export var turn_responsiveness: float = 1.2
@export var pixel_snapping: bool = true
@export var snap_threshold: float = 3.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.5
@export var dash_strength: float = 2.5
@export var max_stamina: float = 100.0
@export var stamina_decay_rate: float = 15.0
@export var stamina_recovery_rate: float = 10.0
@export var stamina_sprint_threshold: float = 10.0
@export var slow_motion_duration: float = 4.0
@export var slow_motion_cooldown: float = 10.0
@export var slow_motion_strength: float = 0.3
@export var slow_motion_stamina_cost: float = 30.0
@export var interaction_distance: float = 50.0
@export_flags_2d_physics var interaction_mask: int = 0

var current_health: float = starting_health
var can_be_damaged: bool = true
var damage_timer: Timer = null

var desired_velocity: Vector2 = Vector2.ZERO
var momentum: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.RIGHT
var is_sprinting: bool = false
var active_speed: float = 0.0
var speed_modifier: float = 1.0

var heat_level: float = 0.0
var current_stamina: float = max_stamina
var can_sprint: bool = true

var is_hiding: bool = false
var in_interaction_area: bool = false
var current_interactable: Node2D = null
var nearest_interactables: Array[Node2D] = []

var can_dash: bool = true
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

var slow_motion_active: bool = false
var slow_motion_timer: float = 0.0
var slow_motion_cooldown_timer: float = 0.0
var can_use_slow_motion: bool = true
var slow_motion_tween: Tween = null

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
	DASHING,
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
@onready var heat_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/HeatBar
@onready var stam_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/StaminaBar

func _ready() -> void:
	hud.show()

	current_health = starting_health
	current_stamina = max_stamina
	active_speed = max_speed
	
	damage_timer = Timer.new()
	damage_timer.one_shot = true
	damage_timer.wait_time = damage_cooldown
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)
	
	if interaction_ray:
		interaction_ray.collision_mask = interaction_mask
		interaction_ray.target_position = Vector2(interaction_distance, 0)
	
	SignalBus.health_changed.emit(current_health, starting_health)
	SignalBus.heat_changed.emit(heat_level, max_heat_level)
	SignalBus.stamina_changed.emit(current_stamina, max_stamina)
	set_state(PlayerState.IDLE)

func _physics_process(delta: float) -> void:
	handle_input()
	handle_dash(delta)
	handle_slow_motion(delta)
	handle_movement(delta)
	handle_stamina(delta)
	update_interaction_ray()
	apply_pixel_perfect_movement()
	handle_animation()
	move_and_slide()
	
	if heat_level > 0:
		reduce_heat(heat_decay_rate * delta)
	
	update_damaged_body_parts(delta)

func handle_input() -> void:
	direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").normalized()
	is_sprinting = Input.is_action_pressed("Sprint") and can_sprint
	
	if Input.is_action_just_pressed("slow_motion") and can_use_slow_motion and not slow_motion_active and current_stamina >= slow_motion_stamina_cost:
		activate_slow_motion()
	
	if Input.is_action_just_pressed("Interact"):
		if can_dash and not is_dashing:
			initiate_dash()
		else:
			handle_interaction()

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
				max_speed = max(max_speed * 0.6, 40.0)
				SignalBus.threshold_crossed.emit("leg_injury", "above", 0.5, severity)
			elif severity > 0.2:
				max_speed = max(max_speed * 0.8, 60.0)
				SignalBus.threshold_crossed.emit("leg_injury", "above", 0.2, severity)
		"left_arm", "right_arm":
			if severity > 0.5:
				acceleration = max(acceleration * 0.7, 500.0)
				SignalBus.threshold_crossed.emit("arm_injury", "above", 0.5, severity)
			elif severity > 0.2:
				acceleration = max(acceleration * 0.85, 700.0)
				SignalBus.threshold_crossed.emit("arm_injury", "above", 0.2, severity)

func handle_stamina(delta: float) -> void:
	if is_sprinting and direction.length() > 0.1:
		current_stamina = max(0.0, current_stamina - stamina_decay_rate * delta)
		if current_stamina <= stamina_sprint_threshold:
			can_sprint = false
			SignalBus.threshold_crossed.emit("stamina", "below", stamina_sprint_threshold, current_stamina)
	else:
		current_stamina = min(max_stamina, current_stamina + stamina_recovery_rate * delta)
		if current_stamina > stamina_sprint_threshold and not can_sprint:
			can_sprint = true
			SignalBus.threshold_crossed.emit("stamina", "above", stamina_sprint_threshold, current_stamina)
	
	SignalBus.stamina_changed.emit(current_stamina, max_stamina)

func handle_slow_motion(delta: float) -> void:
	if slow_motion_active:
		slow_motion_timer -= delta
		if slow_motion_timer <= 0:
			deactivate_slow_motion()
	
	if slow_motion_cooldown_timer > 0:
		slow_motion_cooldown_timer -= delta
		if slow_motion_cooldown_timer <= 0:
			can_use_slow_motion = true

func activate_slow_motion() -> void:
	if slow_motion_tween:
		slow_motion_tween.kill()
	
	slow_motion_active = true
	can_use_slow_motion = false
	slow_motion_timer = slow_motion_duration
	current_stamina -= slow_motion_stamina_cost
	SignalBus.stamina_changed.emit(current_stamina, max_stamina)
	
	slow_motion_tween = create_tween()
	slow_motion_tween.set_ease(Tween.EASE_OUT)
	slow_motion_tween.set_trans(Tween.TRANS_SINE)
	slow_motion_tween.tween_property(Engine, "time_scale", slow_motion_strength, 0.2)
	
	SignalBus.time_effect_started.emit("slow_motion", slow_motion_strength)
	SignalBus.camera_effect_started.emit("slow_motion_start")

func deactivate_slow_motion() -> void:
	if slow_motion_tween:
		slow_motion_tween.kill()
	
	slow_motion_active = false
	slow_motion_cooldown_timer = slow_motion_cooldown
	
	slow_motion_tween = create_tween()
	slow_motion_tween.set_ease(Tween.EASE_IN)
	slow_motion_tween.set_trans(Tween.TRANS_SINE)
	slow_motion_tween.tween_property(Engine, "time_scale", 1.0, 0.2)
	
	SignalBus.time_effect_ended.emit("slow_motion")
	SignalBus.camera_effect_started.emit("slow_motion_end")

func handle_dash(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			speed_modifier = 1.0
			set_state(calculate_state())
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true

func initiate_dash() -> void:
	is_dashing = true
	can_dash = false
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	dash_direction = direction if direction.length() > 0.1 else last_direction
	speed_modifier = dash_strength
	
	set_state(PlayerState.DASHING)
	SignalBus.vfx_started.emit("dash", global_position)
	SignalBus.camera_effect_started.emit("dash_shake")

func handle_movement(delta: float) -> void:
	if direction.length() > 0.1:
		last_direction = direction
	
	active_speed = max_speed * ((sprint_multiplier if is_sprinting else 1.0) * speed_modifier)
	
	if is_dashing:
		desired_velocity = dash_direction * active_speed
	else:
		desired_velocity = direction * active_speed
	
	if direction.length() > 0.1:
		var acceleration_weight = turn_responsiveness
		
		if direction.dot(velocity.normalized()) < -0.5 and velocity.length() > max_speed * 0.8:
			acceleration_weight *= 2.0
		
		velocity = velocity.lerp(desired_velocity, acceleration_curve * acceleration_weight * delta * acceleration / max_speed)
		
		momentum = momentum.lerp(direction * momentum_strength, 0.1)
		
		if not is_dashing:
			if is_sprinting and current_state != PlayerState.RUNNING:
				set_state(PlayerState.RUNNING)
			elif not is_sprinting and current_state != PlayerState.WALKING:
				set_state(PlayerState.WALKING)
	else:
		if velocity.length() > 10.0:
			velocity = velocity.lerp(Vector2.ZERO, deceleration_curve * delta * friction / max_speed)
		else:
			velocity = Vector2.ZERO
			momentum = momentum.lerp(Vector2.ZERO, 0.2)
			
			if current_state != PlayerState.INTERACTING and current_state != PlayerState.HIDING and current_state != PlayerState.INJURED:
				set_state(PlayerState.IDLE)
	
	if not is_dashing:
		velocity += momentum * max_speed

func apply_pixel_perfect_movement() -> void:
	if pixel_snapping and velocity.length() < max_speed * 0.3:
		var pixel_size = 1.0
		
		var target_position = global_position + velocity
		var snapped_position = Vector2(
			round(target_position.x / pixel_size) * pixel_size,
			round(target_position.y / pixel_size) * pixel_size
		)
		
		if target_position.distance_to(snapped_position) < snap_threshold:
			velocity = (snapped_position - global_position) * 0.8

func handle_animation() -> void:
	if not sprite:
		return
	
	var direction_prefix = "Right"
	if abs(direction.y) > abs(direction.x) and direction.y < 0:
		direction_prefix = "Up"
	elif abs(direction.y) > abs(direction.x) and direction.y > 0:
		direction_prefix = "Down"
	
	if is_dashing:
		sprite.play(direction_prefix + "_Run")
		sprite.speed_scale = 1.5
	elif velocity.length() > max_speed * 0.1:
		var speed_percent = velocity.length() / max_speed
		sprite.play(direction_prefix + "_Run")
		sprite.speed_scale = lerp(0.8, 1.5, speed_percent)
	else:
		sprite.play(direction_prefix + "_Idle")
		sprite.speed_scale = 1.0
	
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

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
	
	if slow_motion_active:
		deactivate_slow_motion()
	
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
		PlayerState.DASHING: state_name = "dashing"
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
	elif velocity.length() > max_speed * 0.8 and is_sprinting:
		return PlayerState.RUNNING
	elif velocity.length() > max_speed * 0.1:
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