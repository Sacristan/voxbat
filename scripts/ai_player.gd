class_name AiPlayer
extends Node

const THINK_DELAY := 0.6
const SCORE_JITTER := 8.0

# Base scores — personalities multiply these to shift priorities
const S_OCCUPY_NEUTRAL_RESOURCE    := 15.0
const S_OCCUPY_NEUTRAL_INDUSTRY    := 20.0
const S_OCCUPY_NEUTRAL_RESIDENTIAL := 25.0
const S_OCCUPY_ENEMY_RESOURCE      := 35.0
const S_OCCUPY_ENEMY_INDUSTRY      := 45.0
const S_OCCUPY_ENEMY_RESIDENTIAL   := 55.0
const S_OCCUPY_ENEMY_BASE          := 200.0  # always dominant
const S_UPGRADE_PER_LEVEL          := 30.0   # multiplied by current level
const S_UPGRADE_RESIDENTIAL_BONUS  := 10.0
const S_BUILD_RESIDENTIAL          := 35.0
const S_BUILD_INDUSTRIAL           := 20.0

# Weights: occupy_neutral, occupy_enemy, upgrade, build, industry_bonus
const PERSONALITIES: Dictionary = {
	"expansionist": { "occupy_neutral": 1.2, "occupy_enemy": 1.0, "upgrade": 0.4, "build": 0.6, "industry_bonus": 1.0 },
	"builder":      { "occupy_neutral": 0.5, "occupy_enemy": 0.7, "upgrade": 2.0, "build": 1.8, "industry_bonus": 1.0 },
	"economist":    { "occupy_neutral": 0.9, "occupy_enemy": 0.6, "upgrade": 1.2, "build": 1.5, "industry_bonus": 1.6 },
	"aggressor":    { "occupy_neutral": 0.2, "occupy_enemy": 2.5, "upgrade": 0.2, "build": 0.1, "industry_bonus": 1.0 },
}
const PERSONALITY_NAMES: Array = ["expansionist", "builder", "economist", "aggressor"]

var _main
var _personalities: Array = []


func setup(main_node) -> void:
	_main = main_node
	var cfg: Array = Config.get_value("ai.player_personalities")
	for i in GameState.players.size():
		var pname: String = cfg[i] if i < cfg.size() else "random"
		if pname == "random" or not PERSONALITIES.has(pname):
			pname = PERSONALITY_NAMES[randi() % PERSONALITY_NAMES.size()]
		_personalities.append(PERSONALITIES[pname])
		print("AI Player %d (%s): %s" % [i, GameState.players[i].player_name, pname])


func take_turn() -> void:
	await get_tree().create_timer(THINK_DELAY).timeout
	_try_action()
	await get_tree().create_timer(THINK_DELAY).timeout
	_main.game_net.handle_end_turn()


func _try_action() -> void:
	var p: Dictionary = _personalities[GameState.current_player_index]
	var candidates: Array = []
	_collect_occupy(candidates, p)
	_collect_upgrades(candidates, p)
	_collect_builds(candidates, p)
	if candidates.is_empty():
		return
	candidates.shuffle()
	var best_score: float = -1.0
	var best_action: String = ""
	var best_cell: Cell = null
	for entry in candidates:
		var score: float = float(entry[0]) + randf() * SCORE_JITTER
		if score > best_score:
			best_score = score
			best_action = entry[1]
			best_cell = entry[2]
	if best_cell:
		_main.game_net.handle_action(best_action, best_cell)


func _collect_occupy(candidates: Array, p: Dictionary) -> void:
	var ind_bonus: float = p["industry_bonus"]
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if not _main._can_occupy(cell):
				continue
			candidates.append([_occupy_score(cell, p, ind_bonus), "occupy", cell])


func _occupy_score(cell: Cell, p: Dictionary, ind_bonus: float) -> float:
	var is_enemy: bool = cell.owner_index != -1
	if is_enemy and _main._start_positions[cell.owner_index] == Vector2i(cell.grid_x, cell.grid_z):
		return S_OCCUPY_ENEMY_BASE
	if is_enemy:
		match cell.cell_type:
			Cell.CellType.RESIDENTIAL: return S_OCCUPY_ENEMY_RESIDENTIAL * p["occupy_enemy"]
			Cell.CellType.INDUSTRY:    return S_OCCUPY_ENEMY_INDUSTRY    * p["occupy_enemy"] * ind_bonus
			_:                         return S_OCCUPY_ENEMY_RESOURCE    * p["occupy_enemy"] * ind_bonus
	else:
		match cell.cell_type:
			Cell.CellType.RESIDENTIAL: return S_OCCUPY_NEUTRAL_RESIDENTIAL * p["occupy_neutral"]
			Cell.CellType.INDUSTRY:    return S_OCCUPY_NEUTRAL_INDUSTRY    * p["occupy_neutral"] * ind_bonus
			_:                         return S_OCCUPY_NEUTRAL_RESOURCE    * p["occupy_neutral"] * ind_bonus


func _collect_upgrades(candidates: Array, p: Dictionary) -> void:
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if not _main._can_upgrade(cell):
				continue
			var base: float = S_UPGRADE_PER_LEVEL * cell.cell_level
			if cell.cell_type == Cell.CellType.RESIDENTIAL:
				base += S_UPGRADE_RESIDENTIAL_BONUS
			candidates.append([base * p["upgrade"], "upgrade", cell])


func _collect_builds(candidates: Array, p: Dictionary) -> void:
	var ind_bonus: float = p["industry_bonus"]
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if _main._can_convert(cell, Cell.CellType.RESIDENTIAL):
				candidates.append([S_BUILD_RESIDENTIAL * p["build"], "build_residential", cell])
			if _main._can_convert(cell, Cell.CellType.INDUSTRY):
				candidates.append([S_BUILD_INDUSTRIAL * p["build"] * ind_bonus, "build_industrial", cell])
