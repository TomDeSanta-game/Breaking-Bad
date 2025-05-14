extends Node

var dust_particles = []
var smoke_particles = []
var wind_particles = []
var chemical_particles = []

var global_intensity = 1.0
var particle_settings = {
	"dust": {
		"enabled": true,
		"base_amount": 10,
		"base_velocity": Vector2(5, 5),
		"color": Color(0.8, 0.8, 0.6, 0.4)
	},
	"smoke": {
		"enabled": false,
		"base_amount": 5,
		"base_velocity": Vector2(0, -20),
		"color": Color(0.2, 0.2, 0.2, 0.6)
	},
	"wind": {
		"enabled": false,
		"base_amount": 15,
		"base_velocity": Vector2(50, 0),
		"color": Color(0.9, 0.9, 0.9, 0.2)
	},
	"chemical": {
		"enabled": false,
		"base_amount": 20,
		"base_velocity": Vector2(0, -10),
		"color": Color(0.1, 0.4, 0.8, 0.7)
	}
}

var current_area = "default"
var area_modifiers = {
	"default": {"dust": 1.0, "smoke": 1.0, "wind": 1.0, "chemical": 1.0},
	"lab": {"dust": 0.5, "smoke": 1.5, "wind": 0.0, "chemical": 2.0},
	"desert": {"dust": 2.0, "smoke": 0.8, "wind": 1.5, "chemical": 0.0},
	"home": {"dust": 0.8, "smoke": 0.2, "wind": 0.5, "chemical": 0.0},
	"rv": {"dust": 1.0, "smoke": 1.5, "wind": 0.3, "chemical": 1.5}
}

func _ready():
	SignalBus.area_changed.connect(_on_area_changed)
	set_process(true)
	
	find_existing_particle_nodes()
	update_all_particles()

func _process(delta):
	update_particle_parameters(delta)

func set_global_intensity(intensity: float):
	global_intensity = clamp(intensity, 0.0, 2.0)
	update_all_particles()

func find_existing_particle_nodes():
	dust_particles = get_tree().get_nodes_in_group("dust_particles")
	smoke_particles = get_tree().get_nodes_in_group("smoke_particles")
	wind_particles = get_tree().get_nodes_in_group("wind_particles")
	chemical_particles = get_tree().get_nodes_in_group("chemical_particles")

func update_all_particles():
	update_particle_type(dust_particles, "dust")
	update_particle_type(smoke_particles, "smoke")
	update_particle_type(wind_particles, "wind")
	update_particle_type(chemical_particles, "chemical")

func update_particle_type(particles: Array, type: String):
	var settings = particle_settings[type]
	var area_mod = area_modifiers[current_area][type]
	var final_amount = int(settings.base_amount * global_intensity * area_mod)
	
	if !settings.enabled:
		final_amount = 0
	
	for particle in particles:
		if particle is GPUParticles2D:
			if particle.emitting != settings.enabled:
				particle.emitting = settings.enabled
			
			if particle.process_material:
				particle.amount = final_amount
				
				if particle.process_material is ParticleProcessMaterial:
					particle.process_material.color = settings.color
					
					var velocity = settings.base_velocity * global_intensity * area_mod
					particle.process_material.initial_velocity_min = velocity.length() * 0.7
					particle.process_material.initial_velocity_max = velocity.length() * 1.3
					
					if velocity.x != 0:
						particle.process_material.direction = Vector3(sign(velocity.x), 0, 0)
					if velocity.y != 0:
						particle.process_material.direction = Vector3(0, sign(velocity.y), 0)

func update_particle_parameters(_delta):
	if current_area == "desert":
		var wind_variation = sin(Time.get_ticks_msec() / 2000.0) * 0.5 + 0.5
		var dust_variation = cos(Time.get_ticks_msec() / 3000.0) * 0.3 + 0.7
		
		for particle in wind_particles:
			if particle is GPUParticles2D and particle.process_material:
				particle.process_material.initial_velocity_min = 30 + wind_variation * 30
				particle.process_material.initial_velocity_max = 50 + wind_variation * 50
		
		for particle in dust_particles:
			if particle is GPUParticles2D:
				particle.amount = int(particle_settings.dust.base_amount * dust_variation * global_intensity * area_modifiers[current_area].dust)

func enable_dust(enabled: bool = true):
	particle_settings.dust.enabled = enabled
	update_particle_type(dust_particles, "dust")

func enable_smoke(enabled: bool = true):
	particle_settings.smoke.enabled = enabled
	update_particle_type(smoke_particles, "smoke")

func enable_wind(enabled: bool = true):
	particle_settings.wind.enabled = enabled
	update_particle_type(wind_particles, "wind")

func enable_chemical(enabled: bool = true):
	particle_settings.chemical.enabled = enabled
	update_particle_type(chemical_particles, "chemical")

func create_chemical_burst(position: Vector2, type: String = "blue", duration: float = 2.0):
	var particle = GPUParticles2D.new()
	particle.position = position
	particle.amount = 30
	particle.lifetime = 2.0
	particle.explosiveness = 0.8
	particle.one_shot = true
	particle.add_to_group("chemical_particles")
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45
	mat.initial_velocity_min = 20
	mat.initial_velocity_max = 40
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	
	if type == "blue":
		mat.color = Color(0.1, 0.4, 0.8, 0.7)
	elif type == "yellow":
		mat.color = Color(0.8, 0.8, 0.1, 0.7)
	elif type == "green":
		mat.color = Color(0.1, 0.8, 0.4, 0.7)
	
	particle.process_material = mat
	get_tree().current_scene.add_child(particle)
	particle.emitting = true
	
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func(): particle.queue_free())
	
	return particle

func create_dust_burst(position: Vector2, intensity: float = 1.0, duration: float = 1.0):
	var particle = GPUParticles2D.new()
	particle.position = position
	particle.amount = int(20 * intensity)
	particle.lifetime = 1.0
	particle.explosiveness = 0.9
	particle.one_shot = true
	particle.add_to_group("dust_particles")
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180
	mat.initial_velocity_min = 20 * intensity
	mat.initial_velocity_max = 40 * intensity
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(0.8, 0.8, 0.6, 0.4)
	
	particle.process_material = mat
	get_tree().current_scene.add_child(particle)
	particle.emitting = true
	
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func(): particle.queue_free())
	
	return particle

func _on_area_changed(area_name: String):
	current_area = area_name if area_modifiers.has(area_name) else "default"
	update_all_particles() 