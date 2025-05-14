extends Node

enum BusinessType {
	LAB,
	DISTRIBUTION,
	LAUNDERING,
	FRONT
}

const BUSINESS_PROPERTIES = {
	BusinessType.LAB: {
		"name": "Lab",
		"description": "Production facility for cooking product",
		"base_cost": 50000,
		"daily_expenses": 1000,
		"risk_level": 0.7,
		"upgrade_slots": 3,
		"staff_capacity": 2,
		"products": ["blue_sky", "standard_meth"],
		"visibility": 0.4,
		"required_skill_level": 1
	},
	BusinessType.DISTRIBUTION: {
		"name": "Distribution Network",
		"description": "Network for distributing product to dealers",
		"base_cost": 30000,
		"daily_expenses": 800,
		"risk_level": 0.5,
		"upgrade_slots": 2,
		"staff_capacity": 5,
		"products": [],
		"visibility": 0.6,
		"required_skill_level": 1
	},
	BusinessType.LAUNDERING: {
		"name": "Money Laundering Business",
		"description": "Legitimate business for laundering drug money",
		"base_cost": 80000,
		"daily_expenses": 1500,
		"risk_level": 0.3,
		"upgrade_slots": 2,
		"staff_capacity": 3,
		"products": [],
		"visibility": 0.2,
		"required_skill_level": 2
	},
	BusinessType.FRONT: {
		"name": "Front Business",
		"description": "Legitimate business providing cover for operations",
		"base_cost": 25000,
		"daily_expenses": 600,
		"risk_level": 0.2,
		"upgrade_slots": 1,
		"staff_capacity": 4,
		"products": [],
		"visibility": 0.1,
		"required_skill_level": 0
	}
}

const UPGRADE_TYPES = {
	"security": {
		"name": "Security System",
		"description": "Enhanced security reduces risk of raids",
		"cost": 15000,
		"effect": {
			"risk_reduction": 0.15
		},
		"level_scaling": 1.5
	},
	"equipment": {
		"name": "Equipment Upgrade",
		"description": "Better equipment increases production efficiency",
		"cost": 20000,
		"effect": {
			"production_bonus": 0.2
		},
		"level_scaling": 1.5
	},
	"staff_training": {
		"name": "Staff Training",
		"description": "Better trained staff improves overall efficiency",
		"cost": 10000,
		"effect": {
			"staff_efficiency": 0.15,
			"product_quality": 0.1
		},
		"level_scaling": 1.3
	},
	"laundering_efficiency": {
		"name": "Laundering Efficiency",
		"description": "Improves money laundering throughput",
		"cost": 25000,
		"effect": {
			"laundering_capacity": 0.25
		},
		"level_scaling": 1.6
	},
	"distribution_network": {
		"name": "Distribution Network",
		"description": "Expanded distribution network increases sales capacity",
		"cost": 18000,
		"effect": {
			"distribution_capacity": 0.2,
			"territory_influence": 0.1
		},
		"level_scaling": 1.4
	}
}

const TERRITORY_CONTROL_THRESHOLD = 0.6
const DEFAULT_STARTING_MONEY = 10000
const LAUNDERING_TAX_RATE = 0.15
const MAX_HEAT_LEVEL = 100.0
const DAILY_HEAT_DECAY = 5.0

var player_money = DEFAULT_STARTING_MONEY
var clean_money = 0
var dirty_money = 0
var laundering_capacity = 0.0
var daily_expenses = 0
var daily_income = 0
var global_heat_level = 0.0

var owned_businesses = {}
var territories = {}
var staff = {}
var inventory = {}

var day_counter = 0
var production_timer = 0.0
var production_cycle_duration = 10.0

func _ready():
	SignalBus.business_action.connect(_on_business_action)
	initialize_territories()

func _process(delta):
	process_production_cycles(delta)
	process_heat_decay(delta)

