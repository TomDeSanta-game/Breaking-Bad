@tool
extends Node

signal atmosphere_changed(atmosphere_name)

const AtmosphereType = {
	"NORMAL": "normal",
	"TENSE": "tense",
	"NIGHTTIME": "nighttime",
	"INDOOR": "indoor",
	"LAB": "lab",
	"DESERT": "desert",
	"HALLUCINATION": "hallucination"
}

@export var apply_immediately: bool = true
@export var enable_post_processing: bool = true
@export var current_atmosphere: String = AtmosphereType["NORMAL"]:
	set(value):
		if current_atmosphere != value:
			current_atmosphere = value
			if apply_immediately:
				set_atmosphere(value)
				atmosphere_changed.emit(value)

@export_group("Color Grading")
@export var saturation_factor: float = 1.0
@export var contrast_factor: float = 1.0
@export var brightness_factor: float = 1.0

@export_group("Vignette")
@export var vignette_intensity: float = 0.0
@export var vignette_color: Color = Color(0.0, 0.0, 0.0, 1.0)

@export_group("Color Overlays")
@export var overlay_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var overlay_blend_mode: int = 0

var canvas_layer: CanvasLayer
var color_rect: ColorRect
var atmosphere_settings: Dictionary = {}
var active_effects: Dictionary = {}
var is_initialized: bool = false

func _ready():
	if Engine.is_editor_hint():
		set_process(false)
		return
		
	initialize_atmosphere_settings()
	create_canvas_layer()
	create_post_process_rect()
	
	if apply_immediately:
		set_atmosphere(current_atmosphere)
	
	is_initialized = true

func _process(_delta):
	if Engine.is_editor_hint() || !is_initialized:
		return

func initialize_atmosphere_settings():
	atmosphere_settings = {
		AtmosphereType["NORMAL"]: {
			"color_grading": {
				"saturation": 1.0,
				"contrast": 1.0,
				"brightness": 1.0,
				"temperature": 0.0
			},
			"vignette": {
				"intensity": 0.2,
				"color": Color(0.0, 0.0, 0.0, 1.0)
			},
			"chromatic_aberration": {
				"intensity": 0.0
			},
			"film_grain": {
				"intensity": 0.05,
				"colored": false
			},
			"overlay": {
				"color": Color(0.0, 0.0, 0.0, 0.0),
				"blend_mode": 0
			}
		},
		AtmosphereType["TENSE"]: {
			"color_grading": {
				"saturation": 0.9,
				"contrast": 1.1,
				"brightness": 0.95,
				"temperature": 0.1
			},
			"vignette": {
				"intensity": 0.4,
				"color": Color(0.0, 0.0, 0.0, 1.0)
			},
			"chromatic_aberration": {
				"intensity": 0.1
			},
			"film_grain": {
				"intensity": 0.15,
				"colored": false
			},
			"overlay": {
				"color": Color(0.7, 0.2, 0.1, 0.05),
				"blend_mode": 1
			}
		},
		AtmosphereType["NIGHTTIME"]: {
			"color_grading": {
				"saturation": 0.8,
				"contrast": 1.2,
				"brightness": 0.7,
				"temperature": -0.2
			},
			"vignette": {
				"intensity": 0.6,
				"color": Color(0.0, 0.0, 0.1, 1.0)
			},
			"chromatic_aberration": {
				"intensity": 0.0
			},
			"film_grain": {
				"intensity": 0.2,
				"colored": false
			},
			"overlay": {
				"color": Color(0.0, 0.0, 0.2, 0.1),
				"blend_mode": 2
			}
		},
		AtmosphereType["INDOOR"]: {
			"color_grading": {
				"saturation": 0.9,
				"contrast": 1.0,
				"brightness": 0.9,
				"temperature": 0.1
			},
			"vignette": {
				"intensity": 0.3,
				"color": Color(0.0, 0.0, 0.0, 1.0)
			},
			"chromatic_aberration": {
				"intensity": 0.0
			},
			"film_grain": {
				"intensity": 0.1,
				"colored": false
			},
			"overlay": {
				"color": Color(1.0, 0.9, 0.7, 0.05),
				"blend_mode": 3
			}
		},
		AtmosphereType["LAB"]: {
			"color_grading": {
				"saturation": 0.8,
				"contrast": 1.1,
				"brightness": 1.1,
				"temperature": 0.0
			},
			"vignette": {
				"intensity": 0.4,
				"color": Color(0.0, 0.0, 0.0, 1.0)
			},
			"chromatic_aberration": {
				"intensity": 0.05
			},
			"film_grain": {
				"intensity": 0.08,
				"colored": false
			},
			"overlay": {
				"color": Color(0.2, 0.8, 0.7, 0.05),
				"blend_mode": 2
			}
		},
		AtmosphereType["DESERT"]: {
			"color_grading": {
				"saturation": 1.1,
				"contrast": 1.2,
				"brightness": 1.1,
				"temperature": 0.2
			},
			"vignette": {
				"intensity": 0.3,
				"color": Color(0.3, 0.1, 0.0, 1.0)
			},
			"chromatic_aberration": {
				"intensity": 0.05
			},
			"film_grain": {
				"intensity": 0.1,
				"colored": true
			},
			"overlay": {
				"color": Color(0.8, 0.6, 0.3, 0.1),
				"blend_mode": 1
			}
		},
		AtmosphereType["HALLUCINATION"]: {
			"color_grading": {
				"saturation": 1.4,
				"contrast": 1.2,
				"brightness": 1.0,
				"temperature": 0.0
			},
			"vignette": {
				"intensity": 0.7,
				"color": Color(0.5, 0.0, 0.5, 1.0)
			},
			"chromatic_aberration": {
				"intensity": 0.5
			},
			"film_grain": {
				"intensity": 0.3,
				"colored": true
			},
			"overlay": {
				"color": Color(0.5, 0.0, 0.5, 0.2),
				"blend_mode": 4
			}
		}
	}

