extends Node

enum CALL_STATE { NONE, INCOMING, ACTIVE, ENDED }
enum CALLER_TYPE { FAMILY, BUSINESS, LAW, CARTEL, EMERGENCY }
enum CALL_PRIORITY { LOW, MEDIUM, HIGH, CRITICAL }

var current_call_state = CALL_STATE.NONE
var current_caller_id = ""
var call_start_time = 0
var call_active_time = 0
var is_phone_silenced = false
var is_phone_powered = true
var is_phone_tracked = true
var incoming_call_timer = 0
var incoming_call_duration = 15.0
var active_calls = {}
var missed_calls = []
var call_history = []
var waiting_messages = []
var contacts = {}

var signal_bus
var tension_manager

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")
	tension_manager = get_node_or_null("/root/TensionManager")

func _process(delta):
	if current_call_state == CALL_STATE.INCOMING:
		incoming_call_timer -= delta
		if incoming_call_timer <= 0:
			miss_current_call()
	elif current_call_state == CALL_STATE.ACTIVE:
		call_active_time += delta
		process_active_call(delta)

func register_contact(contact_id, contact_data):
	if not contacts.has(contact_id):
		contacts[contact_id] = contact_data
		return true
	return false

func get_contact(contact_id):
	if contacts.has(contact_id):
		return contacts[contact_id]
	return null

func trigger_incoming_call(caller_id, call_data = {}):
	if not is_phone_powered:
		miss_call(caller_id)
		return false
	
	if current_call_state != CALL_STATE.NONE:
		if call_data.get("priority", CALL_PRIORITY.MEDIUM) > active_calls[current_caller_id].get("priority", CALL_PRIORITY.MEDIUM):
			put_current_call_on_hold()
		else:
			miss_call(caller_id)
			return false
	
	var caller_data = get_contact(caller_id)
	if not caller_data:
		caller_data = {"name": "Unknown", "type": CALLER_TYPE.BUSINESS}
	
	if is_phone_silenced and call_data.get("priority", CALL_PRIORITY.MEDIUM) < CALL_PRIORITY.HIGH:
		miss_call(caller_id)
		return false
	
	current_call_state = CALL_STATE.INCOMING
	current_caller_id = caller_id
	call_data["caller_data"] = caller_data
	active_calls[caller_id] = call_data
	incoming_call_timer = incoming_call_duration
	
	emit_signal("call_incoming", caller_id)
	
	if signal_bus:
		signal_bus.emit_signal("phone_call_incoming", caller_id, caller_data)
	
	apply_reputation_effects(caller_id, "incoming")
	return true

func answer_call(caller_id = ""):
	if caller_id.empty():
		caller_id = current_caller_id
		
	if caller_id.empty() or current_call_state != CALL_STATE.INCOMING:
		return false
	
	current_call_state = CALL_STATE.ACTIVE
	call_start_time = Time.get_ticks_msec()
	call_active_time = 0
	
	emit_signal("call_answered", caller_id)
	
	if signal_bus:
		signal_bus.emit_signal("phone_call_answered", caller_id)
	
	apply_reputation_effects(caller_id, "answered")
	return true

func decline_call(caller_id = ""):
	if caller_id.empty():
		caller_id = current_caller_id
		
	if caller_id.empty() or current_call_state != CALL_STATE.INCOMING:
		return false
	
	current_call_state = CALL_STATE.NONE
	
	var call_data = active_calls[caller_id]
	active_calls.erase(caller_id)
	
	call_history.append({
		"caller_id": caller_id,
		"timestamp": Time.get_unix_time_from_system(),
		"duration": 0,
		"type": "declined",
		"data": call_data
	})
	
	emit_signal("call_declined", caller_id)
	
	if signal_bus:
		signal_bus.emit_signal("phone_call_declined", caller_id)
	
	apply_reputation_effects(caller_id, "declined")
	
	current_caller_id = ""
	return true

