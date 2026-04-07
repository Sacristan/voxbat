extends CanvasLayer

signal occupy_pressed(cell: Cell)
signal panel_closed

var _current_cell: Cell = null

@onready var info_label: Label = $PanelContainer/MarginContainer/VBoxContainer/InfoLabel
@onready var occupy_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/OccupyButton
@onready var close_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/TopRow/CloseButton


func _ready() -> void:
	occupy_btn.pressed.connect(_on_occupy_pressed)
	close_btn.pressed.connect(_on_close_pressed)


func show_for_cell(cell: Cell, can_occupy: bool, cost: int) -> void:
	_current_cell = cell
	info_label.text = "%s (%d, %d)" % [cell.type_name(), cell.grid_x, cell.grid_z]
	occupy_btn.text = "OCCUPY (%d MP)" % cost if cost > 0 else "OCCUPY"
	occupy_btn.disabled = not can_occupy
	show()


func _on_occupy_pressed() -> void:
	occupy_pressed.emit(_current_cell)
	_current_cell = null
	hide()


func _on_close_pressed() -> void:
	_current_cell = null
	panel_closed.emit()
	hide()
