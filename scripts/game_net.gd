extends Node

var _main: Node3D


func _ready() -> void:
	_main = get_parent()
	if not GameState.is_multiplayer:
		return
	set_multiplayer_authority(1)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func is_input_blocked() -> bool:
	return GameState.is_multiplayer and GameState.current_player_index != GameState.my_player_index()


func on_turn_changed() -> void:
	if GameState.is_multiplayer:
		_main.hud.set_end_turn_interactable(GameState.current_player_index == GameState.my_player_index())
	else:
		_main.camera_rig.focus_for_player(GameState.current_player_index)


func handle_action(action: String, cell: Cell) -> void:
	if GameState.is_multiplayer:
		request(action, cell.grid_x, cell.grid_z)
	else:
		match action:
			"occupy":            _main._on_occupy_pressed(cell)
			"raze":              _main._on_raze_pressed(cell)
			"upgrade":           _main._on_upgrade_pressed(cell)
			"build_residential": _main._on_build_residential_pressed(cell)
			"build_industrial":  _main._on_build_industrial_pressed(cell)
			"mobilize":          _main._on_mobilize_pressed(cell)


func handle_end_turn() -> void:
	if GameState.is_multiplayer:
		if GameState.current_player_index != GameState.my_player_index():
			return
		request("end_turn", -1, -1)
	else:
		_main._do_end_turn()


func request(action: String, gx: int, gz: int) -> void:
	if GameState.is_host:
		_dispatch(action, gx, gz)
	else:
		_send_to_host.rpc_id(1, action, gx, gz)


@rpc("any_peer", "reliable")
func _send_to_host(action: String, gx: int, gz: int) -> void:
	if not GameState.is_host:
		return
	_dispatch(action, gx, gz)


func _dispatch(action: String, gx: int, gz: int) -> void:
	var cell: Cell = _main.grid[gz][gx] if gx >= 0 else null
	match action:
		"occupy":
			if _main._can_occupy(cell): _apply_occupy.rpc(gx, gz)
		"raze":
			if _main._can_raze(cell): _apply_raze.rpc(gx, gz)
		"upgrade":
			if _main._can_upgrade(cell): _apply_upgrade.rpc(gx, gz)
		"build_residential":
			if _main._can_convert(cell, Cell.CellType.RESIDENTIAL): _apply_build_residential.rpc(gx, gz)
		"build_industrial":
			if _main._can_convert(cell, Cell.CellType.INDUSTRY): _apply_build_industrial.rpc(gx, gz)
		"mobilize":
			if _main._can_mobilize(cell): _apply_mobilize.rpc(gx, gz)
		"end_turn":
			_apply_end_turn.rpc()


@rpc("authority", "call_local", "reliable")
func _apply_occupy(gx: int, gz: int) -> void:
	_main._on_occupy_pressed(_main.grid[gz][gx])


@rpc("authority", "call_local", "reliable")
func _apply_raze(gx: int, gz: int) -> void:
	_main._on_raze_pressed(_main.grid[gz][gx])


@rpc("authority", "call_local", "reliable")
func _apply_upgrade(gx: int, gz: int) -> void:
	_main._on_upgrade_pressed(_main.grid[gz][gx])


@rpc("authority", "call_local", "reliable")
func _apply_build_residential(gx: int, gz: int) -> void:
	_main._on_build_residential_pressed(_main.grid[gz][gx])


@rpc("authority", "call_local", "reliable")
func _apply_build_industrial(gx: int, gz: int) -> void:
	_main._on_build_industrial_pressed(_main.grid[gz][gx])


@rpc("authority", "call_local", "reliable")
func _apply_mobilize(gx: int, gz: int) -> void:
	_main._on_mobilize_pressed(_main.grid[gz][gx])


@rpc("authority", "call_local", "reliable")
func _apply_end_turn() -> void:
	_main._do_end_turn()


func _on_peer_disconnected(_id: int) -> void:
	if not _main._is_game_over:
		_main._is_game_over = true
		_main.hud.show_game_over("Opponent disconnected")
