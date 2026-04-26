## Tests for ResourceGrid keyboard navigation (Tab/Shift+Tab).
## Run via GdUnit4.

extends GdUnitTestSuite

const ResourceGrid := preload("res://addons/go_sheets/grid/resource_grid.gd")
const ColumnModel  := preload("res://addons/go_sheets/grid/column_model.gd")
const ColumnDef    := preload("res://addons/go_sheets/grid/column_def.gd")


func test_tab_wraps_to_first_editable_column_on_next_row() -> void:
	var grid := _make_grid_with_columns_and_rows(3, 2)
	# Start at row 0, last editable column.
	grid._edit_row = 0
	grid._edit_col = 2

	grid._on_cell_tab_pressed(false)

	assert_int(grid._edit_row).is_equal(1)
	assert_int(grid._edit_col).is_equal(0)
	_cleanup_grid(grid)


func test_shift_tab_wraps_to_last_editable_column_on_previous_row() -> void:
	var grid := _make_grid_with_columns_and_rows(3, 2)
	# Start at row 1, first editable column.
	grid._edit_row = 1
	grid._edit_col = 0

	grid._on_cell_tab_pressed(true)

	assert_int(grid._edit_row).is_equal(0)
	assert_int(grid._edit_col).is_equal(2)
	_cleanup_grid(grid)


func test_tab_at_last_cell_cycles_to_first_cell() -> void:
	var grid := _make_grid_with_columns_and_rows(3, 2)
	# Start at global last editable cell.
	grid._edit_row = 1
	grid._edit_col = 2

	grid._on_cell_tab_pressed(false)

	assert_int(grid._edit_row).is_equal(0)
	assert_int(grid._edit_col).is_equal(0)
	_cleanup_grid(grid)


func test_shift_tab_at_first_cell_cycles_to_last_cell() -> void:
	var grid := _make_grid_with_columns_and_rows(3, 2)
	# Start at global first editable cell.
	grid._edit_row = 0
	grid._edit_col = 0

	grid._on_cell_tab_pressed(true)

	assert_int(grid._edit_row).is_equal(1)
	assert_int(grid._edit_col).is_equal(2)
	_cleanup_grid(grid)


func test_tab_skips_collapsed_columns() -> void:
	var grid := _make_grid_with_columns_and_rows(3, 2)
	# Collapse middle column and ensure traversal jumps 0 -> 2.
	grid._column_model.columns[1].collapsed = true
	grid._compute_column_offsets()
	grid._edit_row = 0
	grid._edit_col = 0

	grid._on_cell_tab_pressed(false)

	assert_int(grid._edit_row).is_equal(0)
	assert_int(grid._edit_col).is_equal(2)
	_cleanup_grid(grid)


func test_apply_column_reorder_updates_model_order() -> void:
	var grid := _make_grid_with_columns_and_rows(3, 1)

	var changed := grid._apply_column_reorder(0, 3)

	assert_bool(changed).is_true()
	assert_str(grid._column_model.columns[0].property_name as String).is_equal("col_1")
	assert_str(grid._column_model.columns[1].property_name as String).is_equal("col_2")
	assert_str(grid._column_model.columns[2].property_name as String).is_equal("col_0")
	_cleanup_grid(grid)


func test_slot_at_x_maps_mouse_to_expected_drop_slot() -> void:
	var grid := _make_grid_with_columns_and_rows(3, 1)
	var vis := grid._column_model.visible_columns()

	assert_int(grid._slot_at_x(10.0, vis)).is_equal(0)
	assert_int(grid._slot_at_x(70.0, vis)).is_equal(1)
	assert_int(grid._slot_at_x(190.0, vis)).is_equal(2)
	assert_int(grid._slot_at_x(500.0, vis)).is_equal(3)
	_cleanup_grid(grid)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

class DummyRow extends Resource:
	var name: String = ""
	var value: int = 0


func _make_grid_with_columns_and_rows(col_count: int, row_count: int) -> ResourceGrid:
	var grid := ResourceGrid.new()
	add_child(grid)
	if not grid.is_node_ready():
		grid._build_ui()

	var saved: Array = []
	for i in col_count:
		var c := ColumnDef.new(StringName("col_%d" % i), TYPE_STRING, PROPERTY_HINT_NONE, "")
		saved.append(c.to_dict())
	var model := ColumnModel.build(&"", saved)

	var rows: Array[Resource] = []
	for i in row_count:
		rows.append(_make_row(i))
	grid.load_data(model, rows)
	return grid


func _cleanup_grid(grid: ResourceGrid) -> void:
	remove_child(grid)
	grid.queue_free()


func _make_row(idx: int) -> Resource:
	var r := DummyRow.new()
	r.name = "row_%d" % idx
	r.value = idx
	return r
