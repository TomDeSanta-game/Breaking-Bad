extends Node

var post_process: Node
var particles: Node
var reflections: Node
var camera_effects: Node

var _effect_intensity_modifiers = {
	"global": 1.0,
	"tension": 0.0,
	"area": 1.0,
	"character": 0.0,
	"story": 0.0
}

# Dynamic lighting system reference
var dynamic_lighting: Node

# Environment variables
var current_environment: String = "default"
var time_of_day: float = 0.5
var weather_condition: String = "clear"

# Parallax backgrounds
var parallax_enabled: bool = true

func _ready():
	post_process = get_node_or_null("/root/UnifiedPostProcess")
	particles = get_node_or_null("/root/EnvironmentalParticles")
	reflections = get_node_or_null("/root/MaterialReflections")
	camera_effects = get_node_or_null("/root/CameraEffects")
	dynamic_lighting = get_node_or_null("/root/DynamicLighting")
	
	SignalBus.connect("tension_level_changed", Callable(self, "_on_tension_changed"))
	SignalBus.connect("environment_changed", Callable(self, "_on_area_changed"))
	SignalBus.connect("player_state_changed", Callable(self, "_on_player_state_changed"))
	SignalBus.connect("time_of_day_changed", Callable(self, "_on_time_of_day_changed"))
	SignalBus.connect("weather_changed", Callable(self, "_on_weather_changed"))

func _process(_delta):
	update_effect_intensities()

func update_effect_intensities():
	var combined_intensity = calculate_combined_intensity()
	
	if reflections:
		reflections.set_global_intensity(combined_intensity)
	
	if camera_effects:
		camera_effects.set_global_intensity(combined_intensity)

func calculate_combined_intensity() -> float:
	var base = _effect_intensity_modifiers["global"]
	var tension_factor = _effect_intensity_modifiers["tension"]
	var area_factor = _effect_intensity_modifiers["area"]
	var character_factor = _effect_intensity_modifiers["character"]
	var story_factor = _effect_intensity_modifiers["story"]
	
	return base * (1.0 + tension_factor) * area_factor * (1.0 + character_factor) * (1.0 + story_factor)

func set_global_effect_intensity(value: float):
	_effect_intensity_modifiers["global"] = clamp(value, 0.0, 1.0)

# Basic Post Processing Effects
func set_vignette(intensity: float, opacity: float, color: Color = Color(0.0, 0.0, 0.0, 1.0)):
	if post_process:
		post_process.set_vignette(intensity, opacity, color)

func set_film_grain(amount: float, size: float, speed: float):
	if post_process:
		post_process.set_film_grain(amount, size, speed)

func set_chromatic_aberration(amount: float, enabled: bool = true):
	if post_process:
		post_process.set_chromatic_aberration(amount, enabled)

func set_heat_distortion(amount: float, speed: float, center: Vector2, radius: float):
	if post_process:
		post_process.set_heat_distortion(amount, speed, center, radius)

func set_depth_of_field(blend: float, depth_range: float):
	if post_process:
		post_process.set_depth_of_field(blend, depth_range)

# New Visual Enhancement Features
func set_palette_shifting(enabled: bool, location: String = ""):
	if post_process:
		if location.is_empty():
			location = current_environment
			
		match location:
			"desert":
				post_process.apply_desert_palette()
			"lab":
				post_process.apply_lab_palette()
			"home":
				post_process.apply_home_palette()
			_:
				post_process.set_palette_shifting(enabled, 
					Color(0.1, 0.1, 0.1, 1.0),
					Color(0.5, 0.5, 0.5, 1.0),
					Color(0.9, 0.9, 0.9, 1.0),
					0.5)

func set_bloom_effect(enabled: bool, intensity: float = 0.3, threshold: float = 0.7):
	if post_process:
		post_process.set_bloom(enabled, intensity, threshold)

func set_dithering_effect(enabled: bool, intensity: float = 0.1, scale: float = 1.0):
	if post_process:
		post_process.set_dithering(enabled, intensity, scale)

func set_pixel_perfect_outlines(enabled: bool, thickness: float = 1.0, 
								color: Color = Color(0.0, 0.0, 0.0, 1.0), 
								threshold: float = 0.1):
	if post_process:
		post_process.set_pixel_perfect_outlines(enabled, thickness, color, threshold)

