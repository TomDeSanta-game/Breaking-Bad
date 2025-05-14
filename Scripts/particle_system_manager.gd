extends Node

enum EffectType {
	EXPLOSION_SMALL,
	EXPLOSION_LARGE,
	CHEMICAL_REACTION_BLUE,
	CHEMICAL_REACTION_GREEN,
	CHEMICAL_REACTION_YELLOW,
	MUZZLE_FLASH,
	BLOOD_SPLATTER,
	SMOKE_PUFF,
	GLASS_SHATTER,
	BULLET_IMPACT
}

var effect_scenes = {}
var active_effects = []
var signal_bus = null

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")
	
	preload_effects()
	
func preload_effects():
	var effect_paths = {
		EffectType.EXPLOSION_SMALL: "res://Resources/VFX/explosion_small.tscn",
		EffectType.EXPLOSION_LARGE: "res://Resources/VFX/explosion_large.tscn",
		EffectType.CHEMICAL_REACTION_BLUE: "res://Resources/VFX/chemical_reaction_blue.tscn",
		EffectType.CHEMICAL_REACTION_GREEN: "res://Resources/VFX/chemical_reaction_green.tscn",
		EffectType.CHEMICAL_REACTION_YELLOW: "res://Resources/VFX/chemical_reaction_yellow.tscn",
		EffectType.MUZZLE_FLASH: "res://Resources/VFX/muzzle_flash.tscn",
		EffectType.BLOOD_SPLATTER: "res://Resources/VFX/blood_splatter.tscn",
		EffectType.SMOKE_PUFF: "res://Resources/VFX/smoke_puff.tscn",
		EffectType.GLASS_SHATTER: "res://Resources/VFX/glass_shatter.tscn",
		EffectType.BULLET_IMPACT: "res://Resources/VFX/bullet_impact.tscn"
	}
	
	for effect_type in effect_paths:
		var path = effect_paths[effect_type]
		if ResourceLoader.exists(path):
			effect_scenes[effect_type] = load(path)

func spawn_effect(effect_type: EffectType, position: Vector2, rotation: float = 0.0, scale_factor: float = 1.0, one_shot: bool = true):
	if !effect_scenes.has(effect_type):
		return null
	
	var effect_instance = effect_scenes[effect_type].instantiate()
	get_tree().current_scene.add_child(effect_instance)
	effect_instance.global_position = position
	effect_instance.rotation = rotation
	effect_instance.scale = Vector2(scale_factor, scale_factor)
	
	if effect_instance.has_method("restart"):
		effect_instance.restart()
	elif effect_instance.has_method("set_emitting"):
		effect_instance.set_emitting(true)
	
	if one_shot:
		active_effects.append(effect_instance)
		if signal_bus:
			signal_bus.vfx_started.emit(effect_type, position)
			
		var timer = effect_instance.get_node_or_null("Timer")
		if !timer:
			timer = Timer.new()
			timer.one_shot = true
			effect_instance.add_child(timer)
			
		timer.wait_time = get_effect_duration(effect_type)
		timer.timeout.connect(_on_effect_timer_timeout.bind(effect_instance, effect_type, position))
		timer.start()
	
	return effect_instance

func _on_effect_timer_timeout(effect_instance, effect_type, position):
	if is_instance_valid(effect_instance):
		active_effects.erase(effect_instance)
		if signal_bus:
			signal_bus.vfx_completed.emit(effect_type, position)
		effect_instance.queue_free()

func spawn_explosion(position: Vector2, large: bool = false, scale_factor: float = 1.0):
	var effect_type = EffectType.EXPLOSION_LARGE if large else EffectType.EXPLOSION_SMALL
	var effect = spawn_effect(effect_type, position, 0.0, scale_factor)
	
	if CameraEffects and effect:
		CameraEffects.add_impact_at_position(position, 0.8 if large else 0.4)
	
	if signal_bus:
		var damage_radius = 100.0 if large else 50.0
		signal_bus.explosion_occurred.emit(position, scale_factor, damage_radius)
	
	return effect

