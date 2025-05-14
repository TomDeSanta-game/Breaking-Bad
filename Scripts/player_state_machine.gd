class_name PlayerStateMachine
extends LimboHSM

var player: CharacterBody2D
var states: Dictionary = {}
var current_state_name: String = ""
var last_horizontal_direction: int = 1

const STATE_DOWN_IDLE: String = "down_idle"
const STATE_RIGHT_IDLE: String = "right_idle"
const STATE_UP_IDLE: String = "up_idle"
const STATE_DOWN_RUN: String = "down_run"
const STATE_RIGHT_RUN: String = "right_run" 
const STATE_UP_RUN: String = "up_run"

func init(player_node: CharacterBody2D) -> void:
	player = player_node
	agent = player
	
	states = {
		STATE_DOWN_IDLE: _create_state(STATE_DOWN_IDLE, down_idle_start, down_idle_update),
		STATE_RIGHT_IDLE: _create_state(STATE_RIGHT_IDLE, right_idle_start, right_idle_update),
		STATE_UP_IDLE: _create_state(STATE_UP_IDLE, up_idle_start, up_idle_update),
		STATE_DOWN_RUN: _create_state(STATE_DOWN_RUN, down_run_start, down_run_update),
		STATE_RIGHT_RUN: _create_state(STATE_RIGHT_RUN, right_run_start, right_run_update),
		STATE_UP_RUN: _create_state(STATE_UP_RUN, up_run_start, up_run_update),
	}
	
	for state in states.values():
		add_child(state)
		
	_setup_transitions()
	
	current_state_name = STATE_DOWN_IDLE
	initial_state = states.get(STATE_DOWN_IDLE)
	if initial_state:
		set("current_state", initial_state)
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus:
			signal_bus.emit_signal("player_state_changed", STATE_DOWN_IDLE)

func _create_state(state_name: String, start_func: Callable, update_func: Callable) -> LimboState:
	var state = LimboState.new()
	state.name = state_name
	state.call_on_enter(start_func).call_on_update(update_func)
	return state

func _setup_transitions() -> void:
	add_transition(states.get(STATE_DOWN_IDLE), states.get(STATE_DOWN_RUN), "_on_move")
	add_transition(states.get(STATE_RIGHT_IDLE), states.get(STATE_RIGHT_RUN), "_on_move")
	add_transition(states.get(STATE_UP_IDLE), states.get(STATE_UP_RUN), "_on_move")
	
	add_transition(states.get(STATE_DOWN_RUN), states.get(STATE_DOWN_IDLE), "_on_stop")
	add_transition(states.get(STATE_RIGHT_RUN), states.get(STATE_RIGHT_IDLE), "_on_stop")
	add_transition(states.get(STATE_UP_RUN), states.get(STATE_UP_IDLE), "_on_stop")
	
	add_transition(states.get(STATE_DOWN_IDLE), states.get(STATE_RIGHT_IDLE), "_on_move_right")
	add_transition(states.get(STATE_DOWN_IDLE), states.get(STATE_UP_IDLE), "_on_move_up")
	add_transition(states.get(STATE_RIGHT_IDLE), states.get(STATE_DOWN_IDLE), "_on_move_down")
	add_transition(states.get(STATE_RIGHT_IDLE), states.get(STATE_UP_IDLE), "_on_move_up")
	add_transition(states.get(STATE_UP_IDLE), states.get(STATE_DOWN_IDLE), "_on_move_down")
	add_transition(states.get(STATE_UP_IDLE), states.get(STATE_RIGHT_IDLE), "_on_move_right")
	
	add_transition(states.get(STATE_DOWN_RUN), states.get(STATE_RIGHT_RUN), "_on_move_right")
	add_transition(states.get(STATE_DOWN_RUN), states.get(STATE_UP_RUN), "_on_move_up")
	add_transition(states.get(STATE_RIGHT_RUN), states.get(STATE_DOWN_RUN), "_on_move_down")
	add_transition(states.get(STATE_RIGHT_RUN), states.get(STATE_UP_RUN), "_on_move_up")
	add_transition(states.get(STATE_UP_RUN), states.get(STATE_DOWN_RUN), "_on_move_down")
	add_transition(states.get(STATE_UP_RUN), states.get(STATE_RIGHT_RUN), "_on_move_right")

func _on_move() -> bool:
	return player.direction != Vector2.ZERO

func _on_stop() -> bool:
	return player.direction == Vector2.ZERO

func _on_move_right() -> bool:
	return abs(player.direction.x) > abs(player.direction.y) && player.direction.x != 0

func _on_move_down() -> bool:
	return abs(player.direction.y) > abs(player.direction.x) && player.direction.y > 0

