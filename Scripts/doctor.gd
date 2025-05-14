extends CharacterBody2D

@export var move_speed: float = 50.0
@export var interaction_distance: float = 80.0
@export var dialogue_timeline: String = "diagnosis"

@warning_ignore("unused_signal") signal show_interaction_prompt(text)
@warning_ignore("unused_signal") signal hide_interaction_prompt

var player = null
var can_interact = false

func _ready():
	add_to_group("NPC")
	add_to_group("Doctor")

func _physics_process(_delta):
	if player and global_position.distance_to(player.global_position) <= interaction_distance:
		if not can_interact:
			can_interact = true
			show_prompt("Press E to talk to Doctor")
	elif can_interact:
		can_interact = false
		hide_prompt()

func show_prompt(text):
	SignalBus.show_interaction_prompt.emit(text)

func hide_prompt():
	SignalBus.hide_interaction_prompt.emit()

func _unhandled_input(event):
	if event.is_action_pressed("interact") and can_interact:
		Dialogic.start_timeline(dialogue_timeline)
		get_viewport().set_input_as_handled()

func set_player_reference(p):
	player = p 