@tool
## ResourceGrid
##
## Scrollable spreadsheet grid that shows one resource per row and one
## @export property per column.
##
## Uses a virtual row pool: a fixed set of GridRow nodes is recycled as the
## user scrolls, so 500+ rows never allocate 500 Control trees.
##
## Add as a child of GoSheetsPanel; call load_data() to populate.

class_name ResourceGrid
extends VBoxContainer

signal row_selected(resource: Resource)
## Emitted after the user drags a resize handle or toggles a column collapse.
## The panel should respond by persisting the updated ColumnModel.
signal column_layout_changed
## Emitted when the user commits an inline cell edit.
## The panel is responsible for undo/redo, ResourceSaver, and row refresh.
signal cell_value_changed(
		resource: Resource,
		property: StringName,
		old_value: Variant,
		new_value: Variant)

# Self-preload
const _COLUMN_MODEL_SCRIPT := preload("res://addons/go_sheets/grid/column_model.gd")
const _GRID_ROW_SCRIPT     := preload("res://addons/go_sheets/grid/grid_row.gd")
const _CELL_EDITOR_SCRIPT  := preload("res://addons/go_sheets/grid/cell_editor.gd")

# ── Layout constants ──────────────────────────────────────────────────────────
const ROW_HEIGHT      := 24
const HEADER_HEIGHT   := 28
const COLLAPSED_WIDTH := 16   # width of a collapsed column strip
const MIN_COL_WIDTH   := 40   # minimum drag-resize width
const RESIZE_ZONE_PX  := 6    # px from a column's right edge that triggers resize cursor
const REORDER_DRAG_THRESHOLD_PX := 6.0
const REORDER_TARGET_FILL_COLOR := Color(0.30, 0.56, 0.95, 0.22)
const REORDER_TARGET_DIVIDER_COLOR := Color(0.45, 0.72, 1.00, 0.95)
const REORDER_TARGET_DIVIDER_WIDTH := 2

## Set to true (via the panel’s Debug toggle) to print layout diagnostics.
var debug_mode: bool = false

# Edit navigation state
var _edit_row: int = -1
var _edit_col: int = -1

# ── State ─────────────────────────────────────────────────────────────────────
var _column_model: ColumnModel
var _resources: Array[Resource] = []
var _selected_index: int = -1

# Sort state
var _sort_column: int = -1     # index into visible columns
var _sort_dir: int = 0          # 1 = asc, -1 = desc

# Column resize drag state
var _drag_col_index: int = -1   # visible-column index being dragged
var _drag_start_x: float = 0.0  # global mouse x at drag start
var _drag_start_w: int = 0      # col.width at drag start

# Header reorder drag state
var _header_press_col: int = -1
var _header_press_x: float = 0.0
var _header_press_moved: bool = false
var _reorder_drop_slot: int = -1

# ── UI nodes ─────────────────────────────────────────────────────────────────
var _scroll: ScrollContainer
var _content: VBoxContainer    # auto-sizes from children; drives scroll range
var _header_bar: Control       # fixed header — single MOUSE_FILTER_STOP, all input centralised
var _context_menu: PopupMenu   # right-click column menu
var _context_menu_col: int = -1
var _cell_editor: CellEditor   # shared popup for inline editing

# ── Column widths (index into visible_columns) ────────────────────────────────
var _col_x_offsets: Array[int] = []
var _total_width: int = 0


func _ready() -> void:
	if _scroll == null:
		_build_ui()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Load [param resources] and display them using [param col_model].
func load_data(col_model: ColumnModel, resources: Array[Resource]) -> void:
	if _scroll == null:
		_build_ui()
	_column_model = col_model
	_resources    = resources
	_selected_index = -1
	_sort_column = -1
	_sort_dir    = 0
	# Defer if called before this node's _ready() has completed (e.g. during
	# parent._ready()), so all child _ready() callbacks settle before row creation.
	if is_node_ready():
		_rebuild()
	else:
		_rebuild.call_deferred()