func initialize_territories():
	territories = {
		"albuquerque_north": {
			"name": "North Albuquerque",
			"control": 0.0,
			"rivals": ["local_gang"],
			"heat": 0.0,
			"value": 1.0,
			"connections": ["albuquerque_east", "albuquerque_west"]
		},
		"albuquerque_east": {
			"name": "East Albuquerque",
			"control": 0.0,
			"rivals": ["local_gang", "cartel"],
			"heat": 0.0,
			"value": 1.2,
			"connections": ["albuquerque_north", "albuquerque_south"]
		},
		"albuquerque_south": {
			"name": "South Valley",
			"control": 0.0,
			"rivals": ["cartel"],
			"heat": 0.0,
			"value": 0.9,
			"connections": ["albuquerque_east", "albuquerque_west"]
		},
		"albuquerque_west": {
			"name": "West Mesa",
			"control": 0.0,
			"rivals": ["local_gang"],
			"heat": 0.0,
			"value": 0.8,
			"connections": ["albuquerque_north", "albuquerque_south"]
		}
	}

func _on_business_action(action, data):
	match action:
		"purchase":
			purchase_business(data.type, data.territory_id, data.name)
		"sell":
			sell_business(data.business_id)
		"upgrade":
			upgrade_business(data.business_id, data.upgrade_type)
		"hire_staff":
			hire_staff(data.staff_id, data.business_id)
		"fire_staff":
			fire_staff(data.staff_id)
		"launder_money":
			launder_money(data.amount)
		"withdraw_money":
			withdraw_clean_money(data.amount)
		"expand_territory":
			expand_territory(data.territory_id, data.investment)

func purchase_business(business_type, territory_id, custom_name = ""):
	if not business_type in BusinessType.values():
		push_warning("Unknown business type: " + str(business_type))
		return false
	
	if not territory_id in territories:
		push_warning("Unknown territory: " + territory_id)
		return false
	
	var props = BUSINESS_PROPERTIES[business_type]
	var cost = props.base_cost
	
	if dirty_money + clean_money < cost:
		SignalBus.notification_requested.emit(
			"Insufficient Funds",
			"You don't have enough money to purchase this business",
			"warning",
			3.0
		)
		return false
	
	var business_id = generate_business_id()
	var territory_control = territories[territory_id].control
	
	var business_data = props.duplicate(true)
	business_data.id = business_id
	business_data.type = business_type
	business_data.territory = territory_id
	business_data.name = custom_name if not custom_name.is_empty() else props.name + " #" + str(business_id)
	business_data.staff = []
	business_data.upgrades = {}
	business_data.level = 1
	business_data.production_efficiency = 1.0
	business_data.last_production_time = Time.get_unix_time_from_system()
	business_data.stock = {}
	business_data.heat = territory_control * 10.0
	
	for product in props.products:
		business_data.stock[product] = 0
	
	owned_businesses[business_id] = business_data
	
	deduct_money(cost)
	daily_expenses += props.daily_expenses
	
	SignalBus.business_purchased.emit(business_data)
	
	SignalBus.notification_requested.emit(
		"Business Purchased",
		"You now own a " + props.name + " in " + territories[territory_id].name,
		"success",
		4.0
	)
	
	update_territorial_influence(territory_id)
	
	return true

func sell_business(business_id):
	if not business_id in owned_businesses:
		return false
	
	var business = owned_businesses[business_id]
	var props = BUSINESS_PROPERTIES[business.type]
	
	var value = props.base_cost * 0.7 * business.level
	
	for upgrade_type in business.upgrades:
		var upgrade = business.upgrades[upgrade_type]
		value += UPGRADE_TYPES[upgrade_type].cost * 0.5 * upgrade.level
	
	for staff_id in business.staff:
		if staff_id in staff:
			fire_staff(staff_id)
	
	add_dirty_money(value)
	daily_expenses -= props.daily_expenses
	
	var territory_id = business.territory
	var business_data = owned_businesses[business_id]
	
	owned_businesses.erase(business_id)
	
	SignalBus.business_sold.emit(business_data)
	
	SignalBus.notification_requested.emit(
		"Business Sold",
		"You sold your " + business.name + " for $" + str(int(value)),
		"info",
		3.0
	)
	
	update_territorial_influence(territory_id)
	
	return true

