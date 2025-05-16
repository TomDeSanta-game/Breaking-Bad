extends Control

@onready var objective_panel = $ObjectivePanel
@onready var quest_text = $ObjectivePanel/QuestText
@onready var completion_panel = $ObjectivePanel/CompletionPanel

var current_quest = ""
var is_animating = false
var panel_default_position
var panel_tween

func _ready():
	# Set default position
	panel_default_position = objective_panel.position
	
	# Make sure panel is visible and fully opaque
	objective_panel.modulate.a = 1.0
	objective_panel.visible = true
	
	# Connect signals
	SignalBus.connect("objective_added", start_quest)
	SignalBus.connect("objective_completed", complete_quest)
	
	# Show default objective text
	quest_text.text = "Find a way to make money"
	current_quest = "initial"
	
	Log.info("ObjectiveLabel initialized with default text")

func start_quest(quest_id: String, text: String) -> void:
	if is_animating:
		await get_tree().create_timer(0.5).timeout
		
	is_animating = true
	current_quest = quest_id
	
	quest_text.text = text
	objective_panel.visible = true
	completion_panel.visible = false
	
	objective_panel.position.x = panel_default_position.x - 30
	panel_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	panel_tween.tween_property(objective_panel, "modulate:a", 0, 0)
	panel_tween.tween_property(objective_panel, "modulate:a", 1.0, 0.4)
	panel_tween.parallel().tween_property(objective_panel, "position:x", panel_default_position.x, 0.5)
	
	await panel_tween.finished
	is_animating = false
	
	Log.info("Started quest: ", quest_id)
	SignalBus.emit_signal("player_objective_updated", quest_id, text, false)

func change_quest(quest_id: String, text: String) -> void:
	if is_animating:
		await get_tree().create_timer(0.5).timeout
	
	is_animating = true
	current_quest = quest_id
	
	panel_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	panel_tween.tween_property(quest_text, "modulate:a", 0, 0.2)
	await panel_tween.finished
	
	quest_text.text = text
	panel_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	panel_tween.tween_property(quest_text, "modulate:a", 1.0, 0.3)
	
	var pulse_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(objective_panel, "scale", Vector2(1.05, 1.05), 0.2)
	pulse_tween.tween_property(objective_panel, "scale", Vector2(1.0, 1.0), 0.2)
	
	await panel_tween.finished
	is_animating = false
	
	Log.info("Changed quest: ", quest_id)
	SignalBus.emit_signal("player_objective_updated", quest_id, text, false)

func complete_quest(quest_id: String) -> void:
	if current_quest != quest_id or is_animating:
		return
		
	is_animating = true
	
	completion_panel.visible = true
	completion_panel.modulate.a = 0
	
	panel_tween = create_tween().set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(completion_panel, "modulate:a", 1.0, 0.3)
	
	var success_flash = create_tween().set_loops(3)
	success_flash.tween_property(quest_text, "modulate", Color(0.2, 1, 0.2), 0.15)
	success_flash.tween_property(quest_text, "modulate", Color.WHITE, 0.15)
	
	await success_flash.finished
	
	panel_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	panel_tween.tween_property(objective_panel, "position:x", panel_default_position.x - 30, 0.4)
	panel_tween.parallel().tween_property(objective_panel, "modulate:a", 0, 0.4)
	
	await panel_tween.finished
	
	objective_panel.visible = false
	completion_panel.visible = false
	is_animating = false
	
	current_quest = ""
	
	Log.info("Completed quest: ", quest_id)
	SignalBus.emit_signal("player_objective_updated", quest_id, "", true)

func show_objective_panel(visible_state: bool) -> void:
	if visible_state == objective_panel.visible:
		return
		
	if visible_state:
		objective_panel.visible = true
		panel_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		panel_tween.tween_property(objective_panel, "modulate:a", 1.0, 0.3)
		panel_tween.parallel().tween_property(objective_panel, "position:x", panel_default_position.x, 0.4)
	else:
		panel_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		panel_tween.tween_property(objective_panel, "position:x", panel_default_position.x - 30, 0.3)
		panel_tween.parallel().tween_property(objective_panel, "modulate:a", 0, 0.3)
		await panel_tween.finished
		objective_panel.visible = false 