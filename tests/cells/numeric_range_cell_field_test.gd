## Tests for NumericCellField — range spinbox+slider (PROPERTY_HINT_RANGE).
## Run via GdUnit4.

extends GdUnitTestSuite

const NumericCellField := preload("res://addons/go_sheets/cells/numeric_cell_field.gd")
const ColumnDef        := preload("res://addons/go_sheets/grid/column_def.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_range_int(hint_string: String, value: float) -> NumericCellField:
	var col := ColumnDef.new(&"mana_cost", TYPE_INT, PROPERTY_HINT_RANGE, hint_string)
	var field := NumericCellField.new()
	field.setup(col, value, true)
	add_child(field)
	return field


func _make_range_float(hint_string: String, value: float) -> NumericCellField:
	var col := ColumnDef.new(&"ratio", TYPE_FLOAT, PROPERTY_HINT_RANGE, hint_string)
	var field := NumericCellField.new()
	field.setup(col, value, false)
	add_child(field)
	return field


# ---------------------------------------------------------------------------
# Structure
# ---------------------------------------------------------------------------

func test_container_is_vbox() -> void:
	var field := _make_range_int("0,100,1", 0.0)
	await await_signal_on(field, "ready")

	assert_bool(field._container is VBoxContainer).is_true()

	remove_child(field)
	field.queue_free()


func test_has_slider() -> void:
	var field := _make_range_int("0,100,1", 0.0)
	await await_signal_on(field, "ready")

	assert_object(field._slider).is_not_null()

	remove_child(field)
	field.queue_free()


func test_vbox_child_zero_is_spinbox() -> void:
	var field := _make_range_int("0,100,1", 0.0)
	await await_signal_on(field, "ready")

	assert_bool((field._container as VBoxContainer).get_child(0) is SpinBox).is_true()

	remove_child(field)
	field.queue_free()


func test_vbox_child_one_is_slider() -> void:
	var field := _make_range_int("0,100,1", 0.0)
	await await_signal_on(field, "ready")

	assert_bool((field._container as VBoxContainer).get_child(1) is HSlider).is_true()

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# Bounds parsed from hint_string
# ---------------------------------------------------------------------------

func test_spinbox_min_matches_hint() -> void:
	var field := _make_range_int("10,200,5", 10.0)
	await await_signal_on(field, "ready")

	assert_float(field._spinbox.min_value).is_equal(10.0)

	remove_child(field)
	field.queue_free()


func test_spinbox_max_matches_hint() -> void:
	var field := _make_range_int("10,200,5", 10.0)
	await await_signal_on(field, "ready")

	assert_float(field._spinbox.max_value).is_equal(200.0)

	remove_child(field)
	field.queue_free()


func test_spinbox_step_matches_hint() -> void:
	var field := _make_range_int("0,100,5", 0.0)
	await await_signal_on(field, "ready")

	assert_float(field._spinbox.step).is_equal(5.0)

	remove_child(field)
	field.queue_free()


func test_slider_bounds_match_hint() -> void:
	var field := _make_range_float("0.0,1.0,0.1", 0.5)
	await await_signal_on(field, "ready")

	assert_float(field._slider.min_value).is_equal(0.0)
	assert_float(field._slider.max_value).is_equal(1.0)
	assert_float(field._slider.step).is_equal(0.1)

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# Initial value
# ---------------------------------------------------------------------------

func test_initial_value_set_on_spinbox() -> void:
	var field := _make_range_int("0,100,1", 42.0)
	await await_signal_on(field, "ready")

	assert_float(field._spinbox.value).is_equal(42.0)

	remove_child(field)
	field.queue_free()


func test_initial_value_set_on_slider() -> void:
	var field := _make_range_int("0,100,1", 42.0)
	await await_signal_on(field, "ready")

	assert_float(field._slider.value).is_equal(42.0)

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# Bidirectional sync
# ---------------------------------------------------------------------------

func test_changing_spinbox_updates_slider() -> void:
	var field := _make_range_int("0,100,1", 0.0)
	await await_signal_on(field, "ready")

	field._spinbox.value = 75
	assert_float(field._slider.value).is_equal(75.0)

	remove_child(field)
	field.queue_free()


func test_changing_slider_updates_spinbox() -> void:
	var field := _make_range_int("0,100,1", 0.0)
	await await_signal_on(field, "ready")

	field._slider.value = 30
	assert_float(field._spinbox.value).is_equal(30.0)

	remove_child(field)
	field.queue_free()


func test_sync_same_value_does_not_loop() -> void:
	# Setting the same value twice should not recurse.
	var field := _make_range_float("0.0,10.0,0.5", 5.0)
	await await_signal_on(field, "ready")

	field._spinbox.value = 5.0
	assert_float(field._slider.value).is_equal(5.0)  # no crash = pass

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# value_changed signal type
# ---------------------------------------------------------------------------

func test_int_value_changed_emits_int() -> void:
	var field := _make_range_int("0,100,1", 0.0)
	await await_signal_on(field, "ready")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field._spinbox.value = 55
	field._on_submitted()

	assert_bool(emitted is int).is_true()
	assert_int(emitted as int).is_equal(55)

	remove_child(field)
	field.queue_free()


func test_float_value_changed_emits_float() -> void:
	var field := _make_range_float("0.0,5.0,0.5", 0.0)
	await await_signal_on(field, "ready")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field._spinbox.value = 2.5
	field._on_submitted()

	assert_bool(emitted is float).is_true()
	assert_float(emitted as float).is_equal(2.5)

	remove_child(field)
	field.queue_free()
