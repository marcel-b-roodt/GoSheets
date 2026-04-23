@tool
## GoSheetsPanel — main screen root.
##
## Owns the full Resources tab layout:
##   • Toolbar : TypeSelector dropdown + Refresh button + Debug toggle
##   • Filter  : live-search LineEdit
##   • Grid    : ResourceGrid showing one row per matching resource
##
## Debug mode: enable the 'Debug' toggle in the toolbar to write
## diagnostic prints to the Godot Output panel (prefixed [GoSheets]).
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

var _debug_toggle: CheckButton
var _debug_mode: bool = false

## Timer used to debounce filter-text changes (avoids a query per keystroke).
var _filter_timer: Timer
## Outer layout VBoxContainer — stored so debug output can inspect its size.
var _vbox: VBoxContainer

## Cached flat list of all .tres/.res paths under the scan root.
## Populated by _refresh_path_cache() and kept up-to-date via
## EditorFileSystem.filesystem_changed.
var _path_cache: Array[String] = []
var _path_cache_dirty: bool = true
## Maps each cached path → resource type string from EditorFileSystem.
## Populated alongside _path_cache; used to skip loading mismatched files.
var _type_map: Dictionary = {}
## Per-type resource cache.  Cleared on filesystem_changed.
## Key: StringName(type_name)  Value: Array[Resource]
var _resource_cache: Dictionary = {}
## EditorUndoRedoManager obtained once in _ready(); used for all cell edits.
var _undo_redo: EditorUndoRedoManager = null
## Tracks the last undo_redo history version to detect Inspector-side changes.
var _last_undo_version: int = -1
## Timer for polling undo version changes (detects Inspector edits).
var _sync_timer: Timer = null


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	# EditorInterface.get_editor_main_screen() is a VBoxContainer.
	# When a node is added to a Container its layout_mode is forced to
	# CONTAINER, making anchors irrelevant.  SIZE_EXPAND_FILL ensures
	# Godot's Container layout gives this panel the full available height.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_settings = _SETTINGS_SCRIPT.load_or_create()
	_build_ui()
	# Connect EditorFileSystem so file additions/deletions auto-refresh the grid.
	var efs := EditorInterface.get_resource_filesystem()
	efs.filesystem_changed.connect(_on_filesystem_changed)
	# Grab undo/redo manager once.
	_undo_redo = EditorInterface.get_editor_undo_redo()
	# Poll timer: detect undo/redo or Inspector changes every 300 ms.
	_sync_timer = Timer.new()
	_sync_timer.wait_time = 0.3
	_sync_timer.one_shot = false
	_sync_timer.timeout.connect(_on_sync_timer)
	add_child(_sync_timer)
	_sync_timer.start()
	_populate_type_selector()
	# Restore last selection
	if _settings.last_selected_type != "":
		_on_type_selected(_settings.last_selected_type)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vbox)

	# --- Toolbar ---
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 32)
	_vbox.add_child(toolbar)

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
	_vbox.add_child(filter_bar)

	var filter_label := Label.new()
	filter_label.text = "  Filter:"
	filter_bar.add_child(filter_label)

	_filter_edit = LineEdit.new()
	_filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_edit.placeholder_text = "Type to filter by any property value…"
	_filter_edit.text_changed.connect(_on_filter_text_changed)
	filter_bar.add_child(_filter_edit)

	var clear_btn := Button.new()
	clear_btn.text = "✕"
	clear_btn.tooltip_text = "Clear filter"
	clear_btn.pressed.connect(func() -> void:
		if _filter_timer:
			_filter_timer.stop()
		_filter_edit.text = ""
		_filter_text = ""
		_apply_filter("")
	)
	filter_bar.add_child(clear_btn)

	# --- Separator ---
	_vbox.add_child(HSeparator.new())

	# --- Grid ---
	_grid = _RESOURCE_GRID_SCRIPT.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.debug_mode = _debug_mode
	_grid.row_selected.connect(_on_row_selected)
	_grid.column_layout_changed.connect(_on_column_layout_changed)
	_grid.cell_value_changed.connect(_on_cell_value_changed)
	_vbox.add_child(_grid)

	# --- Filter debounce timer ---
	_filter_timer = Timer.new()
	_filter_timer.wait_time = 0.25
	_filter_timer.one_shot = true
	_filter_timer.timeout.connect(_on_filter_apply)
	add_child(_filter_timer)


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
	# Cancel any in-flight filter debounce — new type clears filter state.
	if _filter_timer:
		_filter_timer.stop()

	if type_name == &"":
		_all_resources = []
		_filter_text = ""
		_filter_edit.text = ""
		_column_model = null
		var empty: Array[Resource] = []
		_grid.load_data(ColumnModel.new(), empty)
		return

	_dbg("--- Type selected: %s" % type_name)

	# Save selection
	_settings.last_selected_type = type_name as String
	_settings.save()

	# Rebuild columns (apply saved layout if any)
	var saved_layout: Array = _settings.column_layouts.get(type_name as String, [])
	_column_model = _COLUMN_MODEL_SCRIPT.build(type_name, saved_layout)
	_dbg("ColumnModel built: %d column(s)" % _column_model.columns.size())
	for col: ColumnDef in _column_model.columns:
		_dbg("    col '%s'  type=%d  visible=%s" % [col.property_name, col.property_type, col.visible])

	# Use cached path list (rebuilt when filesystem changes or root changes)
	if _path_cache_dirty:
		_refresh_path_cache()
	_dbg("Path cache: %d path(s) under '%s'" % [_path_cache.size(), _settings.scan_root])
	for p: String in _path_cache:
		_dbg("  path: %s  [EFS type='%s']" % [p, _type_map.get(p, "?")])

	# Resolve target script path for matching
	var target_script_path := _resolve_script_path(type_name)
	_dbg("Target script: %s" % (target_script_path if target_script_path != "" else "NOT FOUND"))

	if _resource_cache.has(type_name):
		_all_resources = _resource_cache[type_name]
		if _all_resources.is_empty():
			# Stale empty entry (e.g. from a broken previous run) — reload.
			_resource_cache.erase(type_name)
			_all_resources = _load_resources_of_type_by_path(_path_cache, target_script_path)
			_dbg("Stale-empty cache cleared; loaded %d for %s" % [_all_resources.size(), type_name])
			_resource_cache[type_name] = _all_resources
		else:
			_dbg("Resource cache HIT: %d resource(s) for %s" % [_all_resources.size(), type_name])
	else:
		_all_resources = _load_resources_of_type_by_path(_path_cache, target_script_path)
		_dbg("Matched %d resource(s) of type %s" % [_all_resources.size(), type_name])
		for r: Resource in _all_resources:
			_dbg("  MATCH: %s" % r.resource_path)
		_resource_cache[type_name] = _all_resources

	_apply_filter(_filter_text)


