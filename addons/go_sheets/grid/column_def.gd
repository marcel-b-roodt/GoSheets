## ColumnDef
##
## Describes a single column in the GoSheets grid.
## Derived from an @export property of the viewed Resource type.
## Stored in GoSheetsSettings.column_layouts per resource type.
class_name ColumnDef
extends RefCounted

## Special sentinel for the synthetic resource-filename column.
const FILENAME_COLUMN: StringName = &"__filename__"

## Internal property name as returned by ClassDB / get_property_list().
var property_name: StringName = &""
## Human-readable header label (defaults to property_name with _ replaced by space).
var display_name: String = ""
## Godot Variant.Type constant for this property.
var property_type: int = TYPE_NIL
## Hint string from PropertyInfo (used for enums, ranges, etc.).
var hint_string: String = ""
## PropertyHint constant.
var hint: int = PROPERTY_HINT_NONE
## Whether the column is currently shown in the grid.
var visible: bool = true
## Column width in pixels (stored and restored; ignored while collapsed).
var width: int = 120
## Whether this column is collapsed to a narrow strip.
## Collapsed columns show only a resize handle + tooltip; cells are hidden.
var collapsed: bool = false
## Whether this column is pinned to the left.
var pinned: bool = false
## 0 = unsorted, 1 = ascending, -1 = descending.
var sort_direction: int = 0


func _init(
		p_name: StringName = &"",
		p_type: int = TYPE_NIL,
		p_hint: int = PROPERTY_HINT_NONE,
		p_hint_string: String = "") -> void:
	property_name = p_name
	property_type = p_type
	hint = p_hint
	hint_string = p_hint_string
	display_name = _make_display_name(p_name)


## Serialise to a plain Dictionary for storage in GoSheetsSettings.
func to_dict() -> Dictionary:
	return {
		"property_name": property_name,
		"display_name":  display_name,
		"property_type": property_type,
		"hint_string":   hint_string,
		"hint":          hint,
		"visible":       visible,
		"width":         width,
		"collapsed":     collapsed,
		"pinned":        pinned,
		"sort_direction": sort_direction,
	}


## Restore a ColumnDef from a stored Dictionary.
static func from_dict(d: Dictionary) -> ColumnDef:
	var col := ColumnDef.new(
		d.get("property_name", &""),
		d.get("property_type", TYPE_NIL),
		d.get("hint", PROPERTY_HINT_NONE),
		d.get("hint_string", ""),
	)
	col.display_name   = d.get("display_name",   col.display_name)
	col.visible        = d.get("visible",         true)
	col.width          = d.get("width",           120)
	col.collapsed      = d.get("collapsed",       false)
	col.pinned         = d.get("pinned",          false)
	col.sort_direction = d.get("sort_direction",  0)
	return col


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

static func _make_display_name(p_name: StringName) -> String:
	# "attack_damage" → "Attack Damage"
	var s := (p_name as String).replace("_", " ")
	if s.is_empty():
		return s
	return s[0].to_upper() + s.substr(1)
