class_name MapOverlay
extends Control

const FOG := Color("1A120C")
const TERRAIN_EMPTY := Color("8A4B2A")
const TERRAIN_ROCK := Color("3A241C")
const TERRAIN_CLIFF := Color("3A3A42")
const TERRAIN_CRATER := Color("4A3020")
const PLAYER_PAD := Color("3DDC97")
const RADAR_BLIP := Color("C23B22")
const PLAYER_MARK := Color("F2EDE6")
const FRAME := Color(0, 0, 0, 0.80)
const PX_PER_TILE := 2
const RADAR_RANGE_TILES := 48
const RADAR_KIND := 9

var _tex: ImageTexture
var _player_tile := Vector2i(-1, -1)
var _map_w: int = Constants.MAP_W
var _map_h: int = Constants.MAP_H
var _last_sig := ""


func _init() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_NEAREST


func set_open(open: bool) -> void:
	visible = open
	mouse_filter = MOUSE_FILTER_STOP if open else MOUSE_FILTER_IGNORE
	if open:
		queue_redraw()


func is_open() -> bool:
	return visible


func apply_snapshot(snap: SimSnapshot) -> void:
	if snap == null or not visible:
		return
	var sig := _signature(snap)
	if sig != _last_sig:
		_rebuild(snap)
		_last_sig = sig
	_player_tile = _player_tile_of(snap)
	queue_redraw()


func _draw() -> void:
	var size := get_size()
	draw_rect(Rect2(Vector2.ZERO, size), FRAME)
	if _tex == null:
		return
	var tex_size := _tex.get_size()
	var origin := (size - tex_size) * 0.5
	draw_texture(_tex, origin)
	if _player_tile.x < 0 or _player_tile.y < 0:
		return
	if _player_tile.x >= _map_w or _player_tile.y >= _map_h:
		return
	var center := origin + Vector2(
		float(_player_tile.x * PX_PER_TILE) + 1.0,
		float(_player_tile.y * PX_PER_TILE) + 1.0
	)
	draw_line(center + Vector2(-3.0, 0.0), center + Vector2(3.0, 0.0), PLAYER_MARK, 1.0)
	draw_line(center + Vector2(0.0, -3.0), center + Vector2(0.0, 3.0), PLAYER_MARK, 1.0)


static func paint_model(
	tiles: PackedByteArray,
	discovered: PackedByteArray,
	map_w: int,
	map_h: int,
	buildings: Array = [],
	units: Array = [],
	radar_range: int = RADAR_RANGE_TILES
) -> PackedColorArray:
	var colors := PackedColorArray()
	var n := map_w * map_h
	colors.resize(n)
	for i in n:
		if i >= discovered.size() or discovered[i] == 0:
			colors[i] = FOG
			continue
		var terrain := Types.TileTerrain.EMPTY
		if i < tiles.size():
			terrain = tiles[i]
		colors[i] = terrain_color(terrain)
	var radars: Array[Vector2i] = []
	for raw in buildings:
		if not raw is Dictionary:
			continue
		var rec: Dictionary = raw
		if int(rec.get("hp", 0)) <= 0:
			continue
		if int(rec.get("faction", -1)) != Types.Faction.PLAYER:
			continue
		if int(rec.get("kind", -1)) != RADAR_KIND:
			continue
		radars.append(_origin_of(rec))
	for raw in buildings:
		if not raw is Dictionary:
			continue
		var rec: Dictionary = raw
		if int(rec.get("hp", 0)) <= 0:
			continue
		if int(rec.get("faction", -1)) != Types.Faction.PLAYER:
			continue
		if not _is_player_pad(int(rec.get("kind", -1))):
			continue
		_fill_span(colors, map_w, map_h, _origin_of(rec), 2, PLAYER_PAD)
	if radars.is_empty():
		return colors
	for raw in buildings:
		if not raw is Dictionary:
			continue
		var rec: Dictionary = raw
		if int(rec.get("hp", 0)) <= 0:
			continue
		if int(rec.get("faction", -1)) != Types.Faction.ENEMY:
			continue
		var kind := int(rec.get("kind", -1))
		var origin := _origin_of(rec)
		if kind == Types.BuildingKind.HABITAT or kind == Types.BuildingKind.DEPOT:
			if _footprint_in_radar(origin, 2, radars, radar_range):
				_fill_span(colors, map_w, map_h, origin, 2, RADAR_BLIP, discovered)
		elif kind == Types.BuildingKind.TURRET:
			if _tile_in_radar(origin, radars, radar_range):
				_fill_span(colors, map_w, map_h, origin, 1, RADAR_BLIP, discovered)
	for raw in units:
		if not raw is Dictionary:
			continue
		var rec: Dictionary = raw
		if int(rec.get("faction", -1)) != Types.Faction.ENEMY:
			continue
		if rec.has("alive") and not bool(rec["alive"]):
			continue
		if int(rec.get("hp", 1)) <= 0:
			continue
		var tile := _unit_tile(rec)
		if not _tile_in_radar(tile, radars, radar_range):
			continue
		if tile.x < 0 or tile.y < 0 or tile.x >= map_w or tile.y >= map_h:
			continue
		if discovered.size() > 0:
			var di := tile.y * map_w + tile.x
			if di < 0 or di >= discovered.size() or discovered[di] == 0:
				continue
		colors[tile.y * map_w + tile.x] = RADAR_BLIP
	return colors


