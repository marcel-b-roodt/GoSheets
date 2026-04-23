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

# Self-preload
const _GRID_ROW_SCRIPT := preload("res://addons/go_sheets/grid/grid_row.gd")

# ── Layout constants ──────────────────────────────────────────────────────────
const ROW_HEIGHT      := 24
const HEADER_HEIGHT   := 28
const COLLAPSED_WIDTH := 16   # width of a collapsed column strip
const MIN_COL_WIDTH   := 40   # minimum drag-resize width
const RESIZE_ZONE_PX  := 6    # px from a column's right edge that triggers resize cursor

## Set to true (via the panel’s Debug toggle) to print layout diagnostics.
var debug_mode: bool = false

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

# ── UI nodes ─────────────────────────────────────────────────────────────────
var _scroll: ScrollContainer
var _content: VBoxContainer    # auto-sizes from children; drives scroll range
var _header_bar: Control       # fixed header — single MOUSE_FILTER_STOP, all input centralised
var _context_menu: PopupMenu   # right-click column menu
var _context_menu_col: int = -1

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
			var sort_suffix := ""
			if _sort_column == i:
				sort_suffix = "  ▲" if _sort_dir == 1 else "  ▼"

			var lbl := Label.new()
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.position = Vector2(x + 6, 0)
			lbl.size = Vector2(eff_w - 12, HEADER_HEIGHT)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.clip_text = true
			lbl.text = col.display_name + sort_suffix
			_header_bar.add_child(lbl)


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

	# ── Ongoing resize drag ───────────────────────────────────────────
	if _drag_col_index >= 0:
		if event is InputEventMouseMotion and _drag_col_index < vis.size():
			var delta := int(lx - _drag_start_x)
			vis[_drag_col_index].width = maxi(_drag_start_w + delta, MIN_COL_WIDTH)
			_compute_column_offsets()
			_rebuild_header()
			_populate_rows()
			accept_event()
			return
		if event is InputEventMouseButton:
			var mbe := event as InputEventMouseButton
			if mbe.button_index == MOUSE_BUTTON_LEFT and not mbe.pressed:
				_drag_col_index = -1
				column_layout_changed.emit()
				accept_event()
			return

	# ── Hover: cursor + tooltip ────────────────────────────────────────────
	var rz := _resize_zone_at(lx, vis)
	var ci := _col_at(lx, vis)

	if event is InputEventMouseMotion:
		_header_bar.mouse_default_cursor_shape = (
			Control.CURSOR_HSIZE if rz >= 0 else Control.CURSOR_ARROW
		)
		_header_bar.tooltip_text = (
			vis[ci].display_name if ci >= 0 and vis[ci].collapsed else ""
		)
		return

	# ── Click ───────────────────────────────────────────────────────────────
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
			else:
				_on_header_clicked(ci)
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


func _show_column_context_menu(col_idx: int, global_pos: Vector2) -> void:
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
	_context_menu.position = Vector2i(global_pos)
	_context_menu.popup()


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

func _on_row_clicked(row_index: int) -> void:
	_selected_index = row_index
	_populate_rows()   # re-render to update highlight
	if row_index >= 0 and row_index < _resources.size():
		row_selected.emit(_resources[row_index])


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
