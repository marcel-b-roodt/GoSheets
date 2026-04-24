# GoSheets — Feature Registry

The single source of truth for every feature's status. Updated after each task set.

**Status legend:** ✅ Complete · 🔧 In Progress · 📋 Planned · ❌ Removed / Deferred

---

## Stage 0 — Foundation

| # | Feature | Status |
|---|---|---|
| 0.1 | Plugin entry point — `plugin.gd`, dock registration, enable/disable | 📋 Planned |
| 0.2 | Resource scanner — discover `.tres`/`.res` files under a configurable root | 📋 Planned |
| 0.3 | Script-class registry — enumerate `Resource` subclasses in the project | 📋 Planned |
| 0.4 | Settings persistence — `user://` resource for plugin config | 📋 Planned |
| 0.5 | Verify + CI scaffolding — `verify.sh`, GdUnit4, GitHub Actions | 📋 Planned |

## Stage 1 — Spreadsheet Core (Read-only)

| # | Feature | Status |
|---|---|---|
| 1.1 | Type selector dropdown | 📋 Planned |
| 1.2 | Auto-derived column definitions from `@export` properties | 📋 Planned |
| 1.3 | Grid renderer with virtual/pooled rows | 📋 Planned |
| 1.4 | Read-only cell display (all scalar + reference types) | 📋 Planned |
| 1.5 | Row selection + Inspector sync | 📋 Planned |
| 1.6 | Column visibility toggle | 📋 Planned |
| 1.7 | Column reordering | 📋 Planned |
| 1.8 | Sort by column | 📋 Planned |
| 1.9 | Text search / filter bar | 📋 Planned |

## Stage 2 — Inline Editing

| # | Feature | Status |
|---|---|---|
| 2.1 | Inline cell editing | 📋 Planned |
| 2.2 | Undo/redo integration | 📋 Planned |
| 2.3 | Multi-cell batch edit | 📋 Planned |
| 2.4 | Enum support | 📋 Planned |
| 2.5 | Resource reference picker | 📋 Planned |
| 2.6 | Array property cells | 📋 Planned |
| 2.7 | Dirty-state indicator + auto-save option | 📋 Planned |
| 2.8 | Keyboard navigation | ✅ Core wired: Enter/F2 open cell; Tab/Shift+Tab navigate; Escape cancels. Tab focus-leak to Godot editor unresolved (needs focus capture via `_input` override in grid). |

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
| 4.3 | Column width resize | 📋 Planned |
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