func create_canvas_layer():
	if canvas_layer != null:
		return
		
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "AtmosphereEffects"
	canvas_layer.layer = 100
	canvas_layer.follow_viewport_enabled = true
	add_child(canvas_layer)

func create_post_process_rect():
	if color_rect != null || canvas_layer == null:
		return
		
	color_rect = ColorRect.new()
	color_rect.name = "PostProcessRect"
	canvas_layer.add_child(color_rect)
	
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.offset_right = 0
	color_rect.offset_bottom = 0
	
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	
	shader.code = """
		shader_type canvas_item;
		
		uniform float saturation : hint_range(0.0, 2.0) = 1.0;
		uniform float contrast : hint_range(0.0, 2.0) = 1.0;
		uniform float brightness : hint_range(0.0, 2.0) = 1.0;
		uniform float temperature : hint_range(-1.0, 1.0) = 0.0;
		
		uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
		uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
		
		uniform float chromatic_aberration : hint_range(0.0, 5.0) = 0.0;
		
		uniform float film_grain_intensity : hint_range(0.0, 1.0) = 0.0;
		uniform bool colored_grain = false;
		
		uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
		uniform int blend_mode = 0;
		
		uniform float z_depth : hint_range(0.0, 1.0) = 0.99;
		
		float rand(vec2 co) {
			return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
		}
		
		vec3 temperature_adjust(vec3 color, float temp_value) {
			vec3 warm = vec3(1.0, 0.8, 0.6);
			vec3 cool = vec3(0.6, 0.8, 1.0);
			
			if (temp_value > 0.0) {
				return color * mix(vec3(1.0), warm, temp_value);
			} else {
				return color * mix(vec3(1.0), cool, -temp_value);
			}
		}
		
		vec3 apply_overlay(vec3 base, vec4 overlay, int mode) {
			vec3 result = base;
			float alpha = overlay.a;
			
			if (mode == 0) {
				result = mix(base, overlay.rgb, alpha);
			} else if (mode == 1) {
				result = mix(base, base * overlay.rgb, alpha);
			} else if (mode == 2) {
				result = mix(base, 1.0 - (1.0 - base) * (1.0 - overlay.rgb), alpha);
			} else if (mode == 3) {
				vec3 a = 2.0 * base * overlay.rgb;
				vec3 b = 1.0 - 2.0 * (1.0 - base) * (1.0 - overlay.rgb);
				vec3 overlay_result = vec3(
					base.r < 0.5 ? a.r : b.r,
					base.g < 0.5 ? a.g : b.g,
					base.b < 0.5 ? a.b : b.b
				);
				result = mix(base, overlay_result, alpha);
			} else if (mode == 4) {
				vec3 soft_light = vec3(
					base.r < 0.5 ? (2.0 * base.r * overlay.r + base.r * base.r * (1.0 - 2.0 * overlay.r)) : (sqrt(base.r) * (2.0 * overlay.r - 1.0) + 2.0 * base.r * (1.0 - overlay.r)),
					base.g < 0.5 ? (2.0 * base.g * overlay.g + base.g * base.g * (1.0 - 2.0 * overlay.g)) : (sqrt(base.g) * (2.0 * overlay.g - 1.0) + 2.0 * base.g * (1.0 - overlay.g)),
					base.b < 0.5 ? (2.0 * base.b * overlay.b + base.b * base.b * (1.0 - 2.0 * overlay.b)) : (sqrt(base.b) * (2.0 * overlay.b - 1.0) + 2.0 * base.b * (1.0 - overlay.b))
				);
				result = mix(base, soft_light, alpha);
			}
			
			return result;
		}
		
		void fragment() {
			vec4 original = texture(TEXTURE, UV);
			
			float aberration = chromatic_aberration * 0.01;
			float aberration_amount = floor(aberration * 100.0) / 100.0;
			vec2 uv_r = UV + vec2(aberration_amount, 0.0);
			vec2 uv_b = UV - vec2(aberration_amount, 0.0);
			
			float r = texture(TEXTURE, uv_r).r;
			float g = original.g;
			float b = texture(TEXTURE, uv_b).b;
			vec3 color = vec3(r, g, b);
			
			color = color * brightness;
			
			color = (color - 0.5) * contrast + 0.5;
			
			float gray = dot(color, vec3(0.299, 0.587, 0.114));
			color = mix(vec3(gray), color, saturation);
			
			color = temperature_adjust(color, temperature);
			
			float grain_value = rand(UV + TIME) * film_grain_intensity;
			grain_value = floor(grain_value * 100.0) / 100.0;
			
			if (colored_grain) {
				float r_offset = rand(UV + vec2(TIME, 0.0)) * 0.2 - 0.1;
				float g_offset = rand(UV + vec2(0.0, TIME)) * 0.2 - 0.1;
				float b_offset = rand(UV + vec2(TIME, TIME)) * 0.2 - 0.1;
				color.r += r_offset * film_grain_intensity;
				color.g += g_offset * film_grain_intensity;
				color.b += b_offset * film_grain_intensity;
			} else {
				color += grain_value - (film_grain_intensity * 0.5);
			}
			
			color = apply_overlay(color, overlay_color, blend_mode);
			
			float vignette = smoothstep(0.8, 0.2, length(UV - vec2(0.5)));
			color = mix(color, vignette_color.rgb, vignette * vignette_intensity * vignette_color.a);
			
			COLOR = vec4(color, original.a);
		}
	"""
	
	shader_material.shader = shader
	color_rect.material = shader_material
	
	update_shader_parameters({
		"saturation": 1.0,
		"contrast": 1.0,
		"brightness": 1.0,
		"temperature": 0.0,
		"vignette_intensity": 0.0,
		"vignette_color": Color(0.0, 0.0, 0.0, 1.0),
		"chromatic_aberration": 0.0,
		"film_grain_intensity": 0.0,
		"colored_grain": false,
		"overlay_color": Color(0.0, 0.0, 0.0, 0.0),
		"blend_mode": 0,
		"z_depth": 0.99
	})

