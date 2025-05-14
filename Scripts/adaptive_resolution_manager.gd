extends Node
class_name AdaptiveResolutionManager

@export var enabled: bool = true
@export var default_scale: float = 1.0
@export var transition_speed: float = 2.0
@export var pixel_perfect: bool = true
@export var affect_ui: bool = false

enum ResolutionState {
	NORMAL,
	ZOOMED_IN,
	ZOOMED_OUT,
	DRAMATIC,
	BLURRED,
	CUSTOM
}

var viewport: Viewport
var current_state: ResolutionState = ResolutionState.NORMAL
var target_scale: float = 1.0
var current_scale: float = 1.0
var original_size: Vector2i
var base_resolution: Vector2i
var resolution_material: ShaderMaterial
var transition_active: bool = false
var transition_timer: float = 0.0
var transition_duration: float = 0.5
var previous_scale: float = 1.0
var viewport_container: Node = null

const PIXEL_SHADER = """
shader_type canvas_item;

uniform float pixel_size = 1.0;
uniform bool enable = true;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	if (enable) {
		vec2 uv = SCREEN_UV;
		vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 0));
		vec2 pixel = floor(SCREEN_UV * screen_size / pixel_size) * pixel_size / screen_size;
		COLOR = texture(SCREEN_TEXTURE, pixel);
	} else {
		COLOR = texture(SCREEN_TEXTURE, SCREEN_UV);
	}
}
"""

func _ready():
	viewport = get_viewport()
	if viewport:
		original_size = viewport.size
		base_resolution = original_size
		_setup_viewport_container()
		_setup_resolution_material()
	
	current_scale = default_scale
	target_scale = default_scale
	
	SignalBus.connect("resolution_state_changed", Callable(self, "_on_resolution_state_changed"))
	SignalBus.connect("custom_resolution_requested", Callable(self, "_on_custom_resolution_requested"))

func _process(delta):
	if not enabled or not viewport:
		return
	
	if transition_active:
		transition_timer += delta
		var t = min(transition_timer / transition_duration, 1.0)
		t = _ease_in_out(t)
		current_scale = lerp(previous_scale, target_scale, t)
		
		if transition_timer >= transition_duration:
			transition_active = false
			current_scale = target_scale
	
	_update_resolution(delta)

func _setup_viewport_container():
	pass

func _setup_resolution_material():
	resolution_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = PIXEL_SHADER
	resolution_material.shader = shader
	
	resolution_material.set_shader_parameter("pixel_size", current_scale)
	resolution_material.set_shader_parameter("enable", pixel_perfect)

func _update_resolution(_delta):
	if resolution_material:
		resolution_material.set_shader_parameter("pixel_size", current_scale)
	
	if not pixel_perfect:
		var new_size = Vector2i(
			int(base_resolution.x / current_scale),
			int(base_resolution.y / current_scale)
		)
		
		if viewport.size != new_size:
			viewport.size = new_size
			
			if viewport_container and "stretch" in viewport_container:
				viewport_container.set("stretch", true)

func set_resolution_state(state: ResolutionState, duration: float = 0.5):
	previous_scale = current_scale
	transition_timer = 0.0
	transition_duration = max(0.1, duration)
	transition_active = true
	current_state = state
	
	match state:
		ResolutionState.NORMAL:
			target_scale = default_scale
		ResolutionState.ZOOMED_IN:
			target_scale = default_scale * 2.0
		ResolutionState.ZOOMED_OUT:
			target_scale = default_scale * 0.5
		ResolutionState.DRAMATIC:
			target_scale = default_scale * 3.0
		ResolutionState.BLURRED:
			target_scale = default_scale * 0.75
		ResolutionState.CUSTOM:
			pass

func set_custom_resolution_scale(scale: float, duration: float = 0.5):
	previous_scale = current_scale
	target_scale = max(0.1, scale)
	transition_timer = 0.0
	transition_duration = max(0.1, duration)
	transition_active = true
	current_state = ResolutionState.CUSTOM

func reset_resolution(duration: float = 0.5):
	set_resolution_state(ResolutionState.NORMAL, duration)

func set_pixel_perfect(enable: bool):
	pixel_perfect = enable
	
	if resolution_material:
		resolution_material.set_shader_parameter("enable", pixel_perfect)

func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _on_resolution_state_changed(state: int, duration: float):
	if state >= 0 and state < ResolutionState.size():
		set_resolution_state(state, duration)

func _on_custom_resolution_requested(scale: float, duration: float):
	set_custom_resolution_scale(scale, duration)

func create_dramatic_moment(duration: float = 2.0, _intensity: float = 1.0):
	set_resolution_state(ResolutionState.DRAMATIC, 0.2)
	
	await get_tree().create_timer(duration * 0.8).timeout
	reset_resolution(duration * 0.2) 