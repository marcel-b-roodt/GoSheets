## BoolCellField
##
## A CheckBox for editing boolean values.

class_name BoolCellField
extends CellField

var _check_box: CheckBox

func _init() -> void:
	_check_box = CheckBox.new()
	_check_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_check_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_check_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_check_box.toggled.connect(func(_pressed: bool) -> void: _on_toggled())
	add_child(_check_box)

func set_value(value: Variant) -> void:
	_check_box.button_pressed = bool(value) if value != null else false
	_update_label()

func get_value() -> Variant:
	return _check_box.button_pressed

func focus_main() -> void:
	_check_box.grab_focus()

func _on_toggled() -> void:
	_update_label()
	value_changed.emit(get_value())

func _update_label() -> void:
	_check_box.text = "Enabled" if _check_box.button_pressed else "Disabled"
