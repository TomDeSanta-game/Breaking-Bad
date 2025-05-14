extends Node

signal weather_changed(weather_type, intensity)
signal weather_effect_applied(effect_type, value)
@warning_ignore("unused_signal") signal weather_effect_removed(effect_type)

enum WeatherType {
	CLEAR,
	RAIN,
	DUST_STORM,
	FOG,
	WINDY,
	THUNDERSTORM
}

const WEATHER_PROPERTIES = {
	WeatherType.CLEAR: {
		"visibility_modifier": 1.0,
		"movement_modifier": 1.0,
		"sound_dampening": 1.0,
		"surface_modifier": "dry",
		"effects": {}
	},
	WeatherType.RAIN: {
		"visibility_modifier": 0.8,
		"movement_modifier": 0.9,
		"sound_dampening": 0.7,
		"surface_modifier": "wet",
		"effects": {
			"slippery_surfaces": true,
			"puddles": true,
			"reduced_fire_chance": true
		}
	},
	WeatherType.DUST_STORM: {
		"visibility_modifier": 0.4,
		"movement_modifier": 0.7,
		"sound_dampening": 0.5,
		"surface_modifier": "dusty",
		"effects": {
			"reduced_visibility": true,
			"coughing": true,
			"tracks_visible": false
		}
	},
	WeatherType.FOG: {
		"visibility_modifier": 0.5,
		"movement_modifier": 0.95,
		"sound_dampening": 0.8,
		"surface_modifier": "damp",
		"effects": {
			"reduced_visibility": true,
			"muffled_sounds": true,
			"stealth_bonus": true
		}
	},
	WeatherType.WINDY: {
		"visibility_modifier": 0.9,
		"movement_modifier": 0.85,
		"sound_dampening": 0.6,
		"surface_modifier": "dry",
		"effects": {
			"projectile_deviation": true,
			"increased_sound_range": true,
			"paper_debris": true
		}
	},
	WeatherType.THUNDERSTORM: {
		"visibility_modifier": 0.6,
		"movement_modifier": 0.8,
		"sound_dampening": 0.4,
		"surface_modifier": "wet",
		"effects": {
			"slippery_surfaces": true,
			"reduced_visibility": true,
			"lightning_flashes": true,
			"thunder_sounds": true,
			"puddles": true
		}
	}
}

var current_weather = WeatherType.CLEAR
var current_intensity = 0.5
var transition_duration = 30.0
var transition_timer = 0.0
var transitioning = false
var target_weather = WeatherType.CLEAR
var target_intensity = 0.5

var weather_effects = {}
var affected_nodes = {}
var surface_states = {}

func _ready():
	SignalBus.weather_changed.connect(_on_weather_changed)
	initialize_weather_system()

func _process(delta):
	if transitioning:
		process_weather_transition(delta)
	
	update_weather_effects(delta)

func initialize_weather_system():
	current_weather = WeatherType.CLEAR
	current_intensity = 0.0
	transitioning = false
	
	apply_weather_effects()
	
	SignalBus.notification_requested.emit(
		"Weather System",
		"Weather system initialized",
		"info",
		2.0
	)

func _on_weather_changed(weather_type, intensity):
	set_weather(weather_type, intensity)

func set_weather(weather_type, intensity = 0.5, transition_time = 30.0):
	if not weather_type in WeatherType.values():
		push_warning("Unknown weather type: " + str(weather_type))
		return
	
	if current_weather == weather_type and current_intensity == intensity:
		return
	
	target_weather = weather_type
	target_intensity = clamp(intensity, 0.0, 1.0)
	
	if transition_time > 0.0:
		transition_duration = transition_time
		transition_timer = 0.0
		transitioning = true
	else:
		current_weather = target_weather
		current_intensity = target_intensity
		transitioning = false
		apply_weather_effects()
	
	var weather_name = WeatherType.keys()[weather_type]
	var intensity_description = get_intensity_description(intensity)
	
	SignalBus.notification_requested.emit(
		"Weather Changing",
		intensity_description + " " + weather_name + " approaching",
		"info",
		4.0
	)
	
	weather_changed.emit(current_weather, current_intensity)

func process_weather_transition(delta):
	if not transitioning:
		return
	
	transition_timer += delta
	var progress = transition_timer / transition_duration
	
	if progress >= 1.0:
		current_weather = target_weather
		current_intensity = target_intensity
		transitioning = false
	else:
		var _weather_props = WEATHER_PROPERTIES[current_weather]
		var _target_props = WEATHER_PROPERTIES[target_weather]
		
		var lerp_intensity = lerp(current_intensity, target_intensity, progress)
		current_intensity = lerp_intensity
	
	apply_weather_effects()

func apply_weather_effects():
	var weather_props = WEATHER_PROPERTIES[current_weather]
	var scaled_intensity = current_intensity
	
	var visibility = lerp(1.0, weather_props.visibility_modifier, scaled_intensity)
	var movement = lerp(1.0, weather_props.movement_modifier, scaled_intensity)
	var sound = lerp(1.0, weather_props.sound_dampening, scaled_intensity)
	
	weather_effects = {
		"visibility": visibility,
		"movement": movement,
		"sound": sound,
		"surface": weather_props.surface_modifier
	}
	
	for effect in weather_props.effects.keys():
		if weather_props.effects[effect]:
			var effect_value = scaled_intensity
			weather_effects[effect] = effect_value
			weather_effect_applied.emit(effect, effect_value)
	
	update_visual_effects()
	update_audio_effects()
	update_surface_states()
	
	SignalBus.environment_changed.emit("weather_" + WeatherType.keys()[current_weather].to_lower())

