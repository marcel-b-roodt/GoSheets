## Tests for TypeRegistry.
## Run via GdUnit4.
##
## TypeRegistry depends on ProjectSettings.get_global_class_list() which
## returns script classes registered in the *current* project.  The tests
## cover the pure inheritance-walk logic directly by calling the private
## helpers indirectly through the public API with synthetic class lists.
extends GdUnitTestSuite

const TypeRegistry := preload("res://addons/go_sheets/scanner/type_registry.gd")

# ---------------------------------------------------------------------------
# Helpers — build synthetic class-list arrays
# ---------------------------------------------------------------------------

## Build a fake global class list entry.
static func _make_entry(cls: StringName, base: StringName, path: String = "") -> Dictionary:
	return {"class": cls, "base": base, "path": path}


# ---------------------------------------------------------------------------
# _extends_resource (internal logic) via synthetic lists
# ---------------------------------------------------------------------------

func test_direct_resource_child_is_detected() -> void:
	# Build a list where MyItem extends Resource directly
	var fake_list: Array = [
		_make_entry(&"MyItem", &"Resource", "res://data/my_item.gd"),
	]
	var result := TypeRegistry._extends_resource(&"MyItem", fake_list)
	assert_bool(result).is_true()


func test_nested_resource_child_is_detected() -> void:
	# MyWeapon -> Item -> Resource
	var fake_list: Array = [
		_make_entry(&"Item",     &"Resource", "res://data/item.gd"),
		_make_entry(&"MyWeapon", &"Item",     "res://data/my_weapon.gd"),
	]
	var result := TypeRegistry._extends_resource(&"MyWeapon", fake_list)
	assert_bool(result).is_true()


func test_non_resource_script_class_is_rejected() -> void:
	# Helper extends RefCounted — not a Resource
	var fake_list: Array = [
		_make_entry(&"Helper", &"RefCounted", "res://util/helper.gd"),
	]
	var result := TypeRegistry._extends_resource(&"Helper", fake_list)
	assert_bool(result).is_false()


func test_node_subclass_is_rejected() -> void:
	var fake_list: Array = [
		_make_entry(&"MyNode", &"Node", "res://my_node.gd"),
	]
	var result := TypeRegistry._extends_resource(&"MyNode", fake_list)
	assert_bool(result).is_false()


func test_empty_class_name_is_rejected() -> void:
	var result := TypeRegistry._extends_resource(&"", [])
	assert_bool(result).is_false()


func test_unknown_class_name_is_rejected() -> void:
	var result := TypeRegistry._extends_resource(&"DoesNotExist", [])
	assert_bool(result).is_false()


# ---------------------------------------------------------------------------
# get_resource_types — integration (uses real ProjectSettings)
# ---------------------------------------------------------------------------

func test_get_resource_types_returns_array() -> void:
	var result := TypeRegistry.get_resource_types()
	# The project may have zero script classes, but should return an Array
	assert_array(result).is_not_null()


func test_get_resource_types_entries_have_required_keys() -> void:
	var result := TypeRegistry.get_resource_types()
	for entry: Dictionary in result:
		assert_bool(entry.has("class")).is_true()
		assert_bool(entry.has("path")).is_true()
		assert_bool(entry.has("base")).is_true()


func test_get_resource_types_is_sorted_alphabetically() -> void:
	var result := TypeRegistry.get_resource_types()
	for i in range(1, result.size()):
		var prev := result[i - 1]["class"] as String
		var curr := result[i]["class"] as String
		assert_bool(prev <= curr).is_true()


func test_get_resource_type_names_matches_get_resource_types() -> void:
	var types  := TypeRegistry.get_resource_types()
	var names  := TypeRegistry.get_resource_type_names()
	assert_int(names.size()).is_equal(types.size())
