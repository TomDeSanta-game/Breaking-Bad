extends Node

@export_category("Environment Settings")
@export var environment_container: NodePath
@export var auto_connect_to_lighting: bool = true

@export_category("Default Lighting")
@export var default_ambient_energy: float = 0.3
@export var default_ambient_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var default_shadow_strength: float = 0.5

@export_category("State Modifiers")
@export var day_ambient_energy_mod: float = 1.0
@export var day_ambient_color_mod: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var day_shadow_mod: float = 1.0

@export var morning_ambient_energy_mod: float = 0.8
@export var morning_ambient_color_mod: Color = Color(1.0, 0.9, 0.8, 1.0)
@export var morning_shadow_mod: float = 0.9

@export var sunset_ambient_energy_mod: float = 0.7
@export var sunset_ambient_color_mod: Color = Color(1.0, 0.8, 0.6, 1.0)
@export var sunset_shadow_mod: float = 0.8

@export var dusk_ambient_energy_mod: float = 0.5
@export var dusk_ambient_color_mod: Color = Color(0.6, 0.6, 0.8, 1.0)
@export var dusk_shadow_mod: float = 0.7

@export var night_ambient_energy_mod: float = 0.3
@export var night_ambient_color_mod: Color = Color(0.3, 0.3, 0.6, 1.0)
@export var night_shadow_mod: float = 0.9

@export var dawn_ambient_energy_mod: float = 0.6
@export var dawn_ambient_color_mod: Color = Color(0.8, 0.8, 1.0, 1.0)
@export var dawn_shadow_mod: float = 0.8

@export var emergency_ambient_energy_mod: float = 0.5
@export var emergency_ambient_color_mod: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var emergency_shadow_mod: float = 1.0

var ambient_light: CanvasModulate
var environment_nodes = []
var current_environment_state = "DAY"
var lighting_system = null
var signal_bus = null

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")
	
	if not environment_container.is_empty():
		var container = get_node_or_null(environment_container)
		if container:
			find_environment_nodes(container)
	
	var lighting_node = get_node_or_null("/root/DynamicLighting")
	if lighting_node:
		lighting_system = lighting_node.get_lighting_system()
	
	setup_ambient_light()
	
	if auto_connect_to_lighting and signal_bus:
		connect_to_lighting_system()

func find_environment_nodes(parent):
	for child in parent.get_children():
		if child is Node2D:
			environment_nodes.append(child)
		
		if child.get_child_count() > 0:
			find_environment_nodes(child)

func setup_ambient_light():
	ambient_light = CanvasModulate.new()
	ambient_light.name = "EnvironmentAmbientLight"
	ambient_light.color = default_ambient_color
	ambient_light.light_mask = 1
	add_child(ambient_light)
	
	update_environment_state(current_environment_state)

func connect_to_lighting_system():
	if signal_bus:
		signal_bus.connect("lighting_state_changed", Callable(self, "_on_lighting_state_changed"))

func _on_lighting_state_changed(state_name: String):
	update_environment_state(state_name)

func update_environment_state(state_name: String):
	current_environment_state = state_name
	
	var ambient_energy = default_ambient_energy
	var ambient_color = default_ambient_color
	var shadow_strength = default_shadow_strength
	
	match state_name:
		"DAY":
			ambient_energy *= day_ambient_energy_mod
			ambient_color *= day_ambient_color_mod
			shadow_strength *= day_shadow_mod
		"MORNING":
			ambient_energy *= morning_ambient_energy_mod
			ambient_color *= morning_ambient_color_mod
			shadow_strength *= morning_shadow_mod
		"SUNSET":
			ambient_energy *= sunset_ambient_energy_mod
			ambient_color *= sunset_ambient_color_mod
			shadow_strength *= sunset_shadow_mod
		"DUSK":
			ambient_energy *= dusk_ambient_energy_mod
			ambient_color *= dusk_ambient_color_mod
			shadow_strength *= dusk_shadow_mod
		"NIGHT":
			ambient_energy *= night_ambient_energy_mod
			ambient_color *= night_ambient_color_mod
			shadow_strength *= night_shadow_mod
		"DAWN":
			ambient_energy *= dawn_ambient_energy_mod
			ambient_color *= dawn_ambient_color_mod
			shadow_strength *= dawn_shadow_mod
		"EMERGENCY":
			ambient_energy *= emergency_ambient_energy_mod
			ambient_color *= emergency_ambient_color_mod
			shadow_strength *= emergency_shadow_mod
	
	if ambient_light:
		ambient_light.color = ambient_color * ambient_energy
	
	update_environment_shadows(shadow_strength)

func update_environment_shadows(strength: float):
	for node in environment_nodes:
		if is_instance_valid(node) and node is Node2D:
			if node.has_method("set_shadow_strength"):
				node.set_shadow_strength(strength)

func set_lighting_state(state_name: String):
	if lighting_system:
		lighting_system.update_lighting_by_name(state_name)
	else:
		update_environment_state(state_name)

func get_current_state() -> String:
	return current_environment_state 
