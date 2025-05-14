extends Node
class_name LightingSystem

enum LightingPreset {
	DAY,
	SUNSET,
	DUSK,
	NIGHT,
	DAWN,
	MORNING,
	EMERGENCY
}

@export_category("Time Settings")
@export var day_night_cycle_enabled: bool = true
@export var day_length_minutes: float = 24.0
@export var time_scale: float = 1.0
@export var starting_hour: float = 8.0

@export_category("Lighting Presets")
@export var presets: Dictionary = {
	"DAY": {"color": Color(1.0, 1.0, 1.0), "intensity": 1.0, "hour_start": 8.0, "hour_end": 18.0},
	"SUNSET": {"color": Color(1.0, 0.8, 0.6), "intensity": 0.7, "hour_start": 18.0, "hour_end": 20.0},
	"DUSK": {"color": Color(0.6, 0.6, 0.8), "intensity": 0.5, "hour_start": 20.0, "hour_end": 22.0},
	"NIGHT": {"color": Color(0.3, 0.3, 0.6), "intensity": 0.3, "hour_start": 22.0, "hour_end": 4.0},
	"DAWN": {"color": Color(0.8, 0.8, 1.0), "intensity": 0.6, "hour_start": 4.0, "hour_end": 5.0},
	"MORNING": {"color": Color(1.0, 0.9, 0.8), "intensity": 0.8, "hour_start": 5.0, "hour_end": 8.0},
	"EMERGENCY": {"color": Color(1.0, 0.2, 0.2), "intensity": 0.9}
}

var current_time: float = 0.0
var current_preset: String = "DAY"
var registered_lights: Array = []
var override_preset: String = ""
var override_color: Color = Color.WHITE
var override_intensity: float = 1.0
var use_override: bool = false

signal time_changed(time)
signal preset_changed(preset_name)
signal lighting_updated(color, intensity)

func _ready():
	current_time = starting_hour
	if day_night_cycle_enabled:
		update_lighting()

func _process(delta):
	if day_night_cycle_enabled and override_preset.is_empty():
		var time_delta = delta * time_scale * (1440.0 / day_length_minutes / 60.0)
		current_time = fmod(current_time + time_delta, 24.0)
		update_lighting()

func update_lighting():
	if not use_override:
		determine_preset_from_time()
	
	var color = get_current_color()
	var intensity = get_current_intensity()
	
	update_all_lights(color, intensity)
	emit_signal("lighting_updated", color, intensity)

func determine_preset_from_time():
	var new_preset = "DAY"
	
	for preset_name in presets:
		var preset = presets[preset_name]
		if preset.has("hour_start") and preset.has("hour_end"):
			var start_hour = preset["hour_start"]
			var end_hour = preset["hour_end"]
			
			if start_hour < end_hour:
				if current_time >= start_hour and current_time < end_hour:
					new_preset = preset_name
					break
			else:
				if current_time >= start_hour or current_time < end_hour:
					new_preset = preset_name
					break
	
	if new_preset != current_preset:
		current_preset = new_preset
		emit_signal("preset_changed", current_preset)

func update_all_lights(color, intensity):
	for i in range(registered_lights.size() - 1, -1, -1):
		var light = registered_lights[i]
		if is_instance_valid(light):
			light.update_light(color, intensity)
		else:
			registered_lights.remove_at(i)

func get_current_color() -> Color:
	if use_override and not override_color.is_equal_approx(Color.WHITE):
		return override_color
	
	var preset_name = override_preset if not override_preset.is_empty() else current_preset
	return presets[preset_name]["color"]

func get_current_intensity() -> float:
	if use_override and override_intensity != 1.0:
		return override_intensity
	
	var preset_name = override_preset if not override_preset.is_empty() else current_preset
	return presets[preset_name]["intensity"]

func get_current_preset() -> String:
	return override_preset if not override_preset.is_empty() else current_preset

func get_current_time() -> float:
	return current_time

func get_time_string(use_12h: bool = true) -> String:
	var hour = int(current_time)
	var minute = int((current_time - hour) * 60.0)
	
	if use_12h:
		var am_pm = "AM" if hour < 12 else "PM"
		if hour == 0:
			hour = 12
		elif hour > 12:
			hour -= 12
		
		return "%d:%02d %s" % [hour, minute, am_pm]
	else:
		return "%02d:%02d" % [hour, minute]

func set_time(hour: float):
	current_time = fmod(hour, 24.0)
	if day_night_cycle_enabled:
		update_lighting()
	emit_signal("time_changed", current_time)

func set_preset_override(preset_name: String):
	if presets.has(preset_name):
		override_preset = preset_name
		update_lighting()
	else:
		override_preset = ""

func clear_preset_override():
	override_preset = ""
	update_lighting()

func set_color_override(color: Color):
	override_color = color
	use_override = true
	update_lighting()

func set_intensity_override(intensity: float):
	override_intensity = intensity
	use_override = true
	update_lighting()

func clear_overrides():
	override_preset = ""
	override_color = Color.WHITE
	override_intensity = 1.0
	use_override = false
	update_lighting()

func register_light(light):
	if not registered_lights.has(light):
		registered_lights.append(light)
		
		var color = get_current_color()
		var intensity = get_current_intensity()
		light.update_light(color, intensity)

func unregister_light(light):
	registered_lights.erase(light) 