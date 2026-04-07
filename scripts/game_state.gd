extends Node

signal turn_changed(player: PlayerData)

var players: Array[PlayerData] = []
var current_player_index: int = 0
var has_occupied_this_turn: bool = false


func _ready() -> void:
	var p1 := PlayerData.new()
	p1.player_name = "Player A"
	p1.color = Color(1.0, 0.15, 0.15)

	var p2 := PlayerData.new()
	p2.player_name = "Player B"
	p2.color = Color(0.15, 0.35, 1.0)

	players = [p1, p2]


func current_player() -> PlayerData:
	return players[current_player_index]


func opponent() -> PlayerData:
	return players[(current_player_index + 1) % players.size()]


func end_turn() -> void:
	has_occupied_this_turn = false
	current_player_index = (current_player_index + 1) % players.size()
	turn_changed.emit(current_player())
