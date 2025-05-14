extends Node

signal weapon_equipped(weapon_data)
signal weapon_unequipped(weapon_data)
signal ammo_changed(current_ammo, max_ammo)
signal reload_started(weapon_data)
signal reload_completed(weapon_data)
signal weapon_fired(weapon_data, hit_result)

const WEAPON_TYPES = {
	"PISTOL": {
		"damage": 15.0,
		"fire_rate": 0.4,
		"accuracy": 0.85,
		"range": 200.0,
		"recoil": 3.0,
		"reload_time": 1.2,
		"magazine_size": 8,
		"noise_level": 65.0,
		"mobility": 0.95,
		"heat_per_shot": 4.0,
		"weapon_sway": 1.2,
		"ads_speed": 0.2
	},
	"REVOLVER": {
		"damage": 40.0,
		"fire_rate": 0.8,
		"accuracy": 0.9,
		"range": 220.0,
		"recoil": 5.0,
		"reload_time": 2.0,
		"magazine_size": 6,
		"noise_level": 75.0,
		"mobility": 0.9,
		"heat_per_shot": 8.0,
		"weapon_sway": 1.5,
		"ads_speed": 0.25
	},
	"SHOTGUN": {
		"damage": 70.0,
		"fire_rate": 1.2,
		"accuracy": 0.6,
		"range": 100.0,
		"recoil": 8.0,
		"reload_time": 2.5,
		"magazine_size": 5,
		"noise_level": 85.0,
		"mobility": 0.75,
		"heat_per_shot": 12.0,
		"weapon_sway": 2.0,
		"ads_speed": 0.3
	},
	"RIFLE": {
		"damage": 25.0,
		"fire_rate": 0.1,
		"accuracy": 0.95,
		"range": 350.0,
		"recoil": 4.0,
		"reload_time": 2.0,
		"magazine_size": 20,
		"noise_level": 80.0,
		"mobility": 0.7,
		"heat_per_shot": 6.0,
		"weapon_sway": 1.8,
		"ads_speed": 0.3
	},
	"KNIFE": {
		"damage": 30.0,
		"fire_rate": 0.5,
		"accuracy": 1.0,
		"range": 20.0,
		"recoil": 0.0,
		"reload_time": 0.0,
		"magazine_size": 0,
		"noise_level": 10.0,
		"mobility": 1.0,
		"heat_per_shot": 1.0,
		"weapon_sway": 0.5,
		"ads_speed": 0.15
	}
}

var player = null
var current_weapon = null
var current_ammo = 0
var reloading = false
var reload_timer = 0.0
var next_shot_time = 0.0
var aiming_down_sights = false
var weapon_sway_offset = Vector2.ZERO
var recoil_offset = Vector2.ZERO
var weapon_rotation = 0.0

func _ready():
	SignalBus.player_event.connect(_on_player_event)

func _process(delta):
	if reloading:
		process_reload(delta)
	
	handle_weapon_sway(delta)
	handle_recoil_recovery(delta)

func _on_player_event(event_type, data):
	if event_type == "weapon_equipped":
		var weapon_id = data.weapon_id
		var weapon_type = data.type
		equip_weapon(weapon_id, weapon_type)
	
	if event_type == "weapon_action":
		match data.action:
			"fire":
				fire_weapon()
			"reload":
				start_reload()
			"aim":
				toggle_aim(data.aim_active if "aim_active" in data else true)

func equip_weapon(weapon_id, weapon_type):
	if not weapon_type in WEAPON_TYPES:
		push_warning("Unknown weapon type: " + weapon_type)
		return
	
	if current_weapon and current_weapon.id == weapon_id:
		return
	
	if current_weapon:
		unequip_current_weapon()
	
	var weapon_data = WEAPON_TYPES[weapon_type].duplicate()
	weapon_data.id = weapon_id
	weapon_data.type = weapon_type
	
	current_weapon = weapon_data
	current_ammo = weapon_data.magazine_size
	reloading = false
	reload_timer = 0.0
	next_shot_time = 0.0
	aiming_down_sights = false
	
	weapon_equipped.emit(current_weapon)
	ammo_changed.emit(current_ammo, current_weapon.magazine_size)
	
	SignalBus.player_event.emit("weapon_stat_changed", {
		"mobility": current_weapon.mobility
	})

func unequip_current_weapon():
	if not current_weapon:
		return
	
	weapon_unequipped.emit(current_weapon)
	
	SignalBus.player_event.emit("weapon_stat_changed", {
		"mobility": 1.0
	})
	
	current_weapon = null
	current_ammo = 0
	reloading = false

func fire_weapon():
	if not current_weapon or reloading:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time < next_shot_time:
		return
	
	if current_ammo <= 0:
		play_empty_sound()
		start_reload()
		return
	
	current_ammo -= 1
	next_shot_time = current_time + current_weapon.fire_rate
	
	var hit_result = calculate_shot_result()
	
	apply_recoil()
	play_fire_effects()
	
	weapon_fired.emit(current_weapon, hit_result)
	ammo_changed.emit(current_ammo, current_weapon.magazine_size)
	
	if player and player.has_method("add_heat"):
		player.add_heat(current_weapon.heat_per_shot)
	
	if current_ammo <= 0:
		start_reload()