## Return the currently selected Resource, or null.
func selected_resource() -> Resource:
	if _selected_index < 0 or _selected_index >= _resources.size():
		return null
	return _resources[_selected_index]


## Rebind only the row(s) displaying [param resource] without a full rebuild.
## Called after a cell edit or undo so the label refreshes immediately.
func refresh_resource(resource: Resource) -> void:
	if _column_model == null:
		return
	var vis := _column_model.visible_columns()
	for i in _resources.size():
		if _resources[i] == resource:
			var row: GridRow = _content.get_child(i) as GridRow
			if row != null and row.visible:
				row.bind(i, resource, vis, _col_x_offsets, i == _selected_index)
			return


## Rebind every visible row — used when undo/redo may have changed any resource.
func refresh_all_rows() -> void:
	if _column_model == null:
		return
	var vis := _column_model.visible_columns()
	for i in _resources.size():
		var row: GridRow = _content.get_child(i) as GridRow
		if row != null and row.visible:
			row.bind(i, _resources[i], vis, _col_x_offsets, i == _selected_index)


# ---------------------------------------------------------------------------
# Private — UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	add_theme_constant_override("separation", 0)

	# Fixed header row — VBox gives it exactly HEADER_HEIGHT via minimum_size.
	_header_bar = Control.new()
	_header_bar.custom_minimum_size = Vector2(0, HEADER_HEIGHT)
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.clip_contents = false
	# All header interaction is centralised here: resize drags work because
	# Godot routes all mouse events to the pressed control until release.
	_header_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_header_bar.gui_input.connect(_on_header_gui_input)
	add_child(_header_bar)

	# Scrollable body — SIZE_EXPAND_FILL takes the remaining vertical space.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = false
	add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 0)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_context_menu = PopupMenu.new()
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(_context_menu)

	_cell_editor = _CELL_EDITOR_SCRIPT.new()
	_cell_editor.debug_mode = debug_mode
	_cell_editor.value_committed.connect(_on_cell_value_committed)
	_cell_editor.tab_pressed.connect(_on_cell_tab_pressed)
	add_child(_cell_editor)


func _rebuild() -> void:
	if _column_model == null:
		return
	_compute_column_offsets()
	_rebuild_header()
	_populate_rows()


func _compute_column_offsets() -> void:
	var vis := _column_model.visible_columns()
	_col_x_offsets.clear()
	var x := 0
	for col: ColumnDef in vis:
		_col_x_offsets.append(x)
		x += COLLAPSED_WIDTH if col.collapsed else col.width
	_total_width = x


func _rebuild_header() -> void:
	for child in _header_bar.get_children():
		child.queue_free()

	var vis := _column_model.visible_columns()

	for i in vis.size():
		var col: ColumnDef = vis[i]
		var x: int = _col_x_offsets[i]
		var eff_w: int = COLLAPSED_WIDTH if col.collapsed else col.width

		# Column background (visual only — ALL children have MOUSE_FILTER_IGNORE).
		var bg := ColorRect.new()
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.position = Vector2(x, 1)
		bg.size = Vector2(eff_w - 1, HEADER_HEIGHT - 1)
		bg.color = (
			Color(0.10, 0.12, 0.20, 0.80)
			if not col.collapsed
			else Color(0.08, 0.08, 0.16, 0.60)
		)
		_header_bar.add_child(bg)

		if not col.collapsed:
			var lbl := Label.new()
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.position = Vector2(x + 6, 0)
			# Reserve room for sort chevron so it doesn't get clipped.
			var text_right_pad := 20 if _sort_column == i else 12
			lbl.size = Vector2(maxf(0.0, float(eff_w - text_right_pad - 6)), HEADER_HEIGHT)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.clip_text = true
			lbl.text = col.display_name
			_header_bar.add_child(lbl)

			if _sort_column == i:
				var chevron := Label.new()
				chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
				chevron.position = Vector2(x + eff_w - 23, 0)
				chevron.size = Vector2(12, HEADER_HEIGHT)
				chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				chevron.text = "▲" if _sort_dir == 1 else "▼"
				_header_bar.add_child(chevron)

	_draw_reorder_target(vis)


