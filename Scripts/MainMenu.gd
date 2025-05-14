extends Control

var hover_sound: AudioStreamPlayer
var menu_tween: Tween
var is_transitioning = false

func _ready():
	SoundManager.set_sound_volume(0.1)
	SoundManager.play_sound(load("res://assets/Sounds/breaking_bad_theme.mp3"), "SFX")
	setup_audio()
	setup_buttons()
	animate_entrance()

func _enter_tree():
	if Engine.is_editor_hint():
		$MenuPanel.modulate.a = 1.0
		$MenuPanel.position.y = $MenuPanel.position.y

func setup_audio():
	hover_sound = AudioStreamPlayer.new()
	add_child(hover_sound)
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = 44100
	hover_sound.stream = stream
	hover_sound.volume_db = -10

func setup_buttons():
	for button in get_all_buttons():
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))

func get_all_buttons():
	return $MenuPanel/VBoxContainer/ButtonsContainer.get_children()

func animate_entrance():
	if Engine.is_editor_hint():
		return
		
	$MenuPanel.modulate.a = 0
	$MenuPanel.position.y += 50
	menu_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	menu_tween.tween_property($MenuPanel, "modulate:a", 1.0, 0.4)
	menu_tween.parallel().tween_property($MenuPanel, "position:y", $MenuPanel.position.y - 50, 0.4)

func _on_button_mouse_entered(button):
	if hover_sound and !is_transitioning:
		hover_sound.play()
		var button_tween = create_tween().set_ease(Tween.EASE_OUT)
		button_tween.tween_property(button, "position:y", button.position.y - 5, 0.1)
		button_tween.tween_property(button, "position:y", button.position.y, 0.1)

func transition_to_scene(scene_path):
	if is_transitioning:
		return
		
	is_transitioning = true
	menu_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	menu_tween.tween_property($MenuPanel, "modulate:a", 0.0, 0.3)
	menu_tween.parallel().tween_property($MenuPanel, "position:y", $MenuPanel.position.y + 50, 0.3)
	await menu_tween.finished
	
	if ResourceLoader.exists(scene_path):
		SceneManager.change_scene(scene_path)
	else:
		Log.warn("Scene not found: ", scene_path)
		is_transitioning = false
		animate_entrance()

func _on_start_button_pressed():
	transition_to_scene("res://Scenes/House.tscn")

func _on_methlab_button_pressed():
	transition_to_scene("res://Scenes/MethhLab.tscn")

func _on_options_button_pressed():
	Log.info("No options menu")

func _on_quit_button_pressed():
	get_tree().quit()
