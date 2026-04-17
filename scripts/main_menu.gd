extends Control

@onready var local_versus_btn: Button = $CenterContainer/VBoxContainer/LocalVersusButton
@onready var multiplayer_versus_btn: Button = $CenterContainer/VBoxContainer/MultiplayerVersusButton

func _ready() -> void:
	local_versus_btn.pressed.connect(_on_local_versus_pressed)
	multiplayer_versus_btn.pressed.connect(_on_multiplayer_versus_pressed)

func _on_local_versus_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_multiplayer_versus_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/lobby.tscn")
