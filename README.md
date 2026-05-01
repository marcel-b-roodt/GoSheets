# GoSheets

**Free, open-source spreadsheet-style resource editor for Godot 4.**

> View, create, edit, and manage all your resources in one place without leaving the Godot editor.

[![CI](https://github.com/marcel-b-roodt/GoSheets/actions/workflows/ci.yml/badge.svg)](https://github.com/marcel-b-roodt/GoSheets/actions/workflows/ci.yml)

---

## What is GoSheets?

GoSheets is a Godot 4 EditorPlugin that gives you a spreadsheet view of every `Resource` in your project. Pick a resource type from the dropdown, and all instances appear in a scrollable, sortable, filterable table, one row per resource, one column per exported property. Edit cells inline, sort by any column, search across all fields, and create or duplicate resources from the toolbar.

Designed for anyone who uses Godot Resources for game data: item databases, stat tables, ability configs, localization sheets, and more. No external tools required.

## Status

🔧 **Active development — Stage 2 (Inline Editing).**

Foundation, scanner, type registry, read-only grid, sorting, filtering, column management, and inline cell editing for scalars, enums, resources, arrays, and dictionaries are working. Undo/redo is wired. See the [feature registry](docs/feature-registry.md) for what's done and what's next.

## Installation

**From the Godot Asset Library** *(once listed)*:
1. Open **Project → AssetLib** inside Godot.
2. Search for **GoSheets** and install.
3. Enable the plugin under **Project → Project Settings → Plugins**.

**From a release zip**:
1. Download the latest zip from [Releases](https://github.com/marcel-b-roodt/GoSheets/releases).
2. Drop the `addons/go_sheets/` folder into your project's `addons/` directory.
3. Enable the plugin under **Project → Project Settings → Plugins**.

**From source**:
```bash
git clone https://github.com/marcel-b-roodt/GoSheets.git
```
Open `project.godot` in Godot 4. The plugin activates automatically.

## Quick Start

1. Enable GoSheets in **Project → Project Settings → Plugins**.
2. Click **Resources** in Godot's top centre bar (next to 2D / 3D / Script).
3. Select a resource type from the dropdown. All `.tres`/`.res` files of that type appear in the grid.
4. Click a cell and press **Enter** or **F2** to edit inline. **Tab** / **Shift+Tab** to move between cells.
5. Sort by clicking a column header. Filter with the search bar.

## Design Principles

| Pillar | Description |
|---|---|
| **Editor-first** | Every workflow feels native to Godot. No detached windows or external processes for core operations. |
| **Maximum ease of use** | Open the dock, pick a type, start editing within seconds. Sensible defaults everywhere. |
| **Powerful in a tight package** | Filtering, sorting, inline editing, bulk operations, CSV import/export, and cross-reference lookup in one panel. |
| **Non-destructive** | No GoSheets operation corrupts or silently overwrites resources. Undo/redo works for every mutation. |
| **Stable** | Test coverage on all algorithmic code. A broken plugin that corrupts resources is worse than a missing feature. |
| **Accessible** | Keyboard-first navigation, contextual tooltips, and helpful empty-state guidance. |

## Roadmap

| Stage | Focus | Status |
|---|---|---|
| 0 — Foundation | Plugin skeleton, scanner, type registry, settings, CI | ✅ Complete |
| 1 — Spreadsheet Core | Read-only grid, columns, sorting, filtering | ✅ Complete |
| 2 — Inline Editing | Cell editors, undo/redo, keyboard navigation | 🔧 In Progress |
| 3 — Resource Lifecycle | Create, duplicate, delete, rename, bulk create | 📋 Planned |
| 4 — Column Customization | Picker panel, pinning, computed columns, nested expansion | 📋 Planned |
| 5 — Search & Relationships | Advanced filters, cross-reference, "where used" | 📋 Planned |
| 6 — Import / Export | CSV/JSON import/export, clipboard copy, diff view | 📋 Planned |
| 7 — Polish & Docs | Keyboard-first, theming, performance audit, Asset Library | 📋 Planned |

Full feature-by-feature status lives in **[docs/feature-registry.md](docs/feature-registry.md)**. Stage details are in **[docs/roadmap.md](docs/roadmap.md)**.

## AI Tooling Transparency Disclosure

Most code in this repository was generated with AI assistance and reviewed by the maintainer. Specifically:

- **Tooling:** [OpenCode](https://opencode.ai) (models previously run through VS Code Copilot integration), running GLM-5.1 or latest (an open-weight model from [Zhipu AI / THUDM](https://github.com/THUDM/GLM-4), [glm-4 license](https://huggingface.co/THUDM/glm-4-9b/blob/main/LICENSE)) via [Ollama](https://ollama.com). Other models, provided they are open-source and appropriately licensed, may also be used.
- **Human role:** Project architecture, feature design, code structure, acceptance testing, and all release decisions are made by the maintainer. Every AI-generated change is read, evaluated, and tested before merging. No code ships without human approval.
- **CI:** All code passes `gdparse` (syntax), `gdlint` (style), and a GdUnit4 test suite on every push via GitHub Actions.
- **Not used:** Autonomous agents, unsupervised commits, or unsupervised merges. No outside contributors.

If you have questions about how any piece of code was written or verified, please feel free to open an issue.

## Contributing

Bug reports and feature requests are welcome. Please open an issue first for significant changes.

## Support the project

GoSheets is free and open-source. If it saves you time, consider supporting development on [Patreon](https://patreon.com/gosheets_godot) or [Ko-fi](https://ko-fi.com/marcelroodt).

## License

GPL v3 — see [LICENSE.md](LICENSE.md).