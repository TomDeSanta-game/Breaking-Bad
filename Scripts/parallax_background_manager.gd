extends Node2D
class_name ParallaxBackgroundManager

@export var enabled: bool = true
@export var follow_target_path: NodePath
@export_range(0.0, 1.0) var default_strength: float = 1.0
@export var auto_scroll: bool = false
@export var auto_scroll_speed: Vector2 = Vector2(20.0, 0.0)
@export var offset_scale: float = 1.0

var layers: Array[ParallaxLayer] = []
var target: Node2D = null
var previous_target_position: Vector2
var camera: Camera2D = null
var strength: float = 1.0

func _ready():
	_setup_layers()
	
	if not follow_target_path.is_empty():
		target = get_node_or_null(follow_target_path)
		if target:
			previous_target_position = target.global_position
	

	SignalBus.connect("parallax_settings_changed", Callable(self, "_on_parallax_settings_changed"))
	

	strength = default_strength

func _setup_layers():

	for child in get_children():
		if child is ParallaxLayer:
			layers.append(child)
			

			child.motion_scale *= offset_scale

func _process(delta):
	if not enabled:
		return
	

	if auto_scroll:
		for layer in layers:
			layer.motion_offset += auto_scroll_speed * delta * layer.motion_scale
	

	if target:
		var target_movement = target.global_position - previous_target_position
		
		for layer in layers:

			var adjusted_motion_scale = layer.motion_scale * strength
			layer.motion_offset -= target_movement * adjusted_motion_scale
			
		previous_target_position = target.global_position

func set_strength(new_strength: float):
	strength = clamp(new_strength, 0.0, 1.0)

func set_enabled(is_enabled: bool):
	enabled = is_enabled

func _on_parallax_settings_changed(enabled_value: bool, strength_value: float):
	set_enabled(enabled_value)
	set_strength(strength_value)

func add_layer(texture: Texture2D, motion_scale: Vector2, z_index: int = 0) -> ParallaxLayer:
	var layer = ParallaxLayer.new()
	layer.motion_scale = motion_scale * offset_scale
	layer.z_index = z_index
	
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	
	layer.add_child(sprite)
	add_child(layer)
	layers.append(layer)
	
	return layer 