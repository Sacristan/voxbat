extends Node3D

const CellScene := preload("res://scenes/cell.tscn")

var GRID_SIZE: int = 5
var _start_positions: Array = []
var _industrial_positions: Array = []
var _village_positions: Array = []

var grid: Array = []
var _selected_cell: Cell = null
var _is_game_over: bool = false

@onready var grid_root: Node3D = $GridRoot
@onready var camera_rig = $CameraRig
@onready var hud = $HUD
@onready var cell_panel = $CellPanel


func _ready() -> void:
	GRID_SIZE = Config.get_value("grid.size")
	for p in Config.get_value("grid.start_positions"):
		_start_positions.append(Vector2i(p[0], p[1]))
	for p in Config.get_value("grid.industrial_positions"):
		_industrial_positions.append(Vector2i(p[0], p[1]))
	for p in Config.get_value("grid.village_positions"):
		_village_positions.append(Vector2i(p[0], p[1]))

	get_viewport().physics_object_picking = true
	_spawn_grid()
	_place_starting_cells()
	camera_rig.focus_for_player(GameState.current_player_index, true)
	camera_rig.fit_to_grid(GRID_SIZE)
	GameState.turn_changed.connect(_on_turn_changed)
	hud.end_turn_pressed.connect(_on_end_turn)
	hud.resource_info_requested.connect(_on_resource_info_requested)
	cell_panel.occupy_pressed.connect(_on_occupy_pressed)
	cell_panel.raze_pressed.connect(_on_raze_pressed)
	cell_panel.upgrade_pressed.connect(_on_upgrade_pressed)
	cell_panel.panel_closed.connect(_on_panel_closed)
	_update_hud()


func _spawn_grid() -> void:
	grid.resize(GRID_SIZE)
	for z in GRID_SIZE:
		grid[z] = []
		grid[z].resize(GRID_SIZE)
		for x in GRID_SIZE:
			var cell: Cell = CellScene.instantiate()
			cell.position = Vector3(x - GRID_SIZE / 2.0 + 0.5, 0.0, z - GRID_SIZE / 2.0 + 0.5)
			cell.grid_x = x
			cell.grid_z = z
			var pos := Vector2i(x, z)
			if pos in _start_positions:
				cell.cell_type = Cell.CellType.RESIDENTIAL
				cell.cell_level = 3  # metropolis
			elif pos in _industrial_positions:
				cell.cell_type = Cell.CellType.INDUSTRY
				cell.cell_level = 1  # workshop
			elif pos in _village_positions:
				cell.cell_type = Cell.CellType.RESIDENTIAL
				cell.cell_level = 1  # village (unoccupied)
			cell.cell_clicked.connect(_on_cell_clicked)
			grid_root.add_child(cell)
			grid[z][x] = cell


func _place_starting_cells() -> void:
	for i in _start_positions.size():
		var sp: Vector2i = _start_positions[i]
		grid[sp.y][sp.x].claim(GameState.players[i])


# Returns positions reachable from the player's starting base via owned cells.
func _get_connected_positions(player_idx: int) -> Dictionary:
	var start: Vector2i = _start_positions[player_idx]
	if grid[start.y][start.x].owner_index != player_idx:
		return {}
	var visited := {start: true}
	var queue: Array = [start]
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nx: int = cur.x + dx
				var nz: int = cur.y + dz
				if nx < 0 or nx >= GRID_SIZE or nz < 0 or nz >= GRID_SIZE:
					continue
				var npos := Vector2i(nx, nz)
				if visited.has(npos):
					continue
				if grid[nz][nx].owner_index == player_idx:
					visited[npos] = true
					queue.append(npos)
	return visited


func _has_adjacent_owned(gx: int, gz: int, player_idx: int) -> bool:
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var nx: int = gx + dx
			var nz: int = gz + dz
			if nx < 0 or nx >= GRID_SIZE or nz < 0 or nz >= GRID_SIZE:
				continue
			if grid[nz][nx].owner_index == player_idx:
				return true
	return false


# --- Per-cell resource helpers (return 0 during upgrade cooldown) ---

