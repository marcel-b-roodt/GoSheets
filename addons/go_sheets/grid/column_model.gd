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
		# Restore saved layout, then append any new properties not yet in layout
		var seen: Dictionary = {}
		for d: Dictionary in saved_dicts:
			var col: ColumnDef = _COLUMN_DEF_SCRIPT.from_dict(d)
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
			if entry.get("class", &"") == type_name:
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
