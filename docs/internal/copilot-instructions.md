# GoSheets — Copilot Instructions

## Project Overview

**GoSheets** is a free, open-source **Godot 4 EditorPlugin** — a spreadsheet-style resource editor for Godot, inspired by Unity's ScriptableSheets.

**Repo:** https://github.com/marcel-b-roodt/GoSheets

The design pillars are:
- **Editor-first** — every workflow feels native to Godot; no detached windows or external processes for core operations.
- **Maximum ease of use** — a developer should be able to open the dock, pick a resource type, and be editing data within seconds. Defaults must be sensible.
- **Powerful in a tight package** — filtering, sorting, inline editing, bulk operations, CSV import/export, and cross-reference lookup, all in one panel.
- **Non-destructive** — no GoSheets operation should corrupt or silently overwrite resources. Undo/redo must work for every mutation.
- **Stable** — test coverage on all algorithmic code. A broken plugin that corrupts resources is worse than a missing feature.
- **Accessible** — keyboard-first navigation, contextual tooltips, and helpful empty-state guidance for new users.

---

## Architecture Summary

| Layer | Description |
|---|---|
| `addons/go_sheets/plugin.gd` | `EditorPlugin` entry point. Declares GoSheets as a **main screen plugin** (overrides `_has_main_screen()` → `true`, `_get_plugin_name()` → `"Resources"`, `_get_plugin_icon()`). Instantiates and owns the main panel. |
| `addons/go_sheets/core/` | Main screen root (`GoSheetsPanel`), type selector, settings persistence, undo/redo helpers. |
| `addons/go_sheets/scanner/` | Resource file scanner (`ResourceScanner`), script-class registry (`TypeRegistry`). |
| `addons/go_sheets/grid/` | Grid renderer, column model, cell widgets, row selection manager. |
| `addons/go_sheets/cells/` | Per-property-type cell renderers and editors (`IntCell`, `StringCell`, `ColorCell`, `ResourceRefCell`, etc.). |
| `addons/go_sheets/filters/` | Filter/sort engine; expression evaluator for computed columns. |
| `addons/go_sheets/io/` | CSV/JSON import and export writers. |
| `tests/` | GdUnit4 test suites — mirrors the addon structure. |

### Main screen plugin — how it works in Godot 4

GoSheets occupies the **main viewport area** alongside 2D, 3D, Script, and AssetLib — not a side dock. The user switches to it by clicking the **"Resources"** button in the top centre bar of the editor.

Key overrides in `plugin.gd`:

```gdscript
func _has_main_screen() -> bool:
    return true

func _get_plugin_name() -> String:
    return "Resources"

func _get_plugin_icon() -> Texture2D:
    return preload("res://addons/go_sheets/icon.svg")

func _make_visible(visible: bool) -> void:
    _panel.visible = visible

func _enter_tree() -> void:
    _panel = preload("res://addons/go_sheets/core/go_sheets_panel.tscn").instantiate()
    EditorInterface.get_editor_main_screen().add_child(_panel)
    _make_visible(false)

func _exit_tree() -> void:
    if _panel:
        _panel.queue_free()
```

`GoSheetsPanel` (`core/go_sheets_panel.gd` + `.tscn`) is a full-viewport `Control` that owns the toolbar, type selector, filter bar, and the grid.

### Pure helpers and reusable operations
- Keep pure logic out of editor-only classes such as `EditorPlugin` and dock panel scripts.
- Put scan logic, filter/sort algorithms, import/export serialisers, and other headless-safe logic into reusable `RefCounted` helper libraries under the relevant domain folder.
- Editor-facing classes may keep thin wrappers, but the real implementation should live in the reusable helper module.
- Tests should target the reusable helper directly when possible instead of reaching through editor-only classes.
- When refactoring logic out of editor code, remove duplicated legacy implementations rather than leaving two sources of truth.

### Language policy
**All plugin code is GDScript.** This ensures the plugin works in every Godot 4 project regardless of whether the user has .NET installed.

- **GDScript** — everything: scanner, grid, cell widgets, filters, import/export, UI.
- **GDExtension** — not planned. The operations in GoSheets are I/O-bound and UI-bound, not CPU-bound. GDExtension complexity is not justified.

