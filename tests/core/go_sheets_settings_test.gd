## Tests for GoSheetsSettings.
## Run via GdUnit4.
extends GdUnitTestSuite

const GoSheetsSettings := preload("res://addons/go_sheets/core/go_sheets_settings.gd")

# Use a test-specific save path to avoid clobbering real settings.
const TEST_SAVE_PATH := "user://go_sheets_settings_test.tres"

func after_each() -> void:
	# Clean up any file written during a test.
	if ResourceLoader.exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(TEST_SAVE_PATH))

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

func test_new_instance_has_default_scan_root() -> void:
	var s := GoSheetsSettings.new()
	assert_str(s.scan_root).is_equal("res://")


func test_new_instance_has_empty_last_selected_type() -> void:
	var s := GoSheetsSettings.new()
	assert_str(s.last_selected_type).is_equal("")


func test_new_instance_has_empty_column_layouts() -> void:
	var s := GoSheetsSettings.new()
	assert_int(s.column_layouts.size()).is_equal(0)

# ---------------------------------------------------------------------------
# load_or_create — no file on disk → returns fresh defaults
# ---------------------------------------------------------------------------

func test_load_or_create_returns_instance_when_no_file_exists() -> void:
	# Ensure the test path is absent
	if ResourceLoader.exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

	# Temporarily patch SAVE_PATH by instantiating and reading defaults
	var s := GoSheetsSettings.new()
	assert_object(s).is_not_null()
	assert_str(s.scan_root).is_equal("res://")

# ---------------------------------------------------------------------------
# Save + reload round-trip
# ---------------------------------------------------------------------------

func test_save_and_reload_preserves_scan_root() -> void:
	var s := GoSheetsSettings.new()
	s.scan_root = "res://data/"

	# Save to test path via ResourceSaver directly (avoids patching const)
	var err := ResourceSaver.save(s, TEST_SAVE_PATH)
	assert_int(err).is_equal(OK)

	var loaded := ResourceLoader.load(TEST_SAVE_PATH, "GoSheetsSettings")
	assert_object(loaded).is_not_null()
	assert_str((loaded as GoSheetsSettings).scan_root).is_equal("res://data/")


func test_save_and_reload_preserves_last_selected_type() -> void:
	var s := GoSheetsSettings.new()
	s.last_selected_type = "ItemData"

	ResourceSaver.save(s, TEST_SAVE_PATH)
	var loaded := ResourceLoader.load(TEST_SAVE_PATH, "GoSheetsSettings") as GoSheetsSettings
	assert_str(loaded.last_selected_type).is_equal("ItemData")


func test_save_and_reload_preserves_column_layouts() -> void:
	var s := GoSheetsSettings.new()
	s.column_layouts["ItemData"] = [{"name": "damage", "visible": true}]

	ResourceSaver.save(s, TEST_SAVE_PATH)
	var loaded := ResourceLoader.load(TEST_SAVE_PATH, "GoSheetsSettings") as GoSheetsSettings
	assert_bool(loaded.column_layouts.has("ItemData")).is_true()
	assert_int(loaded.column_layouts["ItemData"].size()).is_equal(1)