func upgrade_business(business_id, upgrade_type):
	if not business_id in owned_businesses or not upgrade_type in UPGRADE_TYPES:
		return false
	
	var business = owned_businesses[business_id]
	var upgrade_props = UPGRADE_TYPES[upgrade_type]
	
	var current_level = 0
	if upgrade_type in business.upgrades:
		current_level = business.upgrades[upgrade_type].level
	
	if current_level >= 3:
		SignalBus.notification_requested.emit(
			"Upgrade Failed",
			"This upgrade is already at maximum level",
			"warning",
			3.0
		)
		return false
	
	var next_level = current_level + 1
	var cost = upgrade_props.cost * pow(upgrade_props.level_scaling, current_level)
	
	if dirty_money + clean_money < cost:
		SignalBus.notification_requested.emit(
			"Insufficient Funds",
			"You don't have enough money to purchase this upgrade",
			"warning",
			3.0
		)
		return false
	
	deduct_money(cost)
	
	if not upgrade_type in business.upgrades:
		business.upgrades[upgrade_type] = {
			"level": 1,
			"effects": upgrade_props.effect.duplicate()
		}
	else:
		business.upgrades[upgrade_type].level = next_level
		
		for effect in upgrade_props.effect:
			business.upgrades[upgrade_type].effects[effect] = upgrade_props.effect[effect] * next_level
	
	apply_business_upgrades(business)
	
	SignalBus.notification_requested.emit(
		"Business Upgraded",
		"Upgraded " + upgrade_props.name + " to Level " + str(next_level),
		"success",
		3.0
	)
	
	return true

func apply_business_upgrades(business):
	var base_props = BUSINESS_PROPERTIES[business.type]
	
	business.production_efficiency = 1.0
	business.risk_level = base_props.risk_level
	
	for upgrade_type in business.upgrades:
		var upgrade = business.upgrades[upgrade_type]
		var effects = upgrade.effects
		
		for effect_type in effects:
			var effect_value = effects[effect_type]
			
			match effect_type:
				"production_bonus":
					business.production_efficiency += effect_value
				"risk_reduction":
					business.risk_level = max(0.1, business.risk_level - effect_value)
				"staff_efficiency":
					business.staff_efficiency = 1.0 + effect_value
				"product_quality":
					business.product_quality_bonus = effect_value
				"laundering_capacity":
					if business.type == BusinessType.LAUNDERING:
						calculate_laundering_capacity()
				"distribution_capacity":
					if business.type == BusinessType.DISTRIBUTION:
						business.distribution_capacity = 1.0 + effect_value
				"territory_influence":
					var territory_id = business.territory
					update_territorial_influence(territory_id)

func hire_staff(staff_id, business_id):
	if not staff_id in staff or not business_id in owned_businesses:
		return false
	
	var staff_member = staff[staff_id]
	var business = owned_businesses[business_id]
	
	if staff_member.assigned_business != null:
		fire_staff(staff_id)
	
	if business.staff.size() >= BUSINESS_PROPERTIES[business.type].staff_capacity:
		SignalBus.notification_requested.emit(
			"Hiring Failed",
			"This business is already at maximum staff capacity",
			"warning",
			3.0
		)
		return false
	
	staff_member.assigned_business = business_id
	business.staff.append(staff_id)
	
	daily_expenses += staff_member.salary
	
	SignalBus.notification_requested.emit(
		"Staff Hired",
		"Hired " + staff_member.name + " for " + business.name,
		"success",
		3.0
	)
	
	return true

func fire_staff(staff_id):
	if not staff_id in staff:
		return false
	
	var staff_member = staff[staff_id]
	
	if staff_member.assigned_business == null:
		return false
	
	var business_id = staff_member.assigned_business
	
	if business_id in owned_businesses:
		var business = owned_businesses[business_id]
		business.staff.erase(staff_id)
	
	staff_member.assigned_business = null
	daily_expenses -= staff_member.salary
	
	SignalBus.notification_requested.emit(
		"Staff Fired",
		"Fired " + staff_member.name,
		"info",
		3.0
	)
	
	return true

