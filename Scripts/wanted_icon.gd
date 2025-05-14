extends Control

@export var star_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var star_border_color: Color = Color(0.6, 0, 0, 1.0)
@export var star_border_width: float = 1.5
@export var star_points: int = 5
@export var inner_radius_ratio: float = 0.4
@export var star_rotation: float = 0.0

func _draw():
	var center = size / 2
	var radius = min(size.x, size.y) / 2
	var inner_radius = radius * inner_radius_ratio
	
	var points = []
	var angle_step = TAU / (star_points * 2)
	var angle = star_rotation - PI / 2
	
	for i in range(star_points * 2):
		var point_radius = radius if i % 2 == 0 else inner_radius
		points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
		angle += angle_step
	
	draw_polygon(PackedVector2Array(points), PackedColorArray([star_color]))
	draw_polyline(PackedVector2Array(points + [points[0]]), star_border_color, star_border_width, true)

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		queue_redraw() 