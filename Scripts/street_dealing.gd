extends Node

enum PRODUCT_TYPE {BLUE, WHITE, PILLS}
enum CUSTOMER_TYPE {CASUAL, JUNKIE, DEALER, UNDERCOVER}

@export_category("Dealing Settings")
@export var enable_dealing: bool = true
@export var base_deal_time: float = 10.0
@export var max_customers_per_area: int = 3
@export var customer_spawn_time: float = 15.0
@export var max_price_negotiation: float = 1.5
@export var base_negotiation_steps: int = 3

var territories = {}
var active_customers = {}
var active_deals = {}
var current_territory = ""
var player_products = {}
var player_cash = 0.0
var reputation = {}
var heat = {}
var territory_heat = {}
var territory_reputation = {}
var dealing_enabled = true
var signal_bus = null
var tension_manager = null

var customer_types = {
	CUSTOMER_TYPE.CASUAL: {
		"name": "Casual",
		"weight": 10.0,
		"price_sensitivity": 0.7,
		"quality_sensitivity": 0.5,
		"heat_modifier": 0.5,
		"patience": 3.0,
		"dialog_options": {
			"greeting": [
				"Hey, heard you might have something for me.",
				"You got the stuff?"
			],
			"negotiation": {
				"too_high": [
					"That's too much.",
					"You think I'm stupid?",
					"I'll find someone else.",
					"Forget about it."
				],
				"acceptable": [
					"Yeah, that works for me.",
					"That's what I'm talking about.",
					"Let's do it."
				],
				"negotiate": [
					"Can you do any better?",
					"That's steep... how about less?",
					"That's not what I had in mind."
				]
			},
			"success": [
				"Thanks, pleasure doing business.",
				"Nice, that's what I needed."
			],
			"reject": [
				"No way, that's too much.",
				"You think I'm taking me for a fool?"
			],
			"leave": [
				"I'm out of here.",
				"This is a waste of time."
			]
		}
	},
	CUSTOMER_TYPE.JUNKIE: {
		"name": "Junkie",
		"weight": 5.0,
		"price_sensitivity": 0.3,
		"quality_sensitivity": 0.2,
		"heat_modifier": 0.3,
		"patience": 2.0,
		"dialog_options": {
			"greeting": [
				"Hey man, got anything?",
				"I need a fix, you holding?"
			],
			"negotiation": {
				"too_high": [
					"No way I can afford that!",
					"Come on, I'm desperate here.",
					"That's killing me, man."
				],
				"acceptable": [
					"Yeah, yeah, that works.",
					"I'll take it, I'll take it!",
					"Thank god, yes."
				],
				"negotiate": [
					"Can't you go lower? Please?",
					"I don't have that much...",
					"How about a discount for a regular?"
				]
			},
			"success": [
				"Oh thank you, thank you!",
				"You're a lifesaver, man."
			],
			"reject": [
				"Forget it, I'll find someone else.",
				"You're worse than the withdrawal."
			],
			"leave": [
				"I gotta go, I'm getting sick...",
				"Can't wait anymore, I'm out."
			]
		}
	},
	CUSTOMER_TYPE.DEALER: {
		"name": "Dealer",
		"weight": 2.0,
		"price_sensitivity": 0.9,
		"quality_sensitivity": 0.9,
		"heat_modifier": 0.7,
		"patience": 4.0,
		"dialog_options": {
			"greeting": [
				"Looking to re-up.",
				"Got something special?"
			],
			"negotiation": {
				"too_high": [
					"Never gonna move it at that price.",
					"You're out of your mind with those numbers.",
					"Market rate is way lower."
				],
				"acceptable": [
					"That's fair, I can work with that.",
					"I'll take it off your hands.",
					"Deal."
				],
				"negotiate": [
					"I need better margins than that.",
					"Let's talk bulk discount.",
					"My customers expect better prices."
				]
			},
			"success": [
				"Good doing business.",
				"I'll be back for more if quality checks out."
			],
			"reject": [
				"Not at these prices.",
				"You're asking too much for this quality."
			],
			"leave": [
				"I've got other suppliers.",
				"You're wasting my time."
			]
		}
	},
	CUSTOMER_TYPE.UNDERCOVER: {
		"name": "Curious Buyer",
		"weight": 1.0,
		"price_sensitivity": 0.1,
		"quality_sensitivity": 0.1,
		"heat_modifier": 5.0,
		"patience": 5.0,
		"is_undercover": true,
		"dialog_options": {
			"greeting": [
				"Hey, I heard you're the one to talk to.",
				"First time buyer, need something good."
			],
			"negotiation": {
				"too_high": [
					"That's a bit steep for a first buy.",
					"I was told prices were better.",
					"I might need to shop around."
				],
				"acceptable": [
					"Sounds reasonable.",
					"I can do that.",
					"Price seems fair."
				],
				"negotiate": [
					"Can you do better for a first-timer?",
					"Is that your best price?",
					"I was hoping for a better deal."
				]
			},
			"success": [
				"Transaction complete.",
				"Pleasure doing business with you."
			],
			"reject": [
				"I'll have to reconsider.",
				"That's not working for me."
			],
			"leave": [
				"I need to think about this more.",
				"I'll get back to you."
			]
		}
	}
}

