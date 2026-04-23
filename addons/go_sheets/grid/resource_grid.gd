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

# Self-preload
const _GRID_ROW_SCRIPT := preload("res://addons/go_sheets/grid/grid_row.gd")

# ── Layout constants ──────────────────────────────────────────────────────────
const ROW_HEIGHT    := 24
const HEADER_HEIGHT := 28

## Set to true (via the panel’s Debug toggle) to print layout diagnostics.
var debug_mode: bool = false

# ── State ─────────────────────────────────────────────────────────────────────
var _column_model: ColumnModel
var _resources: Array[Resource] = []
var _selected_index: int = -1

# Sort state
var _sort_column: int = -1     # index into visible columns
var _sort_dir: int = 0          # 1 = asc, -1 = desc

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
		x += col.width
	_total_width = x


func _rebuild_header() -> void:
	# Remove old header labels
	for child in _header_bar.get_children():
		child.queue_free()

	var vis := _column_model.visible_columns()
	for i in vis.size():
		var col: ColumnDef = vis[i]
		var btn := Button.new()
		btn.text = col.display_name
		btn.flat = true
		btn.size = Vector2(col.width, HEADER_HEIGHT)
		btn.position = Vector2(_col_x_offsets[i], 0)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color", Color.WHITE)
		var sort_suffix := ""
		if _sort_column == i:
			sort_suffix = " ▲" if _sort_dir == 1 else " ▼"
		btn.text = col.display_name + sort_suffix
		var col_idx := i   # capture for closure
		btn.pressed.connect(func() -> void: _on_header_clicked(col_idx))
		_header_bar.add_child(btn)


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
