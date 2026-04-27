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


func test_dictionary_set_value_populates_rows() -> void:
	var field := CollectionCellField.new()
	field.setup(true)
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value({"name": "fire", "damage": 10})
	# Row editor should have two rows
	assert_int(field._dict_rows.get_child_count()).is_equal(2)
	# First row key should be "name"
	var row0 := field._dict_rows.get_child(0) as HBoxContainer
	var key0 := row0.get_child(0) as LineEdit
	assert_str(key0.text).is_equal("name")
	# TextEdit should be hidden in dictionary mode
	assert_bool(field._text_edit.visible).is_false()
	assert_bool(field._dict_scroll.visible).is_true()

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


func test_dict_apply_emits_value_changed() -> void:
	var field := CollectionCellField.new()
	field.setup(true)
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field.set_value({"hp": "100"})
	# Mutate the first row's value edit
	var row := field._dict_rows.get_child(0) as HBoxContainer
	var val_edit := row.get_child(2) as LineEdit
	val_edit.text = "999"
	field._on_apply_pressed()

	assert_bool(emitted is Dictionary).is_true()
	assert_bool((emitted as Dictionary).has("hp")).is_true()
	assert_int(int((emitted as Dictionary)["hp"])).is_equal(999)
	assert_bool(field._error_label.visible).is_false()

	remove_child(field)
	field.queue_free()


func test_dict_apply_rejects_duplicate_keys() -> void:
	var field := CollectionCellField.new()
	field.setup(true)
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted := false
	field.value_changed.connect(func(_v): emitted = true)

	field.set_value({})
	# Add two rows with the same key
	field._append_dict_row("key", "1")
	field._append_dict_row("key", "2")
	field._on_apply_pressed()

	assert_bool(emitted).is_false()
	assert_bool(field._error_label.visible).is_true()

	remove_child(field)
	field.queue_free()


func test_dict_reset_restores_rows() -> void:
	var field := CollectionCellField.new()
	field.setup(true)
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value({"x": "1"})
	# Add an extra unsaved row then reset
	field._append_dict_row("extra", "")
	assert_int(field._dict_rows.get_child_count()).is_equal(2)
	field._on_reset_pressed()
	await get_tree().process_frame
	assert_int(field._dict_rows.get_child_count()).is_equal(1)

	remove_child(field)
	field.queue_free()


func test_resource_array_set_value_formats_as_path_lines() -> void:
	var field := CollectionCellField.new()
	field.setup(false, PROPERTY_HINT_ARRAY_TYPE, "SpellMetadata")
	add_child(field)
	await await_signal_on(field, "ready")

	var fireball := load("res://test_scenes/data/spells/fireball.tres")
	field.set_value([fireball])

	assert_bool(field._resource_array_mode).is_true()
	assert_bool(
		field._text_edit.text.find("res://test_scenes/data/spells/fireball.tres") >= 0
	).is_true()
	assert_bool(field._text_edit.text.find("<Resource#") < 0).is_true()

	remove_child(field)
	field.queue_free()


func test_apply_resource_paths_emits_resource_array() -> void:
	var field := CollectionCellField.new()
	field.setup(false, PROPERTY_HINT_ARRAY_TYPE, "SpellMetadata")
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	field.set_value([])
	field._text_edit.text = (
		"res://test_scenes/data/spells/fireball.tres\n"
		+ "res://test_scenes/data/spells/ice_shard.tres"
	)
	field._on_apply_pressed()

	assert_bool(emitted is Array).is_true()
	assert_int((emitted as Array).size()).is_equal(2)
	assert_bool((emitted as Array)[0] is Resource).is_true()
	assert_bool((emitted as Array)[1] is Resource).is_true()
	assert_bool(field._error_label.visible).is_false()

	remove_child(field)
	field.queue_free()
