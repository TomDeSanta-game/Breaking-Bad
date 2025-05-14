extends Node

@export_category("Audio Settings")
@export var music_crossfade_time: float = 2.0
@export var ambient_crossfade_time: float = 3.0
@export var sound_bus: String = "Master"

@export_category("Music Tracks")
@export var normal_music: AudioStream
@export var tense_music: AudioStream
@export var chase_music: AudioStream
@export var stealth_music: AudioStream

@export_category("Ambient Sounds")
@export var normal_ambient: AudioStream
@export var tense_ambient: AudioStream

@export_category("Sound Effects")
@export var tension_stinger: AudioStream
@export var detection_stinger: AudioStream
@export var alert_stinger: AudioStream

var current_music_player: AudioStreamPlayer
var next_music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var current_music_name: String = ""
var current_ambient_name: String = ""
var last_tension_level = -1
var transitioning: bool = false

func _ready():
	current_music_player = AudioStreamPlayer.new()
	current_music_player.bus = sound_bus
	current_music_player.volume_db = 0.0
	add_child(current_music_player)
	
	next_music_player = AudioStreamPlayer.new()
	next_music_player.bus = sound_bus
	next_music_player.volume_db = -80.0
	add_child(next_music_player)
	
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = sound_bus
	ambient_player.volume_db = 0.0
	add_child(ambient_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = sound_bus
	sfx_player.volume_db = 0.0
	add_child(sfx_player)
	
	SignalBus.tension_level_changed.connect(_on_tension_level_changed)
	SignalBus.threshold_crossed.connect(_on_tension_threshold_crossed)
	SignalBus.player_detected.connect(_on_player_detected)
	
	if normal_music:
		play_music("normal", normal_music)
	if normal_ambient:
		play_ambient("normal", normal_ambient)

func _on_tension_level_changed(level_name: String, previous_level: String):
	var LEVEL = {
		"MINIMAL": 0,
		"LOW": 1,
		"MEDIUM": 2,
		"HIGH": 3,
		"CRITICAL": 4
	}
	
	if not LEVEL.has(level_name):
		return
		
	var level = LEVEL[level_name]
	var prev_level = LEVEL.get(previous_level, -1)
	
	match level:
		LEVEL.MINIMAL:
			if current_music_name != "normal" && normal_music && !transitioning:
				play_music("normal", normal_music)
			if current_ambient_name != "normal" && normal_ambient:
				play_ambient("normal", normal_ambient)
				
		LEVEL.LOW:
			if sfx_player && tension_stinger && prev_level < level:
				sfx_player.stream = tension_stinger
				sfx_player.play()
				
		LEVEL.MEDIUM:
			if current_music_name != "tense" && tense_music && !transitioning:
				play_music("tense", tense_music)
			if current_ambient_name != "tense" && tense_ambient:
				play_ambient("tense", tense_ambient)
				
		LEVEL.HIGH, LEVEL.CRITICAL:
			if current_music_name != "chase" && chase_music && !transitioning:
				play_music("chase", chase_music)

func _on_tension_threshold_crossed(_threshold_name, _direction, _threshold_value, _current_value):
	if _direction == "up" && tension_stinger && sfx_player:
		sfx_player.stream = tension_stinger
		sfx_player.play()

func _on_player_detected(npc_type):
	if npc_type && detection_stinger && sfx_player:
		sfx_player.stream = detection_stinger
		sfx_player.play()
		
		if chase_music && current_music_name != "chase" && !transitioning:
			play_music("chase", chase_music)
	elif !npc_type && stealth_music && current_music_name == "chase" && !transitioning:
		play_music("stealth", stealth_music)

func play_music(music_name: String, music_stream: AudioStream) -> void:
	if music_name == current_music_name:
		return
		
	current_music_name = music_name
	
	if transitioning:
		next_music_player.stop()
		
	var temp = current_music_player
	current_music_player = next_music_player
	next_music_player = temp
	
	current_music_player.stream = music_stream
	current_music_player.play()
	
	var tween = create_tween()
	tween.tween_property(current_music_player, "volume_db", 0.0, music_crossfade_time)
	tween.parallel().tween_property(next_music_player, "volume_db", -80.0, music_crossfade_time)
	transitioning = true
	
	await tween.finished
	next_music_player.stop()
	transitioning = false
	
	SignalBus.music_changed.emit(music_name)

func play_ambient(ambient_name: String, ambient_stream: AudioStream) -> void:
	if ambient_name == current_ambient_name:
		return
		
	current_ambient_name = ambient_name
	
	var tween = create_tween()
	if ambient_player.playing:
		tween.tween_property(ambient_player, "volume_db", -80.0, ambient_crossfade_time)
		await tween.finished
		
	ambient_player.stream = ambient_stream
	ambient_player.play()
	
	tween = create_tween()
	tween.tween_property(ambient_player, "volume_db", 0.0, ambient_crossfade_time)
	
	SignalBus.ambient_changed.emit(ambient_name)

func play_sound_effect(sfx_stream: AudioStream) -> void:
	if sfx_stream == null:
		return
		
	sfx_player.stream = sfx_stream
	sfx_player.play()

func update_tension_level(tension_level: float) -> void:
	var level = int(tension_level * 10)
	
	if level == last_tension_level:
		return
		
	last_tension_level = level
	
	if level >= 8:
		play_music("chase", chase_music)
		play_ambient("tense", tense_ambient)
	elif level >= 5:
		play_music("tense", tense_music)
		play_ambient("tense", tense_ambient)
	else:
		play_music("normal", normal_music)
		play_ambient("normal", normal_ambient)

func play_tension_stinger() -> void:
	play_sound_effect(tension_stinger)
	
func play_detection_stinger() -> void:
	play_sound_effect(detection_stinger)
	
func play_alert_stinger() -> void:
	play_sound_effect(alert_stinger)

func stop_all_audio():
	transitioning = false
	if current_music_player:
		current_music_player.stop()
	if next_music_player:
		next_music_player.stop()
	if ambient_player:
		ambient_player.stop()
	current_music_name = ""
	current_ambient_name = ""

func _on_tension_changed(_current, _previous):
	pass

func _on_threshold_crossed(_threshold_name, _direction, _threshold_value, _current_value):
	pass