### `ResourceScanner` — resource discovery
Walks a configurable root path recursively via `DirAccess` and returns a list of `.tres`/`.res` file paths. Results are cached and rebuilt on demand (or when the filesystem changes).

### `TypeRegistry` — script-class enumeration
Enumerates all `class_name` declarations that extend `Resource` using `ProjectSettings` and `ResourceLoader`. Provides the type-selector dropdown with live classes only.

### `ColumnModel` — column definition
One `ColumnDef` per visible property. Derived automatically from the `@export` annotations of the selected type via `ClassDB`. Stores:
- `property_name: StringName`
- `property_type: Variant.Type`
- `display_name: String`
- `visible: bool`
- `width: int`
- `pinned: bool`
- `sort_direction: int` (0 = none, 1 = asc, −1 = desc)

Column layouts are saved per type in the plugin settings resource.

---

## Documentation

Public design docs live in `/docs/` and are **git-tracked** — they ship with the repo for contributors and curious users.
Private / internal docs live in `/docs/internal/` which is **gitignored** (local-only working files).

```
docs/                             ← git-tracked (public)
  README.md                      ← navigation index
  goal.md                        ← north star — what GoSheets is and isn't
  roadmap.md                     ← ordered stage-by-stage feature roadmap
  feature-registry.md            ← source of truth for every feature's status
  architecture.md                ← codebase architecture for contributors
  internal/                      ← gitignored (local only)
    release-management.md        ← versioning, branch strategy, release workflow (private)
    monetization/
      patreon-strategy.md        ← Patreon/funding strategy (private)
      patreon-bio.md
      kofi.md
    marketing/
      marketing.md               ← brand voice & messaging (private)
    social/
      README.md                  ← social media overview & workflow
      content/
        queue.md                 ← master list of all post batches + status
        _template.md             ← blank template for a new content batch
        YYYY-MM-DD-feature-name.md ← one file per feature/milestone
      scripts/                   ← posting automation
        post_tweet.py
        requirements.txt
        .env.en / .env.jp        ← credentials (gitignored)
      platforms/
        twitter-setup.md
        discord-setup.md
```

### Docs workflow — follow this on every feature change:
1. **Before implementing:** check whether a doc exists for the feature area. Read it — the doc describes *intended* behaviour. Implement to match the doc's intent where possible.
2. **If no doc exists:** write one as part of the work. Document the intent, the data model, and the current behaviour. Be honest about stubs.
3. **After implementing:** update the relevant doc to reflect what was actually built. **Update [`docs/feature-registry.md`](../docs/feature-registry.md) too.**
4. **If the feature is demo-able:** create a social content batch in `docs/internal/social/content/` following the Social Content Workflow below.

Docs should be **concise and accurate**, not exhaustive. A table or diagram is worth more than paragraphs.

---

## Feature Registry Workflow

The registry lives at [`docs/feature-registry.md`](../docs/feature-registry.md). It is the **single source of truth** for what GoSheets has and what it plans to have.

Status legend: ✅ Complete · 🔧 In Progress · 📋 Planned · ❌ Removed / Deferred

### Rules:
1. **Consult the registry before each task set.** Understand the project's current shape before adding or changing anything.
2. **Update the registry after each task set.** New features or significant changes must be reflected immediately.
3. **Completed TODOs → move to the registry** with status ✅. Do not leave completed entries in `TODO.md` indefinitely.
4. **Bugfix TODOs → delete when done.** Bug entries in `TODO.md` do not belong in the registry.
5. **The registry drives scoping decisions** — if something is not in the registry, it does not exist.

---

## NearTermTodos Workflow

`NearTermTodos.txt` is a prioritised queue of improvements for **recent additions** — things to resolve before moving on.

### Rules:
1. **Read `NearTermTodos.txt` in full when requested.** Treat each item as an actionable task.
2. **Iterate in order.** An item is done when code and any breadcrumb are complete and verified.
3. **Remove completed items.** Do not leave completed items in the file.
4. **Leave out-of-scope items** with a brief note — do not silently skip.
5. **The file is a short-term queue, not an archive.** Keep it small. Leave it empty when exhausted.

