extends Control

const APP_ID := "Hexfront_v1.0_a"
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
@onready var password_toggle: CheckBox = $CenterContainer/VBoxContainer/PasswordRow/PasswordToggle
@onready var password_field: LineEdit = $CenterContainer/VBoxContainer/PasswordRow/PasswordField
@onready var refresh_btn: Button = $CenterContainer/VBoxContainer/BrowseHeader/RefreshButton
@onready var game_list_container: VBoxContainer = $CenterContainer/VBoxContainer/GameScrollContainer/GameListContainer
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var back_btn: Button = $CenterContainer/VBoxContainer/BackButton
@onready var password_prompt: Control = $PasswordPrompt
@onready var prompt_field: LineEdit = $PasswordPrompt/CenterContainer/Panel/VBox/PromptField
@onready var prompt_error: Label = $PasswordPrompt/CenterContainer/Panel/VBox/PromptError
@onready var prompt_cancel_btn: Button = $PasswordPrompt/CenterContainer/Panel/VBox/ButtonRow/CancelButton
@onready var prompt_join_btn: Button = $PasswordPrompt/CenterContainer/Panel/VBox/ButtonRow/JoinButton

var _hosted_game_key: String = ""
var _firebase_available: bool = false
var _pending_game_name: String = ""
var _pending_session_id: String = ""
var _pending_password_hash: String = ""
var _list_etag: String = ""
var _refresh_timer: Timer
var _is_refreshing: bool = false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_cleanup_previous_session()

	host_name_field.text = _random_name()
	host_btn.pressed.connect(_on_host_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	password_toggle.toggled.connect(_on_password_toggle)
	prompt_cancel_btn.pressed.connect(_on_prompt_cancel)
	prompt_join_btn.pressed.connect(_on_prompt_join)
	prompt_field.text_submitted.connect(func(_t): _on_prompt_join())

	var db_url: String = Config.get_value("firebase.database_url")
	if db_url.is_empty():
		_set_status("Set firebase.database_url in config.json to enable game browser.")
		refresh_btn.disabled = true
	else:
		_firebase_available = true
		_refresh_game_list()
		_refresh_timer = Timer.new()
		_refresh_timer.wait_time = 10.0
		_refresh_timer.timeout.connect(func(): _refresh_game_list(false))
		add_child(_refresh_timer)
		_refresh_timer.start()


func _exit_tree() -> void:
	get_tree().auto_accept_quit = true
	if _firebase_available and not _hosted_game_key.is_empty():
		MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_handle_quit_request()


func _handle_quit_request() -> void:
	if _firebase_available and not _hosted_game_key.is_empty():
		await MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""
	get_tree().quit()


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
	var game_name := host_name_field.text.strip_edges()
	if game_name.is_empty():
		game_name = _random_name()
	_set_status("Waiting for opponent... (%s_%s)" % [game_name, session_id])

	if _firebase_available:
		var password_hash := ""
		if password_toggle.button_pressed and not password_field.text.is_empty():
			password_hash = _hash_password(password_field.text)
		_hosted_game_key = await MasterServer.register_game(game_name, session_id, password_hash)


func _join_game(game_name: String, session_id: String, password_hash: String = "") -> void:
	if not password_hash.is_empty():
		_show_password_prompt(game_name, session_id, password_hash)
		return
	_do_join(game_name, session_id)


func _do_join(game_name: String, session_id: String) -> void:
	_set_ui_busy(true)
	_set_status("Joining %s_%s..." % [game_name, session_id])

	var tube := _create_tube_client()
	tube.session_joined.connect(_on_session_joined)
	tube.session_left.connect(_on_session_left)
	tube.error_raised.connect(_on_tube_error)
	tube.join_session(session_id)


func _show_password_prompt(game_name: String, session_id: String, password_hash: String) -> void:
	_pending_game_name = game_name
	_pending_session_id = session_id
	_pending_password_hash = password_hash
	prompt_field.text = ""
	prompt_error.visible = false
	password_prompt.visible = true
	prompt_field.grab_focus()


func _on_password_toggle(enabled: bool) -> void:
	password_field.visible = enabled
	if not enabled:
		password_field.text = ""


func _on_prompt_cancel() -> void:
	password_prompt.visible = false


func _on_prompt_join() -> void:
	if _hash_password(prompt_field.text) != _pending_password_hash:
		prompt_error.visible = true
		return
	password_prompt.visible = false
	_do_join(_pending_game_name, _pending_session_id)


func _hash_password(pwd: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(pwd.to_utf8_buffer())
	return ctx.finish().hex_encode()


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
	if _firebase_available and not _hosted_game_key.is_empty():
		await MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""


func _on_tube_error(_code: int, message: String) -> void:
	_set_status("Error: %s" % message)
	_set_ui_busy(false)
	if _firebase_available and not _hosted_game_key.is_empty():
		await MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""


func _on_back_pressed() -> void:
	if _firebase_available and not _hosted_game_key.is_empty():
		await MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""
	_cleanup_previous_session()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_refresh_pressed() -> void:
	_refresh_game_list()


func _refresh_game_list(show_loading: bool = true) -> void:
	if _is_refreshing:
		return
	_is_refreshing = true
	refresh_btn.disabled = true
	if show_loading:
		_clear_game_list()
		var placeholder := Label.new()
		placeholder.text = "Loading..."
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_list_container.add_child(placeholder)

	var response: Dictionary = await MasterServer.list_games(_list_etag)
	_list_etag = response["etag"]

	if response["games"] == null:
		refresh_btn.disabled = false
		_is_refreshing = false
		return

	_clear_game_list()
	var games: Array = response["games"]
	if games.is_empty():
		var lbl := Label.new()
		lbl.text = "No games found."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_list_container.add_child(lbl)
	else:
		for game in games:
			var btn := Button.new()
			var game_name: String = game.get("game_name", "?")
			var session_id: String = game.get("session_id", "")
			var password_hash: String = game.get("password_hash", "")
			btn.text = "%s_%s%s" % [game_name, session_id, " [P]" if not password_hash.is_empty() else ""]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.pressed.connect(func(): _join_game(game_name, session_id, password_hash))
			game_list_container.add_child(btn)

	refresh_btn.disabled = false
	_is_refreshing = false


func _clear_game_list() -> void:
	for child in game_list_container.get_children():
		child.queue_free()


func _set_ui_busy(busy: bool) -> void:
	host_btn.disabled = busy
	refresh_btn.disabled = busy
	if _refresh_timer:
		if busy:
			_refresh_timer.stop()
		else:
			_refresh_timer.start()


func _set_status(text: String) -> void:
	status_label.text = text


func _random_name() -> String:
	return ADJECTIVES[randi() % ADJECTIVES.size()] + NOUNS[randi() % NOUNS.size()]