func set_crt_effect(enabled: bool, curvature: float = 0.1, 
					scanline_intensity: float = 0.5, 
					brightness: float = 1.2):
	if post_process:
		post_process.set_crt_effect(enabled, curvature, scanline_intensity, brightness)

func set_contrast_adjustment(enabled: bool, amount: float = 1.1):
	if post_process:
		post_process.set_contrast_adjustment(enabled, amount)

# Dynamic Lighting Controls
func set_dynamic_shadow_intensity(intensity: float):
	if dynamic_lighting:
		dynamic_lighting.set_shadow_intensity(intensity)

func set_time_of_day(time: float):  # 0-1 range, 0 = midnight, 0.5 = noon, 1 = midnight
	time_of_day = clamp(time, 0.0, 1.0)
	
	if dynamic_lighting:
		dynamic_lighting.set_time_of_day(time_of_day)
	

	var day_night_factor = sin(time_of_day * PI)  # Creates noon peak
	
	if post_process:

		var contrast = lerp(1.3, 1.1, day_night_factor)  # Higher contrast at night
		post_process.set_contrast_adjustment(true, contrast)
		

		var brightness = lerp(0.9, 1.2, day_night_factor)
		if post_process.crt_enabled:
			post_process.crt_brightness = brightness

# Particle Effects
func enable_dust_particles(enabled: bool = true):
	if particles:
		particles.enable_dust(enabled)

func enable_smoke_particles(enabled: bool = true):
	if particles:
		particles.enable_smoke(enabled)

func enable_wind_effect(enabled: bool = true):
	if particles:
		particles.enable_wind(enabled)

func enable_chemical_particles(enabled: bool = true):
	if particles:
		particles.enable_chemical(enabled)

func enable_weather_particles(type: String, intensity: float = 1.0):
	if particles:
		particles.enable_weather(type, intensity)

# Reflections
func enable_material_reflections(enabled: bool = true):
	if reflections:
		reflections.enable_reflections(enabled)

func set_reflection_quality(quality: int):  # 0=low, 1=medium, 2=high
	if reflections:
		reflections.set_quality(quality)

# Camera Effects
func enable_camera_shake(enabled: bool = true):
	if camera_effects:
		camera_effects.enable_camera_shake(enabled)

func trigger_camera_shake(intensity: float = 0.5, duration: float = 0.5):
	if camera_effects:
		camera_effects.shake(intensity, duration)

func trigger_time_freeze(duration: float = 0.2):
	if camera_effects:
		camera_effects.apply_freeze_frame(duration)

func set_parallax_effect(enabled: bool, strength: float = 1.0):
	parallax_enabled = enabled

	SignalBus.emit_signal("parallax_settings_changed", enabled, strength)

# Combined Effects
func trigger_pulse_effect(duration: float = 0.5, intensity: float = 0.8):
	if post_process:
		post_process.create_pulse_effect(duration, intensity)

func trigger_particle_burst(type: String, position: Vector2, amount: int = 10):
	if particles:
		particles.create_burst(type, position, amount)

# Environment Presets
func apply_environment_preset(preset: String):
	current_environment = preset
	
	match preset:
		"lab":
			set_palette_shifting(true, "lab")
			set_bloom_effect(true, 0.3, 0.7)
			set_dithering_effect(false)
			set_pixel_perfect_outlines(true, 1.0, Color(0.0, 0.2, 0.3, 0.7), 0.15)
			if dynamic_lighting:
				dynamic_lighting.set_environment("lab")
		"desert":
			set_palette_shifting(true, "desert")
			set_bloom_effect(true, 0.25, 0.8)
			set_dithering_effect(true, 0.05, 1.0)
			set_pixel_perfect_outlines(true, 1.0, Color(0.3, 0.2, 0.0, 0.5), 0.1)
			set_heat_distortion(0.002, 0.2, Vector2(0.5, 0.5), 0.9)
			if dynamic_lighting:
				dynamic_lighting.set_environment("desert")
		"home":
			set_palette_shifting(true, "home")
			set_bloom_effect(false)
			set_dithering_effect(false)
			set_pixel_perfect_outlines(false)
			if dynamic_lighting:
				dynamic_lighting.set_environment("home")
		"night":
			set_contrast_adjustment(true, 1.3)
			if post_process:
				post_process.set_vignette(0.6, 0.7, Color(0.0, 0.0, 0.1, 0.8))
			set_bloom_effect(true, 0.2, 0.6)
			set_pixel_perfect_outlines(true, 1.2, Color(0.0, 0.0, 0.2, 0.8), 0.08)
			if dynamic_lighting:
				dynamic_lighting.set_environment("night")
		"retro":
			set_crt_effect(true, 0.1, 0.7, 1.1)
			set_dithering_effect(true, 0.2, 1.0)
			set_film_grain(0.2, 1.5, 2.0)
			set_contrast_adjustment(true, 1.4)
		_:

			set_palette_shifting(false)
			set_bloom_effect(false)
			set_dithering_effect(false)
			set_pixel_perfect_outlines(false)
			set_crt_effect(false)
			set_contrast_adjustment(false)
			if dynamic_lighting:
				dynamic_lighting.set_environment("default")

