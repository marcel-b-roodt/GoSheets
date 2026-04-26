## ColumnModel
##
## Derives a list of ColumnDef entries from the @export properties of a
## Resource subclass, applying any saved layout (visibility, width, order)
## from GoSheetsSettings.
##
## Pure logic — no EditorPlugin dependency; fully testable headlessly.

class_name ColumnModel
extends RefCounted

# Self-preloads
const _COLUMN_DEF_SCRIPT := preload("res://addons/go_sheets/grid/column_def.gd")
# Groups to skip — not user-facing
const _SKIP_GROUPS: Array[String] = ["", "script_variables"]
# Property usage flags that indicate an @export property
const _EXPORT_USAGE := PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE

## All columns for the current type, in display order.
var columns: Array[ColumnDef] = []


## Build a ColumnModel for [param type_name] using ClassDB property info.
## Applies saved layout from [param saved_dicts] if provided.
static func build(type_name: StringName, saved_dicts: Array = []) -> ColumnModel:
	var model := ColumnModel.new()
	var raw_props := _get_export_properties(type_name)

	if saved_dicts.is_empty():
		# First time: create ColumnDefs from script properties
		for prop: Dictionary in raw_props:
			model.columns.append(
				_COLUMN_DEF_SCRIPT.new(
					prop.name,
					prop.type,
					prop.hint,
					prop.hint_string,
				)
			)
	else:
		# Restore saved layout, then append any new properties not yet in layout.
		# Always refresh type metadata (hint, hint_string, property_type) from the
		# live property info so stale saved values (e.g. an old @export_range that
		# was removed from the script) cannot incorrectly affect the editor UI.
		var prop_info: Dictionary = {}
		for prop: Dictionary in raw_props:
			prop_info[prop.name] = prop

		var seen: Dictionary = {}
		for d: Dictionary in saved_dicts:
			var col: ColumnDef = _COLUMN_DEF_SCRIPT.from_dict(d)
			# Overwrite type metadata with current live definition.
			if prop_info.has(col.property_name):
				var live: Dictionary = prop_info[col.property_name]
				col.property_type = live.type
				col.hint          = live.hint
				col.hint_string   = live.hint_string
			model.columns.append(col)
			seen[col.property_name] = true
		for prop: Dictionary in raw_props:
			if not seen.has(prop.name):
				model.columns.append(
					_COLUMN_DEF_SCRIPT.new(
						prop.name,
						prop.type,
						prop.hint,
						prop.hint_string,
					)
				)

	return model


## Return only the visible columns, pinned ones first.
func visible_columns() -> Array[ColumnDef]:
	var pinned: Array[ColumnDef] = []
	var unpinned: Array[ColumnDef] = []
	for col: ColumnDef in columns:
		if not col.visible:
			continue
		if col.pinned:
			pinned.append(col)
		else:
			unpinned.append(col)
	pinned.append_array(unpinned)
	return pinned


## Serialise all columns to an Array[Dictionary] for saving.
func to_dicts() -> Array:
	var out: Array = []
	for col: ColumnDef in columns:
		out.append(col.to_dict())
	return out


## Move a visible column from [param from_visible_index] to [param to_visible_slot].
## The slot is in visible-column space and ranges from 0..visible_columns().size().
## Returns true if the model order changed.
func move_visible_column_to_slot(from_visible_index: int, to_visible_slot: int) -> bool:
	var vis := visible_columns()
	if from_visible_index < 0 or from_visible_index >= vis.size():
		return false

	var moving: ColumnDef = vis[from_visible_index]
	var from_model_index: int = columns.find(moving)
	if from_model_index < 0:
		return false

	# Clamp slot to the valid insertion range in visible-column space.
	var clamped_slot: int = mini(maxi(to_visible_slot, 0), vis.size())

	# Convert target slot to model-array insertion index.
	var target_model_index: int = columns.size()
	if clamped_slot < vis.size():
		var target_col: ColumnDef = vis[clamped_slot]
		target_model_index = columns.find(target_col)
		if target_model_index < 0:
			return false

	# No-op when moving before itself or immediately after itself.
	if target_model_index == from_model_index or target_model_index == from_model_index + 1:
		return false

	columns.remove_at(from_model_index)
	if from_model_index < target_model_index:
		target_model_index -= 1
	columns.insert(target_model_index, moving)
	return true


# ---------------------------------------------------------------------------
# Private — property extraction
# ---------------------------------------------------------------------------

static func _get_export_properties(type_name: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	# Try via a temporary instance first (works for script-defined classes).
	# Fall back to ClassDB for pure built-ins.
	var props: Array[Dictionary] = []

	if ClassDB.class_exists(type_name):
		props = ClassDB.class_get_property_list(type_name, true)
	else:
		# Script-defined class: load the script and get property list from
		# a temporary instance.
		var global_classes: Array = ProjectSettings.get_global_class_list()
		for entry: Dictionary in global_classes:
			if entry.get("class", "") == (type_name as String):
				var script: GDScript = load(entry.get("path", ""))
				if script:
					var tmp: Resource = script.new()
					if tmp:
						props = tmp.get_property_list()
				break

	for prop: Dictionary in props:
		if _is_user_export(prop):
			result.append(prop)

	return result


static func _is_user_export(prop: Dictionary) -> bool:
	var usage: int = prop.get("usage", 0)
	# Must have both DEFAULT and SCRIPT_VARIABLE flags
	if not (usage & PROPERTY_USAGE_DEFAULT) or not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
		return false
	# Skip internal Godot properties (resource_name, resource_path, etc.)
	var name_str: String = prop.get("name", "")
	if name_str.begins_with("resource_") or name_str == "script":
		return false
	return true