# ---------------------------------------------------------------------------
# Private — header input (centralised)
# ---------------------------------------------------------------------------

## Single gui_input handler for the whole header bar.
## Godot routes ALL mouse events to the control that received the initial
## button press until that button is released — so resize drags are smooth
## even when the mouse moves outside the header bounds.
func _on_header_gui_input(event: InputEvent) -> void:
	if _column_model == null:
		return
	var vis := _column_model.visible_columns()
	var lx: float = (event as InputEventMouse).position.x \
		if event is InputEventMouse else -1.0

	if _handle_resize_drag_input(event, vis, lx):
		return
	if _handle_reorder_drag_input(event, vis, lx):
		return

	var rz := _resize_zone_at(lx, vis)
	var ci := _col_at(lx, vis)

	if _handle_header_hover(event, vis, rz, ci):
		return
	_handle_header_click(event, vis, lx, rz, ci)


func _handle_resize_drag_input(event: InputEvent, vis: Array, lx: float) -> bool:
	if _drag_col_index < 0:
		return false
	if event is InputEventMouseMotion and _drag_col_index < vis.size():
		var delta := int(lx - _drag_start_x)
		vis[_drag_col_index].width = maxi(_drag_start_w + delta, MIN_COL_WIDTH)
		_compute_column_offsets()
		_rebuild_header()
		_populate_rows()
		accept_event()
		return true
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT and not mbe.pressed:
			_drag_col_index = -1
			column_layout_changed.emit()
			accept_event()
		return true
	return false


func _handle_reorder_drag_input(event: InputEvent, vis: Array, lx: float) -> bool:
	if _header_press_col < 0:
		return false
	if event is InputEventMouseMotion:
		if absf(lx - _header_press_x) >= REORDER_DRAG_THRESHOLD_PX:
			_header_press_moved = true
			var next_slot := _slot_at_x(lx, vis)
			if next_slot != _reorder_drop_slot:
				_reorder_drop_slot = next_slot
				_rebuild_header()
			_header_bar.mouse_default_cursor_shape = Control.CURSOR_DRAG
		accept_event()
		return true
	if event is InputEventMouseButton:
		var release := event as InputEventMouseButton
		if release.button_index == MOUSE_BUTTON_LEFT and not release.pressed:
			if _header_press_moved:
				if _apply_column_reorder(_header_press_col, _reorder_drop_slot):
					_rebuild()
					column_layout_changed.emit()
			else:
				_on_header_clicked(_header_press_col)
			_clear_header_press_state()
			accept_event()
		return true
	return false


func _handle_header_hover(event: InputEvent, vis: Array, rz: int, ci: int) -> bool:
	if not event is InputEventMouseMotion:
		return false
	_header_bar.mouse_default_cursor_shape = (
		Control.CURSOR_HSIZE if rz >= 0 else Control.CURSOR_ARROW
	)
	_header_bar.tooltip_text = (
		vis[ci].display_name if ci >= 0 and vis[ci].collapsed else ""
	)
	return true


