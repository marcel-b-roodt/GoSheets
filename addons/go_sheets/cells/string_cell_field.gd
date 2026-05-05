@tool
## StringCellField
##
## A LineEdit for editing string values.

class_name StringCellField
extends CellField

var _line_edit: LineEdit

func _init() -> void:
	_line_edit = LineEdit.new()
	_line_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line_edit.select_all_on_focus = true
	_line_edit.text_submitted.connect(func(_t: String) -> void: _on_submitted())
	_line_edit.focus_exited.connect(func() -> void: _on_focus_exited())
	add_child(_line_edit)

func set_value(value: Variant) -> void:
	_line_edit.text = str(value) if value != null else ""

func get_value() -> Variant:
	return _line_edit.text

func focus_main() -> void:
	_line_edit.grab_focus()
	_line_edit.select_all()

func _on_submitted() -> void:
	value_changed.emit(get_value())

func _on_focus_exited() -> void:
	# Only commit if focus left entirely (not moving to another control in parent).
	if get_viewport().gui_get_focus_owner() != null \
			and (get_viewport().gui_get_focus_owner() == self \
			or is_ancestor_of(get_viewport().gui_get_focus_owner())):
		return
	value_changed.emit(get_value())
