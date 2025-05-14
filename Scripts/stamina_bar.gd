extends ProgressBar

@export var should_pulse_when_low: bool = true
@export var pulse_threshold: float = 30.0
@export var high_stamina_color: Color = Color(0.0, 0.7, 1.0, 1.0)
@export var low_stamina_color: Color = Color(0.1, 0.3, 0.9, 1.0)
@export var empty_stamina_color: Color = Color(0.2, 0.2, 0.5, 1.0)

@onready var tween = null
@onready var label = $ValueLabel

var current_stamina: float = 100.0
var max_stamina: float = 100.0
var is_low: bool = false

func _ready() -> void:
	SignalBus.stamina_changed.connect(_on_stamina_changed)
	value = 100.0
	
func _process(_delta: float) -> void:
	if should_pulse_when_low and is_low:
		if !tween or !tween.is_running():
			pulse_bar()

func _on_stamina_changed(new_stamina: float, stamina_cap: float) -> void:
	current_stamina = new_stamina
	max_stamina = stamina_cap
	
	var new_value = (current_stamina / max_stamina) * 100.0
	
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "value", new_value, 0.3)
	
	if label:
		label.text = "%d%%" % int(new_value)
	
	update_color(new_value)
	
	is_low = new_value <= pulse_threshold

func update_color(stamina_percent: float) -> void:
	var bar_color: Color
	
	if stamina_percent <= pulse_threshold * 0.5:
		bar_color = empty_stamina_color
	elif stamina_percent <= pulse_threshold:
		bar_color = low_stamina_color
	else:
		bar_color = high_stamina_color
	
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", bar_color, 0.3)

func pulse_bar() -> void:
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.7, 0.5)
	tween.tween_property(self, "modulate:a", 1.0, 0.5) 