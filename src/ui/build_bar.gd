class_name BuildBar
extends Control

const TEXT := Color("F2EDE6")
const SELECTED := Color("3DDC97")
const ICON_PX := 20
const COST_ICON_PX := 16

const _WALL_PATH := "res://assets/sprites/placeholder/wall_player.png"
const _TURRET_PATH := "res://assets/sprites/placeholder/turret_player.png"
const _SCRAP_PATH := "res://assets/sprites/placeholder/scrap.png"

var selected_kind: int = -1:
	set(value):
		selected_kind = value
		_refresh()

var _wall_frame: PanelContainer
var _turret_frame: PanelContainer
var _plain: StyleBoxFlat
var _selected: StyleBoxFlat


func _ready() -> void:
	if theme == null:
		theme = preload("res://assets/theme/default.tres")
	mouse_filter = MOUSE_FILTER_IGNORE
	_ensure_ui()
	_refresh()


func _ensure_ui() -> void:
	if _wall_frame != null:
		return
	texture_filter = TEXTURE_FILTER_NEAREST
	_plain = StyleBoxFlat.new()
	_plain.bg_color = Color(0, 0, 0, 0.35)
	_plain.set_border_width_all(2)
	_plain.border_color = Color(0, 0, 0, 0)
	_plain.content_margin_left = 2
	_plain.content_margin_top = 2
	_plain.content_margin_right = 2
	_plain.content_margin_bottom = 2
	_selected = _plain.duplicate()
	_selected.border_color = SELECTED
	var col := VBoxContainer.new()
	col.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	_wall_frame = _entry(col, "1", _WALL_PATH, Constants.WALL_COST)
	_turret_frame = _entry(col, "2", _TURRET_PATH, Constants.TURRET_COST)


func _entry(parent: VBoxContainer, hotkey: String, sprite_path: String, cost: int) -> PanelContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var frame := PanelContainer.new()
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _plain)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = TEXTURE_FILTER_NEAREST
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	var tex := WorldView.load_png(sprite_path)
	if tex != null:
		icon.texture = tex
	frame.add_child(icon)
	row.add_child(frame)
	var key := Label.new()
	key.text = hotkey
	key.add_theme_font_size_override("font_size", 16)
	key.add_theme_color_override("font_color", TEXT)
	key.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(key)
	var scrap := TextureRect.new()
	scrap.custom_minimum_size = Vector2(COST_ICON_PX, COST_ICON_PX)
	scrap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scrap.texture_filter = TEXTURE_FILTER_NEAREST
	scrap.mouse_filter = MOUSE_FILTER_IGNORE
	var scrap_tex := WorldView.load_png(_SCRAP_PATH)
	if scrap_tex != null:
		scrap.texture = scrap_tex
	row.add_child(scrap)
	var cost_lab := Label.new()
	cost_lab.text = str(cost)
	cost_lab.add_theme_font_size_override("font_size", 16)
	cost_lab.add_theme_color_override("font_color", TEXT)
	cost_lab.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(cost_lab)
	parent.add_child(row)
	return frame


func _refresh() -> void:
	_ensure_ui()
	_wall_frame.add_theme_stylebox_override(
		"panel",
		_selected if selected_kind == Types.BuildingKind.WALL else _plain
	)
	_turret_frame.add_theme_stylebox_override(
		"panel",
		_selected if selected_kind == Types.BuildingKind.TURRET else _plain
	)
