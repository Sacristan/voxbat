extends Control

const PORT := 7777

@onready var host_btn: Button = $CenterContainer/VBoxContainer/HostButton
@onready var ip_field: LineEdit = $CenterContainer/VBoxContainer/JoinRow/IPLineEdit
@onready var join_btn: Button = $CenterContainer/VBoxContainer/JoinRow/JoinButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var back_btn: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	back_btn.pressed.connect(_on_back_pressed)


func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		status_label.text = "Failed to start server (port %d in use?)" % PORT
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	GameState.is_multiplayer = true
	GameState.is_host = true
	GameState.my_peer_id = 1
	host_btn.disabled = true
	join_btn.disabled = true
	status_label.text = "Hosting on port %d — waiting for opponent..." % PORT


func _on_join_pressed() -> void:
	var ip := ip_field.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		status_label.text = "Failed to connect to %s:%d" % [ip, PORT]
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	GameState.is_multiplayer = true
	GameState.is_host = false
	host_btn.disabled = true
	join_btn.disabled = true
	status_label.text = "Connecting to %s:%d..." % [ip, PORT]


func _on_peer_connected(_id: int) -> void:
	status_label.text = "Opponent connected! Starting..."
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _on_connected_to_server() -> void:
	GameState.my_peer_id = multiplayer.get_unique_id()
	status_label.text = "Connected! Starting..."
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://main.tscn")


func _on_connection_failed() -> void:
	status_label.text = "Connection failed."
	multiplayer.multiplayer_peer = null
	host_btn.disabled = false
	join_btn.disabled = false
	GameState.is_multiplayer = false
	GameState.is_host = false


func _on_peer_disconnected(_id: int) -> void:
	status_label.text = "Opponent disconnected."


func _on_back_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	GameState.is_multiplayer = false
	GameState.is_host = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
