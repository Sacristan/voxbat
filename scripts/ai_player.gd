class_name AiPlayer
extends Node

const THINK_DELAY := 0.6
const SCORE_JITTER := 8.0

const S_OCCUPY_NEUTRAL_RESOURCE    := 15.0
const S_OCCUPY_NEUTRAL_INDUSTRY    := 30.0
const S_OCCUPY_NEUTRAL_RESIDENTIAL := 25.0
const S_OCCUPY_ENEMY_RESOURCE      := 35.0
const S_OCCUPY_ENEMY_INDUSTRY      := 75.0
const S_OCCUPY_ENEMY_RESIDENTIAL   := 70.0
const S_OCCUPY_ENEMY_BASE          := 200.0
const S_UPGRADE_PER_LEVEL          := 30.0
const S_UPGRADE_RESIDENTIAL_BONUS  := 10.0
const S_BUILD_RESIDENTIAL          := 22.0
const S_BUILD_INDUSTRIAL           := 20.0
const S_MOBILIZE_BASE              := 0.9

const MIN_RAW_RESOURCES            := 2

const NEED_COMFORTABLE := 50
const NEED_SCARCE      := 20
const NEED_MAX_FACTOR  := 3.5

# Own-raze: only fire when at least one resource is in this need bracket or above
const OWN_RAZE_MIN_NEED   := 2.5
const OWN_RAZE_THRESHOLD  := 20.0
const SUSTAIN_PENALTY_RATE := 0.15

const PERSONALITIES: Dictionary = {
	"expansionist": { "occupy_neutral": 1.2, "occupy_enemy": 1.0, "upgrade": 0.4, "build": 0.6, "industry_bonus": 1.0, "proximity_bonus": 0.0 },
	"builder":      { "occupy_neutral": 0.8, "occupy_enemy": 0.7, "upgrade": 1.4, "build": 1.8, "industry_bonus": 1.0, "proximity_bonus": 0.0 },
	"economist":    { "occupy_neutral": 0.9, "occupy_enemy": 0.6, "upgrade": 1.2, "build": 1.5, "industry_bonus": 1.6, "proximity_bonus": 0.0 },
	"aggressor":    { "occupy_neutral": 0.5, "occupy_enemy": 2.5, "upgrade": 0.3, "build": 0.35, "industry_bonus": 1.0, "proximity_bonus": 1.5 },
}
const PERSONALITY_NAMES: Array = ["expansionist", "builder", "economist", "aggressor"]

var _main
var _personalities: Array = []
var _pnames: Array = []


func setup(main_node) -> void:
	randomize()
	_main = main_node
	var cfg: Array = Config.get_value("ai.player_personalities")
	for i in GameState.players.size():
		var pname: String = cfg[i] if i < cfg.size() else "random"
		if pname == "random" or not PERSONALITIES.has(pname):
			pname = PERSONALITY_NAMES[randi() % PERSONALITY_NAMES.size()]
		_personalities.append(PERSONALITIES[pname])
		_pnames.append(pname)
		print("AI Player %d (%s): %s" % [i, GameState.players[i].player_name, pname])


func take_turn() -> void:
	await get_tree().create_timer(THINK_DELAY).timeout
	_try_action()
	await get_tree().create_timer(THINK_DELAY).timeout
	_main.game_net.handle_end_turn()


func _try_action() -> void:
	var p: Dictionary = _personalities[GameState.current_player_index]
	var needs: Dictionary = _resource_needs()
	var player: PlayerData = GameState.current_player()
	var candidates: Array = []
	_collect_occupy(candidates, p, needs, player)
	_collect_upgrades(candidates, p, needs)
	_collect_builds(candidates, p, needs)
	_collect_razes(candidates, p, needs, player)
	_collect_mobilizes(candidates, needs)
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
		var dbg: PlayerData = GameState.current_player()
		print("AI %s [%s]: %s '%s'L%d@[%d,%d] MP:%d SUP:%d MAT:%d n=%.1f/%.1f/%.1f" % [
			dbg.player_name, _pnames[GameState.current_player_index].substr(0, 3),
			best_action, best_cell.level_name(), best_cell.cell_level,
			best_cell.grid_x, best_cell.grid_z,
			dbg.manpower, dbg.supplies, dbg.materials,
			needs["mp"], needs["sup"], needs["mat"]])
		_main.game_net.handle_action(best_action, best_cell)


