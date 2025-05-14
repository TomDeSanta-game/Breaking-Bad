extends CanvasModulate

@export_category("Environment Light Settings")
@export var use_global_lighting: bool = true
@export var override_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var override_intensity: float = 1.0
@export var transition_speed: float = 2.0
@export var min_light_level: float = 0.1
@export var add_rim_light: bool = false

@export_category("Scene-Specific Settings")
@export var scene_type: String = "outdoors"
@export var time_of_day_effect: bool = true
@export var atmosphere_density: float = 0.0

var lighting_system = null
var signal_bus = null
var target_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var current_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var transitioning: bool = false
var scene_light_modifier: float = 1.0
var scene_color_modifier: Color = Color(1.0, 1.0, 1.0, 1.0)
var rim_light: DirectionalLight2D = null

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")
	if add_rim_light:
		add_rim_light_node()
	
	lighting_system = get_node_or_null("/root/DynamicLightingSystem")
	
	if use_global_lighting and lighting_system:
		connect_to_lighting_system()
	else:
		color = override_color
		current_color = override_color
		target_color = override_color
	
	set_scene_modifiers()

func _process(delta):
	if transitioning:
		current_color = current_color.lerp(target_color, delta * transition_speed)
		
		if current_color.is_equal_approx(target_color):
			transitioning = false
		
		update_environment_color()

func connect_to_lighting_system():
	if signal_bus:
		signal_bus.connect("lighting_state_changed", _on_lighting_state_changed)
		
		if lighting_system:
			var initial_color = lighting_system.get_current_color()
			var initial_intensity = lighting_system.get_current_intensity()
			update_from_lighting_system(initial_color, initial_intensity)

func update_from_lighting_system(light_color: Color, intensity: float):
	var adjusted_intensity = max(intensity, min_light_level)
	var new_color = light_color * adjusted_intensity * scene_color_modifier
	
	if scene_type == "indoors":
		new_color = new_color.lightened(0.2)
	elif scene_type == "lab":
		new_color = new_color.lerp(Color(0.8, 0.95, 1.0, 1.0), 0.3)
	elif scene_type == "desert":
		new_color = new_color.lerp(Color(1.0, 0.9, 0.7, 1.0), 0.4)
	
	target_color = new_color
	transitioning = true

func _on_lighting_state_changed(state_name: String):
	if lighting_system and use_global_lighting:
		var c = lighting_system.get_current_color()
		var intensity = lighting_system.get_current_intensity()
		update_from_lighting_system(c, intensity)
		
		if rim_light:
			update_rim_light(state_name)

func set_scene_modifiers():
	match scene_type:
		"outdoors":
			scene_light_modifier = 1.0
			scene_color_modifier = Color(1.0, 1.0, 1.0, 1.0)
		"indoors":
			scene_light_modifier = 0.8
			scene_color_modifier = Color(0.9, 0.9, 1.0, 1.0)
		"lab":
			scene_light_modifier = 0.9
			scene_color_modifier = Color(0.8, 0.95, 1.0, 1.0)
		"desert":
			scene_light_modifier = 1.1
			scene_color_modifier = Color(1.0, 0.9, 0.7, 1.0)

func update_environment_color():
	color = current_color
	
	if atmosphere_density > 0.01:
		apply_atmosphere_effect()

func apply_atmosphere_effect():
	var desaturation = min(atmosphere_density * 0.5, 0.4)
	var grey = (color.r + color.g + color.b) / 3.0
	color = color.lerp(Color(grey, grey, grey, 1.0), desaturation)
	
	if time_of_day_effect and lighting_system:
		var current_time = lighting_system.current_time
		if current_time > 6.0 and current_time < 10.0:
			color = color.lerp(Color(1.0, 0.8, 0.6, 1.0), 0.1)
		elif current_time > 17.0 and current_time < 20.0:
			color = color.lerp(Color(0.8, 0.5, 0.6, 1.0), 0.1)

func add_rim_light_node():
	rim_light = DirectionalLight2D.new()
	rim_light.color = Color(1.0, 0.9, 0.8, 1.0)
	rim_light.energy = 0.3
	rim_light.blend_mode = Light2D.BLEND_MODE_ADD
	rim_light.shadow_enabled = true
	rim_light.shadow_filter = 3
	rim_light.shadow_filter_smooth = 4.0
	rim_light.shadow_color = Color(0.0, 0.0, 0.1, 0.6)
	rim_light.global_rotation = deg_to_rad(45)
	add_child(rim_light)
	
func update_rim_light(state_name: String):
	if not rim_light:
		return
		
	match state_name:
		"DAWN":
			rim_light.energy = 0.4
			rim_light.color = Color(1.0, 0.7, 0.5, 1.0)
			rim_light.rotation = deg_to_rad(60)
		"DAY":
			rim_light.energy = 0.3
			rim_light.color = Color(1.0, 0.9, 0.8, 1.0)
			rim_light.rotation = deg_to_rad(45) 
		"DUSK":
			rim_light.energy = 0.35
			rim_light.color = Color(0.9, 0.6, 0.3, 1.0)
			rim_light.rotation = deg_to_rad(120)
		"NIGHT":
			rim_light.energy = 0.15
			rim_light.color = Color(0.5, 0.5, 0.8, 1.0)
			rim_light.rotation = deg_to_rad(180)
		"INDOOR_BRIGHT":
			rim_light.energy = 0.2
			rim_light.color = Color(1.0, 0.9, 0.8, 1.0)
		"INDOOR_DIM":
			rim_light.energy = 0.1
			rim_light.color = Color(0.8, 0.8, 0.9, 1.0)
		"INDOOR_DARK":
			rim_light.energy = 0.05
			rim_light.color = Color(0.3, 0.3, 0.5, 1.0)
		"LAB":
			rim_light.energy = 0.3
			rim_light.color = Color(0.6, 0.9, 1.0, 1.0)
		"EMERGENCY":
			rim_light.energy = 0.4
			rim_light.color = Color(1.0, 0.3, 0.2, 1.0) 
