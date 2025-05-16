extends Node

var light_texture_path = "res://assets/Lights/light_texture.png"
var default_radius = 256
var default_gradient_colors = [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
var default_gradient_offsets = [0.0, 1.0]

func _ready():
	generate_default_light_texture()

func generate_default_light_texture():
	var file_check = FileAccess.file_exists(light_texture_path)
	if file_check:
		Log.info("LightTextureGenerator: Light texture already exists")
		return
		
	Log.info("LightTextureGenerator: Creating default light texture")
	
	var img = Image.create(default_radius * 2, default_radius * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(default_radius, default_radius)
	var gradient = create_radial_gradient()
	
	for x in range(default_radius * 2):
		for y in range(default_radius * 2):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			var norm_dist = min(dist / default_radius, 1.0)
			var color = gradient.sample(norm_dist)
			img.set_pixel(x, y, color)
	
	var error = img.save_png(light_texture_path)
	if error != OK:
		Log.err("LightTextureGenerator: Failed to save light texture")
	else:
		Log.info("LightTextureGenerator: Light texture created successfully")

func create_radial_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.colors = default_gradient_colors
	gradient.offsets = default_gradient_offsets
	return gradient 