func _handle_header_click(event: InputEvent, vis: Array, lx: float, rz: int, ci: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return

	if mbe.button_index == MOUSE_BUTTON_LEFT:
		if rz >= 0:
			# Begin resize drag.
			_drag_col_index = rz
			_drag_start_x   = lx
			_drag_start_w   = vis[rz].width
		elif ci >= 0:
			if vis[ci].collapsed:
				vis[ci].collapsed = false
				_rebuild()
				column_layout_changed.emit()
			elif vis[ci].pinned:
				# Pinned columns cannot be reordered — treat as no-op.
				pass
			else:
				_header_press_col = ci
				_header_press_x = lx
				_header_press_moved = false
				_reorder_drop_slot = ci
		accept_event()

	elif mbe.button_index == MOUSE_BUTTON_RIGHT:
		if ci >= 0:
			_show_column_context_menu(ci, mbe.global_position)
		accept_event()


## Returns the visible-column index whose right boundary is within
## RESIZE_ZONE_PX of [param x], or -1 if none (collapsed cols are skipped).
func _resize_zone_at(x: float, vis: Array) -> int:
	for i in vis.size():
		if vis[i].collapsed:
			continue
		var right := float(_col_x_offsets[i] + vis[i].width)
		if abs(x - right) <= RESIZE_ZONE_PX:
			return i
	return -1


## Returns the visible-column index whose area contains [param x], or -1.
func _col_at(x: float, vis: Array) -> int:
	for i in vis.size():
		var eff_w: int = COLLAPSED_WIDTH if vis[i].collapsed else vis[i].width
		if x >= _col_x_offsets[i] and x < _col_x_offsets[i] + eff_w:
			return i
	return -1


## Returns insertion slot in visible-column space for a drop position.
## Slot range is 0..vis.size().
func _slot_at_x(x: float, vis: Array) -> int:
	for i in vis.size():
		var eff_w: int = COLLAPSED_WIDTH if vis[i].collapsed else vis[i].width
		var left: float = _col_x_offsets[i]
		var midpoint: float = left + (float(eff_w) * 0.5)
		if x < midpoint:
			return i
	return vis.size()


func _apply_column_reorder(from_visible_index: int, to_visible_slot: int) -> bool:
	if _column_model == null:
		return false
	return _column_model.move_visible_column_to_slot(from_visible_index, to_visible_slot)


func _clear_header_press_state() -> void:
	_header_press_col = -1
	_header_press_x = 0.0
	_header_press_moved = false
	_reorder_drop_slot = -1
	_header_bar.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_rebuild_header()


func _draw_reorder_target(vis: Array) -> void:
	if not _header_press_moved or _reorder_drop_slot < 0:
		return
	if _reorder_drop_slot < vis.size():
		var target_col: ColumnDef = vis[_reorder_drop_slot]
		var target_x: int = _col_x_offsets[_reorder_drop_slot]
		var target_w: int = COLLAPSED_WIDTH if target_col.collapsed else target_col.width
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.position = Vector2(target_x, 1)
		fill.size = Vector2(maxi(target_w - 1, 1), HEADER_HEIGHT - 1)
		fill.color = REORDER_TARGET_FILL_COLOR
		_header_bar.add_child(fill)

	var divider_x := (
		_total_width
		if _reorder_drop_slot >= vis.size()
		else _col_x_offsets[_reorder_drop_slot]
	)
	var divider := ColorRect.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.position = Vector2(divider_x - int(REORDER_TARGET_DIVIDER_WIDTH / 2), 0)
	divider.size = Vector2(REORDER_TARGET_DIVIDER_WIDTH, HEADER_HEIGHT)
	divider.color = REORDER_TARGET_DIVIDER_COLOR
	_header_bar.add_child(divider)


func _show_column_context_menu(col_idx: int, _global_pos: Vector2) -> void:
	var vis := _column_model.visible_columns()
	if col_idx >= vis.size():
		return
	_context_menu_col = col_idx
	_context_menu.clear()
	if vis[col_idx].collapsed:
		_context_menu.add_item("Show Column", 3)
	else:
		_context_menu.add_item("Sort Ascending  ▲", 0)
		_context_menu.add_item("Sort Descending  ▼", 1)
		_context_menu.add_separator()
		_context_menu.add_item("Hide Column", 2)
	_context_menu.add_separator()
	_context_menu.add_item("Expand All Hidden", 4)
	# Use DisplayServer.mouse_get_position() for correct multi-monitor placement.
	# global_pos from gui_input is viewport-local; mouse_get_position() is screen-global.
	_context_menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ZERO))


