class_name BuildingPanel
extends Control

const TEXT := Color("F2EDE6")
const PANEL := Color(0, 0, 0, 0.65)
const HP_FILL := Color("3DDC97")
const SELECTED := Color("3DDC97")
const FONT_SIZE := 16
const ICON_PX := 32
const RES_ICON_PX := 16

const _HABITAT := "res://assets/sprites/placeholder/habitat_player.png"
const _DEPOT := "res://assets/sprites/placeholder/depot_player.png"
const _WALL := "res://assets/sprites/placeholder/wall_player.png"
const _TURRET := "res://assets/sprites/placeholder/turret_player.png"
const _WORKSHOP := "res://assets/sprites/placeholder/workshop_player.png"
const _LAB := "res://assets/sprites/placeholder/lab_player.png"
const _SCRAP := "res://assets/sprites/placeholder/scrap.png"
const _ICE := "res://assets/sprites/placeholder/ice.png"
const _ORE := "res://assets/sprites/placeholder/ore.png"
const _PARTS := "res://assets/sprites/placeholder/parts.png"

var inspected_id: int = -1
var withdraw: bool = false
var pending_research_kind: int = -1

var _kind: int = -1
var _faction: int = Types.Faction.PLAYER
var _research_selected: int = -1
var _research_progress: float = 0.0
var _techs_done: int = 0
var _icon: TextureRect
var _hp_fill: ColorRect
var _hp_value: Label
var _depot_box: VBoxContainer
var _depot_counts: Dictionary = {}
var _deposit_btn: Button
var _withdraw_btn: Button
var _lab_box: VBoxContainer
var _tech_btns: Array[Button] = []
var _lab_fill: ColorRect
var _lab_progress: Label
var _workshop_box: VBoxContainer
var _workshop_lock: Label
var _plain: StyleBoxFlat
var _selected: StyleBoxFlat


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_STOP


func _ready() -> void:
	if theme == null:
		theme = preload("res://assets/theme/default.tres")
	mouse_filter = MOUSE_FILTER_STOP
	visible = inspected_id >= 0
	_ensure_ui()


func is_open() -> bool:
	return visible and inspected_id >= 0


func inspected_kind() -> int:
	return _kind


func withdraw_active() -> bool:
	return (
		is_open()
		and _kind == Types.BuildingKind.DEPOT
		and _faction == Types.Faction.PLAYER
		and withdraw
	)


func consumes_pointer(screen_pos: Vector2) -> bool:
	if not visible:
		return false
	return get_global_rect().has_point(screen_pos)


func open_building(rec: Dictionary) -> void:
	var id := int(rec.get("id", -1))
	if not visible or inspected_id != id:
		withdraw = false
		pending_research_kind = -1
	inspected_id = id
	visible = true
	apply_record(rec)


func close() -> void:
	inspected_id = -1
	withdraw = false
	pending_research_kind = -1
	_kind = -1
	visible = false


func take_research_kind() -> int:
	var kind := pending_research_kind
	pending_research_kind = -1
	return kind


func apply_snapshot(snap: SimSnapshot) -> void:
	if inspected_id < 0:
		visible = false
		return
	var rec := find_building(snap, inspected_id)
	if rec.is_empty() or int(rec.get("hp", 0)) <= 0:
		close()
		return
	if snap != null:
		_research_selected = int(snap.research_selected)
		_research_progress = float(snap.research_progress)
		_techs_done = int(snap.techs_done)
	apply_record(rec)


