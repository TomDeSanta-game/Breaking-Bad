extends Node

var radius = 120.0
var speed = 1.5
var time = 0.0
var center_position = Vector2.ZERO
var vertical_offset = 0.0
var vertical_speed = 2.0
var max_vertical_offset = 30.0

func _ready():
	var parent_light = get_parent()
	if parent_light is PointLight2D:
		center_position = parent_light.position

func _process(delta):
	time += delta * speed
	vertical_offset = sin(time * vertical_speed) * max_vertical_offset
	
	var parent_light = get_parent()
	if parent_light is PointLight2D:
		var new_position = center_position + Vector2(
			cos(time) * radius,
			sin(time) * radius + vertical_offset
		)
		parent_light.position = new_position
		
		# Slightly vary the energy and color for dynamic lighting effect
		parent_light.energy = 1.0 + abs(sin(time * 0.5)) * 0.5
		
		var hue_shift = (sin(time * 0.2) + 1.0) * 0.5 * 0.2  # Small hue shift
		parent_light.color = Color.from_hsv(hue_shift + 0.7, 0.6, 0.9, 1.0) 