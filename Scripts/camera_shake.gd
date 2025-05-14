extends Camera2D

@export var decay: float = 0.8
@export var max_offset: Vector2 = Vector2(32, 24)
@export var max_roll: float = 0.1
@export var trauma_power: float = 2.0
@export var noise_frequency: float = 0.3
@export var noise_octaves: int = 3
@export var max_trauma: float = 1.0
@export var time_scale: float = 5.0
@export var trauma_jitter_reduction: bool = true

@export var impact_max_offset: Vector2 = Vector2(40, 40)
@export var impact_decay: float = 2.0
@export var impact_direction_influence: float = 0.8

@export var edge_push_threshold: float = 0.3
@export var edge_push_strength: float = 0.4
@export var edge_push_padding: Vector2 = Vector2(100, 100)

@export var follow_smoothing: float = 10.0
@export var focus_speed: float = 0.2
@export var default_zoom: Vector2 = Vector2(1, 1)
@export var target: Node2D

var current_offset: Vector2 = Vector2.ZERO
var current_rotation: float = 0.0
var trauma: float = 0.0
var noise_y: float = 0.0
var noise: FastNoiseLite = FastNoiseLite.new()
var target_position: Vector2 = Vector2.ZERO
var target_zoom: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var original_rotation: float = 0.0
var impact_trauma: float = 0.0
var impact_direction: Vector2 = Vector2.ZERO
var edge_push_factor: float = 0.0
var last_shake_time: int = 0
var secondary_targets: Array = []
var cinematic_letterbox_rects: Array = []
var is_reset_focus_in_progress: bool = false

func _ready():
	noise.seed = randi()
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves
	
	target_zoom = default_zoom
	position_smoothing_enabled = true
	position_smoothing_speed = follow_smoothing
	drag_horizontal_enabled = true
	drag_vertical_enabled = true
	drag_horizontal_offset = 0.0
	drag_vertical_offset = 0.0
	original_position = position
	original_rotation = rotation

	SignalBus.connect("explosion_occurred", Callable(self, "add_trauma_from_explosion"))
	SignalBus.connect("player_damaged", Callable(self, "add_trauma_from_damage"))
	SignalBus.connect("gunshot_fired", Callable(self, "add_trauma_from_gunshot"))
	SignalBus.connect("glass_broken", Callable(self, "add_trauma_from_glass"))
	SignalBus.connect("camera_effect_started", Callable(self, "on_camera_effect"))

func _process(delta):
	if trauma > 0:
		trauma = max(trauma - decay * delta, 0)
		shake(delta)
	
	if trauma <= 0 and offset != Vector2.ZERO:
		offset = lerp(offset, Vector2.ZERO, min(10 * delta, 1.0))
		rotation = lerp(rotation, 0.0, min(10 * delta, 1.0))
	
	if impact_trauma > 0:
		impact_trauma = max(impact_trauma - impact_decay * delta, 0)
		apply_impact_shake()
	
	process_camera_targets(delta)
	process_edge_push(delta)
	
	if trauma_jitter_reduction:
		offset = lerp(offset, current_offset, 0.5)
		rotation = lerp(rotation, current_rotation, 0.5)
	else:
		offset = current_offset
		rotation = current_rotation

func add_trauma(amount):
	trauma = min(trauma + amount, max_trauma)
	last_shake_time = Time.get_ticks_msec()

func add_trauma_from_explosion(pos, size, _damage_radius):
	var camera_position = global_position if self else Vector2.ZERO
	var distance = pos.distance_to(camera_position)
	var distance_factor = clamp(1.0 - distance / 1000.0, 0.0, 1.0)
	
	var trauma_amount = 0.3 * size * distance_factor
	add_trauma(trauma_amount)

func add_trauma_from_damage(damage_amount, _attacker_position):
	var trauma_amount = 0.2 * (damage_amount / 10.0)
	add_trauma(trauma_amount)

func add_trauma_from_gunshot(pos, _direction, weapon_type):
	var camera_position = global_position if self else Vector2.ZERO
	var distance = pos.distance_to(camera_position)
	var distance_factor = clamp(1.0 - distance / 500.0, 0.0, 1.0)
	
	var weapon_factor = 1.0
	if weapon_type == "pistol":
		weapon_factor = 0.5
	elif weapon_type == "shotgun":
		weapon_factor = 1.5
	elif weapon_type == "rifle":
		weapon_factor = 1.0
	
	var trauma_amount = 0.15 * weapon_factor * distance_factor
	add_trauma(trauma_amount)

