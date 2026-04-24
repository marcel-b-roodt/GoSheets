## Tests for CellEditor keyboard handling and navigation.
## Run via GdUnit4.

extends GdUnitTestSuite

const CellEditor := preload("res://addons/go_sheets/grid/cell_editor.gd")
const ColumnDef  := preload("res://addons/go_sheets/grid/column_def.gd")

# ---------------------------------------------------------------------------
# _input() --- escape cancels without emitting committed
# ---------------------------------------------------------------------------

func test_escape_does_not_emit_value_committed() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_ready(editor)

	var committed := false
	editor.value_committed.connect(func(_r, _p, _o, _n): committed = true)

	var col := ColumnDef.new(&"name", TYPE_STRING, false, 120, "", 0)
	col.hint_string = ""
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_property(editor, "visible", true, 2000)

	# Simulate Escape key press.
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	editor._input(ev)

	assert_bool(committed).is_false()
	remove_child(editor)
	editor.queue_free()


func test_escape_closes_editor() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_ready(editor)

	var col := ColumnDef.new(&"health", TYPE_INT, false, 120, "", 0)
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_property(editor, "visible", true, 2000)

	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	editor._input(ev)

	assert_bool(editor.visible).is_false()
	remove_child(editor)
	editor.queue_free()


# ---------------------------------------------------------------------------
# _input() --- tab commits and emits tab_pressed
# ---------------------------------------------------------------------------

func test_tab_emits_tab_pressed_not_shift() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_ready(editor)

	var tab_received := false
	var shift_received := false
	editor.tab_pressed.connect(func(is_shift):
		tab_received = true
		shift_received = is_shift)

	var col := ColumnDef.new(&"damage", TYPE_FLOAT, false, 120, "", 0)
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_property(editor, "visible", true, 2000)

	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	ev.shift = false
	editor._input(ev)

	assert_bool(tab_received).is_true()
	assert_bool(shift_received).is_false()
	remove_child(editor)
	editor.queue_free()


func test_shift_tab_emits_tab_pressed_with_shift() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_ready(editor)

	var tab_received := false
	var shift_received := false
	editor.tab_pressed.connect(func(is_shift):
		tab_received = true
		shift_received = is_shift)

	var col := ColumnDef.new(&"speed", TYPE_INT, false, 120, "", 0)
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_property(editor, "visible", true, 2000)

	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	ev.shift = true
	editor._input(ev)

	assert_bool(tab_received).is_true()
	assert_bool(shift_received).is_true()
	remove_child(editor)
	editor.queue_free()


func test_tab_does_not_emit_when_editor_not_visible() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_ready(editor)

	var received := false
	editor.tab_pressed.connect(func(_s): received = true)

	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	editor._input(ev)

	assert_bool(received).is_false()
	remove_child(editor)
	editor.queue_free()


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

class DummyResource extends Resource:
	var name: String = "test"
	var health: int = 100
	var damage: float = 5.0
	var speed: int = 42


func _make_dummy_resource() -> Resource:
	return DummyResource.new()
