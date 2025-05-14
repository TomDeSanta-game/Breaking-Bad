extends CharacterBody2D

@export var move_speed: float = 60.0
@export var interaction_distance: float = 80.0 
@export var dialogue_timeline: String = "jesse_intro"

signal show_interaction_prompt(text)
signal hide_interaction_prompt

var player = null
var can_interact = false
var following_player = false
var follow_distance = 50.0

func _ready():
	add_to_group("NPC")
	add_to_group("Jesse")

func _physics_process(delta):
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player <= interaction_distance:
			if not can_interact:
				can_interact = true
				show_prompt("Press E to talk to Jesse")
		elif can_interact:
			can_interact = false
			hide_prompt()
		
		if following_player:
			follow_behavior(delta)

func show_prompt(text):
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("show_interaction_prompt"):
		signal_bus.emit_signal("show_interaction_prompt", text)
	else:
		show_interaction_prompt.emit(text)

func hide_prompt():
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.has_signal("hide_interaction_prompt"):
		signal_bus.emit_signal("hide_interaction_prompt")
	else:
		hide_interaction_prompt.emit()

func follow_behavior(_delta):
	if player:
		var distance = global_position.distance_to(player.global_position)
		
		if distance > follow_distance:
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * move_speed
		else:
			velocity = Vector2.ZERO
		
		move_and_slide()
		
		if velocity.length() > 0:
			$AnimatedSprite2D.play("walk")
			if velocity.x < 0:
				$AnimatedSprite2D.flip_h = true
			else:
				$AnimatedSprite2D.flip_h = false
		else:
			$AnimatedSprite2D.play("idle")

func _unhandled_input(event):
	if event.is_action_pressed("interact") and can_interact:
		Dialogic.start_timeline(dialogue_timeline)
		get_viewport().set_input_as_handled()

func set_player_reference(p):
	player = p

func start_following():
	following_player = true
	
func stop_following():
	following_player = false
	velocity = Vector2.ZERO 