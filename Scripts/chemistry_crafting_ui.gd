extends Control

var crafting_system: ChemistryCraftingSystem

@onready var recipe_selector = $RecipeSelector
@onready var element_grid = $ElementGrid
@onready var temperature_slider = $TemperatureControl/Slider
@onready var temperature_label = $TemperatureControl/Value
@onready var mixing_slider = $MixingControl/Slider
@onready var mixing_label = $MixingControl/Value
@onready var progress_bar = $ProgressBar
@onready var quality_meter = $QualityMeter
@onready var status_label = $StatusLabel
@onready var start_button = $StartButton
@onready var recipe_info = $RecipeInfo
@onready var chemical_particles = $ChemicalParticles

var current_recipe = ""
var element_items = {}

func _ready():
	crafting_system = get_node("/root/ChemistryCraftingSystem")
	if not crafting_system:
		push_error("ChemistryCraftingSystem singleton not found!")
		return
	
	crafting_system.crafting_started.connect(_on_crafting_started)
	crafting_system.crafting_progress.connect(_on_crafting_progress)
	crafting_system.crafting_completed.connect(_on_crafting_completed)
	crafting_system.crafting_failed.connect(_on_crafting_failed)
	
	temperature_slider.value_changed.connect(_on_temperature_changed)
	mixing_slider.value_changed.connect(_on_mixing_changed)
	recipe_selector.item_selected.connect(_on_recipe_selected)
	start_button.pressed.connect(_on_start_pressed)
	
	initialize_ui()

func initialize_ui():
	recipe_selector.clear()
	
	var index = 0
	for recipe_name in crafting_system.RECIPES.keys():
		recipe_selector.add_item(recipe_name.replace("_", " "), index)
		index += 1
	
	if recipe_selector.item_count > 0:
		recipe_selector.select(0)
		_on_recipe_selected(0)
	
	update_element_display()
	update_recipe_info()
	update_controls_state(false)

func update_element_display():
	for child in element_grid.get_children():
		element_grid.remove_child(child)
		child.queue_free()
	
	element_items.clear()
	
	for element_name in crafting_system.inventory.keys():
		var element_box = HBoxContainer.new()
		var name_label = Label.new()
		var amount_label = Label.new()
		
		name_label.text = element_name.replace("_", " ")
		amount_label.text = str(crafting_system.inventory[element_name])
		
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(20, 20)
		color_rect.color = crafting_system.ELEMENT_TYPES[element_name].color
		
		element_box.add_child(color_rect)
		element_box.add_child(name_label)
		element_box.add_child(amount_label)
		
		element_grid.add_child(element_box)
		element_items[element_name] = amount_label

func update_recipe_info():
	recipe_info.clear()
	
	if current_recipe.is_empty() or not current_recipe in crafting_system.RECIPES:
		return
	
	var recipe = crafting_system.RECIPES[current_recipe]
	
	recipe_info.append_text("[b]" + current_recipe.replace("_", " ") + "[/b]\n\n")
	recipe_info.append_text("Required elements:\n")
	
	for i in range(recipe.elements.size()):
		var element = recipe.elements[i]
		var quantity = recipe.quantities[i]
		var color = crafting_system.ELEMENT_TYPES[element].color
		
		recipe_info.append_text("- [color=#" + color.to_html() + "]" + element.replace("_", " ") + "[/color]: " + str(quantity) + "\n")
	
	recipe_info.append_text("\nIdeal temperature: " + str(recipe.temperature) + "°C\n")
	recipe_info.append_text("Mixing time: " + str(recipe.mixing_time) + " seconds\n")
	recipe_info.append_text("Difficulty: " + str(int(recipe.difficulty * 100)) + "%\n")
	recipe_info.append_text("Result: " + recipe.result.replace("_", " ") + "\n")
	recipe_info.append_text("Value multiplier: " + str(recipe.value_multiplier) + "x\n")

func update_inventory_display():
	for element_name in element_items.keys():
		element_items[element_name].text = str(crafting_system.inventory[element_name])

func _on_recipe_selected(index: int):
	current_recipe = recipe_selector.get_item_text(index).replace(" ", "_")
	update_recipe_info()
	update_start_button_state()

