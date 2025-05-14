extends Area2D

@export var glow_intensity: float = 1.0
@export var glow_color: Color = Color(0.0, 0.83, 0.89, 1.0)
@export var pulse_speed: float = 0.5

func _ready():
	set_collision_layer(4)
	set_collision_mask(1 | 2)
	
	var crystal1 = get_node("Crystal1")
	var crystal2 = get_node("Crystal2")
	var crystal3 = get_node("Crystal3")
	
	if crystal1 and crystal2 and crystal3:
		create_crystal_glow()
		
func _on_body_entered(body):
	if body.is_in_group("player"):
		if get_node_or_null("/root/SignalBus"):
			get_node("/root/SignalBus").emit_signal("meth_batch_collected")
		queue_free()
		
func create_crystal_glow():
	var crystal = [get_node("Crystal1"), get_node("Crystal2"), get_node("Crystal3")]
	
	for c in crystal:
		if c and c.has_node("Glow"):
			var glow = c.get_node("Glow")
			glow.color = glow_color
			glow.energy = glow_intensity
			
			var tween = create_tween()
			tween.set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(glow, "energy", glow_intensity * 1.5, pulse_speed)
			tween.tween_property(glow, "energy", glow_intensity * 0.7, pulse_speed)
