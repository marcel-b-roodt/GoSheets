@tool
## GoSheetsPanel — main screen root.
##
## Owns the full Resources tab layout:
##   • Toolbar : TypeSelector dropdown + Refresh button
##   • Filter  : live-search LineEdit
##   • Debug   : collapsible log pane (visible when debug_mode is on)
##   • Grid    : ResourceGrid showing one row per matching resource
##
## Data flow:
##   TypeSelector.type_selected → _on_type_selected()
##     → ResourceScanner.scan() → _load_resources_of_type()
##     → ColumnModel.build() → ResourceGrid.load_data()
##   Filter LineEdit.text_changed → _apply_filter()
##   ResourceGrid.row_selected → EditorInterface.edit_resource()
extends Control

# Self-preloads
const _TYPE_SELECTOR_SCRIPT  := preload("res://addons/go_sheets/core/type_selector.gd")
const _RESOURCE_GRID_SCRIPT  := preload("res://addons/go_sheets/grid/resource_grid.gd")
const _COLUMN_MODEL_SCRIPT   := preload("res://addons/go_sheets/grid/column_model.gd")
const _SETTINGS_SCRIPT       := preload("res://addons/go_sheets/core/go_sheets_settings.gd")

const _DEBUG_MAX_LINES := 200

# ── State ─────────────────────────────────────────────────────────────────────
var _settings: GoSheetsSettings
var _type_selector: TypeSelector
var _filter_edit: LineEdit
var _grid: ResourceGrid
var _scan_root_btn: Button

## All resources of the current type (unfiltered)
var _all_resources: Array[Resource] = []
## Currently applied filter string (lower-case)
var _filter_text: String = ""
## The active ColumnModel
var _column_model: ColumnModel = null

# Debug pane nodes
var _debug_panel: PanelContainer
var _debug_log: RichTextLabel
var _debug_toggle: CheckButton
var _debug_mode: bool = false


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

	var type_label := Label.new()
	type_label.text = "  Resource Type:"
	toolbar.add_child(type_label)

	_type_selector = _TYPE_SELECTOR_SCRIPT.new()
	_type_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_selector.type_selected.connect(_on_type_selected)
	_type_selector.refresh_requested.connect(_on_refresh_requested)
	toolbar.add_child(_type_selector)

	_scan_root_btn = Button.new()
	_scan_root_btn.text = "Scan Root: " + _settings.scan_root
	_scan_root_btn.tooltip_text = "Click to change the root directory to scan"
	_scan_root_btn.pressed.connect(_on_scan_root_pressed)
	toolbar.add_child(_scan_root_btn)

	# Debug toggle in toolbar
	_debug_toggle = CheckButton.new()
	_debug_toggle.text = "Debug"
	_debug_toggle.tooltip_text = "Show/hide the debug log pane"
	_debug_toggle.toggled.connect(_on_debug_toggled)
	toolbar.add_child(_debug_toggle)

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

	# --- Debug pane (hidden by default) ---
	_debug_panel = PanelContainer.new()
	_debug_panel.custom_minimum_size = Vector2(0, 140)
	_debug_panel.visible = false
	vbox.add_child(_debug_panel)

	var debug_vbox := VBoxContainer.new()
	_debug_panel.add_child(debug_vbox)

	var debug_header := HBoxContainer.new()
	debug_vbox.add_child(debug_header)

	var debug_title := Label.new()
	debug_title.text = "  Debug Log"
	debug_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_header.add_child(debug_title)

	var clear_log_btn := Button.new()
	clear_log_btn.text = "Clear"
	clear_log_btn.pressed.connect(func() -> void: _debug_log.clear())
	debug_header.add_child(clear_log_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debug_vbox.add_child(scroll)

	_debug_log = RichTextLabel.new()
	_debug_log.bbcode_enabled = true
	_debug_log.scroll_following = true
	_debug_log.fit_content = true
	_debug_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_debug_log)

	# --- Separator ---
	vbox.add_child(HSeparator.new())

	# --- Grid ---
	_grid = _RESOURCE_GRID_SCRIPT.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.row_selected.connect(_on_row_selected)
	vbox.add_child(_grid)


