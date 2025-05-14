extends Node

signal takedown_performed(target_npc, takedown_type)
signal takedown_failed(target_npc, reason)

enum TakedownType {
	CHOKE,
	KNOCKOUT,
	LETHAL
}

const TAKEDOWN_RANGE = 50.0
const STEALTH_ANGLE_THRESHOLD = 45.0
const TAKEDOWN_DURATION = {
	TakedownType.CHOKE: 2.5,
	TakedownType.KNOCKOUT: 1.2,
	TakedownType.LETHAL: 0.8
}

const TAKEDOWN_NOISE_LEVEL = {
	TakedownType.CHOKE: 5.0,
	TakedownType.KNOCKOUT: 15.0,
	TakedownType.LETHAL: 10.0
}

const TAKEDOWN_HEAT_LEVEL = {
	TakedownType.CHOKE: 5.0,
	TakedownType.KNOCKOUT: 10.0,
	TakedownType.LETHAL: 25.0
}

var player = null
var takedown_in_progress = false
var current_target = null
var takedown_timer = 0.0
var current_takedown_type = TakedownType.CHOKE
var player_original_position = Vector2.ZERO
var target_original_position = Vector2.ZERO
var target_original_rotation = 0.0

func _ready():
	SignalBus.player_event.connect(_on_player_event)

func _process(delta):
	if takedown_in_progress:
		process_takedown(delta)
	else:
		find_potential_targets()

func _on_player_event(event_type, data):
	if event_type == "stealth_takedown_initiated":
		var target_npc = data.target
		var takedown_type = data.type if data.has("type") else TakedownType.CHOKE
		
		initiate_takedown(target_npc, takedown_type)

func find_potential_targets():
	if not player or takedown_in_progress:
		return
		
	var player_facing = player.player_facing()
	var space_state = player.get_world_2d().direct_space_state
	
	var query = PhysicsRayQueryParameters2D.new()
	query.from = player.global_position
	query.to = player.global_position + player_facing * TAKEDOWN_RANGE
	query.collision_mask = 4
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider.is_in_group("npc"):
		var npc = result.collider
		
		if is_target_valid_for_takedown(npc):
			highlight_takedown_target(npc)
			
			if Input.is_action_just_pressed("stealth_takedown"):
				var takedown_type = determine_takedown_type()
				initiate_takedown(npc, takedown_type)
		else:
			current_target = null
			SignalBus.hide_interaction_prompt.emit()
	else:
		current_target = null
		SignalBus.hide_interaction_prompt.emit()

func is_target_valid_for_takedown(npc):
	if not npc or not npc.has_method("is_aware_of_player"):
		return false
		
	if npc.is_aware_of_player():
		return false
	
	var to_target = npc.global_position - player.global_position
	var target_facing = npc.get_facing_direction() if npc.has_method("get_facing_direction") else Vector2.ZERO
	
	var angle = rad_to_deg(target_facing.angle_to(to_target))
	return abs(angle) > 180 - STEALTH_ANGLE_THRESHOLD

func determine_takedown_type():
	var takedown_type = TakedownType.CHOKE
	
	if player.has_method("get_equipped_weapon"):
		var weapon = player.get_equipped_weapon()
		
		if weapon and "knife" in weapon.to_lower():
			takedown_type = TakedownType.LETHAL
	
	if Input.is_action_pressed("sprint"):
		takedown_type = TakedownType.KNOCKOUT
		
	return takedown_type

func highlight_takedown_target(npc):
	if current_target != npc:
		current_target = npc
		
		var prompt_text = "Choke Out"
		var takedown_type = determine_takedown_type()
		
		match takedown_type:
			TakedownType.KNOCKOUT:
				prompt_text = "Knock Out"
			TakedownType.LETHAL:
				prompt_text = "Eliminate"
		
		SignalBus.show_interaction_prompt.emit(prompt_text)

func initiate_takedown(target_npc, takedown_type):
	if takedown_in_progress or not target_npc:
		return
		
	if not is_target_valid_for_takedown(target_npc):
		takedown_failed.emit(target_npc, "Target is aware of player")
		return
	
	takedown_in_progress = true
	current_target = target_npc
	current_takedown_type = takedown_type
	takedown_timer = 0.0
	
	SignalBus.hide_interaction_prompt.emit()
	
	player_original_position = player.global_position
	target_original_position = target_npc.global_position
	target_original_rotation = target_npc.rotation if target_npc.has_method("get_rotation") else 0.0
	
	if player.has_method("set_process_input"):
		player.set_process_input(false)
	
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	if target_npc.has_method("set_physics_process"):
		target_npc.set_physics_process(false)
	
	position_for_takedown()
	
	SignalBus.player_state_changed.emit("takedown")
	SignalBus.camera_effect_started.emit("takedown_zoom")
	
	match current_takedown_type:
		TakedownType.CHOKE:
			play_takedown_animation("choke")
		TakedownType.KNOCKOUT:
			play_takedown_animation("knockout")
		TakedownType.LETHAL:
			play_takedown_animation("lethal")

func position_for_takedown():
	if not player or not current_target:
		return
		
	var target_position = current_target.global_position
	var to_target = (target_position - player.global_position).normalized()
	
	var offset = to_target * 15.0
	player.global_position = target_position - offset

func play_takedown_animation(animation_name):
	if not player or not current_target:
		return
	
	if player.sprite and player.sprite.has_method("play"):
		player.sprite.play(animation_name)
	
	if current_target.has_method("play_animation"):
		current_target.play_animation("takedown_" + animation_name)

func process_takedown(delta):
	if not player or not current_target:
		complete_takedown()
		return
	
	takedown_timer += delta
	
	var duration = TAKEDOWN_DURATION[current_takedown_type]
	if takedown_timer >= duration:
		complete_takedown()

func complete_takedown():
	if not current_target:
		reset_takedown_state()
		return
	
	var _noise_level = TAKEDOWN_NOISE_LEVEL[current_takedown_type]
	var heat_level = TAKEDOWN_HEAT_LEVEL[current_takedown_type]
	
	SignalBus.vfx_started.emit("takedown_complete", current_target.global_position)
	
	if current_target.has_method("on_takedown"):
		current_target.on_takedown(current_takedown_type)
	
	if current_target.has_method("knock_out"):
		current_target.knock_out(TAKEDOWN_DURATION[current_takedown_type] * 10)
	
	if current_takedown_type == TakedownType.LETHAL and current_target.has_method("kill"):
		current_target.kill()
	
	if player.has_method("add_heat"):
		player.add_heat(heat_level)
	
	takedown_performed.emit(current_target, current_takedown_type)
	
	reset_takedown_state()
	
	if player.has_method("set_process_input"):
		player.set_process_input(true)
	
	if player.has_method("set_physics_process"):
		player.set_physics_process(true)
	
	SignalBus.player_state_changed.emit("normal")
	SignalBus.camera_effect_ended.emit("takedown_zoom")

func reset_takedown_state():
	takedown_in_progress = false
	current_target = null
	takedown_timer = 0.0

func setup_player(player_node):
	player = player_node 