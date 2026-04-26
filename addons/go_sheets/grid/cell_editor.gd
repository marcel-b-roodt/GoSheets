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

# Self-preloads — ColumnDef is used as a compile-time type annotation in
# class-level vars and function signatures, so it must be preloaded here to
# ensure Godot can compile this script regardless of scan order.
const _COLUMN_DEF_SCRIPT     := preload("res://addons/go_sheets/grid/column_def.gd")
const _STRING_CELL_FIELD     := preload("res://addons/go_sheets/cells/string_cell_field.gd")
const _NUMERIC_CELL_FIELD    := preload("res://addons/go_sheets/cells/numeric_cell_field.gd")
const _BOOL_CELL_FIELD       := preload("res://addons/go_sheets/cells/bool_cell_field.gd")
const _ENUM_CELL_FIELD       := preload("res://addons/go_sheets/cells/enum_cell_field.gd")
const _COLOR_CELL_FIELD      := preload("res://addons/go_sheets/cells/color_cell_field.gd")
const _RESOURCE_REF_CELL_FIELD := preload("res://addons/go_sheets/cells/resource_ref_cell_field.gd")
const _COLLECTION_CELL_FIELD := preload("res://addons/go_sheets/cells/collection_cell_field.gd")

const _MIN_WIDTH             := 48
const _POPUP_PADDING         := 4

## When true, print popup sizing diagnostics.
var debug_mode: bool = false

# Current edit context
var _resource: Resource
var _property: StringName
var _col: ColumnDef
var _old_value: Variant

# The single active editor control (swapped per type)
var _inner: Control

# Prevent double-commit when focus_exited fires after Tab/Enter commit
var _committed: bool = false


func _ready() -> void:
	# PopupPanel defaults — borderless, auto-close on focus loss.
	transparent_bg = false
	exclusive = false
	# We size explicitly in open() so all fields match cell bounds consistently.
	wrap_controls = false
	close_requested.connect(_on_close_requested)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_cancel()
			KEY_TAB:
				get_viewport().set_input_as_handled()
				_commit()
				tab_pressed.emit(event.shift_pressed)


func _cancel() -> void:
	hide()


func _write_old_value() -> void:
	pass


func _commit_deferred_if_focus_left() -> void:
	_commit_if_focus_left.call_deferred()


func _commit_if_focus_left() -> void:
	if not visible or _committed or _inner == null:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and (focus_owner == _inner or _inner.is_ancestor_of(focus_owner)):
		return
	_commit()


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
	_committed  = false

	_rebuild_inner(col, _old_value)

	# Set position first, then show popup, then size it after layout settles.
	# This ensures PopupPanel doesn't override our size during popup() startup sequence.
	position = screen_rect.position
	popup()

	# Now apply sizing after popup is visible and layout is ready.
	# Defer one frame to ensure Godot has computed child sizes.
	_apply_popup_size.call_deferred(screen_rect)
	_focus_inner.call_deferred()


func _apply_popup_size(screen_rect: Rect2i) -> void:
	# Explicit sizing keeps popup dimensions stable and per-cell.
	# Width follows the column width exactly (with a tiny floor), while height
	# starts at row height and expands to fit the editor content (slider rows, etc.).
	var popup_w := maxi(screen_rect.size.x, _MIN_WIDTH)
	var content_h := screen_rect.size.y
	var min_h := screen_rect.size.y
	var inner_min_size := Vector2.ZERO
	if _inner != null:
		inner_min_size = _inner.get_combined_minimum_size()
		min_h = int(ceil(inner_min_size.y)) + (_POPUP_PADDING * 2)
		content_h = maxi(screen_rect.size.y, min_h)  # At least row height, expand if needed

		size = Vector2i(popup_w, content_h)
		_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_inner.offset_left = _POPUP_PADDING
		_inner.offset_top = _POPUP_PADDING
		_inner.offset_right = -_POPUP_PADDING
		_inner.offset_bottom = -_POPUP_PADDING
	else:
		size = Vector2i(popup_w, screen_rect.size.y)

	if debug_mode:
		print("CellEditor._apply_popup_size:")
		print("  screen_rect: %s" % screen_rect)
		print("  inner min_size: %s" % inner_min_size)
		print("  calculated min_h (inner + padding): %d" % min_h)
		print("  row height: %d" % screen_rect.size.y)
		print("  final content_h: %d" % content_h)
		print("  popup size being set to: (%d, %d)" % [popup_w, content_h])
		_print_popup_size_debug.call_deferred(screen_rect)


