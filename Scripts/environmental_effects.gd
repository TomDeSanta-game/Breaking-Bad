extends Node2D

enum WeatherType {
	CLEAR,
	RAIN,
	SNOW,
	DUST_STORM,
	FOG
}

enum TimeOfDay {
	MORNING,
	DAY,
	EVENING,
	NIGHT
}

@export var enable_weather_effects: bool = true
@export var enable_post_processing: bool = true
@export var weather_darkening_factor: float = 0.3
@export var max_dust_emission_rate: int = 50
@export var max_rain_emission_rate: int = 100
@export var max_snow_emission_rate: int = 80
@export var max_fog_opacity: float = 0.5

var current_weather_type: String = "clear"
var current_weather_intensity: float = 0.0

var dust_storm_particles: GPUParticles2D
var rain_particles: GPUParticles2D
var snow_particles: GPUParticles2D
var fog_overlay: ColorRect

var heat_distortion: ColorRect
var film_grain: ColorRect
var vignette: ColorRect
var chromatic_aberration: ColorRect

var global_canvas_modulate: CanvasModulate
var lighting_system: Node

var region_type: String = "urban"
var heat_distortion_active: bool = false
var film_grain_active: bool = false
var vignette_active: bool = false
var chromatic_aberration_active: bool = false

func _ready():
	setup_post_processing()
	create_weather_particles()
	
	global_canvas_modulate = get_node_or_null("/root/GlobalCanvasModulate") as CanvasModulate
	lighting_system = get_node_or_null("/root/LightingSystem")
	
	SignalBus.weather_changed.connect(_on_weather_changed)

func _process(delta):
	update_current_weather(delta)

func create_weather_particles():
	if !enable_weather_effects:
		return
	
	dust_storm_particles = GPUParticles2D.new()
	dust_storm_particles.name = "DustStormParticles"
	add_child(dust_storm_particles)
	
	var dust_material = ParticleProcessMaterial.new()
	dust_material.particle_flag_disable_z = true
	dust_material.direction = Vector3(-1.0, 0.2, 0)
	dust_material.spread = 15.0
	dust_material.gravity = Vector3(0, 0, 0)
	dust_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_material.emission_box_extents = Vector3(300, 300, 1)
	dust_material.color = Color(0.8, 0.7, 0.5, 0.8)
	dust_material.lifetime_randomness = 0.4
	dust_material.initial_velocity_min = 60.0
	dust_material.initial_velocity_max = 100.0
	
	dust_storm_particles.process_material = dust_material
	dust_storm_particles.lifetime = 4.0
	dust_storm_particles.amount = max_dust_emission_rate
	dust_storm_particles.emitting = false
	dust_storm_particles.z_index = 10
	
	rain_particles = GPUParticles2D.new()
	rain_particles.name = "RainParticles"
	add_child(rain_particles)
	
	var rain_material = ParticleProcessMaterial.new()
	rain_material.particle_flag_disable_z = true
	rain_material.direction = Vector3(0.1, 1.0, 0)
	rain_material.spread = 5.0
	rain_material.gravity = Vector3(0, 98, 0)
	rain_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_material.emission_box_extents = Vector3(400, 10, 1)
	rain_material.color = Color(0.7, 0.8, 1.0, 0.8)
	rain_material.lifetime_randomness = 0.2
	rain_material.initial_velocity_min = 200.0
	rain_material.initial_velocity_max = 300.0
	
	rain_particles.process_material = rain_material
	rain_particles.lifetime = 2.0
	rain_particles.amount = max_rain_emission_rate
	rain_particles.emitting = false
	rain_particles.z_index = 10
	
	snow_particles = GPUParticles2D.new()
	snow_particles.name = "SnowParticles"
	add_child(snow_particles)
	
	var snow_material = ParticleProcessMaterial.new()
	snow_material.particle_flag_disable_z = true
	snow_material.direction = Vector3(0.1, 0.9, 0)
	snow_material.spread = 20.0
	snow_material.gravity = Vector3(0, 20, 0)
	snow_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	snow_material.emission_box_extents = Vector3(400, 10, 1)
	snow_material.color = Color(1.0, 1.0, 1.0, 0.9)
	snow_material.lifetime_randomness = 0.3
	snow_material.initial_velocity_min = 40.0
	snow_material.initial_velocity_max = 80.0
	
	snow_particles.process_material = snow_material
	snow_particles.lifetime = 8.0
	snow_particles.amount = max_snow_emission_rate
	snow_particles.emitting = false
	snow_particles.z_index = 10
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "FogLayer"
	canvas_layer.layer = 5
	add_child(canvas_layer)
	
	fog_overlay = ColorRect.new()
	fog_overlay.name = "FogOverlay"
	fog_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog_overlay.color = Color(0.8, 0.8, 0.9, 0.0)
	fog_overlay.visible = false
	canvas_layer.add_child(fog_overlay)

