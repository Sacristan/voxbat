class_name Cell
extends StaticBody3D

enum CellType { RESOURCE, INDUSTRY, RESIDENTIAL }

signal cell_clicked(cell: Cell)

var grid_x: int = 0
var grid_z: int = 0
var owner_index: int = -1
var cell_type: CellType = CellType.RESOURCE

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

const TYPE_COLORS: Dictionary = {
	0: Color(0.15, 0.55, 0.15),  # RESOURCE - green
	1: Color(0.45, 0.28, 0.10),  # INDUSTRY - brown
	2: Color(0.00, 0.72, 0.82),  # RESIDENTIAL - cyan
}

const SELECTED_COLOR := Color(1.0, 0.9, 0.0)
const OUTLINE_GROW := 0.08

var _fill_mat: StandardMaterial3D
var _outline_mat: StandardMaterial3D


func _ready() -> void:
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.albedo_color = TYPE_COLORS[cell_type]

	_outline_mat = StandardMaterial3D.new()
	_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mat.grow = true
	_outline_mat.grow_amount = 0.0
	_outline_mat.albedo_color = Color.WHITE

	_fill_mat.next_pass = _outline_mat
	mesh_instance.set_surface_override_material(0, _fill_mat)


func _input_event(_camera: Camera3D, event: InputEvent,
		_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			cell_clicked.emit(self)


func select() -> void:
	_outline_mat.grow_amount = OUTLINE_GROW
	_outline_mat.albedo_color = SELECTED_COLOR


func deselect() -> void:
	if owner_index == -1:
		_outline_mat.grow_amount = 0.0
	else:
		_outline_mat.grow_amount = OUTLINE_GROW
		_outline_mat.albedo_color = GameState.players[owner_index].color


func claim(player: PlayerData) -> void:
	owner_index = GameState.players.find(player)
	_fill_mat.albedo_color = TYPE_COLORS[cell_type]
	_outline_mat.grow_amount = OUTLINE_GROW
	_outline_mat.albedo_color = player.color


func type_name() -> String:
	match cell_type:
		CellType.RESOURCE: return "Resource"
		CellType.INDUSTRY: return "Industry"
		CellType.RESIDENTIAL: return "Residential"
	return "Unknown"