func _cell_mp(cell: Cell) -> int:
	if cell.upgrade_cooldown > 0:
		return 0
	match cell.cell_type:
		Cell.CellType.RESOURCE:
			return Config.get_value("economy.resource_cell_mp")
		Cell.CellType.INDUSTRY:
			var vals: Array = Config.get_value("economy.industry_cell_mp_per_level")
			return vals[cell.cell_level - 1]
		Cell.CellType.RESIDENTIAL:
			var vals: Array = Config.get_value("economy.residential_cell_mp_per_level")
			return vals[cell.cell_level - 1]
	return 0


func _cell_sup(cell: Cell) -> int:
	if cell.upgrade_cooldown > 0:
		return 0
	match cell.cell_type:
		Cell.CellType.RESOURCE:
			return Config.get_value("economy.resource_cell_sup")
		Cell.CellType.INDUSTRY:
			var vals: Array = Config.get_value("economy.industry_cell_sup_per_level")
			return vals[cell.cell_level - 1]
		Cell.CellType.RESIDENTIAL:
			var vals: Array = Config.get_value("economy.residential_cell_sup_per_level")
			return vals[cell.cell_level - 1]
	return 0


func _cell_mat(cell: Cell) -> int:
	if cell.upgrade_cooldown > 0:
		return 0
	match cell.cell_type:
		Cell.CellType.INDUSTRY:
			var vals: Array = Config.get_value("economy.industry_cell_mat_per_level")
			return vals[cell.cell_level - 1]
		Cell.CellType.RESIDENTIAL:
			var vals: Array = Config.get_value("economy.residential_cell_mat_per_level")
			return vals[cell.cell_level - 1]
	return 0


# --- Costs ---

func _residential_mp_output(level: int) -> int:
	var vals: Array = Config.get_value("economy.residential_cell_mp_per_level")
	return vals[level - 1]


func _occupation_cost(cell: Cell) -> int:
	if cell.cell_type == Cell.CellType.RESIDENTIAL:
		var base := _residential_mp_output(cell.cell_level)
		if cell.owner_index == -1:
			return base
		if cell.owner_index != GameState.current_player_index:
			var mult: int = Config.get_value("occupation.enemy_residential_cost_multiplier")
			return base * mult
		return 0
	if cell.owner_index == -1:
		return Config.get_value("occupation.neutral_cost")
	if cell.owner_index != GameState.current_player_index:
		return Config.get_value("occupation.enemy_cost")
	return 0


func _raze_cost(cell: Cell) -> int:
	if cell.owner_index != -1 and cell.owner_index != GameState.current_player_index:
		return Config.get_value("raze.enemy_cost")
	return Config.get_value("raze.own_cost")


func _upgrade_cost(cell: Cell) -> Dictionary:
	if cell.cell_level >= 3 or cell.cell_type == Cell.CellType.RESOURCE:
		return {"mp": 0, "sup": 0}
	var idx := cell.cell_level - 1  # 0 = L1→2, 1 = L2→3
	if cell.cell_type == Cell.CellType.RESIDENTIAL:
		var mp_costs: Array = Config.get_value("upgrade.residential_mp_costs")
		return {"mp": mp_costs[idx], "sup": 0}
	elif cell.cell_type == Cell.CellType.INDUSTRY:
		var sup_costs: Array = Config.get_value("upgrade.industry_sup_costs")
		var mp_costs: Array = Config.get_value("upgrade.industry_mp_costs")
		return {"mp": mp_costs[idx], "sup": sup_costs[idx]}
	return {"mp": 0, "sup": 0}


func _upgrade_cost_text(cell: Cell) -> String:
	var cost := _upgrade_cost(cell)
	if cost["sup"] > 0:
		return "%d SUP / %d MP" % [cost["sup"], cost["mp"]]
	return "%d MP" % cost["mp"]


# --- Can-do checks ---

func _can_occupy(cell: Cell) -> bool:
	if _is_game_over or GameState.has_occupied_this_turn:
		return false
	if cell.raze_turns_remaining > 0:
		return false
	if cell.owner_index == GameState.current_player_index:
		return false
	if not _has_adjacent_owned(cell.grid_x, cell.grid_z, GameState.current_player_index):
		return false
	return GameState.current_player().manpower >= _occupation_cost(cell)


func _can_raze(cell: Cell) -> bool:
	return (
		not _is_game_over
		and not GameState.has_occupied_this_turn
		and cell.raze_turns_remaining == 0
		and _has_adjacent_owned(cell.grid_x, cell.grid_z, GameState.current_player_index)
		and GameState.current_player().manpower >= _raze_cost(cell)
	)


