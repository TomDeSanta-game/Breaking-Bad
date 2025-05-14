extends Node2D
@export var grid_size = 32
@export var grid_color = Color(0.5, 0.5, 0.5, 0.2)
@export var grid_visible = false
func _ready():
	update_grid_visibility(grid_visible)
func update_grid_visibility(visible_state: bool):
	grid_visible = visible_state
	visible = grid_visible
	queue_redraw()
func toggle_grid():
	update_grid_visibility(!grid_visible)
func _draw():
	if not visible:
		return
	var viewport_size = Vector2(1152, 648)
	for x in range(0, int(viewport_size.x) + 1, grid_size):
		draw_line(Vector2(x, 0), Vector2(x, viewport_size.y), grid_color)
	for y in range(0, int(viewport_size.y) + 1, grid_size):
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), grid_color)
