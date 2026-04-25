## ColorCellField
##
## A ColorPickerButton for editing color values.

class_name ColorCellField
extends CellField

var _color_picker: ColorPickerButton

func _init() -> void:
	_color_picker = ColorPickerButton.new()
	_color_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_color_picker.custom_minimum_size = Vector2(80, 0)
	_color_picker.popup_closed.connect(func() -> void: _on_popup_closed())
	add_child(_color_picker)

func set_value(value: Variant) -> void:
	_color_picker.color = value if value is Color else Color.WHITE

func get_value() -> Variant:
	return _color_picker.color

func focus_main() -> void:
	_color_picker.grab_focus()

func _on_popup_closed() -> void:
	value_changed.emit(get_value())
