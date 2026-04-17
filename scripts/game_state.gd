extends Node

signal turn_changed(player: PlayerData)

var players: Array[PlayerData] = []
var current_player_index: int = 0
var has_occupied_this_turn: bool = false
var god_mode: bool = false


func _ready() -> void:
	var pcfg: Array = Config.get_value("players")
	for pd in pcfg:
		var p := PlayerData.new()
		p.player_name = pd.get("name", "Player")
		var c: Array = pd.get("color", [1.0, 1.0, 1.0])
		p.color = Color(c[0], c[1], c[2])
		p.manpower  = pd.get("manpower",  100)
		p.supplies  = pd.get("supplies",  100)
		p.materials = pd.get("materials", 100)
		players.append(p)


func current_player() -> PlayerData:
	return players[current_player_index]


func opponent() -> PlayerData:
	return players[(current_player_index + 1) % players.size()]


func end_turn() -> void:
	has_occupied_this_turn = false
	current_player_index = (current_player_index + 1) % players.size()
	turn_changed.emit(current_player())