---

## HighLevelTodos Workflow

`HighLevelTodos.txt` is a scratchpad for raw design intent and vague feature desires.

### Rules:
1. **Check at the start of every task set.** Identify items that can be turned into `TODO.md` entries or registry rows.
2. **Source each item cleanly** — translate vague notes into specific, scoped TODO entries. Add to `TODO.md` and/or registry as `📋 Planned`.
3. **Remove sourced items** from the file. Leave it empty when all items are sourced.
4. **Leave unsourceable items** (e.g. "make it feel cool") until they can be clarified.

---

## Copilot Session Workflow

Rules that govern how Copilot operates during a working session.

### 1 — Calibrate step granularity to task size
Always state a step plan at the start of a reply. Then apply this rule:

| Situation | Action |
|---|---|
| All steps are small and low-risk (≤ 3 files, straightforward changes) | Complete all steps in one reply |
| A step requires explicit approval (new script, architecture decision) | Stop and yield after stating the proposal |
| A step touches 4+ files with significant new content | Do one step, yield, continue next reply |
| Any step is uncertain or experimental | Do that step alone, yield for review |
| Cumulative response is getting long (many files already changed) | Finish the current step cleanly, yield |

The goal is efficient forward progress — don't artificially split tiny tasks, but don't overrun response limits on large ones.

### 2 — Use `./verify.sh` for all GDScript validation
Never call `gdparse` or `gdlint` directly. Always run:
```bash
./verify.sh
```
This is the single gate for syntax and lint. Running sub-tools individually is redundant and noisy.

### 3 — Spot repeatable steps → propose a script
If the same sequence of shell commands recurs across two or more sessions, **pause and propose** a new helper script in `scripts/` before continuing. State what the script would do and ask for approval. Do not silently add scripts.

### 4 — New scripts ship with bats tests
Every script added under `scripts/` must have a companion bats test file. Tests live in `scripts/<tool-name>/tests/`. Run bats and confirm all tests pass before considering the script done. See **Scripts & Shell Testing** below for the layout.

### 5 — Split work into release-trackable task slices
Every non-trivial request must be split into small, independently verifiable slices so release notes can map changes to real user-facing outcomes.

Use this pattern:
- **One task slice = one clear behavior change** (or one coherent refactor)
- **Each slice lands with tests** (or a stated reason why tests are not applicable)
- **Avoid mixed commits** that combine unrelated fixes/features/docs

Before coding, write a short slice plan in this form:
1. Scope (what behavior changes)
2. Files touched
3. Validation (tests/manual checks)
4. Commit message (planned)

If a request is broad, propose a sequence of small slices and execute in order.

### 6 — Commit messages must be changelog-friendly
Commit messages are the raw material for `scripts/release/prepare_release_notes.sh`.
Use conventional, descriptive subjects that can be grouped cleanly into Added / Changed / Fixed / Tests.

Required format:
- `feat(scope): <user-facing change>`
- `fix(scope): <bug fix>`
- `refactor(scope): <internal cleanup with behavior impact noted if any>`
- `test(scope): <coverage addition>`
- `docs(scope): <documentation update>`
- `chore(scope): <non-user-facing maintenance>`

Examples:
- `feat(grid): add keyboard wrapping between rows for Tab navigation`
- `fix(cells): compute popup height from child minimum size`
- `test(grid): cover tab/shift-tab wrapping and collapsed-column skipping`

Avoid vague messages like `update`, `cleanup`, `wip`, or multi-topic subjects.

---

## Pre-Commit Verification

**Run `./verify.sh` before every commit.** The hook fires automatically if you set up `.githooks` once:

```bash
git config core.hooksPath .githooks   # one-time, after cloning
```

### What verify.sh checks

| Step | Tool | What it catches |
|---|---|---|
| Syntax check | `gdparse` (gdtoolkit) | Parse errors, malformed GDScript |
| Lint check | `gdlint` (gdtoolkit) | Style violations, shadowed vars, unused args |

### What it does NOT catch (handle these manually)

