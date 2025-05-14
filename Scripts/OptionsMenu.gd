extends Control

func _ready():
	var vsync_button = $MenuPanel/VBoxContainer/SettingsContainer/VsyncOption/VsyncButton
	vsync_button.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

func _on_vsync_button_toggled(button_pressed):
	if button_pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_back_button_pressed():
	SceneManager.change_scene("res://Scenes/MainMenu.tscn")
