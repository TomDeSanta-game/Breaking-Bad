extends Node

enum CameraEffectType {
	NORMAL,
	TENSION,
	COMBAT,
	DRUNK,
	HALLUCINATION,
	DREAM,
	SURVEILLANCE,
	FOCUS
}

var effect_parameters = {
	CameraEffectType.NORMAL: {
		"trauma_decay": 1.0,
		"trauma": 0.0,
		"max_offset": Vector2(0, 0),
		"max_roll": 0.0,
		"chromatic_aberration": 0.0,
		"vignette": 0.2,
		"vignette_opacity": 0.4,
		"filmgrain": 0.1,
		"saturation": 1.0
	},
	CameraEffectType.TENSION: {
		"trauma_decay": 0.8,
		"trauma": 0.1,
		"max_offset": Vector2(10, 10),
		"max_roll": 0.1,
		"chromatic_aberration": 0.1,
		"vignette": 0.4,
		"vignette_opacity": 0.6,
		"filmgrain": 0.2,
		"saturation": 0.9
	},
	CameraEffectType.COMBAT: {
		"trauma_decay": 0.5,
		"trauma": 0.2,
		"max_offset": Vector2(20, 20),
		"max_roll": 0.15,
		"chromatic_aberration": 0.3,
		"vignette": 0.6,
		"vignette_opacity": 0.7,
		"filmgrain": 0.4,
		"saturation": 1.2
	},
	CameraEffectType.DRUNK: {
		"trauma_decay": 0.2,
		"trauma": 0.3,
		"max_offset": Vector2(30, 30),
		"max_roll": 0.2,
		"chromatic_aberration": 0.5,
		"vignette": 0.3,
		"vignette_opacity": 0.5,
		"filmgrain": 0.3,
		"saturation": 0.8
	},
	CameraEffectType.HALLUCINATION: {
		"trauma_decay": 0.3,
		"trauma": 0.35,
		"max_offset": Vector2(40, 40),
		"max_roll": 0.3,
		"chromatic_aberration": 0.7,
		"vignette": 0.7,
		"vignette_opacity": 0.8,
		"filmgrain": 0.6,
		"saturation": 1.4
	},
	CameraEffectType.DREAM: {
		"trauma_decay": 0.1,
		"trauma": 0.05,
		"max_offset": Vector2(15, 15),
		"max_roll": 0.05,
		"chromatic_aberration": 0.2,
		"vignette": 0.5,
		"vignette_opacity": 0.6,
		"filmgrain": 0.3,
		"saturation": 0.7
	},
	CameraEffectType.SURVEILLANCE: {
		"trauma_decay": 0.9,
		"trauma": 0.0,
		"max_offset": Vector2(5, 5),
		"max_roll": 0.0,
		"chromatic_aberration": 0.1,
		"vignette": 0.8,
		"vignette_opacity": 0.9,
		"filmgrain": 0.7,
		"saturation": 0.5
	},
	CameraEffectType.FOCUS: {
		"trauma_decay": 0.95,
		"trauma": 0.0,
		"max_offset": Vector2(0, 0),
		"max_roll": 0.0,
		"chromatic_aberration": 0.05,
		"vignette": 0.7,
		"vignette_opacity": 0.7,
		"filmgrain": 0.05,
		"saturation": 1.1
	}
}

var current_effect_type = CameraEffectType.NORMAL
var active_camera = null
var post_process_material = null
var last_applied_params = {}
var is_initialized = false
var tension_manager = null

func _ready():
	SignalBus.connect("threshold_crossed", _on_tension_threshold_crossed)
	SignalBus.connect("player_damaged", _on_player_damaged)
	
	call_deferred("initialize")

func initialize():
	if is_initialized:
		return
		
	active_camera = get_viewport().get_camera_2d()
	if !active_camera:
		push_warning("EnhancedCameraEffects: No camera found")
		return
		
	tension_manager = get_node_or_null("/root/TensionManager")
	if !tension_manager:
		push_warning("EnhancedCameraEffects: No tension manager found")
	
	setup_post_processing()
	is_initialized = true

