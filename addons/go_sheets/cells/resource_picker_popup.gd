@tool
## ResourcePickerPopup
##
## A searchable popup listing project resources filtered by type.
## Opens modeless above the current editor; the caller connects
## resource_selected to receive the chosen resource path.
##
## Usage:
##   var picker := ResourcePickerPopup.new()
##   add_child(picker)
##   picker.resource_selected.connect(_on_resource_picked)
##   picker.open("SpellMetadata")     # pass "" to show all resources
##
## Type matching reads only the first line of each .tres file (fast, no full
## load). When a non-.tres file or an unreadable file is encountered, the
## type is treated as unknown and the file is included when base_type is "".

class_name ResourcePickerPopup
extends PopupPanel

## Emitted when the user confirms a selection.
## [param path] is the res:// path; the caller is responsible for loading.
signal resource_selected(path: String)

# Self-preloads
const _RESOURCE_SCANNER_SCRIPT := preload("res://addons/go_sheets/scanner/resource_scanner.gd")

const _MIN_WIDTH  := 320
const _MIN_HEIGHT := 240

var _base_type: String = ""
var _all_paths: Array[String] = []   # filtered by type at open time

var _search_edit: LineEdit
var _list: ItemList
var _status_label: Label


func _init() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left   =  6
	root.offset_top    =  6
	root.offset_right  = -6
	root.offset_bottom = -6
	add_child(root)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search…"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(_on_search_changed)
	root.add_child(_search_edit)

	_list = ItemList.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_list.item_activated.connect(_on_item_activated)
	root.add_child(_list)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.modulate = Color(0.6, 0.6, 0.6, 1.0)
	root.add_child(_status_label)

	exclusive = false
	wrap_controls = false


## Open the picker for [param base_type] resources.
## Pass [param base_type] = "" to list all resource files.
## [param scan_root] is the root directory to scan (default: "res://").
func open(base_type: String, scan_root: String = "res://") -> void:
	_base_type = base_type
	_all_paths.clear()
	_search_edit.text = ""

	var all := _RESOURCE_SCANNER_SCRIPT.scan(scan_root)
	for path: String in all:
		if _base_type == "" or _type_matches(path, _base_type):
			_all_paths.append(path)

	_rebuild_list("")
	_status_label.text = "%d resource(s) found" % _all_paths.size()

	size = Vector2i(_MIN_WIDTH, _MIN_HEIGHT)
	popup()
	_search_edit.grab_focus()


## Read just the first line of a .tres file to get the gd_resource type.
## Returns "" for .res files, missing files, or unrecognised formats.
static func read_tres_type(path: String) -> String:
	if not path.ends_with(".tres"):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var first_line := file.get_line()
	file.close()
	# Header form: [gd_resource type="SpellMetadata" format=3 uid="uid://..."]
	var marker := 'type="'
	var start := first_line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end := first_line.find('"', start)
	if end < 0:
		return ""
	return first_line.substr(start, end - start)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _type_matches(path: String, wanted: String) -> bool:
	var file_type := read_tres_type(path)
	if file_type == "":
		# .res file or unreadable — include only when wanted is blank
		return wanted == ""
	# Direct match or ClassDB inheritance match
	if file_type == wanted:
		return true
	if ClassDB.class_exists(file_type) and ClassDB.class_exists(wanted):
		return ClassDB.is_parent_class(file_type, wanted)
	return false


func _rebuild_list(filter: String) -> void:
	_list.clear()
	var lower_filter := filter.to_lower()
	for path: String in _all_paths:
		var base := path.get_file()
		if lower_filter == "" or base.to_lower().contains(lower_filter):
			var idx := _list.add_item(base)
			_list.set_item_tooltip(idx, path)
			_list.set_item_metadata(idx, path)


func _on_search_changed(text: String) -> void:
	_rebuild_list(text)


func _on_item_activated(index: int) -> void:
	var path: String = _list.get_item_metadata(index)
	hide()
	resource_selected.emit(path)
