@tool
## CollectionCellField
##
## Mini editor for Array and Dictionary values.
##
## - Array[Resource]: one res:// path per line (path-per-line mode)
## - Array (scalar): JSON TextEdit
## - Dictionary: structured key/value row editor with Add/Remove controls
##
## All modes share Apply/Reset buttons. Apply commits and closes the popup;
## Reset restores the last committed state. Focus-away does NOT auto-commit
## (get_value() returns the last committed _value when text is dirty).

class_name CollectionCellField
extends CellField

# Self-preloads
const _RESOURCE_PICKER_POPUP_SCRIPT := preload(
		"res://addons/go_sheets/cells/resource_picker_popup.gd")

var _is_dictionary: bool = false
var _value: Variant = []
var _resource_array_mode: bool = false
var _array_resource_class_hint: String = ""

# Shared layout
var _container: VBoxContainer
var _error_label: Label
var _apply_button: Button
var _reset_button: Button

# Scalar array mode
var _text_edit: TextEdit

# Resource array row editor (visible only in resource-array mode)
var _resource_scroll: ScrollContainer
var _resource_rows: VBoxContainer   # one child HBoxContainer per resource
var _add_resource_button: Button

# Dictionary row editor (visible only in dictionary mode)
var _dict_scroll: ScrollContainer
var _dict_rows: VBoxContainer   # one child HBoxContainer per key/value pair
var _add_row_button: Button

# Shared picker popup (created lazily)
var _picker_popup: Node


func _init() -> void:
	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 4)
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_container)

	# --- Scalar array / JSON text edit ---
	_text_edit = TextEdit.new()
	_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_edit.custom_minimum_size = Vector2(220, 80)
	_container.add_child(_text_edit)

	# --- Resource array row editor ---
	_resource_scroll = ScrollContainer.new()
	_resource_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_resource_scroll.custom_minimum_size = Vector2(280, 90)
	_resource_scroll.visible = false
	_container.add_child(_resource_scroll)

	_resource_rows = VBoxContainer.new()
	_resource_rows.add_theme_constant_override("separation", 2)
	_resource_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_scroll.add_child(_resource_rows)

	_add_resource_button = Button.new()
	_add_resource_button.text = "+ Add resource"
	_add_resource_button.flat = true
	_add_resource_button.visible = false
	_add_resource_button.pressed.connect(_on_add_resource_pressed)
	_container.add_child(_add_resource_button)

	# --- Dictionary row editor (hidden in array modes) ---
	_dict_scroll = ScrollContainer.new()
	_dict_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dict_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dict_scroll.custom_minimum_size = Vector2(320, 90)
	_dict_scroll.visible = false
	_container.add_child(_dict_scroll)

	_dict_rows = VBoxContainer.new()
	_dict_rows.add_theme_constant_override("separation", 2)
	_dict_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dict_scroll.add_child(_dict_rows)

	_add_row_button = Button.new()
	_add_row_button.text = "+ Add row"
	_add_row_button.flat = true
	_add_row_button.visible = false
	_add_row_button.pressed.connect(_on_add_row_pressed)
	_container.add_child(_add_row_button)

	# --- Error label ---
	_error_label = Label.new()
	_error_label.visible = false
	_error_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_container.add_child(_error_label)

	# --- Apply / Reset ---
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
		_hint: int = PROPERTY_HINT_NONE,
		hint_string: String = "") -> void:
	_is_dictionary = is_dictionary
	_resource_array_mode = false
	_array_resource_class_hint = ""
	# Always attempt detection — Godot's PROPERTY_HINT_ARRAY_TYPE integer is
	# inconsistent across versions for GDScript-defined typed arrays.
	# _detect_resource_array_class returns "" for non-resource arrays, so this is safe.
	if not _is_dictionary:
		_array_resource_class_hint = _detect_resource_array_class(hint_string)
	_update_mode_visibility()


func set_value(value: Variant) -> void:
	if _is_dictionary:
		_value = value if value is Dictionary else {}
	else:
		_value = value if value is Array else []
	if _is_dictionary:
		_resource_array_mode = false
		_rebuild_dict_rows(_value)
	elif _array_resource_class_hint != "" or _array_contains_resources(_value):
		_resource_array_mode = true
		_rebuild_resource_rows(_value)
	else:
		_resource_array_mode = false
		_text_edit.text = _format_value_for_editor(_value)
	_update_mode_visibility()
	_clear_error()


func get_value() -> Variant:
	if _is_dictionary:
		var parsed := _parse_dict_rows()
		return parsed if parsed != null else _value
	if _resource_array_mode:
		var parsed := _parse_resource_rows()
		return parsed if parsed != null else _value
	var parsed := _parse_current_text()
	if parsed == null:
		return _value
	return parsed


