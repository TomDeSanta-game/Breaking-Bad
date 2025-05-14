extends Button

func _ready():
	pressed.connect(change_to_meth_lab_scene)

func change_to_meth_lab_scene():
	get_tree().change_scene_to_file("res://Scenes/MethLab.tscn")

func show_button():
	visible = true

func hide_button():
	visible = false
