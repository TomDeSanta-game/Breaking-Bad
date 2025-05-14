extends Control

signal closed(id)

@export var id: int = 0
@export var notification_type: String = "info"

var element_symbols = {
	"info": "In",
	"success": "Br",
	"warning": "Cr",
	"error": "Hg"
}

var element_numbers = {
	"info": "49",
	"success": "35",
	"warning": "24",
	"error": "80"
}

var colors = {
	"info": Color("7dd3fc"),
	"success": Color("b3da03"),
	"warning": Color("fbbf24"),
	"error": Color("ef4444")
}

func _ready():
	setup_appearance()

func setup_appearance():
	var panel = $Container
	var icon_panel = $Container/IconPanel
	var element_symbol = $Container/IconPanel/ElementSymbol
	var element_number = $Container/IconPanel/ElementNumber
	var title = $Container/MarginContainer/VBoxContainer/TitlePanel/TitleLabel
	
	panel.get("theme_override_styles/panel").border_color = colors[notification_type]
	icon_panel.get("theme_override_styles/panel").bg_color = colors[notification_type]
	title.add_theme_color_override("font_color", colors[notification_type])
	$Container/MarginContainer/VBoxContainer/TitlePanel.get("theme_override_styles/panel").border_color = colors[notification_type]
	
	element_symbol.text = element_symbols[notification_type]
	element_number.text = element_numbers[notification_type]

func set_title(title_text: String):
	$Container/MarginContainer/VBoxContainer/TitlePanel/TitleLabel.text = title_text.to_upper()

func set_message(message_text: String):
	$Container/MarginContainer/VBoxContainer/ContentPanel/MessageLabel.text = message_text

func set_lifetime(seconds: float):
	$Timer.wait_time = seconds

func close():
	$AnimationPlayer.play("fade_out")

func _on_timer_timeout():
	close()
	emit_signal("closed", id) 