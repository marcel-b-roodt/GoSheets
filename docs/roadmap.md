# GoSheets — Roadmap

> **North star:** Using resources in Godot for game logic should be simple and straightforward. A developer should be able to find, view, edit, create, and wire up every resource in their project without ever leaving the editor.

---

## Stage 0 — Foundation (Plugin skeleton + data layer)

The plugin boots, registers its dock, and can read resource files from disk. No UI beyond a placeholder panel.

| # | Feature | Notes |
|---|---|---|
| 0.1 | Plugin entry point — `plugin.gd` as a **main screen plugin** (`_has_main_screen() → true`, `_get_plugin_name() → "Resources"`); `GoSheetsPanel` added to `EditorInterface.get_editor_main_screen()` | Sits alongside 2D / 3D / Script in the top bar |
| 0.2 | Resource scanner — discover all `.tres`/`.res` files under a configurable root path | Recursive `DirAccess` walk; cached list |
| 0.3 | Script-class registry — enumerate all `class_name` types that extend `Resource` in the project | Uses `ProjectSettings` + `ResourceLoader.get_recognized_extensions_for_type` |
| 0.4 | Persistence layer — save/load plugin settings (root scan path, column layout, last-selected type) as a `Resource` stored in `user://` | |
| 0.5 | Verify + CI scaffolding — `verify.sh`, GdUnit4 test suite, GitHub Actions `ci.yml` | Port from GoSheets template |

**Exit criteria:** Plugin enables without errors; scanner returns a correct flat list of resource paths; settings survive editor restart.

---

## Stage 1 — Spreadsheet core (Read-only grid)

A scrollable, filterable table that shows all resources of a selected type, one resource per row, one property per column.

| # | Feature | Notes |
|---|---|---|
| 1.1 | Type selector — dropdown/list to pick which `Resource` subclass to view | Populated from Stage 0.3 registry |
| 1.2 | Column definition — auto-derive columns from `@export` properties of the selected type | Reflect via `ClassDB` / script inspection |
| 1.3 | Grid renderer — `GridContainer`-based table with header row and data rows | Virtual/pooled rows for performance (target: 500 rows at 60 fps) |
| 1.4 | Read-only cell display — render `int`, `float`, `String`, `bool`, `Color`, `Vector2`, `Vector3`, `NodePath`, `Resource` reference by type | Appropriate widget per type |
| 1.5 | Row selection — single and multi-select; syncs with the Godot Inspector | Clicking a row selects the resource in the Inspector |
| 1.6 | Column visibility toggle — show/hide individual columns; remembered per type | ✅ Persistent via Stage 0.4 settings |
| 1.7 | Column reordering — drag to reorder columns; remembered per type | |
| 1.8 | Sort by column — click header to sort ascending/descending | ✅ Stable sort; handles all cell types |
| 1.9 | Text search / filter bar — filter rows by substring across all visible string columns | ✅ Debounced live filter |

**Exit criteria:** Developer can open the dock, pick a resource type, see all matching resources in a scrollable table, sort, filter, and single-click to inspect a resource.

---

## Stage 2 — Inline editing

Make the grid editable so developers can tweak values without opening the Inspector.

| # | Feature | Notes |
|---|---|---|
| 2.1 | Inline cell editing — click a cell to edit it in place | `LineEdit` for strings; `SpinBox` for int/float; `CheckBox` for bool; `ColorPickerButton` for Color |
| 2.2 | Undo/redo integration — every cell edit is wrapped in `EditorUndoRedoManager` | |
| 2.3 | Multi-cell edit — select multiple rows and change a shared property for all of them at once | Batch undo action |
| 2.4 | Enum support — `@export_enum` / `@export` int with `PROPERTY_HINT_ENUM` renders as an `OptionButton` dropdown | Parse `hint_string` to populate items |
| 2.5 | Resource reference cells — `PROPERTY_HINT_RESOURCE_TYPE` renders as a button; click opens Godot's standard `EditorInterface` resource picker | |
| 2.6 | Ranged numeric cells — `PROPERTY_HINT_RANGE` int/float renders as a `SpinBox` (min/max/step from hint_string); optional inline slider if space allows | |
| 2.7 | Array property cells — collapsed summary view with expand-to-edit | `Array[int]`, `Array[String]`, etc. |
| 2.8 | Dirty-state indicator — mark rows/cells with unsaved changes; auto-save on focus loss (configurable) | |
| 2.9 | Keyboard navigation — Tab/Shift-Tab between cells, Enter to confirm, Escape to cancel | |

**Exit criteria:** Developer can edit any scalar, enum, or reference property directly in the grid; undo/redo works correctly; multi-select batch edit works.

---

## Stage 3 — Resource lifecycle management

Create, duplicate, and delete resources from within GoSheets.

| # | Feature | Notes |
|---|---|---|
| 3.1 | New resource — toolbar button creates a new instance of the selected type, saves as `.tres`, adds it to the table | File path chooser dialog |
| 3.2 | Duplicate resource — copy an existing resource to a new file | Deep vs. shallow copy option |
| 3.3 | Delete resource — remove from disk with confirmation; respects undo | Soft-delete pattern: move to trash via `OS.move_to_trash` |
| 3.4 | Rename / move resource — inline rename or drag-to-folder | Updates `uid://` references in the project |
| 3.5 | Bulk create — create N resources from a template, with auto-incremented names | Useful for item databases, skill tables, etc. |
| 3.6 | Inheritance — create a new resource that inherits from (`base_resource` pattern) an existing one | For layered stat systems |