func setup_post_processing():
	if !enable_post_processing:
		return
	
	var post_process_layer = CanvasLayer.new()
	post_process_layer.name = "PostProcessLayer"
	post_process_layer.layer = 10
	add_child(post_process_layer)
	
	create_heat_distortion(post_process_layer)
	create_film_grain(post_process_layer)
	create_vignette(post_process_layer)
	create_chromatic_aberration(post_process_layer)

func create_heat_distortion(parent: Node):
	heat_distortion = ColorRect.new()
	heat_distortion.name = "HeatDistortion"
	heat_distortion.set_anchors_preset(Control.PRESET_FULL_RECT)
	heat_distortion.visible = false
	parent.add_child(heat_distortion)
	
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform float intensity : hint_range(0.0, 0.1) = 0.0;
	uniform float time_scale : hint_range(0.0, 5.0) = 1.0;
	
	float random(vec2 p) {
		return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
	}
	
	void fragment() {
		vec2 uv = SCREEN_UV;
		
		float time = TIME * time_scale;
		
		vec2 direction = vec2(0.0, 1.0);
		float effect = sin(uv.y * 20.0 + time) * intensity;
		
		vec2 distorted_uv = uv + direction * effect;
		
		COLOR = texture(SCREEN_TEXTURE, distorted_uv);
	}
	"""
	
	shader_material.shader = shader
	shader_material.set_shader_parameter("intensity", 0.01)
	shader_material.set_shader_parameter("time_scale", 1.0)
	
	heat_distortion.material = shader_material

func create_film_grain(parent: Node):
	film_grain = ColorRect.new()
	film_grain.name = "FilmGrain"
	film_grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_grain.visible = false
	parent.add_child(film_grain)
	
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform float grain_amount : hint_range(0.0, 0.5) = 0.05;
	uniform float grain_scale : hint_range(1.0, 10.0) = 1.0;
	
	float random(vec2 p) {
		return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
	}
	
	void fragment() {
		vec2 uv = SCREEN_UV;
		vec4 color = texture(SCREEN_TEXTURE, uv);
		
		float grain_time = floor(TIME * 10.0) / 10.0;
		float grain = random(uv * grain_scale + grain_time);
		
		color.rgb += vec3(grain - 0.5) * grain_amount;
		
		COLOR = color;
	}
	"""
	
	shader_material.shader = shader
	shader_material.set_shader_parameter("grain_amount", 0.05)
	shader_material.set_shader_parameter("grain_scale", 1.0)
	
	film_grain.material = shader_material

func create_vignette(parent: Node):
	vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.visible = false
	parent.add_child(vignette)
	
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
	uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
	uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
	
	void fragment() {
		vec2 uv = SCREEN_UV;
		vec4 color = texture(SCREEN_TEXTURE, uv);
		
		float vignette = smoothstep(0.8, 0.2, length(uv - vec2(0.5)));
		color.rgb = mix(color.rgb, vignette_color.rgb, vignette * vignette_opacity * vignette_intensity);
		
		COLOR = color;
	}
	"""
	
	shader_material.shader = shader
	shader_material.set_shader_parameter("vignette_intensity", 0.4)
	shader_material.set_shader_parameter("vignette_opacity", 0.5)
	shader_material.set_shader_parameter("vignette_color", Color(0, 0, 0, 1))
	
	vignette.material = shader_material

func create_chromatic_aberration(parent: Node):
	chromatic_aberration = ColorRect.new()
	chromatic_aberration.name = "ChromaticAberration"
	chromatic_aberration.set_anchors_preset(Control.PRESET_FULL_RECT)
	chromatic_aberration.visible = false
	parent.add_child(chromatic_aberration)
	
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform float aberration_amount : hint_range(0.0, 0.1) = 0.01;
	
	void fragment() {
		vec2 uv = SCREEN_UV;
		
		float offset_r = floor(aberration_amount * 100.0) / 100.0;
		float offset_b = -offset_r;
		
		float r = texture(SCREEN_TEXTURE, uv + vec2(offset_r, 0.0)).r;
		float g = texture(SCREEN_TEXTURE, uv).g;
		float b = texture(SCREEN_TEXTURE, uv + vec2(offset_b, 0.0)).b;
		
		COLOR = vec4(r, g, b, 1.0);
	}
	"""
	
	shader_material.shader = shader
	shader_material.set_shader_parameter("aberration_amount", 0.01)
	
	chromatic_aberration.material = shader_material