## Stores the new filter text and (re)starts the debounce timer.
func _on_filter_text_changed(text: String) -> void:
	_filter_text = text.to_lower()
	_filter_timer.start()


## Called when the debounce timer fires — applies the current filter.
func _on_filter_apply() -> void:
	_apply_filter(_filter_text)


func _on_row_selected(resource: Resource) -> void:
	if resource == null:
		return
	EditorInterface.edit_resource(resource)


func _on_column_layout_changed() -> void:
	if _column_model == null or _settings == null:
		return
	var type_key := _settings.last_selected_type
	_settings.column_layouts[type_key] = _column_model.to_dicts()
	_settings.save()
	_dbg("Column layout saved for '%s'" % type_key)


## Called when the user commits an inline cell edit in the grid.
## Wraps the change in an EditorUndoRedoManager action so Ctrl+Z works,
## writes the new value to the resource, saves it to disk, and refreshes
## the affected row without rebuilding the whole grid.
func _on_cell_value_changed(
		resource: Resource,
		property: StringName,
		old_value: Variant,
		new_value: Variant) -> void:
	if resource == null or _undo_redo == null:
		return
	# No-op if nothing actually changed.
	if old_value == new_value:
		return

	var label := "Edit %s.%s" % [resource.get_class(), property]
	_undo_redo.create_action(label, UndoRedo.MERGE_DISABLE)
	# do: set new value + save
	_undo_redo.add_do_property(resource, property, new_value)
	_undo_redo.add_do_method(self, "_save_and_refresh_resource", resource)
	# undo: restore old value + save
	_undo_redo.add_undo_property(resource, property, old_value)
	_undo_redo.add_undo_method(self, "_save_and_refresh_resource", resource)
	_undo_redo.commit_action()
	_dbg("Cell edit: %s.%s  %s → %s" % [resource.get_class(), property, old_value, new_value])


