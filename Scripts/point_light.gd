extends "res://Scripts/light_base.gd"
class_name PointLightNode

@export_category("Point Light Settings")
@export var texture_scale: float = 1.0
@export var shadow_filter_quality: int = 1
@export var light_texture: Texture2D

@export_category("Preset Types")
@export var light_preset: String = "DEFAULT"

var light_node: PointLight2D
var original_scale: float = 1.0
var flicker_generator = null
var noise_texture = null

const PRESETS = {
	"DEFAULT": {},
	"CANDLE": {
		"base_color": Color(1.0, 0.8, 0.5),
		"base_energy": 0.8,
		"texture_scale": 1.0,
		"effect_enabled": true,
		"effect_type": "flicker",
		"effect_speed": 3.0,
		"effect_intensity": 0.2
	},
	"FLUORESCENT": {
		"base_color": Color(0.9, 0.95, 1.0),
		"base_energy": 0.9,
		"texture_scale": 1.5,
		"effect_enabled": true,
		"effect_type": "flicker",
		"effect_speed": 10.0,
		"effect_intensity": 0.05
	},
	"INCANDESCENT": {
		"base_color": Color(1.0, 0.95, 0.8),
		"base_energy": 1.0,
		"texture_scale": 1.2
	},
	"EMERGENCY": {
		"base_color": Color(1.0, 0.2, 0.2),
		"base_energy": 0.6,
		"texture_scale": 1.0,
		"effect_enabled": true,
		"effect_type": "pulse",
		"effect_speed": 2.0,
		"effect_intensity": 0.3
	}
}

func _ready():
	apply_preset()
	setup_light()
	super._ready()

func setup_light():
	light_node = PointLight2D.new()
	light_node.texture = light_texture
	light_node.texture_scale = texture_scale
	light_node.energy = 0.0 if not light_enabled else base_energy
	light_node.shadow_enabled = shadow_enabled
	light_node.shadow_filter = shadow_filter_quality
	light_node.shadow_filter_smooth = 3.0
	light_node.color = base_color
	
	original_scale = texture_scale
	
	if not light_texture:
		create_default_texture()
	
	add_child(light_node)
	
	if effect_type == "flicker" or effect_type == "noise":
		setup_noise_texture()

func create_default_texture():
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.width = 256
	gradient_texture.height = 256
	
	light_texture = gradient_texture
	light_node.texture = light_texture

func setup_noise_texture():
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.5
	noise.fractal_octaves = 2
	
	noise_texture = NoiseTexture2D.new()
	noise_texture.noise = noise
	noise_texture.width = 256
	noise_texture.height = 256

func apply_preset():
	if light_preset != "DEFAULT" and PRESETS.has(light_preset):
		var preset = PRESETS[light_preset]
		
		if preset.has("base_color"):
			base_color = preset.base_color
			
		if preset.has("base_energy"):
			base_energy = preset.base_energy
			
		if preset.has("texture_scale"):
			texture_scale = preset.texture_scale
			
		if preset.has("effect_enabled"):
			effect_enabled = preset.effect_enabled
			
		if preset.has("effect_type"):
			effect_type = preset.effect_type
			
		if preset.has("effect_speed"):
			effect_speed = preset.effect_speed
			
		if preset.has("effect_intensity"):
			effect_intensity = preset.effect_intensity

func apply_effect():
	var effect_value = 0.0
	
	match effect_type:
		"flicker":
			if noise_texture:
				var noise_offset = Vector2(time_passed * 0.1, sin(time_passed * 0.2) * 0.5)
				var noise_val = noise_texture.noise.get_noise_2d(noise_offset.x, noise_offset.y)
				effect_value = (noise_val + 1.0) * 0.5
			else:
				effect_value = randf()
			
			var energy_mod = 1.0 + ((effect_value * 2.0 - 1.0) * effect_intensity)
			light_node.energy = base_energy * energy_mod * current_energy_mod
			
		"pulse":
			effect_value = (sin(time_passed) + 1.0) * 0.5
			var energy_mod = 1.0 + (effect_value * effect_intensity)
			light_node.energy = base_energy * energy_mod * current_energy_mod
			
		"breathe":
			effect_value = (sin(time_passed * 0.5) + 1.0) * 0.5
			var energy_mod = 0.7 + (effect_value * effect_intensity * 2.0)
			light_node.energy = base_energy * energy_mod * current_energy_mod
			var scale_mod = 0.8 + (effect_value * effect_intensity)
			light_node.texture_scale = original_scale * scale_mod

func apply_modulation(modulation: Color, intensity_modifier: float):
	light_node.color = base_color * modulation
	
	if not effect_enabled:
		light_node.energy = base_energy * intensity_modifier

func apply_enabled_state(enabled: bool):
	light_node.energy = base_energy * current_energy_mod if enabled else 0.0
	
func set_shadow_enabled(enabled: bool):
	shadow_enabled = enabled
	light_node.shadow_enabled = enabled 