func update_current_weather(_delta: float):
	match current_weather_type:
		"dust_storm":
			update_dust_storm()
		"rain":
			update_rain()
		"snow":
			update_snow()
		"fog":
			update_fog()
		_:
			pass

func set_weather(weather_type_id: int, intensity: float = 1.0):
	current_weather_intensity = clamp(intensity, 0.0, 1.0)
	
	var weather_types = ["clear", "rain", "snow", "dust_storm", "fog"]
	var new_weather_type = weather_types[min(weather_type_id, weather_types.size() - 1)]
	
	if new_weather_type == current_weather_type:
		return
		
	reset_all_weather()
	current_weather_type = new_weather_type
	
	SignalBus.weather_changed.emit(current_weather_type, current_weather_intensity)
	
	match current_weather_type:
		"dust_storm":
			start_dust_storm(current_weather_intensity)
		"rain":
			start_rain(current_weather_intensity)
		"snow":
			start_snow(current_weather_intensity)
		"fog":
			start_fog(current_weather_intensity)
		_:
			pass

func set_weather_intensity(intensity: float):
	var old_intensity = current_weather_intensity
	current_weather_intensity = clamp(intensity, 0.0, 1.0)
	
	if current_weather_intensity == old_intensity:
		return
		
	SignalBus.weather_changed.emit(current_weather_type, current_weather_intensity)
	
	match current_weather_type:
		"dust_storm":
			update_dust_storm()
		"rain":
			update_rain()
		"snow":
			update_snow()
		"fog":
			update_fog()
		_:
			pass

func start_dust_storm(intensity: float = 1.0):
	if dust_storm_particles and enable_weather_effects:
		current_weather_type = "dust_storm"
		current_weather_intensity = clamp(intensity, 0.0, 1.0)
		dust_storm_particles.emitting = true
		var ps = dust_storm_particles.process_material as ParticleProcessMaterial
		if ps:
			ps.emission_box_extents.y = 300
			ps.emission_box_extents.x = 300
			ps.direction = Vector3(-1.0, 0.2, 0.0)
			ps.spread = 15.0
		
		dust_storm_particles.amount = int(max_dust_emission_rate * current_weather_intensity)
		
		darken_scene(current_weather_intensity * weather_darkening_factor)
		
		if region_type == "desert":
			set_heat_distortion(true)

func update_dust_storm():
	if dust_storm_particles and dust_storm_particles.emitting:
		dust_storm_particles.amount = int(max_dust_emission_rate * current_weather_intensity)
		darken_scene(current_weather_intensity * weather_darkening_factor)

func start_rain(intensity: float = 1.0):
	if rain_particles and enable_weather_effects:
		current_weather_type = "rain"
		current_weather_intensity = clamp(intensity, 0.0, 1.0)
		rain_particles.emitting = true
		var ps = rain_particles.process_material as ParticleProcessMaterial
		if ps:
			ps.emission_box_extents.y = 10
			ps.emission_box_extents.x = 400
			ps.direction = Vector3(0.1, 1.0, 0.0)
			ps.spread = 5.0
		
		rain_particles.amount = int(max_rain_emission_rate * current_weather_intensity)
		
		darken_scene(current_weather_intensity * weather_darkening_factor * 0.7)

func update_rain():
	if rain_particles and rain_particles.emitting:
		rain_particles.amount = int(max_rain_emission_rate * current_weather_intensity)
		darken_scene(current_weather_intensity * weather_darkening_factor * 0.7)

func start_snow(intensity: float = 1.0):
	if snow_particles and enable_weather_effects:
		current_weather_type = "snow"
		current_weather_intensity = clamp(intensity, 0.0, 1.0)
		snow_particles.emitting = true
		var ps = snow_particles.process_material as ParticleProcessMaterial
		if ps:
			ps.emission_box_extents.y = 10
			ps.emission_box_extents.x = 400
			ps.direction = Vector3(0.1, 0.9, 0.0)
			ps.spread = 20.0
		
		snow_particles.amount = int(max_snow_emission_rate * current_weather_intensity)
		
		darken_scene(current_weather_intensity * weather_darkening_factor * 0.5)