# --- Resource need helpers ---

func _resource_needs() -> Dictionary:
	var idx: int = GameState.current_player_index
	var player: PlayerData = GameState.current_player()
	var deltas: Dictionary = _main._calc_resource_deltas(idx)
	return {
		"mp":  _need_factor(player.manpower  + deltas["mp"] + _pending_mobilize_mp(idx)),
		"sup": _need_factor(player.supplies  + deltas["sup"]),
		"mat": _need_factor(player.materials + deltas["mat"]),
	}


func _pending_mobilize_mp(player_idx: int) -> int:
	var total: int = 0
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if cell.mobilize_owner_index == player_idx and cell.mobilize_turns_remaining > 0:
				total += cell.mobilize_mp_pending
	return total


func _need_factor(projected: int) -> float:
	if projected >= NEED_COMFORTABLE:
		return 1.0
	if projected >= NEED_SCARCE:
		return 1.0 + float(NEED_COMFORTABLE - projected) / float(NEED_COMFORTABLE - NEED_SCARCE)
	return 2.0 + float(NEED_SCARCE - max(projected, 0)) / float(NEED_SCARCE) * (NEED_MAX_FACTOR - 2.0)


func _cell_need(cell: Cell, needs: Dictionary) -> float:
	match cell.cell_type:
		Cell.CellType.RESIDENTIAL: return needs["mp"]
		Cell.CellType.INDUSTRY:    return needs["mat"]
		_:                         return needs["sup"]


# Penalty for the current drain a cell imposes (used for occupation).
func _sustain_penalty(sup_drain: float, mat_drain: float, needs: Dictionary) -> float:
	var penalty: float = 1.0
	if sup_drain > 0.0:
		penalty *= 1.0 / (1.0 + sup_drain * needs["sup"] * SUSTAIN_PENALTY_RATE)
	if mat_drain > 0.0:
		penalty *= 1.0 / (1.0 + mat_drain * needs["mat"] * SUSTAIN_PENALTY_RATE)
	return penalty


# --- Candidate collectors ---

func _collect_occupy(candidates: Array, p: Dictionary, needs: Dictionary, player: PlayerData) -> void:
	var ind_bonus: float = p["industry_bonus"]
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if not _main._can_occupy(cell):
				continue
			var score: float = _occupy_score(cell, p, ind_bonus, needs)
			# Penalise by drain the new cell would impose on our economy
			var sup_drain: float = maxf(0.0, -float(_main._cell_sup(cell)))
			var mat_drain: float = maxf(0.0, -float(_main._cell_mat(cell)))
			score *= _sustain_penalty(sup_drain, mat_drain, needs)
			# Discount if occupation costs more than half remaining MP
			if player.manpower > 0:
				var strain: float = float(_main._occupation_cost(cell)) / float(player.manpower)
				score *= clampf(1.0 - (strain - 0.5) * 0.8, 0.3, 1.0)
			candidates.append([score, "occupy", cell])