func _print_popup_size_debug(screen_rect: Rect2i) -> void:
	if not debug_mode:
		return
	var inner_size := _inner.size if _inner != null else Vector2.ZERO
	print("CellEditor._post_layout_size:")
	print("  popup position: %s" % position)
	print("  popup size now: %s" % size)
	print("  expected row rect: %s" % screen_rect)
	print("  inner size now: %s" % inner_size)


# ---------------------------------------------------------------------------
# Private — inner control construction
# ---------------------------------------------------------------------------

func _rebuild_inner(col: ColumnDef, current: Variant) -> void:
	# Remove previous inner control if any.
	# Block signals before freeing to prevent stale focus_exited / value_changed
	# from firing after _committed has been reset for the next cell (tab navigation).
	if _inner != null:
		_inner.set_block_signals(true)
		_inner.queue_free()
		_inner = null

	# Create the appropriate CellField subclass based on property type and hints.
	if col.hint == PROPERTY_HINT_ENUM and col.property_type == TYPE_INT:
		var field := _ENUM_CELL_FIELD.new()
		field.populate(col.hint_string)
		field.set_value(int(current) if current != null else 0)
		_inner = field
	elif col.hint == PROPERTY_HINT_RESOURCE_TYPE and col.property_type == TYPE_OBJECT:
		var field := _RESOURCE_REF_CELL_FIELD.new()
		field.setup(col.hint_string)
		field.set_value(current)
		_inner = field
	else:
		match col.property_type:
			TYPE_ARRAY:
				var field := _COLLECTION_CELL_FIELD.new()
				field.setup(false)
				field.set_value(current)
				_inner = field
			TYPE_DICTIONARY:
				var field := _COLLECTION_CELL_FIELD.new()
				field.setup(true)
				field.set_value(current)
				_inner = field
			TYPE_BOOL:
				var field := _BOOL_CELL_FIELD.new()
				field.set_value(bool(current) if current != null else false)
				_inner = field
			TYPE_INT:
				var field := _NUMERIC_CELL_FIELD.new()
				field.setup(col, float(current) if current != null else 0.0, true)
				_inner = field
			TYPE_FLOAT:
				var field := _NUMERIC_CELL_FIELD.new()
				field.setup(col, float(current) if current != null else 0.0, false)
				_inner = field
			TYPE_COLOR:
				var field := _COLOR_CELL_FIELD.new()
				field.set_value(current if current is Color else Color.WHITE)
				_inner = field
			TYPE_STRING, TYPE_STRING_NAME:
				var field := _STRING_CELL_FIELD.new()
				field.set_value(str(current) if current != null else "")
				_inner = field
			_:
				# Unsupported type — close immediately rather than show an empty popup.
				return

	if _inner != null:
		add_child(_inner)
		# Wire the field's value_changed signal to our commit handler.
		if _inner.has_signal("value_changed"):
			_inner.value_changed.connect(func(new_value: Variant) -> void:
				if _committed:
					return
				_committed = true
				value_committed.emit(_resource, _property, _old_value, new_value)
				hide()
			)


## Delegate to CellField.get_value() to read the current editor value.
func _read_inner() -> Variant:
	if _inner == null:
		return _old_value
	if _inner.has_method("get_value"):
		return _inner.get_value()
	return _old_value


func _focus_inner() -> void:
	if _inner == null:
		return
	if _inner.has_method("focus_main"):
		_inner.focus_main()
	else:
		_inner.grab_focus()


# ---------------------------------------------------------------------------
# Private — commit / close
# ---------------------------------------------------------------------------

func _commit() -> void:
	if _resource == null or _committed:
		hide()
		return
	_committed = true
	var new_value: Variant = _read_inner()
	# Always emit — panel decides whether old==new is a no-op worth an undo step.
	value_committed.emit(_resource, _property, _old_value, new_value)
	hide()


func _on_close_requested() -> void:
	# Treat closing the popup as accepting the current value.
	_commit()
