## Tests for ColorCellField.
## Run via GdUnit4.

extends GdUnitTestSuite

const ColorCellField := preload("res://addons/go_sheets/cells/color_cell_field.gd")


# ---------------------------------------------------------------------------
# set_value / get_value
# ---------------------------------------------------------------------------

func test_set_value_sets_picker_color() -> void:
	var field := ColorCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(Color.RED)
	assert_bool(field._color_picker.color.is_equal_approx(Color.RED)).is_true()

	remove_child(field)
	field.queue_free()


func test_get_value_returns_current_color() -> void:
	var field := ColorCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(Color.BLUE)
	var v: Color = field.get_value()
	assert_bool((v as Color).is_equal_approx(Color.BLUE)).is_true()

	remove_child(field)
	field.queue_free()


func test_set_value_non_color_defaults_to_white() -> void:
	var field := ColorCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(null)
	assert_bool(field._color_picker.color.is_equal_approx(Color.WHITE)).is_true()

	remove_child(field)
	field.queue_free()


func test_set_value_with_alpha() -> void:
	var field := ColorCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	var c := Color(0.2, 0.4, 0.6, 0.5)
	field.set_value(c)
	assert_bool(field._color_picker.color.is_equal_approx(c)).is_true()

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# value_changed signal
# ---------------------------------------------------------------------------

func test_value_changed_emitted_on_popup_closed() -> void:
	var field := ColorCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(Color.GREEN)

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field._on_popup_closed()

	assert_bool(emitted != null).is_true()
	assert_bool((emitted as Color).is_equal_approx(Color.GREEN)).is_true()

	remove_child(field)
	field.queue_free()
