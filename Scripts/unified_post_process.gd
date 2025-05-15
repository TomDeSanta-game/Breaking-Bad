extends Node
class_name PostProcessingSystem

signal post_processing_ready

@export var viewport: SubViewport = null
@export var enabled: bool = false
@export var initial_quality_level: int = 1

var post_process_rect: ColorRect
var post_process_material: ShaderMaterial
var is_initialized: bool = false

var vignette_enabled: bool = false
var vignette_intensity: float = 0.4
var vignette_opacity: float = 0.5
var vignette_color: Color = Color(0.0, 0.0, 0.0, 1.0)

var grain_enabled: bool = false
var grain_amount: float = 0.05
var grain_size: float = 1.0
var grain_speed: float = 1.0

var aberration_enabled: bool = false
var aberration_amount: float = 0.5

var heat_distortion_enabled: bool = false
var heat_distortion_amount: float = 0.0
var heat_distortion_speed: float = 0.1
var heat_center: Vector2 = Vector2(0.5, 0.5)
var heat_radius: float = 0.5
var heat_noise_texture: Texture2D

var depth_blend: float = 0.0
var depth_range: float = 10.0

var outline_enabled: bool = false
var outline_thickness: float = 1.0
var outline_color: Color = Color(0.0, 0.0, 0.0, 1.0)
var outline_threshold: float = 0.1

var palette_shift_enabled: bool = false
var palette_shadow: Color = Color(0.0, 0.0, 0.0, 1.0)
var palette_midtone: Color = Color(0.5, 0.5, 0.5, 1.0)
var palette_highlight: Color = Color(1.0, 1.0, 1.0, 1.0)
var palette_shift_amount: float = 0.5

var bloom_enabled: bool = false
var bloom_intensity: float = 0.3
var bloom_threshold: float = 0.7

var dithering_enabled: bool = false
var dithering_intensity: float = 0.1
var dithering_scale: float = 1.0

var crt_enabled: bool = false
var crt_curvature: float = 0.1
var crt_scanline_intensity: float = 0.5
var crt_brightness: float = 1.2

var contrast_enabled: bool = false
var contrast_amount: float = 1.1

var overlay_color: Color = Color(0.0, 0.0, 0.0, 0.0)

func _ready():
	call_deferred("setup_post_processing")
	
	var signal_bus = get_node("/root/SignalBus")
	signal_bus.tension_level_changed.connect(_on_tension_level_changed)
	signal_bus.player_health_changed.connect(_on_player_health_changed)
	signal_bus.environment_changed.connect(_on_environment_changed)
	signal_bus.apply_immediate_effect.connect(_on_apply_immediate_effect)
	
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	
	var noise_texture = NoiseTexture2D.new()
	noise_texture.width = 256
	noise_texture.height = 256
	noise_texture.noise = noise
	noise_texture.seamless = true
	
	heat_noise_texture = noise_texture

func setup_post_processing():
	print("Post-processing permanently disabled")
	is_initialized = false
	enabled = false
	self.process_mode = Node.PROCESS_MODE_DISABLED
	post_processing_ready.emit()
	return

