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
	await await_signal_on(editor, "ready")

	var committed := false
	editor.value_committed.connect(func(_r, _p, _o, _n): committed = true)

	var col := ColumnDef.new(&"name", TYPE_STRING, PROPERTY_HINT_NONE, "")
	col.hint_string = ""
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

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
	await await_signal_on(editor, "ready")

	var col := ColumnDef.new(&"health", TYPE_INT, PROPERTY_HINT_NONE, "")
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	editor._input(ev)

	assert_bool(editor.visible).is_false()
	remove_child(editor)
	editor.queue_free()


func test_close_requested_commits_pending_range_spinbox_value() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var committed := false
	var committed_value: Variant = null
	editor.value_committed.connect(func(_r, _p, _o, n):
		committed = true
		committed_value = n)

	var col := ColumnDef.new(&"mana_cost", TYPE_INT, PROPERTY_HINT_RANGE, "0,100,1")
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

	var container := editor._inner as VBoxContainer
	var spinbox := container.get_child(0) as SpinBox
	var slider := container.get_child(1) as HSlider
	spinbox.value = 25

	assert_float(slider.value).is_equal(25.0)
	editor._on_close_requested()

	assert_bool(committed).is_true()
	assert_int(int(committed_value)).is_equal(25)
	remove_child(editor)
	editor.queue_free()


