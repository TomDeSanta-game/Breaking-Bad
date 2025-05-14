extends Node

var active_effects: Dictionary = {}
var desaturation_material: ShaderMaterial
var chromatic_aberration_material: ShaderMaterial
var vignette_material: ShaderMaterial
var current_tween: Tween = null

func _ready() -> void:
	SignalBus.time_effect_started.connect(_on_time_effect_started)
	SignalBus.time_effect_ended.connect(_on_time_effect_ended)
	
	desaturation_material = ShaderMaterial.new()
	chromatic_aberration_material = ShaderMaterial.new()
	vignette_material = ShaderMaterial.new()

func _on_time_effect_started(effect_name: String, intensity: float) -> void:
	active_effects[effect_name] = intensity
	
	match effect_name:
		"slow_motion":
			apply_slow_motion_effects(intensity)

func _on_time_effect_ended(effect_name: String) -> void:
	active_effects.erase(effect_name)
	
	match effect_name:
		"slow_motion":
			revert_slow_motion_effects()

func apply_slow_motion_effects(_intensity: float) -> void:
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	

	SignalBus.camera_effect_started.emit("slow_motion_filter")
	

	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(func(): 
		SignalBus.ambient_changed.emit("slow_motion_ambient")
	)

func revert_slow_motion_effects() -> void:
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.set_ease(Tween.EASE_IN)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	

	SignalBus.camera_effect_ended.emit("slow_motion_filter")
	

	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(func():
		SignalBus.ambient_changed.emit("default_ambient")
	) 