func update_shader_parameters():
	if not is_initialized or not post_process_material or not enabled:
		return
	
	post_process_material.set_shader_parameter("vignette_enabled", vignette_enabled)
	post_process_material.set_shader_parameter("vignette_intensity", vignette_intensity)
	post_process_material.set_shader_parameter("vignette_opacity", vignette_opacity)
	post_process_material.set_shader_parameter("vignette_color", vignette_color)
	
	post_process_material.set_shader_parameter("grain_enabled", grain_enabled)
	post_process_material.set_shader_parameter("grain_amount", grain_amount)
	post_process_material.set_shader_parameter("grain_size", grain_size)
	post_process_material.set_shader_parameter("grain_speed", grain_speed)
	
	post_process_material.set_shader_parameter("aberration_enabled", aberration_enabled)
	post_process_material.set_shader_parameter("aberration_amount", aberration_amount)
	
	if heat_noise_texture:
		post_process_material.set_shader_parameter("heat_distortion_enabled", heat_distortion_enabled)
		post_process_material.set_shader_parameter("heat_noise", heat_noise_texture)
		post_process_material.set_shader_parameter("heat_distortion_amount", heat_distortion_amount)
		post_process_material.set_shader_parameter("heat_distortion_speed", heat_distortion_speed)
		post_process_material.set_shader_parameter("heat_center", heat_center)
		post_process_material.set_shader_parameter("heat_radius", heat_radius)
	else:
		post_process_material.set_shader_parameter("heat_distortion_enabled", false)
	
	post_process_material.set_shader_parameter("depth_blend", depth_blend)
	post_process_material.set_shader_parameter("depth_range", depth_range)
	
	post_process_material.set_shader_parameter("outline_enabled", outline_enabled)
	post_process_material.set_shader_parameter("outline_thickness", outline_thickness)
	post_process_material.set_shader_parameter("outline_color", outline_color)
	post_process_material.set_shader_parameter("outline_threshold", outline_threshold)
	
	post_process_material.set_shader_parameter("palette_shift_enabled", palette_shift_enabled)
	post_process_material.set_shader_parameter("palette_shadow", palette_shadow)
	post_process_material.set_shader_parameter("palette_midtone", palette_midtone)
	post_process_material.set_shader_parameter("palette_highlight", palette_highlight)
	post_process_material.set_shader_parameter("palette_shift_amount", palette_shift_amount)
	
	post_process_material.set_shader_parameter("bloom_enabled", bloom_enabled)
	post_process_material.set_shader_parameter("bloom_intensity", bloom_intensity)
	post_process_material.set_shader_parameter("bloom_threshold", bloom_threshold)
	
	post_process_material.set_shader_parameter("dithering_enabled", dithering_enabled)
	post_process_material.set_shader_parameter("dithering_intensity", dithering_intensity)
	post_process_material.set_shader_parameter("dithering_scale", dithering_scale)
	
	post_process_material.set_shader_parameter("crt_enabled", crt_enabled)
	post_process_material.set_shader_parameter("crt_curvature", crt_curvature)
	post_process_material.set_shader_parameter("crt_scanline_intensity", crt_scanline_intensity)
	post_process_material.set_shader_parameter("crt_brightness", crt_brightness)
	
	post_process_material.set_shader_parameter("contrast_enabled", contrast_enabled)
	post_process_material.set_shader_parameter("contrast_amount", contrast_amount)
	
	post_process_material.set_shader_parameter("temperature", 0.0)

func set_vignette(intensity: float, opacity: float, color: Color = Color(0.0, 0.0, 0.0, 1.0)):
	vignette_intensity = intensity
	vignette_opacity = opacity
	vignette_color = color
	update_shader_parameters()

func set_film_grain(amount: float, size: float, speed: float):
	grain_amount = amount
	grain_size = size
	grain_speed = speed
	update_shader_parameters()

func set_chromatic_aberration(amount: float, is_enabled: bool = true):
	aberration_amount = amount
	aberration_enabled = is_enabled
	update_shader_parameters()

func set_heat_distortion(amount: float, speed: float, center: Vector2, radius: float):
	heat_distortion_amount = amount
	heat_distortion_speed = speed
	heat_center = center
	heat_radius = radius
	update_shader_parameters()

func set_depth_of_field(blend: float, range_value: float):
	depth_blend = blend
	depth_range = range_value
	update_shader_parameters()

func set_pixel_perfect_outlines(is_enabled: bool, thickness: float = 1.0, color: Color = Color(0.0, 0.0, 0.0, 1.0), threshold: float = 0.1):
	outline_enabled = is_enabled
	outline_thickness = thickness
	outline_color = color
	outline_threshold = threshold
	update_shader_parameters()

func set_palette_shifting(is_enabled: bool, shadow: Color, midtone: Color, highlight: Color, amount: float = 0.5):
	palette_shift_enabled = is_enabled
	palette_shadow = shadow
	palette_midtone = midtone
	palette_highlight = highlight
	palette_shift_amount = amount
	update_shader_parameters()

func set_bloom(is_enabled: bool, intensity: float = 0.3, threshold: float = 0.7):
	bloom_enabled = is_enabled
	bloom_intensity = intensity
	bloom_threshold = threshold
	update_shader_parameters()

