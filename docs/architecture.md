# GoSheets — Architecture

> **Who this is for:** contributors and anyone curious about how the plugin is structured internally.
> For *using* GoSheets, see [GUIDE.md](../GUIDE.md).

---

## Layer map

| Layer | Path | Description |
|---|---|---|
| Plugin entry point | `addons/go_sheets/plugin.gd` | `EditorPlugin` root. Declares GoSheets as a **main screen plugin** (`_has_main_screen() → true`, `_get_plugin_name() → "Resources"`); instantiates and owns the main panel. |
| Core / UI | `addons/go_sheets/core/` | Main screen panel (`GoSheetsPanel`), type selector, settings persistence. |
| Scanner | `addons/go_sheets/scanner/` | Resource file scanner (`ResourceScanner`), script-class registry (`TypeRegistry`). |
| Grid | `addons/go_sheets/grid/` | Grid renderer (`ResourceGrid`), column model (`ColumnModel` / `ColumnDef`), row widget (`GridRow`), cell editor popup (`CellEditor`). |
| Cell fields | `addons/go_sheets/cells/` | Per-property-type cell renderers and editors: `StringCellField`, `BoolCellField`, `ColorCellField`, `NumericCellField`, `EnumCellField`, `ResourceRefCellField`, `CollectionCellField`, `ResourcePickerPopup`. Base class: `CellField`. |
| Filters | `addons/go_sheets/filters/` | Filter/sort engine; expression evaluator for computed columns *(planned, not yet implemented)*. |
| Import/export | `addons/go_sheets/io/` | CSV/JSON import and export writers *(planned, not yet implemented)*. |
| Tests | `tests/` | GdUnit4 test suites mirroring the addon structure. |

---

## Key scripts

### `plugin.gd` — EditorPlugin entry point

GoSheets is a **main screen plugin**. It occupies the main viewport area alongside 2D, 3D, Script, and AssetLib. The user switches to it by clicking **"Resources"** in Godot's top centre bar.

Key overrides:
- `_has_main_screen() → true`
- `_get_plugin_name() → "Resources"`
- `_get_plugin_icon() → preload("res://addons/go_sheets/icon.svg")`
- `_make_visible(visible)` — shows/hides the panel
- `_enter_tree()` — instantiates `go_sheets_panel.tscn` and adds it to `EditorInterface.get_editor_main_screen()`
- `_exit_tree()` — cleans up the panel

### `core/go_sheets_panel.gd` — Main panel controller

Owns:
- Toolbar layout (type selector, search bar, action buttons)
- Current resource type selection
- Delegation to `ResourceGrid` for rendering
- Filter/sort state

### `core/go_sheets_settings.gd` — Settings persistence

Stores plugin configuration as a `Resource` in `user://`:
- Scan root path
- Last-selected type
- Per-type column layout data (order, visibility, width, collapse state)

### `core/type_selector.gd` — Type dropdown

Populated from `TypeRegistry`. Emits a signal when the user picks a new type, triggering a grid rebuild.

### `scanner/resource_scanner.gd` — Resource file discovery

Walks a configurable root path recursively via `DirAccess` and returns a list of `.tres`/`.res` file paths. Results are cached and rebuilt on demand (or when the filesystem changes).

### `scanner/type_registry.gd` — Script-class enumeration

Enumerates all `class_name` declarations that extend `Resource` using `ProjectSettings.get_global_class_list()` and `ResourceLoader`. Provides the type-selector dropdown with live classes only.

### `grid/column_def.gd` — Column definition

One `ColumnDef` per visible property. Derived automatically from `@export` annotations. Stores:
- `property_name: StringName`
- `property_type: Variant.Type`
- `display_name: String`
- `visible: bool`
- `width: int`
- `pinned: bool`
- `sort_direction: int` (0 = none, 1 = asc, -1 = desc)

### `grid/column_model.gd` — Column model

Builds and manages the list of `ColumnDef` objects for a given type. Handles:
- Auto-derivation from `@export` properties via `ClassDB`
- Layout restore from saved settings
- Reorder, visibility, collapse state persistence

