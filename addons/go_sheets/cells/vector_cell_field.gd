@tool
## VectorCellField
##
## A LineEdit-based editor for vector and struct types that can be expressed
## as comma-separated values.  Parses input like "(1, 2, 3)" or "1, 2, 3"
## back into the correct Variant type on commit.

class_name VectorCellField
extends CellField

var _line_edit: LineEdit
var _type: int = TYPE_VECTOR2
var _original_value: Variant

func _init() -> void:
	_line_edit = LineEdit.new()
	_line_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line_edit.select_all_on_focus = true
	_line_edit.text_submitted.connect(
		func(_t: String) -> void: _on_submitted())
	_line_edit.focus_exited.connect(
		func() -> void: _on_focus_exited())
	add_child(_line_edit)


func setup(type: int, initial_value: Variant) -> void:
	_type = type
	_original_value = initial_value
	set_value(initial_value)


func set_value(value: Variant) -> void:
	_line_edit.text = _format_for_edit(value)


func get_value() -> Variant:
	return _parse_from_edit(_line_edit.text)


func focus_main() -> void:
	_line_edit.grab_focus()
	_line_edit.select_all()


func _on_submitted() -> void:
	value_changed.emit(get_value())


func _on_focus_exited() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null \
			and (focus_owner == self or is_ancestor_of(focus_owner)):
		return
	value_changed.emit(get_value())


static func _format_for_edit(value: Variant) -> String:
	if value == null:
		return ""
	match typeof(value):
		TYPE_VECTOR2:
			var v: Vector2 = value
			return "%.4f, %.4f" % [v.x, v.y]
		TYPE_VECTOR2I:
			var v: Vector2i = value
			return "%d, %d" % [v.x, v.y]
		TYPE_VECTOR3:
			var v: Vector3 = value
			return "%.4f, %.4f, %.4f" % [v.x, v.y, v.z]
		TYPE_VECTOR3I:
			var v: Vector3i = value
			return "%d, %d, %d" % [v.x, v.y, v.z]
		TYPE_VECTOR4:
			var v: Vector4 = value
			return "%.4f, %.4f, %.4f, %.4f" % [v.x, v.y, v.z, v.w]
		TYPE_VECTOR4I:
			var v: Vector4i = value
			return "%d, %d, %d, %d" % [v.x, v.y, v.z, v.w]
		TYPE_RECT2:
			var r: Rect2 = value
			return "%.4f, %.4f, %.4f, %.4f" % [
				r.position.x, r.position.y, r.size.x, r.size.y]
		TYPE_RECT2I:
			var r: Rect2i = value
			return "%d, %d, %d, %d" % [
				r.position.x, r.position.y, r.size.x, r.size.y]
		TYPE_TRANSFORM2D:
			var t: Transform2D = value
			return "%.4f, %.4f, %.4f, %.4f, %.4f, %.4f" % [
				t.x.x, t.x.y, t.y.x, t.y.y,
				t.origin.x, t.origin.y]
		TYPE_TRANSFORM3D:
			var t: Transform3D = value
			return "%.4f, %.4f, %.4f, %.4f, %.4f, %.4f" % [
				t.basis.x.x, t.basis.x.y, t.basis.x.z,
				t.origin.x, t.origin.y, t.origin.z]
		TYPE_BASIS:
			var b: Basis = value
			return "%.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f" % [
				b.x.x, b.x.y, b.x.z,
				b.y.x, b.y.y, b.y.z,
				b.z.x, b.z.y, b.z.z]
		TYPE_QUATERNION:
			var q: Quaternion = value
			return "%.4f, %.4f, %.4f, %.4f" % [q.x, q.y, q.z, q.w]
		TYPE_AABB:
			var a: AABB = value
			return "%.4f, %.4f, %.4f, %.4f, %.4f, %.4f" % [
				a.position.x, a.position.y, a.position.z,
				a.size.x, a.size.y, a.size.z]
		TYPE_PLANE:
			var p: Plane = value
			return "%.4f, %.4f, %.4f, %.4f" % [
				p.normal.x, p.normal.y, p.normal.z, p.d]
		TYPE_NODE_PATH:
			return str(value) if value != null else ""
		_:
			return str(value)


func _parse_from_edit(text: String) -> Variant:
	var raw: String = text.strip_edges().trim_prefix("(").trim_suffix(")")
	if _type == TYPE_NODE_PATH:
		var s := raw
		return NodePath(s) if s != "" else NodePath("")
	var parts: PackedStringArray = raw.split(",", false)
	var floats: Array[float] = []
	for part in parts:
		var s: String = part.strip_edges()
		if s != "":
			floats.append(s.to_float())
	var result := _build_from_floats(floats)
	if result != null:
		return result
	return _original_value


func _build_from_floats(f: Array[float]) -> Variant:
	if f.is_empty():
		return null
	var result: Variant = null
	match _type:
		TYPE_VECTOR2:
			if f.size() >= 2:
				result = Vector2(f[0], f[1])
		TYPE_VECTOR2I:
			if f.size() >= 2:
				result = Vector2i(int(f[0]), int(f[1]))
		TYPE_VECTOR3:
			if f.size() >= 3:
				result = Vector3(f[0], f[1], f[2])
		TYPE_VECTOR3I:
			if f.size() >= 3:
				result = Vector3i(int(f[0]), int(f[1]), int(f[2]))
		TYPE_VECTOR4:
			if f.size() >= 4:
				result = Vector4(f[0], f[1], f[2], f[3])
		TYPE_VECTOR4I:
			if f.size() >= 4:
				result = Vector4i(int(f[0]), int(f[1]), int(f[2]), int(f[3]))
		TYPE_RECT2:
			if f.size() >= 4:
				result = Rect2(f[0], f[1], f[2], f[3])
		TYPE_RECT2I:
			if f.size() >= 4:
				result = Rect2i(int(f[0]), int(f[1]), int(f[2]), int(f[3]))
		TYPE_TRANSFORM2D:
			result = _build_transform2d(f)
		TYPE_TRANSFORM3D:
			result = _build_transform3d(f)
		TYPE_BASIS:
			if f.size() >= 9:
				result = Basis(
					Vector3(f[0], f[1], f[2]),
					Vector3(f[3], f[4], f[5]),
					Vector3(f[6], f[7], f[8]))
		TYPE_QUATERNION:
			if f.size() >= 4:
				result = Quaternion(f[0], f[1], f[2], f[3])
		TYPE_AABB:
			if f.size() >= 6:
				result = AABB(
					Vector3(f[0], f[1], f[2]),
					Vector3(f[3], f[4], f[5]))
		TYPE_PLANE:
			if f.size() >= 4:
				result = Plane(Vector3(f[0], f[1], f[2]), f[3])
	return result


func _build_transform2d(f: Array[float]) -> Variant:
	if f.size() < 6:
		return null
	var t := Transform2D.IDENTITY
	t.x = Vector2(f[0], f[1])
	t.y = Vector2(f[2], f[3])
	t.origin = Vector2(f[4], f[5])
	return t


func _build_transform3d(f: Array[float]) -> Variant:
	if f.size() >= 9:
		var b := Basis(
			Vector3(f[0], f[1], f[2]),
			Vector3(f[3], f[4], f[5]),
			Vector3(f[6], f[7], f[8]))
		var o := Vector3(f[9], f[10], f[11]) \
				if f.size() >= 12 else Vector3.ZERO
		return Transform3D(b, o)
	if f.size() >= 3:
		return Transform3D(Basis(), Vector3(f[0], f[1], f[2]))
	return null