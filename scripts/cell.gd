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
var raze_player_index: int = -1
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

const _CELL_SHADER := preload("res://shaders/cell.gdshader")

var _fill_mat: ShaderMaterial
var _outline_mat: StandardMaterial3D
var _level_cubes: Array = []
var _shortage_overlay: MeshInstance3D
var _shortage_label: Label3D
var _shortage_mat: StandardMaterial3D
var _shortage_tween: Tween
var _is_shortage: bool = false

var _upgrading_label: Label3D
var _upgrading_cube_tween: Tween

static var _slice_meshes: Array = []


func _ready() -> void:
	_fill_mat = ShaderMaterial.new()
	_fill_mat.shader = _CELL_SHADER
	_fill_mat.set_shader_parameter("albedo_color", TYPE_COLORS[cell_type])

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
	_create_shortage_indicator()
	_create_upgrading_indicator()


func _create_level_cubes() -> void:
	if _slice_meshes.is_empty():
		# Decreasing radius bottom→top: 80%, 60%, 40%, 20% of visual hex radius (0.5312)
		for r in [0.4249, 0.3187, 0.2125, 0.1063]:
			var m := CylinderMesh.new()
			m.top_radius = r
			m.bottom_radius = r
			m.height = 0.10
			m.radial_segments = 6
			m.rings = 1
			_slice_meshes.append(m)

	# Per-instance materials so color matches cell type; half-transparent
	var base: Color = TYPE_COLORS[cell_type]
	var slice_color := Color(base.r, base.g, base.b, 0.5)

	# Stacked above cell top (y=0.45), 0.10 tall slices with 0.06 gap
	var offsets := [
		Vector3(0.0, 0.50, 0.0),
		Vector3(0.0, 0.66, 0.0),
		Vector3(0.0, 0.82, 0.0),
		Vector3(0.0, 0.98, 0.0),
	]
	for i in 4:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = slice_color
		var mi := MeshInstance3D.new()
		mi.mesh = _slice_meshes[i]
		mi.material_override = mat
		mi.position = offsets[i]
		mi.visible = false
		add_child(mi)
		_level_cubes.append(mi)


func _update_level_visual() -> void:
	if cell_type == CellType.RESOURCE:
		for cube in _level_cubes:
			cube.visible = false
		return
	for i in _level_cubes.size():
		_level_cubes[i].visible = (i < cell_level)


func _create_shortage_indicator() -> void:
	_shortage_mat = StandardMaterial3D.new()
	_shortage_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shortage_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shortage_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.0)
	_shortage_mat.render_priority = 1

	var plane := PlaneMesh.new()
	plane.size = Vector2(0.88, 0.88)

	_shortage_overlay = MeshInstance3D.new()
	_shortage_overlay.mesh = plane
	_shortage_overlay.material_override = _shortage_mat
	_shortage_overlay.position = Vector3(0.0, 0.46, 0.0)
	_shortage_overlay.visible = false
	add_child(_shortage_overlay)

	_shortage_label = Label3D.new()
	_shortage_label.text = "Shortage"
	_shortage_label.font_size = 28
	_shortage_label.modulate = Color(1.0, 0.15, 0.15)
	_shortage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_shortage_label.no_depth_test = true
	_shortage_label.position = Vector3(0.0, 1.3, 0.0)
	_shortage_label.visible = false
	add_child(_shortage_label)


func set_shortage(active: bool, shortage_text: String = "") -> void:
	if active == _is_shortage and (not active or _shortage_label.text == shortage_text):
		return
	_is_shortage = active
	_shortage_overlay.visible = active
	_shortage_label.visible = active
	_shortage_label.text = shortage_text
	if active:
		if _shortage_tween == null or not _shortage_tween.is_valid():
			_shortage_tween = create_tween()
			_shortage_tween.set_loops()
			_shortage_tween.tween_method(_set_shortage_alpha, 0.0, 0.55, 0.9)
			_shortage_tween.tween_method(_set_shortage_alpha, 0.55, 0.0, 0.9)
	else:
		if _shortage_tween != null:
			_shortage_tween.kill()
			_shortage_tween = null
		_shortage_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.0)


