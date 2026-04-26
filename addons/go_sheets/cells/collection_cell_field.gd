## CollectionCellField
##
## Mini editor for Array and Dictionary values using JSON text.
## Shows a compact TextEdit with Apply/Reset controls.

class_name CollectionCellField
extends CellField

var _is_dictionary: bool = false
var _value: Variant = []

var _container: VBoxContainer
var _text_edit: TextEdit
var _error_label: Label
var _apply_button: Button
var _reset_button: Button


func _init() -> void:
	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 4)
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_container)

	_text_edit = TextEdit.new()
	_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_edit.custom_minimum_size = Vector2(220, 80)
	_container.add_child(_text_edit)

	_error_label = Label.new()
	_error_label.visible = false
	_error_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_container.add_child(_error_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.add_child(actions)

	_apply_button = Button.new()
	_apply_button.text = "Apply"
	_apply_button.pressed.connect(_on_apply_pressed)
	actions.add_child(_apply_button)

	_reset_button = Button.new()
	_reset_button.text = "Reset"
	_reset_button.pressed.connect(_on_reset_pressed)
	actions.add_child(_reset_button)


func setup(is_dictionary: bool) -> void:
	_is_dictionary = is_dictionary


func set_value(value: Variant) -> void:
	if _is_dictionary:
		_value = value if value is Dictionary else {}
	else:
		_value = value if value is Array else []
	_text_edit.text = JSON.stringify(_value, "  ")
	_clear_error()


func get_value() -> Variant:
	var parsed := _parse_current_text()
	if parsed == null:
		return _value
	return parsed


func focus_main() -> void:
	_text_edit.grab_focus()
	_text_edit.set_caret_column(0)
	_text_edit.set_caret_line(0)


func _on_apply_pressed() -> void:
	var parsed := _parse_current_text()
	if parsed == null:
		return
	_value = parsed
	_clear_error()
	value_changed.emit(_value)


func _on_reset_pressed() -> void:
	_text_edit.text = JSON.stringify(_value, "  ")
	_clear_error()


func _parse_current_text() -> Variant:
	var parser := JSON.new()
	var err := parser.parse(_text_edit.text)
	if err != OK:
		_set_error("Invalid JSON")
		return null
	var data: Variant = parser.data
	if _is_dictionary and not (data is Dictionary):
		_set_error("Expected a Dictionary JSON object")
		return null
	if (not _is_dictionary) and not (data is Array):
		_set_error("Expected an Array JSON value")
		return null
	return data


func _set_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true


func _clear_error() -> void:
	_error_label.text = ""
	_error_label.visible = false
