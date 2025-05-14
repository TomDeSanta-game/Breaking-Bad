extends Node

var tension_engine = null

func _ready():
	tension_engine = load("res://Scripts/tension_engine.gd").new()
	add_child(tension_engine)

func add_tension(amount):
	if tension_engine:
		tension_engine.add(amount)

func reduce_tension(amount):
	if tension_engine:
		tension_engine.reduce(amount)

func reset():
	if tension_engine:
		tension_engine.reset()

func get_tension():
	if tension_engine:
		return tension_engine.get_tension()
	return 0.0

func get_level():
	if tension_engine:
		return tension_engine.get_level()
	return 0

func get_level_name():
	if tension_engine:
		return tension_engine.get_level_name()
	return "NONE"
