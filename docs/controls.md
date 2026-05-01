# GoSheets — Control Scheme

Design reference for every keyboard shortcut, mouse interaction, and UX pattern in GoSheets.
This document covers **implemented** controls and **planned** controls so the full scheme can be evaluated as a whole before implementation.

Status legend: ✅ Implemented · 📋 Planned

---

## Design Philosophy

| Principle | Decision |
|---|---|
| **Keyboard-first** | Every action reachable without the mouse. Tab navigation, Enter to edit, Escape to cancel. |
| **Spreadsheet muscle-memory** | Tab/Shift+Tab, Enter, Escape follow the conventions of Excel/Sheets and Godot's Inspector. |
| **Collapsed columns are skipped** | Tab navigation jumps over collapsed and pinned-read-only columns so the flow stays on editable data. |
| **Panel buttons = discoverability** | Every keyboard action also has a visible button or header-click trigger. |
| **Right-click = context menu** | Column operations surfaced at the cursor. |

---

## Grid Navigation

| Key / Combo | Action | Status |
|---|---|---|
| **Tab** | Move focus to next editable column; wraps to next row at end | ✅ |
| **Shift+Tab** | Move focus to previous editable column; wraps to previous row at start | ✅ |
| **Enter** or **F2** | Open cell editor for the focused cell | ✅ |
| **Escape** | Cancel current edit, close cell editor, restore old value | ✅ |
| **Arrow keys** | Move focus between cells (grid navigation) | 📋 |
| **Home** | Move focus to first column of current row | 📋 |
| **End** | Move focus to last visible column of current row | 📋 |
| **Page Up / Page Down** | Scroll grid by one viewport height | 📋 |

---

## Row Selection

| Input | Effect | Status |
|---|---|---|
| Left-click (on row) | Select single row; forward to Inspector | ✅ |
| **Shift** + Left-click | Range select | ✅ |
| **Ctrl** + Left-click | Toggle row in/out of multi-selection | ✅ |
| **Ctrl+A** | Select all rows (visible after filter) | 📋 |
| **Escape** | Deselect all rows | 📋 |

---

## Cell Editing

| Key / Combo | Context | Action | Status |
|---|---|---|---|
| **Enter** / **F2** | Any editable cell | Open inline editor | ✅ |
| **Escape** | Cell editor open | Cancel edit, restore value | ✅ |
| **Tab** | Cell editor open | Commit edit, move to next editable cell | ✅ |
| **Shift+Tab** | Cell editor open | Commit edit, move to previous editable cell | ✅ |
| **Enter** (in text/numeric editor) | LineEdit / SpinBox | Commit edit | ✅ |
| **Ctrl+Z** | Any | Undo last edit | ✅ |
| **Ctrl+Shift+Z** | Any | Redo | ✅ |

---

## Column Operations

| Input | Effect | Status |
|---|---|---|
| Click column header | Sort ascending → descending → unsorted | ✅ |
| Drag column header | Reorder column | ✅ |
| Drag column divider | Resize column width | ✅ |
| Double-click column divider | Auto-fit column width to content (max-width cap) | 📋 |
| Click ◀ in header | Collapse column to indicator strip | ✅ |
| Click ▶ in header (collapsed) | Expand column | ✅ |
| Right-click column header | Context menu: visibility, sort, collapse/expand | ✅ |
| **⊞ Expand All** button | Expand all collapsed columns | ✅ |
| **Pin column** | Pin to left (freeze pane) | 📋 |

---

## Toolbar Actions

| Button / Key | Action | Status |
|---|---|---|
| Type selector dropdown | Switch which resource type is displayed | ✅ |
| Search bar | Live text filter across string columns | ✅ |
| **Refresh** | Re-scan filesystem for new/deleted resources | ✅ |
| **New resource** | Create a new `.tres` of the selected type | 📋 |
| **Duplicate** | Copy selected resource to new file | 📋 |
| **Delete** | Move selected resource(s) to trash | 📋 |

---

## Undo / Redo

| Key / Combo | Action | Status |
|---|---|---|
| **Ctrl+Z** | Undo | ✅ |
| **Ctrl+Shift+Z** | Redo | ✅ |

All GoSheets mutations (cell edits, resource creation/deletion when implemented) go through `EditorUndoRedoManager`.

---

## Planned: Resource Lifecycle (Stage 3)

| Key / Combo | Action | Status |
|---|---|---|
| **Ctrl+N** | New resource (of current type) | 📋 |
| **Ctrl+D** | Duplicate selected resource | 📋 |
| **Delete** | Move selected resource(s) to trash | 📋 |
| **F2** (on filename column) | Rename resource file | 📋 |

---

## Planned: Advanced Filter (Stage 5)

| Key / Combo | Action | Status |
|---|---|---|
| **Ctrl+F** | Focus the search bar | 📋 |
| Filter button | Open advanced multi-condition filter panel | 📋 |
| **Ctrl+Shift+F** | Clear all filters | 📋 |

---

## Planned: Import / Export (Stage 6)

| Key / Combo | Action | Status |
|---|---|---|
| **Ctrl+Shift+E** | Export current view to CSV | 📋 |
| **Ctrl+Shift+I** | Import from CSV | 📋 |
| **Ctrl+C** (with row selection) | Copy selected rows as TSV to clipboard | 📋 |

---

## Summary Table — Current Implementation State

| Category | Done | Planned |
|---|---|---|
| Grid navigation (Tab, Enter, Escape) | ✅ | Arrow keys, Home/End, Page Up/Down |
| Row selection (click, Shift, Ctrl) | ✅ | Ctrl+A, Escape to deselect |
| Cell editing (all scalar + collection types) | ✅ | — |
| Undo/redo | ✅ | — |
| Column operations (sort, reorder, resize, collapse) | ✅ | Pin, auto-fit divider double-click |
| Toolbar (type selector, search, refresh) | ✅ | New/Duplicate/Delete buttons |
| Resource lifecycle | — | Stage 3 (Ctrl+N, Ctrl+D, Delete, F2 rename) |
| Advanced filter | — | Stage 5 (Ctrl+F, filter panel, Ctrl+Shift+F) |
| Import / export | — | Stage 6 (CSV, clipboard) |