func set_atmosphere(atmosphere_name: String):
	if !is_initialized:
		return
		
	if atmosphere_settings.has(atmosphere_name):
		var settings = atmosphere_settings[atmosphere_name]
		
		var params = {
			"saturation": settings.color_grading.saturation,
			"contrast": settings.color_grading.contrast,
			"brightness": settings.color_grading.brightness,
			"temperature": settings.color_grading.temperature,
			"vignette_intensity": settings.vignette.intensity,
			"vignette_color": settings.vignette.color,
			"chromatic_aberration": settings.chromatic_aberration.intensity,
			"film_grain_intensity": settings.film_grain.intensity,
			"colored_grain": settings.film_grain.colored,
			"overlay_color": settings.overlay.color,
			"blend_mode": settings.overlay.blend_mode
		}
		
		update_shader_parameters(params)
		
		saturation_factor = settings.color_grading.saturation
		contrast_factor = settings.color_grading.contrast
		brightness_factor = settings.color_grading.brightness
		vignette_intensity = settings.vignette.intensity
		vignette_color = settings.vignette.color
		overlay_color = settings.overlay.color
		overlay_blend_mode = settings.overlay.blend_mode

func update_shader_parameters(params: Dictionary):
	if !is_initialized || !color_rect || !color_rect.material:
		return
	
	var shader_material = color_rect.material as ShaderMaterial
	
	for param in params:
		var value = snappedf(params[param], 0.01) if typeof(params[param]) == TYPE_FLOAT else params[param]
		
		if shader_material.has_shader_parameter(param):
			shader_material.set_shader_parameter(param, value)