## Save [param resource] to disk and refresh its row in the grid.
## Called as both the do and undo action for cell edits.
func _save_and_refresh_resource(resource: Resource) -> void:
	if resource == null:
		return
	if resource.resource_path != "":
		ResourceSaver.save(resource)
	_refresh_resource_row(resource)
	# Keep the Inspector in sync with the (possibly undone) state.
	EditorInterface.edit_resource(resource)


## Rebind only the row(s) that display [param resource] without rebuilding
## the full grid.  Called after save so labels reflect the current value.
func _refresh_resource_row(resource: Resource) -> void:
	if _grid == null or _column_model == null:
		return
	_grid.refresh_resource(resource)


## Polls the undo_redo history version every 300 ms.
## When the version changes (user pressed Ctrl+Z / Ctrl+Y, or the Inspector
## committed a change via its own undo history) we rebind all visible rows
## so the grid stays in sync with the current resource state on disk.
func _on_sync_timer() -> void:
	if _undo_redo == null or _grid == null or _column_model == null:
		return
	# EditorUndoRedoManager.get_object_history_id(obj) maps objects to their
	# history bucket.  0 is GLOBAL_HISTORY (used by the Inspector).
	var ur: UndoRedo = _undo_redo.get_history_undo_redo(0)
	if ur == null:
		return
	var v: int = ur.get_version()
	if v != _last_undo_version:
		_last_undo_version = v
		_grid.refresh_all_rows()
		_dbg("Undo version changed → grid rows refreshed")


func _on_refresh_requested() -> void:
	_dbg("--- Refresh requested")
	_path_cache_dirty = true
	_populate_type_selector()
	if _settings.last_selected_type != "":
		_on_type_selected(_settings.last_selected_type)


func _on_scan_root_pressed() -> void:
	var roots: Array[String] = ["res://", "res://data/", "res://resources/", "res://addons/"]
	var idx: int = roots.find(_settings.scan_root)
	_settings.scan_root = roots[(idx + 1) % roots.size()]
	_settings.save()
	_scan_root_btn.text = "Scan Root: " + _settings.scan_root
	_path_cache_dirty = true
	_dbg("Scan root changed to: %s" % _settings.scan_root)
	if _settings.last_selected_type != "":
		_on_type_selected(_settings.last_selected_type)


func _on_filesystem_changed() -> void:
	_path_cache_dirty = true
	_resource_cache.clear()
	_dbg("EditorFileSystem changed — path cache and resource cache invalidated")
	if _settings != null and _settings.last_selected_type != "":
		_on_type_selected(_settings.last_selected_type)


func _on_debug_toggled(pressed: bool) -> void:
	_debug_mode = pressed
	if _grid:
		_grid.debug_mode = pressed
	if pressed:
		_dbg("Debug mode enabled — output will appear in Godot Output panel.")
		_print_panel_debug.call_deferred()


