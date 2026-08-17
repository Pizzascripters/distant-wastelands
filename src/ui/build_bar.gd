class_name BuildBar
extends Control

const TEXT := Color("F2EDE6")
const SELECTED := Color("3DDC97")
const LOCKED_MOD := Color(1, 1, 1, 0.4)
const FLASH := Color("F2EDE6")
const ICON_PX := 20
const COST_ICON_PX := 16
const FLASH_SEC := 0.2

const _WALL_PATH := "res://assets/sprites/placeholder/wall_player.png"
const _TURRET_PATH := "res://assets/sprites/placeholder/turret_player.png"
const _WORKSHOP_PATH := "res://assets/sprites/placeholder/workshop_player.png"
const _LAB_PATH := "res://assets/sprites/placeholder/lab_player.png"
const _MEDBAY_PATH := "res://assets/sprites/placeholder/medbay_player.png"
const _SCRAP_PATH := "res://assets/sprites/placeholder/scrap.png"
const _ICE_PATH := "res://assets/sprites/placeholder/ice.png"
const _PARTS_PATH := "res://assets/sprites/placeholder/parts.png"

var selected_kind: int = -1:
	set(value):
		selected_kind = value
		_refresh()

var techs_done: int = 0:
	set(value):
		techs_done = value
		_refresh()

var _entries: Array[Dictionary] = []
var _plain: StyleBoxFlat
var _selected: StyleBoxFlat
var _flash_kind: int = -1
var _flash_left: float = 0.0


func _ready() -> void:
	if theme == null:
		theme = preload("res://assets/theme/default.tres")
	mouse_filter = MOUSE_FILTER_IGNORE
	_ensure_ui()
	_refresh()


func flash_locked(kind: int) -> void:
	_ensure_ui()
	_flash_kind = kind
	_flash_left = FLASH_SEC
	set_process(true)
	_refresh()


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		set_process(false)
		return
	_flash_left = maxf(0.0, _flash_left - delta)
	if _flash_left <= 0.0:
		_flash_kind = -1
	_refresh()


func _ensure_ui() -> void:
	if not _entries.is_empty():
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
	_entries.append(_entry(col, Types.BuildingKind.WALL, "1", _WALL_PATH, [
		[_SCRAP_PATH, Constants.WALL_COST],
	]))
	_entries.append(_entry(col, Types.BuildingKind.TURRET, "2", _TURRET_PATH, [
		[_SCRAP_PATH, Constants.TURRET_COST],
	]))
	_entries.append(_entry(col, Types.BuildingKind.WORKSHOP, "3", _WORKSHOP_PATH, [
		[_SCRAP_PATH, Constants.WORKSHOP_COST],
	]))
	_entries.append(_entry(col, Types.BuildingKind.LAB, "4", _LAB_PATH, [
		[_SCRAP_PATH, Constants.LAB_COST],
	]))
	_entries.append(_entry(col, Types.BuildingKind.GREENHOUSE, "5", "", [
		[_SCRAP_PATH, 12],
		[_ICE_PATH, 4],
	]))
	_entries.append(_entry(col, Types.BuildingKind.GATE, "6", "", [
		[_SCRAP_PATH, 4],
		[_PARTS_PATH, 2],
	]))
	_entries.append(_entry(col, Types.BuildingKind.MEDBAY, "7", _MEDBAY_PATH, [
		[_SCRAP_PATH, Constants.MEDBAY_COST_SCRAP],
		[_ICE_PATH, Constants.MEDBAY_COST_ICE],
	]))


func _entry(
	parent: VBoxContainer, kind: int, hotkey: String, sprite_path: String, costs: Array
) -> Dictionary:
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var frame := PanelContainer.new()
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _plain)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	stack.mouse_filter = MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.set_anchors_preset(PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = TEXTURE_FILTER_NEAREST
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	if not sprite_path.is_empty():
		var tex := WorldView.load_png(sprite_path)
		if tex != null:
			icon.texture = tex
	stack.add_child(icon)
	var lock := ColorRect.new()
	lock.color = Color(0, 0, 0, 0.45)
	lock.set_anchors_preset(PRESET_FULL_RECT)
	lock.mouse_filter = MOUSE_FILTER_IGNORE
	lock.visible = false
	stack.add_child(lock)
	var lock_mark := Label.new()
	lock_mark.text = "x"
	lock_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_mark.set_anchors_preset(PRESET_FULL_RECT)
	lock_mark.add_theme_font_size_override("font_size", 14)
	lock_mark.add_theme_color_override("font_color", TEXT)
	lock_mark.mouse_filter = MOUSE_FILTER_IGNORE
	lock.add_child(lock_mark)
	frame.add_child(stack)
	row.add_child(frame)
	var key := Label.new()
	key.text = hotkey
	key.add_theme_font_size_override("font_size", 16)
	key.add_theme_color_override("font_color", TEXT)
	key.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(key)
	for spec in costs:
		var res := TextureRect.new()
		res.custom_minimum_size = Vector2(COST_ICON_PX, COST_ICON_PX)
		res.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		res.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		res.texture_filter = TEXTURE_FILTER_NEAREST
		res.mouse_filter = MOUSE_FILTER_IGNORE
		var res_tex := WorldView.load_png(spec[0])
		if res_tex != null:
			res.texture = res_tex
		row.add_child(res)
		var cost_lab := Label.new()
		cost_lab.text = str(spec[1])
		cost_lab.add_theme_font_size_override("font_size", 16)
		cost_lab.add_theme_color_override("font_color", TEXT)
		cost_lab.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(cost_lab)
	parent.add_child(row)
	return {"kind": kind, "frame": frame, "icon": icon, "lock": lock}


func _refresh() -> void:
	_ensure_ui()
	for entry in _entries:
		var kind: int = entry["kind"]
		var frame: PanelContainer = entry["frame"]
		var icon: TextureRect = entry["icon"]
		var lock: ColorRect = entry["lock"]
		var unlocked := Research.building_unlocked_bits(techs_done, kind)
		frame.add_theme_stylebox_override("panel", _selected if selected_kind == kind else _plain)
		if unlocked:
			icon.modulate = Color.WHITE
			lock.visible = false
		else:
			icon.modulate = LOCKED_MOD
			lock.visible = true
		if kind == _flash_kind and _flash_left > 0.0:
			icon.modulate = FLASH
			lock.visible = true