func test_range_slider_updates_spinbox_value() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var col := ColumnDef.new(&"mana_cost", TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,10,0.5")
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

	var container := editor._inner as VBoxContainer
	var spinbox := container.get_child(0) as SpinBox
	var slider := container.get_child(1) as HSlider
	slider.value = 7.5

	assert_float(spinbox.value).is_equal(7.5)
	remove_child(editor)
	editor.queue_free()


func test_string_submit_commits_updated_value_once() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var commit_count := 0
	var old_value: Variant = null
	var new_value: Variant = null
	editor.value_committed.connect(func(_r, _p, old_v, new_v):
		commit_count += 1
		old_value = old_v
		new_value = new_v)

	var resource := _make_dummy_resource()
	var col := ColumnDef.new(&"name", TYPE_STRING, PROPERTY_HINT_NONE, "")
	editor.open(resource, col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

	var field := editor._inner

	field._line_edit.text = "renamed"
	field._on_submitted()
	editor._on_close_requested()

	assert_int(commit_count).is_equal(1)
	assert_str(old_value as String).is_equal("test")
	assert_str(new_value as String).is_equal("renamed")
	assert_bool(editor.visible).is_false()

	remove_child(editor)
	editor.queue_free()


func test_string_focus_exit_commits_updated_value() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var committed := false
	var committed_value: Variant = null
	editor.value_committed.connect(func(_r, _p, _o, n):
		committed = true
		committed_value = n)

	var col := ColumnDef.new(&"name", TYPE_STRING, PROPERTY_HINT_NONE, "")
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

	var field := editor._inner
	field._line_edit.text = "focus-commit"
	field._on_focus_exited()

	assert_bool(committed).is_true()
	assert_str(committed_value as String).is_equal("focus-commit")
	assert_bool(editor.visible).is_false()

	remove_child(editor)
	editor.queue_free()


func test_plain_numeric_focus_exit_commits_int_value() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var committed := false
	var committed_old: Variant = null
	var committed_new: Variant = null
	editor.value_committed.connect(func(_r, _p, old_v, new_v):
		committed = true
		committed_old = old_v
		committed_new = new_v)

	var col := ColumnDef.new(&"health", TYPE_INT, PROPERTY_HINT_NONE, "")
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

	var field := editor._inner
	field._spinbox.value = 133
	field._on_focus_exited()

	assert_bool(committed).is_true()
	assert_int(int(committed_old)).is_equal(100)
	assert_bool(committed_new is int).is_true()
	assert_int(int(committed_new)).is_equal(133)
	assert_bool(editor.visible).is_false()

	remove_child(editor)
	editor.queue_free()


func test_range_numeric_submit_commits_float_value() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var committed := false
	var committed_value: Variant = null
	editor.value_committed.connect(func(_r, _p, _o, n):
		committed = true
		committed_value = n)

	var col := ColumnDef.new(&"damage", TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,10,0.5")
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

	var field := editor._inner
	field._spinbox.value = 6.5
	field._on_submitted()

	assert_bool(committed).is_true()
	assert_bool(committed_value is float).is_true()
	assert_float(float(committed_value)).is_equal(6.5)
	assert_bool(editor.visible).is_false()

	remove_child(editor)
	editor.queue_free()


# ---------------------------------------------------------------------------
# _input() --- tab commits and emits tab_pressed
# ---------------------------------------------------------------------------

func test_tab_emits_tab_pressed_not_shift() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var tab_received := false
	var shift_received := false
	editor.tab_pressed.connect(func(is_shift):
		tab_received = true
		shift_received = is_shift)

	var col := ColumnDef.new(&"damage", TYPE_FLOAT, PROPERTY_HINT_NONE, "")
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

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
	await await_signal_on(editor, "ready")

	var tab_received := false
	var shift_received := false
	editor.tab_pressed.connect(func(is_shift):
		tab_received = true
		shift_received = is_shift)

	var col := ColumnDef.new(&"speed", TYPE_INT, PROPERTY_HINT_NONE, "")
	editor.open(_make_dummy_resource(), col, Rect2i(100, 100, 120, 24))
	await await_signal_on(editor, "visibility_changed")

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
	await await_signal_on(editor, "ready")

	var received := false
	editor.tab_pressed.connect(func(_s): received = true)

	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	editor._input(ev)

	assert_bool(received).is_false()
	remove_child(editor)
	editor.queue_free()


func test_resource_reference_picker_emits_committed_resource() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var committed := false
	var committed_new: Variant = null
	editor.value_committed.connect(func(_r, _p, _o, n):
		committed = true
		committed_new = n)

	var owner := ResourceOwner.new()
	var col := ColumnDef.new(&"spell_ref", TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "SpellMetadata")
	editor.open(owner, col, Rect2i(100, 100, 220, 24))
	await await_signal_on(editor, "visibility_changed")

	var picked := SpellMetadata.new()
	editor._inner.value_changed.emit(picked)

	assert_bool(committed).is_true()
	assert_bool(committed_new is SpellMetadata).is_true()
	assert_bool(editor.visible).is_false()

	remove_child(editor)
	editor.queue_free()


func test_array_collection_apply_emits_committed_array() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var committed := false
	var committed_new: Variant = null
	editor.value_committed.connect(func(_r, _p, _o, n):
		committed = true
		committed_new = n)

	var owner := CollectionOwner.new()
	var col := ColumnDef.new(&"values", TYPE_ARRAY, PROPERTY_HINT_NONE, "")
	editor.open(owner, col, Rect2i(100, 100, 280, 24))
	await await_signal_on(editor, "visibility_changed")

	editor._inner._text_edit.text = "[4, 5, 6]"
	editor._inner._on_apply_pressed()

	assert_bool(committed).is_true()
	assert_bool(committed_new is Array).is_true()
	assert_int((committed_new as Array).size()).is_equal(3)
	assert_bool(editor.visible).is_false()

	remove_child(editor)
	editor.queue_free()


func test_dictionary_collection_apply_emits_committed_dictionary() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var committed := false
	var committed_new: Variant = null
	editor.value_committed.connect(func(_r, _p, _o, n):
		committed = true
		committed_new = n)

	var owner := CollectionOwner.new()
	var col := ColumnDef.new(&"mapping", TYPE_DICTIONARY, PROPERTY_HINT_NONE, "")
	editor.open(owner, col, Rect2i(100, 100, 280, 24))
	await await_signal_on(editor, "visibility_changed")

	editor._inner._text_edit.text = '{"fire": 12}'
	editor._inner._on_apply_pressed()

	assert_bool(committed).is_true()
	assert_bool(committed_new is Dictionary).is_true()
	assert_int((committed_new as Dictionary).size()).is_equal(1)
	assert_bool(editor.visible).is_false()

	remove_child(editor)
	editor.queue_free()


func test_resource_array_collection_apply_emits_resources_not_strings() -> void:
	var editor := CellEditor.new()
	add_child(editor)
	await await_signal_on(editor, "ready")

	var committed := false
	var committed_new: Variant = null
	editor.value_committed.connect(func(_r, _p, _o, n):
		committed = true
		committed_new = n)

	var owner := CollectionOwner.new()
	var col := ColumnDef.new(&"spell_refs", TYPE_ARRAY, PROPERTY_HINT_ARRAY_TYPE, "SpellMetadata")
	editor.open(owner, col, Rect2i(100, 100, 280, 24))
	await await_signal_on(editor, "visibility_changed")

	editor._inner._text_edit.text = "res://test_scenes/data/spells/fireball.tres"
	editor._inner._on_apply_pressed()

	assert_bool(committed).is_true()
	assert_bool(committed_new is Array).is_true()
	assert_int((committed_new as Array).size()).is_equal(1)
	assert_bool((committed_new as Array)[0] is Resource).is_true()
	assert_bool(((committed_new as Array)[0] as Resource).resource_path ==
		"res://test_scenes/data/spells/fireball.tres").is_true()
	assert_bool(editor.visible).is_false()

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


class SpellMetadata extends Resource:
	var id: String = ""


class ResourceOwner extends Resource:
	var spell_ref: SpellMetadata = null


class CollectionOwner extends Resource:
	var values: Array = []
	var mapping: Dictionary = {}
	var spell_refs: Array[SpellMetadata] = []


func _make_dummy_resource() -> Resource:
	return DummyResource.new()