func spawn_chemical_reaction(position: Vector2, color: String = "blue", scale_factor: float = 1.0, duration: float = 2.0):
	var effect_type
	match color.to_lower():
		"blue":
			effect_type = EffectType.CHEMICAL_REACTION_BLUE
		"green":
			effect_type = EffectType.CHEMICAL_REACTION_GREEN
		"yellow":
			effect_type = EffectType.CHEMICAL_REACTION_YELLOW
		_:
			effect_type = EffectType.CHEMICAL_REACTION_BLUE
	
	var effect = spawn_effect(effect_type, position, 0.0, scale_factor, false)
	if effect:
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = duration
		effect.add_child(timer)
		timer.timeout.connect(func(): 
			if is_instance_valid(effect):
				if effect.has_method("set_emitting"):
					effect.set_emitting(false)
				var cleanup_timer = Timer.new()
				cleanup_timer.one_shot = true
				cleanup_timer.wait_time = 2.0
				effect.add_child(cleanup_timer)
				cleanup_timer.timeout.connect(func(): 
					if is_instance_valid(effect):
						effect.queue_free()
				)
				cleanup_timer.start()
		)
		timer.start()
		
		if signal_bus:
			signal_bus.chemical_reaction_occurred.emit(color, position, scale_factor)
	
	return effect

func spawn_muzzle_flash(position: Vector2, rotation: float, scale_factor: float = 1.0):
	var effect = spawn_effect(EffectType.MUZZLE_FLASH, position, rotation, scale_factor)
	
	if CameraEffects:
		CameraEffects.add_trauma(0.2)
		
	if signal_bus:
		var direction = Vector2.RIGHT.rotated(rotation)
		signal_bus.gunshot_fired.emit(position, direction, "pistol")
	
	return effect

func spawn_blood_splatter(position: Vector2, direction: Vector2 = Vector2.ZERO, scale_factor: float = 1.0):
	var rotation = 0.0
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	var effect = spawn_effect(EffectType.BLOOD_SPLATTER, position, rotation, scale_factor)
	
	if CameraEffects:
		CameraEffects.add_trauma(0.15)
	
	return effect

func spawn_smoke_puff(position: Vector2, scale_factor: float = 1.0, duration: float = 3.0):
	var effect = spawn_effect(EffectType.SMOKE_PUFF, position, 0.0, scale_factor, false)
	
	if effect:
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = duration
		effect.add_child(timer)
		timer.timeout.connect(func(): 
			if is_instance_valid(effect):
				if effect.has_method("set_emitting"):
					effect.set_emitting(false)
				var cleanup_timer = Timer.new()
				cleanup_timer.one_shot = true
				cleanup_timer.wait_time = 2.0
				effect.add_child(cleanup_timer)
				cleanup_timer.timeout.connect(func(): 
					if is_instance_valid(effect):
						effect.queue_free()
				)
				cleanup_timer.start()
		)
		timer.start()
	
	return effect

func spawn_glass_shatter(position: Vector2, scale_factor: float = 1.0):
	var effect = spawn_effect(EffectType.GLASS_SHATTER, position, 0.0, scale_factor)
	
	if signal_bus:
		signal_bus.glass_broken.emit(position, scale_factor * 10.0)
		
	return effect

func spawn_bullet_impact(position: Vector2, normal: Vector2 = Vector2.UP, scale_factor: float = 1.0):
	var rotation = normal.angle() + PI
	return spawn_effect(EffectType.BULLET_IMPACT, position, rotation, scale_factor)

func get_effect_duration(effect_type: EffectType) -> float:
	match effect_type:
		EffectType.EXPLOSION_SMALL:
			return 1.5
		EffectType.EXPLOSION_LARGE:
			return 2.5
		EffectType.MUZZLE_FLASH:
			return 0.2
		EffectType.BLOOD_SPLATTER:
			return 1.0
		EffectType.GLASS_SHATTER:
			return 1.0
		EffectType.BULLET_IMPACT:
			return 0.5
		_:
			return 1.0

func cleanup_all_effects():
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()

func _exit_tree():
	cleanup_all_effects() 