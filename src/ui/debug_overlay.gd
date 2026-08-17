class_name DebugOverlay
extends Control

const TEXT := Color("F2EDE6")
const AMBER := Color("E2C044")
const PANEL := Color(0, 0, 0, 0.65)
const FONT_SIZE := 16
const MISSING := "—"

var _label: Label
var _rows: VBoxContainer
var _snap: SimSnapshot = SimSnapshot.new()


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)


func _ready() -> void:
	_ensure_ui()
	_refresh()


func apply_snapshot(snap: SimSnapshot) -> void:
	if snap == null:
		snap = SimSnapshot.new()
	_snap = snap
	_ensure_ui()
	_refresh()


func _ensure_ui() -> void:
	if _label != null:
		return
	var panel := PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 0.0
	panel.offset_top = 12.0
	panel.offset_right = -12.0
	panel.offset_bottom = 12.0
	panel.grow_horizontal = GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.visible = false
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", TEXT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	panel.add_child(_label)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", 0)
	panel.add_child(_rows)
	add_child(panel)


func _refresh() -> void:
	if _label == null:
		return
	var snap := _snap
	var sim_ms := _float_field(snap, "sim_ms", 0.0)
	var view_ms := _float_field(snap, "view_ms", 0.0)
	var lines: Array = [
		["tick  %d" % snap.tick, TEXT],
		["fps  %d" % Engine.get_frames_per_second(), TEXT],
		[
			"sim_ms  %.2f" % sim_ms,
			AMBER if sim_ms >= Constants.TICK_BUDGET_MSEC else TEXT,
		],
		[
			"view_ms  %.2f" % view_ms,
			AMBER if view_ms >= Constants.VIEW_BUDGET_MSEC else TEXT,
		],
		["units  %d" % _record_count(snap, "units"), TEXT],
		["buildings  %d" % _record_count(snap, "buildings"), TEXT],
		["deposits  %d" % _record_count(snap, "deposits"), TEXT],
		["loot  %d" % _record_count(snap, "loot"), TEXT],
		["projectiles  %d" % _record_count(snap, "projectiles"), TEXT],
		["outcome  %s" % _outcome_name(snap.outcome), TEXT],
		["oxygen_failed  %s" % str(_bool_field(snap, "oxygen_failed", false)), TEXT],
		["player habitat  %s" % _habitat_line(snap, Types.Faction.PLAYER), TEXT],
		["enemy habitat  %s" % _habitat_line(snap, Types.Faction.ENEMY), TEXT],
		["player depot  %s" % _depot_line(snap, Types.Faction.PLAYER), TEXT],
		["enemy depot  %s" % _depot_line(snap, Types.Faction.ENEMY), TEXT],
		["carry food  %d" % _carry_food(snap), TEXT],
		["o2  %.2f" % _float_field(snap, "player_o2", Constants.PLAYER_O2_MAX), TEXT],
		["research  %s" % _research_line(snap), TEXT],
		["next wave  %.2f" % _float_field(snap, "next_raid_at", 0.0), TEXT],
		[
			"completed_this_tick  %d" % _int_field(snap, "completed_this_tick", 0),
			TEXT,
		],
	]
	var plain := PackedStringArray()
	for row in lines:
		plain.append(str(row[0]))
	_label.text = "\n".join(plain)
	_sync_rows(lines)


func _sync_rows(lines: Array) -> void:
	if _rows == null:
		return
	while _rows.get_child_count() < lines.size():
		var line := Label.new()
		line.mouse_filter = MOUSE_FILTER_IGNORE
		line.add_theme_font_size_override("font_size", FONT_SIZE)
		_rows.add_child(line)
	for i in _rows.get_child_count():
		var line := _rows.get_child(i) as Label
		if line == null:
			continue
		if i >= lines.size():
			line.visible = false
			continue
		line.visible = true
		line.text = str(lines[i][0])
		line.add_theme_color_override("font_color", lines[i][1])


func _record_count(snap: SimSnapshot, key: String) -> int:
	return _records(snap, key).size()


func _records(snap: SimSnapshot, key: String) -> Array:
	if key == "units":
		return snap.units
	if key in snap:
		var value: Variant = snap.get(key)
		if value is Array:
			return value
	return []


func _depot_line(snap: SimSnapshot, faction: int) -> String:
	var rec := _living_depot(snap, faction)
	if rec.is_empty():
		return MISSING
	var inv := _inventory_from(rec.get("inventory", {}))
	return "scrap %d  ore %d  parts %d" % [inv["scrap"], inv["ore"], inv["parts"]]


func _habitat_line(snap: SimSnapshot, faction: int) -> String:
	var rec := _living_kind(snap, Types.BuildingKind.HABITAT, faction)
	if rec.is_empty():
		return MISSING
	var inv := _inventory_from(rec.get("inventory", {}))
	return "ice %d" % inv["ice"]


func _living_depot(snap: SimSnapshot, faction: int) -> Dictionary:
	return _living_kind(snap, Types.BuildingKind.DEPOT, faction)


func _living_kind(snap: SimSnapshot, kind: int, faction: int) -> Dictionary:
	for rec in _records(snap, "buildings"):
		if not rec is Dictionary:
			continue
		if rec.get("kind", -1) != kind:
			continue
		if rec.get("faction", -1) != faction:
			continue
		if rec.has("hp") and int(rec["hp"]) <= 0:
			continue
		return rec
	return {}


func _inventory_from(inv: Variant) -> Dictionary:
	var out := {"scrap": 0, "ice": 0, "ore": 0, "parts": 0, "food": 0}
	if inv is Dictionary:
		out["scrap"] = int(inv.get("scrap", 0))
		out["ice"] = int(inv.get("ice", 0))
		out["ore"] = int(inv.get("ore", 0))
		out["parts"] = int(inv.get("parts", 0))
		out["food"] = int(inv.get("food", 0))
	elif inv is Object:
		if "scrap" in inv:
			out["scrap"] = int(inv.scrap)
		if "ice" in inv:
			out["ice"] = int(inv.ice)
		if "ore" in inv:
			out["ore"] = int(inv.ore)
		if "parts" in inv:
			out["parts"] = int(inv.parts)
		if "food" in inv:
			out["food"] = int(inv.food)
	return out


func _carry_food(snap: SimSnapshot) -> int:
	for rec in _records(snap, "units"):
		if not rec is Dictionary:
			continue
		if rec.get("kind", -1) != Types.UnitKind.PLAYER:
			continue
		var inv := _inventory_from(rec.get("inventory", {}))
		return int(inv["food"])
	return 0


func _research_line(snap: SimSnapshot) -> String:
	var selected := -1
	if "research_selected" in snap:
		selected = int(snap.research_selected)
	var progress := _float_field(snap, "research_progress", 0.0)
	var done := 0
	if "techs_done" in snap:
		done = int(snap.techs_done)
	var names := Types.TechKind.keys()
	var name := "none"
	if selected >= 0 and selected < names.size():
		name = str(names[selected])
	return "%s  %.2f  done %d" % [name, progress, done]


func _float_field(snap: SimSnapshot, key: String, fallback: float) -> float:
	if key in snap:
		return float(snap.get(key))
	return fallback


func _int_field(snap: SimSnapshot, key: String, fallback: int) -> int:
	if key in snap:
		return int(snap.get(key))
	return fallback


func _bool_field(snap: SimSnapshot, key: String, fallback: bool) -> bool:
	if key in snap:
		return bool(snap.get(key))
	return fallback


func _outcome_name(value: int) -> String:
	var keys := Types.Outcome.keys()
	if value >= 0 and value < keys.size():
		return str(keys[value])
	return str(value)