func update_visual_effects():
	var visibility = weather_effects.visibility
	
	if current_weather == WeatherType.FOG or current_weather == WeatherType.DUST_STORM:
		SignalBus.camera_effect_started.emit("fog_effect")
		var fog_data = {
			"density": 1.0 - visibility,
			"color": Color(0.8, 0.8, 0.9, 0.5) if current_weather == WeatherType.FOG else Color(0.8, 0.7, 0.5, 0.6)
		}
		SignalBus.vfx_started.emit("fog", fog_data)
	else:
		SignalBus.camera_effect_ended.emit("fog_effect")
		SignalBus.vfx_completed.emit("fog", {})
	
	if current_weather == WeatherType.RAIN or current_weather == WeatherType.THUNDERSTORM:
		var rain_intensity = current_intensity
		SignalBus.vfx_started.emit("rain", {"intensity": rain_intensity})
		
		if current_weather == WeatherType.THUNDERSTORM:
			trigger_lightning_effects()
	else:
		SignalBus.vfx_completed.emit("rain", {})
	
	if current_weather == WeatherType.WINDY or current_weather == WeatherType.DUST_STORM:
		var wind_data = {
			"direction": Vector2(1.0, 0.2).normalized(),
			"strength": current_intensity * (1.5 if current_weather == WeatherType.DUST_STORM else 1.0)
		}
		SignalBus.vfx_started.emit("wind", wind_data)
		
		if current_weather == WeatherType.DUST_STORM:
			SignalBus.vfx_started.emit("dust_particles", {"intensity": current_intensity})
	else:
		SignalBus.vfx_completed.emit("wind", {})
		SignalBus.vfx_completed.emit("dust_particles", {})

func update_audio_effects():
	var sound_dampening = weather_effects.sound
	
	SignalBus.parallax_settings_changed.emit(true, sound_dampening)
	
	if current_weather == WeatherType.RAIN or current_weather == WeatherType.THUNDERSTORM:
		SignalBus.ambient_changed.emit("rain")
	elif current_weather == WeatherType.WINDY or current_weather == WeatherType.DUST_STORM:
		SignalBus.ambient_changed.emit("wind")
	else:
		SignalBus.ambient_changed.emit("default")

func update_surface_states():
	var surface_type = weather_effects.surface
	
	for node_id in affected_nodes.keys():
		var node = affected_nodes[node_id]
		
		if is_instance_valid(node) and node.has_method("set_surface_state"):
			node.set_surface_state(surface_type, current_intensity)

func trigger_lightning_effects():
	if current_weather != WeatherType.THUNDERSTORM:
		return
	
	var lightning_chance = current_intensity * 0.01
	
	if randf() < lightning_chance:
		var screen_pos = Vector2(randf_range(0.0, 1.0), 0.2)
		
		SignalBus.camera_effect_started.emit("lightning_flash")
		SignalBus.vfx_started.emit("lightning", {"position": screen_pos, "intensity": current_intensity})
		
		var thunder_delay = randf_range(0.5, 3.0)
		await get_tree().create_timer(thunder_delay).timeout
		
		SignalBus.vfx_started.emit("thunder_sound", {"distance": thunder_delay / 3.0})

func register_affected_node(node):
	if not node or not is_instance_valid(node):
		return
	
	var node_id = node.get_instance_id()
	affected_nodes[node_id] = node
	
	if node.has_method("set_surface_state"):
		node.set_surface_state(weather_effects.surface, current_intensity)
	
	if not node.is_connected("tree_exiting", _on_node_removed.bind(node_id)):
		node.tree_exiting.connect(_on_node_removed.bind(node_id))

func unregister_affected_node(node):
	if not node:
		return
	
	var node_id = node.get_instance_id()
	
	if node_id in affected_nodes:
		affected_nodes.erase(node_id)

func _on_node_removed(node_id):
	if node_id in affected_nodes:
		affected_nodes.erase(node_id)

func update_weather_effects(delta):
	if current_weather == WeatherType.THUNDERSTORM:
		if randf() < 0.002 * current_intensity:
			trigger_lightning_effects()
	
	for node_id in affected_nodes.keys():
		var node = affected_nodes[node_id]
		
		if is_instance_valid(node) and node.has_method("apply_weather_effects"):
			node.apply_weather_effects(weather_effects, delta)

func get_current_weather():
	return current_weather

func get_current_intensity():
	return current_intensity

func get_weather_property(property_name):
	if property_name in weather_effects:
		return weather_effects[property_name]
	return null

func get_intensity_description(intensity):
	if intensity < 0.3:
		return "Light"
	elif intensity < 0.7:
		return "Moderate"
	else:
		return "Heavy"

func get_temperature_modifier():
	match current_weather:
		WeatherType.CLEAR:
			return 0.0
		WeatherType.RAIN:
			return -5.0
		WeatherType.DUST_STORM:
			return 5.0
		WeatherType.FOG:
			return -3.0
		WeatherType.WINDY:
			return -2.0
		WeatherType.THUNDERSTORM:
			return -8.0
	
	return 0.0 