@tool
extends EditorPlugin

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = preload("version_export_plugin.gd").new()
	add_export_plugin(_export_plugin)
	add_tool_menu_item("Update version.txt from git", _write_version)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	remove_tool_menu_item("Update version.txt from git")
	_export_plugin = null


func _write_version() -> void:
	var output: Array = []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], output)
	var version: String = output[0].strip_edges() if not output.is_empty() else "unknown"
	var f := FileAccess.open("res://version.txt", FileAccess.WRITE)
	if f:
		f.store_string(version)
		f.close()
		print("Version set to: ", version)
	else:
		push_error("VersionInjector: could not write version.txt")
