## Tests for CollectionCellField.
## Run via GdUnit4.

extends GdUnitTestSuite

const CollectionCellField := preload("res://addons/go_sheets/cells/collection_cell_field.gd")


func test_array_set_value_formats_json() -> void:
	var field := CollectionCellField.new()
	field.setup(false)
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value([1, 2, 3])
	assert_bool(field._text_edit.text.find("1") >= 0).is_true()
	assert_bool(field._text_edit.text.find("2") >= 0).is_true()

	remove_child(field)
	field.queue_free()


func test_dictionary_set_value_formats_json() -> void:
	var field := CollectionCellField.new()
	field.setup(true)
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value({"name": "fire"})
	assert_bool(field._text_edit.text.find("name") >= 0).is_true()
	assert_bool(field._text_edit.text.find("fire") >= 0).is_true()

	remove_child(field)
	field.queue_free()


func test_apply_emits_value_changed_for_valid_array_json() -> void:
	var field := CollectionCellField.new()
	field.setup(false)
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field.set_value([])
	field._text_edit.text = "[10, 20]"
	field._on_apply_pressed()

	assert_bool(emitted is Array).is_true()
	assert_int((emitted as Array).size()).is_equal(2)
	assert_bool(field._error_label.visible).is_false()

	remove_child(field)
	field.queue_free()


func test_apply_rejects_invalid_json() -> void:
	var field := CollectionCellField.new()
	field.setup(false)
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted := false
	field.value_changed.connect(func(_v): emitted = true)

	field.set_value([1])
	field._text_edit.text = "[1,"
	field._on_apply_pressed()

	assert_bool(emitted).is_false()
	assert_bool(field._error_label.visible).is_true()

	remove_child(field)
	field.queue_free()


func test_apply_rejects_wrong_collection_kind() -> void:
	var field := CollectionCellField.new()
	field.setup(true)
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted := false
	field.value_changed.connect(func(_v): emitted = true)

	field.set_value({})
	field._text_edit.text = "[1, 2, 3]"
	field._on_apply_pressed()

	assert_bool(emitted).is_false()
	assert_bool(field._error_label.visible).is_true()

	remove_child(field)
	field.queue_free()
