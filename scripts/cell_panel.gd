extends CanvasLayer

signal occupy_pressed(cell: Cell)
signal raze_pressed(cell: Cell)
signal upgrade_pressed(cell: Cell)
signal panel_closed

var _current_cell: Cell = null

@onready var info_label: Label = $PanelContainer/MarginContainer/VBoxContainer/InfoLabel
@onready var occupy_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/OccupyButton
@onready var raze_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/RazeButton
@onready var upgrade_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/UpgradeButton
@onready var close_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/TopRow/CloseButton


func _ready() -> void:
	occupy_btn.pressed.connect(_on_occupy_pressed)
	raze_btn.pressed.connect(_on_raze_pressed)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	close_btn.pressed.connect(_on_close_pressed)


func show_for_cell(
		cell: Cell,
		can_occupy: bool, occupy_cost: int,
		can_raze: bool, raze_cost: int, show_raze: bool,
		can_upgrade: bool, upgrade_cost_text: String, show_upgrade: bool
) -> void:
	_current_cell = cell
	var q: int = cell.grid_x
	var r: int = cell.grid_z - (cell.grid_x - (cell.grid_x & 1)) / 2
	var s: int = -q - r
	info_label.text = "%s (%d, %d, %d)" % [cell.display_name(), q, r, s]
	occupy_btn.text = "OCCUPY (%d MP)" % occupy_cost if occupy_cost > 0 else "OCCUPY"
	occupy_btn.disabled = not can_occupy
	raze_btn.text = "RAZE (%d MP)" % raze_cost
	raze_btn.visible = show_raze
	raze_btn.disabled = not can_raze
	upgrade_btn.text = "UPGRADE (%s)" % upgrade_cost_text
	upgrade_btn.visible = show_upgrade
	upgrade_btn.disabled = not can_upgrade
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


func _on_close_pressed() -> void:
	_current_cell = null
	panel_closed.emit()
	hide()
