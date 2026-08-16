class_name Hud
extends Control

const TEXT := Color("F2EDE6")
const LOW_ICE := Color("E24A3B")
const FONT_SIZE := 16
const MISSING := "—"

var _carry_scrap: Label
var _carry_ice: Label
var _depot_scrap: Label
var _depot_ice: Label
var _habitat_hp: Label
var _depot_hp: Label
var _ice_countdown: Label
var _raid_banner: Label


func _ready() -> void:
	_bind_nodes()
	_style_labels()
	apply_snapshot(SimSnapshot.new())


func apply_snapshot(snap: SimSnapshot) -> void:
	if not _bind_nodes():
		return
	if snap == null:
		snap = SimSnapshot.new()

	var carry := _player_inventory(snap)
	_carry_scrap.text = "Carry scrap  %d" % carry["scrap"]
	_carry_ice.text = "Carry ice  %d" % carry["ice"]

	var depot := _player_building(snap, Types.BuildingKind.DEPOT)
	var habitat := _player_building(snap, Types.BuildingKind.HABITAT)
	var zero_ice := _player_zero_ice_timer(snap)

	if depot.is_empty():
		_depot_scrap.text = "Depot scrap  %s" % MISSING
		_depot_ice.text = "Depot ice  %s" % MISSING
		_depot_hp.text = "Depot HP  0"
		_depot_ice.add_theme_color_override("font_color", TEXT)
		_ice_countdown.visible = false
	else:
		var depot_inv := _inventory_from(depot.get("inventory", {}))
		var depot_ice: int = depot_inv["ice"]
		_depot_scrap.text = "Depot scrap  %d" % depot_inv["scrap"]
		_depot_ice.text = "Depot ice  %d" % depot_ice
		_depot_hp.text = "Depot HP  %d" % int(depot.get("hp", 0))
		var low_ice := depot_ice <= 5 or zero_ice > 0.0
		_depot_ice.add_theme_color_override("font_color", LOW_ICE if low_ice else TEXT)
		var show_countdown := depot_ice == 0 or zero_ice > 0.0
		_ice_countdown.visible = show_countdown
		if show_countdown:
			_ice_countdown.text = str(maxi(ceili(Constants.ZERO_ICE_LIMIT - zero_ice), 0))

	if habitat.is_empty():
		_habitat_hp.text = "Habitat HP  0"
	else:
		_habitat_hp.text = "Habitat HP  %d" % int(habitat.get("hp", 0))

	var banner := _float_field(snap, "banner_timer", 0.0)
	_raid_banner.visible = banner > 0.0
	if banner > 0.0:
		_raid_banner.text = "Raid incoming"


func _bind_nodes() -> bool:
	if _carry_scrap != null:
		return true
	_carry_scrap = get_node_or_null("Panel/VBox/CarryScrap") as Label
	_carry_ice = get_node_or_null("Panel/VBox/CarryIce") as Label
	_depot_scrap = get_node_or_null("Panel/VBox/DepotScrap") as Label
	_depot_ice = get_node_or_null("Panel/VBox/DepotIce") as Label
	_habitat_hp = get_node_or_null("Panel/VBox/HabitatHp") as Label
	_depot_hp = get_node_or_null("Panel/VBox/DepotHp") as Label
	_ice_countdown = get_node_or_null("Panel/VBox/IceCountdown") as Label
	_raid_banner = get_node_or_null("RaidBanner") as Label
	return _carry_scrap != null and _raid_banner != null


func _style_labels() -> void:
	for node in [
		_carry_scrap, _carry_ice, _depot_scrap, _depot_ice,
		_habitat_hp, _depot_hp, _ice_countdown, _raid_banner,
	]:
		if node == null:
			continue
		node.add_theme_color_override("font_color", TEXT)
		node.add_theme_font_size_override("font_size", FONT_SIZE)


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
