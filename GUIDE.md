# GoSheets — How-To Guide

> Everything you need to start managing resources inside Godot with GoSheets.

---

## Table of Contents

1. [The big idea](#the-big-idea)
2. [Installation](#installation)
3. [The Resources panel](#the-resources-panel)
4. [Choosing a resource type](#choosing-a-resource-type)
5. [The spreadsheet grid](#the-spreadsheet-grid)
6. [Inline cell editing](#inline-cell-editing)
7. [Column management](#column-management)
8. [Sorting and filtering](#sorting-and-filtering)
9. [Undo and Redo](#undo-and-redo)
10. [Keyboard shortcuts](#keyboard-shortcuts)
11. [Cell type reference](#cell-type-reference)

---

## The big idea

Godot Resources (`.tres` / `.res` files) are a natural way to store game data: item stats, ability configs, localization strings, quest definitions. But the Inspector only shows one resource at a time, and the FileSystem dock is just a file list.

GoSheets puts all your resources of a given type into a single spreadsheet view. One row per resource, one column per exported property. Edit, sort, filter, and navigate without leaving Godot.

---

## Installation

1. Copy the `addons/go_sheets/` folder into your project's `addons/` folder.
2. Open **Project → Project Settings → Plugins**.
3. Find **GoSheets** and set it to **Enabled**.
4. A **Resources** tab appears in Godot's top centre bar (next to 2D / 3D / Script).

---

## The Resources panel

Click **Resources** in Godot's top bar. The panel fills the main viewport area.

| Section | What it does |
|---|---|
| **Type selector** | Dropdown listing every `class_name` in your project that extends `Resource`. |
| **Search bar** | Live text filter across all visible string columns. |
| **Grid** | The spreadsheet table. One row per resource instance, one column per `@export` property. |
| **Filename column** | First column, always visible, dark-tinted to signal read-only. Shows the `.tres` filename. |

If the dropdown is empty, your project has no `class_name … extends Resource` declarations. Create a GDScript with `class_name` and `extends Resource`, add some `@export` properties, and create at least one `.tres` file of that type.

---

## Choosing a resource type

1. Click the **type selector** dropdown at the top of the panel.
2. Select a resource type. The grid populates with every `.tres` / `.res` instance of that type found under your scan root (default: `res://`).
3. Column headers are derived automatically from the type's `@export` properties.

> **Tip:** GoSheets discovers types from `ProjectSettings.get_global_class_list()`. Only classes that extend `Resource` appear.

---

## The spreadsheet grid

Each row is one resource file. Each column is one exported property.

| Action | How to do it |
|---|---|
| **Select a row** | Click any cell in the row. The resource is forwarded to Godot's Inspector. |
| **Multi-select rows** | Hold **Shift** and click to select a range. Hold **Ctrl** and click to toggle individual rows. |
| **Scroll** | Mouse wheel or drag the scrollbar. |

GoSheets recycles row nodes for performance. Hundreds of resources scroll smoothly.

---

## Inline cell editing

Click a cell and press **Enter** or **F2** to open the inline editor for that property.

| Property type | Editor widget |
|---|---|
| `String` | `LineEdit` text field |
| `int` | `SpinBox` (no range hint) or slider + spinbox (`PROPERTY_HINT_RANGE`) |
| `float` | `SpinBox` (no range hint) or slider + spinbox (`PROPERTY_HINT_RANGE`) |
| `bool` | `CheckBox` toggle |
| `Color` | `ColorPickerButton` |
| Enum (`@export_enum` or `PROPERTY_HINT_ENUM`) | `OptionButton` dropdown |
| Resource reference (`PROPERTY_HINT_RESOURCE_TYPE`) | Godot's built-in `EditorResourcePicker` |
| `Array[Resource]` | Row list with Browse + Remove per entry |
| `Array[String]`, `Array[int]`, etc. | JSON `TextEdit` or per-element editor |
| `Dictionary` | Structured key/value row editor with Add / Remove |

**To commit an edit:** press **Enter** or click away. The value is saved to disk immediately.

**To cancel:** press **Escape**. The old value is restored.

All edits go through Godot's `EditorUndoRedoManager`. **Ctrl+Z** undoes, **Ctrl+Shift+Z** redoes.

---

## Column management

### Column visibility

Right-click a column header or use the column context menu to show/hide columns. Hidden columns can be restored from the same menu.

### Column collapse

Click the **◀** icon in a column header to collapse it to a narrow strip. Click **▶** to expand it. Use **⊞ Expand All** to expand every collapsed column at once.

### Column reorder

Drag a column header left or right to reorder columns. The layout is saved per type and persists across editor sessions.

### Column resize

Drag the divider between column headers to resize. Collapse a column for more space.

### Sort by column

Click a column header to sort ascending. Click again for descending. A third click clears the sort. The sort direction is shown by an arrow icon in the header.

---

## Sorting and filtering

### Sort

Click any column header to cycle through ascending → descending → unsorted. Sort is stable: equal values preserve their previous order.

### Filter

Type in the **search bar** at the top of the panel. Rows are filtered in real-time across all visible string-type columns. The filter is debounced to avoid excessive rebuilds.

---

## Undo and Redo

All property changes made through GoSheets are fully undoable through Godot's standard undo stack.

| Action | Shortcut |
|---|---|
| Undo | **Ctrl+Z** |
| Redo | **Ctrl+Shift+Z** |

This covers inline cell edits and any property changes committed through the grid.

---

## Keyboard shortcuts

| Key / Combo | Action |
|---|---|
| **Enter** or **F2** | Open cell editor for the focused cell |
| **Tab** | Move to next editable column (skips collapsed); wraps to next row |
| **Shift+Tab** | Move to previous editable column (skips collapsed); wraps to previous row |
| **Escape** | Cancel current edit and close the cell editor |
| **Ctrl+Z** | Undo |
| **Ctrl+Shift+Z** | Redo |

Tab navigation wraps across row boundaries and cycles at the dataset edges. Collapsed columns and pinned read-only columns are skipped automatically.

---

## Cell type reference

Every `@export` property type maps to a dedicated cell editor.

| Property type | Hint | Cell editor | Notes |
|---|---|---|---|
| `String` | — | `LineEdit` | Plain text input |
| `int` | — | `SpinBox` | Integer-only, no slider |
| `int` | `PROPERTY_HINT_RANGE` | slider + `SpinBox` | Min/max/step parsed from hint_string |
| `float` | — | `SpinBox` | Floating-point, no slider |
| `float` | `PROPERTY_HINT_RANGE` | slider + `SpinBox` | Min/max/step parsed from hint_string |
| `bool` | — | `CheckBox` | Toggle |
| `Color` | — | `ColorPickerButton` | Opens Godot's color picker |
| Enum | `PROPERTY_HINT_ENUM` | `OptionButton` | Names resolved from hint_string |
| Resource | `PROPERTY_HINT_RESOURCE_TYPE` | `EditorResourcePicker` | Godot's standard resource picker |
| `Array[Resource]` | — | Scrollable row list | Browse opens `ResourcePickerPopup`, Remove deletes entry |
| `Array[scalar]` | — | JSON `TextEdit` | Edit array as JSON text |
| `Dictionary` | — | Key/value row editor | Add / Remove rows; values accept JSON scalars or `res://` paths |

### ResourcePickerPopup

Used by array row editors and dictionary value buttons. Features:
- Scans all `.tres` files and reads `script_class=` header to identify GDScript-defined types
- Filters by class inheritance (only shows resources matching the expected type)
- Live filename search
- Browse button to open Godot's full resource picker

---

## What's coming

GoSheets is in active development. Planned features include:

- Resource creation, duplication, and deletion from the toolbar
- Column pinning and computed columns
- Advanced multi-condition filters
- Cross-reference lookup ("where is this resource used?")
- CSV and JSON import/export
- Full keyboard-first workflow

See the [roadmap](docs/roadmap.md) and [feature registry](docs/feature-registry.md) for the full plan.