extends Control

const STUN_CONFIG := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]}
const POLL_INTERVAL := 0.5

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
var _webrtc: WebRTCMultiplayerPeer = null
var _conn: WebRTCPeerConnection = null
var _signaling_timer: Timer = null
var _remote_ice_applied: int = 0
var _is_host_role: bool = false
var _answer_received: bool = false
var _polling: bool = false


func _ready() -> void:
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


func _process(_delta: float) -> void:
	if _webrtc != null:
		_webrtc.poll()


func _on_host_pressed() -> void:
	_is_host_role = true
	_set_ui_busy(true)
	_set_status("Registering game...")

	if not _firebase_available:
		_set_status("Firebase unavailable.")
		_set_ui_busy(false)
		return

	var game_name := host_name_field.text.strip_edges()
	if game_name.is_empty():
		game_name = _random_name()
	_hosted_game_key = await MasterServer.register_game(game_name)
	if _hosted_game_key.is_empty():
		_set_status("Failed to register game.")
		_set_ui_busy(false)
		return

	_setup_webrtc(true)
	_conn.create_offer()

	GameState.is_multiplayer = true
	GameState.is_host = true
	GameState.my_peer_id = 1
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_set_status("Waiting for opponent...")
	_start_signaling_poll()


func _join_game(game_key: String) -> void:
	_is_host_role = false
	_hosted_game_key = game_key
	_set_ui_busy(true)
	_set_status("Reading game offer...")

	var offer_sdp: String = ""
	for i in range(20):
		offer_sdp = await MasterServer.read_sdp(game_key, "offer")
		if not offer_sdp.is_empty():
			break
		_set_status("Waiting for host offer... (%d)" % (i + 1))
		await get_tree().create_timer(0.5).timeout
	if offer_sdp.is_empty():
		_set_status("Could not read game offer.")
		_set_ui_busy(false)
		return

	_setup_webrtc(false)
	_conn.set_remote_description("offer", offer_sdp)

	GameState.is_multiplayer = true
	GameState.is_host = false
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_set_status("Connecting...")
	_start_signaling_poll()


func _setup_webrtc(as_host: bool) -> void:
	_webrtc = WebRTCMultiplayerPeer.new()
	if as_host:
		_webrtc.create_server()
	else:
		_webrtc.create_client(2)

	_conn = WebRTCPeerConnection.new()
	_conn.initialize(STUN_CONFIG)
	_conn.session_description_created.connect(_on_sdp_created)
	_conn.ice_candidate_created.connect(_on_ice_candidate_created)

	_webrtc.add_peer(_conn, 2 if as_host else 1)
	multiplayer.multiplayer_peer = _webrtc


func _on_sdp_created(type: String, sdp: String) -> void:
	_conn.set_local_description(type, sdp)
	if not _hosted_game_key.is_empty():
		MasterServer.write_sdp(_hosted_game_key, type, sdp)


func _on_ice_candidate_created(media: String, index: int, sdp: String) -> void:
	if _hosted_game_key.is_empty():
		return
	var role := "host" if _is_host_role else "client"
	MasterServer.append_ice(_hosted_game_key, role, {"media": media, "index": index, "sdp": sdp})


func _start_signaling_poll() -> void:
	_signaling_timer = Timer.new()
	add_child(_signaling_timer)
	_signaling_timer.wait_time = POLL_INTERVAL
	_signaling_timer.timeout.connect(_poll_signaling)
	_signaling_timer.start()


func _stop_signaling_poll() -> void:
	if _signaling_timer != null:
		_signaling_timer.stop()
		_signaling_timer.queue_free()
		_signaling_timer = null


func _poll_signaling() -> void:
	if _polling or _webrtc == null:
		return
	_polling = true

	if _is_host_role and not _answer_received:
		var answer := await MasterServer.read_sdp(_hosted_game_key, "answer")
		if not answer.is_empty():
			_conn.set_remote_description("answer", answer)
			_answer_received = true

	var remote_role := "client" if _is_host_role else "host"
	var candidates: Array = await MasterServer.read_ice(_hosted_game_key, remote_role)
	for i in range(_remote_ice_applied, candidates.size()):
		var c: Dictionary = candidates[i]
		_conn.add_ice_candidate(c.get("media", ""), c.get("index", 0), c.get("sdp", ""))
		_remote_ice_applied += 1

	_polling = false


func _on_peer_connected(_id: int) -> void:
	_stop_signaling_poll()
	_set_status("Opponent connected! Starting...")
	await MasterServer.unregister_game(_hosted_game_key)
	_hosted_game_key = ""
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _on_connected_to_server() -> void:
	_stop_signaling_poll()
	GameState.my_peer_id = multiplayer.get_unique_id()
	_set_status("Connected! Starting...")
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _on_connection_failed() -> void:
	_stop_signaling_poll()
	_set_status("Connection failed.")
	_cleanup_webrtc()
	GameState.is_multiplayer = false
	GameState.is_host = false
	_set_ui_busy(false)


func _on_peer_disconnected(_id: int) -> void:
	_set_status("Opponent disconnected.")


func _on_back_pressed() -> void:
	_stop_signaling_poll()
	if _firebase_available and not _hosted_game_key.is_empty():
		await MasterServer.unregister_game(_hosted_game_key)
		_hosted_game_key = ""
	_cleanup_webrtc()
	GameState.is_multiplayer = false
	GameState.is_host = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _cleanup_webrtc() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_webrtc = null
	_conn = null
	_remote_ice_applied = 0
	_answer_received = false
	_polling = false


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
			var key: String = game.get("key", "")
			btn.pressed.connect(func(): _join_game(key))
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
