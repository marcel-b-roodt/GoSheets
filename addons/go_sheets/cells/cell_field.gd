## CellField
##
## Base class for individual cell editor controls.
## Each field type (string, int/float, bool, enum, color) extends this.
##
## A CellField is a lightweight, reusable Control that edits a single value.
## It emits value_changed when the user commits a new value, and handles
## focus/blur lifecycle without knowing about undo/redo or resource persistence.

class_name CellField
extends Control

## Emitted when the user commits a new value.
signal value_changed(new_value: Variant)

## Emitted when Tab is pressed (for navigation).
signal tab_pressed(is_shift: bool)

## Set the current value to display. Called before the field is shown.
func set_value(_value: Variant) -> void:
	push_error("CellField.set_value: subclass must override")

## Read the current value from the field. Called when committing.
func get_value() -> Variant:
	push_error("CellField.get_value: subclass must override")
	return null

## Give focus to the main input control (e.g. LineEdit, SpinBox inner edit).
func focus_main() -> void:
	grab_focus()


func _get_minimum_size() -> Vector2:
	# CellField is a wrapper; forward minimum-size queries to the active child
	# so popup sizing can reflect real editor content dimensions.
	if get_child_count() == 0:
		return Vector2.ZERO
	var child := get_child(0) as Control
	if child == null:
		return Vector2.ZERO
	return child.get_combined_minimum_size()