func calculate_shot_result():
	if not player:
		return null
	
	var accuracy = current_weapon.accuracy
	if aiming_down_sights:
		accuracy = min(1.0, accuracy + 0.1)
	
	var max_spread = (1.0 - accuracy) * 0.5
	var spread_x = randf_range(-max_spread, max_spread)
	var _spread_y = randf_range(-max_spread, max_spread)
	
	var shot_direction = player.player_facing()
	shot_direction = shot_direction.rotated(spread_x)
	
	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = player.global_position
	query.to = player.global_position + shot_direction * current_weapon.range
	query.collision_mask = 1 | 4
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_position = result.position
		var hit_object = result.collider
		var hit_normal = result.normal
		
		if hit_object.is_in_group("npc") and hit_object.has_method("take_damage"):
			var damage = calculate_damage(hit_object, hit_position)
			hit_object.take_damage(damage, player)
		
		SignalBus.vfx_started.emit("bullet_impact", hit_position)
		
		return {
			"hit": true,
			"position": hit_position,
			"object": hit_object,
			"normal": hit_normal,
			"distance": player.global_position.distance_to(hit_position)
		}
	
	return {
		"hit": false,
		"position": player.global_position + shot_direction * current_weapon.range,
		"distance": current_weapon.range
	}

func calculate_damage(_target, hit_position):
	var base_damage = current_weapon.damage
	var distance = player.global_position.distance_to(hit_position)
	var distance_factor = 1.0 - clamp(distance / current_weapon.range, 0.0, 1.0)
	
	var damage = base_damage * (0.7 + distance_factor * 0.3)
	
	if current_weapon.type == "SHOTGUN":
		var pellet_count = 8
		damage = base_damage * (0.7 + distance_factor * 0.3) / pellet_count
	
	if aiming_down_sights:
		damage *= 1.1
	
	return damage

func play_fire_effects():
	if not current_weapon:
		return
	
	SignalBus.gunshot_fired.emit(player.global_position, player.player_facing(), current_weapon.type)
	
	if player and player.sprite:
		player.sprite.play("shoot")

func play_empty_sound():
	SignalBus.vfx_started.emit("empty_gun", player.global_position)

func start_reload():
	if not current_weapon or reloading:
		return
	
	if current_weapon.magazine_size <= 0 or current_ammo >= current_weapon.magazine_size:
		return
	
	reloading = true
	reload_timer = 0.0
	
	reload_started.emit(current_weapon)
	
	if player and player.sprite:
		player.sprite.play("reload")

func process_reload(delta):
	if not current_weapon or not reloading:
		return
	
	reload_timer += delta
	
	if reload_timer >= current_weapon.reload_time:
		complete_reload()

func complete_reload():
	if not current_weapon or not reloading:
		return
	
	current_ammo = current_weapon.magazine_size
	reloading = false
	
	reload_completed.emit(current_weapon)
	ammo_changed.emit(current_ammo, current_weapon.magazine_size)

func toggle_aim(aim_active):
	if not current_weapon:
		return
	
	aiming_down_sights = aim_active
	
	var ads_effect = 0.8
	var field_of_view = 1.0
	
	if aiming_down_sights:
		field_of_view = 1.0 - ads_effect * 0.2
	
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		var target_zoom = Vector2(1.0, 1.0) * (1.0 / field_of_view)
		
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(camera, "zoom", target_zoom, current_weapon.ads_speed)

func apply_recoil():
	if not current_weapon:
		return
	
	var recoil_strength = current_weapon.recoil
	if aiming_down_sights:
		recoil_strength *= 0.7
	
	var recoil_direction = -player.player_facing()
	recoil_offset = recoil_direction * recoil_strength
	
	var _camera_shake_strength = recoil_strength * 0.5
	SignalBus.camera_effect_started.emit("weapon_recoil")

func handle_recoil_recovery(delta):
	if recoil_offset.length() > 0.1:
		recoil_offset = recoil_offset.lerp(Vector2.ZERO, 5.0 * delta)
	else:
		recoil_offset = Vector2.ZERO

func handle_weapon_sway(delta):
	if not current_weapon or not player:
		return
	
	var sway_amount = current_weapon.weapon_sway
	if aiming_down_sights:
		sway_amount *= 0.4
	
	var target_sway = Vector2.ZERO
	
	if player.velocity.length() > 10.0:
		var movement_factor = clamp(player.velocity.length() / player.max_speed, 0.0, 1.0)
		var time_factor = sin(Time.get_ticks_msec() / 1000.0 * 4.0)
		
		target_sway.x = sin(Time.get_ticks_msec() / 1000.0 * 3.0) * sway_amount * movement_factor * 0.5
		target_sway.y = time_factor * sway_amount * movement_factor
	
	weapon_sway_offset = weapon_sway_offset.lerp(target_sway, 2.0 * delta)

func get_weapon_visual_offset():
	return weapon_sway_offset + recoil_offset

func get_current_weapon_data():
	return current_weapon

func setup_player(player_node):
	player = player_node 