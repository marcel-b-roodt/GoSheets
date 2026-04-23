@tool
## GoSheetsPanel — main screen root.
##
## Owns the full Resources tab layout:
##   • Toolbar : TypeSelector dropdown + Refresh button
##   • Filter  : live-search LineEdit
##   • Grid    : ResourceGrid showing one row per matching resource
##
## Data flow:
##   TypeSelector.type_selected → _on_type_selected()
##     → ResourceScanner.scan() → load_matching_resources()
##     → ColumnModel.build() → ResourceGrid.load_data()
##   Filter LineEdit.text_changed → _apply_filter()
##   ResourceGrid.row_selected → EditorInterface.edit_resource()
extends Control

# Self-preloads
const _TYPE_SELECTOR_SCRIPT  := preload("res://addons/go_sheets/core/type_selector.gd")
const _RESOURCE_GRID_SCRIPT  := preload("res://addons/go_sheets/grid/resource_grid.gd")
const _COLUMN_MODEL_SCRIPT   := preload("res://addons/go_sheets/grid/column_model.gd")
const _SETTINGS_SCRIPT       := preload("res://addons/go_sheets/core/go_sheets_settings.gd")

# ── State ─────────────────────────────────────────────────────────────────────
var _settings: GoSheetsSettings
var _type_selector: TypeSelector
var _filter_edit: LineEdit
var _grid: ResourceGrid

## All resources of the current type (unfiltered)
var _all_resources: Array[Resource] = []
## Currently applied filter string (lower-case)
var _filter_text: String = ""
## The active ColumnModel
var _column_model: ColumnModel = null


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_settings = _SETTINGS_SCRIPT.load_or_create()
	_build_ui()
	_populate_type_selector()
	# Restore last selection
	if _settings.last_selected_type != "":
		_on_type_selected(_settings.last_selected_type)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# --- Toolbar ---
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(toolbar)

	# Type label
	var type_label := Label.new()
	type_label.text = "  Resource Type:"
	toolbar.add_child(type_label)

	# TypeSelector
	_type_selector = _TYPE_SELECTOR_SCRIPT.new()
	_type_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_selector.type_selected.connect(_on_type_selected)
	_type_selector.refresh_requested.connect(_on_refresh_requested)
	toolbar.add_child(_type_selector)

	# Scan root button
	var scan_root_btn := Button.new()
	scan_root_btn.text = "Scan Root: " + _settings.scan_root
	scan_root_btn.tooltip_text = "Click to change the root directory to scan"
	scan_root_btn.name = "ScanRootBtn"
	scan_root_btn.pressed.connect(_on_scan_root_pressed.bind(scan_root_btn))
	toolbar.add_child(scan_root_btn)

	# --- Filter bar ---
	var filter_bar := HBoxContainer.new()
	filter_bar.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(filter_bar)

	var filter_label := Label.new()
	filter_label.text = "  Filter:"
	filter_bar.add_child(filter_label)

	_filter_edit = LineEdit.new()
	_filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_edit.placeholder_text = "Type to filter by any property value…"
	_filter_edit.text_changed.connect(_on_filter_changed)
	filter_bar.add_child(_filter_edit)

	var clear_btn := Button.new()
	clear_btn.text = "✕"
	clear_btn.tooltip_text = "Clear filter"
	clear_btn.pressed.connect(func() -> void:
		_filter_edit.text = ""
		_on_filter_changed("")
	)
	filter_bar.add_child(clear_btn)

	# --- Separator ---
	vbox.add_child(HSeparator.new())

	# --- Grid ---
	_grid = _RESOURCE_GRID_SCRIPT.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.row_selected.connect(_on_row_selected)
	vbox.add_child(_grid)


func _populate_type_selector() -> void:
	var types := TypeRegistry.get_resource_types()
	_type_selector.refresh(types, _settings.last_selected_type as StringName)


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func _on_type_selected(type_name: StringName) -> void:
	if type_name == &"":
		_all_resources = []
		_filter_text = ""
		_filter_edit.text = ""
		_column_model = null
		_grid.load_data(ColumnModel.new(), [])
		return

	# Save selection
	_settings.last_selected_type = type_name as String
	_settings.save()

	# Rebuild columns (apply saved layout if any)
	var saved_layout: Array = _settings.column_layouts.get(type_name as String, [])
	_column_model = _COLUMN_MODEL_SCRIPT.build(type_name, saved_layout)

	# Scan for resources of this type
	var all_paths := ResourceScanner.scan(_settings.scan_root)
	_all_resources = _load_resources_of_type(all_paths, type_name)

	_apply_filter(_filter_text)


func _on_filter_changed(text: String) -> void:
	_filter_text = text.to_lower()
	_apply_filter(_filter_text)


func _on_row_selected(resource: Resource) -> void:
	if resource == null:
		return
	# Open resource in Inspector
	EditorInterface.edit_resource(resource)


func _on_refresh_requested() -> void:
	_populate_type_selector()
	if _settings.last_selected_type != "":
		_on_type_selected(_settings.last_selected_type)


func _on_scan_root_pressed(btn: Button) -> void:
	# Cycle through common roots (res://, res://data/, res://resources/)
	var roots: Array[String] = ["res://", "res://data/", "res://resources/", "res://addons/"]
	var idx: int = roots.find(_settings.scan_root)
	_settings.scan_root = roots[(idx + 1) % roots.size()]
	_settings.save()
	btn.text = "Scan Root: " + _settings.scan_root
	if _settings.last_selected_type != "":
		_on_type_selected(_settings.last_selected_type)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _apply_filter(text: String) -> void:
	if _column_model == null:
		return
	var filtered: Array[Resource]
	if text == "":
		filtered = _all_resources
	else:
		filtered = []
		var vis := _column_model.visible_columns()
		for res: Resource in _all_resources:
			if _resource_matches(res, vis, text):
				filtered.append(res)
	_grid.load_data(_column_model, filtered)


static func _resource_matches(
		res: Resource,
		columns: Array,
		lower_filter: String) -> bool:
	for col: ColumnDef in columns:
		var val: Variant = res.get(col.property_name)
		if val == null:
			continue
		if str(val).to_lower().contains(lower_filter):
			return true
	return false


static func _load_resources_of_type(
		paths: Array[String],
		type_name: StringName) -> Array[Resource]:
	var out: Array[Resource] = []
	for path: String in paths:
		var res := ResourceLoader.load(path)
		if res == null:
			continue
		# Check using get_class() or script class_name via is_class
		if res.get_script() == null:
			continue
		var script := res.get_script() as GDScript
		if script == null:
			continue
		# Walk script inheritance to match type_name
		var s: GDScript = script
		while s != null:
			if s.get_global_name() == type_name:
				out.append(res)
				break
			s = s.get_base_script()
	return out
