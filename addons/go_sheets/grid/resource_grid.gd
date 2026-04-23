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
var _header_bar: Control       # fixed header above scroll

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
	_header_bar.clip_contents = true
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
	var any_collapsed := false
	for col: ColumnDef in vis:
		if col.collapsed:
			any_collapsed = true
			break

	for i in vis.size():
		var col: ColumnDef = vis[i]
		var eff_w: int = COLLAPSED_WIDTH if col.collapsed else col.width

		if col.collapsed:
			# Collapsed strip: just a narrow button with tooltip + expand icon.
			var strip := Button.new()
			strip.flat = true
			strip.text = "▶"
			strip.tooltip_text = col.display_name
			strip.position = Vector2(_col_x_offsets[i], 0)
			strip.size = Vector2(COLLAPSED_WIDTH, HEADER_HEIGHT)
			strip.clip_text = true
			var col_idx := i
			strip.pressed.connect(func() -> void: _on_col_expand(col_idx))
			_header_bar.add_child(strip)
		else:
			# Normal column: sort button + collapse chevron + resize handle.
			var sort_suffix := ""
			if _sort_column == i:
				sort_suffix = " ▲" if _sort_dir == 1 else " ▼"

			var btn := Button.new()
			btn.flat = true
			# Leave room on the right for the collapse chevron (16px).
			btn.size = Vector2(eff_w - 16, HEADER_HEIGHT)
			btn.position = Vector2(_col_x_offsets[i], 0)
			btn.text = col.display_name + sort_suffix
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.clip_text = true
			var col_idx := i
			btn.pressed.connect(func() -> void: _on_header_clicked(col_idx))
			_header_bar.add_child(btn)

			# Collapse chevron (◄) — sits in the last 16px of the column.
			var chev := Button.new()
			chev.flat = true
			chev.text = "◄"
			chev.tooltip_text = "Collapse \'%s\'" % col.display_name
			chev.size = Vector2(16, HEADER_HEIGHT)
			chev.position = Vector2(_col_x_offsets[i] + eff_w - 16, 0)
			chev.pressed.connect(func() -> void: _on_col_collapse(col_idx))
			_header_bar.add_child(chev)

			# Resize drag handle — a thin strip at the right edge.
			var handle := Control.new()
			handle.size = Vector2(6, HEADER_HEIGHT)
			handle.position = Vector2(_col_x_offsets[i] + eff_w - 3, 0)
			handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
			handle.mouse_filter = Control.MOUSE_FILTER_STOP
			var h_idx := i
			handle.gui_input.connect(func(ev: InputEvent) -> void:
				_on_resize_handle_input(ev, h_idx)
			)
			_header_bar.add_child(handle)

	# "Expand all" button at the far right when any column is collapsed.
	if any_collapsed:
		var expand_all := Button.new()
		expand_all.flat = false
		expand_all.text = "⊞"
		expand_all.tooltip_text = "Expand all columns"
		expand_all.size = Vector2(28, HEADER_HEIGHT)
		expand_all.position = Vector2(_total_width + 4, 0)
		expand_all.pressed.connect(_on_expand_all)
		_header_bar.add_child(expand_all)


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

	var vis := _column_model.visible_columns()
	if col_index >= vis.size():
		return
	var prop: StringName = vis[col_index].property_name

	_resources.sort_custom(func(a: Resource, b: Resource) -> bool:
		var av: Variant = a.get(prop)
		var bv: Variant = b.get(prop)
		var less: bool = _variant_less(av, bv)
		return less if _sort_dir == 1 else not less
	)

	_selected_index = -1
	_rebuild_header()
	_populate_rows()


func _on_col_collapse(col_index: int) -> void:
	var vis := _column_model.visible_columns()
	if col_index >= vis.size():
		return
	vis[col_index].collapsed = true
	_rebuild()
	column_layout_changed.emit()


func _on_col_expand(col_index: int) -> void:
	var vis := _column_model.visible_columns()
	if col_index >= vis.size():
		return
	vis[col_index].collapsed = false
	_rebuild()
	column_layout_changed.emit()


func _on_expand_all() -> void:
	for col: ColumnDef in _column_model.visible_columns():
		col.collapsed = false
	_rebuild()
	column_layout_changed.emit()


func _on_resize_handle_input(event: InputEvent, col_index: int) -> void:
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				var vis := _column_model.visible_columns()
				if col_index < vis.size():
					_drag_col_index = col_index
					_drag_start_x   = mbe.global_position.x
					_drag_start_w   = vis[col_index].width
			else:
				if _drag_col_index >= 0:
					_drag_col_index = -1
					column_layout_changed.emit()
	elif event is InputEventMouseMotion and _drag_col_index == col_index:
		var mme := event as InputEventMouseMotion
		var delta := int(mme.global_position.x - _drag_start_x)
		var vis := _column_model.visible_columns()
		if _drag_col_index < vis.size():
			vis[_drag_col_index].width = maxi(_drag_start_w + delta, MIN_COL_WIDTH)
			_compute_column_offsets()
			_rebuild_header()
			_populate_rows()


static func _variant_less(a: Variant, b: Variant) -> bool:
	if a == null and b == null:
		return false
	if a == null:
		return true
	if b == null:
		return false
	# Compare as strings for non-numeric types
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