static func terrain_color(terrain: int) -> Color:
	match terrain:
		Types.TileTerrain.ROCK:
			return TERRAIN_ROCK
		Types.TileTerrain.CLIFF:
			return TERRAIN_CLIFF
		Types.TileTerrain.CRATER:
			return TERRAIN_CRATER
		_:
			return TERRAIN_EMPTY


static func _is_player_pad(kind: int) -> bool:
	return (
		kind == Types.BuildingKind.HABITAT
		or kind == Types.BuildingKind.DEPOT
		or kind == RADAR_KIND
	)


static func _origin_of(rec: Dictionary) -> Vector2i:
	var origin: Variant = rec.get("origin_tile", Vector2i.ZERO)
	if origin is Vector2i:
		return origin
	if origin is Vector2:
		return Vector2i(int((origin as Vector2).x), int((origin as Vector2).y))
	return Vector2i.ZERO


static func _unit_tile(rec: Dictionary) -> Vector2i:
	if rec.has("tile") and rec["tile"] is Vector2i:
		return rec["tile"]
	var pos: Variant = rec.get("pos", Vector2.ZERO)
	if pos is Vector2i:
		return pos
	if pos is Vector2:
		var p := pos as Vector2
		return Vector2i(int(floor(p.x / float(Constants.TILE))), int(floor(p.y / float(Constants.TILE))))
	return Vector2i.ZERO


static func _fill_span(
	colors: PackedColorArray,
	map_w: int,
	map_h: int,
	origin: Vector2i,
	span: int,
	color: Color,
	discovered: PackedByteArray = PackedByteArray()
) -> void:
	var require_discovered := discovered.size() > 0
	for dy in span:
		for dx in span:
			var x: int = origin.x + dx
			var y: int = origin.y + dy
			if x < 0 or y < 0 or x >= map_w or y >= map_h:
				continue
			var i := y * map_w + x
			if require_discovered and (i >= discovered.size() or discovered[i] == 0):
				continue
			colors[i] = color


static func _tile_in_radar(tile: Vector2i, radars: Array[Vector2i], radar_range: int) -> bool:
	for origin in radars:
		for dy in 2:
			for dx in 2:
				var r := origin + Vector2i(dx, dy)
				if maxi(absi(tile.x - r.x), absi(tile.y - r.y)) <= radar_range:
					return true
	return false


static func _footprint_in_radar(
	origin: Vector2i, span: int, radars: Array[Vector2i], radar_range: int
) -> bool:
	for dy in span:
		for dx in span:
			if _tile_in_radar(origin + Vector2i(dx, dy), radars, radar_range):
				return true
	return false


func _rebuild(snap: SimSnapshot) -> void:
	_map_w = snap.map_w if snap.map_w > 0 else Constants.MAP_W
	_map_h = snap.map_h if snap.map_h > 0 else Constants.MAP_H
	var colors := paint_model(
		snap.tiles, snap.discovered, _map_w, _map_h, snap.buildings, snap.units
	)
	var img := Image.create(_map_w * PX_PER_TILE, _map_h * PX_PER_TILE, false, Image.FORMAT_RGBA8)
	img.fill(FOG)
	for y in _map_h:
		for x in _map_w:
			var c := colors[y * _map_w + x]
			if c == FOG:
				continue
			var px := x * PX_PER_TILE
			var py := y * PX_PER_TILE
			img.set_pixel(px, py, c)
			img.set_pixel(px + 1, py, c)
			img.set_pixel(px, py + 1, c)
			img.set_pixel(px + 1, py + 1, c)
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)


func _signature(snap: SimSnapshot) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(str(snap.discovered_generation))
	var has_radar := false
	for rec in snap.buildings:
		if int(rec.get("hp", 0)) <= 0:
			continue
		var kind := int(rec.get("kind", -1))
		var faction := int(rec.get("faction", -1))
		if faction == Types.Faction.PLAYER and _is_player_pad(kind):
			var origin := _origin_of(rec)
			parts.append("p:%d:%d:%d:%d" % [kind, origin.x, origin.y, int(rec.get("id", 0))])
			if kind == RADAR_KIND:
				has_radar = true
	if not has_radar:
		return "|".join(parts)
	for rec in snap.buildings:
		if int(rec.get("hp", 0)) <= 0:
			continue
		if int(rec.get("faction", -1)) != Types.Faction.ENEMY:
			continue
		var kind := int(rec.get("kind", -1))
		if (
			kind != Types.BuildingKind.HABITAT
			and kind != Types.BuildingKind.DEPOT
			and kind != Types.BuildingKind.TURRET
		):
			continue
		var origin := _origin_of(rec)
		parts.append("e:%d:%d:%d:%d" % [kind, origin.x, origin.y, int(rec.get("id", 0))])
	for rec in snap.units:
		if int(rec.get("faction", -1)) != Types.Faction.ENEMY:
			continue
		if rec.has("alive") and not bool(rec["alive"]):
			continue
		var tile := _unit_tile(rec)
		parts.append("u:%d:%d:%d" % [int(rec.get("id", 0)), tile.x, tile.y])
	return "|".join(parts)


func _player_tile_of(snap: SimSnapshot) -> Vector2i:
	for rec in snap.units:
		if int(rec.get("kind", -1)) != Types.UnitKind.PLAYER:
			continue
		return _unit_tile(rec)
	return Vector2i(-1, -1)