func setup_post_processing():
	var canvas_layer = get_node_or_null("PostProcessingLayer")
	
	if !canvas_layer:
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "PostProcessingLayer"
		canvas_layer.layer = 100
		add_child(canvas_layer)
		
		var color_rect = ColorRect.new()
		color_rect.name = "PostProcessingRect"
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.set_anchor(SIDE_LEFT, 0.0)
		color_rect.set_anchor(SIDE_TOP, 0.0)
		color_rect.set_anchor(SIDE_RIGHT, 1.0)
		color_rect.set_anchor(SIDE_BOTTOM, 1.0)
		color_rect.set_offset(SIDE_LEFT, 0.0)
		color_rect.set_offset(SIDE_TOP, 0.0)
		color_rect.set_offset(SIDE_RIGHT, 0.0)
		color_rect.set_offset(SIDE_BOTTOM, 0.0)
		
		post_process_material = ShaderMaterial.new()
		
		var shader_text = """
		shader_type canvas_item;
		
		uniform float chromatic_aberration = 0.0;
		uniform float vignette_intensity = 0.0;
		uniform float vignette_opacity = 0.5;
		uniform float film_grain = 0.0;
		uniform float saturation = 1.0;
		uniform float z_index = 0.98;
		
		vec4 textureChromaticAberration(sampler2D tex, vec2 uv, float amount) {
			float offset_r = floor(amount * 100.0) / 100.0;
			float offset_b = -offset_r;
			
			float r = texture(tex, uv + vec2(offset_r, 0.0)).r;
			float g = texture(tex, uv).g;
			float b = texture(tex, uv + vec2(offset_b, 0.0)).b;
			return vec4(r, g, b, 1.0);
		}
		
		float random(vec2 uv) {
			return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
		}
		
		void fragment() {
			vec2 uv = UV;
			
			vec4 color = textureChromaticAberration(TEXTURE, uv, chromatic_aberration * 0.01);
			
			float vignette = smoothstep(0.8, 0.2, length(uv - vec2(0.5)));
			color.rgb = mix(color.rgb, color.rgb * (1.0 - vignette * vignette_opacity), vignette_intensity);
			
			float grain_time = floor(TIME * 10.0) / 10.0;
			float grain = random(uv * grain_time) * film_grain;
			grain = floor(grain * 100.0) / 100.0;
			color.rgb = mix(color.rgb, color.rgb + vec3(grain), film_grain);
			
			float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
			color.rgb = mix(vec3(gray), color.rgb, saturation);
			
			COLOR = color;
		}
		"""
		
		var shader = Shader.new()
		shader.code = shader_text
		post_process_material.shader = shader
		
		color_rect.material = post_process_material
		canvas_layer.add_child(color_rect)

func _process(delta):
	if !is_initialized:
		initialize()
		return
		
	if !active_camera:
		return
		
	var post_rect = get_node_or_null("PostProcessingLayer/PostProcessingRect")
	if post_rect:
		if post_rect.size != get_viewport().get_visible_rect().size:
			post_rect.size = get_viewport().get_visible_rect().size
		
	update_camera_parameters(delta)

func update_camera_parameters(delta: float):
	if !active_camera || !post_process_material:
		return
		
	var params = effect_parameters[current_effect_type]
	
	active_camera.decay = params.trauma_decay
	active_camera.max_offset = params.max_offset
	active_camera.max_roll = params.max_roll
	
	if params.trauma > 0:
		active_camera.add_trauma(params.trauma * 0.1 * delta)
	
	var changed = false
	var shader_params = {
		"chromatic_aberration": params.chromatic_aberration,
		"vignette_intensity": params.vignette,
		"film_grain": params.filmgrain,
		"saturation": params.saturation
	}
	
	for param in shader_params:
		var quantized_value = snappedf(shader_params[param], 0.01)
		
		if !last_applied_params.has(param) || last_applied_params[param] != quantized_value:
			last_applied_params[param] = quantized_value
			post_process_material.set_shader_parameter(param, quantized_value)
			changed = true
	
	if changed:
		post_process_material.set_shader_parameter("z_index", 0.98 + randf() * 0.01)

func set_effect(effect_type: CameraEffectType, duration: float = 0.0):
	current_effect_type = effect_type
	SignalBus.camera_effect_started.emit(effect_type)
	
	if duration > 0:
		var timer = get_tree().create_timer(duration)
		await timer.timeout
		current_effect_type = CameraEffectType.NORMAL
		SignalBus.camera_effect_ended.emit(effect_type)

func add_single_trauma(amount: float, direction: Vector2 = Vector2.ZERO):
	if active_camera && active_camera.has_method("add_trauma"):
		active_camera.add_trauma(amount)
		
	if active_camera && active_camera.has_method("add_impact_trauma"):
		active_camera.add_impact_trauma(amount, direction)

func add_impact_at_position(position: Vector2, strength: float = 1.0):
	if !active_camera:
		return
		
	var direction = (position - active_camera.global_position).normalized()
	
	if active_camera.has_method("add_impact_trauma"):
		active_camera.add_impact_trauma(strength * 0.5, direction)
	else:
		active_camera.add_trauma(strength * 0.5)

func _on_tension_threshold_crossed(threshold_name, direction, _threshold_value, _current_value):
	if direction != "up":
		return
		
	match threshold_name:
		"MINIMAL":
			set_effect(CameraEffectType.NORMAL)
		"LOW":
			set_effect(CameraEffectType.TENSION)
		"MEDIUM":
			set_effect(CameraEffectType.TENSION)
			add_single_trauma(0.3)
		"HIGH":
			set_effect(CameraEffectType.COMBAT)
			add_single_trauma(0.5)
		"CRITICAL":
			set_effect(CameraEffectType.HALLUCINATION)
			add_single_trauma(0.8)
			
func _on_player_damaged(damage_amount, attacker_position):
	set_effect(CameraEffectType.COMBAT, 1.5)
	
	if attacker_position:
		add_impact_at_position(attacker_position, min(damage_amount * 0.1, 0.8))
	else:
		add_single_trauma(min(damage_amount * 0.1, 0.8)) 