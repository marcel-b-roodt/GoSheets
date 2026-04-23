## TypeRegistry
##
## Enumerates all script-defined classes that extend Resource and are visible
## to the current Godot project.
##
## Uses ProjectSettings.get_global_class_list() which returns every class
## registered via `class_name` in a GDScript file.  Only classes whose
## inheritance chain includes "Resource" are kept.
##
## Pure logic — no EditorPlugin dependency; fully testable headlessly.
##
## Usage:
##   var types: Array[Dictionary] = TypeRegistry.get_resource_types()
##   # Each dict: { "class": StringName, "path": String, "base": StringName }
class_name TypeRegistry
extends RefCounted


## Return all project script-classes that extend Resource (directly or
## transitively).  Each entry is a Dictionary with keys:
##   "class"  — StringName  class_name of the script
##   "path"   — String      res:// path to the .gd file
##   "base"   — StringName  immediate parent class name
static func get_resource_types() -> Array[Dictionary]:
	var all_classes: Array = ProjectSettings.get_global_class_list()
	var resource_types: Array[Dictionary] = []

	for entry: Dictionary in all_classes:
		if _extends_resource(entry.get("class", &""), all_classes):
			resource_types.append({
				"class": entry.get("class", &""),
				"path":  entry.get("path",  ""),
				"base":  entry.get("base",  &""),
			})

	resource_types.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["class"] as String) < (b["class"] as String)
	)
	return resource_types


## Return just the sorted list of class names, for populating UI dropdowns.
static func get_resource_type_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for entry: Dictionary in get_resource_types():
		names.append(entry["class"])
	return names


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Check whether [param class_name_] inherits from Resource, walking the
## project class list for script-defined parents and ClassDB for built-ins.
static func _extends_resource(cls: StringName, all_classes: Array) -> bool:
	if cls == &"":
		return false
	var visited: Dictionary = {}
	return _walk_inheritance(cls, all_classes, visited)


static func _walk_inheritance(
		current: StringName,
		all_classes: Array,
		visited: Dictionary) -> bool:

	if current == &"Resource":
		return true
	if current == &"Object" or current == &"RefCounted" or current == &"":
		# Reached a built-in root that is not Resource
		# (RefCounted does not inherit Resource)
		return false
	if visited.has(current):
		return false
	visited[current] = true

	# Try to find a script-defined parent first
	for entry: Dictionary in all_classes:
		if entry.get("class", &"") == current:
			var base: StringName = entry.get("base", &"")
			return _walk_inheritance(base, all_classes, visited)

	# Fall back to ClassDB for built-in Godot classes
	if ClassDB.class_exists(current):
		if ClassDB.is_parent_class(current, "Resource"):
			return true
		var parent: StringName = ClassDB.get_parent_class(current)
		return _walk_inheritance(parent, all_classes, visited)

	return false
