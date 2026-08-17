class_name Hud
extends Control

const TEXT := Color("F2EDE6")
const LOW_ICE := Color("E24A3B")
const RAID_BANNER := Color("E24A3B")
const O2_FULL := Color("3DDC97")
const PANEL := Color(0, 0, 0, 0.65)
const FONT_SIZE := 16
const ICON_PX := 18
const MISSING := "—"
const PLACEHOLDER_O2_TEXT := "60 / 60"

const _SCRAP_PATH := "res://assets/sprites/placeholder/scrap.png"
const _ICE_PATH := "res://assets/sprites/placeholder/ice.png"
const _ORE_PATH := "res://assets/sprites/placeholder/ore.png"
const _PARTS_PATH := "res://assets/sprites/placeholder/parts.png"

var _carry: Dictionary = {}
var _depot: Dictionary = {}
var _ice_countdown: Label
var _o2_fill: ColorRect
var _o2_value: Label
var _raid_banner: Label


func _ready() -> void:
	if theme == null:
		theme = preload("res://assets/theme/default.tres")
	mouse_filter = MOUSE_FILTER_IGNORE
	_ensure_ui()
	apply_snapshot(SimSnapshot.new())


func apply_snapshot(snap: SimSnapshot) -> void:
	_ensure_ui()
	if snap == null:
		snap = SimSnapshot.new()

	var carry := _player_inventory(snap)
	_set_counts(_carry, carry, false)

	var depot := _player_building(snap, Types.BuildingKind.DEPOT)
	var zero_ice := _player_zero_ice_timer(snap)
	if depot.is_empty():
		_set_missing(_depot)
		_ice_countdown.visible = false
	else:
		var depot_inv := _inventory_from(depot.get("inventory", {}))
		var depot_ice: int = depot_inv["ice"]
		var low_ice := depot_ice <= 5 or zero_ice > 0.0
		_set_counts(_depot, depot_inv, low_ice)
		var show_countdown := depot_ice == 0 or zero_ice > 0.0
		_ice_countdown.visible = show_countdown
		if show_countdown:
			_ice_countdown.text = str(maxi(ceili(Constants.ZERO_ICE_LIMIT - zero_ice), 0))

	_o2_fill.color = O2_FULL
	_o2_fill.anchor_right = 1.0
	_o2_value.text = PLACEHOLDER_O2_TEXT

	var banner := _float_field(snap, "banner_timer", 0.0)
	_raid_banner.visible = banner > 0.0
	if banner > 0.0:
		_raid_banner.text = "Raid incoming"
		_raid_banner.add_theme_color_override("font_color", RAID_BANNER)


func _ensure_ui() -> void:
	if _raid_banner != null:
		return
	texture_filter = TEXTURE_FILTER_NEAREST
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	_carry = _resource_row("Carry")
	_depot = _resource_row("Depot")
	vbox.add_child(_carry["row"])
	vbox.add_child(_depot["row"])
	_ice_countdown = _label("")
	_ice_countdown.name = "IceCountdown"
	_ice_countdown.visible = false
	vbox.add_child(_ice_countdown)
	vbox.add_child(_make_o2_row())
	panel.add_child(vbox)
	add_child(panel)
	_raid_banner = _label("Raid incoming")
	_raid_banner.name = "RaidBanner"
	_raid_banner.visible = false
	_raid_banner.set_anchors_preset(PRESET_TOP_WIDE)
	_raid_banner.offset_top = 8.0
	_raid_banner.offset_bottom = 32.0
	_raid_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_raid_banner)


