extends CharacterBody2D

@export var base_speed: float = 50.0
@export var rush_speed: float = 100.0
@export var wander_radius: float = 100.0
@export var alert_distance: float = 150.0
@export var flee_distance: float = 200.0
@export var group_type: String = "civilian"
@export var reaction_threshold: float = 0.6

@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var detection_area = $DetectionArea

enum STATE {IDLE, WANDER, ALERT, FLEE, INVESTIGATE, ATTACK}

var current_state = STATE.IDLE
var manager = null
var player = null
var wander_target = Vector2.ZERO
var start_position = Vector2.ZERO
var current_speed = 0.0
var direction = Vector2.ZERO
var random = RandomNumberGenerator.new()
var reaction_timer = 0.0
var wander_timer = 0.0

func _ready():
	random.randomize()
	start_position = global_position
	manager = get_node_or_null("/root/TensionManager")
	if manager:
		manager.heat_level_changed.connect(_on_heat_level_changed)
		manager.player_detected.connect(_on_player_detected)
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
	set_state(STATE.IDLE)
	wander_timer = random.randf_range(1.0, 5.0)

func _physics_process(delta):
	reaction_timer -= delta
	wander_timer -= delta
	match current_state:
		STATE.IDLE:
			process_idle(delta)
		STATE.WANDER:
			process_wander(delta)
		STATE.ALERT:
			process_alert(delta)
		STATE.FLEE:
			process_flee(delta)
		STATE.INVESTIGATE:
			process_investigate(delta)
		STATE.ATTACK:
			process_attack(delta)
	move_and_slide()
	update_animation()

func process_idle(_delta):
	velocity = Vector2.ZERO
	if wander_timer <= 0:
		set_random_wander_target()
		set_state(STATE.WANDER)

func process_wander(_delta):
	if global_position.distance_to(wander_target) < 10:
		set_state(STATE.IDLE)
		wander_timer = random.randf_range(2.0, 8.0)
		return
	direction = global_position.direction_to(wander_target)
	velocity = direction * current_speed
	if wander_timer <= 0:
		set_state(STATE.IDLE)
		wander_timer = random.randf_range(2.0, 5.0)

func process_alert(_delta):
	if !player:
		set_state(STATE.WANDER)
		return
	var distance = global_position.distance_to(player.global_position)
	if distance > alert_distance * 1.5:
		set_state(STATE.WANDER)
		return
	direction = global_position.direction_to(player.global_position)
	if group_type == "police" or group_type == "guard" or group_type == "cartel":
		velocity = direction * current_speed
	else:
		velocity = Vector2.ZERO

func process_flee(_delta):
	if !player:
		set_state(STATE.WANDER)
		return
	var distance = global_position.distance_to(player.global_position)
	if distance > flee_distance * 1.5:
		set_state(STATE.WANDER)
		return
	direction = -global_position.direction_to(player.global_position)
	velocity = direction * current_speed

func process_investigate(_delta):
	if !player:
		set_state(STATE.WANDER)
		return
	var distance = global_position.distance_to(player.global_position)
	if distance < 20:
		set_state(STATE.ALERT)
		return
	direction = global_position.direction_to(player.global_position)
	velocity = direction * current_speed * 0.7

func process_attack(_delta):
	if !player:
		set_state(STATE.WANDER)
		return
	var distance = global_position.distance_to(player.global_position)
	if distance > alert_distance * 2:
		set_state(STATE.WANDER)
		return
	direction = global_position.direction_to(player.global_position)
	velocity = direction * current_speed

func set_random_wander_target():
	var angle = random.randf_range(0, TAU)
	var distance = random.randf_range(30, wander_radius)
	wander_target = start_position + Vector2(cos(angle), sin(angle)) * distance

func update_animation():
	var anim = "idle"
	if velocity.length() > 5:
		anim = "walk"
		if velocity.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
	match current_state:
		STATE.ALERT:
			anim = "alert"
		STATE.FLEE:
			anim = "flee"
		STATE.ATTACK:
			anim = "attack"
	if animation_player and animation_player.has_animation(anim) and animation_player.current_animation != anim:
		animation_player.play(anim)

func _on_heat_level_changed(new_level, _old_level):
	if new_level == manager.HEAT.HIGH:
		match group_type:
			"civilian":
				set_state(STATE.FLEE)
			"police", "guard", "cartel":
				set_state(STATE.ATTACK)

func _on_player_detected(detector_type):
	if detector_type == group_type and reaction_timer <= 0:
		match group_type:
			"civilian":
				set_state(STATE.ALERT)
			"guard", "police", "cartel":
				set_state(STATE.ATTACK)

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		if manager and manager.tension_engine.get_normalized() > reaction_threshold:
			match group_type:
				"civilian":
					set_state(STATE.ALERT)
				"guard", "police", "cartel":
					set_state(STATE.ATTACK)
		else:
			set_state(STATE.INVESTIGATE)
	elif body.is_in_group("hostiles") and group_type == "police":
		set_state(STATE.ATTACK)

func set_state(new_state):
	if current_state == new_state:
		return
	var _old_state = current_state
	current_state = new_state
	match new_state:
		STATE.IDLE:
			current_speed = 0
		STATE.WANDER:
			current_speed = base_speed * 0.5
		STATE.ALERT:
			current_speed = 0
			reaction_timer = 2.0
		STATE.FLEE:
			current_speed = rush_speed
		STATE.INVESTIGATE:
			current_speed = base_speed * 0.7
		STATE.ATTACK:
			current_speed = rush_speed