func _on_context_menu_id_pressed(id: int) -> void:
	var vis := _column_model.visible_columns()
	if _context_menu_col < 0 or _context_menu_col >= vis.size():
		return
	var col := vis[_context_menu_col]
	match id:
		0:  # Sort Ascending
			_sort_column = _context_menu_col
			_sort_dir = 1
			_do_sort()
		1:  # Sort Descending
			_sort_column = _context_menu_col
			_sort_dir = -1
			_do_sort()
		2:  # Hide Column
			col.collapsed = true
			_rebuild()
			column_layout_changed.emit()
		3:  # Show Column
			col.collapsed = false
			_rebuild()
			column_layout_changed.emit()
		4:  # Expand All
			_on_expand_all()


func _populate_rows() -> void:
	var vis := _column_model.visible_columns()

	# Grow the VBox child pool as needed (nodes are never freed, just hidden).
	while _content.get_child_count() < _resources.size():
		var row: GridRow = _GRID_ROW_SCRIPT.new()
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.row_clicked.connect(_on_row_clicked)
		row.cell_edit_requested.connect(_on_cell_edit_requested)
		row.edit_requested.connect(_on_row_edit_requested)
		_content.add_child(row)
		row._ensure_setup()  # explicit: _ready() may still be deferred

	# Bind and show active rows.
	for i in _resources.size():
		var row: GridRow = _content.get_child(i)
		row.bind(i, _resources[i], vis, _col_x_offsets, i == _selected_index)
		row.show()

	# Hide surplus rows (VBoxContainer skips hidden children in layout).
	for i in range(_resources.size(), _content.get_child_count()):
		_content.get_child(i).hide()

	if debug_mode:
		_print_layout_debug.call_deferred()


# ---------------------------------------------------------------------------
# Private — interaction
# ---------------------------------------------------------------------------

## Open the cell editor at a specific row and visible column index.
func open_editor_at(row_index: int, col_index: int) -> void:
	_edit_row = row_index
	_edit_col = col_index
	_open_editor_at(row_index, col_index)


func _open_editor_at(row_index: int, col_index: int) -> void:
	if _column_model == null:
		return
	if row_index < 0 or row_index >= _resources.size():
		return
	var vis := _column_model.visible_columns()
	if col_index < 0 or col_index >= vis.size():
		return
	var col: ColumnDef = vis[col_index]
	var resource: Resource = _resources[row_index]

	var row_node: GridRow = _content.get_child(row_index) as GridRow
	if row_node == null:
		return
	var row_global: Vector2 = row_node.get_screen_transform().origin
	var cell_rect := Rect2i(
		int(row_global.x) + _col_x_offsets[col_index],
		int(row_global.y),
		col.width,
		ROW_HEIGHT
	)
	_cell_editor.debug_mode = debug_mode
	_cell_editor.open(resource, col, cell_rect)


func _on_row_clicked(row_index: int) -> void:
	_selected_index = row_index
	_populate_rows()   # re-render to update highlight
	if row_index >= 0 and row_index < _resources.size():
		row_selected.emit(_resources[row_index])


## Called when the user double-clicks a cell.
## Opens the CellEditor popup positioned over the clicked cell.
## Pinned columns (e.g. the filename column) are read-only — editing is blocked.
func _on_cell_edit_requested(row_index: int, col_index: int) -> void:
	var vis := _column_model.visible_columns() if _column_model else []
	if col_index >= 0 and col_index < vis.size() and vis[col_index].pinned:
		return
	_edit_row = row_index
	_edit_col = col_index
	_open_editor_at(row_index, col_index)


func _on_row_edit_requested(row_index: int, col_index: int, is_shift: bool) -> void:
	_edit_row = row_index
	_edit_col = col_index
	# For Tab navigation, commit and move to next cell.
	if is_shift or true:
		# Always open the editor; Tab navigation happens via tab_pressed from CellEditor.
		_open_editor_at(row_index, col_index)


