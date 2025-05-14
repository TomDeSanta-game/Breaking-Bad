extends Node2D

func _ready():
	# Create a sprite with a basic color
	var sprite = Sprite2D.new()
	sprite.modulate = Color(1.0, 0.5, 0.2)  # Orange color
	
	# Create a texture
	var image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(image)
	
	# Set up the sprite
	sprite.texture = texture
	sprite.position = Vector2(500, 300)
	sprite.scale = Vector2(5, 5)
	
	# Add to scene
	add_child(sprite)
	
	print("Test scene loaded successfully with a visible orange sprite") 