func calculate_laundering_capacity():
	laundering_capacity = 0.0
	
	for business_id in owned_businesses:
		var business = owned_businesses[business_id]
		
		if business.type == BusinessType.LAUNDERING:
			var base_capacity = 10000.0
			var capacity_multiplier = 1.0
			
			if "laundering_capacity" in business:
				capacity_multiplier = business.laundering_capacity
			
			laundering_capacity += base_capacity * capacity_multiplier * business.level
	
	return laundering_capacity

func launder_money(amount):
	if amount <= 0 or amount > dirty_money:
		return false
	
	var daily_capacity = calculate_laundering_capacity() / 30.0
	
	if amount > daily_capacity:
		amount = daily_capacity
	
	var tax = amount * LAUNDERING_TAX_RATE
	var laundered_amount = amount - tax
	
	dirty_money -= amount
	clean_money += laundered_amount
	
	SignalBus.notification_requested.emit(
		"Money Laundered",
		"Laundered $" + str(int(amount)) + " with $" + str(int(tax)) + " in fees",
		"info",
		3.0
	)
	
	SignalBus.money_changed.emit(get_total_money())
	
	return true

func withdraw_clean_money(amount):
	if amount <= 0 or amount > clean_money:
		return false
	
	clean_money -= amount
	add_money(amount)
	
	SignalBus.notification_requested.emit(
		"Money Withdrawn",
		"Withdrew $" + str(int(amount)) + " from clean money reserves",
		"info",
		3.0
	)
	
	SignalBus.money_changed.emit(get_total_money())
	
	return true

func process_production_cycles(delta):
	production_timer += delta / 86400.0
	
	if production_timer >= production_cycle_duration:
		production_timer = 0.0
		day_counter += 1
		
		for business_id in owned_businesses:
			process_business_production(business_id)
		
		process_daily_finances()

func process_business_production(business_id):
	var business = owned_businesses[business_id]
	var business_type = business.type
	
	match business_type:
		BusinessType.LAB:
			produce_product(business_id)
		BusinessType.DISTRIBUTION:
			distribute_product(business_id)
		BusinessType.LAUNDERING:
			process_laundering(business_id)
		BusinessType.FRONT:
			generate_front_income(business_id)

func produce_product(business_id):
	var business = owned_businesses[business_id]
	
	if business.products.is_empty():
		return
	
	var product_type = business.products[0]
	
	if "blue_sky" in business.products and "blue_perfection" in get_unlocked_skills():
		product_type = "blue_sky"
	
	var base_amount = 100.0
	var quality = 0.5
	

	var staff_bonus = 0.0
	for staff_id in business.staff:
		if staff_id in staff:
			var staff_member = staff[staff_id]
			staff_bonus += staff_member.efficiency * 0.1
	

	var production_bonus = business.production_efficiency - 1.0
	var quality_bonus = 0.0
	
	if "product_quality_bonus" in business:
		quality_bonus = business.product_quality_bonus
	

	var total_amount = base_amount * (1.0 + staff_bonus + production_bonus)
	var total_quality = min(1.0, quality + quality_bonus + staff_bonus * 0.2)
	

	if product_type == "blue_sky" and "blue_perfection" in get_unlocked_skills():
		var skill_effect = get_skill_effect("blue_meth_quality_bonus")
		total_quality = min(1.0, total_quality + skill_effect)
	

	if not product_type in inventory:
		inventory[product_type] = {
			"amount": 0.0,
			"quality": 0.0
		}
	
	var old_amount = inventory[product_type].amount
	var old_quality = inventory[product_type].quality
	

	var new_total = old_amount + total_amount
	var new_quality = (old_amount * old_quality + total_amount * total_quality) / new_total
	
	inventory[product_type].amount = new_total
	inventory[product_type].quality = new_quality
	

	business.stock[product_type] = total_amount
	

	var territory_id = business.territory
	if territory_id in territories:
		territories[territory_id].heat += 10.0 * business.risk_level
	
	global_heat_level += 5.0 * business.risk_level
	
	var product_data = {
		"type": product_type,
		"amount": total_amount,
		"quality": total_quality
	}
	
	SignalBus.production_cycle_completed.emit(business_id, product_data)
	
	SignalBus.notification_requested.emit(
		"Production Complete",
		business.name + " produced " + str(int(total_amount)) + "g of " + product_type.replace("_", " ") + " (" + str(int(total_quality * 100)) + "% quality)",
		"success",
		3.0
	)

