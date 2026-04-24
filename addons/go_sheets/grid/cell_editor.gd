@tool
## CellEditor
##
## A lightweight popup that floats over a grid cell and lets the user edit
## the value in-place.  One instance is created by ResourceGrid and reused
## across all cells — call open() to attach it to a cell, close() to dismiss.
##
## Supported property types / hints:
##   • String                          → LineEdit
##   • int / float                     → SpinBox  (PROPERTY_HINT_RANGE: min/max/step)
##   • bool                            → CheckBox
##   • Color                           → ColorPickerButton
##   • int with PROPERTY_HINT_ENUM     → OptionButton
##   (Resource-reference cells are read-only for now; Stage 2.5 adds a picker)
##
## Emits value_committed when the user confirms a new value.

class_name CellEditor
extends PopupPanel

## Emitted when the user accepts a new value.
## [param resource]  — the resource being edited
## [param property]  — the property StringName
## [param old_value] — value before edit
## [param new_value] — value after edit
signal value_committed(
		resource: Resource,
		property: StringName,
		old_value: Variant,
		new_value: Variant)

## Emitted when Tab is pressed — consumer should commit and move focus.
signal tab_pressed(is_shift: bool)

const _MIN_WIDTH := 120
const _MIN_HEIGHT := 28

# Current edit context
var _resource: Resource
var _property: StringName
var _col: ColumnDef
var _old_value: Variant

# The single active editor control (swapped per type)
var _inner: Control


func _ready() -> void:
	# PopupPanel defaults — borderless, auto-close on focus loss.
	transparent_bg = false
	exclusive = false
	close_requested.connect(_on_close_requested)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				_cancel()
			KEY_TAB:
				_commit()
				tab_pressed.emit(event.shift_pressed)


func _cancel() -> void:
	hide()


func _write_old_value() -> void:
	pass


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Open the editor for [param resource].[param col] at [param screen_rect].
## [param screen_rect] is the cell's bounding box in screen (global) coordinates.
func open(
		resource: Resource,
		col: ColumnDef,
		screen_rect: Rect2i) -> void:
	_resource   = resource
	_property   = col.property_name
	_col        = col
	_old_value  = resource.get(_property)

	_rebuild_inner(col, _old_value)

	var w := maxi(screen_rect.size.x, _MIN_WIDTH)
	var h := maxi(screen_rect.size.y, _MIN_HEIGHT)
	size = Vector2i(w, h)
	position = screen_rect.position
	popup()
	_focus_inner()


# ---------------------------------------------------------------------------
# Private — inner control construction
# ---------------------------------------------------------------------------

func _rebuild_inner(col: ColumnDef, current: Variant) -> void:
	# Remove previous inner control if any.
	if _inner != null:
		_inner.queue_free()
		_inner = null

	if col.hint == PROPERTY_HINT_ENUM and col.property_type == TYPE_INT:
		_inner = _make_option_button(col.hint_string, int(current) if current != null else 0)
	else:
		match col.property_type:
			TYPE_BOOL:
				_inner = _make_check_box(bool(current) if current != null else false)
			TYPE_INT:
				_inner = _make_spin_box(col, float(current) if current != null else 0.0, true)
			TYPE_FLOAT:
				_inner = _make_spin_box(col, float(current) if current != null else 0.0, false)
			TYPE_COLOR:
				_inner = _make_color_picker(current if current is Color else Color.WHITE)
			TYPE_STRING, TYPE_STRING_NAME:
				_inner = _make_line_edit(str(current) if current != null else "")
			_:
				# Unsupported type — close immediately rather than show an empty popup.
				return

	if _inner != null:
		_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_inner.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		add_child(_inner)


func _make_line_edit(text: String) -> LineEdit:
	var le := LineEdit.new()
	le.text = text
	le.select_all_on_focus = true
	le.text_submitted.connect(func(_t: String) -> void: _commit())
	return le