func apply_record(rec: Dictionary) -> void:
	_ensure_ui()
	_kind = int(rec.get("kind", -1))
	_faction = int(rec.get("faction", Types.Faction.PLAYER))
	var tex := WorldView.load_png(_icon_path(_kind))
	if tex != null:
		_icon.texture = tex
	var hp := int(rec.get("hp", 0))
	var hp_max := maxi(int(rec.get("hp_max", 0)), 0)
	_hp_value.text = "%d / %d" % [hp, hp_max]
	var ratio := 0.0
	if hp_max > 0:
		ratio = clampf(float(hp) / float(hp_max), 0.0, 1.0)
	_hp_fill.anchor_right = ratio
	var is_depot := _kind == Types.BuildingKind.DEPOT
	_depot_box.visible = is_depot
	if is_depot:
		var inv := _inventory_from(rec.get("inventory", {}))
		for key in ["scrap", "ice", "ore", "parts"]:
			var lab: Label = _depot_counts[key]
			lab.text = "%d / %d" % [int(inv[key]), int(inv["cap_%s" % key])]
	if _lab_box != null:
		_lab_box.visible = _kind == Types.BuildingKind.LAB
		if _lab_box.visible:
			_refresh_lab()
	if _workshop_box != null:
		_workshop_box.visible = _kind == Types.BuildingKind.WORKSHOP
		if _workshop_box.visible:
			_workshop_lock.visible = (_techs_done & (1 << Types.TechKind.METALLURGY)) == 0
	_refresh_toggle()


static func find_building(snap: SimSnapshot, id: int) -> Dictionary:
	if snap == null:
		return {}
	for rec in snap.buildings:
		if not rec is Dictionary:
			continue
		if int(rec.get("id", -1)) == id:
			return rec
	return {}


static func living_player_record(rec: Dictionary) -> bool:
	if rec.is_empty():
		return false
	if int(rec.get("faction", -1)) != Types.Faction.PLAYER:
		return false
	return int(rec.get("hp", 0)) > 0


static func footprint_aabb(rec: Dictionary) -> Rect2:
	var origin := Vector2.ZERO
	if rec.has("origin_tile"):
		var tile: Vector2i = rec["origin_tile"]
		origin = Vector2(tile) * float(Constants.TILE)
	elif rec.has("pos"):
		origin = rec["pos"]
	var kind := int(rec.get("kind", -1))
	var span := World.footprint_span(kind)
	var size := float(span * Constants.TILE)
	return Rect2(origin, Vector2(size, size))


static func point_aabb_distance(point: Vector2, aabb: Rect2) -> float:
	var closest := Vector2(
		clampf(point.x, aabb.position.x, aabb.end.x),
		clampf(point.y, aabb.position.y, aabb.end.y)
	)
	return point.distance_to(closest)


static func nearest_in_range(snap: SimSnapshot, pos: Vector2) -> Dictionary:
	var best := {}
	var best_dist := INF
	var best_id := 0x7fffffff
	if snap == null:
		return best
	for rec in snap.buildings:
		if not rec is Dictionary or not living_player_record(rec):
			continue
		var dist := point_aabb_distance(pos, footprint_aabb(rec))
		if dist > Constants.INTERACT_BUILDING_RANGE:
			continue
		var id := int(rec.get("id", 0x7fffffff))
		if dist < best_dist or (is_equal_approx(dist, best_dist) and id < best_id):
			best = rec
			best_dist = dist
			best_id = id
	return best


static func at_world_point(snap: SimSnapshot, world_pos: Vector2) -> Dictionary:
	if snap == null:
		return {}
	for rec in snap.buildings:
		if not rec is Dictionary or not living_player_record(rec):
			continue
		if footprint_aabb(rec).has_point(world_pos):
			return rec
	return {}


func _ensure_ui() -> void:
	if _icon != null:
		return
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(260, 88)
	_plain = StyleBoxFlat.new()
	_plain.bg_color = Color(0, 0, 0, 0.35)
	_plain.set_border_width_all(2)
	_plain.border_color = Color(0, 0, 0, 0)
	_plain.content_margin_left = 8
	_plain.content_margin_top = 4
	_plain.content_margin_right = 8
	_plain.content_margin_bottom = 4
	_selected = _plain.duplicate()
	_selected.border_color = SELECTED
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	var main := HBoxContainer.new()
	main.name = "Main"
	main.mouse_filter = MOUSE_FILTER_IGNORE
	main.add_theme_constant_override("separation", 10)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = MOUSE_FILTER_IGNORE
	main.add_child(_icon)
	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.mouse_filter = MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 6)
	stats.add_child(_make_hp_row())
	_depot_box = _make_depot_box()
	stats.add_child(_depot_box)
	_lab_box = _make_lab_box()
	stats.add_child(_lab_box)
	_workshop_box = _make_workshop_box()
	stats.add_child(_workshop_box)
	main.add_child(stats)
	panel.add_child(main)
	add_child(panel)