func _print_panel_debug() -> void:
	var parent_size := Vector2.ZERO
	if get_parent() is Control:
		parent_size = (get_parent() as Control).size
	_dbg("[Panel layout] parent=%s  self=%s  vbox=%s  grid=%s  size_flags_v=%d" % [
		str(parent_size),
		str(size),
		str(_vbox.size if _vbox else Vector2.ZERO),
		str(_grid.size if _grid else Vector2.ZERO),
		size_flags_vertical,
	])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Rebuild _path_cache from EditorFileSystem under the configured scan root.
## Falls back to ResourceScanner (DirAccess) if EditorFileSystem is not ready.
func _refresh_path_cache() -> void:
	_path_cache.clear()
	_type_map.clear()
	var efs := EditorInterface.get_resource_filesystem()
	if efs.is_scanning():
		# Editor hasn't finished its initial import scan yet — fall back.
		_dbg("EditorFileSystem still scanning \u2014 falling back to DirAccess")
		_path_cache = ResourceScanner.scan(_settings.scan_root)
	else:
		var root_dir := efs.get_filesystem_path(_settings.scan_root)
		if root_dir == null:
			_dbg("EditorFileSystem: scan root not found, falling back to DirAccess")
			_path_cache = ResourceScanner.scan(_settings.scan_root)
		else:
			_walk_efs_dir(root_dir, _path_cache)
	_path_cache_dirty = false
	_dbg("Path cache rebuilt: %d path(s)" % _path_cache.size())


## Walk an EditorFileSystemDirectory tree, collecting .tres/.res paths
## and recording each file's declared type in _type_map.
func _walk_efs_dir(dir: EditorFileSystemDirectory, out: Array[String]) -> void:
	for i in dir.get_file_count():
		var fname := dir.get_file(i)
		if fname.ends_with(".tres") or fname.ends_with(".res"):
			var path := dir.get_file_path(i)
			out.append(path)
			_type_map[path] = dir.get_file_type(i)
	for i in dir.get_subdir_count():
		_walk_efs_dir(dir.get_subdir(i), out)


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


## Print [param msg] to the Godot Output panel, prefixed with [GoSheets].
## Silently swallowed when debug mode is off.
func _dbg(msg: String) -> void:
	if _debug_mode:
		print("[GoSheets] ", msg)


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


## Load all resources whose script (or any ancestor script) lives at
## [param target_script_path].  Uses is_instance_of() for reliable
## type-checking — avoids Script object identity pitfalls in Godot 4.
## Uses _type_map to skip loading built-in-typed files that can’t possibly
## match the target user class (avoids unnecessary ResourceLoader.load calls).
func _load_resources_of_type_by_path(
		paths: Array[String],
		target_script_path: String) -> Array[Resource]:
	if target_script_path == "":
		_dbg("  ABORT: target_script_path is empty")
		return []

	var target_script := load(target_script_path) as Script
	if target_script == null:
		_dbg("  ABORT: could not load script at '%s'" % target_script_path)
		return []

	var out: Array[Resource] = []
	for path: String in paths:
		# Fast pre-skip: EFS gives us the engine class for binary .res files
		# (e.g. "CompressedTexture2D", "AudioStreamOGGVorbis").  We can safely
		# skip those without loading.  Script-backed .tres files report
		# "Resource" — never skip those, they need to be loaded and checked.
		var known_type: String = _type_map.get(path, "")
		if known_type != "" and known_type != "Resource" and ClassDB.class_exists(known_type):
			_dbg("  skip (built-in %s, no load): %s" % [known_type, path])
			continue
		var res := ResourceLoader.load(path)
		if res == null:
			_dbg("  SKIP (null): %s" % path)
			continue
		if is_instance_of(res, target_script):
			_dbg("  MATCH: %s" % path)
			out.append(res)
		else:
			var s := res.get_script() as Script
			var sname := s.resource_path if s != null else "(no script)"
			_dbg("  skip: %s  [script=%s]" % [path, sname])
	return out