func distribute_product(business_id):
	var business = owned_businesses[business_id]
	var territory_id = business.territory
	
	if not territory_id in territories:
		return
	
	var territory = territories[territory_id]
	var territory_control = territory.control
	
	if territory_control < 0.3:
		SignalBus.notification_requested.emit(
			"Distribution Failed",
			"Insufficient territory control to distribute product",
			"warning",
			3.0
		)
		return
	
	var distribution_capacity = 100.0
	if "distribution_capacity" in business:
		distribution_capacity *= business.distribution_capacity
	

	var products_to_distribute = []
	
	for product_type in inventory.keys():
		if inventory[product_type].amount > 0:
			products_to_distribute.append(product_type)
	
	if products_to_distribute.is_empty():
		return
	
	var total_income = 0.0
	var distributed_amount = 0.0
	
	for product_type in products_to_distribute:
		var product_data = inventory[product_type]
		var amount_to_distribute = min(distribution_capacity, product_data.amount)
		var quality = product_data.quality
		
		var base_price = get_product_base_price(product_type)
		var price_modifier = 1.0 + (quality - 0.5) * 2.0
		var territory_value = territory.value
		var control_bonus = territory_control * 0.5
		
		var final_price = base_price * price_modifier * territory_value * (1.0 + control_bonus)
		

		if product_type == "blue_sky" and "blue_perfection" in get_unlocked_skills():
			var value_multiplier = get_skill_effect("blue_meth_value_multiplier")
			final_price *= value_multiplier
		
		var income = amount_to_distribute * final_price
		
		total_income += income
		distributed_amount += amount_to_distribute
		
		inventory[product_type].amount -= amount_to_distribute
	
	add_dirty_money(total_income)
	

	territories[territory_id].heat += 5.0 * (1.0 - territory_control)
	global_heat_level += 2.0 * (1.0 - territory_control)
	
	SignalBus.notification_requested.emit(
		"Product Distributed",
		"Sold " + str(int(distributed_amount)) + "g of product for $" + str(int(total_income)),
		"success",
		3.0
	)

func process_laundering(business_id):

	var business = owned_businesses[business_id]
	

	var base_income = 1000.0
	var business_level = business.level
	
	var legitimate_income = base_income * business_level
	
	add_money(legitimate_income)
	

	var auto_launder_amount = min(dirty_money, calculate_laundering_capacity() * 0.1)
	if auto_launder_amount > 0:
		launder_money(auto_launder_amount)

func generate_front_income(business_id):
	var business = owned_businesses[business_id]
	var business_level = business.level
	
	var base_income = 800.0 * business_level
	

	var staff_bonus = 0.0
	for staff_id in business.staff:
		if staff_id in staff:
			staff_bonus += staff[staff_id].efficiency * 0.05
	
	var total_income = base_income * (1.0 + staff_bonus)
	
	add_money(total_income)
	
	SignalBus.notification_requested.emit(
		"Front Business Income",
		business.name + " generated $" + str(int(total_income)),
		"info",
		3.0
	)

