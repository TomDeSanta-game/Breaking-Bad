extends Node2D

@onready var player: Node2D = $Player
@onready var car: Area2D = $CarCollidor
@onready var Dialogic = get_node("/root/Dialogic")

var car_entered = false
var quest

func _ready() -> void:
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.hide_ui(true)
	Dialogic.timeline_ended.connect(on_dialog_timeline_ended)
	register_console_commands()
	car.body_entered.connect(_on_car_body_entered)
	await get_tree().create_timer(1.0).timeout
	Dialogic.start("walter-skyler-jr-1st-inter")

func register_console_commands() -> void:
	if LimboConsole:
		LimboConsole.register_command(end_dialogic, "end_dialogic")

func end_dialogic(_args = null) -> String:
	if Dialogic.current_timeline:
		Dialogic.end_timeline()
		return "Timeline ended"
	return "No active timeline"

func on_dialog_timeline_ended() -> void:
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	player.hide_ui(false)
	
	quest = QuestSystem.get_quest("GetToCar")
	if quest:
		QuestSystem.start_quest(quest)
		player.show_objective(quest.quest_objective)

func _on_car_body_entered(body: Node2D) -> void:
	if car_entered:
		return
	
	if body == player:
		car_entered = true
		QuestSystem.complete_quest(quest)
		player.complete_objective()
		player.hide_ui(true)
		
		await get_tree().create_timer(1.0).timeout
		SceneManager.change_scene("res://Scenes/RideWithHank.tscn")
