@tool
extends EditorExportPlugin


func _get_name() -> String:
	return "VersionInjector"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var output: Array = []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], output)
	var version: String = output[0].strip_edges() if not output.is_empty() else "unknown"
	var f := FileAccess.open("res://version.txt", FileAccess.WRITE)
	if f:
		f.store_string(version)
		f.close()
