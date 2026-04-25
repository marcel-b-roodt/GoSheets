## Tests for EnumCellField.
## Run via GdUnit4.

extends GdUnitTestSuite

const EnumCellField := preload("res://addons/go_sheets/cells/enum_cell_field.gd")


# ---------------------------------------------------------------------------
# populate — simple name list
# ---------------------------------------------------------------------------

func test_populate_simple_adds_correct_count() -> void:
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.populate("Fire,Water,Earth")
	assert_int(field._option_button.item_count).is_equal(3)

	remove_child(field)
	field.queue_free()


func test_populate_simple_assigns_auto_ids() -> void:
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.populate("Fire,Water,Earth")
	assert_int(field._option_button.get_item_id(0)).is_equal(0)
	assert_int(field._option_button.get_item_id(1)).is_equal(1)
	assert_int(field._option_button.get_item_id(2)).is_equal(2)

	remove_child(field)
	field.queue_free()


func test_populate_simple_assigns_correct_labels() -> void:
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.populate("Fire,Water,Earth")
	assert_str(field._option_button.get_item_text(0)).is_equal("Fire")
	assert_str(field._option_button.get_item_text(1)).is_equal("Water")
	assert_str(field._option_button.get_item_text(2)).is_equal("Earth")

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# populate — explicit values (Name:int format)
# ---------------------------------------------------------------------------

func test_populate_explicit_values_assigned_correctly() -> void:
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.populate("None:0,Rare:5,Epic:10")
	assert_int(field._option_button.get_item_id(0)).is_equal(0)
	assert_int(field._option_button.get_item_id(1)).is_equal(5)
	assert_int(field._option_button.get_item_id(2)).is_equal(10)

	remove_child(field)
	field.queue_free()


func test_populate_mixed_explicit_and_auto_values() -> void:
	# "Weak:0,Normal,Strong:10" → ids should be 0, 1, 10
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.populate("Weak:0,Normal,Strong:10")
	assert_int(field._option_button.get_item_id(0)).is_equal(0)
	assert_int(field._option_button.get_item_id(1)).is_equal(1)
	assert_int(field._option_button.get_item_id(2)).is_equal(10)

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# set_value / get_value
# ---------------------------------------------------------------------------

func test_get_value_returns_item_id_at_selection() -> void:
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.populate("None:0,Rare:5,Epic:10")
	field.set_value(1)  # index 1 = id 5 (Rare)
	assert_int(field.get_value() as int).is_equal(5)

	remove_child(field)
	field.queue_free()


func test_set_value_zero_selects_first_item() -> void:
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.populate("Fire,Water,Earth")
	field.set_value(0)
	assert_int(field._option_button.selected).is_equal(0)

	remove_child(field)
	field.queue_free()


func test_set_value_clamps_to_valid_range() -> void:
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.populate("A,B,C")
	field.set_value(999)
	assert_int(field._option_button.selected).is_equal(2)

	remove_child(field)
	field.queue_free()


func test_get_value_returns_zero_when_no_selection() -> void:
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	# No populate — item_count is 0, selected is -1.
	assert_int(field.get_value() as int).is_equal(0)

	remove_child(field)
	field.queue_free()


# ---------------------------------------------------------------------------
# value_changed signal
# ---------------------------------------------------------------------------

func test_value_changed_emitted_on_item_selected() -> void:
	var field := EnumCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.populate("Fire,Water,Earth")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field._option_button.selected = 2
	field._on_selected()

	assert_int(emitted as int).is_equal(2)

	remove_child(field)
	field.queue_free()
