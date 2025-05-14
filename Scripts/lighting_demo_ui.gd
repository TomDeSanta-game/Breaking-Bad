extends Control

@onready var time_label = $Panel/TimeLabel
@onready var preset_label = $Panel/PresetLabel
@onready var lighting_system = get_node_or_null("/root/LightingSystem")

@onready var slow_button = $Panel/TimeControls/SlowButton
@onready var play_button = $Panel/TimeControls/PlayButton
@onready var pause_button = $Panel/TimeControls/PauseButton
@onready var fast_button = $Panel/TimeControls/FastButton

var original_time_scale = 1.0
var paused = false

func _ready():
	if not lighting_system:
		lighting_system = get_node("../LightingSystem")
	
	if lighting_system:
		lighting_system.connect("time_changed", _on_time_changed)
		lighting_system.connect("preset_changed", _on_preset_changed)
		original_time_scale = lighting_system.time_scale
		
	slow_button.connect("pressed", _on_slow_pressed)
	play_button.connect("pressed", _on_play_pressed)
	pause_button.connect("pressed", _on_pause_pressed)
	fast_button.connect("pressed", _on_fast_pressed)

func _process(_delta):
	pass

func _on_time_changed(_time):
	time_label.text = "Time: " + lighting_system.get_time_string()

func _on_preset_changed(preset_name):
	preset_label.text = "Preset: " + preset_name
	
func _on_slow_pressed():
	if lighting_system:
		lighting_system.time_scale = original_time_scale * 0.5
		paused = false

func _on_play_pressed():
	if lighting_system:
		lighting_system.time_scale = original_time_scale
		paused = false
		lighting_system.day_night_cycle_enabled = true

func _on_pause_pressed():
	if lighting_system:
		paused = !paused
		lighting_system.day_night_cycle_enabled = !paused

func _on_fast_pressed():
	if lighting_system:
		lighting_system.time_scale = original_time_scale * 2.0
		paused = false
		lighting_system.day_night_cycle_enabled = true 