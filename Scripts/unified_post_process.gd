extends Node
class_name PostProcessingSystem

signal post_processing_ready

@export var viewport: SubViewport
@export var enabled: bool = true
@export var initial_quality_level: int = 1

var post_process_rect: ColorRect
var post_process_material: ShaderMaterial
var is_initialized: bool = false

var vignette_intensity: float = 0.4
var vignette_opacity: float = 0.5
var vignette_color: Color = Color(0.0, 0.0, 0.0, 1.0)

var grain_amount: float = 0.05
var grain_size: float = 1.0
var grain_speed: float = 1.0

var aberration_amount: float = 0.5
var aberration_enabled: bool = true

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

func _ready():
	call_deferred("setup_post_processing")
	
	var signal_bus = get_node("/root/SignalBus")
	signal_bus.connect("tension_level_changed", Callable(self, "_on_tension_level_changed"))
	signal_bus.connect("player_health_changed", Callable(self, "_on_player_health_changed"))
	signal_bus.connect("environment_changed", Callable(self, "_on_environment_changed"))
	signal_bus.connect("apply_immediate_effect", Callable(self, "_on_apply_immediate_effect"))
	
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
	if not viewport:
		return
	
	post_process_rect = ColorRect.new()
	post_process_rect.material = load("res://Resources/Shaders/post_process.gdshader")
	post_process_material = post_process_rect.material
	
	post_process_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(post_process_rect)
	
	post_process_rect.visible = enabled
	is_initialized = true
	
	update_shader_parameters()
	emit_signal("post_processing_ready")

func update_shader_parameters():
	if not is_initialized:
		return
	
	post_process_material.set_shader_parameter("vignette_enabled", true)
	post_process_material.set_shader_parameter("vignette_intensity", vignette_intensity)
	post_process_material.set_shader_parameter("vignette_opacity", vignette_opacity)
	post_process_material.set_shader_parameter("vignette_color", vignette_color)
	
	post_process_material.set_shader_parameter("grain_enabled", true)
	post_process_material.set_shader_parameter("grain_amount", grain_amount)
	post_process_material.set_shader_parameter("grain_size", grain_size)
	post_process_material.set_shader_parameter("grain_speed", grain_speed)
	
	post_process_material.set_shader_parameter("aberration_enabled", aberration_enabled)
	post_process_material.set_shader_parameter("aberration_amount", aberration_amount)
	
	post_process_material.set_shader_parameter("heat_distortion_enabled", true)
	post_process_material.set_shader_parameter("heat_noise", heat_noise_texture)
	post_process_material.set_shader_parameter("heat_distortion_amount", heat_distortion_amount)
	post_process_material.set_shader_parameter("heat_distortion_speed", heat_distortion_speed)
	post_process_material.set_shader_parameter("heat_center", heat_center)
	post_process_material.set_shader_parameter("heat_radius", heat_radius)
	
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
	
	set_vignette(intensity, vignette_opacity, vignette_color)
	set_chromatic_aberration(aberration_amount * 2.0)
	
	var tween = create_tween()
	tween.tween_property(self, "vignette_intensity", original_vignette, duration)
	tween.parallel().tween_property(self, "aberration_amount", original_aberration, duration)
	tween.tween_callback(Callable(self, "update_shader_parameters"))

func _on_tension_level_changed(level: float):
	var target_vignette = lerp(0.3, 0.6, level)
	var target_aberration = lerp(0.3, 1.0, level)
	var target_grain = lerp(0.05, 0.2, level)
	var target_bloom = lerp(0.0, 0.4, level)
	
	var tween = create_tween()
	tween.tween_property(self, "vignette_intensity", target_vignette, 1.0)
	tween.parallel().tween_property(self, "aberration_amount", target_aberration, 1.0)
	tween.parallel().tween_property(self, "grain_amount", target_grain, 1.0)
	tween.parallel().tween_property(self, "bloom_intensity", target_bloom, 1.0)
	tween.tween_callback(Callable(self, "update_shader_parameters"))
	
	if level > 0.6 and !bloom_enabled:
		set_bloom(true, target_bloom, 0.6)

func _on_player_health_changed(health: float, max_health: float):
	var health_ratio = health / max_health
	
	if health_ratio < 0.5:
		var intensity = lerp(0.4, 0.8, 1.0 - health_ratio * 2.0)
		var opacity = lerp(0.5, 0.7, 1.0 - health_ratio * 2.0)
		var color = Color(0.5, 0.0, 0.0, lerp(0.2, 0.8, 1.0 - health_ratio * 2.0))
		
		set_vignette(intensity, opacity, color)
		
		if health_ratio < 0.3:
			set_chromatic_aberration(lerp(0.5, 2.0, 1.0 - health_ratio / 0.3))
			set_film_grain(lerp(0.1, 0.3, 1.0 - health_ratio / 0.3), grain_size, grain_speed)
			set_dithering(true, lerp(0.0, 0.15, 1.0 - health_ratio / 0.3), 1.0)
	else:
		set_vignette(0.4, 0.5, Color(0.0, 0.0, 0.0, 1.0))
		set_chromatic_aberration(0.5)
		set_film_grain(0.1, 1.0, 1.0)
		set_dithering(false)

func _on_environment_changed(environment: String):
	match environment:
		"lab":
			apply_lab_palette()
			set_bloom(true, 0.2, 0.6)
			set_vignette(0.5, 0.6, Color(0.0, 0.1, 0.2, 1.0))
		"desert":
			apply_desert_palette()
			set_bloom(false)
			set_heat_distortion(0.02, 0.2, Vector2(0.5, 0.5), 2.0)
			set_vignette(0.5, 0.4, Color(0.3, 0.2, 0.1, 1.0))
		"home":
			apply_home_palette()
			set_bloom(false)
			set_vignette(0.4, 0.5, Color(0.1, 0.05, 0.0, 1.0))
		"night":
			set_palette_shifting(true, 
				Color(0.2, 0.15, 0.05, 1.0),
				Color(0.6, 0.5, 0.3, 1.0),
				Color(0.9, 0.7, 0.5, 1.0),
				0.5
			)
			set_bloom(true, 0.3, 0.5)
			set_vignette(0.6, 0.7, Color(0.0, 0.0, 0.1, 1.0))

func _on_apply_immediate_effect(effect_name: String, duration: float = 0.5):
	match effect_name:
		"pulse":
			create_pulse_effect(duration, 0.8)
		"flash":
			var tween = create_tween()
			set_vignette(0.0, 0.0, Color(1.0, 1.0, 1.0, 1.0))
			tween.tween_property(self, "vignette_intensity", 0.4, duration)
			tween.parallel().tween_property(self, "vignette_opacity", 0.5, duration)
			tween.parallel().tween_property(self, "vignette_color", Color(0.0, 0.0, 0.0, 1.0), duration)
			tween.tween_callback(Callable(self, "update_shader_parameters"))
		"glitch":
			var original_aberration = aberration_amount
			set_chromatic_aberration(2.0)
			
			var tween = create_tween()
			tween.tween_property(self, "aberration_amount", original_aberration, duration)
			tween.tween_callback(Callable(self, "update_shader_parameters"))

func set_enabled(is_enabled: bool):
	enabled = is_enabled
	
	if post_process_rect:
		post_process_rect.visible = enabled 