### `grid/resource_grid.gd` — Grid renderer

The main spreadsheet widget. Owns:
- Header row with sort/collapse/drag controls
- Pooled row nodes (`GridRow`) recycled on scroll
- Row selection state
- Forwarding selected resources to the Inspector

### `grid/grid_row.gd` — Single row widget

Binds to one `Resource` instance. Renders cell values and handles click-to-edit.

### `grid/cell_editor.gd` — Cell editor popup

A popup that opens over a cell when the user presses Enter or F2. Delegates to the appropriate `CellField` subclass based on property type.

### `cells/cell_field.gd` — Base cell field

Abstract base for all cell editors. Defines the interface:
- `setup(property_def, resource)` — configure the field
- `get_value()` — return the current editor value
- `commit()` — apply the value via `EditorUndoRedoManager`

### `cells/` — Cell field subclasses

| File | Property type |
|---|---|
| `string_cell_field.gd` | `String` |
| `numeric_cell_field.gd` | `int` / `float` (plain and `PROPERTY_HINT_RANGE`) |
| `bool_cell_field.gd` | `bool` |
| `color_cell_field.gd` | `Color` |
| `enum_cell_field.gd` | `@export_enum` / `PROPERTY_HINT_ENUM` |
| `resource_ref_cell_field.gd` | `PROPERTY_HINT_RESOURCE_TYPE` |
| `collection_cell_field.gd` | `Array` and `Dictionary` |
| `resource_picker_popup.gd` | Searchable popup for selecting resources by type |

---

## Language policy

**All plugin code is GDScript.** No C#, no GDExtension. This ensures the plugin works in every Godot 4 project regardless of whether the user has .NET installed. The operations in GoSheets are I/O-bound and UI-bound, not CPU-bound, so GDExtension complexity is not justified.

---

## Self-preload rule

Godot scans scripts alphabetically. If script A uses class `B` as a type annotation but `B`'s script hasn't been compiled yet, the class resolves to `null` and A is cached with an error.

**Rule:** every script that uses another GoSheets class name at **compile time** (typed vars, parameters, return types, `@export` annotations) must `preload` that script at the top of the file, in dependency order.

Runtime-only uses (`is` checks, `as` casts) do **not** require preloads.

---

## Undo/Redo pattern

Every property mutation in GoSheets goes through `EditorUndoRedoManager`:

```gdscript
var ur := EditorInterface.get_editor_undo_redo()
ur.create_action("Edit %s.%s" % [resource.resource_path, property])
ur.add_do_property(resource, property, new_value)
ur.add_undo_property(resource, property, old_value)
ur.commit_action()
```

This ensures every change is reversible and the resource is saved to disk immediately on commit.

---

## Editor-only guard

All editor-only code is guarded:

```gdscript
func _ready() -> void:
    if not Engine.is_editor_hint():
        return
    # editor setup here
```

GoSheets must not add runtime overhead to published games.

---

## Testing

Framework: **GdUnit4** (install from AssetLib).

Tests mirror the source path under `tests/`:

```
tests/
  scanner/
    resource_scanner_test.gd
    type_registry_test.gd
  core/
    go_sheets_settings_test.gd
  grid/
    column_model_test.gd
    column_model_reorder_test.gd
    cell_editor_test.gd
    cell_editor_popup_size_test.gd
    grid_row_test.gd
    resource_grid_navigation_test.gd
    spell_metadata_columns_test.gd
  cells/
    string_cell_field_test.gd
    numeric_plain_cell_field_test.gd
    numeric_range_cell_field_test.gd
    bool_cell_field_test.gd
    color_cell_field_test.gd
    enum_cell_field_test.gd
    resource_ref_cell_field_test.gd
    resource_picker_popup_test.gd
    collection_cell_field_test.gd
```

Run locally: open the GdUnit4 panel in Godot → **Run all tests**.
Run in CI: `MikeSchulze/gdUnit4-action` on every push/PR via `.github/workflows/ci.yml`.