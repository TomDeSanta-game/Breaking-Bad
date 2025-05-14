extends Node2D

@onready var player = $Player
@onready var skyler = $"NPC's/Skyler"
@onready var walt_jr = $"NPC's/WaltJR"

func _ready() -> void:
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	
	player.visible = true
	skyler.visible = true
	walt_jr.visible = true
	
	fix_white_screen()
	
	if player.has_method("hide_ui"):
		player.hide_ui(true)
	
	# Temporarily comment out Dialogic to see if it works without it
	#Dialogic.timeline_ended.connect(on_dialog_timeline_ended)
	#register_console_commands()
	#car.body_entered.connect(_on_car_body_entered)
	await get_tree().create_timer(1.0).timeout
	
	# Enable player control instead of waiting for dialog to end
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	if player.has_method("hide_ui"):
		player.hide_ui(false)

func fix_white_screen():
	var post_process = get_node_or_null("/root/UnifiedPostProcess")
	if post_process and post_process.has_method("set_enabled"):
		post_process.set_enabled(false)
	
	var effects_manager = get_node_or_null("/root/VisualEffectsManager")
	if effects_manager:
		for child in effects_manager.get_children():
			if child is ColorRect:
				child.visible = false
	
	var white_rect = find_white_rect(get_tree().root)
	if white_rect:
		white_rect.visible = false

func find_white_rect(node):
	if node is ColorRect and node.color.r > 0.9 and node.color.g > 0.9 and node.color.b > 0.9:
		return node
	
	for child in node.get_children():
		var result = find_white_rect(child)
		if result:
			return result
	
	return null