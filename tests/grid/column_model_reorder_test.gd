## Tests for ColumnModel visible-column reordering.
## Run via GdUnit4.
extends GdUnitTestSuite

const ColumnDef   := preload("res://addons/go_sheets/grid/column_def.gd")
const ColumnModel := preload("res://addons/go_sheets/grid/column_model.gd")


func test_move_visible_column_to_slot_reorders_columns() -> void:
	var model := _make_model([&"a", &"b", &"c"])

	var changed := model.move_visible_column_to_slot(0, 2)

	assert_bool(changed).is_true()
	assert_str(model.columns[0].property_name as String).is_equal("b")
	assert_str(model.columns[1].property_name as String).is_equal("a")
	assert_str(model.columns[2].property_name as String).is_equal("c")


func test_move_visible_column_to_slot_to_end_reorders_columns() -> void:
	var model := _make_model([&"a", &"b", &"c"])

	var changed := model.move_visible_column_to_slot(0, 3)

	assert_bool(changed).is_true()
	assert_str(model.columns[0].property_name as String).is_equal("b")
	assert_str(model.columns[1].property_name as String).is_equal("c")
	assert_str(model.columns[2].property_name as String).is_equal("a")


func test_move_visible_column_to_slot_returns_false_for_noop() -> void:
	var model := _make_model([&"a", &"b", &"c"])

	var changed := model.move_visible_column_to_slot(1, 1)

	assert_bool(changed).is_false()
	assert_str(model.columns[0].property_name as String).is_equal("a")
	assert_str(model.columns[1].property_name as String).is_equal("b")
	assert_str(model.columns[2].property_name as String).is_equal("c")


func _make_model(names: Array[StringName]) -> ColumnModel:
	var saved: Array = []
	for nm: StringName in names:
		saved.append(ColumnDef.new(nm, TYPE_INT).to_dict())
	return ColumnModel.build(&"", saved)
