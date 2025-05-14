
#* is_aligned_with_target.gd

#* Copyright (c) 2023-present Serhii Snitsaruk and the LimboAI contributors.

#* Use of this source code is governed by an MIT-style

#* https://opensource.org/licenses/MIT.

#*
@tool
extends BTCondition

## Returns [code]SUCCESS[/code] if the agent is horizontally aligned with the target.

@export var target_var: StringName = &"target"
@export var tolerance: float = 30.0

# Display a customized name (requires @tool).
func _generate_name() -> String:
	return "IsAlignedWithTarget " + LimboUtility.decorate_var(target_var)

# Called each time this task is ticked (aka executed).
func _tick(_delta: float) -> Status:
	var target := blackboard.get_var(target_var) as Node2D
	if not is_instance_valid(target):
		return FAILURE
	var y_diff: float = absf(target.global_position.y - agent.global_position.y)
	if y_diff < tolerance:
		return SUCCESS
	return FAILURE
