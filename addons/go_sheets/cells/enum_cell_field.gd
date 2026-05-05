@tool
## EnumCellField
##
## An OptionButton for editing enum values (int properties with PROPERTY_HINT_ENUM).

class_name EnumCellField
extends CellField

var _option_button: OptionButton

func _init() -> void:
	_option_button = OptionButton.new()
	_option_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_option_button.item_selected.connect(func(_idx: int) -> void: _on_selected())
	add_child(_option_button)

## Call after construction to populate the enum options.
func populate(hint_string: String) -> void:
	# hint_string: "Name,Name:int,Name" — each entry may carry an explicit value.
	var entries := hint_string.split(",", false)
	var auto_val := 0
	for entry: String in entries:
		var colon := entry.find(":")
		if colon >= 0:
			var display := entry.left(colon)
			var val := int(entry.substr(colon + 1))
			_option_button.add_item(display, val)
			auto_val = val + 1
		else:
			_option_button.add_item(entry, auto_val)
			auto_val += 1

func set_value(value: Variant) -> void:
	var idx := int(value) if value != null else 0
	if _option_button.item_count > 0:
		_option_button.selected = clampi(idx, 0, _option_button.item_count - 1)

func get_value() -> Variant:
	return _option_button.get_item_id(_option_button.selected) \
			if _option_button.selected >= 0 else 0

func focus_main() -> void:
	_option_button.grab_focus()

func _on_selected() -> void:
	value_changed.emit(get_value())
