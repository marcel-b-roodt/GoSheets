## Tests for CellEditor popup sizing behavior.
## Run via GdUnit4.

extends GdUnitTestSuite

const CellEditor := preload("res://addons/go_sheets/grid/cell_editor.gd")
const ColumnDef  := preload("res://addons/go_sheets/grid/column_def.gd")


class DummyResource extends Resource:
	var values: Array = []


func test_popup_expands_beyond_narrow_column_for_collection_editor() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var col := ColumnDef.new(&"values", TYPE_ARRAY, PROPERTY_HINT_NONE, "")
	editor.open(DummyResource.new(), col, Rect2i(100, 100, 24, 24))
	await await_signal_on(editor, "visibility_changed")

	editor._apply_popup_size(Rect2i(100, 100, 24, 24))
	assert_int(editor.size.x).is_greater(24)

	remove_child(editor)
	editor.queue_free()