func add_trauma_from_glass(pos, force):
	var camera_position = global_position if self else Vector2.ZERO
	var distance = pos.distance_to(camera_position)
	var distance_factor = clamp(1.0 - distance / 300.0, 0.0, 1.0)
	
	var trauma_amount = 0.1 * force * distance_factor
	add_trauma(trauma_amount)

func on_camera_effect(effect_name):
	match effect_name:
		"explosion_shake":
			add_trauma(0.6)
		"heartbeat":
			heart_beat_effect()

func shake(delta):
	if trauma <= 0:
		return
		
	noise_y += delta * time_scale
	
	var amount = pow(trauma, trauma_power)
	var rotation_amount = max_roll * amount * noise.get_noise_2d(1, noise_y)
	
	var offset_x = max_offset.x * amount * noise.get_noise_2d(noise_y, 0)
	var offset_y = max_offset.y * amount * noise.get_noise_2d(0, noise_y)
	
	offset = Vector2(offset_x, offset_y)
	rotation = rotation_amount

func heart_beat_effect():
	var original_trauma = trauma
	trauma = 0.0
	
	var tween = create_tween()
	tween.tween_property(self, "trauma", 0.4, 0.15)
	tween.tween_property(self, "trauma", 0.0, 0.25)
	tween.tween_interval(0.3)
	tween.tween_property(self, "trauma", 0.3, 0.15)
	tween.tween_property(self, "trauma", original_trauma, 0.25)

func add_impact_trauma(amount, direction = Vector2.ZERO):
	impact_trauma = min(impact_trauma + amount, 1.0)
	impact_direction = direction.normalized()

func add_secondary_target(tar, weight = 0.5):
	if !secondary_targets.has({"node": tar, "weight": weight}):
		secondary_targets.append({"node": tar, "weight": weight})

func remove_secondary_target(tar):
	for i in range(secondary_targets.size() - 1, -1, -1):
		if secondary_targets[i].node == tar:
			secondary_targets.remove_at(i)

func clear_secondary_targets():
	secondary_targets.clear()

func get_target() -> Node2D:
	return target

func apply_trauma_shake():
	var amount = pow(trauma, trauma_power)
	noise_y += 1
	
	var noise_roll = snappedf(noise.get_noise_2d(noise.seed, noise_y), 0.01)
	var noise_x = snappedf(noise.get_noise_2d(noise.seed * 2, noise_y), 0.01)
	var noise_y_val = snappedf(noise.get_noise_2d(noise.seed * 3, noise_y), 0.01)
	
	current_rotation = max_roll * amount * noise_roll
	current_offset.x = max_offset.x * amount * noise_x
	current_offset.y = max_offset.y * amount * noise_y_val

func apply_impact_shake():
	var amount = impact_trauma * impact_trauma
	
	var noise_x = snappedf(noise.get_noise_2d(noise.seed * 4, noise_y), 0.01)
	var noise_y_val = snappedf(noise.get_noise_2d(noise.seed * 5, noise_y), 0.01)
	
	var random_offset = Vector2(
		impact_max_offset.x * amount * noise_x,
		impact_max_offset.y * amount * noise_y_val
	)
	
	var direction_offset = impact_direction * impact_max_offset * amount * impact_direction_influence
	current_offset += random_offset + direction_offset

func process_camera_targets(delta):
	if get_target() != null:
		var main_target = get_target()
		var main_target_pos = main_target.global_position
		target_position = main_target_pos
		
		if secondary_targets.size() > 0:
			var total_weight = 1.0
			var weighted_position = main_target_pos
			
			for target_data in secondary_targets:
				if is_instance_valid(target_data.node):
					weighted_position += target_data.node.global_position * target_data.weight
					total_weight += target_data.weight
			
			target_position = weighted_position / total_weight
		
		if secondary_targets.size() > 0:
			var max_distance = 0.0
			var avg_position = target_position
			
			for target_data in secondary_targets:
				if is_instance_valid(target_data.node):
					var distance = target_data.node.global_position.distance_to(avg_position)
					max_distance = max(max_distance, distance)
			
			var distance_scale = snappedf(clamp(max_distance / 500.0, 0.0, 1.0), 0.01)
			target_zoom = default_zoom.lerp(default_zoom * 1.5, distance_scale)
		else:
			target_zoom = default_zoom
		
		zoom = zoom.lerp(target_zoom, min(focus_speed * delta * 10, 1.0))

