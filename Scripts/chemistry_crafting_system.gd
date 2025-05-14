extends Node
class_name ChemistryCraftingSystem

signal crafting_started(recipe_name)
signal crafting_progress(progress, max_progress)
signal crafting_completed(recipe_name, quality)
signal crafting_failed(recipe_name, reason)

const ELEMENT_TYPES = {
	"Methylamine": {"color": Color(0.2, 0.6, 0.9), "volatility": 0.5, "purity": 0.9},
	"Pseudoephedrine": {"color": Color(0.9, 0.9, 0.9), "volatility": 0.3, "purity": 0.7},
	"Phosphorus": {"color": Color(1.0, 0.5, 0.2), "volatility": 0.8, "purity": 0.85},
	"Aluminum": {"color": Color(0.7, 0.7, 0.7), "volatility": 0.1, "purity": 0.95},
	"Sodium_Hydroxide": {"color": Color(0.9, 0.9, 0.6), "volatility": 0.6, "purity": 0.8},
	"Hydrochloric_Acid": {"color": Color(0.8, 0.3, 0.3), "volatility": 0.7, "purity": 0.9},
	"Iodine": {"color": Color(0.5, 0.0, 0.5), "volatility": 0.4, "purity": 0.85},
	"Red_Phosphorus": {"color": Color(0.8, 0.0, 0.0), "volatility": 0.7, "purity": 0.85},
	"Hydrogen": {"color": Color(0.8, 0.8, 1.0), "volatility": 0.9, "purity": 0.99},
}

const RECIPES = {
	"Blue_Meth": {
		"elements": ["Methylamine", "Aluminum", "Sodium_Hydroxide"],
		"quantities": [3, 1, 1],
		"temperature": 85.0,
		"mixing_time": 10.0,
		"difficulty": 0.7,
		"result": "Blue_Crystal",
		"quality_threshold": 0.75,
		"value_multiplier": 2.0,
		"xp_reward": 100
	},
	"Red_Phosphorus_Meth": {
		"elements": ["Pseudoephedrine", "Red_Phosphorus", "Iodine"],
		"quantities": [2, 1, 1],
		"temperature": 70.0,
		"mixing_time": 8.0,
		"difficulty": 0.5,
		"result": "Crystal",
		"quality_threshold": 0.65,
		"value_multiplier": 1.0,
		"xp_reward": 50
	},
	"Ricin": {
		"elements": ["Hydrogen", "Sodium_Hydroxide", "Hydrochloric_Acid"],
		"quantities": [1, 1, 2],
		"temperature": 45.0,
		"mixing_time": 12.0,
		"difficulty": 0.9,
		"result": "Poison",
		"quality_threshold": 0.8,
		"value_multiplier": 3.0,
		"xp_reward": 150
	}
}

var inventory = {}
var current_recipe = null
var crafting_in_progress = false
var crafting_progress_value = 0.0
var crafting_timer = 0.0
var current_temperature = 25.0
var current_mixing_speed = 0.0
var result_quality = 0.0
var crafting_xp = 0

func _ready():
	initialize_inventory()

func initialize_inventory():
	for element in ELEMENT_TYPES.keys():
		inventory[element] = 0

func add_element(element_name: String, amount: int = 1):
	if element_name in inventory:
		inventory[element_name] += amount
		return true
	return false

func remove_element(element_name: String, amount: int = 1):
	if element_name in inventory and inventory[element_name] >= amount:
		inventory[element_name] -= amount
		return true
	return false

func has_elements_for_recipe(recipe_name: String) -> bool:
	if not recipe_name in RECIPES:
		return false
		
	var recipe = RECIPES[recipe_name]
	
	for i in range(recipe.elements.size()):
		var element = recipe.elements[i]
		var quantity = recipe.quantities[i]
		
		if not element in inventory or inventory[element] < quantity:
			return false
	
	return true