# Signal Handlers
func _on_tension_changed(level: float):
	_effect_intensity_modifiers["tension"] = level

func _on_area_changed(area_name: String):
	current_environment = area_name
	
	if area_name == "lab":
		_effect_intensity_modifiers["area"] = 1.2
		apply_environment_preset("lab")
	elif area_name == "desert":
		_effect_intensity_modifiers["area"] = 1.1
		apply_environment_preset("desert")
	elif area_name == "home":
		_effect_intensity_modifiers["area"] = 0.8
		apply_environment_preset("home")
	else:
		_effect_intensity_modifiers["area"] = 1.0
		apply_environment_preset("default")

func _on_player_state_changed(state: String):
	match state:
		"idle":
			_effect_intensity_modifiers["character"] = 0.0
		"walking":
			_effect_intensity_modifiers["character"] = 0.1
		"running":
			_effect_intensity_modifiers["character"] = 0.2
		"dashing":
			_effect_intensity_modifiers["character"] = 0.3
			if post_process:
				post_process.add_effect("motion_blur", 0.3, 0.5)
		"hiding":
			_effect_intensity_modifiers["character"] = -0.2
			if post_process:
				post_process.set_vignette(0.6, 0.6, Color(0.0, 0.0, 0.0, 0.5))
		"interacting":
			_effect_intensity_modifiers["character"] = 0.1
		"injured":
			_effect_intensity_modifiers["character"] = 0.4
			if post_process:
				post_process.add_effect("chromatic_aberration", 0.7, 2.0)
				post_process.add_effect("vignette_red", 0.7, 2.0)
		"dead":
			_effect_intensity_modifiers["character"] = 0.8
			apply_death_effects()

func _on_character_state_changed(character_name: String, state: String):
	if character_name == "walter" and state == "breaking_bad":
		_effect_intensity_modifiers["character"] = 0.3
	elif character_name == "walter" and state == "heisenberg":
		_effect_intensity_modifiers["character"] = 0.5
	else:
		_effect_intensity_modifiers["character"] = 0.0

func _on_time_of_day_changed(time: float):
	set_time_of_day(time)
	

	if time < 0.25 or time > 0.75:  # Early morning or evening/night
		apply_environment_preset("night")

func _on_weather_changed(condition: String, intensity: float):
	weather_condition = condition
	enable_weather_particles(condition, intensity)
	

	match condition:
		"rain":
			set_bloom_effect(false)
			set_contrast_adjustment(true, 1.2)
			if post_process:
				post_process.set_vignette(0.5, 0.6, Color(0.0, 0.1, 0.2, 0.6))
		"dust":
			set_bloom_effect(true, 0.15, 0.85)
			set_heat_distortion(0.001, 0.1, Vector2(0.5, 0.5), 1.0)
			if post_process:
				post_process.set_vignette(0.4, 0.6, Color(0.3, 0.2, 0.1, 0.5))
		"storm":
			set_contrast_adjustment(true, 1.3)
			if post_process:
				post_process.set_vignette(0.7, 0.7, Color(0.1, 0.1, 0.2, 0.7))
			set_film_grain(0.15, 1.0, 1.5)
		_:

			pass

func set_story_impact(value: float):
	_effect_intensity_modifiers["story"] = clamp(value, 0.0, 1.0)

func apply_death_effects():
	if post_process:
		post_process.add_effect("grayscale", 1.0)
		post_process.add_effect("vignette_black", 1.0)
		post_process.set_contrast_adjustment(true, 0.5)
	
	if camera_effects:
		camera_effects.add_effect("fade_out", 3.0) 