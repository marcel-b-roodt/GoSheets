## Tests for GridRow keyboard handling.
## Run via GdUnit4.

extends GdUnitTestSuite

const GridRow   := preload("res://addons/go_sheets/grid/grid_row.gd")
const ColumnDef := preload("res://addons/go_sheets/grid/column_def.gd")

# ---------------------------------------------------------------------------
# Keyboard: Enter / F2 opens edit mode
# ---------------------------------------------------------------------------

func test_enter_key_emits_edit_requested() -> void:
	var row := GridRow.new()
	add_child(row)
	await await_ready(row)

	var emitted_row: int = -1
	var emitted_col: int = -1
	var emitted_shift: bool = false
	row.edit_requested.connect(func(r, c, s):
		emitted_row = r
		emitted_col = c
		emitted_shift = s)

	row.bind(5, _make_resource(), _make_columns(), [0, 120, 240], false)

	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	row._input(ev)

	assert_int(emitted_row).is_equal(5)
	assert_int(emitted_col).is_equal(0)  # first visible column
	assert_bool(emitted_shift).is_false()

	remove_child(row)
	row.queue_free()


func test_f2_key_emits_edit_requested() -> void:
	var row := GridRow.new()
	add_child(row)
	await await_ready(row)

	var emitted_row: int = -1
	row.edit_requested.connect(func(r, _c, _s): emitted_row = r)

	row.bind(3, _make_resource(), _make_columns(), [0, 120], false)

	var ev := InputEventKey.new()
	ev.keycode = KEY_F2
	ev.pressed = true
	row._input(ev)

	assert_int(emitted_row).is_equal(3)

	remove_child(row)
	row.queue_free()


# ---------------------------------------------------------------------------
# Keyboard: Tab emits edit_requested with shift=true
# ---------------------------------------------------------------------------

func test_tab_emits_edit_requested_with_shift_false() -> void:
	var row := GridRow.new()
	add_child(row)
	await await_ready(row)

	var emitted_shift: bool = true  # init to opposite to detect change
	row.edit_requested.connect(func(_r, _c, s): emitted_shift = s)

	row.bind(0, _make_resource(), _make_columns(), [0, 120, 240], false)

	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	ev.shift = false
	row._input(ev)

	assert_bool(emitted_shift).is_false()

	remove_child(row)
	row.queue_free()


func test_shift_tab_emits_edit_requested_with_shift_true() -> void:
	var row := GridRow.new()
	add_child(row)
	await await_ready(row)

	var emitted_shift: bool = false
	row.edit_requested.connect(func(_r, _c, s): emitted_shift = s)

	row.bind(0, _make_resource(), _make_columns(), [0, 120], false)

	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	ev.shift = true
	row._input(ev)

	assert_bool(emitted_shift).is_true()

	remove_child(row)
	row.queue_free()


# ---------------------------------------------------------------------------
# Keyboard: unhandled keys do not crash
# ---------------------------------------------------------------------------

func test_unhandled_key_does_not_crash() -> void:
	var row := GridRow.new()
	add_child(row)
	await await_ready(row)

	row.bind(0, _make_resource(), _make_columns(), [0], false)

	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	row._input(ev)  # Should not throw.

	remove_child(row)
	row.queue_free()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

class DummyResource extends Resource:
	var name: String = "test"
	var health: int = 100


func _make_resource() -> Resource:
	return DummyResource.new()


func _make_columns() -> Array:
	return [
		ColumnDef.new(&"name", TYPE_STRING, false, 120, "", 0),
		ColumnDef.new(&"health", TYPE_INT, false, 120, "", 0),
	]
