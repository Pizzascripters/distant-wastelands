class_name Hud
extends Control

const TEXT := Color("F2EDE6")
const LOW_ICE := Color("E24A3B")
const RAID_BANNER := Color("E24A3B")
const O2_FULL := Color("3DDC97")
const O2_WARN := Color("E2C044")
const O2_LOW := Color("E24A3B")
const HP_HIGH := Color("E07A5F")
const HP_MID := Color("E2C044")
const HP_LOW := Color("E24A3B")
const PANEL := Color(0, 0, 0, 0.65)
const FONT_SIZE := 16
const ICON_PX := 18
const MISSING := "—"
const PLACEHOLDER_O2_TEXT := "60 / 60"
const PLACEHOLDER_HP_TEXT := "50 / 50"

const _SCRAP_PATH := "res://assets/sprites/placeholder/scrap.png"
const _ICE_PATH := "res://assets/sprites/placeholder/ice.png"
const _ORE_PATH := "res://assets/sprites/placeholder/ore.png"
const _PARTS_PATH := "res://assets/sprites/placeholder/parts.png"
const _FOOD_PATH := "res://assets/sprites/placeholder/food.png"

var _carry: Dictionary = {}
var _colony: Dictionary = {}
var _depot: Dictionary = {}
var _o2_track: ColorRect
var _o2_fill: ColorRect
var _o2_value: Label
var _hp_track: ColorRect
var _hp_fill: ColorRect
var _hp_value: Label
var _raid_banner: Label
var _o2: float = Constants.PLAYER_O2_MAX
var _o2_max: float = Constants.PLAYER_O2_MAX


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

	var habitat_exists := not _player_building(snap, Types.BuildingKind.HABITAT).is_empty()
	var colony_ice := _colony_ice(snap)
	if not habitat_exists:
		_set_missing(_colony)
	else:
		_set_counts(_colony, {"ice": colony_ice}, colony_ice <= 5)

	var depot := _player_building(snap, Types.BuildingKind.DEPOT)
	if depot.is_empty():
		_set_missing(_depot)
	else:
		_set_counts(_depot, _inventory_from(depot.get("inventory", {})), false)

	_apply_o2(snap)
	_apply_hp(snap)

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
	_carry = _resource_row("Carry", true)
	_colony = _colony_row()
	_depot = _resource_row("Depot", false)
	vbox.add_child(_carry["row"])
	vbox.add_child(_colony["row"])
	vbox.add_child(_depot["row"])
	vbox.add_child(_make_o2_row())
	vbox.add_child(_make_hp_row())
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


func _resource_row(title: String, include_food: bool) -> Dictionary:
	var row := HBoxContainer.new()
	row.name = title
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(_label(title))
	var slots := {}
	var kinds: Array = [
		["scrap", _SCRAP_PATH],
		["ore", _ORE_PATH],
		["parts", _PARTS_PATH],
	]
	if include_food:
		kinds = [
			["scrap", _SCRAP_PATH],
			["ice", _ICE_PATH],
			["ore", _ORE_PATH],
			["parts", _PARTS_PATH],
			["food", _FOOD_PATH],
		]
	for kind in kinds:
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


func _colony_row() -> Dictionary:
	var row := HBoxContainer.new()
	row.name = "Colony"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(_label("Ice"))
	var icon := TextureRect.new()
	icon.name = "IceIcon"
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = TEXTURE_FILTER_NEAREST
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	var tex := WorldView.load_png(_ICE_PATH)
	if tex != null:
		icon.texture = tex
	var count := _label("0")
	count.name = "IceCount"
	count.custom_minimum_size = Vector2(28, 0)
	row.add_child(icon)
	row.add_child(count)
	return {"row": row, "counts": {"ice": count}}


func _make_o2_row() -> HBoxContainer:
	var meter := _make_meter_row("O2", PLACEHOLDER_O2_TEXT, O2_FULL)
	_o2_track = meter["track"]
	_o2_fill = meter["fill"]
	_o2_value = meter["value"]
	return meter["row"]


func _make_hp_row() -> HBoxContainer:
	var meter := _make_meter_row("HP", PLACEHOLDER_HP_TEXT, HP_HIGH)
	_hp_track = meter["track"]
	_hp_fill = meter["fill"]
	_hp_value = meter["value"]
	return meter["row"]


