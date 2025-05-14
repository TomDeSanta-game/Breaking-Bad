extends Node2D
var formation_offsets = [
	Vector2(-10, -5),
	Vector2(10, -5),
	Vector2(-5, 0),
	Vector2(5, 0),
	Vector2(-10, 5),
	Vector2(10, 5)
]
var raid_speed = 50.0
var officers = []
var raiding = true
var formation_center
var move_direction = Vector2(-1, 0)
var rotation_speed = 4.0
var time_passed = 0.0
var daylight_intensity = 0.06
var daylight_direction = 1
var house_position = Vector2(-150, 80)
var car_position = Vector2(24, 58)
var target_reached = false
var house_focus_complete = false
var car_focus_timer = 0.0
var house_focus_timer = 3.0
var camera_transition_time = 0.0
var camera_transition_duration = 3.5
var car_transition_duration = 2.5
var formation_center_smoothed = Vector2.ZERO
var camera_target_position = Vector2.ZERO
var camera_offset = Vector2(0, -15)
var initial_zoom = Vector2(5, 5)
var target_zoom = Vector2(4, 4)
var car_focus_zoom = Vector2(4.5, 4.5)
var current_zoom = Vector2(5, 5)
var zoom_speed = 0.5
var dust_particles = []
var dialogic_started = false
var meth_lab_unlocked = false
var raid_phase = 0
var breach_timer = 0.0
var breach_duration = 1.5
var escape_path = []
var jesse_escape_speed = 60.0
var jesse_escaping = false
var flash_effect_active = false
var flash_intensity = 0.0
var warning_effect_active = false
var warning_intensity = 0.0
var warning_flash_speed = 3.0
var camera_shake_intensity = 0.0
var door_broken = false
var time_to_meet_hank: float = 60.0
var timer_active: bool = false
var objective_initialized: bool = false
var in_passenger_seat: bool = false
var countdown_time: float = 0.0
var label_fade_time: float = 1.0
var timer_label_alpha: float = 0.0
var timer_label_target_alpha: float = 0.0
var timer_finished: bool = false
var hank_waiting: bool = false
var player_near_car: bool = false
var dialog_active: bool = false
var quest_started: bool = false
var tension_ramping: bool = false
var tension_target: float = 0.0
var tension_ramp_speed: float = 0.15
var on_main_road: bool = false
var police_response_level: int = 0
var police_scan_timer: float = 0.0
var meth_lab_panel_open: bool = false
var meth_lab_station_active: int = -1
var lab_step: int = 0
var ingredients_collected: int = 0
var meth_lab_success: bool = false
var player_hidden: bool = false
var hiding_spot_entered: bool = false
var hiding_cooldown: float = 0.0
var just_closed_door: bool = false
var can_open_door: bool = false
var siren_playing: bool = false
var quest_complete: bool = false
var signal_bus = null
var tension_manager = null
var police_response = null
var quest_manager = null
var current_quest = null
var player = null
var ui_manager = null
var quest_activated: bool = false
var timer_countdown_active: bool = false
var game_over_shown: bool = false
var dynamic_lighting = null

@onready var meth_lab_button = $MethLabButton
@onready var player_node = $Player
@onready var hank = $Hank
@onready var dialog_area = $DialogTrigger
@onready var meth_lab_entrance = $MethLabEntrance
@onready var jesse = $Jesse
var dialog_started = false
var entering_lab = false
@onready var objective_label: Control = $CanvasLayer/ObjectiveLabel
@onready var timer_label: Control = $CanvasLayer/TimerLabel
@onready var timer_time: Label = $CanvasLayer/TimerLabel/TimerTime
@onready var meth_lab_ui: Control = $CanvasLayer/MethLabGUI
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen
@onready var player_spawn_point: Node2D = $PlayerSpawnPoint
@onready var passenger_point: Node2D = $Map/HankCar/PassengerPoint
@onready var car: Node2D = $Map/HankCar
@onready var doors: Node = $Map/Doors
@onready var police_siren_audio: AudioStreamPlayer = $PoliceSiren
@onready var ambient_audio: AudioStreamPlayer = $AmbientAudio
@onready var tension_effects = $TensionEffects
@onready var map = $Map
@onready var nav_region = $Map/NavigationRegion2D
@onready var chase_trigger_area = $Map/ChaseTriggerArea
@onready var hiding_spot = $Map/HidingSpot
var hiding_spots = []

