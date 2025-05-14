
#* back_away.gd

#* Copyright (c) 2023-present Serhii Snitsaruk and the LimboAI contributors.

#* Use of this source code is governed by an MIT-style

#* https://opensource.org/licenses/MIT.

#*
@tool
extends BTAction

## Returns [code]RUNNING[/code] always.

## Blackboard variable that stores desired speed.
@export var speed_var: StringName = &"speed"

## How much can we deviate from the "away" direction (in radians).
@export var max_angle_deviation: float = 0.7

var _dir: Vector2
var _desired_velocity: Vector2

# Called each time this task is entered.
func _enter() -> void:

	_dir = Vector2.LEFT * agent.get_facing()
	var speed: float = blackboard.get_var(speed_var, 200.0)
	var rand_angle = randf_range(-max_angle_deviation, max_angle_deviation)
	_desired_velocity = _dir.rotated(rand_angle) * speed

# Called each time this task is ticked (aka executed).
func _tick(_delta: float) -> Status:
	agent.move(_desired_velocity)
	agent.face_dir(-signf(_dir.x))
	return RUNNING
