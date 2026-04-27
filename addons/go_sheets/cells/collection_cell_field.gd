@tool
## CollectionCellField
##
## Mini editor for Array and Dictionary values using JSON text.
## Shows a compact TextEdit with Apply/Reset controls.

class_name CollectionCellField
extends CellField

var _is_dictionary: bool = false
var _value: Variant = []
var _resource_array_mode: bool = false
var _array_resource_class_hint: String = ""

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


func setup(
		is_dictionary: bool,
		hint: int = PROPERTY_HINT_NONE,
		hint_string: String = "") -> void:
	_is_dictionary = is_dictionary
	_resource_array_mode = false
	_array_resource_class_hint = ""
	if not _is_dictionary and hint == PROPERTY_HINT_ARRAY_TYPE:
		_array_resource_class_hint = _detect_resource_array_class(hint_string)


func set_value(value: Variant) -> void:
	if _is_dictionary:
		_value = value if value is Dictionary else {}
	else:
		_value = value if value is Array else []
	if _is_dictionary:
		_resource_array_mode = false
	elif _array_resource_class_hint != "" or _array_contains_resources(_value):
		_resource_array_mode = true
	else:
		_resource_array_mode = false
	_text_edit.text = _format_value_for_editor(_value)
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
	_text_edit.text = _format_value_for_editor(_value)
	_clear_error()


func _parse_current_text() -> Variant:
	if _resource_array_mode and not _is_dictionary:
		return _parse_resource_path_lines()

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


func _format_value_for_editor(value: Variant) -> String:
	if _resource_array_mode and value is Array:
		var lines: Array[String] = []
		for entry in value as Array:
			if entry is Resource:
				var res := entry as Resource
				if res.resource_path != "":
					lines.append(res.resource_path)
		return "\n".join(lines)
	return JSON.stringify(value, "  ")


func _parse_resource_path_lines() -> Variant:
	var out: Array[Resource] = []
	var lines := _text_edit.text.split("\n", false)
	for raw_line: String in lines:
		var path := raw_line.strip_edges()
		if path == "":
			continue
		if not path.begins_with("res://"):
			_set_error("Resource paths must start with res://")
			return null
		var loaded := ResourceLoader.load(path)
		if loaded == null:
			_set_error("Could not load resource: %s" % path)
			return null
		if not (loaded is Resource):
			_set_error("Loaded value is not a Resource: %s" % path)
			return null
		if _array_resource_class_hint != "" and not _matches_resource_class_hint(loaded):
			_set_error("Resource type mismatch for path: %s" % path)
			return null
		out.append(loaded)
	return out


func _array_contains_resources(value: Variant) -> bool:
	if not (value is Array):
		return false
	for entry in value as Array:
		if entry is Resource:
			return true
	return false


func _detect_resource_array_class(hint_string: String) -> String:
	if hint_string == "":
		return ""
	if hint_string.find("Resource") >= 0:
		return "Resource"
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var class_name := str(entry.get("class", ""))
		if class_name != "" and hint_string.find(class_name) >= 0:
			return class_name
	return ""


func _matches_resource_class_hint(resource: Resource) -> bool:
	if _array_resource_class_hint == "" or _array_resource_class_hint == "Resource":
		return true
	return ClassDB.is_parent_class(resource.get_class(), _array_resource_class_hint)


func _set_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true


func _clear_error() -> void:
	_error_label.text = ""
	_error_label.visible = false