func end_call(caller_id = ""):
	if caller_id.empty():
		caller_id = current_caller_id
	
	if caller_id.empty() or not active_calls.has(caller_id):
		return false
		
	if caller_id == current_caller_id and current_call_state == CALL_STATE.ACTIVE:
		current_call_state = CALL_STATE.NONE
		
	var call_data = active_calls[caller_id]
	active_calls.erase(caller_id)
	
	var duration = call_active_time
	
	call_history.append({
		"caller_id": caller_id,
		"timestamp": Time.get_unix_time_from_system(),
		"duration": duration,
		"type": "completed",
		"data": call_data
	})
	
	emit_signal("call_ended", caller_id, duration)
	
	if signal_bus:
		signal_bus.emit_signal("phone_call_ended", caller_id, duration)
	
	apply_reputation_effects(caller_id, "ended", duration)
	
	if caller_id == current_caller_id:
		current_caller_id = ""
	
	return true

func make_call(contact_id, call_data = {}):
	if not is_phone_powered:
		return false
	
	if current_call_state != CALL_STATE.NONE:
		return false
	
	var contact = get_contact(contact_id)
	if not contact:
		return false
	
	current_call_state = CALL_STATE.ACTIVE
	current_caller_id = contact_id
	call_data["outgoing"] = true
	call_data["caller_data"] = contact
	active_calls[contact_id] = call_data
	call_start_time = Time.get_ticks_msec()
	call_active_time = 0
	
	if signal_bus:
		signal_bus.emit_signal("phone_call_started", contact_id, contact)
	
	apply_reputation_effects(contact_id, "outgoing")
	return true

func miss_current_call():
	if current_call_state != CALL_STATE.INCOMING:
		return false
	
	miss_call(current_caller_id)
	return true

func miss_call(caller_id):
	if active_calls.has(caller_id):
		var call_data = active_calls[caller_id]
		active_calls.erase(caller_id)
		
		missed_calls.append({
			"caller_id": caller_id,
			"timestamp": Time.get_unix_time_from_system(),
			"data": call_data
		})
		
		call_history.append({
			"caller_id": caller_id,
			"timestamp": Time.get_unix_time_from_system(),
			"duration": 0,
			"type": "missed",
			"data": call_data
		})
		
		if signal_bus:
			signal_bus.emit_signal("phone_call_missed", caller_id)
		
		apply_reputation_effects(caller_id, "missed")
		
		if caller_id == current_caller_id:
			current_call_state = CALL_STATE.NONE
			current_caller_id = ""
		
		return true
	return false

func put_current_call_on_hold():
	if current_call_state != CALL_STATE.ACTIVE:
		return false
	
	var call_data = active_calls[current_caller_id]
	call_data["on_hold"] = true
	call_data["hold_time"] = call_active_time
	
	if signal_bus:
		signal_bus.emit_signal("phone_call_held", current_caller_id)
	
	current_call_state = CALL_STATE.NONE
	current_caller_id = ""
	return true

func resume_call(caller_id):
	if not active_calls.has(caller_id) or not active_calls[caller_id].get("on_hold", false):
		return false
	
	if current_call_state != CALL_STATE.NONE:
		put_current_call_on_hold()
	
	current_call_state = CALL_STATE.ACTIVE
	current_caller_id = caller_id
	active_calls[caller_id].erase("on_hold")
	
	if signal_bus:
		signal_bus.emit_signal("phone_call_resumed", caller_id)
	
	return true

func process_active_call(_delta):
	var call_data = active_calls[current_caller_id]
	
	if call_data.has("max_duration") and call_active_time >= call_data.max_duration:
		end_call()
		return
	
	if call_data.has("dialogue") and call_data.has("dialogue_index"):
		var dialogue = call_data.dialogue
		var index = call_data.dialogue_index
		
		if dialogue.size() > index:
			var dialogue_item = dialogue[index]
			if dialogue_item.has("time") and call_active_time >= dialogue_item.time:
				process_dialogue_item(dialogue_item)
				call_data.dialogue_index += 1

