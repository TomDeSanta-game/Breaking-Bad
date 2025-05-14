extends Node2D

var is_cooking = false
var cook_progress = 0.0
var cook_speed = 0.1
var chemical_quality = {
	"blue": 0.0,
	"green": 0.0,
	"yellow": 0.0
}
var batch_quality = 0.0
var random = RandomNumberGenerator.new()
var particle_effects = []

@onready var progress_bar = $CanvasLayer/CookingUI/ProgressBar
@onready var blue_slider = $CanvasLayer/CookingUI/BlueSlider
@onready var green_slider = $CanvasLayer/CookingUI/GreenSlider
@onready var yellow_slider = $CanvasLayer/CookingUI/YellowSlider
@onready var status_label = $CanvasLayer/CookingUI/StatusLabel
@onready var quality_label = $CanvasLayer/CookingUI/QualityLabel
@onready var start_button = $CanvasLayer/CookingUI/StartButton
@onready var reaction_points = $ReactionPoints.get_children()

func _ready():
	random.randomize()
	blue_slider.value = 0.5
	green_slider.value = 0.5
	yellow_slider.value = 0.5
	update_quality_display()
	start_button.pressed.connect(_on_start_button_pressed)

func _process(delta):
	if is_cooking:
		cook_progress += cook_speed * delta
		progress_bar.value = cook_progress
		
		if cook_progress >= 100:
			complete_batch()
			
		if randf() < 0.05:
			create_random_reaction()

func _on_start_button_pressed():
	if !is_cooking:
		start_cooking()
	else:
		adjust_cooking()

func start_cooking():
	is_cooking = true
	cook_progress = 0.0
	
	chemical_quality["blue"] = blue_slider.value
	chemical_quality["green"] = green_slider.value
	chemical_quality["yellow"] = yellow_slider.value
	
	update_quality_display()
	start_button.text = "Adjust"
	status_label.text = "Status: Cooking in progress..."
	SignalBus.batch_started.emit()
	
	for point in reaction_points:
		create_reaction_at_point(point, dominant_chemical())

func adjust_cooking():
	chemical_quality["blue"] = lerp(chemical_quality["blue"], blue_slider.value, 0.3)
	chemical_quality["green"] = lerp(chemical_quality["green"], green_slider.value, 0.3)
	chemical_quality["yellow"] = lerp(chemical_quality["yellow"], yellow_slider.value, 0.3)
	update_quality_display()
	
	create_random_reaction()

func complete_batch():
	is_cooking = false
	cook_progress = 0.0
	
	batch_quality = calculate_batch_quality()
	
	progress_bar.value = 0
	start_button.text = "Start Cooking"
	status_label.text = "Status: Batch Complete!"
	quality_label.text = "Quality: " + str(int(batch_quality * 100)) + "%"
	
	clear_particle_effects()
	
	SignalBus.batch_complete.emit(batch_quality)

func create_random_reaction():
	if reaction_points.size() > 0:
		var point = reaction_points[randi() % reaction_points.size()]
		create_reaction_at_point(point, dominant_chemical())

func create_reaction_at_point(point, chemical_type):
	var particle_manager = get_node_or_null("/root/ParticleSystemManager")
	if particle_manager:
		clear_effect_at_point(point)
		
		var effect = particle_manager.spawn_chemical_reaction(
			point.global_position, 
			chemical_type, 
			0.8 + randf() * 0.4, 
			3.0 + randf() * 2.0
		)
		
		if effect:
			particle_effects.append({"point": point, "effect": effect})
			SignalBus.chemical_reaction_occurred.emit(chemical_type, point.global_position, 0.8 + randf() * 0.4)

func clear_effect_at_point(point):
	for i in range(particle_effects.size() - 1, -1, -1):
		if particle_effects[i].point == point:
			if is_instance_valid(particle_effects[i].effect):
				particle_effects[i].effect.queue_free()
			particle_effects.remove_at(i)

func clear_particle_effects():
	for effect_data in particle_effects:
		if is_instance_valid(effect_data.effect):
			effect_data.effect.queue_free()
	particle_effects.clear()

func dominant_chemical() -> String:
	var max_val = max(chemical_quality["blue"], max(chemical_quality["green"], chemical_quality["yellow"]))
	if max_val == chemical_quality["blue"]:
		return "blue"
	elif max_val == chemical_quality["green"]:
		return "green"
	else:
		return "yellow"

func calculate_batch_quality() -> float:
	var blue_diff = abs(chemical_quality["blue"] - 0.6)
	var green_diff = abs(chemical_quality["green"] - 0.3)
	var yellow_diff = abs(chemical_quality["yellow"] - 0.1)
	
	var quality = 1.0 - (blue_diff + green_diff + yellow_diff) / 3.0
	
	return clamp(quality, 0.0, 1.0)

func update_quality_display():
	var quality = calculate_batch_quality()
	quality_label.text = "Quality: " + str(int(quality * 100)) + "%"

func _exit_tree():
	clear_particle_effects()