func _make_meter_row(row_name: String, placeholder: String, fill_color: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.name = row_name
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(_label(row_name))
	var track := ColorRect.new()
	track.name = "%sTrack" % row_name
	track.color = Color(0, 0, 0, 0.65)
	track.custom_minimum_size = Vector2(72, 10)
	track.mouse_filter = MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.name = "%sFill" % row_name
	fill.color = fill_color
	fill.mouse_filter = MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(PRESET_FULL_RECT)
	track.add_child(fill)
	row.add_child(track)
	var value := _label(placeholder)
	value.name = "%sValue" % row_name
	row.add_child(value)
	return {"row": row, "track": track, "fill": fill, "value": value}


func _apply_o2(snap: SimSnapshot) -> void:
	_o2 = _float_field(snap, "player_o2", Constants.PLAYER_O2_MAX)
	_o2_max = _float_field(snap, "player_o2_max", Constants.PLAYER_O2_MAX)
	if _o2_max <= 0.0:
		_o2_max = Constants.PLAYER_O2_MAX
	var ratio := clampf(_o2 / _o2_max, 0.0, 1.0)
	_o2_fill.anchor_right = ratio
	_o2_fill.color = _o2_bar_color(_o2)
	_o2_value.text = "%d / %d" % [int(round(_o2)), int(round(_o2_max))]
	if _o2 > 0.0 and _o2_track != null:
		_o2_track.color = Color(0, 0, 0, 0.65)
	set_process(_o2 == 0.0)
	if _o2 == 0.0:
		_pulse_o2_bar()


func _o2_bar_color(o2: float) -> Color:
	if o2 > Constants.PLAYER_O2_WARN:
		return O2_FULL
	if o2 > 10.0:
		return O2_WARN
	return O2_LOW


func _apply_hp(snap: SimSnapshot) -> void:
	var rec := _player_unit(snap)
	var hp_max := Constants.PLAYER_HP
	var hp := Constants.PLAYER_HP
	var alive := true
	if not rec.is_empty():
		hp_max = int(rec.get("hp_max", Constants.PLAYER_HP))
		if hp_max <= 0:
			hp_max = Constants.PLAYER_HP
		hp = int(rec.get("hp", Constants.PLAYER_HP))
		if rec.has("alive"):
			alive = bool(rec["alive"])
	var empty := not alive or hp <= 0
	var shown := 0 if empty else hp
	var ratio := 0.0 if empty else clampf(float(hp) / float(hp_max), 0.0, 1.0)
	_hp_fill.anchor_right = ratio
	_hp_fill.color = _hp_bar_color(shown, hp_max)
	_hp_value.text = "%d / %d" % [shown, hp_max]


func _hp_bar_color(hp: int, hp_max: int) -> Color:
	if hp * 2 > hp_max:
		return HP_HIGH
	if hp > 10 and hp * 2 <= hp_max:
		return HP_MID
	return HP_LOW


func _process(_delta: float) -> void:
	if _o2 == 0.0:
		_pulse_o2_bar()


func _pulse_o2_bar() -> void:
	if _o2_track == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * TAU * 2.0)
	_o2_track.color = Color(0, 0, 0, 0.65).lerp(O2_LOW, pulse)


func _label(text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = MOUSE_FILTER_IGNORE
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_font_size_override("font_size", FONT_SIZE)
	return node


func _set_counts(group: Dictionary, inv: Dictionary, low_ice: bool) -> void:
	var counts: Dictionary = group["counts"]
	for key in counts.keys():
		var lab: Label = counts[key]
		lab.text = str(int(inv.get(key, 0)))
		var color := TEXT
		if key == "ice" and low_ice:
			color = LOW_ICE
		elif key == "food" and int(inv.get("food", 0)) <= Constants.FOOD_WARN:
			color = LOW_ICE
		lab.add_theme_color_override("font_color", color)


func _set_missing(group: Dictionary) -> void:
	var counts: Dictionary = group["counts"]
	for key in counts.keys():
		var lab: Label = counts[key]
		lab.text = MISSING
		lab.add_theme_color_override("font_color", TEXT)


func _player_inventory(snap: SimSnapshot) -> Dictionary:
	return _inventory_from(_player_unit(snap).get("inventory", {}))


func _player_unit(snap: SimSnapshot) -> Dictionary:
	for rec in snap.units:
		if rec.get("kind", -1) == Types.UnitKind.PLAYER:
			return rec
	return {}


func _colony_ice(snap: SimSnapshot) -> int:
	var total := 0
	var saw := false
	if "buildings" in snap:
		var buildings: Variant = snap.get("buildings")
		if buildings != null:
			for rec in buildings:
				if not rec is Dictionary:
					continue
				if rec.get("kind", -1) != Types.BuildingKind.HABITAT:
					continue
				if rec.get("faction", -1) != Types.Faction.PLAYER:
					continue
				if rec.has("hp") and int(rec["hp"]) <= 0:
					continue
				saw = true
				var inv := _inventory_from(rec.get("inventory", {}))
				total += int(inv.get("ice", 0))
	if saw:
		return total
	if "habitat_ice_pool" in snap:
		return int(snap.habitat_ice_pool)
	return 0


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


func _float_field(snap: SimSnapshot, key: String, fallback: float) -> float:
	if key in snap:
		return float(snap.get(key))
	return fallback


func _inventory_from(inv: Variant) -> Dictionary:
	var out := {"scrap": 0, "ice": 0, "ore": 0, "parts": 0, "food": 0}
	if inv is Dictionary:
		out["scrap"] = int(inv.get("scrap", 0))
		out["ice"] = int(inv.get("ice", 0))
		out["ore"] = int(inv.get("ore", 0))
		out["parts"] = int(inv.get("parts", 0))
		out["food"] = int(inv.get("food", 0))
	elif inv is Object:
		for key in out.keys():
			if key in inv:
				out[key] = int(inv.get(key))
	return out
