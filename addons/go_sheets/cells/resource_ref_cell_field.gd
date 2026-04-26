## ResourceRefCellField
##
## Uses Godot's built-in editor resource picker control to edit Resource
## reference properties.

@tool
class_name ResourceRefCellField
extends CellField

var _picker: EditorResourcePicker


func _init() -> void:
	_picker = EditorResourcePicker.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_picker)
	_connect_picker_signals()


func setup(base_type_hint: String) -> void:
	var base_type := base_type_hint if base_type_hint != "" else "Resource"
	if _picker.has_method("set_base_type"):
		_picker.call("set_base_type", base_type)
	else:
		_picker.set("base_type", base_type)


func set_value(value: Variant) -> void:
	var res: Resource = value if value is Resource else null
	_picker.set_block_signals(true)
	_picker.set("edited_resource", res)
	_picker.set_block_signals(false)


func get_value() -> Variant:
	return _picker.get("edited_resource")


func focus_main() -> void:
	_picker.grab_focus()


func _connect_picker_signals() -> void:
	if _picker.has_signal("resource_changed"):
		_picker.resource_changed.connect(_on_picker_resource_changed)
	if _picker.has_signal("resource_selected"):
		_picker.resource_selected.connect(_on_picker_resource_selected)
	if _picker.has_signal("resource_selected_for_inspect"):
		_picker.resource_selected_for_inspect.connect(_on_picker_resource_selected_for_inspect)


func _on_picker_resource_changed(resource: Resource) -> void:
	value_changed.emit(resource)


func _on_picker_resource_selected(resource: Resource, _inspect: bool = false) -> void:
	value_changed.emit(resource)


func _on_picker_resource_selected_for_inspect(resource: Resource) -> void:
	value_changed.emit(resource)
