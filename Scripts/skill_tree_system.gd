extends Node

signal skill_points_changed(current, total_earned)
signal skill_unlocked(skill_id, skill_data)
signal skill_tree_progress_changed(tree_id, current_level, max_level)

enum SkillTree {
	CHEMISTRY,
	COMBAT,
	NEGOTIATION,
	BUSINESS
}

const SKILL_TREE_DATA = {
	SkillTree.CHEMISTRY: {
		"name": "Chemistry",
		"description": "Improve your ability to create higher quality substances",
		"skills": {
			"chemistry_basics": {
				"name": "Chemistry Basics",
				"description": "Basic understanding of chemical reactions",
				"level": 1,
				"cost": 1,
				"effects": {
					"crafting_quality_bonus": 0.1
				},
				"requires": []
			},
			"advanced_synthesis": {
				"name": "Advanced Synthesis",
				"description": "Improved methods for synthesizing chemicals",
				"level": 2,
				"cost": 2,
				"effects": {
					"crafting_speed_bonus": 0.15,
					"crafting_quality_bonus": 0.15
				},
				"requires": ["chemistry_basics"]
			},
			"stabilizing_compounds": {
				"name": "Stabilizing Compounds",
				"description": "Create more stable chemical reactions",
				"level": 2,
				"cost": 2,
				"effects": {
					"accident_chance_reduction": 0.2
				},
				"requires": ["chemistry_basics"]
			},
			"master_chemist": {
				"name": "Master Chemist",
				"description": "Elite chemical knowledge and techniques",
				"level": 3,
				"cost": 3,
				"effects": {
					"crafting_quality_bonus": 0.3,
					"crafting_speed_bonus": 0.2,
					"accident_chance_reduction": 0.3
				},
				"requires": ["advanced_synthesis", "stabilizing_compounds"]
			},
			"blue_perfection": {
				"name": "Blue Perfection",
				"description": "Perfect the blue crystal recipe",
				"level": 4,
				"cost": 5,
				"effects": {
					"blue_meth_value_multiplier": 1.5,
					"blue_meth_quality_bonus": 0.5
				},
				"requires": ["master_chemist"]
			}
		}
	},
	SkillTree.COMBAT: {
		"name": "Combat",
		"description": "Improve your fighting capabilities",
		"skills": {
			"basic_fighting": {
				"name": "Basic Fighting",
				"description": "Learn basic self-defense techniques",
				"level": 1,
				"cost": 1,
				"effects": {
					"melee_damage_bonus": 0.1,
					"health_bonus": 10.0
				},
				"requires": []
			},
			"weapon_proficiency": {
				"name": "Weapon Proficiency",
				"description": "Improved handling of various weapons",
				"level": 2,
				"cost": 2,
				"effects": {
					"ranged_accuracy_bonus": 0.15,
					"weapon_sway_reduction": 0.2
				},
				"requires": ["basic_fighting"]
			},
			"physical_conditioning": {
				"name": "Physical Conditioning",
				"description": "Improved physical capabilities",
				"level": 2,
				"cost": 2,
				"effects": {
					"stamina_max_bonus": 20.0,
					"stamina_recovery_bonus": 0.2,
					"movement_speed_bonus": 0.1
				},
				"requires": ["basic_fighting"]
			},
			"tactical_expert": {
				"name": "Tactical Expert",
				"description": "Advanced combat tactics and techniques",
				"level": 3,
				"cost": 3,
				"effects": {
					"stealth_takedown_speed_bonus": 0.3,
					"parkour_stamina_cost_reduction": 0.2,
					"detection_chance_reduction": 0.2
				},
				"requires": ["weapon_proficiency", "physical_conditioning"]
			},
			"kingpin": {
				"name": "Kingpin",
				"description": "Command respect through fear and intimidation",
				"level": 4,
				"cost": 5,
				"effects": {
					"intimidation_chance_bonus": 0.5,
					"reputation_gain_with_criminal_factions": 0.3,
					"territory_defense_bonus": 0.4
				},
				"requires": ["tactical_expert"]
			}
		}
	},
	SkillTree.NEGOTIATION: {
		"name": "Negotiation",
		"description": "Improve your social and manipulation skills",
		"skills": {
			"basic_persuasion": {
				"name": "Basic Persuasion",
				"description": "Learn fundamental persuasion techniques",
				"level": 1,
				"cost": 1,
				"effects": {
					"sell_price_bonus": 0.1,
					"buy_price_discount": 0.05
				},
				"requires": []
			},
			"manipulation": {
				"name": "Manipulation",
				"description": "Manipulate others to get what you want",
				"level": 2,
				"cost": 2,
				"effects": {
					"npc_favor_chance_bonus": 0.2,
					"bribe_effectiveness_bonus": 0.25
				},
				"requires": ["basic_persuasion"]
			},
			"convincing_lies": {
				"name": "Convincing Lies",
				"description": "Tell more convincing lies",
				"level": 2,
				"cost": 2,
				"effects": {
					"disguise_effectiveness_bonus": 0.2,
					"suspicion_reduction_bonus": 0.15
				},
				"requires": ["basic_persuasion"]
			},
			"master_negotiator": {
				"name": "Master Negotiator",
				"description": "Elite negotiation and social manipulation",
				"level": 3,
				"cost": 3,
				"effects": {
					"sell_price_bonus": 0.3,
					"buy_price_discount": 0.2,
					"relationship_improvement_bonus": 0.25
				},
				"requires": ["manipulation", "convincing_lies"]
			},
			"puppetmaster": {
				"name": "Puppetmaster",
				"description": "Control others from behind the scenes",
				"level": 4,
				"cost": 5,
				"effects": {
					"partner_loyalty_bonus": 0.5,
					"betrayal_chance_reduction": 0.4,
					"territory_expansion_bonus": 0.3
				},
				"requires": ["master_negotiator"]
			}
		}
	},
	SkillTree.BUSINESS: {
		"name": "Business",
		"description": "Improve your business and empire management skills",
		"skills": {
			"basic_economics": {
				"name": "Basic Economics",
				"description": "Understand fundamental business principles",
				"level": 1,
				"cost": 1,
				"effects": {
					"passive_income_bonus": 0.1,
					"business_startup_cost_reduction": 0.05
				},
				"requires": []
			},
			"supply_chain": {
				"name": "Supply Chain",
				"description": "Optimize your supply chain operations",
				"level": 2,
				"cost": 2,
				"effects": {
					"supply_cost_reduction": 0.15,
					"supply_quantity_bonus": 0.2
				},
				"requires": ["basic_economics"]
			},
			"investment_strategy": {
				"name": "Investment Strategy",
				"description": "Make smarter business investments",
				"level": 2,
				"cost": 2,
				"effects": {
					"property_income_bonus": 0.2,
					"business_value_growth_bonus": 0.15
				},
				"requires": ["basic_economics"]
			},
			"empire_manager": {
				"name": "Empire Manager",
				"description": "Expert management of your criminal enterprises",
				"level": 3,
				"cost": 3,
				"effects": {
					"territory_income_bonus": 0.25,
					"employee_efficiency_bonus": 0.2,
					"police_bribe_cost_reduction": 0.3
				},
				"requires": ["supply_chain", "investment_strategy"]
			},
			"heisenberg": {
				"name": "Heisenberg",
				"description": "Become a legendary business mastermind",
				"level": 4,
				"cost": 5,
				"effects": {
					"product_demand_bonus": 0.5,
					"competitor_intimidation_bonus": 0.4,
					"global_income_multiplier": 1.3
				},
				"requires": ["empire_manager"]
			}
		}
	}
}