func _make_hp_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "HpRow"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var track := ColorRect.new()
	track.name = "HpTrack"
	track.color = Color(0, 0, 0, 0.65)
	track.custom_minimum_size = Vector2(96, 10)
	track.mouse_filter = MOUSE_FILTER_IGNORE
	_hp_fill = ColorRect.new()
	_hp_fill.name = "HpFill"
	_hp_fill.color = HP_FILL
	_hp_fill.mouse_filter = MOUSE_FILTER_IGNORE
	_hp_fill.set_anchors_preset(PRESET_FULL_RECT)
	track.add_child(_hp_fill)
	row.add_child(track)
	_hp_value = _label("0 / 0")
	_hp_value.name = "HpValue"
	row.add_child(_hp_value)
	return row


func _make_depot_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "DepotBox"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	box.visible = false
	var row := HBoxContainer.new()
	row.name = "Stocks"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	for spec in [
		["scrap", _SCRAP],
		["ice", _ICE],
		["ore", _ORE],
		["parts", _PARTS],
	]:
		var icon := TextureRect.new()
		icon.name = "%sIcon" % (spec[0] as String).capitalize()
		icon.custom_minimum_size = Vector2(RES_ICON_PX, RES_ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		var tex := WorldView.load_png(spec[1])
		if tex != null:
			icon.texture = tex
		var count := _label("0 / 0")
		count.name = "%sCount" % (spec[0] as String).capitalize()
		row.add_child(icon)
		row.add_child(count)
		_depot_counts[spec[0]] = count
	box.add_child(row)
	var toggle := HBoxContainer.new()
	toggle.name = "Toggle"
	toggle.mouse_filter = MOUSE_FILTER_IGNORE
	toggle.add_theme_constant_override("separation", 6)
	_deposit_btn = _toggle_button("Deposit")
	_withdraw_btn = _toggle_button("Withdraw")
	_deposit_btn.pressed.connect(_on_deposit_pressed)
	_withdraw_btn.pressed.connect(_on_withdraw_pressed)
	toggle.add_child(_deposit_btn)
	toggle.add_child(_withdraw_btn)
	box.add_child(toggle)
	return box


func _make_lab_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "LabBox"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	box.visible = false
	var row := HBoxContainer.new()
	row.name = "Techs"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var icons := [_ICE, _ORE, _SCRAP, _TURRET]
	for i in 4:
		var btn := _toggle_button(str(i + 1))
		btn.name = "Tech%d" % (i + 1)
		btn.custom_minimum_size = Vector2(36, 36)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(RES_ICON_PX, RES_ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		var tex := WorldView.load_png(icons[i])
		if tex != null:
			icon.texture = tex
		btn.add_child(icon)
		var kind := i
		btn.pressed.connect(func() -> void:
			_on_tech_pressed(kind)
		)
		row.add_child(btn)
		_tech_btns.append(btn)
	box.add_child(row)
	var track := ColorRect.new()
	track.name = "LabTrack"
	track.color = Color(0, 0, 0, 0.65)
	track.custom_minimum_size = Vector2(160, 10)
	track.mouse_filter = MOUSE_FILTER_IGNORE
	_lab_fill = ColorRect.new()
	_lab_fill.name = "LabFill"
	_lab_fill.color = SELECTED
	_lab_fill.mouse_filter = MOUSE_FILTER_IGNORE
	_lab_fill.set_anchors_preset(PRESET_FULL_RECT)
	track.add_child(_lab_fill)
	box.add_child(track)
	_lab_progress = _label("0 / 0")
	_lab_progress.name = "LabProgress"
	box.add_child(_lab_progress)
	return box


func _make_workshop_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "WorkshopBox"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.visible = false
	var recipe := HBoxContainer.new()
	recipe.name = "WorkshopRecipe"
	recipe.mouse_filter = MOUSE_FILTER_IGNORE
	recipe.add_theme_constant_override("separation", 4)
	for spec in [
		[_SCRAP, str(Constants.WORKSHOP_SCRAP_COST)],
		[_ORE, str(Constants.WORKSHOP_ORE_COST)],
	]:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(RES_ICON_PX, RES_ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		var tex := WorldView.load_png(spec[0])
		if tex != null:
			icon.texture = tex
		recipe.add_child(icon)
		recipe.add_child(_label(spec[1]))
	recipe.add_child(_label("->"))
	var parts_icon := TextureRect.new()
	parts_icon.custom_minimum_size = Vector2(RES_ICON_PX, RES_ICON_PX)
	parts_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parts_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parts_icon.texture_filter = TEXTURE_FILTER_NEAREST
	parts_icon.mouse_filter = MOUSE_FILTER_IGNORE
	var parts_tex := WorldView.load_png(_PARTS)
	if parts_tex != null:
		parts_icon.texture = parts_tex
	recipe.add_child(parts_icon)
	recipe.add_child(_label(str(Constants.WORKSHOP_PARTS_OUT)))
	box.add_child(recipe)
	_workshop_lock = _label("locked")
	_workshop_lock.name = "WorkshopLock"
	box.add_child(_workshop_lock)
	return box


func _on_tech_pressed(kind: int) -> void:
	if kind == Types.TechKind.BALLISTICS and (_techs_done & (1 << Types.TechKind.METALLURGY)) == 0:
		return
	pending_research_kind = kind


func _refresh_lab() -> void:
	var metal_done := (_techs_done & (1 << Types.TechKind.METALLURGY)) != 0
	for i in _tech_btns.size():
		var btn := _tech_btns[i]
		var done := (_techs_done & (1 << i)) != 0
		var selected := _research_selected == i
		btn.disabled = i == Types.TechKind.BALLISTICS and not metal_done
		btn.modulate = Color(1, 1, 1, 0.4) if btn.disabled or done else Color.WHITE
		btn.add_theme_stylebox_override("normal", _selected if selected else _plain)
		btn.add_theme_stylebox_override("hover", _selected if selected else _plain)
	var dur := Research.duration(_research_selected) if _research_selected >= 0 else 0.0
	var ratio := 0.0
	if dur > 0.0:
		ratio = clampf(_research_progress / dur, 0.0, 1.0)
	_lab_fill.anchor_right = ratio
	if _research_selected < 0:
		_lab_progress.text = "0 / 0"
	else:
		_lab_progress.text = "%.1f / %.1f" % [_research_progress, dur]


func _toggle_button(title: String) -> Button:
	var btn := Button.new()
	btn.name = "%sButton" % title
	btn.text = title
	btn.focus_mode = FOCUS_NONE
	btn.mouse_filter = MOUSE_FILTER_STOP
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_font_size_override("font_size", FONT_SIZE)
	btn.add_theme_stylebox_override("normal", _plain)
	btn.add_theme_stylebox_override("hover", _plain)
	btn.add_theme_stylebox_override("pressed", _selected)
	return btn


func _on_deposit_pressed() -> void:
	withdraw = false
	_refresh_toggle()


func _on_withdraw_pressed() -> void:
	withdraw = true
	_refresh_toggle()


func _refresh_toggle() -> void:
	if _deposit_btn == null:
		return
	_deposit_btn.add_theme_stylebox_override("normal", _selected if not withdraw else _plain)
	_withdraw_btn.add_theme_stylebox_override("normal", _selected if withdraw else _plain)


func _label(text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = MOUSE_FILTER_IGNORE
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_font_size_override("font_size", FONT_SIZE)
	return node


func _icon_path(kind: int) -> String:
	match kind:
		Types.BuildingKind.HABITAT:
			return _HABITAT
		Types.BuildingKind.DEPOT:
			return _DEPOT
		Types.BuildingKind.TURRET:
			return _TURRET
		Types.BuildingKind.WORKSHOP:
			return _WORKSHOP
		Types.BuildingKind.LAB:
			return _LAB
		_:
			return _WALL


func _inventory_from(inv: Variant) -> Dictionary:
	var out := {
		"scrap": 0,
		"ice": 0,
		"ore": 0,
		"parts": 0,
		"cap_scrap": 0,
		"cap_ice": 0,
		"cap_ore": 0,
		"cap_parts": 0,
	}
	if inv is Dictionary:
		for key in out.keys():
			out[key] = int(inv.get(key, 0))
	elif inv is Object:
		for key in out.keys():
			if key in inv:
				out[key] = int(inv.get(key))
	return out
