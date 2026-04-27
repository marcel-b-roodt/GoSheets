# GoSheets — Feature Registry

The single source of truth for every feature's status. Updated after each task set.

**Status legend:** ✅ Complete · 🔧 In Progress · 📋 Planned · ❌ Removed / Deferred

---

## Stage 0 — Foundation

| # | Feature | Status |
|---|---|---|
| 0.1 | Plugin entry point — `plugin.gd`, dock registration, enable/disable | ✅ Main-screen plugin is implemented and mounts the Resources panel into Godot's editor main screen. |
| 0.2 | Resource scanner — discover `.tres`/`.res` files under a configurable root | ✅ Scanner exists with recursive discovery and dedicated test coverage. |
| 0.3 | Script-class registry — enumerate `Resource` subclasses in the project | ✅ Type registry populates the resource-type selector from global classes. |
| 0.4 | Settings persistence — `user://` resource for plugin config | ✅ Settings resource persists scan root, last-selected type, and column layout data. |
| 0.5 | Verify + CI scaffolding — `verify.sh`, GdUnit4, GitHub Actions | ✅ Local verify/test scripts and CI scaffolding are present; some runtime GdUnit cases still need repair. |

## Stage 1 — Spreadsheet Core (Read-only)

| # | Feature | Status |
|---|---|---|
| 1.1 | Type selector dropdown | ✅ Implemented in the main toolbar and populated from the type registry. |
| 1.2 | Auto-derived column definitions from `@export` properties | ✅ ColumnModel builds columns from exported properties and restores saved layouts. |
| 1.3 | Grid renderer with virtual/pooled rows | ✅ ResourceGrid and GridRow provide the read-only spreadsheet surface with recycled rows. |
| 1.4 | Read-only cell display (all scalar + reference types) | 🔧 Core scalar/resource display is in place; broader type coverage can still expand. |
| 1.5 | Row selection + Inspector sync | ✅ Selecting a row forwards the resource into Godot's Inspector. |
| 1.6 | Column visibility toggle | ✅ Visibility/collapse state is implemented and persisted through saved layouts. |
| 1.7 | Column reordering | ✅ Header drag-reorder is implemented and persisted through saved column layouts. |
| 1.8 | Sort by column | ✅ Header sorting and context-menu sort actions are implemented. |
| 1.9 | Text search / filter bar | ✅ Debounced live filter bar is implemented in the panel. |

## Stage 2 — Inline Editing

| # | Feature | Status |
|---|---|---|
| 2.1 | Inline cell editing | 🔧 Popup editor supports string, bool, enum, color, and numeric fields. Range-backed numeric popup editors now show slider + spinbox controls and commit pending values on close; resource picker, arrays, and inline-in-row embedding remain pending. |
| 2.2 | Undo/redo integration | ✅ Inline cell edits are applied through `EditorUndoRedoManager`, saved to disk, and refreshed back into the grid / Inspector. |
| 2.3 | Multi-cell batch edit | 📋 Planned |
| 2.4 | Enum support | ✅ `PROPERTY_HINT_ENUM` editing via `OptionButton` is implemented in the popup editor. |
| 2.5 | Resource reference picker | ✅ `PROPERTY_HINT_RESOURCE_TYPE` now uses a built-in editor resource picker field in inline cell editing. |
| 2.6 | Ranged numeric cells | ✅ `PROPERTY_HINT_RANGE` uses spinbox + slider controls with hint-string min/max/step parsing. |
| 2.7 | Array property cells | 🔧 Array and Dictionary cells now open a mini JSON editor popup with Apply/Reset, type validation, and inline commit; dedicated Dictionary key/value row editor UX remains planned. |
| 2.8 | Dirty-state indicator + auto-save option | 📋 Planned |
| 2.9 | Keyboard navigation | ✅ Enter/F2 open cell; Tab/Shift+Tab navigate editable columns (skipping collapsed), wrap across rows, and cycle at grid boundaries; Escape cancels. |

## Stage 3 — Resource Lifecycle

| # | Feature | Status |
|---|---|---|
| 3.1 | New resource creation | 📋 Planned |
| 3.2 | Duplicate resource | 📋 Planned |
| 3.3 | Delete resource (trash) | 📋 Planned |
| 3.4 | Rename / move resource | 📋 Planned |
| 3.5 | Bulk create | 📋 Planned |
| 3.6 | Resource inheritance | 📋 Planned |

## Stage 4 — Column Customization

| # | Feature | Status |
|---|---|---|
| 4.1 | Column picker panel | 📋 Planned |
| 4.2 | Column pinning | 📋 Planned |
| 4.3 | Column width resize | 🔧 Drag resize is implemented; divider double-click auto-fit remains pending as 4.3b. |
| 4.3a | Column collapse / expand strip | ✅ Header collapse controls and expand-all support are implemented. |
| 4.3b | Divider double-click auto-fit with max-width cap (QoL) | 📋 Planned |
| 4.4 | Computed / derived columns | 📋 Planned |
| 4.5 | Nested resource expansion | 📋 Planned |
| 4.6 | Per-type layout profiles | 📋 Planned |

## Stage 5 — Search & Relationships

| # | Feature | Status |
|---|---|---|
| 5.1 | Advanced multi-condition filter | 📋 Planned |
| 5.2 | Full-text search across all resource types | 📋 Planned |
| 5.3 | "Where used" reverse dependency lookup | 📋 Planned |
| 5.4 | Cross-type join view | 📋 Planned |
| 5.5 | Broken reference detector | 📋 Planned |
| 5.6 | Quick-assign drag to Inspector | 📋 Planned |

## Stage 6 — Import / Export

| # | Feature | Status |
|---|---|---|
| 6.1 | CSV export | 📋 Planned |
| 6.2 | CSV import | 📋 Planned |
| 6.3 | JSON export / import | 📋 Planned |
| 6.4 | Clipboard copy (TSV) | 📋 Planned |
| 6.5 | Diff view (git) | 📋 Planned |

## Stage 7 — Polish & Docs

| # | Feature | Status |
|---|---|---|
| 7.1 | Keyboard-first workflow | 📋 Planned |
| 7.2 | Theming (dark/light) | 📋 Planned |
| 7.3 | Tooltips and contextual help | 📋 Planned |
| 7.4 | Empty-state guidance | 📋 Planned |
| 7.5 | Performance audit (1000-row target) | 📋 Planned |
| 7.6 | Public docs (README, usage guide, FAQ) | 📋 Planned |
| 7.7 | Godot Asset Library submission | 📋 Planned |
