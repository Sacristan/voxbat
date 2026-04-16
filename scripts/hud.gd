extends CanvasLayer

signal end_turn_pressed
signal resource_info_requested(which: String)

@onready var turn_label: Label = $TopBar/TopBarInner/TurnLabel
@onready var end_turn_btn: Button = $TopBar/TopBarInner/EndTurnButton
@onready var manpower_label: Label = $TopBar/TopBarInner/ResourceBar/ManpowerSection/ManpowerLabel
@onready var manpower_delta_label: Label = $TopBar/TopBarInner/ResourceBar/ManpowerSection/ManpowerDeltaLabel
@onready var supplies_label: Label = $TopBar/TopBarInner/ResourceBar/SuppliesSection/SuppliesLabel
@onready var supplies_delta_label: Label = $TopBar/TopBarInner/ResourceBar/SuppliesSection/SuppliesDeltaLabel
@onready var materials_label: Label = $TopBar/TopBarInner/ResourceBar/MaterialsSection/MaterialsLabel
@onready var materials_delta_label: Label = $TopBar/TopBarInner/ResourceBar/MaterialsSection/MaterialsDeltaLabel
@onready var game_over_label: Label = $GameOverLabel
@onready var resource_info_panel = $ResourceInfoPanel
@onready var info_title_label: Label = $ResourceInfoPanel/InfoMargin/InfoVBox/InfoTitleRow/InfoTitleLabel
@onready var info_content_label: Label = $ResourceInfoPanel/InfoMargin/InfoVBox/InfoContentLabel
@onready var info_close_btn: Button = $ResourceInfoPanel/InfoMargin/InfoVBox/InfoTitleRow/InfoCloseButton
@onready var mp_section: HBoxContainer = $TopBar/TopBarInner/ResourceBar/ManpowerSection
@onready var sup_section: HBoxContainer = $TopBar/TopBarInner/ResourceBar/SuppliesSection
@onready var mat_section: HBoxContainer = $TopBar/TopBarInner/ResourceBar/MaterialsSection


func _ready() -> void:
	end_turn_btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	info_close_btn.pressed.connect(func(): resource_info_panel.visible = false)
	mp_section.gui_input.connect(_on_mp_input)
	sup_section.gui_input.connect(_on_sup_input)
	mat_section.gui_input.connect(_on_mat_input)


func update_turn(player_name: String) -> void:
	turn_label.text = "Turn: " + player_name


func update_resources(player: PlayerData, mp_delta: int, sup_delta: int, mat_delta: int) -> void:
	manpower_label.text = "MP: %d" % player.manpower
	_set_delta(manpower_delta_label, mp_delta)
	_set_shortage_label(manpower_label, player.manpower, mp_delta)
	supplies_label.text = "SUP: %d" % player.supplies
	_set_delta(supplies_delta_label, sup_delta)
	_set_shortage_label(supplies_label, player.supplies, sup_delta)
	materials_label.text = "MAT: %d" % player.materials
	_set_delta(materials_delta_label, mat_delta)
	_set_shortage_label(materials_label, player.materials, mat_delta)


func show_game_over(winner_name: String) -> void:
	game_over_label.text = winner_name + " wins!"
	game_over_label.visible = true
	end_turn_btn.disabled = true


func show_resource_info(title: String, content: String) -> void:
	info_title_label.text = title
	info_content_label.text = content
	resource_info_panel.visible = true


func close_all_panels() -> void:
	resource_info_panel.visible = false


func _set_shortage_label(label: Label, value: int, delta: int) -> void:
	if value <= 0 and delta < 0:
		label.modulate = Color(1.0, 0.15, 0.15)
	else:
		label.modulate = Color(1.0, 1.0, 1.0)


func _set_delta(label: Label, delta: int) -> void:
	label.text = "(+%d)" % delta if delta >= 0 else "(%d)" % delta
	if delta < 0:
		label.modulate = Color(1.0, 0.25, 0.25)
	elif delta <= 2:
		label.modulate = Color(1.0, 0.90, 0.00)
	else:
		label.modulate = Color(0.25, 1.00, 0.35)


func _on_mp_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		resource_info_requested.emit("mp")


func _on_sup_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		resource_info_requested.emit("sup")


func _on_mat_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		resource_info_requested.emit("mat")
