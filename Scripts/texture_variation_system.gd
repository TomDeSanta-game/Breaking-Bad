extends Node

class_name TextureVariationSystem

enum VariationMethod {
	ROTATE,
	FLIP,
	COLOR_SHIFT,
	SCALE,
	RANDOM_TILES
}

@export var variation_method: VariationMethod = VariationMethod.RANDOM_TILES
@export var target_group: String = "tileable_sprites"
@export var enabled: bool = true
@export_range(0.0, 1.0) var variation_strength: float = 0.3
@export var seed_value: int = 0

var rng = RandomNumberGenerator.new()
var registered_sprites: Array = []
var original_textures: Dictionary = {}
var variation_atlases: Dictionary = {}

func _ready():
	rng.seed = seed_value if seed_value != 0 else Time.get_unix_time_from_system()

	if not target_group.is_empty():
		call_deferred("register_sprites_in_group")
	
	SignalBus.connect("texture_variation_settings_changed", Callable(self, "_on_variation_settings_changed"))

func register_sprites_in_group():
	var sprites = get_tree().get_nodes_in_group(target_group)
	for sprite in sprites:
		register_sprite(sprite)

func register_sprite(sprite: Node):
	if sprite is Sprite2D or sprite is TextureRect or sprite is TileMap:
		if not registered_sprites.has(sprite):
			registered_sprites.append(sprite)
			

			if sprite is Sprite2D:
				original_textures[sprite] = sprite.texture
			elif sprite is TextureRect:
				original_textures[sprite] = sprite.texture
			

			if enabled:
				apply_variation_to_sprite(sprite)

func unregister_sprite(sprite: Node):
	if registered_sprites.has(sprite):
		registered_sprites.erase(sprite)
		

		if original_textures.has(sprite):
			if sprite is Sprite2D:
				sprite.texture = original_textures[sprite]
			elif sprite is TextureRect:
				sprite.texture = original_textures[sprite]
				
			original_textures.erase(sprite)

func apply_variation_to_all():
	for sprite in registered_sprites:
		apply_variation_to_sprite(sprite)

func apply_variation_to_sprite(sprite: Node):
	match variation_method:
		VariationMethod.ROTATE:
			_apply_rotation_variation(sprite)
		VariationMethod.FLIP:
			_apply_flip_variation(sprite)
		VariationMethod.COLOR_SHIFT:
			_apply_color_variation(sprite)
		VariationMethod.SCALE:
			_apply_scale_variation(sprite)
		VariationMethod.RANDOM_TILES:
			_apply_random_tile_variation(sprite)

func _apply_rotation_variation(sprite: Node):
	if sprite is Sprite2D:
		var angles = [0, 90, 180, 270]
		var selected_angle = angles[rng.randi() % angles.size()]
		sprite.rotation_degrees = selected_angle
	elif sprite is TextureRect:
		pass

func _apply_flip_variation(sprite: Node):
	if sprite is Sprite2D:
		sprite.flip_h = rng.randf() < 0.5
		sprite.flip_v = rng.randf() < 0.5
	elif sprite is TextureRect:
		pass

func _apply_color_variation(sprite: Node):

	var hue_shift = rng.randf_range(-0.05, 0.05) * variation_strength
	var saturation_shift = rng.randf_range(-0.1, 0.1) * variation_strength
	var value_shift = rng.randf_range(-0.1, 0.1) * variation_strength
	

	var color = Color(1, 1, 1, 1)
	var hsv = color.to_hsv()
	hsv.h = fmod(hsv.h + hue_shift, 1.0)
	hsv.s = clamp(hsv.s + saturation_shift, 0.0, 1.0)
	hsv.v = clamp(hsv.v + value_shift, 0.0, 1.0)
	color = Color.from_hsv(hsv.h, hsv.s, hsv.v, 1.0)
	
	if sprite is Sprite2D or sprite is TextureRect:
		sprite.modulate = color

func _apply_scale_variation(sprite: Node):
	if sprite is Sprite2D:
		var scale_factor = 1.0 + rng.randf_range(-0.1, 0.1) * variation_strength
		sprite.scale = Vector2(scale_factor, scale_factor)

func _apply_random_tile_variation(sprite: Node):
	if sprite is TileMap:
		pass
	else:

		if sprite is Sprite2D and sprite.texture:
			var texture_size = sprite.texture.get_size()
			if sprite.region_enabled:

				var region = sprite.region_rect
				var offset_x = rng.randi_range(-8, 8) * variation_strength
				var offset_y = rng.randi_range(-8, 8) * variation_strength
				region.position.x = clamp(region.position.x + offset_x, 0, texture_size.x - region.size.x)
				region.position.y = clamp(region.position.y + offset_y, 0, texture_size.y - region.size.y)
				sprite.region_rect = region
			else:

				sprite.region_enabled = true
				var region_size = Vector2(texture_size.x, texture_size.y)
				sprite.region_rect = Rect2(Vector2.ZERO, region_size)

func create_variation_atlas(texture: Texture2D, variation_count: int = 4) -> Array:

	var variations = []
	if texture == null:
		return variations
		

	for i in range(variation_count):
		var image = texture.get_image()
		

		match i % 4:
			0:
				_apply_image_hue_shift(image, rng.randf_range(-0.05, 0.05) * variation_strength)
			1:
				image.flip_x()
			2:
				image.flip_y()
			3:
				image.flip_x()
				image.flip_y()
		

		var new_texture = ImageTexture.create_from_image(image)
		variations.append(new_texture)
	
	return variations

func _apply_image_hue_shift(image: Image, shift_amount: float):

	image.lock()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel = image.get_pixel(x, y)
			var hsv = pixel.to_hsv()
			hsv.h = fmod(hsv.h + shift_amount, 1.0)
			var new_pixel = Color.from_hsv(hsv.h, hsv.s, hsv.v, pixel.a)
			image.set_pixel(x, y, new_pixel)
	image.unlock()

func set_enabled(is_enabled: bool):
	enabled = is_enabled
	if enabled:
		apply_variation_to_all()
	else:

		for sprite in registered_sprites:
			if original_textures.has(sprite):
				if sprite is Sprite2D:
					sprite.texture = original_textures[sprite]
					sprite.rotation_degrees = 0
					sprite.flip_h = false
					sprite.flip_v = false
					sprite.modulate = Color(1, 1, 1, 1)
					sprite.scale = Vector2(1, 1)
					if sprite.region_enabled and not sprite.has_meta("original_region_enabled"):
						sprite.region_enabled = false
				elif sprite is TextureRect:
					sprite.texture = original_textures[sprite]
					sprite.modulate = Color(1, 1, 1, 1)

func set_variation_strength(strength: float):
	variation_strength = clamp(strength, 0.0, 1.0)
	if enabled:
		apply_variation_to_all()

func _on_variation_settings_changed(is_enabled: bool, strength: float):
	set_enabled(is_enabled)
	set_variation_strength(strength) 