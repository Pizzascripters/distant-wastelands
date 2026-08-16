class_name DebugOverlay
extends Control

const TEXT := Color("F2EDE6")
const PANEL := Color(0, 0, 0, 0.65)
const FONT_SIZE := 16
const MISSING := "—"

var _label: Label
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
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", TEXT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	panel.add_child(_label)
	add_child(panel)


func _refresh() -> void:
	if _label == null:
		return
	var snap := _snap
	_label.text = "\n".join(PackedStringArray([
		"tick  %d" % snap.tick,
		"fps  %d" % Engine.get_frames_per_second(),
		"units  %d" % _record_count(snap, "units"),
		"buildings  %d" % _record_count(snap, "buildings"),
		"deposits  %d" % _record_count(snap, "deposits"),
		"loot  %d" % _record_count(snap, "loot"),
		"projectiles  %d" % _record_count(snap, "projectiles"),
		"outcome  %s" % _outcome_name(snap.outcome),
		"player depot  %s" % _depot_line(snap, Types.Faction.PLAYER),
		"enemy depot  %s" % _depot_line(snap, Types.Faction.ENEMY),
		"next wave  %.2f" % _float_field(snap, "next_wave_at", 0.0),
	]))


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
	return "scrap %d  ice %d" % [inv["scrap"], inv["ice"]]


func _living_depot(snap: SimSnapshot, faction: int) -> Dictionary:
	for rec in _records(snap, "buildings"):
		if not rec is Dictionary:
			continue
		if rec.get("kind", -1) != Types.BuildingKind.DEPOT:
			continue
		if rec.get("faction", -1) != faction:
			continue
		if rec.has("hp") and int(rec["hp"]) <= 0:
			continue
		return rec
	return {}


func _inventory_from(inv: Variant) -> Dictionary:
	var out := {"scrap": 0, "ice": 0}
	if inv is Dictionary:
		out["scrap"] = int(inv.get("scrap", 0))
		out["ice"] = int(inv.get("ice", 0))
	elif inv is Object:
		if "scrap" in inv:
			out["scrap"] = int(inv.scrap)
		if "ice" in inv:
			out["ice"] = int(inv.ice)
	return out


func _float_field(snap: SimSnapshot, key: String, fallback: float) -> float:
	if key in snap:
		return float(snap.get(key))
	return fallback


func _outcome_name(value: int) -> String:
	var keys := Types.Outcome.keys()
	if value >= 0 and value < keys.size():
		return str(keys[value])
	return str(value)
