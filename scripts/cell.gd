class_name Cell
extends StaticBody3D

enum CellType { RESOURCE, INDUSTRY, RESIDENTIAL }

signal cell_clicked(cell: Cell)

var grid_x: int = 0
var grid_z: int = 0
var owner_index: int = -1
var cell_type: CellType = CellType.RESOURCE
var cell_level: int = 1
var raze_turns_remaining: int = 0
var upgrade_cooldown: int = 0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

const TYPE_COLORS: Dictionary = {
	0: Color(0.15, 0.55, 0.15),  # RESOURCE - green
	1: Color(0.45, 0.28, 0.10),  # INDUSTRY - brown
	2: Color(0.00, 0.72, 0.82),  # RESIDENTIAL - cyan
}

const SELECTED_COLOR := Color(1.0, 0.9, 0.0)
const RAZED_COLOR    := Color(0.22, 0.20, 0.18)
const OUTLINE_GROW   := 0.08

var _fill_mat: StandardMaterial3D
var _outline_mat: StandardMaterial3D
var _level_cubes: Array = []

static var _shared_cube_mesh: BoxMesh = null
static var _shared_cube_mat: StandardMaterial3D = null


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

	_create_level_cubes()
	_update_level_visual()


func _create_level_cubes() -> void:
	if _shared_cube_mesh == null:
		_shared_cube_mesh = BoxMesh.new()
		_shared_cube_mesh.size = Vector3(0.18, 0.18, 0.18)
		_shared_cube_mat = StandardMaterial3D.new()
		_shared_cube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_cube_mat.albedo_color = Color(0.9, 0.9, 0.9)

	var offsets := [
		Vector3(-0.25, 0.54, 0.0),
		Vector3( 0.0,  0.54, 0.0),
		Vector3( 0.25, 0.54, 0.0),
	]
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = _shared_cube_mesh
		mi.material_override = _shared_cube_mat
		mi.position = offsets[i]
		mi.visible = false
		add_child(mi)
		_level_cubes.append(mi)


func _update_level_visual() -> void:
	if cell_type == CellType.RESOURCE or raze_turns_remaining > 0:
		for cube in _level_cubes:
			cube.visible = false
		return
	for i in 3:
		_level_cubes[i].visible = (i < cell_level)


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


func upgrade() -> void:
	cell_level += 1
	upgrade_cooldown = Config.get_value("economy.upgrade_cooldown_turns")
	_update_level_visual()


func raze() -> void:
	upgrade_cooldown = 0
	owner_index = -1
	match cell_type:
		CellType.RESOURCE:    raze_turns_remaining = Config.get_value("raze.resource_rubble_turns")
		CellType.INDUSTRY:    raze_turns_remaining = Config.get_value("raze.industry_rubble_turns")
		CellType.RESIDENTIAL: raze_turns_remaining = Config.get_value("raze.residential_rubble_turns")
	_fill_mat.albedo_color = RAZED_COLOR
	_outline_mat.grow_amount = 0.0
	_update_level_visual()


func restore_from_raze() -> void:
	raze_turns_remaining = 0
	_fill_mat.albedo_color = TYPE_COLORS[cell_type]
	_update_level_visual()


func level_name() -> String:
	match cell_type:
		CellType.RESOURCE: return "Resource"
		CellType.INDUSTRY:
			match cell_level:
				1: return "Workshop"
				2: return "Factory"
				3: return "Industrial Complex"
		CellType.RESIDENTIAL:
			match cell_level:
				1: return "Village"
				2: return "Town"
				3: return "Metropolis"
	return "Unknown"


func display_name() -> String:
	if raze_turns_remaining > 0:
		return "Rubble (%d turns)" % raze_turns_remaining
	if upgrade_cooldown > 0:
		return "%s (upgrading: %d)" % [level_name(), upgrade_cooldown]
	return level_name()
