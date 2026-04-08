extends Node

var data: Dictionary = {}


func _ready() -> void:
	var file := FileAccess.open("res://config.json", FileAccess.READ)
	if file == null:
		push_error("Config: could not open config.json")
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("Config: failed to parse config.json")
		return
	data = parsed


func get_value(path: String):
	var keys := path.split(".")
	var node = data
	for k in keys:
		if not node is Dictionary or not node.has(k):
			push_error("Config: missing key '%s'" % path)
			return null
		node = node[k]
	return node