func _on_cell_tab_pressed(is_shift: bool) -> void:
	if _edit_row < 0 or _edit_col < 0:
		return
	var vis := _column_model.visible_columns() if _column_model else []
	if vis.is_empty():
		return
	var editable_cols: Array[int] = []
	for i in vis.size():
		if not vis[i].collapsed and not vis[i].pinned:
			editable_cols.append(i)
	if editable_cols.is_empty():
		return

	var pos: int = editable_cols.find(_edit_col)
	if pos < 0:
		# Fallback: if current index is stale (e.g. column was collapsed),
		# start from the first editable column.
		pos = 0

	# Compute next cell.
	var next_pos: int = pos + (1 if not is_shift else -1)
	var next_row: int = _edit_row

	# Wrap at column edges.
	if next_pos >= editable_cols.size():
		next_pos = 0
		next_row += 1
	elif next_pos < 0:
		next_pos = editable_cols.size() - 1
		next_row -= 1

	# Keep traversal inside GoSheets even at dataset boundaries.
	if next_row >= _resources.size():
		next_row = 0
	elif next_row < 0:
		next_row = _resources.size() - 1

	_edit_col = editable_cols[next_pos]
	_edit_row = next_row
	_open_editor_at(_edit_row, _edit_col)


## Relay the committed value out to GoSheetsPanel.
func _on_cell_value_committed(
		resource: Resource,
		property: StringName,
		old_value: Variant,
		new_value: Variant) -> void:
	cell_value_changed.emit(resource, property, old_value, new_value)


func _on_header_clicked(col_index: int) -> void:
	if _sort_column == col_index:
		_sort_dir = -_sort_dir
	else:
		_sort_column = col_index
		_sort_dir = 1
	_do_sort()


func _do_sort() -> void:
	if _column_model == null:
		return
	var vis := _column_model.visible_columns()
	if _sort_column < 0 or _sort_column >= vis.size():
		return
	var prop: StringName = vis[_sort_column].property_name
	_resources.sort_custom(func(a: Resource, b: Resource) -> bool:
		var av: Variant = a.get(prop)
		var bv: Variant = b.get(prop)
		return _variant_less(av, bv) if _sort_dir == 1 else not _variant_less(av, bv)
	)
	_selected_index = -1
	_rebuild_header()
	_populate_rows()


func _on_expand_all() -> void:
	for col: ColumnDef in _column_model.visible_columns():
		col.collapsed = false
	_rebuild()
	column_layout_changed.emit()


func _variant_less(a: Variant, b: Variant) -> bool:
	if a == null:
		return b != null  # null < non-null; null == null → false
	if b == null:
		return false
	match typeof(a):
		TYPE_INT, TYPE_FLOAT:
			return float(a) < float(b)
		TYPE_STRING, TYPE_STRING_NAME:
			return (a as String) < (b as String)
		TYPE_BOOL:
			return int(a) < int(b)
		_:
			return str(a) < str(b)


# ---------------------------------------------------------------------------
# Debug
# ---------------------------------------------------------------------------

func _print_layout_debug() -> void:
	var parent_size := Vector2.ZERO
	if get_parent() is Control:
		parent_size = (get_parent() as Control).size
	print("[GoSheets/Grid] parent=%s  self=%s  scroll=%s  content=%s  rows=%d  v_flags=%d" % [
		str(parent_size),
		str(size),
		str(_scroll.size if _scroll else Vector2.ZERO),
		str(_content.size if _content else Vector2.ZERO),
		_content.get_child_count() if _content else 0,
		size_flags_vertical,
	])
	if _content:
		for i in min(_content.get_child_count(), 8):
			var row: Node = _content.get_child(i)
			print("  row[%d] visible=%s  pos=%s  size=%s  min=%s" % [
				i,
				str(row.visible),
				str(row.position),
				str(row.size),
				str((row as Control).custom_minimum_size),
			])
