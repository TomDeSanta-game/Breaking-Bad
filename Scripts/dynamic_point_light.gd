extends PointLight2D

@export_category("Light Settings")
@export var light_enabled: bool = true
@export var base_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var base_energy: float = 1.0
@export var shadow_strength: float = 1.0

@export_category("Flicker Effect")
@export var flicker_enabled: bool = false
@export var flicker_speed: float = 10.0
@export var flicker_intensity: float = 0.2
@export var flicker_noise_texture: NoiseTexture2D
@export var use_perlin_noise: bool = true

@export_category("Dynamic Lighting Integration")
@export var register_with_system: bool = true
@export var affected_by_time: bool = true
@export var affected_by_weather: bool = true

var flicker_time: float = 0.0
var flicker_value: float = 0.0
var lighting_system = null
var signal_bus = null
var is_registered: bool = false
var current_modulation: Color = Color(1.0, 1.0, 1.0, 1.0)
var current_energy_mod: float = 1.0
var noise_offset = Vector2(0, 0)

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")

	var lighting_node = get_node_or_null("/root/DynamicLighting")
	if lighting_node:
		lighting_system = lighting_node.get_lighting_system()
	
	if lighting_system and register_with_system:
		register_with_lighting_system()
	
	if not light_enabled:
		energy = 0
	
	shadow_enabled = shadow_strength > 0.01
	shadow_filter = 2
	shadow_filter_smooth = 2.0
	
	if not flicker_noise_texture and use_perlin_noise:
		create_noise_texture()

func _process(delta):
	if flicker_enabled and light_enabled:
		update_flicker(delta)

func update_flicker(delta):
	flicker_time += delta * flicker_speed
	
	if use_perlin_noise and flicker_noise_texture:
		noise_offset.x = flicker_time * 0.1
		noise_offset.y = sin(flicker_time * 0.2) * 0.5
		var noise_val = flicker_noise_texture.noise.get_noise_2d(noise_offset.x, noise_offset.y)
		flicker_value = (noise_val + 1.0) * 0.5
	else:
		flicker_value = randf()
	
	var energy_mod = 1.0 + ((flicker_value * 2.0 - 1.0) * flicker_intensity)
	energy = base_energy * energy_mod * current_energy_mod

func create_noise_texture():
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.5
	noise.fractal_octaves = 2
	
	flicker_noise_texture = NoiseTexture2D.new()
	flicker_noise_texture.noise = noise
	flicker_noise_texture.width = 256
	flicker_noise_texture.height = 256

func update_light(modulation: Color, intensity_modifier: float):
	current_modulation = modulation
	current_energy_mod = intensity_modifier
	
	if light_enabled:
		color = base_color * modulation
		if not flicker_enabled:
			energy = base_energy * intensity_modifier
	
	if signal_bus:
		signal_bus.emit_signal("light_updated", self, color, energy)

func set_light_enabled(e: bool):
	light_enabled = e
	if not e:
		energy = 0
	else:
		energy = base_energy * current_energy_mod
		if flicker_enabled:
			update_flicker(0.016)

func set_flicker_enabled(e: bool):
	flicker_enabled = e
	if not flicker_enabled and light_enabled:
		energy = base_energy * current_energy_mod

func register_with_lighting_system():
	if lighting_system and not is_registered:
		lighting_system.register_light(self)
		is_registered = true

func _exit_tree():
	if lighting_system and is_registered:
		lighting_system.unregister_light(self) 