**Exit criteria:** Developer can manage the full lifecycle of a resource type (create → edit → duplicate → delete) entirely from the GoSheets dock.

---

## Stage 4 — Column customization & property groups

Fine-grained control over which properties are shown and how.

| # | Feature | Notes |
|---|---|---|
| 4.1 | Column picker panel — checkboxes for every available property; grouped by `@export_group` / `@export_subgroup` | |
| 4.2 | Column pinning — pin 1–N columns to the left (like Excel freeze pane) | Useful for name/id columns |
| 4.3 | Column width — manual drag resize; double-click to auto-fit | ✅ Drag handle implemented; double-click auto-fit planned |
| 4.3b | Double-click divider auto-fit (QoL) — in Sheets view, double-click a divider to size the column to its visible content/header, clamped to a max width cap | Prevents very long content from creating overly wide columns |
| 4.3a | Column collapse — click ◀ in header to collapse to 16px strip with tooltip; click ▶ to expand; ⊞ to expand all | ✅ |
| 4.4 | Computed / derived columns — user-defined GDScript expression per column (e.g. `damage * speed`) | Read-only; expression sandbox |
| 4.5 | Nested resource expansion — expand a `Resource` reference cell to show its own properties as sub-columns | Depth-limited (max 2) |
| 4.6 | Per-type layout profiles — save named column layouts and switch between them | |

**Exit criteria:** Developer can configure exactly which columns appear, in what order, and at what width, and save those layouts per resource type.

---

## Stage 5 — Search, cross-reference & relationships

Understand how resources relate to each other across the project.

| # | Feature | Notes |
|---|---|---|
| 5.1 | Advanced filter — multi-condition filters (AND/OR) per column with comparisons (`=`, `!=`, `>`, `<`, `contains`) | |
| 5.2 | Full-text search across all resource types — find any resource by any property value | Index-backed; rebuilt on scan |
| 5.3 | "Where used" — find all scenes, other resources, and scripts that reference a resource | Reverse dependency lookup |
| 5.4 | Cross-type join view — show two resource types side by side linked by a shared reference property | E.g. Items + their associated AbilityData |
| 5.5 | Broken reference detector — highlight cells whose `Resource` reference points to a missing file | |
| 5.6 | Quick-assign — drag a resource from the GoSheets table onto a property in the Inspector or a scene node | |

**Exit criteria:** Developer can answer "which scene uses this item?" and "which items reference this ability?" without leaving the GoSheets dock.

---

## Stage 6 — Import / Export & bulk data workflows

Bridge the gap between GoSheets and external data tools.

| # | Feature | Notes |
|---|---|---|
| 6.1 | CSV export — export the current view (visible columns, current filter/sort) to `.csv` | Headers = column names |
| 6.2 | CSV import — create or update resources from a `.csv`; column headers map to property names; conflict resolution per row | |
| 6.3 | JSON export / import | Same semantics as CSV |
| 6.4 | Clipboard copy — copy selected rows as TSV for pasting into a spreadsheet app | |
| 6.5 | Diff view — show what changed since the last git commit for each resource | Uses `git diff` on `.tres` files |

**Exit criteria:** A game designer can maintain a balance spreadsheet in Excel/Sheets and import it directly into Godot resources with one click.

---

## Stage 7 — Polish, accessibility & documentation

| # | Feature | Notes |
|---|---|---|
| 7.1 | Keyboard-first workflow — every action (create, delete, edit, navigate, filter) reachable via keyboard | Full shortcut map in settings |
| 7.2 | Theming — respects Godot editor theme; dark/light compatible | |
| 7.3 | Tooltips and contextual help — hover any column header or toolbar button for a quick description | |
| 7.4 | Empty-state guidance — helpful onboarding message when no resource type is selected or no resources found | |
| 7.5 | Performance audit — 1000-row table at 60 fps; virtual row recycling; no per-frame allocations | Profiled and test-gated |
| 7.6 | Public docs — `README.md`, usage guide, column-type reference, FAQ | Shipped with the addon |
| 7.7 | Godot Asset Library submission | |

**Exit criteria:** v1.0 released to the Asset Library. A developer with zero prior knowledge can install the plugin and have a working resource spreadsheet in under 5 minutes.

---

## Post-v1.0 Ideas (not yet scheduled)

- Script-driven row colouring / conditional formatting
- Resource "tagging" system independent of properties
- Plugin-defined cell renderers (so other addons can extend GoSheets)
- Remote / Google Sheets sync (read-only live preview)
- Node-pinning: drag a Node from the scene tree to lock to a resource row

---

## Settings & configuration (planned for Stage 4 or standalone)

| # | Feature | Notes |
|---|---|---|
| S.1 | Resource path blacklist — user-defined list of glob/prefix patterns; any `.tres`/`.res` whose path matches is excluded from all scans | Default list filters out `addons/gdUnit4/**` and similar test-framework resources |
| S.2 | Type blacklist — exclude specific class names from the type selector dropdown | Useful for hiding base classes or internal types |

**Exit criteria:** Developer can configure the plugin to hide noise resources (e.g. GdUnit4 internal assets) without those cluttering the type selector or row list.

---

*Roadmap status is tracked row-by-row in [`docs/feature-registry.md`](feature-registry.md).*
