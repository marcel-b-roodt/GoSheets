## Tests for ResourcePickerPopup.
## Run via GdUnit4.

extends GdUnitTestSuite

const ResourcePickerPopup := preload("res://addons/go_sheets/cells/resource_picker_popup.gd")


func test_read_tres_type_returns_correct_type() -> void:
	# fireball.tres should have type="SpellMetadata" in its header
	var t := ResourcePickerPopup.read_tres_type(
		"res://test_scenes/data/spells/fireball.tres"
	)
	assert_str(t).is_equal("SpellMetadata")


func test_read_tres_type_returns_empty_for_res_file() -> void:
	# .gd files are not .tres — should return ""
	var t := ResourcePickerPopup.read_tres_type(
		"res://addons/go_sheets/scanner/resource_scanner.gd"
	)
	assert_str(t).is_equal("")


func test_read_tres_type_returns_empty_for_missing_file() -> void:
	var t := ResourcePickerPopup.read_tres_type("res://does_not_exist.tres")
	assert_str(t).is_equal("")


func test_open_populates_list_for_all_resources() -> void:
	var popup := ResourcePickerPopup.new()
	add_child(popup)
	await await_signal_on(popup, "ready")

	popup.open("")
	# We have test spell resources; the list should have at least one item
	assert_bool(popup._list.item_count > 0).is_true()
	assert_str(popup._base_type).is_equal("")

	popup.hide()
	remove_child(popup)
	popup.queue_free()


func test_open_filters_by_type() -> void:
	var popup := ResourcePickerPopup.new()
	add_child(popup)
	await await_signal_on(popup, "ready")

	popup.open("SpellMetadata")
	# All items in the list should be SpellMetadata resources
	var all_paths_match := true
	for i in popup._list.item_count:
		var path: String = popup._list.get_item_metadata(i)
		var file_type := ResourcePickerPopup.read_tres_type(path)
		if file_type != "SpellMetadata":
			all_paths_match = false
			break
	assert_bool(all_paths_match).is_true()

	popup.hide()
	remove_child(popup)
	popup.queue_free()


func test_search_filter_narrows_list() -> void:
	var popup := ResourcePickerPopup.new()
	add_child(popup)
	await await_signal_on(popup, "ready")

	popup.open("")
	var initial_count := popup._list.item_count

	# Filter to something unique — "fireball" should reduce the list size
	popup._on_search_changed("fireball")
	var filtered_count := popup._list.item_count

	assert_bool(filtered_count < initial_count).is_true()
	assert_bool(filtered_count > 0).is_true()

	popup.hide()
	remove_child(popup)
	popup.queue_free()


func test_item_activated_emits_resource_selected() -> void:
	var popup := ResourcePickerPopup.new()
	add_child(popup)
	await await_signal_on(popup, "ready")

	var emitted_path := ""
	popup.resource_selected.connect(func(p: String) -> void: emitted_path = p)

	popup.open("SpellMetadata")
	# Simulate activating the first item
	assert_bool(popup._list.item_count > 0).is_true()
	popup._on_item_activated(0)

	assert_bool(emitted_path != "").is_true()
	assert_bool(emitted_path.begins_with("res://")).is_true()

	remove_child(popup)
	popup.queue_free()
