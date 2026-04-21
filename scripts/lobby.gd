extends Control

const APP_ID := "Voxbat_v1.0_app"
const TRACKER_URLS: Array[String] = [
	"wss://tracker.openwebtorrent.com",
	"wss://tracker.webtorrent.dev",
]
const STUN_URLS: Array[String] = [
	"stun:stun.l.google.com:19302",
	"stun:stun1.l.google.com:19302",
]

const ADJECTIVES := ["Iron", "Swift", "Dark", "Bold", "Grim", "Wild", "Sly", "Grim",
		"Rust", "Ash", "Stone", "Frost", "Bleak", "Dusk", "Pale", "Worn"]
const NOUNS := ["Wolf", "Fox", "Bear", "Hawk", "Crow", "Fist", "Blade", "Toad",
		"Mole", "Rat", "Newt", "Slug", "Wasp", "Moth", "Grub", "Bat"]

@onready var host_name_field: LineEdit = $CenterContainer/VBoxContainer/HostRow/HostNameField
@onready var host_btn: Button = $CenterContainer/VBoxContainer/HostRow/HostButton
@onready var refresh_btn: Button = $CenterContainer/VBoxContainer/BrowseHeader/RefreshButton
@onready var game_list_container: VBoxContainer = $CenterContainer/VBoxContainer/GameScrollContainer/GameListContainer
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var back_btn: Button = $CenterContainer/VBoxContainer/BackButton

var _hosted_game_key: String = ""
var _firebase_available: bool = false


func _ready() -> void:
	_cleanup_previous_session()

	host_name_field.text = _random_name()
	host_btn.pressed.connect(_on_host_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	var db_url: String = Config.get_value("firebase.database_url")
	if db_url.is_empty():
		_set_status("Set firebase.database_url in config.json to enable game browser.")
		refresh_btn.disabled = true
	else:
		_firebase_available = true
		_refresh_game_list()


func _cleanup_previous_session() -> void:
	if GameState.tube_client != null:
		GameState.tube_client.leave_session()
		GameState.tube_client.queue_free()
		GameState.tube_client = null
	GameState.is_multiplayer = false
	GameState.is_host = false


func _create_tube_client() -> TubeClient:
	var context := TubeContext.new()
	context.app_id = APP_ID
	context.trackers_urls = TRACKER_URLS
	context.stun_servers_urls = STUN_URLS

	var tube := TubeClient.new()
	tube.context = context
	GameState.add_child(tube)
	GameState.tube_client = tube
	return tube


func _on_host_pressed() -> void:
	_set_ui_busy(true)
	_set_status("Creating session...")

	var tube := _create_tube_client()
	tube.session_created.connect(_on_session_created)
	tube.session_left.connect(_on_session_left)
	tube.error_raised.connect(_on_tube_error)
	tube.create_session()


func _on_session_created() -> void:
	var tube := GameState.tube_client
	tube.peer_connected.connect(_on_peer_connected)
	tube.peer_disconnected.connect(_on_peer_disconnected)

	GameState.is_multiplayer = true
	GameState.is_host = true
	GameState.my_peer_id = 1

	var session_id := tube.session_id
	_set_status("Waiting for opponent... (session: %s)" % session_id)

	if _firebase_available:
		var game_name := host_name_field.text.strip_edges()
		if game_name.is_empty():
			game_name = _random_name()
		_hosted_game_key = await MasterServer.register_game(game_name, session_id)


func _join_game(session_id: String) -> void:
	_set_ui_busy(true)
	_set_status("Joining session %s..." % session_id)

	var tube := _create_tube_client()
	tube.session_joined.connect(_on_session_joined)
	tube.session_left.connect(_on_session_left)
	tube.error_raised.connect(_on_tube_error)
	tube.join_session(session_id)


func _on_session_joined() -> void:
	GameState.is_multiplayer = true
	GameState.is_host = false
	GameState.my_peer_id = GameState.tube_client.peer_id
	_set_status("Connected! Starting...")
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _on_peer_connected(_id: int) -> void:
	_set_status("Opponent connected! Starting...")
	if _firebase_available and not _hosted_game_key.is_empty():
		await MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _on_peer_disconnected(_id: int) -> void:
	_set_status("Opponent disconnected.")


func _on_session_left() -> void:
	_set_status("Session ended.")
	_set_ui_busy(false)


func _on_tube_error(_code: int, message: String) -> void:
	_set_status("Error: %s" % message)
	_set_ui_busy(false)


func _on_back_pressed() -> void:
	if _firebase_available and not _hosted_game_key.is_empty():
		await MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""
	_cleanup_previous_session()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_refresh_pressed() -> void:
	_refresh_game_list()


func _refresh_game_list() -> void:
	refresh_btn.disabled = true
	_clear_game_list()
	var placeholder := Label.new()
	placeholder.text = "Loading..."
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_list_container.add_child(placeholder)

	var games: Array = await MasterServer.list_games()
	_clear_game_list()

	if games.is_empty():
		var lbl := Label.new()
		lbl.text = "No games found."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_list_container.add_child(lbl)
	else:
		for game in games:
			var btn := Button.new()
			btn.text = game.get("game_name", "?")
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var session_id: String = game.get("session_id", "")
			btn.pressed.connect(func(): _join_game(session_id))
			game_list_container.add_child(btn)

	refresh_btn.disabled = false


func _clear_game_list() -> void:
	for child in game_list_container.get_children():
		child.queue_free()


func _set_ui_busy(busy: bool) -> void:
	host_btn.disabled = busy
	refresh_btn.disabled = busy


func _set_status(text: String) -> void:
	status_label.text = text


func _random_name() -> String:
	return ADJECTIVES[randi() % ADJECTIVES.size()] + NOUNS[randi() % NOUNS.size()]