func update_start_button_state():
	var can_craft = false
	
	if current_recipe and crafting_system:
		can_craft = crafting_system.has_elements_for_recipe(current_recipe)
	
	start_button.disabled = not can_craft or crafting_system.crafting_in_progress

func _on_start_pressed():
	if current_recipe and crafting_system:
		crafting_system.start_crafting(current_recipe)

func _on_crafting_started(_on_crafting_startedrecipe_name: String):
	update_inventory_display()
	update_controls_state(true)
	status_label.text = "Crafting in progress..."
	progress_bar.value = 0
	quality_meter.value = 50

func _on_crafting_progress(progress: float, _max_progress: float):
	progress_bar.value = progress * 100
	quality_meter.value = crafting_system.result_quality * 100
	
	if crafting_system.result_quality < 0.5:
		quality_meter.modulate = Color(1.0, 0.3, 0.3)
	elif crafting_system.result_quality < 0.7:
		quality_meter.modulate = Color(1.0, 1.0, 0.3)
	else:
		quality_meter.modulate = Color(0.3, 1.0, 0.3)

func _on_crafting_completed(recipe_name: String, quality: float):
	status_label.text = "Crafting completed! Quality: " + str(int(quality * 100)) + "%"
	update_controls_state(false)
	update_start_button_state()
	
	SignalBus.vfx_started.emit("chemistry_success", global_position)
	
	var recipe = crafting_system.RECIPES[recipe_name]
	SignalBus.notification_requested.emit(
		"Crafting Success", 
		"Created " + recipe.result.replace("_", " ") + " with " + str(int(quality * 100)) + "% quality",
		"success",
		3.0
	)

func _on_crafting_failed(_recipe_name: String, reason: String):
	status_label.text = "Crafting failed: " + reason
	update_controls_state(false)
	update_start_button_state()
	
	SignalBus.vfx_started.emit("chemistry_failure", global_position)
	
	SignalBus.notification_requested.emit(
		"Crafting Failed", 
		reason,
		"danger",
		3.0
	)

func update_controls_state(is_crafting: bool):
	temperature_slider.editable = is_crafting
	mixing_slider.editable = is_crafting
	recipe_selector.disabled = is_crafting
	start_button.disabled = is_crafting

func _on_temperature_changed(value: float):
	temperature_label.text = str(int(value)) + "°C"
	
	if crafting_system and crafting_system.crafting_in_progress:
		crafting_system.set_temperature(value)
		
		if value > 100:
			temperature_label.modulate = Color(1.0, 0.3, 0.3)
		elif value > 80:
			temperature_label.modulate = Color(1.0, 0.6, 0.3)
		else:
			temperature_label.modulate = Color(1.0, 1.0, 1.0)

func _on_mixing_changed(value: float):
	var speed_text = "Low"
	
	if value > 0.7:
		speed_text = "High"
	elif value > 0.3:
		speed_text = "Medium"
	
	mixing_label.text = speed_text
	
	if crafting_system and crafting_system.crafting_in_progress:
		crafting_system.set_mixing_speed(value)

func _process(delta: float):
	if crafting_system and crafting_system.crafting_in_progress:
		animate_chemical_particles(delta)
	elif chemical_particles.emitting:
		chemical_particles.emitting = false

func animate_chemical_particles(_delta: float):
	if not chemical_particles.emitting:
		chemical_particles.emitting = true
	
	var recipe = crafting_system.RECIPES[crafting_system.current_recipe]
	var avg_color = Color(0, 0, 0)
	
	for element in recipe.elements:
		avg_color += crafting_system.ELEMENT_TYPES[element].color
	
	avg_color = avg_color / recipe.elements.size()
	
	var particles_material = chemical_particles.process_material
	particles_material.color = avg_color
	
	var intensity = crafting_system.current_mixing_speed
	var emission_rate = 20 + intensity * 40
	
	chemical_particles.amount = int(emission_rate)
	particles_material.initial_velocity_min = 20 + intensity * 80
	particles_material.initial_velocity_max = 50 + intensity * 150 