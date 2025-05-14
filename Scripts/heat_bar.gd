extends ProgressBar

@export var heat_none_color: Color = Color(0.0, 0.7, 0.2, 1.0)
@export var heat_low_color: Color = Color(0.9, 0.7, 0.0, 1.0)
@export var heat_medium_color: Color = Color(0.9, 0.5, 0.0, 1.0)
@export var heat_high_color: Color = Color(0.9, 0.2, 0.0, 1.0)
@export var heat_wanted_color: Color = Color(0.7, 0.0, 0.0, 1.0)
@export var pulse_when_wanted: bool = true

@onready var tween = null
@onready var label = $HeatLabel
@onready var value_label = $ValueLabel
@onready var wanted_icon = $WantedIcon
@onready var wanted_icon_animation = null

const HEAT_LEVELS = ["NONE", "LOW", "MEDIUM", "HIGH", "WANTED"]

var current_heat_level: int = 0
var is_wanted: bool = false

func _ready() -> void:
	SignalBus.heat_level_changed.connect(_on_heat_level_changed)
	reset_display()
	
func _process(_delta: float) -> void:
	if pulse_when_wanted and is_wanted and (!tween or !tween.is_running()):
		pulse_bar()
		pulse_wanted_icon()

func reset_display() -> void:
	value = 0
	update_color(0)
	update_labels(0)
	is_wanted = false
	
	if wanted_icon:
		wanted_icon.visible = false
		stop_icon_animation()

func _on_heat_level_changed(new_heat, _old_heat) -> void:
	current_heat_level = new_heat
	var heat_index = get_heat_index(new_heat)
	var new_value = (heat_index / float(HEAT_LEVELS.size() - 1)) * 100.0
	
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "value", new_value, 0.3)
	
	update_color(heat_index)
	update_labels(heat_index)
	
	var was_wanted = is_wanted
	is_wanted = heat_index == HEAT_LEVELS.size() - 1
	
	if wanted_icon:
		wanted_icon.visible = is_wanted
		
		if is_wanted and !was_wanted:
			pulse_wanted_icon()
		elif !is_wanted and was_wanted:
			stop_icon_animation()

func get_heat_index(heat_value):
	if heat_value is int:
		return heat_value
	
	for i in range(HEAT_LEVELS.size()):
		if HEAT_LEVELS[i] == heat_value:
			return i
	return 0

func update_color(heat_index: int) -> void:
	var bar_color: Color
	
	match heat_index:
		0: bar_color = heat_none_color
		1: bar_color = heat_low_color 
		2: bar_color = heat_medium_color
		3: bar_color = heat_high_color
		4: bar_color = heat_wanted_color
		_: bar_color = heat_none_color
	
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", bar_color, 0.3)

func update_labels(heat_index: int) -> void:
	if heat_index < HEAT_LEVELS.size() and value_label:
		value_label.text = HEAT_LEVELS[heat_index]

func pulse_bar() -> void:
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.7, 0.5)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func pulse_wanted_icon() -> void:
	if wanted_icon and wanted_icon.visible:
		stop_icon_animation()
		
		wanted_icon_animation = create_tween()
		wanted_icon_animation.set_loops()
		wanted_icon_animation.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		
		wanted_icon_animation.tween_property(wanted_icon, "scale", Vector2(1.2, 1.2), 0.5)
		wanted_icon_animation.tween_property(wanted_icon, "scale", Vector2(0.9, 0.9), 0.5)
		wanted_icon_animation.tween_property(wanted_icon, "scale", Vector2(1.0, 1.0), 0.5)
		
		wanted_icon_animation.parallel().tween_property(wanted_icon, "modulate:a", 0.7, 0.8)
		wanted_icon_animation.parallel().tween_property(wanted_icon, "modulate:a", 1.0, 0.8)

func stop_icon_animation() -> void:
	if wanted_icon_animation and wanted_icon_animation.is_running():
		wanted_icon_animation.kill()
		
	if wanted_icon:
		wanted_icon.scale = Vector2(1.0, 1.0)
		wanted_icon.modulate.a = 1.0 