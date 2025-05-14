extends "res://Scripts/light_base.gd"
class_name DirectionalLightNode

@export_category("Directional Light Settings")
@export var height: float = 0.0
@export var initial_rotation: float = 0.0
@export var blend_mode: int = 0
@export var shadow_filter_quality: int = 1

@export_category("Rotation Settings")
@export var auto_rotate: bool = false
@export var rotation_speed: float = 10.0
@export var follow_target_path: NodePath

var light_node: DirectionalLight2D
var follow_target = null

func _ready():
	setup_light()
	
	if not follow_target_path.is_empty():
		follow_target = get_node_or_null(follow_target_path)
		
	super._ready()

func _process(delta):
	super._process(delta)
	
	if auto_rotate and light_enabled:
		rotation_degrees = fmod(rotation_degrees + rotation_speed * delta, 360.0)
		light_node.rotation_degrees = rotation_degrees
	
	if follow_target and is_instance_valid(follow_target):
		update_follow_rotation()

func setup_light():
	light_node = DirectionalLight2D.new()
	light_node.height = height
	light_node.energy = 0.0 if not light_enabled else base_energy
	light_node.shadow_enabled = shadow_enabled
	light_node.shadow_filter = shadow_filter_quality
	light_node.shadow_filter_smooth = 3.0
	light_node.shadow_color = Color(0, 0, 0, shadow_strength)
	light_node.color = base_color
	light_node.blend_mode = blend_mode
	rotation_degrees = initial_rotation
	light_node.rotation_degrees = initial_rotation
	
	add_child(light_node)

func update_follow_rotation():
	if follow_target:
		var direction = follow_target.global_position - global_position
		light_node.rotation = direction.angle()

func apply_effect():
	var effect_value = 0.0
	
	match effect_type:
		"pulse":
			effect_value = (sin(time_passed) + 1.0) * 0.5
			var energy_mod = 1.0 + (effect_value * effect_intensity)
			light_node.energy = base_energy * energy_mod * current_energy_mod
			
		"sway":
			effect_value = sin(time_passed) * effect_intensity * 30.0
			light_node.rotation_degrees = rotation_degrees + effect_value

func apply_modulation(modulation: Color, intensity_modifier: float):
	light_node.color = base_color * modulation
	
	if not effect_enabled:
		light_node.energy = base_energy * intensity_modifier

func apply_enabled_state(enabled: bool):
	light_node.energy = base_energy * current_energy_mod if enabled else 0.0
	
func set_shadow_enabled(enabled: bool):
	shadow_enabled = enabled
	light_node.shadow_enabled = enabled 