var product_data = {
	"blue": {
		"name": "Blue Crystal",
		"base_price": 100.0,
		"quality": 0.9,
		"heat_modifier": 1.0
	},
	"white": {
		"name": "White Crystal",
		"base_price": 70.0,
		"quality": 0.7,
		"heat_modifier": 0.7
	},
	"pills": {
		"name": "Pills",
		"base_price": 30.0,
		"quality": 0.4,
		"heat_modifier": 0.5
	}
}

func _ready():
	signal_bus = get_node_or_null("/root/SignalBus")
	tension_manager = get_node_or_null("/root/TensionManager")
	
	player_products = {
		"blue": 0,
		"white": 0,
		"pills": 0
	}
	
	player_cash = 500.0
	
	if signal_bus:
		signal_bus.tension_changed.connect(_on_tension_changed)

func _on_tension_changed(_current, _previous):
	if _current >= 0.8:
		dealing_enabled = false
	else:
		dealing_enabled = true

func _process(_delta):
	if !enable_dealing:
		return
		
	update_territory_heat(_delta)
	update_customer_patience(_delta)

func update_territory_heat(_delta):
	for territory_id in territory_heat.keys():
		if territory_heat[territory_id] > 0:
			territory_heat[territory_id] = max(0, territory_heat[territory_id] - 0.01 * _delta)
			if territory_heat[territory_id] < 0.1:
				territory_cooled_down(territory_id)

func update_customer_patience(_delta):
	var customers_to_remove = []
	
	for customer_id in active_deals.keys():
		if active_deals[customer_id].has("patience_timer"):
			active_deals[customer_id].patience_timer -= _delta
			if active_deals[customer_id].patience_timer <= 0:
				customers_to_remove.append(customer_id)
	
	for customer_id in customers_to_remove:
		customer_leaves(customer_id)

func territory_cooled_down(territory_id):
	if signal_bus:
		signal_bus.territory_heat_reduced.emit(territory_id)

func register_territory(territory_id, territory):
	territories[territory_id] = territory
	territory_heat[territory_id] = 0.0
	territory_reputation[territory_id] = 0.5

func set_current_territory(territory_id):
	if !territories.has(territory_id):
		current_territory = ""
		return
		
	current_territory = territory_id

func get_current_territory_data():
	if current_territory == "" || !territories.has(current_territory):
		return null
	return territories[current_territory].get_territory_data()

func can_deal() -> bool:
	if !dealing_enabled:
		return false
		
	if current_territory == "" || !territories.has(current_territory):
		return false
		
	var territory_data = territories[current_territory].get_territory_data()
	return territory_data.active

