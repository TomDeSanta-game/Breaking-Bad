extends Node2D
class_name LightBase

@export_category("Base Light Settings")
@export var light_enabled: bool = true
@export var base_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var base_energy: float = 1.0
@export var register_with_system: bool = true
@export var shadow_enabled: bool = false
@export var shadow_strength: float = 0.5

@export_category("Effect Settings")
@export var effect_enabled: bool = false
@export var effect_type: String = "none"
@export var effect_speed: float = 1.0
@export var effect_intensity: float = 0.1

var time_passed: float = 0.0
var lighting_system = null
var current_modulation: Color = Color(1.0, 1.0, 1.0, 1.0)
var current_energy_mod: float = 1.0
var is_registered: bool = false

func _ready():
	if register_with_system:
		register_with_lighting_system()
	
	initialize_light()

func _process(delta):
	if effect_enabled and light_enabled:
		time_passed += delta * effect_speed
		apply_effect()

func initialize_light():
	lighting_system = get_node_or_null("/root/LightingSystem")
	if not lighting_system:
		lighting_system = get_node_or_null("/root/DynamicLightingSystem")

func apply_effect():
	pass

func update_light(modulation: Color, intensity_modifier: float):
	current_modulation = modulation
	current_energy_mod = intensity_modifier
	
	if light_enabled:
		apply_modulation(modulation, intensity_modifier)

func apply_modulation(_modulation: Color, _intensity_modifier: float):
	pass

func set_light_enabled(enabled: bool):
	light_enabled = enabled
	apply_enabled_state(enabled)

func apply_enabled_state(_enabled: bool):
	pass

func set_effect_enabled(enabled: bool):
	effect_enabled = enabled
	
	if not effect_enabled and light_enabled:
		apply_modulation(current_modulation, current_energy_mod)

func register_with_lighting_system():
	if lighting_system and not is_registered:
		lighting_system.register_light(self)
		is_registered = true

func _exit_tree():
	if lighting_system and is_registered:
		lighting_system.unregister_light(self) 