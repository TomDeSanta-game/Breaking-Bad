extends Node

func _ready():
	Log.info("NormalMappingManager: Initializing built-in normal mapping")
	apply_normal_mapping_settings()

func apply_normal_mapping_settings():
	var render_settings = RenderingServer.get_rendering_device()
	if render_settings:
		Log.info("NormalMappingManager: Configuring global normal mapping settings")
	
	configure_project_lights()

func configure_project_lights():
	var light_nodes = get_tree().get_nodes_in_group("dynamic_lights")
	for light in light_nodes:
		if light is PointLight2D:
			configure_light(light)
	
	Log.info("NormalMappingManager: Configured lights for normal mapping")

func configure_light(light: PointLight2D):
	if not light.is_in_group("normal_map_light"):
		light.add_to_group("normal_map_light")
		
	if light.shadow_enabled:
		light.shadow_filter = 1
		light.shadow_filter_smooth = 1.5
	
	if light.texture_scale <= 0:
		light.texture_scale = 2.0

func apply_normal_map_to_sprite(sprite: Sprite2D, normal_texture: Texture2D):
	if sprite and normal_texture:
		var canvas_texture = CanvasTexture.new()
		canvas_texture.diffuse_texture = sprite.texture
		canvas_texture.normal_texture = normal_texture
		canvas_texture.specular_color = Color(0.6, 0.6, 0.6, 1)
		canvas_texture.specular_shininess = 0.5
		sprite.texture = canvas_texture

func register_sprite_with_normal_map(sprite_path: String, normal_map_path: String):
	var sprite = get_node(sprite_path)
	if sprite is Sprite2D:
		var normal_texture = load(normal_map_path)
		if normal_texture:
			apply_normal_map_to_sprite(sprite, normal_texture)
			return true
	return false

func setup_animated_sprite_normal_map(animated_sprite: AnimatedSprite2D, normal_texture: Texture2D):
	if animated_sprite and normal_texture:
		var sprite_frames = animated_sprite.sprite_frames
		if sprite_frames:
			var animation_names = sprite_frames.get_animation_names()
			for anim_name in animation_names:
				for frame_idx in range(sprite_frames.get_frame_count(anim_name)):
					var texture = sprite_frames.get_frame_texture(anim_name, frame_idx)
					var canvas_texture = CanvasTexture.new()
					canvas_texture.diffuse_texture = texture
					canvas_texture.normal_texture = normal_texture
					canvas_texture.specular_color = Color(0.6, 0.6, 0.6, 1)
					canvas_texture.specular_shininess = 0.5
					sprite_frames.set_frame(anim_name, frame_idx, canvas_texture)
			return true
	return false 