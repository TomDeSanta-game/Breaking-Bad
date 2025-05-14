extends Node

func _enter_tree():
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))

func _ready():
	call_deferred("fix_white_screen")
	call_deferred("create_controlled_transition")

func fix_white_screen():
	print("Global white screen fix running...")
	
	# Remove unwanted white screens only (not all post-processing)
	get_tree().call_group("white_screens", "queue_free")
	
	# Remove only problem shader materials
	remove_problem_shaders()
	
	var viewport = get_viewport()
	if viewport:
		viewport.transparent_bg = false
		viewport.canvas_cull_mask = 0xFFFFFFFF
	
	# Fix the post-processing but don't disable it completely
	var post_process = get_node_or_null("/root/UnifiedPostProcess")
	if post_process and post_process.has_method("set_enabled"):
		# Just make sure it doesn't show white screens
		post_process.grain_enabled = false
		post_process.aberration_enabled = false
		print("Fixed UnifiedPostProcess settings")
	
	# Remove all white screens
	var root = get_tree().root
	var found_screens = find_and_transform_white_nodes(root)
	
	# Force immediate screen update
	RenderingServer.force_draw(true)
	
	print("White screen fix completed. Found and removed screens: " + str(found_screens))

func disable_shader_materials():
	print("Disabling all shader materials")
	process_node_shaders(get_tree().root)

func remove_problem_shaders():
	print("Removing only problematic shader materials")
	process_problem_shaders(get_tree().root)

func process_problem_shaders(node):
	# Only remove white or bright-colored shader materials
	if node is CanvasItem and node.material and node.material is ShaderMaterial:
		# Check if this is a bright/white shader that needs to be disabled
		var shader_name = ""
		if node.material.shader and node.material.shader.get_path():
			shader_name = node.material.shader.get_path()
		
		if "white" in shader_name.to_lower() or "bright" in shader_name.to_lower() or "flash" in shader_name.to_lower():
			node.material = null
			print("Disabled problematic shader on: " + str(node.name))
	
	for child in node.get_children():
		process_problem_shaders(child)

func process_node_shaders(node):
	if node is CanvasItem and node.material and node.material is ShaderMaterial:
		node.material = null
		print("Disabled shader on: " + str(node.name))
	
	for child in node.get_children():
		process_node_shaders(child)

func find_and_transform_white_nodes(node):
	var found_count = 0
	
	if node is ColorRect and (node.color.r > 0.9 and node.color.g > 0.9 and node.color.b > 0.9):
		node.color = Color(0, 0, 0, 1.0)
		node.visible = false
		print("Removed white screen: " + str(node.name))
		found_count += 1
	
	for child in node.get_children():
		found_count += find_and_transform_white_nodes(child)
	
	return found_count

func clean_up_post_processing():
	var visual_nodes = get_tree().get_nodes_in_group("post_processing")
	for node in visual_nodes:
		node.queue_free()
		
	var unified_process = get_node_or_null("/root/UnifiedPostProcess")
	if unified_process:
		unified_process.process_mode = Node.PROCESS_MODE_DISABLED

func create_controlled_transition():
	# Wait a short moment to ensure the scene is properly ready
	await get_tree().create_timer(0.1).timeout
	
	# Create our own clean transition overlay
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128  # Very high layer to be on top
	add_child(canvas_layer)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1.0)  # Start with black
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)
	
	# Create a smooth transition from black to gray and then fade out
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0.15, 0.15, 0.15, 1.0), 0.3)  # Black to dark gray
	tween.tween_property(overlay, "modulate", Color(1, 1, 1, 0), 0.5)  # Fade out
	tween.tween_callback(func(): canvas_layer.queue_free())  # Clean up when done
