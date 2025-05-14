extends Node

enum HEAT { NONE, LOW, MEDIUM, HIGH, WANTED }

var current_heat = HEAT.NONE
var tension_engine
var suspicion_active: bool = false
var detection_meter: float = 0.0
var detection_threshold: float = 0.9
var police_cooldown: float = 0.0
var police_cooldown_duration: float = 30.0
var wanted_timer: float = 0.0
var wanted_duration: float = 300.0
var suspicion_zones = []
var signal_bus = null

func _ready():
	tension_engine = load("res://Scripts/tension_engine.gd").new()
	add_child(tension_engine)
	
	signal_bus = get_node_or_null("/root/SignalBus")
	
	SignalBus.tension_level_changed.connect(_on_tension_changed)
	SignalBus.threshold_crossed.connect(_on_threshold_crossed)
	SignalBus.explosion_occurred.connect(_on_explosion_occurred)
	SignalBus.gunshot_fired.connect(_on_gunshot_fired)
	SignalBus.glass_broken.connect(_on_glass_broken)

func _process(delta: float):
	_update_timers(delta)
	_update_detection(delta)

func _update_timers(delta: float):
	if police_cooldown > 0:
		police_cooldown -= delta
	if wanted_timer > 0:
		wanted_timer -= delta
		if wanted_timer <= 0:
			reduce_heat()

func _update_detection(delta: float):
	if suspicion_active and tension_engine:
		var detection_speed = 0.1 * (1.0 + tension_engine.get_normalized())
		detection_meter = min(detection_meter + detection_speed * delta, 1.0)
		if detection_meter >= detection_threshold:
			alert_police()
	else:
		detection_meter = max(detection_meter - 0.2 * delta, 0.0)

func add_tension(amount: float):
	if tension_engine:
		tension_engine.add(amount)

func reduce_tension(amount: float):
	if tension_engine:
		tension_engine.reduce(amount)

func set_suspicion_active(active: bool):
	suspicion_active = active
	if !active:
		detection_meter = 0.0

func alert_police(position: Vector2 = Vector2.ZERO, intensity: float = 1.0):
	detection_meter = 0.0
	police_cooldown = police_cooldown_duration
	
	if signal_bus:
		signal_bus.emit_signal("police_alerted", position, intensity)
	
	if tension_engine:
		tension_engine.add_tension(0.2 * intensity)
	
	var particle_manager = get_node_or_null("/root/ParticleSystemManager")
	if particle_manager:
		particle_manager.spawn_muzzle_flash(position, 0.0, 1.0)
		
		if intensity > 0.5:
			for i in range(3):
				var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
				var impact_pos = position + offset
				particle_manager.spawn_bullet_impact(impact_pos, (position - impact_pos).normalized())

func _on_explosion_occurred(position, size, _damage_radius):
	handle_explosion(position, size)

func handle_explosion(position: Vector2, size: float):
	add_tension(0.4 * size)
	
	var particle_manager = get_node_or_null("/root/ParticleSystemManager")
	if particle_manager:
		particle_manager.spawn_explosion(position, size > 1.5, size / 2.0)

func _on_gunshot_fired(position, direction, weapon_type):
	var rotation = 0.0
	if direction is Vector2 and direction != Vector2.ZERO:
		rotation = direction.angle()
	
	var damage = 1.0
	if weapon_type == "shotgun":
		damage = 1.5
	elif weapon_type == "sniper":
		damage = 2.0
	
	handle_gunshot(position, rotation, damage)

func handle_gunshot(position: Vector2, rotation: float, damage: float = 1.0):
	add_tension(0.15)
	
	var particle_manager = get_node_or_null("/root/ParticleSystemManager")
	if particle_manager:
		particle_manager.spawn_muzzle_flash(position, rotation, 1.0)
		
		var direction = Vector2.RIGHT.rotated(rotation)
		var distance = 500.0
		var hit_pos = position + direction * distance
		
		var space_state = get_viewport().get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(position, hit_pos, 1 + 2, [])
		var result = space_state.intersect_ray(query)
		
		if result:
			hit_pos = result.position
			
			if result.collider.is_in_group("characters") or result.collider.is_in_group("player"):
				particle_manager.spawn_blood_splatter(result.position, -direction, damage)
			else:
				particle_manager.spawn_bullet_impact(result.position, result.normal)

func _on_glass_broken(position, force):
	var particle_manager = get_node_or_null("/root/ParticleSystemManager")
	if particle_manager:
		particle_manager.spawn_glass_shatter(position, force / 10.0)
	
	add_tension(0.1 * force)

func player_detected(by_npc_type: String):
	SignalBus.player_detected.emit(by_npc_type)
	increase_heat()

func increase_heat():
	var old_heat = current_heat
	
	if current_heat < HEAT.WANTED:
		current_heat = HEAT.values()[min(HEAT.values().find(current_heat) + 1, HEAT.values().size() - 1)]
	
	if current_heat == HEAT.WANTED:
		wanted_timer = wanted_duration
	
	SignalBus.heat_level_changed.emit(current_heat, old_heat)

func reduce_heat():
	var old_heat = current_heat
	
	if current_heat > HEAT.NONE:
		current_heat = HEAT.values()[max(HEAT.values().find(current_heat) - 1, 0)]
	
	SignalBus.heat_level_changed.emit(current_heat, old_heat)

func register_suspicion_zone(zone):
	if !suspicion_zones.has(zone):
		suspicion_zones.append(zone)
		return true
	return false

func unregister_suspicion_zone(zone):
	if suspicion_zones.has(zone):
		suspicion_zones.erase(zone)
		return true
	return false

func _on_tension_changed(_current, _previous):
	pass

func _on_threshold_crossed(_threshold_name, _direction, _threshold_value, _current_value):
	pass

func get_detection_progress():
	return detection_meter

func get_normalized_heat():
	return float(HEAT.values().find(current_heat)) / float(HEAT.values().size() - 1)

func get_heat_level():
	return current_heat