var skill_points = 0
var total_skill_points_earned = 0
var unlocked_skills = {}
var tree_levels = {}

func _ready():
	for tree_id in SkillTree.values():
		tree_levels[tree_id] = 0
		
	SignalBus.batch_complete.connect(_on_batch_complete)
	SignalBus.objective_completed.connect(_on_objective_completed)
	SignalBus.player_event.connect(_on_player_event)

func _on_batch_complete(quality):
	add_skill_points(1 + int(quality * 2))

func _on_objective_completed(_objective_id):
	add_skill_points(3)

func _on_player_event(event_type, data):
	if event_type == "unlock_skill":
		var skill_id = data.skill_id if "skill_id" in data else ""
		if not skill_id.is_empty():
			unlock_skill(skill_id)

func add_skill_points(amount):
	skill_points += amount
	total_skill_points_earned += amount
	skill_points_changed.emit(skill_points, total_skill_points_earned)
	
	SignalBus.notification_requested.emit(
		"Skill Points",
		"Earned " + str(amount) + " skill points",
		"reward",
		3.0
	)

func get_skill_data(skill_id):
	for tree_id in SkillTree.values():
		var tree_data = SKILL_TREE_DATA[tree_id]
		if skill_id in tree_data.skills:
			return tree_data.skills[skill_id]
	
	return null

func get_tree_for_skill(skill_id):
	for tree_id in SkillTree.values():
		var tree_data = SKILL_TREE_DATA[tree_id]
		if skill_id in tree_data.skills:
			return tree_id
	
	return -1

func find_tree_max_level(tree_id):
	var max_level = 0
	var tree_data = SKILL_TREE_DATA[tree_id]
	
	for skill_id in tree_data.skills:
		var skill = tree_data.skills[skill_id]
		max_level = max(max_level, skill.level)
	
	return max_level

