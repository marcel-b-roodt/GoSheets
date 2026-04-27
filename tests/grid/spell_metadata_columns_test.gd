## Tests for SpellMetadata column derivation.
## Run via GdUnit4.

extends GdUnitTestSuite

const ColumnModel := preload("res://addons/go_sheets/grid/column_model.gd")


func test_spell_metadata_includes_spell_effects_array_column() -> void:
	var model := ColumnModel.build(&"SpellMetadata", [])
	var found := false
	var found_type := TYPE_NIL
	for c in model.columns:
		if c.property_name == &"spell_effects":
			found = true
			found_type = c.property_type
			break

	assert_bool(found).is_true()
	assert_int(found_type).is_equal(TYPE_ARRAY)