func process_daily_finances():
	var daily_profit = daily_income - daily_expenses
	
	if daily_profit < 0 and player_money < abs(daily_profit):
		SignalBus.notification_requested.emit(
			"Financial Problems",
			"You don't have enough money to pay daily expenses!",
			"danger",
			5.0
		)
		

		for business_id in owned_businesses:
			var business = owned_businesses[business_id]
			business.heat += 5.0
		
		global_heat_level += 10.0
	else:
		player_money += daily_profit
	
	SignalBus.money_changed.emit(get_total_money())
	

	for territory_id in territories:
		var territory = territories[territory_id]
		

		territory.control = max(0.0, territory.control - 0.05)
		

		territory.heat = max(0.0, territory.heat - 3.0)
		
		if territory.control >= TERRITORY_CONTROL_THRESHOLD and not is_territory_controlled(territory_id):
			SignalBus.notification_requested.emit(
				"Territory Controlled",
				"You now control " + territory.name,
				"success",
				4.0
			)
			SignalBus.territory_changed.emit(territory_id, true)
		elif territory.control < TERRITORY_CONTROL_THRESHOLD and is_territory_controlled(territory_id):
			SignalBus.notification_requested.emit(
				"Territory Lost",
				"You've lost control of " + territory.name,
				"danger",
				4.0
			)
			SignalBus.territory_changed.emit(territory_id, false)

func expand_territory(territory_id, investment):
	if not territory_id in territories:
		return false
	
	if investment <= 0 or investment > player_money:
		SignalBus.notification_requested.emit(
			"Insufficient Funds",
			"You don't have enough money for this investment",
			"warning",
			3.0
		)
		return false
	
	var territory = territories[territory_id]
	var current_control = territory.control
	var control_increase = investment / 50000.0
	

	if current_control > 0.5:
		control_increase *= 0.7
	if current_control > 0.7:
		control_increase *= 0.7
	
	territory.control = min(1.0, current_control + control_increase)
	territory.heat += investment / 5000.0
	
	deduct_money(investment)
	
	SignalBus.notification_requested.emit(
		"Territory Expanded",
		"Invested $" + str(int(investment)) + " in " + territory.name,
		"success",
		3.0
	)
	
	update_territorial_influence(territory_id)
	
	return true

func update_territorial_influence(territory_id):
	if not territory_id in territories:
		return
	
	var territory = territories[territory_id]
	var influence = 0.0
	

	for business_id in owned_businesses:
		var business = owned_businesses[business_id]
		
		if business.territory == territory_id:
			influence += 0.1 * business.level
			

			if business.type == BusinessType.DISTRIBUTION:
				influence += 0.2
				if "territory_influence" in business:
					influence += 0.1 * business.territory_influence
	
	territory.control = min(1.0, territory.control + influence)
	
	if territory.control >= TERRITORY_CONTROL_THRESHOLD and not is_territory_controlled(territory_id):
		SignalBus.notification_requested.emit(
			"Territory Controlled",
			"You now control " + territory.name,
			"success",
			4.0
		)
		SignalBus.territory_changed.emit(territory_id, true)

func process_heat_decay(delta):
	global_heat_level = max(0.0, global_heat_level - DAILY_HEAT_DECAY * delta / 86400.0)

func is_territory_controlled(territory_id):
	if not territory_id in territories:
		return false
	
	return territories[territory_id].control >= TERRITORY_CONTROL_THRESHOLD

func get_product_base_price(product_type):
	match product_type:
		"blue_sky":
			return 100.0
		"standard_meth":
			return 80.0
		_:
			return 50.0

func add_money(amount):
	player_money += amount
	SignalBus.money_changed.emit(get_total_money())

func add_dirty_money(amount):
	dirty_money += amount
	SignalBus.money_changed.emit(get_total_money())

func deduct_money(amount):
	var remaining = amount
	

	if player_money >= remaining:
		player_money -= remaining
		remaining = 0
	else:
		remaining -= player_money
		player_money = 0
	

	if remaining > 0 and dirty_money >= remaining:
		dirty_money -= remaining
	
	SignalBus.money_changed.emit(get_total_money())

func get_total_money():
	return player_money

func get_dirty_money():
	return dirty_money

func get_clean_money():
	return clean_money

func get_unlocked_skills():
	var skill_tree = get_node_or_null("/root/SkillTreeSystem")
	if skill_tree:
		return skill_tree.get_unlocked_skills()
	return {}

func get_skill_effect(effect_name):
	var skill_tree = get_node_or_null("/root/SkillTreeSystem")
	if skill_tree:
		return skill_tree.get_total_skill_effect(effect_name)
	return 0.0

func generate_business_id():
	return "business_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000) 