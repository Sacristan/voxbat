extends CanvasLayer

func _ready() -> void:
	$CenterContainer/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$CenterContainer/VBoxContainer/MenuButton.pressed.connect(_on_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_resume()
		else:
			_pause()

func _pause() -> void:
	show()
	get_tree().paused = true

func _resume() -> void:
	hide()
	get_tree().paused = false

func _on_resume_pressed() -> void:
	_resume()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