func focus_main() -> void:
	if _is_dictionary:
		if _dict_rows.get_child_count() > 0:
			var first_row := _dict_rows.get_child(0) as HBoxContainer
			var key_edit := first_row.get_node_or_null("KeyEdit") as LineEdit
			if key_edit != null:
				key_edit.grab_focus()
				return
		_add_row_button.grab_focus()
		return
	if _resource_array_mode:
		_add_resource_button.grab_focus()
		return
	_text_edit.grab_focus()
	_text_edit.set_caret_column(0)
	_text_edit.set_caret_line(0)


func _on_apply_pressed() -> void:
	if _is_dictionary:
		var parsed := _parse_dict_rows()
		if parsed == null:
			return
		_value = parsed
		_clear_error()
		value_changed.emit(_value)
		return
	if _resource_array_mode:
		var parsed := _parse_resource_rows()
		if parsed == null:
			return
		_value = parsed
		_clear_error()
		value_changed.emit(_value)
		return
	var parsed := _parse_current_text()
	if parsed == null:
		return
	_value = parsed
	_clear_error()
	value_changed.emit(_value)


func _on_reset_pressed() -> void:
	if _is_dictionary:
		_rebuild_dict_rows(_value)
		_clear_error()
		return
	if _resource_array_mode:
		_rebuild_resource_rows(_value)
		_clear_error()
		return
	_text_edit.text = _format_value_for_editor(_value)
	_clear_error()


func _on_add_row_pressed() -> void:
	_append_dict_row("", "")


func _on_remove_row_pressed(row: HBoxContainer) -> void:
	row.queue_free()


func _on_add_resource_pressed() -> void:
	_open_picker(
		_array_resource_class_hint,
		func(path: String) -> void: _append_resource_row(path)
	)


func _on_browse_resource_row_pressed(row: HBoxContainer) -> void:
	_open_picker(
		_array_resource_class_hint,
		func(path: String) -> void:
			var lbl := row.get_node_or_null("PathLabel") as Label
			if lbl != null:
				lbl.text = path.get_file()
				lbl.tooltip_text = path
				row.set_meta("path", path)
	)


func _on_browse_dict_value_pressed(row: HBoxContainer) -> void:
	_open_picker(
		"",
		func(path: String) -> void:
			var val_edit := row.get_node_or_null("ValueEdit") as LineEdit
			if val_edit != null:
				val_edit.text = path
	)


func _on_remove_resource_row_pressed(row: HBoxContainer) -> void:
	row.queue_free()


# Open _picker_popup configured to call [param callback] with the chosen path.
func _open_picker(base_type: String, callback: Callable) -> void:
	if _picker_popup == null:
		_picker_popup = _RESOURCE_PICKER_POPUP_SCRIPT.new()
		add_child(_picker_popup)
	for conn in _picker_popup.resource_selected.get_connections():
		_picker_popup.resource_selected.disconnect(conn["callable"])
	_picker_popup.resource_selected.connect(callback, CONNECT_ONE_SHOT)
	_picker_popup.open(base_type)


# ---------------------------------------------------------------------------
# Resource array row editor
# ---------------------------------------------------------------------------

func _update_mode_visibility() -> void:
	_text_edit.visible = not _is_dictionary and not _resource_array_mode
	_resource_scroll.visible = not _is_dictionary and _resource_array_mode
	_add_resource_button.visible = not _is_dictionary and _resource_array_mode
	_dict_scroll.visible = _is_dictionary
	_add_row_button.visible = _is_dictionary


func _rebuild_resource_rows(arr: Array) -> void:
	for child in _resource_rows.get_children():
		child.queue_free()
	for entry in arr:
		if entry is Resource:
			var res := entry as Resource
			_append_resource_row(res.resource_path)


