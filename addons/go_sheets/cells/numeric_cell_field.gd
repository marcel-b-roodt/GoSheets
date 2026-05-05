## NumericCellField
##
## A SpinBox for editing numeric values. If ColumnDef has PROPERTY_HINT_RANGE,
## adds a slider below the spinbox.

class_name NumericCellField
extends CellField

const _COLUMN_DEF_SCRIPT := preload("res://addons/go_sheets/grid/column_def.gd")

var _is_int: bool
var _container: Control  # VBoxContainer if range, otherwise just spinbox
var _spinbox: SpinBox
var _slider: HSlider

func _ready() -> void:
	pass  # _container is built in setup()

## Call this after construction to configure the field.
## [param col] — ColumnDef with type/hint info
## [param value] — initial value
## [param is_int] — whether to round values to integers
func setup(col: _COLUMN_DEF_SCRIPT, value: float, is_int: bool) -> void:
	_is_int = is_int

	if col.hint == PROPERTY_HINT_RANGE and col.hint_string != "":
		_build_range_container(col, value)
	else:
		_build_plain_spinbox(value)

	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

func set_value(value: Variant) -> void:
	_spinbox.value = float(value) if value != null else 0.0

func get_value() -> Variant:
	var raw := _spinbox.value
	return int(raw) if _is_int else raw

func focus_main() -> void:
	_spinbox.get_line_edit().grab_focus()
	_spinbox.get_line_edit().select_all()

func _build_plain_spinbox(value: float) -> void:
	_spinbox = SpinBox.new()
	_spinbox.step = 1.0 if _is_int else 0.001
	_spinbox.min_value = -1e9
	_spinbox.max_value = 1e9
	_spinbox.value = value
	_spinbox.rounded = _is_int
	_spinbox.get_line_edit().text_submitted.connect(func(_t: String) -> void: _on_submitted())
	_spinbox.focus_exited.connect(func() -> void: _on_focus_exited())
	_container = _spinbox

func _build_range_container(col: _COLUMN_DEF_SCRIPT, value: float) -> void:
	var parts := col.hint_string.split(",", false)
	var min_val := float(parts[0]) if parts.size() >= 1 else 0.0
	var max_val := float(parts[1]) if parts.size() >= 2 else 100.0
	var step    := float(parts[2]) if parts.size() >= 3 else 1.0

	_spinbox = SpinBox.new()
	_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spinbox.step = step
	_spinbox.min_value = min_val
	_spinbox.max_value = max_val
	_spinbox.value = value
	_spinbox.rounded = _is_int
	_spinbox.get_line_edit().text_submitted.connect(func(_t: String) -> void: _on_submitted())
	_spinbox.focus_exited.connect(func() -> void: _on_focus_exited())

	_slider = HSlider.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.min_value = min_val
	_slider.max_value = max_val
	_slider.step = step
	_slider.value = value
	_slider.rounded = _is_int
	_slider.focus_exited.connect(func() -> void: _on_focus_exited())

	# Keep spinbox and slider in sync.
	_spinbox.value_changed.connect(func(next_value: float) -> void:
		if abs(_slider.value - next_value) > 0.0001:
			_slider.value = next_value
	)
	_slider.value_changed.connect(func(next_value: float) -> void:
		if abs(_spinbox.value - next_value) > 0.0001:
			_spinbox.value = next_value
	)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_spinbox)
	vbox.add_child(_slider)
	_container = vbox

func _on_submitted() -> void:
	value_changed.emit(get_value())

func _on_focus_exited() -> void:
	# Only commit if focus left entirely (not moving within container).
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and (focus_owner == self or is_ancestor_of(focus_owner)):
		return
	value_changed.emit(get_value())

func _on_focus_exited() -> void:
	# Only commit if focus left entirely (not moving within container).
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and (focus_owner == self or is_ancestor_of(focus_owner)):
		return
	value_changed.emit(get_value())