func _set_shortage_alpha(alpha: float) -> void:
	_shortage_mat.albedo_color = Color(1.0, 0.0, 0.0, alpha)


func _create_upgrading_indicator() -> void:
	_upgrading_label = Label3D.new()
	_upgrading_label.text = "Upgrading"
	_upgrading_label.font_size = 28
	_upgrading_label.modulate = Color(0.0, 1.0, 1.0)
	_upgrading_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_upgrading_label.no_depth_test = true
	_upgrading_label.position = Vector3(0.0, 1.6, 0.0)
	_upgrading_label.visible = false
	add_child(_upgrading_label)


func set_upgrading(active: bool) -> void:
	_upgrading_label.visible = active
	if _upgrading_cube_tween != null:
		_upgrading_cube_tween.kill()
		_upgrading_cube_tween = null
	if active and cell_level >= 1 and cell_level <= _level_cubes.size():
		var top_cube: MeshInstance3D = _level_cubes[cell_level - 1]
		_upgrading_cube_tween = create_tween()
		_upgrading_cube_tween.set_loops()
		_upgrading_cube_tween.tween_property(top_cube.material_override, "albedo_color:a", 1.0, 1.2).from(0.0)
		_upgrading_cube_tween.tween_property(top_cube.material_override, "albedo_color:a", 0.0, 1.2)
	else:
		# Restore normal alpha on the cube that was flashing
		if cell_level >= 1 and cell_level <= _level_cubes.size():
			var top_cube: MeshInstance3D = _level_cubes[cell_level - 1]
			var c: Color = top_cube.material_override.albedo_color
			top_cube.material_override.albedo_color = Color(c.r, c.g, c.b, 0.5)


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
	_fill_mat.set_shader_parameter("albedo_color", TYPE_COLORS[cell_type])
	_outline_mat.grow_amount = OUTLINE_GROW
	_outline_mat.albedo_color = player.color


func upgrade() -> void:
	cell_level += 1
	upgrade_cooldown = Config.get_value("economy.upgrade_cooldown_turns")
	_update_level_visual()
	set_upgrading(true)


func convert_to(new_type: CellType) -> void:
	cell_type = new_type
	cell_level = 1
	upgrade_cooldown = Config.get_value("economy.upgrade_cooldown_turns")
	_fill_mat.set_shader_parameter("albedo_color", TYPE_COLORS[cell_type])
	var slice_color := Color(TYPE_COLORS[cell_type].r, TYPE_COLORS[cell_type].g, TYPE_COLORS[cell_type].b, 0.5)
	for cube in _level_cubes:
		cube.material_override.albedo_color = slice_color
	_update_level_visual()
	set_upgrading(true)


func raze() -> void:
	upgrade_cooldown = 0
	owner_index = -1
	if cell_type != CellType.RESOURCE:
		if cell_level > 1:
			cell_level -= 1
		else:
			cell_type = CellType.RESOURCE
	match cell_type:
		CellType.RESOURCE:    raze_turns_remaining = Config.get_value("raze.resource_rubble_turns")
		CellType.INDUSTRY:    raze_turns_remaining = Config.get_value("raze.industry_rubble_turns")
		CellType.RESIDENTIAL: raze_turns_remaining = Config.get_value("raze.residential_rubble_turns")
	_fill_mat.set_shader_parameter("albedo_color", RAZED_COLOR)
	_outline_mat.grow_amount = 0.0
	_update_level_visual()


func restore_from_raze() -> void:
	raze_turns_remaining = 0
	raze_player_index = -1
	_fill_mat.set_shader_parameter("albedo_color", TYPE_COLORS[cell_type])
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
				3: return "City"
				4: return "Metropolis"
	return "Unknown"


func max_level() -> int:
	match cell_type:
		CellType.RESIDENTIAL: return 4
		CellType.INDUSTRY:    return 3
	return 1


func display_name() -> String:
	if raze_turns_remaining > 0:
		return "Rubble (%d turns)" % raze_turns_remaining
	if upgrade_cooldown > 0:
		return "%s (upgrading: %d)" % [level_name(), upgrade_cooldown]
	return level_name()
