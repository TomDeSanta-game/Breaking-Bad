extends Node
class_name SubpixelAnimator

@export var target_sprite_path: NodePath
@export var enabled: bool = true
@export_range(0.1, 5.0) var animation_speed: float = 1.0
@export_range(0.01, 1.0) var amplitude: float = 0.2
@export var animation_type: String = "breathing"
@export var apply_to_shader: bool = false
@export var shader_param_name: String = "offset"

var target_sprite: Node2D = null
var original_position: Vector2 = Vector2.ZERO
var time_passed: float = 0.0
var material: ShaderMaterial = null

func _ready():
	if not target_sprite_path.is_empty():
		target_sprite = get_node_or_null(target_sprite_path)
		if target_sprite:
			original_position = target_sprite.position
			
			if apply_to_shader and target_sprite is CanvasItem:
				material = target_sprite.material as ShaderMaterial
	
	SignalBus.connect("subpixel_animation_settings_changed", Callable(self, "_on_subpixel_settings_changed"))

func _process(delta):
	if not enabled or not target_sprite:
		return
	
	time_passed += delta * animation_speed
	
	match animation_type:
		"breathing":
			_apply_breathing_animation()
		"hovering":
			_apply_hovering_animation()
		"subtle_sway":
			_apply_subtle_sway_animation()
		"pulse":
			_apply_pulse_animation()
		"heartbeat":
			_apply_heartbeat_animation()

func _apply_breathing_animation():
	var breathing_offset = Vector2(0, sin(time_passed) * amplitude)
	
	if apply_to_shader and material and not shader_param_name.is_empty():
		material.set_shader_parameter(shader_param_name, breathing_offset)
	else:
		target_sprite.position = original_position + breathing_offset

func _apply_hovering_animation():
	var hovering_offset = Vector2(
		sin(time_passed * 0.7) * amplitude * 0.3,
		sin(time_passed) * amplitude
	)
	
	if apply_to_shader and material and not shader_param_name.is_empty():
		material.set_shader_parameter(shader_param_name, hovering_offset)
	else:
		target_sprite.position = original_position + hovering_offset

func _apply_subtle_sway_animation():
	var sway_offset = Vector2(
		sin(time_passed * 0.5) * amplitude,
		cos(time_passed * 0.3) * amplitude * 0.5
	)
	
	if apply_to_shader and material and not shader_param_name.is_empty():
		material.set_shader_parameter(shader_param_name, sway_offset)
	else:
		target_sprite.position = original_position + sway_offset

func _apply_pulse_animation():
	var scale_factor = 1.0 + sin(time_passed * 2.0) * amplitude * 0.1
	var pulse_offset = Vector2.ZERO
	
	if target_sprite is Node2D:
		target_sprite.scale = Vector2(scale_factor, scale_factor)
	
	if apply_to_shader and material and not shader_param_name.is_empty():
		material.set_shader_parameter(shader_param_name, pulse_offset)

func _apply_heartbeat_animation():
	var t = fmod(time_passed, 3.0)
	var scale_factor = 1.0
	
	if t < 0.2:
		scale_factor = 1.0 + sin(t * PI / 0.2) * amplitude * 0.15
	elif t < 0.4:
		scale_factor = 1.0 + sin((t - 0.2) * PI / 0.2) * amplitude * 0.08
	
	if target_sprite is Node2D:
		target_sprite.scale = Vector2(scale_factor, scale_factor)
	
	if apply_to_shader and material and not shader_param_name.is_empty():
		material.set_shader_parameter(shader_param_name, Vector2(scale_factor - 1.0, 0))

func reset_to_original():
	if target_sprite:
		if not apply_to_shader:
			target_sprite.position = original_position
		
		if target_sprite is Node2D:
			target_sprite.scale = Vector2.ONE
		
		if apply_to_shader and material and not shader_param_name.is_empty():
			material.set_shader_parameter(shader_param_name, Vector2.ZERO)

func set_enabled(is_enabled: bool):
	enabled = is_enabled
	
	if not enabled:
		reset_to_original()

func set_amplitude(value: float):
	amplitude = clamp(value, 0.01, 1.0)

func set_speed(value: float):
	animation_speed = clamp(value, 0.1, 5.0)

func set_animation_type(anim_type: String):
	if anim_type in ["breathing", "hovering", "subtle_sway", "pulse", "heartbeat"]:
		animation_type = anim_type
	else:
		animation_type = "breathing"

func register_sprite(sprite: Node2D):
	if sprite:
		target_sprite = sprite
		original_position = sprite.position
		
		if apply_to_shader and sprite is CanvasItem:
			material = sprite.material as ShaderMaterial

func _on_subpixel_settings_changed(is_enabled: bool, anim_type: String, anim_speed: float, anim_amplitude: float):
	set_enabled(is_enabled)
	set_animation_type(anim_type)
	set_speed(anim_speed)
	set_amplitude(anim_amplitude) 