func start_crafting(recipe_name: String) -> bool:
	if crafting_in_progress or not recipe_name in RECIPES or not has_elements_for_recipe(recipe_name):
		return false
	
	current_recipe = recipe_name
	var recipe = RECIPES[recipe_name]
	
	for i in range(recipe.elements.size()):
		var element = recipe.elements[i]
		var quantity = recipe.quantities[i]
		remove_element(element, quantity)
	
	crafting_in_progress = true
	crafting_progress_value = 0.0
	crafting_timer = 0.0
	current_temperature = 25.0
	current_mixing_speed = 0.0
	result_quality = 0.5
	
	crafting_started.emit(recipe_name)
	return true

func set_temperature(temp: float):
	if not crafting_in_progress:
		return
		
	current_temperature = clamp(temp, 20.0, 120.0)
	update_quality_based_on_parameters()

func set_mixing_speed(speed: float):
	if not crafting_in_progress:
		return
		
	current_mixing_speed = clamp(speed, 0.0, 1.0)
	update_quality_based_on_parameters()

func update_quality_based_on_parameters():
	if not current_recipe or not crafting_in_progress:
		return
		
	var recipe = RECIPES[current_recipe]
	var ideal_temp = recipe.temperature
	var temp_deviation = abs(current_temperature - ideal_temp) / 100.0
	var mixing_ideal = 0.6
	var mixing_deviation = abs(current_mixing_speed - mixing_ideal)
	
	var volatility_factor = 0.0
	for element in recipe.elements:
		volatility_factor += ELEMENT_TYPES[element].volatility
	volatility_factor /= recipe.elements.size()
	
	var risk_factor = volatility_factor * (temp_deviation + mixing_deviation)
	
	if randf() < risk_factor * 0.1:
		trigger_accident(risk_factor)
	
	var quality_change = (1.0 - temp_deviation * 2.0) * 0.01
	quality_change += (1.0 - mixing_deviation * 2.0) * 0.01
	
	result_quality = clamp(result_quality + quality_change, 0.0, 1.0)

func trigger_accident(risk_factor: float):
	var accident_type = "minor"
	var position = Vector2.ZERO
	
	if risk_factor > 0.5:
		accident_type = "major"
	
	if risk_factor > 0.8:
		accident_type = "explosion"
		crafting_failed.emit(current_recipe, "Explosion due to high temperature and volatility")
		crafting_in_progress = false
		current_recipe = null
		
		SignalBus.explosion_occurred.emit(position, risk_factor, risk_factor * 100.0)
		return
	
	var effect_position = position
	var intensity = risk_factor
	SignalBus.chemical_reaction_occurred.emit(accident_type, effect_position, intensity)

func _process(delta: float):
	if crafting_in_progress:
		crafting_timer += delta
		var recipe = RECIPES[current_recipe]
		var max_time = recipe.mixing_time
		
		crafting_progress_value = crafting_timer / max_time
		update_quality_based_on_parameters()
		
		crafting_progress.emit(crafting_progress_value, 1.0)
		
		if crafting_progress_value >= 1.0:
			complete_crafting()

func complete_crafting():
	if not crafting_in_progress:
		return
		
	crafting_in_progress = false
	var recipe = RECIPES[current_recipe]
	
	var success = result_quality >= recipe.quality_threshold
	if success:
		var xp_earned = recipe.xp_reward * result_quality
		crafting_xp += xp_earned
		
		SignalBus.batch_complete.emit(result_quality)
		crafting_completed.emit(current_recipe, result_quality)
	else:
		SignalBus.batch_failed.emit()
		crafting_failed.emit(current_recipe, "Quality too low")
	
	current_recipe = null

func get_recipe_info(recipe_name: String) -> Dictionary:
	if recipe_name in RECIPES:
		return RECIPES[recipe_name]
	return {}

func get_element_info(element_name: String) -> Dictionary:
	if element_name in ELEMENT_TYPES:
		return ELEMENT_TYPES[element_name]
	return {}

func create_chemical_reaction(position: Vector2, chemical_type: String, intensity: float = 1.0):
	SignalBus.chemical_reaction_occurred.emit(chemical_type, position, intensity) 