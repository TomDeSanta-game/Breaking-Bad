extends BTAction

@export var group: StringName
@export var target_var: StringName = &"target"

var target: CharacterBody2D

func _tick(_delta: float) -> Status:
	target = _get_target_node()
	
	if not is_instance_valid(target):
		return FAILURE
		
	blackboard.set_var(target_var, target)
	
	if target.global_position:
		blackboard.set_var(&"position", target.global_position)
		
	return SUCCESS

func _get_target_node() -> CharacterBody2D:
	var nodes = agent.get_tree().get_nodes_in_group(group)
	
	if nodes.is_empty():
		return null
		
	match group:
		&"Enemy":
			if nodes.size() >= 2:
				nodes.shuffle()
				
				while nodes.front() == agent and nodes.size() > 1:
					nodes.shuffle()
					
				return nodes.front() as CharacterBody2D
			
			return nodes.front() as CharacterBody2D if nodes.front() != agent else null
			
		&"Player":
			return nodes.front() as CharacterBody2D
			
	return null 