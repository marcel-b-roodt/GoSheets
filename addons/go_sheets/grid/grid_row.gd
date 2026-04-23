@tool
## GridRow
##
## A single horizontal row in the ResourceGrid.
## Renders one Resource's visible-column values as read-only labels.
## Signals up when the user clicks it.

class_name GridRow
extends Control

signal row_clicked(row_index: int)

const ROW_HEIGHT := 24

var _index: int = -1
var _labels: Array = []   # Array of Label
## X positions of column dividers, drawn in _draw().
var _col_boundaries: Array[int] = []

# Background panel for selection highlight
var _bg: ColorRect


func _ready() -> void:
	_ensure_setup()


func _draw() -> void:
	# Subtle vertical column divider lines.
	var c := Color(1.0, 1.0, 1.0, 0.07)
	for x in _col_boundaries:
		draw_line(Vector2(x, 2), Vector2(x, ROW_HEIGHT - 2), c, 1.0)


## Called eagerly before tree entry so bind() works immediately after new().
func _ensure_setup() -> void:
	if _bg != null:
		return
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color.TRANSPARENT
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


## Bind this row to [param index] position in the dataset.
##
## [param resource]       — Resource whose properties to display
## [param columns]        — Ordered Array[ColumnDef] of visible columns
## [param x_offsets]      — Matching Array[int] of x pixel offsets
## [param is_selected]    — Whether to render a selection highlight
func bind(
	index: int,
	resource: Resource,
	columns: Array,
	x_offsets: Array[int],
	is_selected: bool
) -> void:
	_index = index

	# Update column divider positions for _draw().
	_col_boundaries.clear()
	for i in range(1, x_offsets.size()):
		_col_boundaries.append(x_offsets[i])
	queue_redraw()

	# Grow label pool as needed
	while _labels.size() < columns.size():
		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		add_child(lbl)
		_labels.append(lbl)

	# Populate — collapsed columns get a hidden label (space reserved by offset)
	for i in columns.size():
		var col = columns[i]
		var lbl: Label = _labels[i]
		if col.collapsed:
			lbl.hide()
			continue
		lbl.position = Vector2(x_offsets[i] + 4, 0)
		lbl.size = Vector2(col.width - 8, ROW_HEIGHT)
		lbl.text = _format_value(resource.get(col.property_name), col.property_type)
		lbl.show()

	# Hide surplus labels
	for i in range(columns.size(), _labels.size()):
		_labels[i].hide()

	# Background tint
	if is_selected:
		_bg.color = Color(0.2, 0.5, 1.0, 0.35)
	elif index % 2 == 0:
		_bg.color = Color(1.0, 1.0, 1.0, 0.03)
	else:
		_bg.color = Color.TRANSPARENT


# ---------------------------------------------------------------------------
# Value formatting
# ---------------------------------------------------------------------------

static func _format_value(value: Variant, type: Variant.Type) -> String:
	if value == null:
		return ""
	match type:
		TYPE_BOOL:
			return "Yes" if bool(value) else "No"
		TYPE_FLOAT:
			var f: float = float(value)
			if abs(f - round(f)) < 0.0001:
				return str(int(f))
			# %g is not supported in GDScript; use %f then strip trailing zeros.
			return ("%.4f" % f).rstrip("0").rstrip(".")
		TYPE_ARRAY:
			var arr := value as Array
			if arr == null:
				return str(value)
			return "[%d items]" % arr.size()
		TYPE_DICTIONARY:
			var d := value as Dictionary
			if d == null:
				return str(value)
			return "{%d keys}" % d.size()
		TYPE_OBJECT:
			if value is Resource:
				var res := value as Resource
				if res.resource_path != "":
					return res.resource_path.get_file()
				return "<" + res.get_class() + ">"
			return str(value)
		_:
			return str(value)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
			row_clicked.emit(_index)
			accept_event()
