extends BTAction

@export var target_pos: StringName = &"position"
@export var direction_var: StringName = &"direction"
@export var speed: float = 100.0
@export var tolerance: float = 10.0

func _tick(delta: float) -> Status:
	var target_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	
	if blackboard.has_var(target_pos):
		target_position = blackboard.get_var(target_pos)
		
		if agent.global_position.distance_to(target_position) <= tolerance:
			return SUCCESS
			
		var direction = agent.global_position.direction_to(target_position)
		velocity = direction * speed * delta
		
	elif blackboard.has_var(direction_var):
		var dir = blackboard.get_var(direction_var)
		
		match dir:
			"up":
				velocity.y = -speed * delta
			"down":
				velocity.y = speed * delta
			"left":
				velocity.x = -speed * delta
			"right":
				velocity.x = speed * delta
	
	if velocity != Vector2.ZERO:
		agent.global_position += velocity
		return RUNNING
		
	return FAILURE 