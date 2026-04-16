extends CanvasLayer

signal occupy_pressed(cell: Cell)
signal raze_pressed(cell: Cell)
signal upgrade_pressed(cell: Cell)
signal build_residential_pressed(cell: Cell)
signal build_industrial_pressed(cell: Cell)
signal panel_closed

var _current_cell: Cell = null

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TopRow/TitleLabel
@onready var coords_label: Label = $PanelContainer/MarginContainer/VBoxContainer/CoordsLabel
@onready var economy_label: Label = $PanelContainer/MarginContainer/VBoxContainer/EconomyLabel
@onready var occupy_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/OccupyButton
@onready var raze_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/RazeButton
@onready var upgrade_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/UpgradeButton
@onready var build_residential_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/BuildResidentialButton
@onready var build_industrial_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/BuildIndustrialButton
@onready var close_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/TopRow/CloseButton


func _ready() -> void:
	occupy_btn.pressed.connect(_on_occupy_pressed)
	raze_btn.pressed.connect(_on_raze_pressed)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	build_residential_btn.pressed.connect(_on_build_residential_pressed)
	build_industrial_btn.pressed.connect(_on_build_industrial_pressed)
	close_btn.pressed.connect(_on_close_pressed)

func show_for_cell(
		cell: Cell,
		can_occupy: bool, occupy_cost: int,
		can_raze: bool, raze_cost: int, raze_yield_text: String, show_raze: bool,
		can_upgrade: bool, upgrade_cost_text: String, show_upgrade: bool,
		can_build_residential: bool, residential_cost_text: String, show_build: bool,
		can_build_industrial: bool, industrial_cost_text: String
) -> void:
	_current_cell = cell
	var q: int = cell.grid_x
	var r: int = cell.grid_z - (cell.grid_x - (cell.grid_x & 1)) / 2
	var s: int = -q - r
	coords_label.text = "(%d, %d, %d)" % [q, r, s]
	economy_label.text = cell.economy_text()
	var ctype: String
	match cell.cell_type:
		Cell.CellType.RESOURCE:    ctype = "Resource"
		Cell.CellType.INDUSTRY:    ctype = "Industry"
		Cell.CellType.RESIDENTIAL: ctype = "Residential"
		_:                         ctype = ""
	if cell.raze_turns_remaining > 0:
		title_label.text = "Rubble (%d), %s" % [cell.raze_turns_remaining, ctype]
	elif cell.cell_type == Cell.CellType.RESOURCE:
		title_label.text = "Resource"
	else:
		title_label.text = "%s, %s (LVL%d)" % [cell.level_name(), ctype, cell.cell_level]
		if cell.upgrade_cooldown > 0:
			title_label.text += " ↑%d" % cell.upgrade_cooldown
	occupy_btn.text = "OCCUPY (%d MP)" % occupy_cost if occupy_cost > 0 else "OCCUPY"
	occupy_btn.disabled = not can_occupy
	var raze_cost_text := "RAZE (%d MP)" % raze_cost if raze_cost > 0 else "RAZE (free)"
	raze_btn.text = "%s → %s" % [raze_cost_text, raze_yield_text]
	raze_btn.visible = show_raze
	raze_btn.disabled = not can_raze
	upgrade_btn.text = "UPGRADE (%s)" % upgrade_cost_text
	upgrade_btn.visible = show_upgrade
	upgrade_btn.disabled = not can_upgrade
	build_residential_btn.text = "BUILD RESIDENTIAL (%s)" % residential_cost_text
	build_residential_btn.visible = show_build
	build_residential_btn.disabled = not can_build_residential
	build_industrial_btn.text = "BUILD INDUSTRIAL (%s)" % industrial_cost_text
	build_industrial_btn.visible = show_build
	build_industrial_btn.disabled = not can_build_industrial
	show()


func _on_occupy_pressed() -> void:
	occupy_pressed.emit(_current_cell)
	_current_cell = null
	hide()


func _on_raze_pressed() -> void:
	raze_pressed.emit(_current_cell)
	_current_cell = null
	hide()


func _on_upgrade_pressed() -> void:
	upgrade_pressed.emit(_current_cell)
	_current_cell = null
	hide()


func _on_build_residential_pressed() -> void:
	build_residential_pressed.emit(_current_cell)
	_current_cell = null
	hide()


func _on_build_industrial_pressed() -> void:
	build_industrial_pressed.emit(_current_cell)
	_current_cell = null
	hide()


func _on_close_pressed() -> void:
	_current_cell = null
	panel_closed.emit()
	hide()