func process_edge_push(delta):
	if !is_instance_valid(target) or secondary_targets.size() == 0:
		return
	
	var viewport_size = get_viewport_rect().size
	var camera_center = global_position
	var edge_threshold = viewport_size * edge_push_threshold
	
	var closest_distance = INF
	var closest_direction = Vector2.ZERO
	
	for target_data in secondary_targets:
		if !is_instance_valid(target_data.node):
			continue
			
		var target_pos = target_data.node.global_position
		var screen_pos = (target_pos - camera_center) * zoom + viewport_size / 2
		
		if screen_pos.x < edge_threshold.x:
			var distance = edge_threshold.x - screen_pos.x
			if distance < closest_distance:
				closest_distance = distance
				closest_direction = Vector2.LEFT
		elif screen_pos.x > viewport_size.x - edge_threshold.x:
			var distance = screen_pos.x - (viewport_size.x - edge_threshold.x)
			if distance < closest_distance:
				closest_distance = distance
				closest_direction = Vector2.RIGHT
				
		if screen_pos.y < edge_threshold.y:
			var distance = edge_threshold.y - screen_pos.y
			if distance < closest_distance:
				closest_distance = distance
				closest_direction = Vector2.UP
		elif screen_pos.y > viewport_size.y - edge_threshold.y:
			var distance = screen_pos.y - (viewport_size.y - edge_threshold.y)
			if distance < closest_distance:
				closest_distance = distance
				closest_direction = Vector2.DOWN
	
	if closest_distance < INF:
		var edge_factor = snappedf(clamp(closest_distance / edge_threshold.x, 0.0, 1.0), 0.01)
		var push_offset = closest_direction * edge_push_strength * edge_factor
		offset += push_offset * delta * 10

func add_cinematic_letterbox():
	if cinematic_letterbox_rects.size() > 0:
		return
	
	var viewport_size = get_viewport_rect().size
	var letterbox_height = viewport_size.y * 0.1
	
	for i in range(2):
		var letterbox = ColorRect.new()
		letterbox.color = Color(0, 0, 0, 1)
		
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100
		add_child(canvas_layer)
		canvas_layer.add_child(letterbox)
		
		letterbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		if i == 0:
			letterbox.set_size(Vector2(viewport_size.x, letterbox_height))
			letterbox.position = Vector2(0, 0)
		else:
			letterbox.set_size(Vector2(viewport_size.x, letterbox_height))
			letterbox.position = Vector2(0, viewport_size.y - letterbox_height)
		
		cinematic_letterbox_rects.append(letterbox)

func remove_cinematic_letterbox():
	for rect in cinematic_letterbox_rects:
		if is_instance_valid(rect) and rect.get_parent() and rect.get_parent().get_parent() == self:
			rect.get_parent().queue_free()
	
	cinematic_letterbox_rects.clear()

func focus_on_target(focus_target: Node2D, duration: float = 1.0):
	if !is_instance_valid(focus_target):
		return
	
	var original_target = target
	var focus_tween = create_tween()
	focus_tween.set_parallel(true)
	
	target = focus_target
	add_secondary_target(original_target, 0.0)
	
	focus_tween.tween_property(self, "zoom", zoom * 0.7, duration).set_ease(Tween.EASE_IN_OUT)
	focus_tween.tween_property(self, "position_smoothing_speed", 2.0, duration * 0.5)
	
	await focus_tween.finished
	position_smoothing_speed = 2.0

func reset_focus(duration: float = 1.0):
	if is_reset_focus_in_progress:
		return
		
	is_reset_focus_in_progress = true
	
	var _original_zoom = zoom
	var reset_tween = create_tween()
	reset_tween.set_parallel(true)
	
	if secondary_targets.size() > 0 and is_instance_valid(secondary_targets[0].node):
		target = secondary_targets[0].node
		secondary_targets.clear()
	
	reset_tween.tween_property(self, "zoom", default_zoom, duration).set_ease(Tween.EASE_IN_OUT)
	reset_tween.tween_property(self, "position_smoothing_speed", follow_smoothing, duration * 0.5)
	
	await reset_tween.finished
	position_smoothing_speed = follow_smoothing
	is_reset_focus_in_progress = false
