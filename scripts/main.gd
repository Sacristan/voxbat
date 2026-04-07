extends Node3D

const GRID_SIZE := 8
const CellScene := preload("res://scenes/cell.tscn")

var grid: Array = []  # grid[z][x] -> Cell

@onready var grid_root: Node3D = $GridRoot
@onready var camera_rig = $CameraRig
@onready var hud = $HUD


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_spawn_grid()
	_place_starting_cells()
	camera_rig.fit_to_grid(GRID_SIZE)
	GameState.turn_changed.connect(func(p: PlayerData) -> void: hud.update_turn(p.player_name))
	hud.update_turn(GameState.current_player().player_name)


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
			cell.cell_clicked.connect(_on_cell_clicked)
			grid_root.add_child(cell)
			grid[z][x] = cell


func _place_starting_cells() -> void:
	grid[0][0].claim(GameState.players[0])
	grid[GRID_SIZE - 1][GRID_SIZE - 1].claim(GameState.players[1])


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


func _on_cell_clicked(cell: Cell) -> void:
	if cell.owner_index != -1:
		return
	if not _has_adjacent_owned(cell.grid_x, cell.grid_z, GameState.current_player_index):
		return
	cell.claim(GameState.current_player())
	GameState.advance_turn()
