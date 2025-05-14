extends Node

signal disguise_equipped(disguise_data)
signal disguise_removed()
signal disguise_heat_level_changed(current, max_level)

const DISGUISE_TYPES = {
	"CIVILIAN": {
		"detection_modifier": 1.0,
		"speed_modifier": 1.0,
		"access_level": 0,
		"suspicion_threshold": 0.6,
		"heat_decay_bonus": 0.0,
		"areas_allowed": ["public"],
		"groups_fooled": ["civilian"],
		"special_abilities": []
	},
	"COOK": {
		"detection_modifier": 0.9,
		"speed_modifier": 0.95,
		"access_level": 1,
		"suspicion_threshold": 0.7,
		"heat_decay_bonus": 0.1,
		"areas_allowed": ["public", "restaurant", "kitchen"],
		"groups_fooled": ["civilian", "staff"],
		"special_abilities": []
	},
	"JANITOR": {
		"detection_modifier": 0.8,
		"speed_modifier": 0.9,
		"access_level": 2,
		"suspicion_threshold": 0.8,
		"heat_decay_bonus": 0.2,
		"areas_allowed": ["public", "maintenance", "storage"],
		"groups_fooled": ["civilian", "staff"],
		"special_abilities": ["carry_bodies"]
	},
	"SECURITY": {
		"detection_modifier": 0.7,
		"speed_modifier": 0.9,
		"access_level": 3,
		"suspicion_threshold": 0.5,
		"heat_decay_bonus": 0.0,
		"areas_allowed": ["public", "security", "restricted"],
		"groups_fooled": ["civilian", "staff"],
		"special_abilities": ["detain"]
	},
	"HAZMAT": {
		"detection_modifier": 0.6,
		"speed_modifier": 0.8,
		"access_level": 3,
		"suspicion_threshold": 0.7,
		"heat_decay_bonus": 0.0,
		"areas_allowed": ["public", "laboratory", "chemical"],
		"groups_fooled": ["civilian", "staff", "security"],
		"special_abilities": ["chemical_resistance"]
	},
	"POLICE": {
		"detection_modifier": 0.5,
		"speed_modifier": 0.9,
		"access_level": 4,
		"suspicion_threshold": 0.4,
		"heat_decay_bonus": 0.0,
		"areas_allowed": ["public", "security", "restricted", "police"],
		"groups_fooled": ["civilian", "staff"],
		"special_abilities": ["detain", "interrogate"]
	},
	"DEA": {
		"detection_modifier": 0.4,
		"speed_modifier": 0.95,
		"access_level": 5,
		"suspicion_threshold": 0.3,
		"heat_decay_bonus": 0.0,
		"areas_allowed": ["public", "security", "restricted", "police", "dea"],
		"groups_fooled": ["civilian", "staff", "security"],
		"special_abilities": ["search", "detain", "interrogate"]
	}
}

var player = null
var current_disguise = null
var discovered_disguises = []
var disguise_heat_level = 0.0
var disguise_heat_max = 100.0
var disguise_heat_decay_timer = 0.0
var disguise_heat_decay_interval = 1.0

func _ready():
	SignalBus.player_event.connect(_on_player_event)

func _process(delta):
	process_disguise_heat(delta)

func _on_player_event(event_type, data):
	if event_type == "disguise_equip":
		var disguise_id = data.disguise_id
		equip_disguise(disguise_id)
	
	if event_type == "disguise_remove":
		remove_disguise()

func equip_disguise(disguise_id):
	if not disguise_id in DISGUISE_TYPES:
		push_warning("Unknown disguise type: " + disguise_id)
		return
	
	if current_disguise and current_disguise.id == disguise_id:
		return
	
	var disguise_data = DISGUISE_TYPES[disguise_id].duplicate()
	disguise_data.id = disguise_id
	
	current_disguise = disguise_data
	disguise_heat_level = 0.0
	
	if not disguise_id in discovered_disguises:
		discovered_disguises.append(disguise_id)
		SignalBus.notification_requested.emit(
			"New Disguise Acquired",
			"You now have access to the " + disguise_id.capitalize() + " disguise.",
			"unlock",
			4.0
		)
	
	update_player_appearance(disguise_id)
	apply_disguise_effects()
	
	disguise_equipped.emit(current_disguise)
	disguise_heat_level_changed.emit(disguise_heat_level, disguise_heat_max)
	
	SignalBus.notification_requested.emit(
		"Disguise Equipped",
		"You are now disguised as a " + disguise_id.capitalize() + ".",
		"info",
		3.0
	)

func remove_disguise():
	if not current_disguise:
		return
	
	var old_disguise = current_disguise
	current_disguise = null
	
	update_player_appearance("CIVILIAN")
	reset_disguise_effects()
	
	disguise_removed.emit()
	
	SignalBus.notification_requested.emit(
		"Disguise Removed",
		"You have removed your " + old_disguise.id.capitalize() + " disguise.",
		"info",
		3.0
	)

func update_player_appearance(disguise_id):
	if not player or not player.sprite:
		return
	
	var animation_prefix = "disguise_" + disguise_id.to_lower()
	
	if player.sprite.has_animation(animation_prefix + "_idle"):
		player.sprite.play(animation_prefix + "_idle")

func apply_disguise_effects():
	if not current_disguise or not player:
		return
	
	if player.has_method("set_speed_modifier"):
		player.set_speed_modifier(current_disguise.speed_modifier)

func reset_disguise_effects():
	if not player:
		return
	
	if player.has_method("set_speed_modifier"):
		player.set_speed_modifier(1.0)

func can_access_area(area_type):
	if not current_disguise:
		return area_type == "public"
	
	return area_type in current_disguise.areas_allowed

func can_fool_npc_group(group_name):
	if not current_disguise:
		return false
	
	return group_name in current_disguise.groups_fooled

func has_special_ability(ability_name):
	if not current_disguise:
		return false
	
	return ability_name in current_disguise.special_abilities

func add_disguise_heat(amount):
	if not current_disguise:
		return
	
	disguise_heat_level = min(disguise_heat_max, disguise_heat_level + amount)
	disguise_heat_level_changed.emit(disguise_heat_level, disguise_heat_max)
	
	if disguise_heat_level >= disguise_heat_max:
		blow_cover()

func process_disguise_heat(delta):
	if not current_disguise or disguise_heat_level <= 0.0:
		return
	
	disguise_heat_decay_timer += delta
	
	if disguise_heat_decay_timer >= disguise_heat_decay_interval:
		disguise_heat_decay_timer = 0.0
		
		var decay_rate = 2.0 + current_disguise.heat_decay_bonus
		disguise_heat_level = max(0.0, disguise_heat_level - decay_rate)
		
		disguise_heat_level_changed.emit(disguise_heat_level, disguise_heat_max)

func blow_cover():
	SignalBus.notification_requested.emit(
		"Cover Blown",
		"Your disguise has been compromised!",
		"danger",
		5.0
	)
	
	remove_disguise()
	
	if player and player.has_method("add_heat"):
		player.add_heat(25.0)

func get_detection_modifier():
	if not current_disguise:
		return 1.0
	
	return current_disguise.detection_modifier

func get_suspicion_threshold():
	if not current_disguise:
		return 0.6
	
	return current_disguise.suspicion_threshold

func get_access_level():
	if not current_disguise:
		return 0
	
	return current_disguise.access_level

func is_disguised():
	return current_disguise != null

func get_current_disguise_data():
	return current_disguise

func setup_player(player_node):
	player = player_node 