func disable_effects():
	if !is_initialized:
		return
		
	active_effects = {}
	
	var default_params = {
		"saturation": 1.0,
		"contrast": 1.0,
		"brightness": 1.0,
		"temperature": 0.0,
		"vignette_intensity": 0.0,
		"vignette_color": Color(0.0, 0.0, 0.0, 1.0),
		"chromatic_aberration": 0.0,
		"film_grain_intensity": 0.0,
		"colored_grain": false,
		"overlay_color": Color(0.0, 0.0, 0.0, 0.0),
		"blend_mode": 0
	}
	
	update_shader_parameters(default_params)

func enable_effect(effect_name: String, intensity: float = 1.0, duration: float = 0.0):
	if !is_initialized:
		return
		
	active_effects[effect_name] = {
		"intensity": intensity,
		"time_remaining": duration if duration > 0.0 else -1.0
	}
	
	match effect_name:
		"chromatic_aberration":
			update_shader_parameters({"chromatic_aberration": intensity * 2.0})
		"film_grain":
			update_shader_parameters({
				"film_grain_intensity": intensity * 0.3,
				"colored_grain": false
			})
		"vignette":
			update_shader_parameters({
				"vignette_intensity": intensity * 0.7,
				"vignette_color": Color(0.0, 0.0, 0.0, 1.0)
			})
		"desaturation":
			update_shader_parameters({"saturation": 1.0 - (intensity * 0.5)})
		"contrast_boost":
			update_shader_parameters({"contrast": 1.0 + (intensity * 0.3)})
		"warm_filter":
			update_shader_parameters({"temperature": intensity * 0.3})
		"cool_filter":
			update_shader_parameters({"temperature": -intensity * 0.3})
		"dream":
			update_shader_parameters({
				"saturation": 0.8,
				"brightness": 1.1,
				"chromatic_aberration": 0.3,
				"vignette_intensity": 0.5,
				"vignette_color": Color(0.2, 0.0, 0.4, 1.0),
				"overlay_color": Color(0.5, 0.3, 0.8, 0.1),
				"blend_mode": 2
			})
		"drugged":
			update_shader_parameters({
				"saturation": 1.3,
				"contrast": 1.2,
				"chromatic_aberration": 0.6 * intensity,
				"vignette_intensity": 0.5 * intensity,
				"vignette_color": Color(0.5, 0.0, 0.5, 1.0),
				"overlay_color": Color(0.5, 0.0, 0.5, 0.15 * intensity),
				"blend_mode": 4
			})
		"fear":
			update_shader_parameters({
				"saturation": 0.7,
				"contrast": 1.2,
				"vignette_intensity": 0.6 * intensity,
				"vignette_color": Color(0.3, 0.0, 0.0, 1.0),
				"overlay_color": Color(0.7, 0.0, 0.0, 0.1 * intensity),
				"blend_mode": 1
			})

func disable_effect(effect_name: String):
	if !is_initialized || !active_effects.has(effect_name):
		return
		
	active_effects.erase(effect_name)
	
	set_atmosphere(current_atmosphere)

func update_effect_timing(delta: float):
	if !is_initialized || active_effects.is_empty():
		return
		
	var effects_to_disable = []
	
	for effect_name in active_effects:
		var effect_data = active_effects[effect_name]
		
		if effect_data.time_remaining > 0:
			effect_data.time_remaining -= delta
			
			if effect_data.time_remaining <= 0:
				effects_to_disable.append(effect_name)
	
	for effect_name in effects_to_disable:
		disable_effect(effect_name)

func _on_tension_level_changed(level_name, _previous_level):
	if !is_initialized:
		return
		
	match level_name:
		"MINIMAL":
			set_atmosphere(AtmosphereType["NORMAL"])
		"LOW":
			set_atmosphere(AtmosphereType["NORMAL"])
		"MEDIUM":
			set_atmosphere(AtmosphereType["TENSE"])
		"HIGH":
			set_atmosphere(AtmosphereType["TENSE"])
			enable_effect("chromatic_aberration", 0.3, 3.0)
		"CRITICAL":
			set_atmosphere(AtmosphereType["HALLUCINATION"])
			enable_effect("chromatic_aberration", 0.5)
			enable_effect("film_grain", 0.7) 