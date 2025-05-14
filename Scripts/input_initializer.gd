extends Node

func _ready():
	ensure_input_mappings()

func ensure_input_mappings():
	add_action_if_missing("slow_motion", KEY_Q)

func add_action_if_missing(action_name: String, default_key: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		
		var event = InputEventKey.new()
		event.keycode = default_key
		InputMap.action_add_event(action_name, event) 