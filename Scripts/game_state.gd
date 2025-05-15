extends Node

var player_health: int = 100
var currency: int = 0
var heat_level: int = 0

var current_chapter: int = 1
var current_mission: String = "intro"
var inventory = {}

var player_position: Vector2 = Vector2.ZERO
var current_scene: String = "" 