func _make_spin_box(col: ColumnDef, value: float, is_int: bool) -> SpinBox:
	var sb := SpinBox.new()
	sb.step = 1.0 if is_int else 0.001
	sb.min_value = -1e9
	sb.max_value = 1e9
	if col.hint == PROPERTY_HINT_RANGE and col.hint_string != "":
		_apply_range_hint(sb, col.hint_string, is_int)
	sb.value = value
	sb.rounded = is_int
	# Confirm on Enter in the embedded LineEdit.
	sb.get_line_edit().text_submitted.connect(func(_t: String) -> void: _commit())
	return sb


func _apply_range_hint(sb: SpinBox, hint_string: String, is_int: bool) -> void:
	# hint_string format: "min,max" or "min,max,step" or "min,max,step,suffix"
	var parts := hint_string.split(",", false)
	if parts.size() >= 1:
		sb.min_value = float(parts[0])
	if parts.size() >= 2:
		sb.max_value = float(parts[1])
	if parts.size() >= 3:
		sb.step = float(parts[2])
	if is_int:
		sb.rounded = true


func _make_check_box(checked: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.button_pressed = checked
	cb.text = "Enabled" if checked else "Disabled"
	cb.toggled.connect(func(on: bool) -> void: cb.text = "Enabled" if on else "Disabled")
	# Commit immediately on toggle.
	cb.toggled.connect(func(_on: bool) -> void: _commit())
	return cb


func _make_option_button(hint_string: String, selected_idx: int) -> OptionButton:
	var ob := OptionButton.new()
	_populate_option_button(ob, hint_string)
	# Clamp selected index to valid range.
	if ob.item_count > 0:
		ob.selected = clampi(selected_idx, 0, ob.item_count - 1)
	# Commit immediately on selection change.
	ob.item_selected.connect(func(_idx: int) -> void: _commit())
	return ob


func _populate_option_button(ob: OptionButton, hint_string: String) -> void:
	# hint_string: "Name,Name:int,Name" — each entry may carry an explicit value.
	var entries := hint_string.split(",", false)
	var auto_val := 0
	for entry: String in entries:
		var colon := entry.find(":")
		if colon >= 0:
			var display := entry.left(colon)
			var val := int(entry.substr(colon + 1))
			ob.add_item(display, val)
			auto_val = val + 1
		else:
			ob.add_item(entry, auto_val)
			auto_val += 1


func _make_color_picker(color: Color) -> ColorPickerButton:
	var cpb := ColorPickerButton.new()
	cpb.color = color
	cpb.custom_minimum_size = Vector2(80, 0)
	# Commit when the picker popup closes.
	cpb.popup_closed.connect(func() -> void: _commit())
	return cpb


func _focus_inner() -> void:
	if _inner == null:
		return
	# For SpinBox, focus the inner LineEdit so keyboard works immediately.
	if _inner is SpinBox:
		(_inner as SpinBox).get_line_edit().grab_focus()
		(_inner as SpinBox).get_line_edit().select_all()
	else:
		_inner.grab_focus()


# ---------------------------------------------------------------------------
# Private — commit / close
# ---------------------------------------------------------------------------

func _commit() -> void:
	if _inner == null or _resource == null:
		hide()
		return
	var new_value: Variant = _read_inner()
	# Always emit — panel decides whether old==new is a no-op worth an undo step.
	value_committed.emit(_resource, _property, _old_value, new_value)
	hide()


func _read_inner() -> Variant:
	if _inner is LineEdit:
		var t: String = (_inner as LineEdit).text
		return StringName(t) if _col.property_type == TYPE_STRING_NAME else t
	if _inner is SpinBox:
		var raw := (_inner as SpinBox).value
		return int(raw) if _col.property_type == TYPE_INT else raw
	if _inner is CheckBox:
		return (_inner as CheckBox).button_pressed
	if _inner is OptionButton:
		var ob := _inner as OptionButton
		return ob.get_item_id(ob.selected) if ob.selected >= 0 else _old_value
	if _inner is ColorPickerButton:
		return (_inner as ColorPickerButton).color
	return _old_value


func _on_close_requested() -> void:
	# User closed without confirming (e.g. Escape / click outside).
	hide()
