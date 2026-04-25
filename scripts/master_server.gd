extends Node

const STALE_SECONDS := 120
const JSON_HEADERS := ["Content-Type: application/json"]

var _db_url: String = ""


func _ready() -> void:
	_db_url = Config.get_value("firebase.database_url").rstrip("/")
	print("MasterServer: db_url = ", _db_url)


func register_game(game_name: String) -> String:
	var body := JSON.stringify({
		"game_name": game_name,
		"timestamp": Time.get_unix_time_from_system()
	})
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(_db_url + "/games.json", JSON_HEADERS, HTTPClient.METHOD_POST, body)
	print("MasterServer: register_game request err=", err, " body=", body)
	var result: Array = await http.request_completed
	http.queue_free()
	print("MasterServer: register_game result=", result[0], " code=", result[1], " body=", result[3].get_string_from_utf8())
	if result[0] == OK and result[1] == 200:
		var data = JSON.parse_string(result[3].get_string_from_utf8())
		if data is Dictionary:
			return data.get("name", "")
	return ""


func unregister_game(key: String) -> void:
	if key.is_empty():
		return
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(_db_url + "/games/" + key + ".json", [], HTTPClient.METHOD_DELETE)
	print("MasterServer: unregister_game key=", key, " err=", err)
	var result: Array = await http.request_completed
	http.queue_free()
	print("MasterServer: unregister_game result=", result[0], " code=", result[1])


func list_games() -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(_db_url + "/games.json")
	print("MasterServer: list_games request err=", err)
	var result: Array = await http.request_completed
	http.queue_free()
	print("MasterServer: list_games result=", result[0], " code=", result[1], " body=", result[3].get_string_from_utf8())
	if result[0] != OK or result[1] != 200:
		return []
	var text: String = result[3].get_string_from_utf8()
	if text.strip_edges() == "null":
		return []
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return []
	var now := Time.get_unix_time_from_system()
	var games: Array = []
	for key in data:
		var entry: Dictionary = data[key]
		if now - entry.get("timestamp", 0) < STALE_SECONDS:
			entry["key"] = key
			games.append(entry)
	return games


func write_sdp(game_key: String, type: String, sdp: String) -> bool:
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(
		_db_url + "/games/" + game_key + "/" + type + ".json",
		JSON_HEADERS, HTTPClient.METHOD_PUT, JSON.stringify(sdp)
	)
	print("MasterServer: write_sdp type=", type, " err=", err)
	var result: Array = await http.request_completed
	http.queue_free()
	return result[0] == OK and result[1] == 200


func read_sdp(game_key: String, type: String) -> String:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(_db_url + "/games/" + game_key + "/" + type + ".json")
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != OK or result[1] != 200:
		return ""
	var text: String = result[3].get_string_from_utf8().strip_edges()
	if text == "null":
		return ""
	var parsed = JSON.parse_string(text)
	return parsed if parsed is String else ""


func append_ice(game_key: String, role: String, candidate: Dictionary) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(
		_db_url + "/games/" + game_key + "/" + role + "_ice.json",
		JSON_HEADERS, HTTPClient.METHOD_POST, JSON.stringify(candidate)
	)
	await http.request_completed
	http.queue_free()


func read_ice(game_key: String, role: String) -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(_db_url + "/games/" + game_key + "/" + role + "_ice.json")
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != OK or result[1] != 200:
		return []
	var text: String = result[3].get_string_from_utf8().strip_edges()
	if text == "null":
		return []
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return []
	return data.values()
