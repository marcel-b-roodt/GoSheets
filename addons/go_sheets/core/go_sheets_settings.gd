@tool
## GoSheetsSettings
##
## Persists plugin configuration to user://go_sheets_settings.tres.
## Loaded once at plugin startup; saved explicitly after mutations.
##
## Fields:
##   scan_root         — the root path the scanner watches (default "res://")
##   last_selected_type — the class_name the user last viewed (may be ""
##                        on first run)
##   column_layouts    — Dictionary keyed by class_name String; each value is
##                       an Array[Dictionary] of ColumnDef-compatible dicts.
##                       Populated by the grid layer in Stage 1+.
class_name GoSheetsSettings
extends Resource

const SAVE_PATH := "user://go_sheets_settings.tres"

@export var scan_root: String = "res://"
@export var last_selected_type: String = ""
## Stores column layout per resource type.
## Key: class_name (String), Value: Array of column-def Dictionaries.
@export var column_layouts: Dictionary = {}


# ---------------------------------------------------------------------------
# Load / Save
# ---------------------------------------------------------------------------

## Load settings from disk, or return a fresh default instance if none exist.
static func load_or_create() -> GoSheetsSettings:
	if ResourceLoader.exists(SAVE_PATH):
		var loaded := ResourceLoader.load(SAVE_PATH, "GoSheetsSettings")
		if loaded is GoSheetsSettings:
			return loaded as GoSheetsSettings
	return GoSheetsSettings.new()


## Persist the current state to disk.
func save() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	if err != OK:
		push_error("GoSheetsSettings: failed to save settings (error %d)" % err)
