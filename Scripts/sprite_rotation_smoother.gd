extends Node
class_name SpriteRotationSmoother

@export var target_sprite_path: NodePath
@export var enabled: bool = true
@export_range(1, 8) var quality_level: int = 2
@export var preserve_pixel_art: bool = true
@export var auto_adjust_scale: bool = true
@export var rotation_only: bool = true
@export var pixel_perfect_mode: bool = true

var target_sprite: Sprite2D = null
var original_texture: Texture2D = null
var rotation_cache: Dictionary = {}
var current_angle_key: String = ""
var cached_versions: int = 36

func _ready():
	if not target_sprite_path.is_empty():
		target_sprite = get_node_or_null(target_sprite_path)
		_initialize_sprite()
	
	SignalBus.connect("sprite_smoothing_settings_changed", Callable(self, "_on_smoothing_settings_changed"))

func _initialize_sprite():
	if not target_sprite or not target_sprite is Sprite2D:
		return
	
	original_texture = target_sprite.texture
	if not original_texture:
		return
	
	if preserve_pixel_art:
		target_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		target_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	if enabled and quality_level > 1:
		precache_rotations()

func _process(_delta):
	if not enabled or not target_sprite or not original_texture:
		return
	
	if rotation_only:
		_handle_rotation_smoothing()

func precache_rotations():
	if not original_texture:
		return
	
	rotation_cache.clear()
	var angle_step = 360.0 / cached_versions
	
	for i in range(cached_versions):
		var angle = i * angle_step
		var angle_key = "%.1f" % angle
		
		if rotation_cache.has(angle_key):
			continue
		var rotated_texture = _create_rotated_texture(original_texture, angle)
		rotation_cache[angle_key] = rotated_texture

func _handle_rotation_smoothing():
	var current_angle = fmod(abs(target_sprite.rotation_degrees), 360.0)
	
	var angle_step = 360.0 / cached_versions
	var index = round(current_angle / angle_step)
	index = wrapi(index, 0, cached_versions)
	var closest_angle = index * angle_step
	var angle_key = "%.1f" % closest_angle
	if angle_key != current_angle_key:
		current_angle_key = angle_key
		
		if rotation_cache.has(angle_key):
			target_sprite.texture = rotation_cache[angle_key]
		else:
			var rotated_texture = _create_rotated_texture(original_texture, closest_angle)
			rotation_cache[angle_key] = rotated_texture
			target_sprite.texture = rotated_texture
		target_sprite.rotation_degrees = 0

func _create_rotated_texture(texture: Texture2D, angle: float) -> Texture2D:
	if not texture:
		return null
	
	var image = texture.get_image()
	
	if quality_level <= 1:
		image.rotate(deg_to_rad(angle))
	else:
		var temp_image = image.duplicate()
		
		var scale_factor = quality_level
		var new_size = Vector2i(image.get_width() * scale_factor, image.get_height() * scale_factor)
		temp_image.resize(new_size.x, new_size.y, Image.INTERPOLATE_NEAREST)
		
		temp_image.rotate(deg_to_rad(angle))
		if pixel_perfect_mode:
			temp_image.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_NEAREST)
		else:
			temp_image.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_LANCZOS)
		
		image = temp_image
	
	return ImageTexture.create_from_image(image)

func set_enabled(is_enabled: bool):
	enabled = is_enabled
	
	if target_sprite and original_texture:
		if enabled:
			_handle_rotation_smoothing()
		else:

			target_sprite.texture = original_texture
			target_sprite.rotation_degrees = fmod(abs(target_sprite.rotation_degrees), 360.0)
			current_angle_key = ""

func set_quality(level: int):
	quality_level = clamp(level, 1, 8)
	

	rotation_cache.clear()
	current_angle_key = ""
	
	if enabled:
		precache_rotations()
		_handle_rotation_smoothing()

func set_pixel_art_mode(preserve: bool):
	preserve_pixel_art = preserve
	
	if target_sprite:
		if preserve_pixel_art:
			target_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		else:
			target_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func register_sprite(sprite: Sprite2D):
	if sprite and sprite is Sprite2D:
		target_sprite = sprite
		_initialize_sprite()

func _on_smoothing_settings_changed(is_enabled: bool, quality: int, preserve_pixels: bool):
	set_enabled(is_enabled)
	set_quality(quality)
	set_pixel_art_mode(preserve_pixels) 