func process_dialogue_item(item):
	if not item.has("type"):
		return
	
	match item.type:
		"message":
			if signal_bus and item.has("text"):
				signal_bus.emit_signal("phone_dialogue", current_caller_id, item.text)
		"choice":
			if signal_bus and item.has("options"):
				signal_bus.emit_signal("phone_choices", current_caller_id, item.options)
		"effect":
			if item.has("effect_type") and item.has("value"):
				apply_effect(item.effect_type, item.value)
				if item.has("faction"):
					update_faction_relationship(item.get("faction"), item.value)
				if item.has("quest_id"):
					update_quest(item.get("quest_id"), item.value)
		"end":
			end_call()

func apply_effect(effect_type, value):
	match effect_type:
		"tension":
			if tension_manager:
				tension_manager.add_tension(value)
		"relationship":
			pass
		"quest":
			pass

func update_faction_relationship(faction_id, value):
	if signal_bus:
		signal_bus.emit_signal("faction_relationship_changed", faction_id, value)

func update_quest(quest_id, value):
	if signal_bus:
		signal_bus.emit_signal("quest_update", quest_id, value)

func apply_reputation_effects(caller_id, action_type, _duration = 0):
	var caller_data = get_contact(caller_id)
	if not caller_data:
		return
	
	var caller_type = caller_data.get("type", CALLER_TYPE.BUSINESS)
	
	match action_type:
		"missed":
			match caller_type:
				CALLER_TYPE.FAMILY:
					if tension_manager:
						tension_manager.add_tension(0.05)
				CALLER_TYPE.LAW:
					if tension_manager:
						tension_manager.add_tension(0.03)
				CALLER_TYPE.EMERGENCY:
					if tension_manager:
						tension_manager.add_tension(0.15)
		"declined":
			match caller_type:
				CALLER_TYPE.FAMILY:
					if tension_manager:
						tension_manager.add_tension(0.1)
				CALLER_TYPE.LAW:
					if tension_manager:
						tension_manager.add_tension(0.08)
				CALLER_TYPE.EMERGENCY:
					if tension_manager:
						tension_manager.add_tension(0.2)
		"answered":
			match caller_type:
				CALLER_TYPE.FAMILY:
					if tension_manager:
						tension_manager.reduce_tension(0.05)
				CALLER_TYPE.LAW:
					
					pass
				CALLER_TYPE.EMERGENCY:
					if tension_manager:
						tension_manager.reduce_tension(0.08)

func send_message(contact_id, message_data):
	if not is_phone_powered:
		return false
	
	var contact = get_contact(contact_id)
	if not contact:
		return false
	
	var message = {
		"sender_id": contact_id,
		"timestamp": Time.get_unix_time_from_system(),
		"read": false,
		"data": message_data
	}
	
	waiting_messages.append(message)
	
	emit_signal("message_received", contact_id, message_data)
	
	if signal_bus:
		signal_bus.emit_signal("phone_message_received", contact_id, message_data)
	
	return true

func mark_messages_read(contact_id = ""):
	var found = false
	
	for message in waiting_messages:
		if contact_id.empty() or message.sender_id == contact_id:
			message.read = true
			found = true
	
	return found

func toggle_phone_power():
	is_phone_powered = !is_phone_powered
	
	if not is_phone_powered and current_call_state != CALL_STATE.NONE:
		miss_current_call()
		
	if signal_bus:
		signal_bus.emit_signal("phone_power_changed", is_phone_powered)
	
	return is_phone_powered

func toggle_phone_silent():
	is_phone_silenced = !is_phone_silenced
	
	if signal_bus:
		signal_bus.emit_signal("phone_silent_changed", is_phone_silenced)
	
	return is_phone_silenced

func toggle_gps_tracking():
	is_phone_tracked = !is_phone_tracked
	
	if signal_bus:
		signal_bus.emit_signal("phone_gps_changed", is_phone_tracked)
	
	return is_phone_tracked

func get_call_history():
	return call_history

func get_missed_calls():
	return missed_calls

func clear_missed_calls():
	var old_missed = missed_calls.duplicate()
	missed_calls.clear()
	return old_missed

func get_messages():
	return waiting_messages

func clear_read_messages():
	var unread = []
	
	for message in waiting_messages:
		if not message.read:
			unread.append(message)
	
	waiting_messages = unread
	return unread 