func update_snow():
	if snow_particles and snow_particles.emitting:
		snow_particles.amount = int(max_snow_emission_rate * current_weather_intensity)
		darken_scene(current_weather_intensity * weather_darkening_factor * 0.5)

func start_fog(intensity: float = 1.0):
	if fog_overlay and enable_weather_effects:
		current_weather_type = "fog"
		current_weather_intensity = clamp(intensity, 0.0, 1.0)
		fog_overlay.visible = true
		var overlay_color = fog_overlay.color
		overlay_color.a = current_weather_intensity * max_fog_opacity
		fog_overlay.color = overlay_color
		
		darken_scene(current_weather_intensity * weather_darkening_factor * 0.3)

func update_fog():
	if fog_overlay and fog_overlay.visible:
		var overlay_color = fog_overlay.color
		overlay_color.a = current_weather_intensity * max_fog_opacity
		fog_overlay.color = overlay_color
		darken_scene(current_weather_intensity * weather_darkening_factor * 0.3)

func darken_scene(amount: float):
	amount = clamp(amount, 0.0, 1.0)
	
	if global_canvas_modulate:
		var base_color = Color(1.0, 1.0, 1.0)
		var darken_factor = 1.0 - amount
		global_canvas_modulate.color = base_color * darken_factor
	
	if lighting_system and lighting_system.has_method("set_global_light_energy"):
		lighting_system.set_global_light_energy(1.0 - amount * 0.5)

func set_heat_distortion(enabled: bool, intensity: float = 0.5):
	heat_distortion_active = enabled
	
	if not enable_post_processing or not heat_distortion:
		return
		
	heat_distortion.visible = enabled
	
	if enabled and heat_distortion.material is ShaderMaterial:
		var shader_mat = heat_distortion.material as ShaderMaterial
		if shader_mat.has_shader_parameter("intensity"):
			shader_mat.set_shader_parameter("intensity", intensity * 0.02)

func set_film_grain(enabled: bool, intensity: float = 0.5):
	film_grain_active = enabled
	
	if not enable_post_processing or not film_grain:
		return
		
	film_grain.visible = enabled
	
	if enabled and film_grain.material is ShaderMaterial:
		var shader_mat = film_grain.material as ShaderMaterial
		if shader_mat.has_shader_parameter("grain_amount"):
			shader_mat.set_shader_parameter("grain_amount", intensity * 0.1)

func set_vignette(enabled: bool, intensity: float = 0.5):
	vignette_active = enabled
	
	if not enable_post_processing or not vignette:
		return
		
	vignette.visible = enabled
	
	if enabled and vignette.material is ShaderMaterial:
		var shader_mat = vignette.material as ShaderMaterial
		if shader_mat.has_shader_parameter("vignette_intensity"):
			shader_mat.set_shader_parameter("vignette_intensity", intensity * 0.4)

func set_chromatic_aberration(enabled: bool, intensity: float = 0.5):
	chromatic_aberration_active = enabled
	
	if not enable_post_processing or not chromatic_aberration:
		return
		
	chromatic_aberration.visible = enabled
	
	if enabled and chromatic_aberration.material is ShaderMaterial:
		var shader_mat = chromatic_aberration.material as ShaderMaterial
		if shader_mat.has_shader_parameter("aberration_amount"):
			shader_mat.set_shader_parameter("aberration_amount", intensity * 0.01)

func reset_all_weather():
	if dust_storm_particles:
		dust_storm_particles.emitting = false
	
	if rain_particles:
		rain_particles.emitting = false
	
	if snow_particles:
		snow_particles.emitting = false
	
	if fog_overlay:
		fog_overlay.visible = false
	
	if region_type == "desert":
		set_heat_distortion(false)
	
	darken_scene(0.0)

func set_region_type(type: String):
	region_type = type
	
	if region_type == "desert" and current_weather_type == "clear":
		set_heat_distortion(true, 0.3)
	elif heat_distortion_active and current_weather_type == "clear":
		set_heat_distortion(false)

func _on_weather_changed(type: String, intensity: float):
	if type != current_weather_type:
		set_weather(WeatherType[type.to_upper()], intensity)
	elif intensity != current_weather_intensity:
		set_weather_intensity(intensity) 
