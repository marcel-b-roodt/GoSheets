## Tests for BoolCellField.
## Run via GdUnit4.

extends GdUnitTestSuite

const BoolCellField := preload("res://addons/go_sheets/cells/bool_cell_field.gd")


# ---------------------------------------------------------------------------
# set_value / get_value
# ---------------------------------------------------------------------------

func test_set_value_true_checks_checkbox() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(true)
	assert_bool(field._check_box.button_pressed).is_true()

	remove_child(field)
	field.queue_free()


func test_set_value_false_unchecks_checkbox() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(false)
	assert_bool(field._check_box.button_pressed).is_false()

	remove_child(field)
	field.queue_free()


func test_set_value_null_defaults_to_false() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(null)
	assert_bool(field._check_box.button_pressed).is_false()

	remove_child(field)
	field.queue_free()


func test_get_value_returns_true_when_checked() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(true)
	assert_bool(field.get_value() as bool).is_true()

	remove_child(field)
	field.queue_free()


func test_get_value_returns_false_when_unchecked() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(false)
	assert_bool(field.get_value() as bool).is_false()

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# Label text reflects state
# ---------------------------------------------------------------------------

func test_set_value_true_shows_enabled_label() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(true)
	assert_str(field._check_box.text).is_equal("Enabled")

	remove_child(field)
	field.queue_free()


func test_set_value_false_shows_disabled_label() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(false)
	assert_str(field._check_box.text).is_equal("Disabled")

	remove_child(field)
	field.queue_free()


func test_toggle_updates_label_to_enabled() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(false)
	field._check_box.button_pressed = true
	field._on_toggled()

	assert_str(field._check_box.text).is_equal("Enabled")

	remove_child(field)
	field.queue_free()


func test_toggle_updates_label_to_disabled() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(true)
	field._check_box.button_pressed = false
	field._on_toggled()

	assert_str(field._check_box.text).is_equal("Disabled")

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# value_changed signal
# ---------------------------------------------------------------------------

func test_value_changed_emitted_on_toggle() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field.set_value(false)
	field._check_box.button_pressed = true
	field._on_toggled()

	assert_bool(emitted as bool).is_true()

	remove_child(field)
	field.queue_free()


func test_value_changed_emits_false_on_uncheck() -> void:
	var field := BoolCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field.set_value(true)
	field._check_box.button_pressed = false
	field._on_toggled()

	assert_bool(emitted as bool).is_false()

	remove_child(field)
	field.queue_free()
