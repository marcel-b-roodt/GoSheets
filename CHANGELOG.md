# Changelog

All notable changes to GoSheets will be documented in this file.

## [Unreleased]

---

## [0.1.2] — 2026-05-05

### Added
- Dirty-state indicator — amber tint on rows with unsaved changes; Save All button and dirty count label in toolbar; auto-save on panel focus loss; Ctrl+S flushes all dirty resources.

### Fixed
- SpinBox typed values now apply correctly before commit (typing a number and clicking away updates the value).
- `@tool` annotation added to all CellField scripts to fix editor loading failures.
- NodePath parsing fixed in VectorCellField (was referencing undefined `text` variable).
- Duplicate `_on_focus_exited` function removed from NumericCellField.
- Undo version initialised at startup to prevent all resources appearing dirty on first load.
- Sync timer no longer marks all resources dirty for GoSheets-initiated edits (only for external Inspector changes).
- Null-safety guard added for CellEditor in ResourceGrid.

---

## [0.1.1] — 2026-05-05

### Added
- Inline editing for all struct/vector types — `VectorCellField` displays and edits Vector2, Vector2i, Vector3, Vector3i, Vector4, Vector4i, Rect2, Rect2i, Transform2D, Transform3D, Basis, Quaternion, AABB, Plane, and NodePath using comma-separated input.
- Project README, LICENSE, GUIDE, and public documentation pages.

### Fixed
- Typed array class detection now resolves correctly regardless of `hint_string` value.
- Variant inference errors in grid row internals resolved with explicit `int` type annotations.
- Test resource `chain_lightning.tres` corrected to use proper typed `Array[Resource]` reference format.

---

## [0.1.0] - 2026-04-27

### Added

**Plugin foundation**
- Main-screen plugin (`plugin.gd`) — GoSheets occupies the "Resources" tab in Godot's top centre bar alongside 2D / 3D / Script / AssetLib tabs.
- Recursive `.tres` / `.res` file scanner (`ResourceScanner`) with configurable root path and caching.
- Script-class registry (`TypeRegistry`) enumerating all `class_name … extends Resource` declarations via `ProjectSettings.get_global_class_list()`.
- Settings persistence — scan root, last-selected type, and per-type column layouts saved to `user://`.
- `verify.sh` lint/parse gate (gdtoolkit), GdUnit4 test suite, and GitHub Actions CI workflow.

**Spreadsheet grid (read-only surface)**
- Type selector dropdown populated from the type registry.
- Auto-derived column definitions from `@export` properties — name, type, Variant.Type, `PropertyHint`, and hint_string all stored and serialised.
- Grid renderer with virtual / pooled rows; no per-row node allocation; handles hundreds of files cleanly.
- Row selection forwards the selected resource to Godot's built-in Inspector panel.
- Column visibility toggle, column collapse to a narrow indicator strip, column reorder by dragging headers.
- Sort ascending / descending by any column (header click or context menu).
- Live debounced text filter bar.
- Pinned read-only filename column always rendered as the first column with a dark tint to signal read-only state.

**Inline cell editing (popup editor)**
- String fields (`LineEdit`).
- Integer and float fields (`SpinBox`).
- Bool toggle (`CheckBox`).
- Enum picker via `PROPERTY_HINT_ENUM` — option names resolved from hint_string.
- Color picker via `ColorPickerButton`.
- Ranged numeric fields via `PROPERTY_HINT_RANGE` — slider + spinbox with min/max/step parsed from hint_string.
- Resource reference fields via `PROPERTY_HINT_RESOURCE_TYPE` — uses Godot's built-in `EditorResourcePicker`.
- `ResourcePickerPopup` — scans `.tres` files, reads `script_class=` header field to correctly identify GDScript-defined Resource subclasses, filters by class inheritance, live filename search.
- Typed `Array[Resource]` editor — scrollable row list, Browse (opens picker filtered to the element type) + Remove per entry.
- Scalar array editor — JSON `TextEdit` for plain-typed arrays such as `Array[String]`.
- Dictionary editor — structured key/value row editor with Add / Remove; values accept JSON scalars or `res://` paths resolved to Resources at commit time.
- All cell edits applied through `EditorUndoRedoManager`; changes saved to disk immediately on commit.

**Keyboard navigation**
- Enter / F2 opens the cell editor for the focused cell.
- Tab / Shift+Tab move to the next / previous editable column (collapsed and pinned columns skipped); wraps across row boundaries and cycles at dataset boundaries.
- Escape cancels an open edit without committing.
