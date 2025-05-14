extends Node

signal interaction_available(object_type, object_id)
signal interaction_performed(object_type, object_id)

const INTERACTION_TYPES = {
	"COVER": {
		"prompt": "Take Cover",
		"icon": "shield",
		"duration": 0.5
	},
	"FLIP": {
		"prompt": "Flip",
		"icon": "flip",
		"duration": 0.8
	},
	"PUSH": {
		"prompt": "Push",
		"icon": "push",
		"duration": 0.6
	},
	"CLIMB": {
		"prompt": "Climb",
		"icon": "climb",
		"duration": 1.0
	},
	"HIDE": {
		"prompt": "Hide",
		"icon": "hide",
		"duration": 0.7
	},
	"TURN_OFF": {
		"prompt": "Turn Off",
		"icon": "power",
		"duration": 0.3
	},
	"TURN_ON": {
		"prompt": "Turn On",
		"icon": "power",
		"duration": 0.3
	},
	"OPEN": {
		"prompt": "Open",
		"icon": "open",
		"duration": 0.5
	},
	"CLOSE": {
		"prompt": "Close",
		"icon": "close",
		"duration": 0.5
	}
}

var player = null
var interactable_objects = {}
var current_interaction = null
var interaction_timer = 0.0
var interaction_in_progress = false

func _ready():
	SignalBus.player_event.connect(_on_player_event)

func _process(delta):
	if interaction_in_progress:
		process_interaction(delta)

func register_interactable(object_node, type, properties = {}):
	if not object_node or not object_node is Node2D:
		return false
		
	if not type in INTERACTION_TYPES:
		push_warning("Unknown interaction type: " + type)
		return false
	
	var object_id = object_node.get_instance_id()
	
	interactable_objects[object_id] = {
		"node": object_node,
		"type": type,
		"properties": properties,
		"available": true
	}
	
	if not object_node.is_connected("tree_exiting", _on_object_removed.bind(object_id)):
		object_node.tree_exiting.connect(_on_object_removed.bind(object_id))
	
	return true

func unregister_interactable(object_node):
	if not object_node:
		return
	
	var object_id = object_node.get_instance_id()
	
	if object_id in interactable_objects:
		interactable_objects.erase(object_id)

func _on_object_removed(object_id):
	if object_id in interactable_objects:
		interactable_objects.erase(object_id)

func _on_player_event(event_type, data):
	if event_type == "object_interaction":
		var object_id = data.object_id
		interact_with_object(object_id)

func interact_with_object(object_id):
	if not object_id in interactable_objects or interaction_in_progress:
		return
	
	var interactable = interactable_objects[object_id]
	
	if not interactable.available or not is_instance_valid(interactable.node):
		return
	
	var interaction_type = interactable.type
	
	if not can_perform_interaction(object_id, interaction_type):
		SignalBus.notification_requested.emit(
			"Can't Interact",
			"Cannot " + INTERACTION_TYPES[interaction_type].prompt + " right now",
			"warning",
			2.0
		)
		return
	
	current_interaction = {
		"object_id": object_id,
		"type": interaction_type,
		"node": interactable.node,
		"properties": interactable.properties
	}
	
	interaction_in_progress = true
	interaction_timer = 0.0
	
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	SignalBus.player_state_changed.emit("interaction")
	position_for_interaction()
	play_interaction_animation()

func can_perform_interaction(object_id, _interaction_type):
	if not player:
		return false
	
	if not object_id in interactable_objects:
		return false
	
	var interactable = interactable_objects[object_id]
	
	if not is_instance_valid(interactable.node):
		return false
	
	var distance = player.global_position.distance_to(interactable.node.global_position)
	var max_distance = player.interaction_distance if player.has_method("get_interaction_distance") else 50.0
	
	if distance > max_distance:
		return false
	
	return true

func position_for_interaction():
	if not player or not current_interaction or not is_instance_valid(current_interaction.node):
		return
	
	var object_position = current_interaction.node.global_position
	var interaction_type = current_interaction.type
	
	var property_position = Vector2.ZERO
	if "interaction_position" in current_interaction.properties:
		property_position = current_interaction.properties.interaction_position
	
	if property_position != Vector2.ZERO:
		player.global_position = object_position + property_position
	else:
		var direction = (player.global_position - object_position).normalized()
		var distance = 20.0
		player.global_position = object_position + direction * distance

func play_interaction_animation():
	if not player or not current_interaction:
		return
		
	var animation_name = "interact"
	if "animation" in current_interaction.properties:
		animation_name = current_interaction.properties.animation
	
	if player.sprite and player.sprite.has_method("play"):
		player.sprite.play(animation_name)
	
	var object_node = current_interaction.node
	if object_node.has_method("play_interaction_animation"):
		object_node.play_interaction_animation(current_interaction.type)

func process_interaction(delta):
	if not current_interaction:
		complete_interaction()
		return
	
	interaction_timer += delta
	
	var duration = INTERACTION_TYPES[current_interaction.type].duration
	if "duration" in current_interaction.properties:
		duration = current_interaction.properties.duration
	
	if interaction_timer >= duration:
		complete_interaction()

func complete_interaction():
	if not current_interaction:
		reset_interaction_state()
		return
	
	var object_id = current_interaction.object_id
	var interaction_type = current_interaction.type
	var object_node = current_interaction.node
	
	if is_instance_valid(object_node) and object_node.has_method("on_interaction_complete"):
		object_node.on_interaction_complete(interaction_type, player)
	
	apply_interaction_effects()
	
	interaction_performed.emit(interaction_type, object_id)
	SignalBus.player_event.emit("interaction_completed", {
		"type": interaction_type,
		"object_id": object_id
	})
	
	reset_interaction_state()
	
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(true)
	
	SignalBus.player_state_changed.emit("normal")

func apply_interaction_effects():
	if not current_interaction or not is_instance_valid(current_interaction.node):
		return
	
	var interaction_type = current_interaction.type
	var object_node = current_interaction.node
	
	match interaction_type:
		"COVER":
			if player and player.has_method("enter_cover"):
				player.enter_cover(object_node)
			
		"FLIP":
			if object_node.has_method("flip"):
				object_node.flip()
			elif object_node is RigidBody2D:
				apply_physics_impulse(object_node, Vector2(0, -200))
		
		"PUSH":
			if object_node.has_method("push"):
				object_node.push(player.player_facing())
			elif object_node is RigidBody2D:
				apply_physics_impulse(object_node, player.player_facing() * 200)
		
		"HIDE":
			if player and player.has_method("hide_in_object"):
				player.hide_in_object(object_node)
		
		"TURN_OFF":
			if object_node.has_method("turn_off"):
				object_node.turn_off()
			elif object_node is Light2D:
				object_node.enabled = false
		
		"TURN_ON":
			if object_node.has_method("turn_on"):
				object_node.turn_on()
			elif object_node is Light2D:
				object_node.enabled = true
		
		"OPEN":
			if object_node.has_method("open"):
				object_node.open()
		
		"CLOSE":
			if object_node.has_method("close"):
				object_node.close()

func apply_physics_impulse(body, impulse):
	if body is RigidBody2D:
		body.apply_central_impulse(impulse)

func reset_interaction_state():
	interaction_in_progress = false
	current_interaction = null
	interaction_timer = 0.0

func setup_player(player_node):
	player = player_node 