func is_skill_available(skill_id):
	var skill_data = get_skill_data(skill_id)
	
	if not skill_data:
		return false
	
	for required_skill in skill_data.requires:
		if not required_skill in unlocked_skills:
			return false
	
	return true

func can_unlock_skill(skill_id):
	var skill_data = get_skill_data(skill_id)
	
	if not skill_data:
		return false
	
	if skill_id in unlocked_skills:
		return false
	
	if not is_skill_available(skill_id):
		return false
	
	if skill_points < skill_data.cost:
		return false
	
	return true

func unlock_skill(skill_id):
	if not can_unlock_skill(skill_id):
		return false
	
	var skill_data = get_skill_data(skill_id)
	var tree_id = get_tree_for_skill(skill_id)
	
	if tree_id < 0 or not skill_data:
		return false
	
	skill_points -= skill_data.cost
	unlocked_skills[skill_id] = skill_data.effects
	
	tree_levels[tree_id] = max(tree_levels[tree_id], skill_data.level)
	
	skill_unlocked.emit(skill_id, skill_data)
	skill_points_changed.emit(skill_points, total_skill_points_earned)
	skill_tree_progress_changed.emit(tree_id, tree_levels[tree_id], find_tree_max_level(tree_id))
	
	apply_skill_effects(skill_id)
	
	SignalBus.notification_requested.emit(
		"Skill Unlocked",
		"Learned " + skill_data.name,
		"unlock",
		4.0
	)
	
	SignalBus.player_event.emit("skill_unlocked", {"skill_id": skill_id, "skill_data": skill_data})
	
	return true

func apply_skill_effects(skill_id):
	var effects = unlocked_skills[skill_id]
	
	for effect_name in effects.keys():
		var effect_value = effects[effect_name]
		
		match effect_name:
			"health_bonus":
				if SignalBus.get_signal_connection_count("player_stat_modified") > 0:
					SignalBus.player_stat_modified.emit("health", effect_value)
			
			"stamina_max_bonus":
				if SignalBus.get_signal_connection_count("player_stat_modified") > 0:
					SignalBus.player_stat_modified.emit("max_stamina", effect_value)
			
			"movement_speed_bonus":
				if SignalBus.get_signal_connection_count("player_stat_modified") > 0:
					SignalBus.player_stat_modified.emit("speed", effect_value)

func get_total_skill_effect(effect_name):
	var total_effect = 0.0
	
	for skill_id in unlocked_skills.keys():
		var effects = unlocked_skills[skill_id]
		if effect_name in effects:
			total_effect += effects[effect_name]
	
	return total_effect

func get_tree_level(tree_id):
	if tree_id in tree_levels:
		return tree_levels[tree_id]
	return 0

func get_tree_skills(tree_id):
	if tree_id in SKILL_TREE_DATA:
		return SKILL_TREE_DATA[tree_id].skills
	return {}

func get_unlocked_skills():
	return unlocked_skills

func get_available_skills():
	var available = []
	
	for tree_id in SkillTree.values():
		var tree_data = SKILL_TREE_DATA[tree_id]
		for skill_id in tree_data.skills:
			if not skill_id in unlocked_skills and is_skill_available(skill_id):
				available.append(skill_id)
	
	return available

func get_skill_points():
	return skill_points

func get_formatted_effect_text(effect_name, effect_value):
	var text = ""
	var value_text = ""
	
	if effect_value >= 0:
		value_text = "+" + str(effect_value)
	else:
		value_text = str(effect_value)
	
	if effect_value >= 1.0 and effect_name.contains("multiplier"):
		value_text = "x" + str(effect_value)
	elif effect_name.contains("bonus") or effect_name.contains("reduction") or effect_name.contains("discount"):
		value_text = str(int(effect_value * 100)) + "%"
	
	match effect_name:
		"health_bonus":
			text = value_text + " Health"
		"stamina_max_bonus":
			text = value_text + " Max Stamina"
		"stamina_recovery_bonus":
			text = value_text + " Stamina Recovery"
		"movement_speed_bonus":
			text = value_text + " Movement Speed"
		"melee_damage_bonus":
			text = value_text + " Melee Damage"
		"ranged_accuracy_bonus":
			text = value_text + " Ranged Accuracy"
		"crafting_quality_bonus":
			text = value_text + " Crafting Quality"
		"crafting_speed_bonus":
			text = value_text + " Crafting Speed"
		"accident_chance_reduction":
			text = value_text + " Accident Chance"
		"sell_price_bonus":
			text = value_text + " Selling Prices"
		"buy_price_discount":
			text = value_text + " Purchase Discount"
		_:
			var readable_name = effect_name.replace("_", " ").capitalize()
			text = value_text + " " + readable_name
	
	return text 