func _ready() -> void:
	$Jesse.speed = 30.0
	setup_jesse_escape_path()
	setup_dynamic_lighting()
	
	for i in range(1, 7):
		officers.append(get_node("PoliceOfficers/PoliceOfficer" + str(i)))
		var particles = get_node("PoliceOfficers/PoliceOfficer" + str(i) + "/DustParticles")
		dust_particles.append(particles)
	formation_center = calculate_formation_center()
	formation_center_smoothed = formation_center
	camera_target_position = formation_center
	$Camera2D.global_position = formation_center
	$Camera2D.zoom = initial_zoom
	current_zoom = initial_zoom
	toggle_dust_particles(false)
	$Camera2D.position_smoothing_enabled = true
	$Background.color = Color(0.95, 0.87, 0.73, 1.0)
	if has_node("AmbientVignette"):
		$AmbientVignette.color = Color(0.1, 0.0, 0.0, 0.4)
	if has_node("House/HouseBase"):
		$House/HouseBase.color = Color(0.8, 0.65, 0.4, 1.0)
	if has_node("House/HouseRoof"):
		$House/HouseRoof.color = Color(0.5, 0.3, 0.15, 1.0)
	create_desert_dust()
	create_raid_effects()
	if meth_lab_button:
		meth_lab_button.hide_button()
	if dialog_area:
		dialog_area.body_entered.connect(_on_dialog_trigger_entered)
	if meth_lab_entrance:
		meth_lab_entrance.body_entered.connect(_on_meth_lab_entrance_entered)
	tension_manager = get_node_or_null("/root/TensionManager")
	signal_bus = get_node_or_null("/root/SignalBus")
	police_response = get_node_or_null("/root/PoliceResponse")
	if signal_bus:
		signal_bus.game_over.connect(_on_game_over)
	if police_response:
		police_response.police_response_changed.connect(_on_police_response_changed)
	player = get_node_or_null("Player")
	if player:
		player.global_position = player_spawn_point.global_position
		player.set_physics_process(true)
	if objective_label:
		objective_label.visible = false
	if timer_label:
		timer_label.visible = false
	if game_over_screen:
		game_over_screen.visible = false
	setup_jesse_escape_path()

func setup_dynamic_lighting():
	var dynamic_lighting_node = get_node_or_null("/root/DynamicLighting")
	if dynamic_lighting_node:
		dynamic_lighting = dynamic_lighting_node.get_lighting_system()
		dynamic_lighting.update_lighting_state("DAY")

func setup_jesse_escape_path():
	escape_path = [
		house_position + Vector2(20, 20),
		house_position + Vector2(40, 30),
		house_position + Vector2(60, 20),
		house_position + Vector2(100, 10),
		house_position + Vector2(140, 15),
		car_position + Vector2(0, 0),
		car_position
	]

func calculate_formation_center() -> Vector2:
	var center = Vector2.ZERO
	for officer in officers:
		center += officer.global_position
	return center / max(1, officers.size())

func toggle_dust_particles(enabled: bool):
	for particle in dust_particles:
		if particle:
			particle.emitting = enabled

func create_raid_effects():
	var flash_rect = ColorRect.new()
	flash_rect.name = "BreachFlash"
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.z_index = 100
	var flash_canvas = CanvasLayer.new()
	flash_canvas.name = "FlashCanvas"
	flash_canvas.add_child(flash_rect)
	add_child(flash_canvas)
	var warning_rect = ColorRect.new()
	warning_rect.name = "WarningOverlay"
	warning_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_rect.color = Color(0.9, 0.1, 0.1, 0)
	warning_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	warning_rect.z_index = 99
	var warning_canvas = CanvasLayer.new()
	warning_canvas.name = "WarningCanvas"
	warning_canvas.add_child(warning_rect)
	add_child(warning_canvas)
	var raid_text = Label.new()
	raid_text.name = "RaidText"
	raid_text.text = "POLICE RAID"
	raid_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raid_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	raid_text.visible = false
	raid_text.add_theme_font_size_override("font_size", 32)
	raid_text.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	raid_text.set_anchors_preset(Control.PRESET_CENTER)
	warning_canvas.add_child(raid_text)