func _can_upgrade(cell: Cell) -> bool:
	if _is_game_over or GameState.has_occupied_this_turn:
		return false
	if cell.owner_index != GameState.current_player_index:
		return false
	if cell.cell_type == Cell.CellType.RESOURCE:
		return false
	if cell.cell_level >= 3:
		return false
	if cell.upgrade_cooldown > 0 or cell.raze_turns_remaining > 0:
		return false
	var cost := _upgrade_cost(cell)
	var player := GameState.current_player()
	return player.manpower >= cost["mp"] and player.supplies >= cost["sup"]


# --- Economy ---

func _calc_resource_deltas(player_idx: int) -> Dictionary:
	var connected := _get_connected_positions(player_idx)
	var mp := 0; var sup := 0; var mat := 0
	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var cell: Cell = grid[z][x]
			if cell.owner_index != player_idx or not connected.has(Vector2i(x, z)):
				continue
			mp += _cell_mp(cell)
			sup += _cell_sup(cell)
			mat += _cell_mat(cell)
	var player := GameState.players[player_idx]
	if player.supplies + sup <= 0:
		mp += Config.get_value("economy.zero_supply_mp_penalty")
	if player.materials + mat <= 0:
		mp += Config.get_value("economy.zero_material_mp_penalty")
	return {"mp": mp, "sup": sup, "mat": mat}


# Returns winner name on starvation game-over, empty string otherwise.
func _apply_turn_effects(player_idx: int) -> String:
	var player := GameState.players[player_idx]
	var connected := _get_connected_positions(player_idx)
	var residential_starved := false
	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var cell: Cell = grid[z][x]
			if cell.owner_index != player_idx or not connected.has(Vector2i(x, z)):
				continue
			# Starvation check before deducting (only active residential)
			if cell.cell_type == Cell.CellType.RESIDENTIAL and cell.upgrade_cooldown == 0:
				var sup_need := -_cell_sup(cell)
				var mat_need := -_cell_mat(cell)
				if player.supplies < sup_need or player.materials < mat_need:
					residential_starved = true
			player.manpower = max(0, player.manpower + _cell_mp(cell))
			player.supplies = max(0, player.supplies + _cell_sup(cell))
			player.materials = max(0, player.materials + _cell_mat(cell))
	if player.supplies == 0:
		player.manpower = max(0, player.manpower + Config.get_value("economy.zero_supply_mp_penalty"))
	if player.materials == 0:
		player.manpower = max(0, player.manpower + Config.get_value("economy.zero_material_mp_penalty"))
	if residential_starved:
		player.starvation_turns += 1
		var limit: int = Config.get_value("economy.starvation_turns_to_lose")
		if player.starvation_turns >= limit:
			var opp_idx := (player_idx + 1) % GameState.players.size()
			return GameState.players[opp_idx].player_name
	else:
		player.starvation_turns = 0
	return ""


func _tick_timers() -> void:
	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var cell: Cell = grid[z][x]
			if cell.raze_turns_remaining > 0:
				cell.raze_turns_remaining -= 1
				if cell.raze_turns_remaining == 0:
					cell.restore_from_raze()
			if cell.upgrade_cooldown > 0:
				cell.upgrade_cooldown -= 1


# --- Input handlers ---

func _on_cell_clicked(cell: Cell) -> void:
	if _selected_cell != null and _selected_cell != cell:
		_selected_cell.deselect()
	_selected_cell = cell
	cell.select()
	var is_adjacent := _has_adjacent_owned(cell.grid_x, cell.grid_z, GameState.current_player_index)
	var show_raze := is_adjacent or cell.raze_turns_remaining > 0
	var show_upgrade := (
		cell.cell_type != Cell.CellType.RESOURCE
		and cell.cell_level < 3
		and cell.raze_turns_remaining == 0
		and cell.owner_index == GameState.current_player_index
	)
	cell_panel.show_for_cell(
		cell,
		_can_occupy(cell), _occupation_cost(cell),
		_can_raze(cell), _raze_cost(cell), show_raze,
		_can_upgrade(cell), _upgrade_cost_text(cell), show_upgrade
	)


