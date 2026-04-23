@tool
extends Control

## GoSheetsPanel — main screen root.
##
## Owns the full Resources tab layout: toolbar, type selector,
## filter bar, and the grid. Populated in later stages.


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_build_placeholder()


func _build_placeholder() -> void:
	var label := Label.new()
	label.text = "GoSheets — Resources"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
