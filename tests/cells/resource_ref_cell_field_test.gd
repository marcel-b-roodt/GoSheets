## Tests for ResourceRefCellField.
## Run via GdUnit4.

extends GdUnitTestSuite

const ResourceRefCellField := preload("res://addons/go_sheets/cells/resource_ref_cell_field.gd")


class DummyResource extends Resource:
	var label: String = ""


func test_setup_defaults_base_type_to_resource() -> void:
	var field := ResourceRefCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.setup("")
	assert_str(str(field._picker.get("base_type"))).is_equal("Resource")

	remove_child(field)
	field.queue_free()


func test_setup_applies_base_type_hint() -> void:
	var field := ResourceRefCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.setup("SpellMetadata")
	assert_str(str(field._picker.get("base_type"))).is_equal("SpellMetadata")

	remove_child(field)
	field.queue_free()


func test_set_and_get_value_round_trip_resource() -> void:
	var field := ResourceRefCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	var res := DummyResource.new()
	res.label = "alpha"
	field.set_value(res)

	var out: Variant = field.get_value()
	assert_object(out).is_not_null()
	assert_bool(out is DummyResource).is_true()
	assert_str((out as DummyResource).label).is_equal("alpha")

	remove_child(field)
	field.queue_free()


func test_set_value_null_clears_picker_resource() -> void:
	var field := ResourceRefCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	field.set_value(null)
	assert_object(field.get_value()).is_null()

	remove_child(field)
	field.queue_free()


func test_picker_change_emits_value_changed() -> void:
	var field := ResourceRefCellField.new()
	add_child(field)
	await await_signal_on(field, "ready")

	var emitted: Variant = null
	field.value_changed.connect(func(v): emitted = v)

	var res := DummyResource.new()
	res.label = "picked"
	field._on_picker_resource_changed(res)

	assert_object(emitted).is_not_null()
	assert_bool(emitted is DummyResource).is_true()
	assert_str((emitted as DummyResource).label).is_equal("picked")

	remove_child(field)
	field.queue_free()