func _on_occupy_pressed(cell: Cell) -> void:
	var player := GameState.current_player()
	var is_enemy_residential := (
		cell.owner_index != -1
		and cell.owner_index != GameState.current_player_index
		and cell.cell_type == Cell.CellType.RESIDENTIAL
	)
	player.manpower -= _occupation_cost(cell)
	cell.claim(player)
	_selected_cell = null
	GameState.has_occupied_this_turn = true
	_update_hud()
	if is_enemy_residential:
		_is_game_over = true
		hud.show_game_over(player.player_name)


func _on_raze_pressed(cell: Cell) -> void:
	GameState.current_player().manpower -= _raze_cost(cell)
	cell.raze()
	_selected_cell = null
	GameState.has_occupied_this_turn = true
	_update_hud()


func _on_upgrade_pressed(cell: Cell) -> void:
	var cost := _upgrade_cost(cell)
	var player := GameState.current_player()
	player.manpower -= cost["mp"]
	player.supplies -= cost["sup"]
	cell.upgrade()
	_selected_cell = null
	GameState.has_occupied_this_turn = true
	_update_hud()


func _on_panel_closed() -> void:
	if _selected_cell != null:
		_selected_cell.deselect()
		_selected_cell = null


func _on_end_turn() -> void:
	if _is_game_over:
		return
	_tick_timers()
	var winner := _apply_turn_effects(GameState.current_player_index)
	if winner != "":
		_is_game_over = true
		hud.show_game_over(winner)
		return
	if _selected_cell != null:
		_selected_cell.deselect()
		_selected_cell = null
	cell_panel.hide()
	GameState.end_turn()


func _on_turn_changed(_player: PlayerData) -> void:
	camera_rig.focus_for_player(GameState.current_player_index)
	_update_hud()


func _on_resource_info_requested(which: String) -> void:
	var titles := {"mp": "Manpower / turn", "sup": "Supplies / turn", "mat": "Materials / turn"}
	hud.show_resource_info(titles.get(which, which), _compute_resource_breakdown(which))


func _compute_resource_breakdown(which: String) -> String:
	var player_idx := GameState.current_player_index
	var connected := _get_connected_positions(player_idx)
	var player := GameState.players[player_idx]

	var groups: Dictionary = {}   # label -> {total, count}
	var cell_sup_total := 0
	var cell_mat_total := 0

	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var cell: Cell = grid[z][x]
			if cell.owner_index != player_idx or not connected.has(Vector2i(x, z)):
				continue
			cell_sup_total += _cell_sup(cell)
			cell_mat_total += _cell_mat(cell)
			var amount: int
			match which:
				"mp":  amount = _cell_mp(cell)
				"sup": amount = _cell_sup(cell)
				"mat": amount = _cell_mat(cell)
				_: amount = 0
			var key := cell.level_name()
			if cell.upgrade_cooldown > 0:
				key += " (upgrading)"
			if not groups.has(key):
				groups[key] = {"total": 0, "count": 0}
			groups[key]["total"] += amount
			groups[key]["count"] += 1

	var lines: Array = []
	var running_total := 0
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var g: Dictionary = groups[key]
		var amt: int = g["total"]
		var cnt: int = g["count"]
		running_total += amt
		var amt_str := ("+" if amt >= 0 else "") + str(amt) if amt != 0 else "—"
		lines.append("  %s ×%d:  %s" % [key, cnt, amt_str])

	if which == "mp":
		var sup_pen: int = Config.get_value("economy.zero_supply_mp_penalty")
		var mat_pen: int = Config.get_value("economy.zero_material_mp_penalty")
		if player.supplies + cell_sup_total <= 0:
			running_total += sup_pen
			lines.append("  Zero supplies:   %d" % sup_pen)
		if player.materials + cell_mat_total <= 0:
			running_total += mat_pen
			lines.append("  Zero materials:  %d" % mat_pen)

	if lines.is_empty():
		return "(no connected cells)"

	var plus := "+" if running_total >= 0 else ""
	lines.append("─────────────────────")
	lines.append("  Net:  %s%d" % [plus, running_total])
	return "\n".join(lines)


func _update_hud() -> void:
	var deltas := _calc_resource_deltas(GameState.current_player_index)
	hud.update_turn(GameState.current_player().player_name)
	hud.update_resources(GameState.current_player(), deltas["mp"], deltas["sup"], deltas["mat"])