func _occupy_score(cell: Cell, p: Dictionary, ind_bonus: float, needs: Dictionary) -> float:
	var is_enemy: bool = cell.owner_index != -1
	var need: float = _cell_need(cell, needs)
	var contest_factor: float = 0.0 if cell.contested_turns >= 3 else 1.0 / (1.0 + cell.contested_turns * 1.5)
	var proximity_factor: float = 1.0
	if p["proximity_bonus"] > 0.0:
		var enemy_idx: int = (GameState.current_player_index + 1) % GameState.players.size()
		var ebase: Vector2i = _main._start_positions[enemy_idx]
		var dist: float = maxf(abs(cell.grid_x - ebase.x), abs(cell.grid_z - ebase.y))
		proximity_factor = 1.0 + p["proximity_bonus"] * clampf(1.0 - dist / 8.0, 0.0, 1.0)
	if is_enemy and _main._start_positions[cell.owner_index] == Vector2i(cell.grid_x, cell.grid_z):
		return S_OCCUPY_ENEMY_BASE * contest_factor * proximity_factor
	if is_enemy:
		match cell.cell_type:
			Cell.CellType.RESIDENTIAL: return S_OCCUPY_ENEMY_RESIDENTIAL * p["occupy_enemy"] * need * contest_factor * proximity_factor
			Cell.CellType.INDUSTRY:    return S_OCCUPY_ENEMY_INDUSTRY    * p["occupy_enemy"] * ind_bonus * need * contest_factor * proximity_factor
			_:                         return S_OCCUPY_ENEMY_RESOURCE    * p["occupy_enemy"] * ind_bonus * need * contest_factor * proximity_factor
	else:
		match cell.cell_type:
			Cell.CellType.RESIDENTIAL: return S_OCCUPY_NEUTRAL_RESIDENTIAL * p["occupy_neutral"] * need
			Cell.CellType.INDUSTRY:    return S_OCCUPY_NEUTRAL_INDUSTRY    * p["occupy_neutral"] * ind_bonus * need
			_:                         return S_OCCUPY_NEUTRAL_RESOURCE    * p["occupy_neutral"] * ind_bonus * need


func _collect_upgrades(candidates: Array, p: Dictionary, needs: Dictionary) -> void:
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if not _main._can_upgrade(cell):
				continue
			var base: float = S_UPGRADE_PER_LEVEL * cell.cell_level
			if cell.cell_type == Cell.CellType.RESIDENTIAL:
				base += S_UPGRADE_RESIDENTIAL_BONUS
			var need: float = _cell_need(cell, needs)
			# Penalise based on ADDITIONAL drain the next level adds, not the current drain
			var delta: Dictionary = _upgrade_drain_delta(cell)
			var penalty: float = _sustain_penalty(
				maxf(0.0, -float(delta["sup"])),
				maxf(0.0, -float(delta["mat"])),
				needs)
			candidates.append([base * p["upgrade"] * need * penalty, "upgrade", cell])


# Returns the per-turn resource delta change (next_level - current_level) for an upgrade.
func _upgrade_drain_delta(cell: Cell) -> Dictionary:
	var nl: int = cell.cell_level + 1
	var cl: int = cell.cell_level
	var d_sup: int = 0
	var d_mat: int = 0
	if cell.cell_type == Cell.CellType.RESIDENTIAL:
		var sup_vals: Array = Config.get_value("economy.residential_cell_sup_per_level")
		var mat_vals: Array = Config.get_value("economy.residential_cell_mat_per_level")
		if nl - 1 < sup_vals.size():
			d_sup = int(sup_vals[nl - 1]) - int(sup_vals[cl - 1])
		if nl - 1 < mat_vals.size():
			d_mat = int(mat_vals[nl - 1]) - int(mat_vals[cl - 1])
	elif cell.cell_type == Cell.CellType.INDUSTRY:
		var sup_vals: Array = Config.get_value("economy.industry_cell_sup_per_level")
		if nl - 1 < sup_vals.size():
			d_sup = int(sup_vals[nl - 1]) - int(sup_vals[cl - 1])
	return {"sup": d_sup, "mat": d_mat}


func _collect_builds(candidates: Array, p: Dictionary, needs: Dictionary) -> void:
	var ind_bonus: float = p["industry_bonus"]
	var idx: int = GameState.current_player_index
	var raw_count: int = 0
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if cell.owner_index == idx and cell.cell_type == Cell.CellType.RESOURCE:
				raw_count += 1
	if raw_count <= MIN_RAW_RESOURCES:
		return
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if _main._can_convert(cell, Cell.CellType.RESIDENTIAL):
				var penalty: float = _build_net_sustain(cell, Cell.CellType.RESIDENTIAL, needs)
				candidates.append([S_BUILD_RESIDENTIAL * p["build"] * needs["mp"] * penalty, "build_residential", cell])
			if _main._can_convert(cell, Cell.CellType.INDUSTRY):
				var penalty: float = _build_net_sustain(cell, Cell.CellType.INDUSTRY, needs)
				candidates.append([S_BUILD_INDUSTRIAL * p["build"] * ind_bonus * needs["mat"] * penalty, "build_industrial", cell])


