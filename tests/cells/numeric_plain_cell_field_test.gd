## Tests for NumericCellField — plain spinbox (no range hint).
## Run via GdUnit4.

extends GdUnitTestSuite

const NumericCellField := preload("res://addons/go_sheets/cells/numeric_cell_field.gd")
const ColumnDef        := preload("res://addons/go_sheets/grid/column_def.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_plain_int(value: float) -> NumericCellField:
	var col := ColumnDef.new(&"damage", TYPE_INT)
	var field := NumericCellField.new()
	field.setup(col, value, true)
	add_child(field)
	return field


func _make_plain_float(value: float) -> NumericCellField:
	var col := ColumnDef.new(&"speed", TYPE_FLOAT)
	var field := NumericCellField.new()
	field.setup(col, value, false)
	add_child(field)
	return field


# ---------------------------------------------------------------------------
# Structure
# ---------------------------------------------------------------------------

func test_container_is_spinbox() -> void:
	var field := _make_plain_int(0.0)
	await await_signal_on(field, "ready")

	assert_bool(field._container is SpinBox).is_true()

	remove_child(field)
	field.queue_free()


func test_has_no_slider() -> void:
	var field := _make_plain_int(0.0)
	await await_signal_on(field, "ready")

	assert_object(field._slider).is_null()

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# Bounds and step
# ---------------------------------------------------------------------------

func test_int_step_is_one() -> void:
	var field := _make_plain_int(0.0)
	await await_signal_on(field, "ready")

	assert_float(field._spinbox.step).is_equal(1.0)

	remove_child(field)
	field.queue_free()


func test_float_step_is_small() -> void:
	var field := _make_plain_float(0.0)
	await await_signal_on(field, "ready")

	assert_float(field._spinbox.step).is_equal(0.001)

	remove_child(field)
	field.queue_free()


func test_has_wide_bounds() -> void:
	var field := _make_plain_int(0.0)
	await await_signal_on(field, "ready")

	assert_float(field._spinbox.min_value).is_less_equal(-1e8)
	assert_float(field._spinbox.max_value).is_greater_equal(1e8)

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# set_value / get_value
# ---------------------------------------------------------------------------

func test_initial_value_set_on_spinbox() -> void:
	var field := _make_plain_int(7.0)
	await await_signal_on(field, "ready")

	assert_float(field._spinbox.value).is_equal(7.0)

	remove_child(field)
	field.queue_free()


func test_set_value_updates_spinbox() -> void:
	var field := _make_plain_int(0.0)
	await await_signal_on(field, "ready")

	field.set_value(42)
	assert_float(field._spinbox.value).is_equal(42.0)

	remove_child(field)
	field.queue_free()


func test_set_value_null_defaults_to_zero() -> void:
	var field := _make_plain_int(5.0)
	await await_signal_on(field, "ready")

	field.set_value(null)
	assert_float(field._spinbox.value).is_equal(0.0)

	remove_child(field)
	field.queue_free()


func test_int_get_value_returns_int_type() -> void:
	var field := _make_plain_int(7.0)
	await await_signal_on(field, "ready")

	assert_bool(field.get_value() is int).is_true()
	assert_int(field.get_value() as int).is_equal(7)

	remove_child(field)
	field.queue_free()


func test_float_get_value_returns_float_type() -> void:
	var field := _make_plain_float(3.5)
	await await_signal_on(field, "ready")

	assert_bool(field.get_value() is float).is_true()
	assert_float(field.get_value() as float).is_equal(3.5)

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# value_changed signal
# ---------------------------------------------------------------------------

func test_value_changed_emitted_on_submitted() -> void:
	var field := _make_plain_int(0.0)
	await await_signal_on(field, "ready")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field._spinbox.value = 10
	field._on_submitted()

	assert_int(emitted as int).is_equal(10)

	remove_child(field)
	field.queue_free()