func create_desert_dust() -> void:
	var desert_dust = CPUParticles2D.new()
	desert_dust.name = "DesertDust"
	desert_dust.amount = 100
	desert_dust.lifetime = 4.0
	desert_dust.explosiveness = 0.0
	desert_dust.randomness = 1.0
	desert_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	desert_dust.emission_rect_extents = Vector2(500, 300)
	desert_dust.gravity = Vector2(10, 0)
	desert_dust.initial_velocity_min = 5.0
	desert_dust.initial_velocity_max = 10.0
	desert_dust.scale_amount_min = 0.5
	desert_dust.scale_amount_max = 2.0
	desert_dust.color = Color(0.9, 0.8, 0.6, 0.15)
	add_child(desert_dust)

func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		raid_phase += 1
	time_passed += delta
	if raiding:
		_update_raid(delta)
	_update_scene_effects(delta)
	if timer_active:
		_update_timer(delta)

func _update_raid(delta):
	_update_formation(delta)
	if !target_reached && raid_phase < 2:
		_move_formation(delta)
	match raid_phase:
		0:
			if _near_target(house_position, 50.0):
				raid_phase = 1
				target_reached = true
		1:
			if !house_focus_complete:
				_focus_camera_on_house(delta)
			else:
				_focus_camera_on_car(delta)
				
				if camera_transition_time >= camera_transition_duration - 0.5 && !warning_effect_active:
					if dynamic_lighting:
						dynamic_lighting.update_lighting_state("EMERGENCY")
					_start_warning_effect()
					
		2:
			if !flash_effect_active:
				_start_breach_effect()
				target_reached = false
				move_direction = (car_position - formation_center).normalized()
			_update_breach_effect(delta)
			if camera_shake_intensity > 0:
				_apply_camera_shake(delta)
		3:
			if !jesse_escaping:
				jesse_escaping = true
				if has_node("Jesse"):
					$Jesse.visible = true
			_update_jesse_escape(delta)
			_focus_camera_on_car(delta)
			
			if camera_transition_time >= camera_transition_duration - 0.5 && dynamic_lighting && dynamic_lighting.current_lighting_state != "NIGHT":
				dynamic_lighting.update_lighting_state("NIGHT")
		4:
			if camera_shake_intensity > 0:
				_apply_camera_shake(delta)
			else:
				_show_objective()
				
func _on_meth_lab_entrance_entered(body):
	if body.is_in_group("player") && meth_lab_unlocked:
		entering_lab = true
		if dynamic_lighting:
			dynamic_lighting.update_lighting_state("LAB")

func _on_dialog_trigger_entered(body):
	if body.is_in_group("player") && !dialog_started:
		dialog_started = true
		if dynamic_lighting:
			dynamic_lighting.update_lighting_state("DAY")
		
func _on_police_response_changed(new_level):
	police_response_level = new_level
	if new_level >= 2 && dynamic_lighting:
		dynamic_lighting.update_lighting_state("EMERGENCY")
	elif new_level == 1 && dynamic_lighting:
		dynamic_lighting.update_lighting_state("NIGHT")
	elif new_level == 0 && dynamic_lighting:
		dynamic_lighting.update_lighting_state("DAY")

func _update_scene_effects(delta):
	if flash_effect_active:
		if has_node("FlashCanvas/BreachFlash"):
			get_node("FlashCanvas/BreachFlash").color = Color(1, 1, 1, flash_intensity)
	if warning_effect_active:
		warning_intensity = 0.3 + 0.2 * sin(time_passed * warning_flash_speed)
		if has_node("WarningCanvas/WarningOverlay"):
			get_node("WarningCanvas/WarningOverlay").color = Color(0.9, 0.1, 0.1, warning_intensity)
	$Camera2D.global_position = lerp($Camera2D.global_position, camera_target_position + camera_offset, 2.0 * delta)
	$Camera2D.zoom = lerp($Camera2D.zoom, current_zoom, zoom_speed * delta)

