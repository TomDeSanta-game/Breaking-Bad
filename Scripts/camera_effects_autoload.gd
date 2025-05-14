extends Node

var active_camera: Camera2D = null
var original_camera_position: Vector2 = Vector2.ZERO
var original_camera_zoom: Vector2 = Vector2.ONE

var camera_effects = {
	"shake": {
		"active": false,
		"intensity": 0.0,
		"remaining_time": 0.0,
		"trauma": 0.0,
		"trauma_decay": 1.0,
		"enabled": true
	},
	"breathing": {
		"active": false,
		"intensity": 0.0,
		"speed": 1.0,
		"time": 0.0,
		"enabled": true
	},
	"pulsating_zoom": {
		"active": false,
		"intensity": 0.0,
		"speed": 1.0,
		"time": 0.0,
		"enabled": true
	},
	"drift": {
		"active": false,
		"intensity": 0.0,
		"direction": Vector2.ZERO,
		"remaining_time": 0.0,
		"enabled": true
	}
}

var freeze_frame = {
	"active": false,
	"time_scale": 1.0,
	"remaining_time": 0.0,
	"enabled": true
}

var global_intensity: float = 1.0
var time_dilation: float = 1.0

func _ready():
	set_process(true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	SignalBus.tension_changed.connect(_on_tension_changed)
	if SignalBus.has_signal("explosion_occurred"):
		SignalBus.explosion_occurred.connect(_on_explosion_occurred)
	if SignalBus.has_signal("impact_occurred"):
		SignalBus.impact_occurred.connect(_on_impact_occurred)

func _process(delta):
	find_active_camera()
	
	if active_camera == null:
		return
		
	var actual_delta = delta * time_dilation
	
	update_camera_shake(actual_delta)
	update_breathing_camera(actual_delta)
	update_pulsating_zoom(actual_delta)
	update_camera_drift(actual_delta)
	update_freeze_frame(actual_delta)

func set_global_intensity(intensity: float):
	global_intensity = clamp(intensity, 0.0, 2.0)

func find_active_camera():
	if active_camera == null or !is_instance_valid(active_camera):
		active_camera = get_viewport().get_camera_2d()
		if active_camera:
			original_camera_position = active_camera.position
			original_camera_zoom = active_camera.zoom

func reset_camera():
	if active_camera and is_instance_valid(active_camera):
		active_camera.position = original_camera_position
		active_camera.offset = Vector2.ZERO
		active_camera.zoom = original_camera_zoom
		active_camera.rotation = 0.0

func shake(intensity: float = 0.5, duration: float = 0.3):
	if !camera_effects.shake.enabled:
		return
		
	camera_effects.shake.active = true
	camera_effects.shake.trauma = min(camera_effects.shake.trauma + intensity, 1.0)
	camera_effects.shake.remaining_time = max(camera_effects.shake.remaining_time, duration)
	
	SignalBus.camera_effect_started.emit("shake")

func update_camera_shake(delta):
	var effect = camera_effects.shake
	if !effect.active or !effect.enabled:
		return
		
	effect.trauma = max(0, effect.trauma - effect.trauma_decay * delta)
	effect.remaining_time -= delta
	
	if effect.trauma <= 0.01 or effect.remaining_time <= 0:
		effect.active = false
		effect.trauma = 0.0
		effect.remaining_time = 0.0
		
		if active_camera:
			active_camera.offset.x = 0
			active_camera.offset.y = 0
			active_camera.rotation = 0
			
		SignalBus.camera_effect_ended.emit("shake")
		return
	
	if active_camera:
		var intensity = effect.trauma * effect.trauma * global_intensity
		var seed_value = Time.get_ticks_msec()
		active_camera.offset.x = intensity * 32.0 * (randf_from_seed(seed_value) * 2.0 - 1.0)
		active_camera.offset.y = intensity * 32.0 * (randf_from_seed(seed_value + 1) * 2.0 - 1.0)
		active_camera.rotation = intensity * 0.05 * (randf_from_seed(seed_value + 2) * 2.0 - 1.0)

func enable_camera_shake(enabled: bool = true):
	camera_effects.shake.enabled = enabled

func start_breathing_camera(intensity: float = 0.3, speed: float = 1.0):
	if !camera_effects.breathing.enabled:
		return
		
	camera_effects.breathing.active = true
	camera_effects.breathing.intensity = intensity * global_intensity
	camera_effects.breathing.speed = speed
	camera_effects.breathing.time = 0.0
	
	SignalBus.camera_effect_started.emit("breathing")

func stop_breathing_camera():
	if !camera_effects.breathing.active:
		return
		
	camera_effects.breathing.active = false
	if active_camera:
		active_camera.offset = Vector2.ZERO
		
	SignalBus.camera_effect_ended.emit("breathing")

func update_breathing_camera(delta):
	var effect = camera_effects.breathing
	if !effect.active or !effect.enabled:
		return
		
	effect.time += delta * effect.speed
	
	if active_camera:
		var breathing = sin(effect.time * 2.0) * effect.intensity
		active_camera.offset = Vector2(breathing * 0.5, breathing)

func enable_breathing_camera(enabled: bool = true):
	camera_effects.breathing.enabled = enabled

func start_pulsating_zoom(intensity: float = 0.1, speed: float = 1.0):
	if !camera_effects.pulsating_zoom.enabled:
		return
		
	camera_effects.pulsating_zoom.active = true
	camera_effects.pulsating_zoom.intensity = intensity * global_intensity
	camera_effects.pulsating_zoom.speed = speed
	camera_effects.pulsating_zoom.time = 0.0
	
	SignalBus.camera_effect_started.emit("pulsating_zoom")

func stop_pulsating_zoom():
	if !camera_effects.pulsating_zoom.active:
		return
		
	camera_effects.pulsating_zoom.active = false
	if active_camera:
		active_camera.zoom = original_camera_zoom
		
	SignalBus.camera_effect_ended.emit("pulsating_zoom")

func update_pulsating_zoom(delta):
	var effect = camera_effects.pulsating_zoom
	if !effect.active or !effect.enabled:
		return
		
	effect.time += delta * effect.speed
	
	if active_camera:
		var zoom_factor = 1.0 + sin(effect.time * 2.0) * effect.intensity
		active_camera.zoom = original_camera_zoom * zoom_factor

func enable_pulsating_zoom(enabled: bool = true):
	camera_effects.pulsating_zoom.enabled = enabled

func drift_camera(direction: Vector2, intensity: float = 0.5, duration: float = 1.0):
	if !camera_effects.drift.enabled:
		return
		
	camera_effects.drift.active = true
	camera_effects.drift.direction = direction.normalized()
	camera_effects.drift.intensity = intensity * global_intensity
	camera_effects.drift.remaining_time = duration
	
	SignalBus.camera_effect_started.emit("drift")

func update_camera_drift(delta):
	var effect = camera_effects.drift
	if !effect.active or !effect.enabled:
		return
		
	effect.remaining_time -= delta
	
	if effect.remaining_time <= 0:
		effect.active = false
		effect.remaining_time = 0.0
		
		SignalBus.camera_effect_ended.emit("drift")
		return
	
	if active_camera:
		var movement = effect.direction * effect.intensity * delta * 100.0
		active_camera.position += movement

func enable_camera_drift(enabled: bool = true):
	camera_effects.drift.enabled = enabled

func apply_freeze_frame(duration: float = 0.2, time_scale: float = 0.05):
	if !freeze_frame.enabled:
		return
		
	freeze_frame.active = true
	freeze_frame.time_scale = time_scale
	freeze_frame.remaining_time = duration
	
	time_dilation = time_scale
	Engine.time_scale = time_scale
	
	SignalBus.camera_effect_started.emit("freeze_frame")

func update_freeze_frame(delta):
	if !freeze_frame.active or !freeze_frame.enabled:
		return
		
	freeze_frame.remaining_time -= delta / freeze_frame.time_scale
	
	if freeze_frame.remaining_time <= 0:
		freeze_frame.active = false
		freeze_frame.remaining_time = 0.0
		
		time_dilation = 1.0
		Engine.time_scale = 1.0
		
		SignalBus.camera_effect_ended.emit("freeze_frame")

func enable_freeze_frame(enabled: bool = true):
	freeze_frame.enabled = enabled

func _on_tension_changed(value: float):
	if value > 0.5 and !camera_effects.breathing.active:
		start_breathing_camera(0.2 * value, 1.0 + value * 0.5)
	elif value <= 0.2 and camera_effects.breathing.active:
		stop_breathing_camera()

func _on_explosion_occurred(_position, size, _damage_radius):
	var intensity = clamp(size * 0.5, 0.3, 1.0)
	var duration = 0.2 + size * 0.1
	
	shake(intensity, duration)
	if size >= 1.5:
		apply_freeze_frame(0.1, 0.2)

func _on_impact_occurred(_position, force, _source):
	var intensity = clamp(force * 0.3, 0.1, 0.8)
	var duration = 0.1 + force * 0.05
	
	if force >= 0.5:
		shake(intensity, duration)
		
	if force >= 1.5:
		apply_freeze_frame(0.07, 0.3)

func randf_from_seed(seed_value: int) -> float:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randf() 