@tool
extends EditorPlugin

# Self-preloads — GoSheetsPanel uses ColumnModel etc. at compile time; loaded
# transitively through the scene, so no direct preload needed here. Plugin.gd
# only holds a Control reference.

const _PANEL_SCENE := preload("res://addons/go_sheets/core/go_sheets_panel.tscn")

var _panel: Control


func _enter_tree() -> void:
	_panel = _PANEL_SCENE.instantiate()
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)


func _exit_tree() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Resources"


func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/go_sheets/icon.svg")


func _make_visible(visible: bool) -> void:
	if _panel:
		_panel.visible = visible