func set_dithering(is_enabled: bool, intensity: float = 0.1, scale: float = 1.0):
	dithering_enabled = is_enabled
	dithering_intensity = intensity
	dithering_scale = scale
	update_shader_parameters()

func set_crt_effect(is_enabled: bool, curvature: float = 0.1, scanline_intensity: float = 0.5, brightness: float = 1.2):
	crt_enabled = is_enabled
	crt_curvature = curvature
	crt_scanline_intensity = scanline_intensity
	crt_brightness = brightness
	update_shader_parameters()

func set_contrast_adjustment(is_enabled: bool, amount: float = 1.1):
	contrast_enabled = is_enabled
	contrast_amount = amount
	update_shader_parameters()

func apply_desert_palette():
	set_palette_shifting(true, 
		Color(0.4, 0.3, 0.1, 1.0),
		Color(0.8, 0.6, 0.3, 1.0),
		Color(1.0, 0.9, 0.6, 1.0),
		0.6
	)

func apply_lab_palette():
	set_palette_shifting(true, 
		Color(0.05, 0.1, 0.2, 1.0),
		Color(0.2, 0.5, 0.6, 1.0),
		Color(0.7, 0.9, 1.0, 1.0),
		0.5
	)

func apply_home_palette():
	set_palette_shifting(true, 
		Color(0.15, 0.1, 0.05, 1.0),
		Color(0.5, 0.4, 0.3, 1.0),
		Color(0.9, 0.8, 0.7, 1.0),
		0.4
	)

func create_pulse_effect(duration: float = 0.5, intensity: float = 0.8):
	var original_vignette = vignette_intensity
	var original_aberration = aberration_amount
	
	set_vignette(original_vignette + 0.3 * intensity, 0.7 * intensity)
	set_chromatic_aberration(0.5 * intensity)
	
	var tween = create_tween()
	tween.tween_method(set_vignette.bind(vignette_opacity, vignette_color), 
		vignette_intensity, original_vignette, duration)
	tween.parallel().tween_method(set_chromatic_aberration.bind(true),
		aberration_amount, original_aberration, duration)

func create_shake_effect(duration: float = 0.3, intensity: float = 1.0):
	SignalBus.camera_effect_requested.emit("shake", intensity, duration)

func _on_tension_level_changed(level_name: String, _previous: String):
	if not is_initialized:
		return
	
	match level_name:
		"MINIMAL":
			set_vignette(0.2, 0.4)
			set_film_grain(0.03, 1.0, 1.0)
			set_chromatic_aberration(0.0, false)
			
		"LOW":
			set_vignette(0.3, 0.5)
			set_film_grain(0.05, 1.0, 1.0)
			set_chromatic_aberration(0.0, false)
			
		"MEDIUM":
			set_vignette(0.4, 0.6, Color(0.1, 0.0, 0.0, 1.0))
			set_film_grain(0.07, 1.2, 1.5)
			set_chromatic_aberration(0.2, true)
			create_pulse_effect(0.8, 0.3)
			
		"HIGH":
			set_vignette(0.5, 0.7, Color(0.2, 0.0, 0.0, 1.0))
			set_film_grain(0.1, 1.5, 2.0)
			set_chromatic_aberration(0.4, true)
			create_pulse_effect(0.6, 0.5)
			
		"CRITICAL":
			set_vignette(0.7, 0.8, Color(0.4, 0.0, 0.0, 1.0))
			set_film_grain(0.15, 2.0, 3.0)
			set_chromatic_aberration(0.6, true)
			set_contrast_adjustment(true, 1.2)
			create_pulse_effect(0.4, 0.7)
			create_shake_effect(0.3, 0.5)

func _on_player_health_changed(current_health: float, max_health: float):
	if not is_initialized:
		return
	
	var health_ratio = current_health / max_health
	
	if health_ratio < 0.3:
		var intensity = (0.3 - health_ratio) / 0.3
		set_vignette(0.5 + (0.3 * intensity), 0.8 * intensity, Color(0.5, 0.0, 0.0, 1.0))
		set_film_grain(0.1 + (0.1 * intensity), 1.5, 2.0)
		set_chromatic_aberration(0.3 * intensity, intensity > 0.2)
		
		if intensity > 0.7:
			create_pulse_effect(1.2 + (intensity * 0.5), intensity * 0.8)
	else:
		set_vignette(vignette_intensity, vignette_opacity, vignette_color)
		set_chromatic_aberration(aberration_amount, aberration_enabled)