func generate_customer(territory_id = ""):
	if !dealing_enabled:
		return null
		
	var territory = null
	if territory_id == "":
		if current_territory != "" && territories.has(current_territory):
			territory_id = current_territory
			territory = territories[current_territory]
		else:
			return null
	elif territories.has(territory_id):
		territory = territories[territory_id]
	else:
		return null
		
	var territory_data = territory.get_territory_data()
	if !territory_data.active:
		return null
		
	var customer_id = "customer_" + str(randi())
	while active_customers.has(customer_id):
		customer_id = "customer_" + str(randi())
		
	var customer_type = _select_customer_type(territory_data)
	var type_data = customer_types[customer_type].duplicate()
	
	var dialog_options = type_data.dialog_options
	var greetings = dialog_options.greeting
	var greeting = greetings[randi() % greetings.size()]
	
	var customer = {
		"id": customer_id,
		"type": type_data.name,
		"type_enum": customer_type,
		"greeting": greeting,
		"greeting_options": dialog_options.greeting,
		"negotiation_dialogue": "How much?",
		"success_dialogue": "Thanks, pleasure doing business.",
		"failure_dialogue": "No way, that's too much.",
		"price_sensitivity": type_data.price_sensitivity,
		"quality_sensitivity": type_data.quality_sensitivity,
		"patience": type_data.patience,
		"heat_modifier": type_data.heat_modifier,
		"territory_id": territory_data.id,
		"is_undercover": type_data.get("is_undercover", false)
	}
	
	active_customers[customer_id] = {
		"data": customer,
		"deal_started": false
	}
	
	if signal_bus:
		signal_bus.customer_spawned.emit(customer_id, territory_id, active_customers[customer_id].data)
		
	return true

func _select_customer_type(territory_data):
	var allowed_types = []
	var weights = []
	var total_weight = 0
	
	for type in customer_types:
		var weight = customer_types[type].weight
		var risk_modifier = 1.0
		var reputation_mod = 1.0
		
		if customer_types[type].get("is_undercover", false):
			if !territory_heat.has(territory_data.id) || territory_heat[territory_data.id] < 0.5:
				continue
			risk_modifier = lerp(0.1, 3.0, territory_heat[territory_data.id])
			
		var adjusted_weight = weight * risk_modifier * reputation_mod
		weights.append(adjusted_weight)
		total_weight += adjusted_weight
		allowed_types.append(type)
		
	if allowed_types.size() == 0:
		return CUSTOMER_TYPE.CASUAL
		
	var roll = randf() * total_weight
	var current_total = 0
	
	for i in range(allowed_types.size()):
		current_total += weights[i]
		if roll <= current_total:
			return allowed_types[i]
			
	return allowed_types[0]

func get_product_data(product_type):
	if product_data.has(product_type):
		return product_data[product_type]
	return null

func get_base_price(product_type, customer_data):
	var product = get_product_data(product_type)
	if !product:
		return 0
		
	var base_price = product.base_price
	var price_mod = 1.0
	
	if territory_reputation.has(customer_data.territory_id):
		price_mod = lerp(0.8, 1.2, territory_reputation[customer_data.territory_id])
	
	base_price = base_price * price_mod
	
	if customer_data.has("type_enum"):
		var type = customer_data.type_enum
		if type == CUSTOMER_TYPE.DEALER:
			base_price *= 0.85
		elif type == CUSTOMER_TYPE.JUNKIE:
			base_price *= 1.2
			
	return int(base_price)

func calculate_success_chance(price, base_price, quality, customer_data):
	var price_ratio = base_price / float(max(1, price))
	var quality_bonus = quality * 0.5
	
	var price_weight = 0.6
	var quality_weight = 0.4
	
	if customer_data.has("price_sensitivity"):
		price_weight = customer_data.price_sensitivity
		
	if customer_data.has("quality_sensitivity"):
		quality_weight = customer_data.quality_sensitivity
		
	var price_score = lerp(0.0, 1.0, clamp(price_ratio, 0.5, 1.5))
	var total_score = (price_score * price_weight) + (quality_bonus * quality_weight)
	
	return clamp(total_score, 0.0, 1.0)

