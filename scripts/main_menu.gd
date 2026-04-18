extends Control

@onready var local_versus_btn: Button = $CenterContainer/VBoxContainer/LocalVersusButton
@onready var vs_ai_btn: Button = $CenterContainer/VBoxContainer/VsAIButton
@onready var ai_vs_ai_btn: Button = $CenterContainer/VBoxContainer/AIvsAIButton
@onready var multiplayer_versus_btn: Button = $CenterContainer/VBoxContainer/MultiplayerVersusButton

func _ready() -> void:
	local_versus_btn.pressed.connect(_on_local_versus_pressed)
	vs_ai_btn.pressed.connect(_on_vs_ai_pressed)
	ai_vs_ai_btn.pressed.connect(_on_ai_vs_ai_pressed)
	multiplayer_versus_btn.pressed.connect(_on_multiplayer_versus_pressed)

func _on_local_versus_pressed() -> void:
	GameState.ai_flags = [false, false]
	get_tree().change_scene_to_file("res://main.tscn")

func _on_vs_ai_pressed() -> void:
	GameState.ai_flags = [false, true]
	get_tree().change_scene_to_file("res://main.tscn")

func _on_ai_vs_ai_pressed() -> void:
	GameState.ai_flags = [true, true]
	get_tree().change_scene_to_file("res://main.tscn")

func _on_multiplayer_versus_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/lobby.tscn")
