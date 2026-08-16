class_name BuildBar
extends Control

const TEXT := Color("F2EDE6")
const SELECTED := Color("3DDC97")

var selected_kind: int = -1:
	set(value):
		selected_kind = value
		_refresh()

var _wall: Label
var _turret: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(col)
	_wall = _entry("1  Wall  %d" % Constants.WALL_COST)
	_turret = _entry("2  Turret  %d" % Constants.TURRET_COST)
	col.add_child(_wall)
	col.add_child(_turret)
	_refresh()


func _entry(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", TEXT)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label


func _refresh() -> void:
	if _wall == null:
		return
	_wall.add_theme_color_override(
		"font_color", SELECTED if selected_kind == Types.BuildingKind.WALL else TEXT
	)
	_turret.add_theme_color_override(
		"font_color", SELECTED if selected_kind == Types.BuildingKind.TURRET else TEXT
	)