func start_deal(customer_id, product_type):
	if !active_customers.has(customer_id) || active_customers[customer_id].deal_started:
		return false
		
	var customer_data = active_customers[customer_id].data
	var product = get_product_data(product_type)
	
	if !product || !player_products.has(product_type) || player_products[product_type] <= 0:
		return false
		
	var base_price = get_base_price(product_type, customer_data)
	
	active_deals[customer_id] = {
		"customer_id": customer_id,
		"product_type": product_type,
		"base_price": base_price,
		"current_price": base_price,
		"negotiation_steps": 0,
		"max_steps": base_negotiation_steps,
		"patience_timer": customer_data.patience * base_deal_time
	}
	
	active_customers[customer_id].deal_started = true
	
	if signal_bus:
		signal_bus.deal_started.emit(customer_id, product_type, base_price)
		
	return true

func offer_price(customer_id, price):
	if !active_deals.has(customer_id):
		return false
		
	var deal_data = active_deals[customer_id]
	var customer_data = active_customers[customer_id].data
	var product = get_product_data(deal_data.product_type)
	
	if !product:
		return false
		
	deal_data.negotiation_steps += 1
	deal_data.current_price = price
	
	var success_chance = calculate_success_chance(price, deal_data.base_price, product.quality, customer_data)
	var success_roll = randf()
	
	var result = {
		"accepted": false,
		"counter_offer": 0,
		"final": false,
		"success_chance": success_chance
	}
	
	if success_roll <= success_chance:
		result.accepted = true
		result.final = true
		complete_deal(customer_id, price)
	else:
		if deal_data.negotiation_steps >= deal_data.max_steps:
			result.final = true
			if customer_data.get("is_undercover", false):
				bust_player(customer_id)
			else:
				customer_leaves(customer_id)
		else:
			var counter_modifier = lerp(1.1, 1.3, 1.0 - success_chance)
			var counter_offer = int(deal_data.base_price * counter_modifier)
			result.counter_offer = counter_offer
	
	if signal_bus:
		signal_bus.price_offered.emit(customer_id, price, result)
		
	return result

func complete_deal(customer_id, price):
	if !active_deals.has(customer_id):
		return false
		
	var deal_data = active_deals[customer_id]
	var customer_data = active_customers[customer_id].data
	
	if player_products[deal_data.product_type] <= 0:
		customer_leaves(customer_id)
		return false
		
	player_products[deal_data.product_type] -= 1
	player_cash += price
	
	var product = get_product_data(deal_data.product_type)
	var heat_increase = product.heat_modifier * customer_data.heat_modifier * 0.1
	increase_territory_heat(customer_data.territory_id, heat_increase)
	
	if signal_bus:
		signal_bus.deal_completed.emit(customer_id, deal_data.product_type, price)
	
	remove_customer(customer_id)
	return true

func customer_leaves(customer_id):
	if !active_customers.has(customer_id):
		return
		
	if signal_bus:
		signal_bus.customer_left.emit(customer_id)
		
	remove_customer(customer_id)

func bust_player(customer_id):
	if !active_customers.has(customer_id):
		return
		
	var customer_data = active_customers[customer_id].data
	var heat_increase = 1.0
	
	increase_territory_heat(customer_data.territory_id, heat_increase)
	
	if signal_bus:
		signal_bus.player_busted.emit(customer_id)
		
	if tension_manager:
		tension_manager.add(0.3)
		
	remove_customer(customer_id)

func remove_customer(customer_id):
	if active_deals.has(customer_id):
		active_deals.erase(customer_id)
		
	if active_customers.has(customer_id):
		active_customers.erase(customer_id)

func increase_territory_heat(territory_id, amount):
	if !territory_heat.has(territory_id):
		territory_heat[territory_id] = 0.0
		
	territory_heat[territory_id] = min(territory_heat[territory_id] + amount, 1.0)
	
	if territory_heat[territory_id] > 0.7 && tension_manager:
		tension_manager.add(0.1)
		
	if signal_bus:
		signal_bus.territory_heat_increased.emit(territory_id, territory_heat[territory_id])

func _on_threshold_crossed(_threshold_name, _direction, _threshold_value, _current_value):
	pass
