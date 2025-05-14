extends StaticBody2D

signal door_opened(door_id)
signal door_closed(door_id)

@export var door_id: String = "door"
@export var initially_locked: bool = false
@export var key_required: String = ""
@export var auto_close: bool = true
@export var close_delay: float = 3.0
@export var locked_text: String = "This door is locked."

var is_open: bool = false
var is_locked: bool = false
var player_in_range: bool = false
var current_player = null
var close_timer: Timer

func _ready():
	is_locked = initially_locked
	
	close_timer = Timer.new()
	close_timer.one_shot = true
	close_timer.wait_time = close_delay
	close_timer.timeout.connect(_on_close_timer_timeout)
	add_child(close_timer)
	
	if $Sprite2D and $Sprite2D.frame != 0:
		$Sprite2D.frame = 0

func _process(_delta):
	if player_in_range and current_player and Input.is_action_just_pressed("interact"):
		interact()

func interact():
	if is_locked:
		if key_required and current_player and current_player.has_key(key_required):
			unlock()
			open()
		else:
			SignalBus.notification_requested.emit("Door Locked", locked_text, "warning", 2.0)
		return
	
	is_open = !is_open
	
	if is_open:
		open()
	else:
		close()

func open():
	if is_locked:
		return
		
	is_open = true
	$CollisionShape2D.set_deferred("disabled", true)
	
	if $Sprite2D:
		$Sprite2D.frame += 4
		
	emit_signal("door_opened", door_id)
	
	if auto_close:
		close_timer.start()

func close():
	is_open = false
	$CollisionShape2D.set_deferred("disabled", false)
	
	if $Sprite2D:
		$Sprite2D.frame -= 4
		
	emit_signal("door_closed", door_id)

func lock():
	is_locked = true

func unlock():
	is_locked = false
	SignalBus.notification_requested.emit("Door Unlocked", "You unlocked the door with the " + key_required + ".", "success", 3.0)

func _on_da_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		current_player = body
		if $Button:
			$Button.process_mode = Node.PROCESS_MODE_INHERIT
			$Button.show()

func _on_da_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		current_player = null
		if $Button:
			$Button.process_mode = Node.PROCESS_MODE_DISABLED
			$Button.hide()

func _on_button_pressed():
	interact()

func _on_close_timer_timeout():
	if is_open:
		close()