| Risk | How to catch it |
|---|---|
| Undefined `class_name` references | Open project in Godot editor; check Output panel for errors on script load |
| Missing `@tool` on editor scripts | Test plugin enable/disable in Godot editor |
| Wrong method signatures (undo/redo) | Run GdUnit4 test suite locally |
| Grid rendering regressions | Open a test project in Godot, create a resource type, and verify the grid displays correctly |

### Before committing any new file — checklist

- [ ] `./verify.sh` exits 0  ← **use this, not direct `gdparse`/`gdlint` calls**
- [ ] File opened in Godot editor with no red errors in the Output panel
- [ ] If a new class: verify it appears in the Godot class autocomplete
- [ ] If editor-only code: tested with plugin enabled **and** disabled
- [ ] Tests updated or added for every non-trivial function

### Install gdtoolkit (once per machine)

```bash
# Arch Linux
pip install --break-system-packages gdtoolkit

# Ubuntu / Debian / macOS
pip install gdtoolkit
```

---

## Scripts & Shell Testing

Helper scripts live in `scripts/`. Each script gets its own sub-folder and a companion bats test suite.

```
scripts/
  verify/               ← wraps ./verify.sh logic for unit-testable pieces
    tests/
      verify_test.bats
  <tool-name>/
    <tool-name>.sh
    tests/
      <tool-name>_test.bats
```

### Rules
1. **Every script in `scripts/` must have a bats test file** in its `tests/` sub-folder.
2. **Tests must pass before the script is considered done.** Run with:
   ```bash
   bats scripts/<tool-name>/tests/<tool-name>_test.bats
   ```
3. **Install bats once per machine:**
   ```bash
   # Arch Linux
   sudo pacman -S bash-bats

   # Ubuntu / Debian
   sudo apt install bats

   # macOS
   brew install bats-core
   ```
4. **Propose before adding.** If a repeatable command sequence is spotted, suggest the script + test plan and wait for approval (see Session Workflow rule 3).

---

## Social Content Workflow

Every significant feature completion or milestone triggers a content batch — a set of posts across Twitter/X, Patreon, Ko-fi, Reddit, and Discord.

Content files live in `docs/internal/social/content/` (gitignored — local only).

```
docs/internal/social/content/
  queue.md                     ← master list: every batch and its publish status
  _template.md                 ← blank template — copy this for each new batch
  YYYY-MM-DD-feature-name.md   ← one file per feature or milestone
```

### When to create a content batch

Create a new file from `_template.md` when **any** of the following happen:

- A complete, demo-able feature lands on `develop` (e.g. "Cube generator works")
- A roadmap stage is completed (e.g. "Stage 1 — all primitives done")
- A versioned release ships (e.g. `v0.2.0`)
- A behind-the-scenes moment worth sharing (design decision, problem solved, lessons learned)

### Process (run this after every qualifying feature merge)

1. Copy `_template.md` → `docs/internal/social/content/YYYY-MM-DD-feature-name.md`
2. Fill in **Meta** (date, feature name, visual asset note).
3. Write each platform's draft in order: Twitter → Patreon patron-only → Patreon public → Ko-fi → Reddit → Discord.
4. Add a row to `queue.md` with status **📝 Draft**.
5. When drafts are reviewed and ready, update status to **✅ Ready to post**.
6. After publishing each platform, tick the checklist and update the queue row to **📤 Posted**.

### Platform guidelines (quick reference)

| Platform | Threshold | Tone | Key rule |
|---|---|---|---|
| **Twitter/X** | Any demo-able feature | Punchy, visual-first | ≤280 chars; always pair with GIF/screenshot |
| **Patreon (patron-only)** | Every feature | Behind-the-scenes, honest | Post 1–2 days before public release |
| **Patreon (public devlog)** | Every release or stage | Inclusive, celebratory | Post on or after GitHub release |
| **Ko-fi** | Every release or stage | Short, grateful, low-friction | Crosspost public devlog summary with GitHub link + one-time support link |
| **Reddit** (`r/godot`, `r/gamedev`) | Stage completions / major ops | Community member, not promoter | Title must be specific; no hard sell |
| **Discord** (Godot `#showcase`/`#resources`) | Same as Reddit | Short, friendly | Drop a GIF; no `#general` posts |