func _resource_row(title: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.name = title
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(_label(title))
	var slots := {}
	for kind in [
		["scrap", _SCRAP_PATH],
		["ice", _ICE_PATH],
		["ore", _ORE_PATH],
		["parts", _PARTS_PATH],
	]:
		var icon := TextureRect.new()
		icon.name = "%sIcon" % kind[0].capitalize()
		icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		var tex := WorldView.load_png(kind[1])
		if tex != null:
			icon.texture = tex
		var count := _label("0")
		count.name = "%sCount" % kind[0].capitalize()
		count.custom_minimum_size = Vector2(28, 0)
		row.add_child(icon)
		row.add_child(count)
		slots[kind[0]] = count
	return {"row": row, "counts": slots}


func _make_o2_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "O2"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(_label("O2"))
	var track := ColorRect.new()
	track.name = "O2Track"
	track.color = Color(0, 0, 0, 0.65)
	track.custom_minimum_size = Vector2(72, 10)
	track.mouse_filter = MOUSE_FILTER_IGNORE
	_o2_fill = ColorRect.new()
	_o2_fill.name = "O2Fill"
	_o2_fill.color = O2_FULL
	_o2_fill.mouse_filter = MOUSE_FILTER_IGNORE
	_o2_fill.set_anchors_preset(PRESET_FULL_RECT)
	track.add_child(_o2_fill)
	row.add_child(track)
	_o2_value = _label(PLACEHOLDER_O2_TEXT)
	_o2_value.name = "O2Value"
	row.add_child(_o2_value)
	return row


func _label(text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = MOUSE_FILTER_IGNORE
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_font_size_override("font_size", FONT_SIZE)
	return node


func _set_counts(group: Dictionary, inv: Dictionary, low_ice: bool) -> void:
	var counts: Dictionary = group["counts"]
	for key in ["scrap", "ice", "ore", "parts"]:
		var lab: Label = counts[key]
		lab.text = str(int(inv.get(key, 0)))
		var color := LOW_ICE if key == "ice" and low_ice else TEXT
		lab.add_theme_color_override("font_color", color)


func _set_missing(group: Dictionary) -> void:
	var counts: Dictionary = group["counts"]
	for key in ["scrap", "ice", "ore", "parts"]:
		var lab: Label = counts[key]
		lab.text = MISSING
		lab.add_theme_color_override("font_color", TEXT)


func _player_inventory(snap: SimSnapshot) -> Dictionary:
	for rec in snap.units:
		if rec.get("kind", -1) == Types.UnitKind.PLAYER:
			return _inventory_from(rec.get("inventory", {}))
	return _inventory_from({})


func _player_building(snap: SimSnapshot, kind: int) -> Dictionary:
	if not "buildings" in snap:
		return {}
	var buildings: Variant = snap.get("buildings")
	if buildings == null:
		return {}
	for rec in buildings:
		if not rec is Dictionary:
			continue
		if rec.get("kind", -1) != kind:
			continue
		if rec.get("faction", -1) != Types.Faction.PLAYER:
			continue
		if rec.has("hp") and int(rec["hp"]) <= 0:
			continue
		return rec
	return {}


func _player_zero_ice_timer(snap: SimSnapshot) -> float:
	if "player_zero_ice_timer" in snap:
		return float(snap.get("player_zero_ice_timer"))
	if "zero_ice_timer" in snap:
		var value: Variant = snap.get("zero_ice_timer")
		if value is Dictionary:
			return float(value.get(Types.Faction.PLAYER, 0.0))
		return float(value)
	return 0.0


func _float_field(snap: SimSnapshot, key: String, fallback: float) -> float:
	if key in snap:
		return float(snap.get(key))
	return fallback


func _inventory_from(inv: Variant) -> Dictionary:
	var out := {"scrap": 0, "ice": 0, "ore": 0, "parts": 0}
	if inv is Dictionary:
		out["scrap"] = int(inv.get("scrap", 0))
		out["ice"] = int(inv.get("ice", 0))
		out["ore"] = int(inv.get("ore", 0))
		out["parts"] = int(inv.get("parts", 0))
	elif inv is Object:
		for key in out.keys():
			if key in inv:
				out[key] = int(inv.get(key))
	return out
