@tool
## TypeSelector
##
## A toolbar widget that lets the developer pick which Resource subclass
## to view in the grid.  Emits [signal type_selected] when the selection
## changes.
##
## Populated by calling refresh() with the current TypeRegistry output.
class_name TypeSelector
extends HBoxContainer

signal type_selected(type_name: StringName)
## Emitted when the user presses the Refresh (↺) button.
## The panel should respond by re-scanning types and calling refresh().
signal refresh_requested

var _option: OptionButton
var _refresh_btn: Button
## Maps OptionButton item index → class StringName
var _index_to_class: Array[StringName] = []


func _enter_tree() -> void:
	# Guard: _enter_tree fires again if re-parented; build UI only once.
	if _option != null:
		return

	_option = OptionButton.new()
	_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option.item_selected.connect(_on_item_selected)
	add_child(_option)

	_refresh_btn = Button.new()
	_refresh_btn.text = "↺"
	_refresh_btn.tooltip_text = "Rescan resource types"
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	add_child(_refresh_btn)


## Populate the dropdown from [param type_entries] — same format as
## TypeRegistry.get_resource_types() returns.
## Pass [param selected_type] to restore a previously selected class.
func refresh(type_entries: Array[Dictionary], selected_type: StringName = &"") -> void:
	_option.clear()
	_index_to_class.clear()

	_option.add_item("— select a type —", 0)
	_index_to_class.append(&"")

	for entry: Dictionary in type_entries:
		var cls: StringName = entry.get("class", &"")
		_option.add_item(cls as String, _index_to_class.size())
		_index_to_class.append(cls)

	# Restore selection
	if selected_type != &"":
		for i in _index_to_class.size():
			if _index_to_class[i] == selected_type:
				_option.selected = i
				return
	_option.selected = 0


## Returns the currently selected class name, or "" if none.
func selected_type() -> StringName:
	var idx := _option.selected
	if idx < 0 or idx >= _index_to_class.size():
		return &""
	return _index_to_class[idx]


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_item_selected(index: int) -> void:
	var cls: StringName = &""
	if index >= 0 and index < _index_to_class.size():
		cls = _index_to_class[index]
	type_selected.emit(cls)


func _on_refresh_pressed() -> void:
	refresh_requested.emit()
