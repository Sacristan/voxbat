extends Node

const STALE_SECONDS := 120
const JSON_HEADERS := ["Content-Type: application/json"]

var _db_url: String = ""


func _ready() -> void:
	_db_url = Config.get_value("firebase.database_url").rstrip("/")
	#if OS.is_debug_build(): print("MasterServer: db_url = ", _db_url)

func register_game(game_name: String, session_id: String, password_hash: String = "") -> String:
	var entry: Dictionary = {
		"game_name": game_name,
		"session_id": session_id,
		"timestamp": Time.get_unix_time_from_system()
	}
	if not password_hash.is_empty():
		entry["password_hash"] = password_hash
	var body := JSON.stringify(entry)
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(_db_url + "/games.json", JSON_HEADERS, HTTPClient.METHOD_POST, body)
	if OS.is_debug_build(): print("MasterServer: register_game request err=", err, " body=", body)
	var result: Array = await http.request_completed
	http.queue_free()
	if OS.is_debug_build(): print("MasterServer: register_game result=", result[0], " code=", result[1], " body=", result[3].get_string_from_utf8())
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
	if OS.is_debug_build(): print("MasterServer: unregister_game key=", key, " err=", err)
	var result: Array = await http.request_completed
	http.queue_free()
	if OS.is_debug_build(): print("MasterServer: unregister_game result=", result[0], " code=", result[1])


## Returns {"games": Array, "etag": String} on success/change,
## or {"games": null, "etag": String} when server returns 304 (unchanged).
func list_games(etag: String = "") -> Dictionary:
	var headers: Array[String] = []
	if not etag.is_empty():
		headers = ["If-None-Match: " + etag]
	var http := HTTPRequest.new()
	add_child(http)
	http.request(_db_url + "/games.json", headers)
	var result: Array = await http.request_completed
	http.queue_free()

	if result[1] == 304:
		return {"games": null, "etag": etag}

	if result[0] != OK or result[1] != 200:
		return {"games": [], "etag": etag}

	var new_etag := etag
	for header: String in result[2]:
		if header.to_lower().begins_with("etag:"):
			new_etag = header.substr(5).strip_edges()
			break

	var text: String = result[3].get_string_from_utf8()
	if text.strip_edges() == "null":
		return {"games": [], "etag": new_etag}
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return {"games": [], "etag": new_etag}
	var now := Time.get_unix_time_from_system()
	var games: Array = []
	for key in data:
		var entry: Dictionary = data[key]
		if now - entry.get("timestamp", 0) < STALE_SECONDS:
			entry["key"] = key
			games.append(entry)
	return {"games": games, "etag": new_etag}
