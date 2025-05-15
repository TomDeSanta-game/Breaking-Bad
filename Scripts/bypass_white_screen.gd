extends Node

func _enter_tree():
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))

func _ready():
	call_deferred("fix_white_screen")
	call_deferred("create_transition")

func fix_white_screen():
	get_tree().call_group("white_screens", "queue_free")
	process_problem_shaders(get_tree().root)
	
	var viewport = get_viewport()
	if viewport:
		viewport.transparent_bg = false
		viewport.canvas_cull_mask = 0xFFFFFFFF
	
	var post_process = get_node_or_null("/root/UnifiedPostProcess")
	if post_process and post_process.has_method("set_enabled"):
		post_process.grain_enabled = false
		post_process.aberration_enabled = false
	
	find_and_transform_white_nodes(get_tree().root)
	RenderingServer.force_draw(true)

func process_problem_shaders(node):
	if node is CanvasItem and node.material and node.material is ShaderMaterial:
		var shader_name = ""
		if node.material.shader and node.material.shader.get_path():
			shader_name = node.material.shader.get_path().to_lower()
			if "white" in shader_name or "bright" in shader_name or "flash" in shader_name:
				node.material = null
	
	for child in node.get_children():
		process_problem_shaders(child)

func find_and_transform_white_nodes(node):
	if node is ColorRect and (node.color.r > 0.9 and node.color.g > 0.9 and node.color.b > 0.9):
		node.color = Color(0, 0, 0, 1.0)
		node.visible = false
	
	for child in node.get_children():
		find_and_transform_white_nodes(child)

func create_transition():
	await get_tree().create_timer(0.1).timeout
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128
	add_child(canvas_layer)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)
	
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0.15, 0.15, 0.15, 1.0), 0.3)
	tween.tween_property(overlay, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): canvas_layer.queue_free())
