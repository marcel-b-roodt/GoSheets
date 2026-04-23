## Tests for ColumnDef and ColumnModel.
## Run via GdUnit4.
extends GdUnitTestSuite

const ColumnDef   := preload("res://addons/go_sheets/grid/column_def.gd")
const ColumnModel := preload("res://addons/go_sheets/grid/column_model.gd")

# ---------------------------------------------------------------------------
# ColumnDef — construction and display name
# ---------------------------------------------------------------------------

func test_display_name_replaces_underscores_with_spaces() -> void:
	var col := ColumnDef.new(&"attack_damage", TYPE_INT)
	assert_str(col.display_name).is_equal("Attack damage")


func test_display_name_capitalises_first_letter() -> void:
	var col := ColumnDef.new(&"speed", TYPE_FLOAT)
	assert_str(col.display_name).is_equal("Speed")


func test_display_name_empty_when_property_name_empty() -> void:
	var col := ColumnDef.new(&"", TYPE_NIL)
	assert_str(col.display_name).is_equal("")


func test_defaults_visible_true() -> void:
	var col := ColumnDef.new(&"value", TYPE_INT)
	assert_bool(col.visible).is_true()


func test_defaults_width_120() -> void:
	var col := ColumnDef.new(&"value", TYPE_INT)
	assert_int(col.width).is_equal(120)


func test_defaults_pinned_false() -> void:
	var col := ColumnDef.new(&"value", TYPE_INT)
	assert_bool(col.pinned).is_false()


func test_defaults_sort_direction_zero() -> void:
	var col := ColumnDef.new(&"value", TYPE_INT)
	assert_int(col.sort_direction).is_equal(0)


# ---------------------------------------------------------------------------
# ColumnDef — round-trip serialisation
# ---------------------------------------------------------------------------

func test_to_dict_contains_all_keys() -> void:
	var col := ColumnDef.new(&"damage", TYPE_INT)
	var d := col.to_dict()
	for key in ["property_name", "display_name", "property_type",
				"hint_string", "hint", "visible", "width", "pinned", "sort_direction"]:
		assert_bool(d.has(key)).is_true()


func test_from_dict_restores_property_name() -> void:
	var col := ColumnDef.new(&"speed", TYPE_FLOAT)
	col.width = 200
	col.visible = false
	var restored := ColumnDef.from_dict(col.to_dict())
	assert_str(restored.property_name as String).is_equal("speed")


func test_from_dict_restores_width() -> void:
	var col := ColumnDef.new(&"speed", TYPE_FLOAT)
	col.width = 200
	var restored := ColumnDef.from_dict(col.to_dict())
	assert_int(restored.width).is_equal(200)


func test_from_dict_restores_visible_false() -> void:
	var col := ColumnDef.new(&"speed", TYPE_FLOAT)
	col.visible = false
	var restored := ColumnDef.from_dict(col.to_dict())
	assert_bool(restored.visible).is_false()


func test_from_dict_restores_sort_direction() -> void:
	var col := ColumnDef.new(&"name", TYPE_STRING)
	col.sort_direction = 1
	var restored := ColumnDef.from_dict(col.to_dict())
	assert_int(restored.sort_direction).is_equal(1)

# ---------------------------------------------------------------------------
# ColumnModel — build from saved dicts
# ---------------------------------------------------------------------------

func _make_saved_dicts(names: Array[StringName]) -> Array:
	var out: Array = []
	for nm: StringName in names:
		out.append(ColumnDef.new(nm, TYPE_INT).to_dict())
	return out


func test_build_from_saved_dicts_restores_column_count() -> void:
	var saved := _make_saved_dicts([&"damage", &"speed"])
	var model := ColumnModel.build(&"", saved)
	assert_int(model.columns.size()).is_equal(2)


func test_build_from_saved_dicts_preserves_order() -> void:
	var saved := _make_saved_dicts([&"speed", &"damage"])
	var model := ColumnModel.build(&"", saved)
	assert_str(model.columns[0].property_name as String).is_equal("speed")
	assert_str(model.columns[1].property_name as String).is_equal("damage")


func test_visible_columns_excludes_hidden() -> void:
	var saved := _make_saved_dicts([&"a", &"b", &"c"])
	var model := ColumnModel.build(&"", saved)
	model.columns[1].visible = false
	var vis := model.visible_columns()
	assert_int(vis.size()).is_equal(2)
	assert_str(vis[0].property_name as String).is_equal("a")
	assert_str(vis[1].property_name as String).is_equal("c")


func test_visible_columns_puts_pinned_first() -> void:
	var saved := _make_saved_dicts([&"a", &"b", &"c"])
	var model := ColumnModel.build(&"", saved)
	model.columns[2].pinned = true   # "c" is pinned
	var vis := model.visible_columns()
	assert_str(vis[0].property_name as String).is_equal("c")


func test_to_dicts_round_trips_all_columns() -> void:
	var saved := _make_saved_dicts([&"x", &"y"])
	var model := ColumnModel.build(&"", saved)
	var out := model.to_dicts()
	assert_int(out.size()).is_equal(2)


# ---------------------------------------------------------------------------
# ColumnModel — build from real ClassDB type (Resource itself)
# ---------------------------------------------------------------------------

func test_build_from_resource_returns_model() -> void:
	# Resource has user-visible @export properties in some subclasses.
	# Calling build on a built-in that has no @export gives an empty list —
	# that's valid; we just check it doesn't crash.
	var model := ColumnModel.build(&"Resource", [])
	assert_object(model).is_not_null()
