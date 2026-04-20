extends Node

signal turn_changed(player: PlayerData)

var players: Array[PlayerData] = []
var current_player_index: int = 0
var has_occupied_this_turn: bool = false
var god_mode: bool = false

var is_multiplayer: bool = false
var is_host: bool = false
var my_peer_id: int = 1
var ai_flags: Array[bool] = [false, false]


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


func my_player_index() -> int:
	if not is_multiplayer:
		return current_player_index
	return 0 if is_host else 1


func reset() -> void:
	current_player_index = 0
	has_occupied_this_turn = false
	var pcfg: Array = Config.get_value("players")
	for i in players.size():
		var pd: Dictionary = pcfg[i]
		players[i].manpower = pd.get("manpower", 100)
		players[i].supplies = pd.get("supplies", 100)
		players[i].materials = pd.get("materials", 100)
		players[i].starvation_turns = 0


func current_player() -> PlayerData:
	return players[current_player_index]


func opponent() -> PlayerData:
	return players[(current_player_index + 1) % players.size()]


func end_turn() -> void:
	has_occupied_this_turn = false
	current_player_index = (current_player_index + 1) % players.size()
	turn_changed.emit(current_player())
