extends DirectionalLight2D

@export_category("Spotlight Settings")
@export var light_enabled: bool = true
@export var base_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var base_energy: float = 1.0
@export var scale_factor: float = 1.0
@export var apply_global_modulation: bool = true
@export var cast_shadow: bool = true
@export var shadow_strength: float = 0.8
@export var shadow_filter_quality: int = 1

@export_category("Rotation Settings")
@export var rotation_mode: String = "static"
@export var rotation_speed: float = 1.0
@export var rotation_range: float = 90.0
@export var follow_target_path: NodePath

@export_category("Cone Settings")
@export var cone_angle: float = 45.0
@export var inner_cone_angle: float = 30.0
@export var edge_feather: float = 0.2

var original_height: float
var current_angle: float = 0.0
var target_rotation: float = 0.0
var follow_target = null
var lighting_system = null
var signal_bus = null
var is_registered: bool = false
var current_modulation: Color = Color(1.0, 1.0, 1.0, 1.0)
var current_energy_mod: float = 1.0
var cone_shape: ConvexPolygonShape2D = null

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")
	original_height = height
	
	var lighting_node = get_node_or_null("/root/DynamicLighting")
	if lighting_node:
		lighting_system = lighting_node.get_lighting_system()
	
	if lighting_system and apply_global_modulation:
		register_with_lighting_system()
	
	if not light_enabled:
		energy = 0
	
	shadow_enabled = cast_shadow
	shadow_filter = shadow_filter_quality
	shadow_filter_smooth = 5.0
	
	if not follow_target_path.is_empty():
		follow_target = get_node_or_null(follow_target_path)
	
	setup_spotlight()

func _process(delta):
	if rotation_mode != "static" and light_enabled:
		update_rotation(delta)
	
	if follow_target and is_instance_valid(follow_target):
		update_follow_rotation()

func setup_spotlight():
	max_distance = 2000.0
	blend_mode = Light2D.BLEND_MODE_ADD
	
	if cone_angle > 0:
		blend_mode = Light2D.BLEND_MODE_ADD
		shadow_enabled = cast_shadow
		shadow_strength = shadow_strength

func update_rotation(delta):
	match rotation_mode:
		"oscillate":
			current_angle += rotation_speed * delta
			rotation_degrees = sin(current_angle) * rotation_range
		"rotate":
			rotation_degrees = fmod(rotation_degrees + rotation_speed * delta, 360.0)
		"random":
			if abs(rotation_degrees - target_rotation) < 5.0:
				target_rotation = randf_range(-rotation_range, rotation_range)
			rotation_degrees = lerp(rotation_degrees, target_rotation, delta * rotation_speed)

func update_follow_rotation():
	if follow_target:
		var direction = follow_target.global_position - global_position
		rotation = direction.angle()

func update_light(modulation: Color, intensity_modifier: float):
	current_modulation = modulation
	current_energy_mod = intensity_modifier
	
	if light_enabled:
		color = base_color * modulation
		energy = base_energy * intensity_modifier
		height = original_height * scale_factor
	
	if signal_bus:
		signal_bus.emit_signal("light_updated", self, color, energy)

func set_light_enabled(e: bool):
	light_enabled = e
	energy = base_energy * current_energy_mod if e else 0.0

func set_cone_angle(angle: float):
	cone_angle = angle
	setup_spotlight()

func register_with_lighting_system():
	if lighting_system and not is_registered:
		lighting_system.register_light(self)
		is_registered = true

func _exit_tree():
	if lighting_system and is_registered:
		lighting_system.unregister_light(self) 
