extends Control

@onready var local_versus_btn: Button = $CenterContainer/VBoxContainer/LocalVersusButton
@onready var vs_ai_btn: Button = $CenterContainer/VBoxContainer/VsAIButton
@onready var ai_vs_ai_btn: Button = $CenterContainer/VBoxContainer/AIvsAIButton
@onready var multiplayer_versus_btn: Button = $CenterContainer/VBoxContainer/MultiplayerVersusButton
@onready var how_to_play_btn: Button = $CenterContainer/VBoxContainer/HowToPlayButton
@onready var how_to_play_panel: Control = $HowToPlayPanel
@onready var close_btn: Button = $HowToPlayPanel/CenterContainer/PanelContainer/MarginContainer/VBox/CloseButton
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	local_versus_btn.pressed.connect(_on_local_versus_pressed)
	vs_ai_btn.pressed.connect(_on_vs_ai_pressed)
	ai_vs_ai_btn.pressed.connect(_on_ai_vs_ai_pressed)
	multiplayer_versus_btn.pressed.connect(_on_multiplayer_versus_pressed)
	how_to_play_btn.pressed.connect(func(): how_to_play_panel.visible = true)
	close_btn.pressed.connect(func(): how_to_play_panel.visible = false)
	ai_vs_ai_btn.visible = OS.has_feature("editor")
	var vf := FileAccess.open("res://version.txt", FileAccess.READ)
	if vf:
		version_label.text = vf.get_as_text().strip_edges()
	else:
		version_label.text = "err:%d" % FileAccess.get_open_error()
	if GameState.ai_flags[0] and GameState.ai_flags[1]:
		get_tree().change_scene_to_file.call_deferred("res://main.tscn")

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