func _on_move_up() -> bool:
	return abs(player.direction.y) > abs(player.direction.x) && player.direction.y < 0

func down_idle_start() -> void:
	player.animated_sprite.play(player.ANIMATIONS.DOWN_IDLE)
	current_state_name = STATE_DOWN_IDLE
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.emit_signal("player_state_changed", STATE_DOWN_IDLE)

func down_idle_update(_delta: float) -> void:
	if player.direction != Vector2.ZERO:
		if abs(player.direction.x) > abs(player.direction.y):
			if player.direction.x != 0:
				last_horizontal_direction = sign(player.direction.x)
			player.animated_sprite.flip_h = (last_horizontal_direction < 0)
			dispatch("right_run")
		else:
			if player.direction.y > 0:
				dispatch("down_run")
			else:
				dispatch("up_run")

func right_idle_start() -> void:
	player.animated_sprite.play(player.ANIMATIONS.RIGHT_IDLE)
	current_state_name = STATE_RIGHT_IDLE
	player.animated_sprite.flip_h = (last_horizontal_direction < 0)
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.emit_signal("player_state_changed", STATE_RIGHT_IDLE)

func right_idle_update(_delta: float) -> void:
	if player.direction != Vector2.ZERO:
		if abs(player.direction.x) > abs(player.direction.y):
			if player.direction.x != 0:
				last_horizontal_direction = sign(player.direction.x)
			player.animated_sprite.flip_h = (last_horizontal_direction < 0)
			dispatch("right_run")
		else:
			if player.direction.y > 0:
				dispatch("down_run")
			else:
				dispatch("up_run")

func up_idle_start() -> void:
	player.animated_sprite.play(player.ANIMATIONS.UP_IDLE)
	current_state_name = STATE_UP_IDLE
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.emit_signal("player_state_changed", STATE_UP_IDLE)

func up_idle_update(_delta: float) -> void:
	if player.direction != Vector2.ZERO:
		if abs(player.direction.x) > abs(player.direction.y):
			if player.direction.x != 0:
				last_horizontal_direction = sign(player.direction.x)
			player.animated_sprite.flip_h = (last_horizontal_direction < 0)
			dispatch("right_run")
		else:
			if player.direction.y > 0:
				dispatch("down_run")
			else:
				dispatch("up_run")

func down_run_start() -> void:
	player.animated_sprite.play(player.ANIMATIONS.DOWN_RUN)
	current_state_name = STATE_DOWN_RUN
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.emit_signal("player_state_changed", STATE_DOWN_RUN)

func down_run_update(_delta: float) -> void:
	if player.direction.x != 0:
		last_horizontal_direction = sign(player.direction.x)
	
	if player.direction == Vector2.ZERO:
		dispatch("down_idle")
	elif abs(player.direction.x) > abs(player.direction.y):
		if player.direction.x != 0:
			last_horizontal_direction = sign(player.direction.x)
		player.animated_sprite.flip_h = (last_horizontal_direction < 0)
		dispatch("right_run")
	elif player.direction.y < 0:
		dispatch("up_run")

func right_run_start() -> void:
	player.animated_sprite.play(player.ANIMATIONS.RIGHT_RUN)
	current_state_name = STATE_RIGHT_RUN
	player.animated_sprite.flip_h = (last_horizontal_direction < 0)
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.emit_signal("player_state_changed", STATE_RIGHT_RUN)

func right_run_update(_delta: float) -> void:
	if player.direction.x != 0:
		last_horizontal_direction = sign(player.direction.x)
	player.animated_sprite.flip_h = (last_horizontal_direction < 0)
	
	if player.direction == Vector2.ZERO:
		dispatch("right_idle")
	elif abs(player.direction.y) > abs(player.direction.x):
		if player.direction.y > 0:
			dispatch("down_run")
		else:
			dispatch("up_run")

func up_run_start() -> void:
	player.animated_sprite.play(player.ANIMATIONS.UP_RUN)
	current_state_name = STATE_UP_RUN
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.emit_signal("player_state_changed", STATE_UP_RUN)

func up_run_update(_delta: float) -> void:
	if player.direction.x != 0:
		last_horizontal_direction = sign(player.direction.x)
	
	if player.direction == Vector2.ZERO:
		dispatch("up_idle")
	elif abs(player.direction.x) > abs(player.direction.y):
		if player.direction.x != 0:
			last_horizontal_direction = sign(player.direction.x)
		player.animated_sprite.flip_h = (last_horizontal_direction < 0)
		dispatch("right_run")
	elif player.direction.y > 0:
		dispatch("down_run")
