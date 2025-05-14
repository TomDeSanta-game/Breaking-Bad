extends Node

var lighting_system = null

func _ready():
	if not Engine.is_editor_hint():
		lighting_system = get_node_or_null("/root/LightingSystem")
		
		if not lighting_system:
			lighting_system = LightingSystem.new()
			lighting_system.name = "LightingSystem"
			get_node("/root").add_child(lighting_system)

func set_preset(preset_name: String):
	if lighting_system:
		lighting_system.set_preset_override(preset_name)
		
func clear_preset_override():
	if lighting_system:
		lighting_system.clear_preset_override()

func set_color_override(color: Color):
	if lighting_system:
		lighting_system.set_color_override(color)
		
func set_intensity_override(intensity: float):
	if lighting_system:
		lighting_system.set_intensity_override(intensity)
		
func clear_overrides():
	if lighting_system:
		lighting_system.clear_overrides()
		
func get_current_preset() -> String:
	if lighting_system:
		return lighting_system.get_current_preset()
	return "DAY"
	
func get_current_color() -> Color:
	if lighting_system:
		return lighting_system.get_current_color()
	return Color.WHITE
	
func get_current_intensity() -> float:
	if lighting_system:
		return lighting_system.get_current_intensity()
	return 1.0
	
func get_current_time() -> float:
	if lighting_system:
		return lighting_system.get_current_time()
	return 12.0
	
func get_time_string(use_12h: bool = true) -> String:
	if lighting_system:
		return lighting_system.get_time_string(use_12h)
	return "12:00 PM" if use_12h else "12:00" 