func _update_formation(delta):
	formation_center = calculate_formation_center()
	formation_center_smoothed = lerp(formation_center_smoothed, formation_center, 5.0 * delta)

func _move_formation(delta):
	for i in range(officers.size()):
		if i < officers.size() && i < formation_offsets.size():
			var target_pos = formation_center + formation_offsets[i].rotated(move_direction.angle())
			var direction = (target_pos - officers[i].global_position).normalized()
			officers[i].global_position += direction * raid_speed * delta

func _near_target(target, threshold):
	return formation_center.distance_to(target) < threshold

func _update_jesse_escape(delta):
	if jesse_escaping && jesse && escape_path.size() > 0:
		var target = escape_path[0]
		var direction = (target - jesse.global_position).normalized()
		jesse.global_position += direction * jesse_escape_speed * delta
		if jesse.global_position.distance_to(target) < 5.0:
			escape_path.pop_front()
			if escape_path.size() == 0:
				jesse_escaping = false
				jesse.visible = false

func _focus_camera_on_house(delta):
	if camera_transition_time < camera_transition_duration:
		camera_transition_time += delta
		var t = camera_transition_time / camera_transition_duration
		t = ease(t, 0.5)
		camera_target_position = lerp(formation_center_smoothed, house_position, t)
		current_zoom = lerp(initial_zoom, target_zoom, t)
	else:
		camera_target_position = house_position
		current_zoom = target_zoom

func _focus_camera_on_car(delta):
	if camera_transition_time < camera_transition_duration:
		camera_transition_time += delta
		var t = camera_transition_time / camera_transition_duration
		t = ease(t, 0.5)
		camera_target_position = lerp(formation_center_smoothed, car_position, t)
		current_zoom = lerp(initial_zoom, car_focus_zoom, t)
	else:
		camera_target_position = car_position
		current_zoom = car_focus_zoom

func _start_breach_effect():
	flash_effect_active = true
	flash_intensity = 1.0

func _update_breach_effect(delta):
	flash_intensity = lerp(flash_intensity, 0.0, 5.0 * delta)
	if flash_intensity < 0.01:
		flash_effect_active = false
		flash_intensity = 0.0
		raid_phase = 5
		jesse_escaping = true

func _start_warning_effect():
	warning_effect_active = true
	warning_intensity = 0.5 + sin(time_passed * warning_flash_speed) * 0.3

func _apply_camera_shake(_delta):
	camera_shake_intensity = 0.5 + sin(time_passed * 10.0) * 0.3

func _show_objective():
	Log.info("Objective completed")

func _on_game_over(_reason):
	if dynamic_lighting:
		dynamic_lighting.update_lighting_state("EMERGENCY") 

func _update_timer(delta):
	if countdown_time > 0:
		countdown_time -= delta
		_update_timer_display()
	else:
		if !timer_finished:
			timer_finished = true
			_on_timer_finished()
	if timer_label_alpha != timer_label_target_alpha:
		timer_label_alpha = lerp(timer_label_alpha, timer_label_target_alpha, delta * (1.0 / label_fade_time))
		if timer_label:
			timer_label.modulate.a = timer_label_alpha

func _update_timer_display():
	if timer_time:
		var minutes = int(countdown_time / 60)
		var seconds = int(countdown_time) % 60
		timer_time.text = "%d:%02d" % [minutes, seconds]
		if countdown_time < 10:
			timer_time.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
			warning_effect_active = true
		else:
			timer_time.add_theme_color_override("font_color", Color(1, 1, 1))

func _on_timer_finished():
	Log.info("Timer finished")
	if timer_label:
		timer_label_target_alpha = 0.0
	warning_effect_active = false
	if !in_passenger_seat && !game_over_shown:
		_show_game_over("You failed to meet Hank in time")
		
func _show_game_over(_reason = ""):
	if game_over_shown:
		return
	game_over_shown = true
	if player:
		player.set_physics_process(false)
	if game_over_screen:
		game_over_screen.visible = true
	if tension_manager:
		tension_manager.reset()
	if dynamic_lighting:
		dynamic_lighting.update_lighting_state("EMERGENCY") 