### Hashtags (Twitter)
`#GodotEngine #godot4 #gamedev #indiedev`
Add `#leveldesign` for level-design-relevant features; `#opensource` for release announcements.

### Social writing style — always apply to every post

GoSheets's voice is a solo dev talking to other devs. It should sound personal and direct, not polished or corporate. The biggest risk is AI-generated copy that reads as obviously machine-written — this erodes trust.

**Avoid at all times:**
- Em-dashes (`—`). Use a comma, a full stop, or parentheses instead.
- Phrases that signal AI output: "delve into", "it's worth noting", "in conclusion", "seamlessly", "powerful", "robust", "I'm excited to", "game-changing", "at its core", "leverage".
- Opening hooks that summarise the whole post in the first sentence. Start mid-thought, with the concrete fact.
- Tricolon lists padded for rhythm ("X, Y, and Z are all in now"). State what's in, tersely.
- Passive voice as a stylistic default. Say who does what.
- Ending with a generic CTA ("check it out!", "let me know what you think!"). Let the work speak; link without fanfare.

**Aim for:**
- Short sentences. Cut anything that does not add information.
- Specific details over adjectives. "Snaps to the nearest vertex in screen space" beats "precise vertex snapping".
- Lowercase where it reads naturally in context (tweets especially).
- A comma or a new line where an em-dash is tempting.
- Honest about what is not done yet. "UV is next" not "UV mapping is on the horizon".

---

## Release Runbook Workflow

The full release process lives in `docs/internal/release-management.md` (gitignored — local only).

### When to generate a release runbook

Generate or prompt the developer to review the release runbook when **any** of the following are true:

| Trigger | Action |
|---|---|
| A roadmap stage is marked fully ✅ in `feature-registry.md` | Prompt: *"Stage N is complete — ready to cut a release? See `docs/internal/release-management.md`."* |
| `CHANGELOG.md [Unreleased]` section has grown to 5+ entries | Prompt: *"[Unreleased] has N entries — consider cutting a release."* |
| Developer explicitly asks to "prepare a release" or "cut a release" | Generate the checklist below immediately |
| The developer asks for a "release runbook" by name | Generate the checklist below immediately |

### Release readiness checklist (generate this on request)

When asked, output the following as a markdown task list, pre-filled with the current version from `plugin.cfg`:

```markdown
## Release Checklist — vX.Y.Z

### Pre-release
- [ ] All planned features for this version are ✅ in `feature-registry.md`
- [ ] `./verify.sh` exits 0 on the `develop` branch
- [ ] GdUnit4 test suite passes (run all tests in Godot editor)
- [ ] Plugin enables/disables cleanly in a fresh Godot project
- [ ] `CHANGELOG.md` [Unreleased] section is accurate and complete

### Cut the release branch
- [ ] `git checkout develop && git pull`
- [ ] `git checkout -b release/vX.Y.Z`
- [ ] Bump `version=` in `addons/go_sheets/plugin.cfg` to X.Y.Z
- [ ] Rename `[Unreleased]` → `[X.Y.Z] — YYYY-MM-DD` in `CHANGELOG.md`
- [ ] Open a new empty `[Unreleased]` section above it
- [ ] Commit: `chore: bump version to vX.Y.Z`

### Merge & tag
- [ ] `git checkout main && git merge --no-ff release/vX.Y.Z`
- [ ] `git tag -a vX.Y.Z -m "Release vX.Y.Z — <short description>"`
- [ ] `git push origin main --tags`
- [ ] `git checkout develop && git merge --no-ff release/vX.Y.Z && git push origin develop`
- [ ] `git branch -d release/vX.Y.Z && git push origin --delete release/vX.Y.Z`

### Publish
- [ ] CI `release.yml` workflow completes — draft GitHub Release created
- [ ] Review draft: add screenshots/GIFs, verify zip contents, publish
- [ ] Submit updated version to Godot Asset Library (minor releases only)

### Announce
- [ ] Create social content batch: `docs/internal/social/content/YYYY-MM-DD-vX.Y.Z-release.md`
- [ ] Patreon patron-only post (1–2 days before public)
- [ ] Patreon public devlog
- [ ] Ko-fi public crosspost
- [ ] Reddit `r/godot` + `r/gamedev`
- [ ] Godot Discord `#resources`
- [ ] Twitter/X with GIF and `#opensource`
```

### Rules
1. **Read `docs/internal/release-management.md`** before executing any release step — it is the authoritative reference.
2. **Never commit directly to `main`** — always via a `release/*` branch PR.
3. **The release zip must not contain** `docs/`, `tests/`, `.github/`, or `project.godot`.

---

## Code Quality Guidelines

### Priority order for every change: **Correctness → Simplicity → Performance**
GoSheets operations are primarily I/O-bound (disk reads, Godot API calls) and UI-bound. Readable, correct code comes first.

### When working on any feature:
1. **Write the test first (or alongside).** All scanner, filter, import/export, and column-model functions must have GdUnit4 tests. No exceptions.
2. **Guard editor-only code with `Engine.is_editor_hint()`.** The plugin must not add runtime overhead to published games.
3. **Virtual / pooled rows in the grid.** The grid must handle 500+ rows without frame-rate degradation. Never create one Control node per row — recycle row nodes.
4. **No tool-node leaks.** Any dock or overlay code that creates editor UI must clean up in `_exit_tree()`.
5. **Resource mutations go through `EditorUndoRedoManager`.** Every property change, resource creation, and deletion must be undoable.
6. **The plugin must not save or modify resources without explicit user action** (or auto-save being clearly opt-in).

### Editor plugin rules
All `EditorPlugin` scripts (`plugin.gd` and anything `preload`ed by it in `_enter_tree()`) must be **GDScript**.

### GDScript self-preload rule — ALWAYS apply to new scripts

Godot's startup scan processes scripts **alphabetically, folder by folder**. A script is compiled the first time it is encountered. If a referenced class name is not yet registered at that moment, the script is **cached with a compile error** — and Godot will return that errored cached version on all subsequent `preload` calls, even after the dependency is available.

**The rule:** Every script that references another GoSheets class name at compile time **must** explicitly `preload` that script (or one that transitively preloads it) at the top of the file, **before** any type annotation that uses the class name.

#### What counts as a compile-time reference (requires self-preload)

| Construct | Example | Requires preload? |
|---|---|---|
| Class-level `var` type annotation | `var x: ColumnModel` | ✅ Yes |
| `@export` type annotation | `@export var m: ColumnModel` | ✅ Yes |
| Function parameter type | `func f(m: ColumnModel)` | ✅ Yes |
| Function return type | `func f() -> ColumnModel` | ✅ Yes |
| Typed `for`-loop variable | `for col: ColumnDef in columns:` | ✅ Yes |
| Typed local variable | `var col: ColumnDef = ...` | ✅ Yes |
| `as` cast in function body | `node as GoSheetsPanel` | ❌ Runtime only |
| `is` check in function body | `if x is ColumnModel:` | ❌ Runtime only |

#### Preload ordering rule

List preloads in **dependency order** — each script after the scripts it depends on:

```gdscript
# Example for a script in grid/ that uses scanner/ and core/ types:
const _COLUMN_DEF_SCRIPT   := preload("res://addons/go_sheets/grid/column_def.gd")
const _COLUMN_MODEL_SCRIPT := preload("res://addons/go_sheets/grid/column_model.gd")
const _SETTINGS_SCRIPT     := preload("res://addons/go_sheets/core/go_sheets_settings.gd")
```

Scripts with no GoSheets dependencies need no preloads themselves.

#### Checklist — every new GDScript file

- [ ] List all GoSheets classes used as **compile-time** type annotations
- [ ] Add a `const _XYZ_SCRIPT := preload(...)` for each one (in dependency order)
- [ ] Add a comment block labelled `# Self-preloads` explaining why each is needed
- [ ] Run `./verify.sh` — a passing verify does **not** guarantee runtime load success; also disable → re-enable the plugin in Godot to flush the script cache

### Naming conventions
- **Variables and functions:** `snake_case`
- **Classes / inner classes:** `PascalCase`
- **Constants:** `SCREAMING_SNAKE_CASE`
- **Private members (by convention):** prefix with `_` (e.g. `_cached_rows`)
- **Files:** `snake_case.gd`
- **Test files:** mirror source name with `_test` suffix (e.g. `resource_scanner_test.gd`)

---

## Testing Strategy

### Philosophy
Scanner, filter, and import/export code is the most logic-dense part of GoSheets. Structure it so logic can be tested independently of the Godot scene tree wherever possible — pure functions that take data and return data are easiest to test.

**Test coverage is mandatory for all functions beyond trivial pass-through.** Every new operation (scan, filter, sort, CSV import/export, column derivation, etc.) must ship with tests for its core path and at least one edge case.

### Test setup
- **Framework:** [GdUnit4](https://github.com/MikeSchulze/gdUnit4) — install from AssetLib (`addons/gdUnit4/`).
- All scanner, filter, column-model, and I/O code is tested here.
- Run locally: open the GdUnit4 panel in the Godot editor → **Run all tests**.
- Run in CI: `MikeSchulze/gdUnit4-action` runs tests headlessly on every push/PR.

### What to test

| Area | Notes |
|---|---|
| `ResourceScanner` — returns correct paths, handles empty dir, handles nested dirs | Pure logic; no scene needed |
| `TypeRegistry` — enumerates only `Resource` subclasses | Pure logic |
| `ColumnModel` — derives correct `ColumnDef` list from a mock script | Pure logic |
| Filter engine — AND/OR conditions, all comparison operators | Pure logic |
| Sort engine — ascending/descending, handles all cell types including null | Pure logic |
| CSV export — output parses correctly with correct headers | Pure logic |
| CSV import — creates correct resource data; conflict resolution | Pure logic |
| Undo/redo — property change is reversible | GdUnit4 scene test |

### Test file location
Mirror the source path under `tests/`:
- `tests/scanner/resource_scanner_test.gd`
- `tests/scanner/type_registry_test.gd`
- `tests/grid/column_model_test.gd`
- `tests/filters/filter_engine_test.gd`
- `tests/io/csv_export_test.gd`
- `tests/io/csv_import_test.gd`

---

## CI & Release

### GitHub Actions
- **`ci.yml`** — runs on every push and PR to `main` and `develop`: downloads Godot headless + GdUnit4, runs `tests/` suite via `MikeSchulze/gdUnit4-action`.
- **`release.yml`** — runs on tag push matching `v*`: builds plugin zip (`addons/go_sheets/` + `README.md` + `CHANGELOG.md` + `LICENSE`), extracts the changelog section, creates a draft GitHub Release.

### Versioning
Semantic versioning: `0.STAGE.PATCH` pre-v1.0, then `MAJOR.MINOR.PATCH`.

### Branch strategy
```
main      ← tagged releases only; always releasable
develop   ← integration; all feature branches merge here
feature/* ← one branch per roadmap item
fix/*     ← bug fixes; hotfixes branch from main
release/* ← short-lived version-bump + changelog prep
```

Full details in [`docs/internal/release-management.md`](../docs/internal/release-management.md).

---

## Common Patterns

### Scanning and loading resources
```gdscript
# 1. Scan for resource files
var paths := ResourceScanner.scan("res://data/")

# 2. Load each resource
for path in paths:
    var res := ResourceLoader.load(path)
    if res is MyDataResource:
        rows.append(res)
```

### Undo/Redo pattern for property edits
```gdscript
var ur := EditorInterface.get_editor_undo_redo()
ur.create_action("Edit %s.%s" % [resource.resource_path, property])
ur.add_do_property(resource, property, new_value)
ur.add_undo_property(resource, property, old_value)
ur.commit_action()
```

### Editor-only guard
```gdscript
func _ready() -> void:
    if not Engine.is_editor_hint():
        return
    # editor setup here
```

### Virtual row recycling (grid performance)
```gdscript
# Re-use existing row nodes; only create new ones when the pool is exhausted.
func _populate_rows(data: Array) -> void:
    for i in data.size():
        var row: Control
        if i < _row_pool.size():
            row = _row_pool[i]
        else:
            row = _ROW_SCENE.instantiate()
            _row_pool.append(row)
            add_child(row)
        row.bind(data[i])
    # Hide unused pooled rows
    for i in range(data.size(), _row_pool.size()):
        _row_pool[i].hide()
```
