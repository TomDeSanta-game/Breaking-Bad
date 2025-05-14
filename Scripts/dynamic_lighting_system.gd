extends Node

enum LightingState {
	AUTO,
	DAY,
	SUNSET,
	DUSK,
	NIGHT,
	DAWN,
	MORNING,
	EMERGENCY
}

enum TimeMode {
	REAL_TIME,
	GAME_TIME,
	MANUAL
}

@export_category("Time Settings")
@export var time_mode: TimeMode = TimeMode.GAME_TIME
@export var day_length_minutes: float = 24.0
@export var time_scale: float = 1.0
@export var starting_hour: float = 8.0
@export var enable_day_night_cycle: bool = true

@export_category("Lighting Colors")
@export var day_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var morning_color: Color = Color(1.0, 0.9, 0.8, 1.0)
@export var sunset_color: Color = Color(1.0, 0.8, 0.6, 1.0)
@export var dusk_color: Color = Color(0.6, 0.6, 0.8, 1.0)
@export var night_color: Color = Color(0.3, 0.3, 0.6, 1.0)
@export var dawn_color: Color = Color(0.8, 0.8, 1.0, 1.0)
@export var emergency_color: Color = Color(1.0, 0.2, 0.2, 1.0)

@export_category("Lighting Intensities")
@export var day_intensity: float = 1.0
@export var morning_intensity: float = 0.8
@export var sunset_intensity: float = 0.7
@export var dusk_intensity: float = 0.5
@export var night_intensity: float = 0.3
@export var dawn_intensity: float = 0.6
@export var emergency_intensity: float = 0.9

@export_category("Time Ranges")
@export var morning_start_hour: float = 5.0
@export var day_start_hour: float = 8.0
@export var sunset_start_hour: float = 18.0
@export var dusk_start_hour: float = 20.0
@export var night_start_hour: float = 22.0
@export var dawn_start_hour: float = 4.0

var signal_bus = null
var current_time: float = 0.0
var current_lighting_state = "AUTO"
var current_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var current_intensity: float = 1.0
var registered_lights = []
var state_override: LightingState = LightingState.AUTO
var color_override: Color = Color(1.0, 1.0, 1.0, 1.0)
var intensity_override: float = 1.0
var use_color_override: bool = false
var use_intensity_override: bool = false

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")
	
	current_time = hour_to_time(starting_hour)
	
	if enable_day_night_cycle and time_mode != TimeMode.MANUAL:
		update_time(current_time)

func _process(delta):
	if enable_day_night_cycle and time_mode != TimeMode.MANUAL:
		var time_delta = delta * time_scale * (1440.0 / day_length_minutes / 60.0)
		current_time = fmod(current_time + time_delta, 24.0)
		update_time(current_time)

func hour_to_time(hour: float) -> float:
	return fmod(hour, 24.0)

func update_time(time: float):
	current_time = time
	
	if state_override == LightingState.AUTO:
		determine_lighting_state()
	else:
		update_lighting_by_name(get_state_name(state_override))
	
	if signal_bus:
		signal_bus.emit_signal("lighting_time_changed", current_time)

func update_lighting_by_name(state_name: String):
	current_lighting_state = state_name
	
	match state_name:
		"DAY":
			update_lighting(day_color, day_intensity)
		"MORNING":
			update_lighting(morning_color, morning_intensity)
		"SUNSET":
			update_lighting(sunset_color, sunset_intensity)
		"DUSK":
			update_lighting(dusk_color, dusk_intensity)
		"NIGHT":
			update_lighting(night_color, night_intensity)
		"DAWN":
			update_lighting(dawn_color, dawn_intensity)
		"EMERGENCY":
			update_lighting(emergency_color, emergency_intensity)
	
	if signal_bus:
		signal_bus.emit_signal("lighting_state_changed", state_name)

func determine_lighting_state():
	var state = LightingState.DAY
	
	if current_time >= night_start_hour or current_time < dawn_start_hour:
		state = LightingState.NIGHT
	elif current_time >= dusk_start_hour and current_time < night_start_hour:
		state = LightingState.DUSK
	elif current_time >= sunset_start_hour and current_time < dusk_start_hour:
		state = LightingState.SUNSET
	elif current_time >= dawn_start_hour and current_time < morning_start_hour:
		state = LightingState.DAWN
	elif current_time >= morning_start_hour and current_time < day_start_hour:
		state = LightingState.MORNING
	elif current_time >= day_start_hour and current_time < sunset_start_hour:
		state = LightingState.DAY
	
	update_lighting_by_name(get_state_name(state))

func update_lighting(color: Color, intensity: float):
	var final_color = color
	var final_intensity = intensity
	
	if use_color_override:
		final_color = color_override
	
	if use_intensity_override:
		final_intensity = intensity_override
	
	current_color = final_color
	current_intensity = final_intensity
	
	update_all_lights()

func update_all_lights():
	for light in registered_lights:
		if is_instance_valid(light):
			light.update_light(current_color, current_intensity)

func get_state_name(state: LightingState) -> String:
	match state:
		LightingState.DAY:
			return "DAY"
		LightingState.MORNING:
			return "MORNING"
		LightingState.SUNSET:
			return "SUNSET"
		LightingState.DUSK:
			return "DUSK"
		LightingState.NIGHT:
			return "NIGHT"
		LightingState.DAWN:
			return "DAWN"
		LightingState.EMERGENCY:
			return "EMERGENCY"
		_:
			return "DAY"

func set_time(hour: float):
	current_time = hour_to_time(hour)
	update_time(current_time)

func set_state_override(state: LightingState):
	state_override = state
	update_time(current_time)

func set_color_override(color: Color, use_override: bool = true):
	color_override = color
	use_color_override = use_override
	update_time(current_time)

func set_intensity_override(intensity: float, use_override: bool = true):
	intensity_override = intensity
	use_intensity_override = use_override
	update_time(current_time)

func register_light(light):
	if not light in registered_lights:
		registered_lights.append(light)
		light.update_light(current_color, current_intensity)

func unregister_light(light):
	if light in registered_lights:
		registered_lights.erase(light)

func get_current_time() -> float:
	return current_time

func get_current_hour() -> int:
	return int(current_time)

func get_current_minute() -> int:
	var hour = int(current_time)
	var minute = int((current_time - hour) * 60.0)
	return minute

func get_time_string() -> String:
	var hour = get_current_hour()
	var minute = get_current_minute()
	var am_pm = "AM" if hour < 12 else "PM"
	
	if hour == 0:
		hour = 12
	elif hour > 12:
		hour -= 12
	
	return "%d:%02d %s" % [hour, minute, am_pm] 
