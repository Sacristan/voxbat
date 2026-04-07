extends CanvasLayer

signal end_turn_pressed

@onready var turn_label: Label = $TopBar/TopBarInner/TurnLabel
@onready var manpower_label: Label = $TopBar/TopBarInner/ResourceBar/ManpowerLabel
@onready var supplies_label: Label = $TopBar/TopBarInner/ResourceBar/SuppliesLabel
@onready var materials_label: Label = $TopBar/TopBarInner/ResourceBar/MaterialsLabel
@onready var end_turn_btn: Button = $TopBar/TopBarInner/EndTurnButton
@onready var game_over_label: Label = $GameOverLabel


func _ready() -> void:
	end_turn_btn.pressed.connect(func() -> void: end_turn_pressed.emit())


func update_turn(player_name: String) -> void:
	turn_label.text = "Turn: " + player_name


func update_resources(player: PlayerData) -> void:
	manpower_label.text = "Manpower: %d" % player.manpower
	supplies_label.text = "Supplies: %d" % player.supplies
	materials_label.text = "Materials: %d" % player.materials


func show_game_over(winner_name: String) -> void:
	game_over_label.text = winner_name + " wins!"
	game_over_label.visible = true
	end_turn_btn.disabled = true