# Sustainability penalty for converting a cell: accounts for both the old income lost and new drain added.
func _build_net_sustain(old_cell: Cell, new_type: Cell.CellType, needs: Dictionary) -> float:
	var old_sup: int = _main._cell_sup(old_cell)
	var old_mat: int = _main._cell_mat(old_cell)
	var new_sup: int = 0
	var new_mat: int = 0
	if new_type == Cell.CellType.RESIDENTIAL:
		new_sup = int((Config.get_value("economy.residential_cell_sup_per_level") as Array)[0])
		new_mat = int((Config.get_value("economy.residential_cell_mat_per_level") as Array)[0])
	else:
		new_sup = int((Config.get_value("economy.industry_cell_sup_per_level") as Array)[0])
		new_mat = int((Config.get_value("economy.industry_cell_mat_per_level") as Array)[0])
	# Positive = we're losing supply/mat income (net drain increases)
	var net_sup_drain: float = maxf(0.0, float(old_sup) - float(new_sup))
	var net_mat_drain: float = maxf(0.0, float(old_mat) - float(new_mat))
	return _sustain_penalty(net_sup_drain, net_mat_drain, needs)


func _collect_razes(candidates: Array, p: Dictionary, needs: Dictionary, player: PlayerData) -> void:
	var idx: int = GameState.current_player_index
	var max_need: float = maxf(needs["mp"], maxf(needs["sup"], needs["mat"]))
	var urgency: float = 1.0 + float(player.starvation_turns) * 2.0
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if not _main._can_raze(cell):
				continue
			if cell.owner_index == idx:
				# Never raze the starting base — it's the win-condition cell
				if _main._start_positions[idx] == Vector2i(cell.grid_x, cell.grid_z):
					continue
				# Only consider own-raze when at least one resource is critically low
				if max_need < OWN_RAZE_MIN_NEED:
					continue
				var score: float = _own_raze_score(cell, needs) * urgency
				if score > OWN_RAZE_THRESHOLD:
					candidates.append([score, "raze", cell])
			else:
				# Don't raze neutral cells we could just occupy — that's always better
				if cell.owner_index == -1 and _main._can_occupy(cell):
					continue
				candidates.append([_enemy_raze_score(cell, p), "raze", cell])


func _collect_mobilizes(candidates: Array, needs: Dictionary) -> void:
	for row in _main.grid:
		for c in row:
			var cell: Cell = c as Cell
			if not _main._can_mobilize(cell):
				continue
			var mp_yields: Array = Config.get_value("mobilize.residential_mp_yields")
			var mp_yield: float = float(mp_yields[cell.cell_level - 1])
			# Attractive when MP is scarce; discounted when MAT is already scarce
			var score: float = mp_yield * needs["mp"] * S_MOBILIZE_BASE / maxf(1.0, needs["mat"])
			candidates.append([score, "mobilize", cell])


func _own_raze_score(cell: Cell, needs: Dictionary) -> float:
	var sup_drain: float = maxf(0.0, -float(_main._cell_sup(cell)))
	var mat_drain: float = maxf(0.0, -float(_main._cell_mat(cell)))
	var mp_drain:  float = maxf(0.0, -float(_main._cell_mp(cell)))
	var score: float = 0.0
	score += sup_drain * maxf(0.0, needs["sup"] - 1.0) * 3.0
	score += mat_drain * maxf(0.0, needs["mat"] - 1.0) * 3.0
	score += mp_drain  * maxf(0.0, needs["mp"]  - 1.0) * 2.0
	return score


func _enemy_raze_score(cell: Cell, p: Dictionary) -> float:
	var sup_yield: float = maxf(0.0, float(_main._cell_sup(cell)))
	var mat_yield: float = maxf(0.0, float(_main._cell_mat(cell)))
	var mp_yield:  float = maxf(0.0, float(_main._cell_mp(cell)))
	var value: float = sup_yield * 3.0 + mat_yield * 2.5 + mp_yield * 2.0
	return value * p["occupy_enemy"] * 0.6
