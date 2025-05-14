extends StaticBody2D

@onready var sl: Sprite2D = $Sprite2D_left
@onready var sr: Sprite2D = $Sprite2D_right
@onready var button: Button = $Button
@export var dt: StringName
@export var fh: bool = false
@export var doors_array: Array = []

var door_scene: PackedScene = preload("res://Scenes/Door.tscn")
var doors: Array = []
var sprite_2d: Sprite2D
var opened: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	if doors_array.size() > 0:
		for door_data in doors_array:
			var door = door_scene.instantiate()
			door.door_id = door_data.id
			door.door_locked = door_data.locked
			door.key_id = door_data.key_id
			door.position = door_data.position
			door.input_pickable = true
			add_child(door)
			doors.append(door)
			
	sprite_2d = $Sprite2D
	button = get_node_or_null("Button")
	
	if button:
		button.pressed.connect(self._on_button_pressed)
		
	set_active(false)
	
	await get_tree().create_timer(0.1).timeout
	
	if fh == false:
		sl.flip_h = false
		sr.flip_h = true
	else:
		sl.flip_h = true
		sr.flip_h = false
	
	if dt == "":
		
		sl.frame = 0
		sr.frame = 0
	elif dt == "horizontal":
		sl.frame = 1
		sr.frame = 1
	elif dt == "vertical":
		sl.frame = 2
		sr.frame = 2
	elif dt == "cross":
		sl.frame = 3
		sr.frame = 3

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		button.process_mode = Node.PROCESS_MODE_INHERIT
		button.show()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		button.process_mode = Node.PROCESS_MODE_DISABLED
		button.hide()

func _on_button_pressed() -> void:
	if opened == false:
		opened = true
		if dt == "":
			sl.frame = 4
			sr.frame = 4
		elif dt == "horizontal":
			sl.frame = 5
			sr.frame = 5
		elif dt == "vertical":
			sl.frame = 6
			sr.frame = 6
		elif dt == "cross":
			sl.frame = 7
			sr.frame = 7
	else:
		opened = false
		if dt == "":
			sl.frame = 0
			sr.frame = 0
		elif dt == "horizontal":
			sl.frame = 1
			sr.frame = 1
		elif dt == "vertical":
			sl.frame = 2
			sr.frame = 2
		elif dt == "cross":
			sl.frame = 3
			sr.frame = 3

func set_active(active: bool):
	if button:
		if active:
			button.process_mode = Node.PROCESS_MODE_INHERIT
			button.modulate.a = 1.0
		else:
			button.process_mode = Node.PROCESS_MODE_DISABLED
			button.modulate.a = 0.0
