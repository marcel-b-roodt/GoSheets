## Tests for StringCellField.
## Run via GdUnit4.

extends GdUnitTestSuite

const StringCellField := preload("res://addons/go_sheets/cells/string_cell_field.gd")


# ---------------------------------------------------------------------------
# set_value / get_value
# ---------------------------------------------------------------------------

func test_set_value_updates_line_edit_text() -> void:
	var field := StringCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value("hello")
	assert_str(field._line_edit.text).is_equal("hello")

	remove_child(field)
	field.queue_free()


func test_get_value_returns_current_text() -> void:
	var field := StringCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value("world")
	assert_str(field.get_value() as String).is_equal("world")

	remove_child(field)
	field.queue_free()


func test_set_value_null_clears_text() -> void:
	var field := StringCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(null)
	assert_str(field._line_edit.text).is_equal("")

	remove_child(field)
	field.queue_free()


func test_set_value_empty_string() -> void:
	var field := StringCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value("")
	assert_str(field._line_edit.text).is_equal("")

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# value_changed signal
# ---------------------------------------------------------------------------

func test_value_changed_emitted_on_text_submitted() -> void:
	var field := StringCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted_value: Variant = null
	field.value_changed.connect(func(v): emitted_value = v)

	field._line_edit.text = "submitted"
	field._on_submitted()

	assert_str(str(emitted_value)).is_equal("submitted")

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# select_all_on_focus
# ---------------------------------------------------------------------------

func test_line_edit_has_select_all_on_focus() -> void:
	var field := StringCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	assert_bool(field._line_edit.select_all_on_focus).is_true()

	remove_child(field)
	field.queue_free()
