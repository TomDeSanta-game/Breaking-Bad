extends Node2D

signal reflection_updated(surface_type)

var reflection_enabled = true
var global_intensity = 1.0

var reflection_surfaces = {
	"glass": [],
	"metal": [],
	"crystal": [],
	"water": []
}

var surface_properties = {
	"glass": {
		"specular": 0.7,
		"roughness": 0.1,
		"metallic": 0.0,
		"reflectivity": 0.5,
		"refraction": 0.1,
		"color_modulation": Color(1.0, 1.0, 1.0, 1.0)
	},
	"metal": {
		"specular": 0.8,
		"roughness": 0.2,
		"metallic": 1.0,
		"reflectivity": 0.7,
		"refraction": 0.0,
		"color_modulation": Color(0.9, 0.9, 1.0, 1.0)
	},
	"crystal": {
		"specular": 0.9,
		"roughness": 0.05,
		"metallic": 0.0,
		"reflectivity": 0.8,
		"refraction": 0.2,
		"color_modulation": Color(0.8, 0.95, 1.0, 1.0)
	},
	"water": {
		"specular": 0.6,
		"roughness": 0.3,
		"metallic": 0.0,
		"reflectivity": 0.4,
		"refraction": 0.3,
		"color_modulation": Color(0.7, 0.8, 1.0, 0.8)
	}
}

var environment_light = {
	"intensity": 1.0,
	"direction": Vector2(1.0, 1.0),
	"color": Color(1.0, 0.98, 0.95, 1.0)
}

var initialized = false

func _ready():
	find_reflection_surfaces()
	set_process(true)
	initialized = true
	update_all_surfaces()

func _process(delta):
	if !reflection_enabled:
		return
		
	animate_reflections(delta)

func set_global_intensity(intensity: float):
	global_intensity = clamp(intensity, 0.0, 2.0)
	if initialized:
		update_all_surfaces()

func enable_reflections(enabled: bool = true):
	reflection_enabled = enabled
	if initialized:
		update_all_surfaces()

func find_reflection_surfaces():
	for surface_type in reflection_surfaces.keys():
		reflection_surfaces[surface_type] = get_tree().get_nodes_in_group(surface_type + "_surface")

func update_all_surfaces():
	for surface_type in reflection_surfaces.keys():
		update_surface_type(surface_type)

func update_surface_type(surface_type: String):
	if !reflection_surfaces.has(surface_type):
		return
		
	var surfaces = reflection_surfaces[surface_type]
	var properties = surface_properties[surface_type]
	
	for surface in surfaces:
		apply_material_properties(surface, properties, surface_type)
	
	emit_signal("reflection_updated", surface_type)

func apply_material_properties(surface: Node, properties: Dictionary, surface_type: String):
	if !reflection_enabled:
		reset_material(surface)
		return
		
	if surface is CanvasItem:
		var mat = surface.material
		if mat == null:
			mat = ShaderMaterial.new()
			surface.material = mat
			
		if mat is ShaderMaterial:
			var shader_path = "res://Resources/Shaders/" + surface_type + "_reflection.gdshader"
			var shader = load(shader_path) if ResourceLoader.exists(shader_path) else load_default_reflection_shader()
			
			if shader:
				mat.shader = shader
				
				var effective_intensity = global_intensity
				mat.set_shader_parameter("reflection_intensity", properties.reflectivity * effective_intensity)
				mat.set_shader_parameter("specular", properties.specular * effective_intensity)
				mat.set_shader_parameter("roughness", properties.roughness)
				mat.set_shader_parameter("metallic", properties.metallic)
				mat.set_shader_parameter("refraction", properties.refraction * effective_intensity)
				mat.set_shader_parameter("color_modulation", properties.color_modulation)
				
				mat.set_shader_parameter("light_direction", environment_light.direction.normalized())
				mat.set_shader_parameter("light_color", environment_light.color)
				mat.set_shader_parameter("light_intensity", environment_light.intensity * effective_intensity)

func reset_material(surface: Node):
	if surface is CanvasItem:
		surface.material = null

func animate_reflections(_delta):
	var time = Time.get_ticks_msec() / 1000.0
	
	for surface_type in reflection_surfaces.keys():
		var surfaces = reflection_surfaces[surface_type]
		
		for surface in surfaces:
			if surface is CanvasItem and surface.material is ShaderMaterial:
				var mat = surface.material
				
				var movement = Vector2(sin(time * 0.7), cos(time * 0.5)) * 0.02
				mat.set_shader_parameter("time_offset", time)
				mat.set_shader_parameter("reflection_offset", movement)

func load_default_reflection_shader():
	return load("res://Resources/Shaders/default_reflection.gdshader")

func set_environment_light(intensity: float, direction: Vector2, color: Color):
	environment_light.intensity = intensity
	environment_light.direction = direction.normalized()
	environment_light.color = color
	
	if initialized:
		update_all_surfaces()

func register_surface(node: Node, surface_type: String):
	if !reflection_surfaces.has(surface_type):
		return
		
	node.add_to_group(surface_type + "_surface")
	reflection_surfaces[surface_type].append(node)
	
	var properties = surface_properties[surface_type]
	apply_material_properties(node, properties, surface_type)

func deregister_surface(node: Node, surface_type: String):
	if !reflection_surfaces.has(surface_type):
		return
		
	node.remove_from_group(surface_type + "_surface")
	reflection_surfaces[surface_type].erase(node)
	reset_material(node) 