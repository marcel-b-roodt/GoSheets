## Tests for ResourceScanner.
## Run via GdUnit4 (panel or headless CI).
extends GdUnitTestSuite

const ResourceScanner := preload("res://addons/go_sheets/scanner/resource_scanner.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Create a temporary directory tree under user:// for isolation.
## Returns the root path.  Call _cleanup() in after_each.
var _tmp_root: String = ""

func before_each() -> void:
	_tmp_root = "user://go_sheets_test_%d" % Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(_tmp_root)


func after_each() -> void:
	_remove_dir_recursive(_tmp_root)
	_tmp_root = ""


func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = false
	dir.include_navigational = false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path + "/" + entry
		if dir.current_is_dir():
			_remove_dir_recursive(full)
			DirAccess.remove_absolute(full)
		else:
			DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _touch(path: String) -> void:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string("")
	fa.close()


func _mkdir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_returns_empty_array_for_nonexistent_path() -> void:
	var result := ResourceScanner.scan("res://nonexistent_path_xyz_abc/")
	assert_array(result).is_empty()


func test_returns_empty_array_for_empty_directory() -> void:
	var result := ResourceScanner.scan(_tmp_root)
	assert_array(result).is_empty()


func test_finds_tres_file_at_root() -> void:
	_touch(_tmp_root + "/my_item.tres")
	var result := ResourceScanner.scan(_tmp_root)
	assert_array(result).has_size(1)
	assert_bool(result[0].ends_with("my_item.tres")).is_true()


func test_finds_res_file_at_root() -> void:
	_touch(_tmp_root + "/my_item.res")
	var result := ResourceScanner.scan(_tmp_root)
	assert_array(result).has_size(1)
	assert_bool(result[0].ends_with("my_item.res")).is_true()


func test_ignores_non_resource_files() -> void:
	_touch(_tmp_root + "/readme.txt")
	_touch(_tmp_root + "/script.gd")
	_touch(_tmp_root + "/scene.tscn")
	var result := ResourceScanner.scan(_tmp_root)
	assert_array(result).is_empty()


func test_finds_files_in_nested_subdirectory() -> void:
	_mkdir(_tmp_root + "/items/weapons")
	_touch(_tmp_root + "/items/weapons/sword.tres")
	var result := ResourceScanner.scan(_tmp_root)
	assert_array(result).has_size(1)
	assert_bool(result[0].ends_with("sword.tres")).is_true()


func test_finds_multiple_files_at_different_depths() -> void:
	_touch(_tmp_root + "/root.tres")
	_mkdir(_tmp_root + "/sub")
	_touch(_tmp_root + "/sub/child.tres")
	_touch(_tmp_root + "/sub/other.res")
	var result := ResourceScanner.scan(_tmp_root)
	assert_array(result).has_size(3)


func test_does_not_return_directory_names() -> void:
	_mkdir(_tmp_root + "/items.tres")  # directory with .tres extension
	var result := ResourceScanner.scan(_tmp_root)
	assert_array(result).is_empty()


func test_trailing_slash_on_root_path_is_handled() -> void:
	_touch(_tmp_root + "/item.tres")
	var result_with_slash := ResourceScanner.scan(_tmp_root + "/")
	var result_without := ResourceScanner.scan(_tmp_root)
	assert_array(result_with_slash).has_size(result_without.size())