func _on_environment_changed(environment_type: String):
	if not is_initialized:
		return
	
	match environment_type:
		"desert", "weather_dust_storm":
			apply_desert_palette()
			set_heat_distortion(0.2, 0.2, Vector2(0.5, 0.2), 1.0)
			
		"lab":
			apply_lab_palette()
			set_heat_distortion(0.0, 0.0, Vector2(0.5, 0.5), 0.5)
			
		"home":
			apply_home_palette()
			set_heat_distortion(0.0, 0.0, Vector2(0.5, 0.5), 0.5)
			
		"hallucination":
			set_palette_shifting(true, 
				Color(0.1, 0.0, 0.2, 1.0),
				Color(0.5, 0.1, 0.6, 1.0),
				Color(0.9, 0.5, 1.0, 1.0),
				0.7
			)
			set_chromatic_aberration(0.8, true)
			set_heat_distortion(0.4, 0.4, Vector2(0.5, 0.5), 1.0)
			
		"fire", "explosion":
			set_heat_distortion(0.5, 0.8, Vector2(0.5, 0.5), 1.0)
			create_pulse_effect(0.3, 0.9)
			
		_:
			set_palette_shifting(false, Color.BLACK, Color.GRAY, Color.WHITE, 0.0)
			set_heat_distortion(0.0, 0.0, Vector2(0.5, 0.5), 0.5)

func _on_apply_immediate_effect(effect_name: String, params: Dictionary):
	if not is_initialized:
		return
	
	match effect_name:
		"flash":
			if params.has("color") and params.has("duration"):
				flash_screen(params.color, params.duration)
		
		"pulse":
			var intensity = 1.0
			var duration = 0.5
			
			if params.has("intensity"):
				intensity = params.intensity
			if params.has("duration"):
				duration = params.duration
				
			create_pulse_effect(duration, intensity)
			
		"shake":
			var intensity = 1.0
			var duration = 0.3
			
			if params.has("intensity"):
				intensity = params.intensity
			if params.has("duration"):
				duration = params.duration
				
			create_shake_effect(duration, intensity)
			
		"heat_wave":
			var amount = 0.5
			var speed = 0.8
			var center = Vector2(0.5, 0.5)
			var radius = 1.0
			var duration = 2.0
			
			if params.has("amount"):
				amount = params.amount
			if params.has("speed"):
				speed = params.speed
			if params.has("center"):
				center = params.center
			if params.has("radius"):
				radius = params.radius
			if params.has("duration"):
				duration = params.duration
				
			set_heat_distortion(amount, speed, center, radius)
			
			if duration > 0.0:
				var tween = create_tween()
				tween.tween_method(func(v): set_heat_distortion(v, speed, center, radius), 
					amount, 0.0, duration)

func flash_screen(color: Color, duration: float = 0.5):
	if not is_initialized or not post_process_material:
		return
	
	post_process_material.set_shader_parameter("overlay_color", color)
	post_process_material.set_shader_parameter("blend_mode", 0)
	
	var tween = create_tween()
	tween.tween_method(func(v): post_process_material.set_shader_parameter("overlay_color", v), 
		color, Color(0, 0, 0, 0), duration)

func set_quality_level(level: int):
	if not is_initialized:
		return
		
	match level:
		0:  
			grain_enabled = false
			bloom_enabled = false
			aberration_enabled = false
			palette_shift_enabled = false
			dithering_enabled = false
			
		1:  
			grain_enabled = true
			bloom_enabled = true
			aberration_enabled = false
			palette_shift_enabled = true
			dithering_enabled = false
			
		2:  
			grain_enabled = true
			bloom_enabled = true
			aberration_enabled = true
			palette_shift_enabled = true
			dithering_enabled = true
	
	update_shader_parameters()

func _on_screen_capture_requested():
	if is_initialized and post_process_material:
		var original_enabled = enabled
		enabled = false
		update_shader_parameters()
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		enabled = original_enabled
		update_shader_parameters() 
