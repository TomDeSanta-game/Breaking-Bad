
#* move_forward.gd

#* Copyright (c) 2023-present Serhii Snitsaruk and the LimboAI contributors.

#* Use of this source code is governed by an MIT-style

#* https://opensource.org/licenses/MIT.

#*
@tool
extends BTAction

## until the [member duration] is exceeded. [br]

## Returns [code]RUNNING[/code] if the elapsed time does not exceed [member duration]. [br]

## Blackboard variable that stores desired speed.
@export var speed_var: StringName = &"speed"

## How long to perform this task (in seconds).
@export var duration: float = 0.1

# Display a customized name (requires @tool).
func _generate_name() -> String:
	return "MoveForward  speed: %s  duration: %ss" % [
		LimboUtility.decorate_var(speed_var),
		duration]

# Called each time this task is ticked (aka executed).
func _tick(_delta: float) -> Status:
	var facing: float = agent.get_facing()
	var speed: float = blackboard.get_var(speed_var, 100.0)
	var desired_velocity: Vector2 = Vector2.RIGHT * facing * speed
	agent.move(desired_velocity)
	agent.update_facing()
	if elapsed_time > duration:
		return SUCCESS
	return RUNNING
