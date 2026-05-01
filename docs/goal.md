# GoSheets — Project Goal

## North Star

> **Using resources in Godot for game logic should be simple and straightforward. A developer should be able to find, view, edit, create, and wire up every resource in their project without ever leaving the editor.**

GoSheets is a Godot 4 EditorPlugin that delivers a spreadsheet-style resource editor directly inside Godot. It targets developers who use Resources for game data: item databases, stat tables, ability configs, localization sheets, and more. See it all, edit it all, search it all, from one panel.

---

## What GoSheets Is

- A **spreadsheet view for Godot Resources** — one row per `.tres` file, one column per `@export` property.
- An **inline editor** — click a cell, change the value, press Enter. No Inspector round-trip for bulk tweaks.
- A **resource discovery tool** — find every instance of a type, sort, filter, cross-reference.
- An **import/export bridge** — bring CSV/JSON data in, push it out, paste rows to a spreadsheet app.
- **Open-source and community-driven** — free to use, transparently developed, Patreon-funded.

## What GoSheets Is Not

- A replacement for the Godot Inspector. The Inspector handles single-object deep editing; GoSheets handles many-object overview editing. They complement each other.
- A database engine. GoSheets reads and writes `.tres`/`.res` files on disk. It does not add a query language, indexing service, or runtime data layer.
- A runtime library. GoSheets targets the Godot **editor** only; it does not ship code into your game build.
- A generic spreadsheet. GoSheets is resource-type-aware. Columns come from your script's `@export` declarations, not from free-form cells.

---

## Success Criteria (v1.0)

| Capability | Target |
|---|---|
| Type-aware spreadsheet | Auto-derived columns from `@export` properties for any Resource subclass |
| Inline editing | All scalar, enum, reference, and collection types editable in-place |
| Resource lifecycle | Create, duplicate, rename, delete from the toolbar |
| Column management | Pin, collapse, reorder, resize, visibility toggle, per-type layout profiles |
| Sort and filter | Sort by any column; text search + multi-condition advanced filter |
| Cross-reference | "Where used" lookup; broken reference detection |
| Import / export | CSV, JSON, clipboard TSV; two-way sync |
| Undo/redo | Every mutation reversible through `EditorUndoRedoManager` |
| Performance | 1000 rows at 60 fps with virtual row recycling |
| Accessibility | Keyboard-first navigation; tooltips; empty-state guidance |
| Distribution | Listed on the Godot Asset Library |

---

## Guiding Principles

1. **Editor-first.** Every workflow must feel native to Godot. No detached windows, no external processes for core operations.
2. **Maximum ease of use.** Open the dock, pick a type, start editing within seconds. Sensible defaults everywhere.
3. **Powerful in a tight package.** Filtering, sorting, inline editing, bulk operations, CSV import/export, and cross-reference lookup in one panel.
4. **Non-destructive.** No GoSheets operation corrupts or silently overwrites resources. Undo/redo works for every mutation.
5. **Stable.** Test coverage on all algorithmic code. A broken plugin that corrupts resources is worse than a missing feature.
6. **Accessible.** Keyboard-first navigation, contextual tooltips, and helpful empty-state guidance.