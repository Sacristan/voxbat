extends CanvasLayer

signal end_turn_pressed

@onready var turn_label: Label = $TopBar/TopBarInner/TurnLabel
@onready var manpower_label: Label = $TopBar/TopBarInner/ResourceBar/ManpowerLabel
@onready var manpower_delta_label: Label = $TopBar/TopBarInner/ResourceBar/ManpowerDeltaLabel
@onready var supplies_label: Label = $TopBar/TopBarInner/ResourceBar/SuppliesLabel
@onready var materials_label: Label = $TopBar/TopBarInner/ResourceBar/MaterialsLabel
@onready var end_turn_btn: Button = $TopBar/TopBarInner/EndTurnButton
@onready var game_over_label: Label = $GameOverLabel


func _ready() -> void:
	end_turn_btn.pressed.connect(func() -> void: end_turn_pressed.emit())


func update_turn(player_name: String) -> void:
	turn_label.text = "Turn: " + player_name


func update_resources(player: PlayerData, manpower_delta: int = 0) -> void:
	manpower_label.text = "Manpower: %d" % player.manpower
	manpower_delta_label.text = "(+%d)" % manpower_delta if manpower_delta >= 0 else "(%d)" % manpower_delta
	if manpower_delta < 0:
		manpower_delta_label.modulate = Color(1.0, 0.25, 0.25)
	elif manpower_delta <= 2:
		manpower_delta_label.modulate = Color(1.0, 0.9, 0.0)
	else:
		manpower_delta_label.modulate = Color(0.25, 1.0, 0.35)
	supplies_label.text = "Supplies: %d" % player.supplies
	materials_label.text = "Materials: %d" % player.materials


func show_game_over(winner_name: String) -> void:
	game_over_label.text = winner_name + " wins!"
	game_over_label.visible = true
	end_turn_btn.disabled = true