func _populate_type_selector() -> void:
	var types := TypeRegistry.get_resource_types()
	_dbg("TypeRegistry returned %d type(s)" % types.size())
	for t: Dictionary in types:
		_dbg("  • %s  (%s)" % [t.get("class", "?"), t.get("path", "?")])
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
		var empty: Array[Resource] = []
		_grid.load_data(ColumnModel.new(), empty)
		return

	_dbg("─── Type selected: [b]%s[/b]" % type_name)

	# Save selection
	_settings.last_selected_type = type_name as String
	_settings.save()

	# Rebuild columns (apply saved layout if any)
	var saved_layout: Array = _settings.column_layouts.get(type_name as String, [])
	_column_model = _COLUMN_MODEL_SCRIPT.build(type_name, saved_layout)
	_dbg("ColumnModel built: %d column(s)" % _column_model.columns.size())
	for col: ColumnDef in _column_model.columns:
		_dbg("  col [i]%s[/i]  type=%d  visible=%s" % [col.property_name, col.property_type, col.visible])

	# Scan for resources of this type
	var all_paths := ResourceScanner.scan(_settings.scan_root)
	_dbg("ResourceScanner: %d path(s) under '%s'" % [all_paths.size(), _settings.scan_root])

	# Resolve target script path for matching
	var target_script_path := _resolve_script_path(type_name)
	var not_found := "[color=red]NOT FOUND[/color]"
	_dbg("Target script: %s" % (target_script_path if target_script_path != "" else not_found))

	_all_resources = _load_resources_of_type_by_path(all_paths, target_script_path)
	_dbg("Matched [b]%d[/b] resource(s) of type %s" % [_all_resources.size(), type_name])
	for r: Resource in _all_resources:
		_dbg("  ✓ %s" % r.resource_path)

	_apply_filter(_filter_text)


func _on_filter_changed(text: String) -> void:
	_filter_text = text.to_lower()
	_apply_filter(_filter_text)


func _on_row_selected(resource: Resource) -> void:
	if resource == null:
		return
	EditorInterface.edit_resource(resource)


func _on_refresh_requested() -> void:
	_dbg("─── Refresh requested")
	_populate_type_selector()
	if _settings.last_selected_type != "":
		_on_type_selected(_settings.last_selected_type)


func _on_scan_root_pressed() -> void:
	var roots: Array[String] = ["res://", "res://data/", "res://resources/", "res://addons/"]
	var idx: int = roots.find(_settings.scan_root)
	_settings.scan_root = roots[(idx + 1) % roots.size()]
	_settings.save()
	_scan_root_btn.text = "Scan Root: " + _settings.scan_root
	_dbg("Scan root changed to: %s" % _settings.scan_root)
	if _settings.last_selected_type != "":
		_on_type_selected(_settings.last_selected_type)


func _on_debug_toggled(pressed: bool) -> void:
	_debug_mode = pressed
	_debug_panel.visible = pressed
	if pressed:
		_dbg("Debug mode enabled.")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _apply_filter(text: String) -> void:
	if _column_model == null:
		return
	var filtered: Array[Resource] = []
	if text == "":
		filtered = _all_resources
	else:
		var vis := _column_model.visible_columns()
		for res: Resource in _all_resources:
			if _resource_matches(res, vis, text):
				filtered.append(res)
	_dbg("Filter '%s' → %d / %d row(s) shown" % [text, filtered.size(), _all_resources.size()])
	_grid.load_data(_column_model, filtered)


## Log a message to the debug pane (BBCode supported).
## Silently swallowed when debug mode is off.
func _dbg(msg: String) -> void:
	if not _debug_mode:
		return
	if _debug_log == null:
		return
	# Trim oldest lines to keep the log from growing unbounded
	if _debug_log.get_line_count() > _DEBUG_MAX_LINES:
		_debug_log.clear()
	_debug_log.append_text(msg + "\n")


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


## Return the res:// script path for [param type_name] from the global class list.
static func _resolve_script_path(type_name: StringName) -> String:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == (type_name as String):
			return entry.get("path", "")
	return ""


## Match resources by comparing their script's resource_path against
## [param target_script_path].  Script object identity comparison is
## unreliable in Godot 4 because ResourceLoader may return different
## Script instances for the same file.
static func _load_resources_of_type_by_path(
		paths: Array[String],
		target_script_path: String) -> Array[Resource]:
	if target_script_path == "":
		return []

	var out: Array[Resource] = []
	for path: String in paths:
		var res := ResourceLoader.load(path)
		if res == null:
			continue
		var s: Script = res.get_script() as Script
		while s != null:
			if s.resource_path == target_script_path:
				out.append(res)
				break
			s = s.get_base_script() as Script
	return out