func _append_resource_row(path: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("path", path)
	_resource_rows.add_child(row)

	var lbl := Label.new()
	lbl.name = "PathLabel"
	lbl.text = path.get_file() if path != "" else "(empty)"
	lbl.tooltip_text = path
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	row.add_child(lbl)

	var browse_btn := Button.new()
	browse_btn.name = "BrowseBtn"
	browse_btn.text = "Browse"
	browse_btn.flat = true
	browse_btn.pressed.connect(_on_browse_resource_row_pressed.bind(row))
	row.add_child(browse_btn)

	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.flat = true
	remove_btn.pressed.connect(_on_remove_resource_row_pressed.bind(row))
	row.add_child(remove_btn)


func _parse_resource_rows() -> Variant:
	var out: Array[Resource] = []
	for row_node in _resource_rows.get_children():
		var row := row_node as HBoxContainer
		if row == null or not row.has_meta("path"):
			continue
		var path: String = row.get_meta("path")
		if path == "":
			_set_error("A resource row has no path; remove or browse it first")
			return null
		var loaded := ResourceLoader.load(path)
		if loaded == null:
			_set_error("Could not load resource: %s" % path)
			return null
		if _array_resource_class_hint != "" and not _matches_resource_class_hint(loaded):
			_set_error("Type mismatch: %s" % path)
			return null
		out.append(loaded)
	return out


# ---------------------------------------------------------------------------
# Dictionary row editor
# ---------------------------------------------------------------------------

func _rebuild_dict_rows(dict: Dictionary) -> void:
	for child in _dict_rows.get_children():
		child.queue_free()
	for key: Variant in dict:
		_append_dict_row(str(key), _value_to_display_string(dict[key]))


func _append_dict_row(key_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dict_rows.add_child(row)

	var key_edit := LineEdit.new()
	key_edit.name = "KeyEdit"
	key_edit.placeholder_text = "key"
	key_edit.text = key_text
	key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_edit.custom_minimum_size = Vector2(80, 0)
	row.add_child(key_edit)

	var sep := Label.new()
	sep.text = "→"
	row.add_child(sep)

	var val_edit := LineEdit.new()
	val_edit.name = "ValueEdit"
	val_edit.placeholder_text = "value (JSON or res://)"
	val_edit.text = value_text
	val_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_edit.custom_minimum_size = Vector2(80, 0)
	row.add_child(val_edit)

	var browse_btn := Button.new()
	browse_btn.text = "…"
	browse_btn.flat = true
	browse_btn.tooltip_text = "Browse for a resource"
	browse_btn.pressed.connect(_on_browse_dict_value_pressed.bind(row))
	row.add_child(browse_btn)

	var remove_btn := Button.new()
	remove_btn.text = "✕"
	remove_btn.flat = true
	remove_btn.pressed.connect(_on_remove_row_pressed.bind(row))
	row.add_child(remove_btn)


func _parse_dict_rows() -> Variant:
	var result := {}
	var keys_seen: Array[String] = []
	for row_node in _dict_rows.get_children():
		var row := row_node as HBoxContainer
		if row == null:
			continue
		var key_edit := row.get_node_or_null("KeyEdit") as LineEdit
		var val_edit := row.get_node_or_null("ValueEdit") as LineEdit
		if key_edit == null or val_edit == null:
			continue
		var key := key_edit.text.strip_edges()
		if key == "":
			_set_error("Keys must not be empty")
			return null
		if key in keys_seen:
			_set_error("Duplicate key: %s" % key)
			return null
		keys_seen.append(key)
		result[key] = _parse_dict_value(val_edit.text.strip_edges())
	return result


func _parse_dict_value(raw: String) -> Variant:
	# res:// path → load as Resource
	if raw.begins_with("res://"):
		var loaded := ResourceLoader.load(raw)
		if loaded != null:
			return loaded
		return raw
	# Try JSON scalar (number, bool, null, quoted string, array, object)
	var parser := JSON.new()
	if parser.parse(raw) == OK:
		return parser.data
	# Fallback: treat as plain string
	return raw


func _value_to_display_string(val: Variant) -> String:
	if val is Resource:
		var res := val as Resource
		return res.resource_path if res.resource_path != "" else "<Resource>"
	if val is String:
		return val
	return JSON.stringify(val)


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


func _format_value_for_editor(value: Variant) -> String:
	return JSON.stringify(value, "  ")


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
	# Godot encodes typed-array element type as "T/H:ClassName" or "T:ClassName".
	# Extract what is after the last colon — that is the element class name.
	var colon_pos := hint_string.rfind(":")
	if colon_pos >= 0:
		var class_name_str := hint_string.substr(colon_pos + 1).strip_edges()
		if class_name_str != "":
			# Engine Resource subclass (e.g. Texture2D, AudioStream)?
			if ClassDB.class_exists(class_name_str) and ClassDB.is_parent_class(class_name_str, "Resource"):
				return class_name_str
			# GDScript class — confirm it exists in the global class list.
			for entry: Dictionary in ProjectSettings.get_global_class_list():
				if entry.get("class", "") == class_name_str:
					return class_name_str
	# Fallback: legacy substring scan (e.g. bare "Resource" hint_string)
	if hint_string.find("Resource") >= 0:
		return "Resource"
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var entry_class := str(entry.get("class", ""))
		if entry_class != "" and hint_string.find(entry_class) >= 0:
			return entry_class
	return ""


func _matches_resource_class_hint(resource: Resource) -> bool:
	if _array_resource_class_hint == "" or _array_resource_class_hint == "Resource":
		return true
	# Engine/extension class: use ClassDB for inheritance check.
	if ClassDB.class_exists(_array_resource_class_hint):
		return ClassDB.is_parent_class(resource.get_class(), _array_resource_class_hint)
	# GDScript class: walk the resource's script chain and compare resource_path
	# against the expected class entry in the global class list.
	var expected_path := ""
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == _array_resource_class_hint:
			expected_path = entry.get("path", "")
			break
	if expected_path == "":
		return false
	var script := resource.get_script() as GDScript
	while script != null:
		if script.resource_path == expected_path:
			return true
		script = script.get_base_script() as GDScript
	return false


func _set_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true


func _clear_error() -> void:
	_error_label.text = ""
	_error_label.visible = false
