extends PointLight2D

@export_category("Area Light Settings")
@export var light_enabled: bool = true
@export var base_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var base_energy: float = 1.0
@export var base_texture_scale: float = 1.0
@export var apply_global_modulation: bool = true
@export var falloff_distance: float = 200.0
@export var ambient_contribution: float = 0.2
@export var shadow_strength: float = 0.5

@export_category("Atmosphere Settings")
@export var dust_particles_enabled: bool = false
@export var dust_density: float = 0.2
@export var dust_color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var dust_speed: float = 0.3
@export var dust_scale: float = 1.0

@export_category("Animation Settings")
@export var animation_enabled: bool = false
@export var animation_type: String = "none"
@export var animation_speed: float = 1.0
@export var animation_intensity: float = 0.1

var original_scale: float
var time_passed: float = 0.0
var lighting_system = null
var signal_bus = null
var is_registered: bool = false
var current_modulation: Color = Color(1.0, 1.0, 1.0, 1.0)
var current_energy_mod: float = 1.0
var dust_particles = null

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")
	original_scale = texture_scale
	
	var lighting_node = get_node_or_null("/root/DynamicLighting")
	if lighting_node:
		lighting_system = lighting_node.get_lighting_system()
	
	if lighting_system and apply_global_modulation:
		register_with_lighting_system()
	
	if not light_enabled:
		energy = 0
	
	shadow_enabled = shadow_strength > 0.01
	shadow_filter = 3
	shadow_filter_smooth = 5.0
	
	update_light_properties()
	if dust_particles_enabled:
		setup_dust_particles()

func _process(delta):
	if animation_enabled and light_enabled:
		time_passed += delta * animation_speed
		apply_animation_effect()

func setup_dust_particles():
	dust_particles = CPUParticles2D.new()
	dust_particles.amount = 50 * dust_density
	dust_particles.lifetime = 3.0
	dust_particles.explosiveness = 0.05
	dust_particles.randomness = 0.8
	dust_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dust_particles.emission_sphere_radius = texture_scale * 0.8
	dust_particles.gravity = Vector2(0, -5 * dust_speed)
	dust_particles.initial_velocity_min = 5.0 * dust_speed
	dust_particles.initial_velocity_max = 10.0 * dust_speed
	dust_particles.scale_amount_min = 0.5 * dust_scale
	dust_particles.scale_amount_max = 1.5 * dust_scale
	dust_particles.modulate = dust_color
	add_child(dust_particles)
	dust_particles.emitting = light_enabled

func apply_animation_effect():
	var animation_value = 0.0
	
	match animation_type:
		"breathe":
			animation_value = (sin(time_passed) + 1.0) * 0.5
		"throb":
			animation_value = (sin(time_passed * 2.0) + 1.0) * 0.5
		"flicker":
			animation_value = randf() * 2.0 - 1.0
		"wave":
			animation_value = sin(time_passed) * cos(time_passed * 0.5)
		_:
			return
	
	var energy_mod = 1.0 + (animation_value * animation_intensity)
	energy = base_energy * energy_mod * current_energy_mod
	
	if animation_type == "wave":
		var scale_mod = 1.0 + (animation_value * animation_intensity * 0.2)
		texture_scale = original_scale * base_texture_scale * scale_mod

func update_light(modulation: Color, intensity_modifier: float):
	current_modulation = modulation
	current_energy_mod = intensity_modifier
	
	if light_enabled:
		color = base_color * modulation
		energy = base_energy * intensity_modifier
		
		if dust_particles:
			dust_particles.modulate = dust_color * modulation
		
		update_light_properties()
	
	if signal_bus:
		signal_bus.emit_signal("light_updated", self, color, energy)

func update_light_properties():
	texture_scale = original_scale * base_texture_scale
	shadow_enabled = shadow_strength > 0.01
	
	if not animation_enabled:
		energy = base_energy * current_energy_mod

func set_light_enabled(e: bool):
	light_enabled = e
	e = base_energy * current_energy_mod if e else 0.0
	
	if dust_particles:
		dust_particles.emitting = e and dust_particles_enabled

func set_animation_enabled(e: bool):
	animation_enabled = e
	update_light_properties()

func register_with_lighting_system():
	if lighting_system and not is_registered:
		lighting_system.register_light(self)
		is_registered = true

func _exit_tree():
	if lighting_system and is_registered:
		lighting_system.unregister_light(self) 
