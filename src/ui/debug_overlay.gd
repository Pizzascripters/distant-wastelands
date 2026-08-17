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
		["habitat ice pool  %d" % _habitat_ice_pool(snap), TEXT],
		["enemy habitat  %s" % _habitat_line(snap, Types.Faction.ENEMY), TEXT],
		["depot pool  %s" % _depot_pool_line(snap), TEXT],
		["enemy depot  %s" % _depot_line(snap, Types.Faction.ENEMY), TEXT],
		["carry food  %d" % _carry_food(snap), TEXT],
		["o2  %.2f" % _float_field(snap, "player_o2", Constants.PLAYER_O2_MAX), TEXT],
		["research  %s" % _research_line(snap), TEXT],
		[
			"next raid  %.2f  wave %d"
			% [_float_field(snap, "next_raid_at", 0.0), _int_field(snap, "wave_index", 0)],
			TEXT,
		],
		[
			"active  %d  sleep %d"
			% [
				_int_field(snap, "active_unit_count", 0),
				_int_field(snap, "sleeping_unit_count", 0),
			],
			TEXT,
		],
		["discovered  %s" % _discovered_line(snap), TEXT],
		["player tile  %s" % _player_tile_line(snap), TEXT],
		["density  %d" % _density_at_player(snap), TEXT],
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


func _depot_pool_line(snap: SimSnapshot) -> String:
	var pools := _depot_pools(snap)
	return "scrap %d  ore %d  parts %d" % [pools["scrap"], pools["ore"], pools["parts"]]


func _depot_pools(snap: SimSnapshot) -> Dictionary:
	var totals := {"scrap": 0, "ore": 0, "parts": 0}
	var saw := false
	for rec in _records(snap, "buildings"):
		if not rec is Dictionary:
			continue
		if rec.get("kind", -1) != Types.BuildingKind.DEPOT:
			continue
		if rec.get("faction", -1) != Types.Faction.PLAYER:
			continue
		if rec.has("hp") and int(rec["hp"]) <= 0:
			continue
		saw = true
		var inv := _inventory_from(rec.get("inventory", {}))
		totals["scrap"] += int(inv["scrap"])
		totals["ore"] += int(inv["ore"])
		totals["parts"] += int(inv["parts"])
	if saw:
		return totals
	return {
		"scrap": _int_field(snap, "depot_scrap_pool", 0),
		"ore": _int_field(snap, "depot_ore_pool", 0),
		"parts": _int_field(snap, "depot_parts_pool", 0),
	}


func _habitat_ice_pool(snap: SimSnapshot) -> int:
	var total := 0
	var saw := false
	for rec in _records(snap, "buildings"):
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
		total += int(inv["ice"])
	if saw:
		return total
	return _int_field(snap, "habitat_ice_pool", 0)


func _discovered_line(snap: SimSnapshot) -> String:
	var total := _int_field(snap, "map_w", Constants.MAP_W) * _int_field(snap, "map_h", Constants.MAP_H)
	var found := 0
	if "discovered" in snap:
		var bits: Variant = snap.discovered
		if bits is PackedByteArray:
			for bit in bits:
				if int(bit) != 0:
					found += 1
	return "%d / %d" % [found, total]


func _player_tile_line(snap: SimSnapshot) -> String:
	var tile := _player_tile(snap)
	if tile.x < 0:
		return MISSING
	return "%d, %d" % [tile.x, tile.y]


func _player_tile(snap: SimSnapshot) -> Vector2i:
	for rec in _records(snap, "units"):
		if not rec is Dictionary:
			continue
		if rec.get("kind", -1) != Types.UnitKind.PLAYER:
			continue
		if rec.has("tile"):
			return rec["tile"]
		var pos: Vector2 = rec.get("pos", Vector2(-1.0, -1.0))
		if pos.x < 0.0 or pos.y < 0.0:
			return Vector2i(-1, -1)
		return Vector2i(
			int(floor(pos.x / float(Constants.TILE))),
			int(floor(pos.y / float(Constants.TILE)))
		)
	return Vector2i(-1, -1)


func _density_at_player(snap: SimSnapshot) -> int:
	var tile := _player_tile(snap)
	if tile.x < 0:
		return 0
	var n := Constants.ENEMY_DENSITY_N
	var ox := int(tile.x / n) * n
	var oy := int(tile.y / n) * n
	var count := 0
	for rec in _records(snap, "units"):
		if not rec is Dictionary:
			continue
		if rec.get("faction", -1) != Types.Faction.ENEMY:
			continue
		if rec.has("alive") and not bool(rec["alive"]):
			continue
		if rec.has("hp") and int(rec["hp"]) <= 0:
			continue
		var other := _record_tile(rec)
		if other.x < ox or other.x >= ox + n or other.y < oy or other.y >= oy + n:
			continue
		count += 1
	return count


func _record_tile(rec: Dictionary) -> Vector2i:
	if rec.has("tile"):
		return rec["tile"]
	var pos: Vector2 = rec.get("pos", Vector2.ZERO)
	return Vector2i(
		int(floor(pos.x / float(Constants.TILE))),
		int(floor(pos.y / float(Constants.TILE)))
	)


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
