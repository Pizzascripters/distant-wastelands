class_name WorldView
extends Node2D

const GRID := Color("7A4024")
const GROUND_FILL := Color("8A4B2A")
const ROCK_FILL := Color("3A241C")
const ROCK_OUTLINE := Color("1A100C")
const SCRAP_FILL := Color("C45C26")
const ICE_FILL := Color("A8D8EA")
const ORE_FILL := Color("5A6A78")
const SCRAP_W := 20.0
const SCRAP_H := 16.0
const ICE_SIZE := 18.0
const ORE_W := 18.0
const ORE_H := 16.0
const GROUND_PATH := "res://assets/sprites/tiles/ground.png"
const ROCK_PATH := "res://assets/sprites/tiles/rock.png"
const SCRAP_PATH := "res://assets/sprites/placeholder/scrap.png"
const ICE_PATH := "res://assets/sprites/placeholder/ice.png"
const ORE_PATH := "res://assets/sprites/placeholder/ore.png"

var _tiles: PackedByteArray = PackedByteArray()
var _deposits: Array[Dictionary] = []
var _ground_tex: Texture2D
var _rock_tex: Texture2D
var _scrap_tex: Texture2D
var _ice_tex: Texture2D
var _ore_tex: Texture2D
var _textures_ready: bool = false
var _terrain_tex: ImageTexture
var _overlay_redraws: int = 0


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_ensure_textures()


static func load_png(path: String) -> Texture2D:
	# FileAccess still sees the PNG after a clone; ResourceLoader remaps to
	# .godot/imported/*.ctex, which is missing until the editor imports.
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50:
		var img := Image.new()
		if img.load_png_from_buffer(bytes) == OK:
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func rebuild(snap: SimSnapshot) -> void:
	_tiles = snap.tiles
	_ensure_textures()
	_rebuild_terrain_cache()
	apply_deposits(snap)
	queue_redraw()


func apply_deposits(snap: SimSnapshot) -> void:
	if _deposits_match(snap.deposits):
		return
	_deposits = snap.deposits.duplicate()
	_overlay_redraws += 1
	queue_redraw()


func _deposits_match(next: Array) -> bool:
	if next.size() != _deposits.size():
		return false
	var prev_remaining := {}
	for rec in _deposits:
		prev_remaining[int(rec.get("id", 0))] = int(rec.get("remaining", 0))
	var seen := {}
	for rec in next:
		var id := int(rec.get("id", 0))
		if seen.has(id) or not prev_remaining.has(id):
			return false
		if int(rec.get("remaining", 0)) != int(prev_remaining[id]):
			return false
		seen[id] = true
	return seen.size() == prev_remaining.size()


func _ensure_textures() -> void:
	if _textures_ready:
		return
	_ground_tex = load_png(GROUND_PATH)
	_rock_tex = load_png(ROCK_PATH)
	_scrap_tex = load_png(SCRAP_PATH)
	_ice_tex = load_png(ICE_PATH)
	_ore_tex = load_png(ORE_PATH)
	_textures_ready = true


func _rebuild_terrain_cache() -> void:
	var tile := Constants.TILE
	var w := Constants.MAP_W * tile
	var h := Constants.MAP_H * tile
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ground_src := _tile_image(_ground_tex, tile)
	if ground_src != null:
		for y in Constants.MAP_H:
			for x in Constants.MAP_W:
				img.blit_rect(ground_src, Rect2i(0, 0, tile, tile), Vector2i(x * tile, y * tile))
	else:
		img.fill(GROUND_FILL)
	for i in Constants.MAP_W + 1:
		img.fill_rect(Rect2i(mini(i * tile, w - 1), 0, 1, h), GRID)
	for j in Constants.MAP_H + 1:
		img.fill_rect(Rect2i(0, mini(j * tile, h - 1), w, 1), GRID)
	if not _tiles.is_empty():
		var rock_src := _tile_image(_rock_tex, tile)
		for y in Constants.MAP_H:
			for x in Constants.MAP_W:
				if _tiles[y * Constants.MAP_W + x] != Types.TileTerrain.ROCK:
					continue
				var origin := Vector2i(x * tile, y * tile)
				if rock_src != null:
					img.blit_rect(rock_src, Rect2i(0, 0, tile, tile), origin)
				else:
					_stamp_primitive_rock(img, origin, tile)
	_terrain_tex = ImageTexture.create_from_image(img)


func _tile_image(tex: Texture2D, tile: int) -> Image:
	var src := _image_from_tex(tex)
	if src == null:
		return null
	if src.get_width() == tile and src.get_height() == tile:
		return src
	var scaled := src.duplicate()
	scaled.resize(tile, tile, Image.INTERPOLATE_NEAREST)
	return scaled


func _image_from_tex(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	return img


func _stamp_primitive_rock(img: Image, origin: Vector2i, tile: int) -> void:
	var r := Rect2i(origin.x + 1, origin.y + 1, tile - 2, tile - 2)
	img.fill_rect(r, ROCK_FILL)
	img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, 1), ROCK_OUTLINE)
	img.fill_rect(Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), ROCK_OUTLINE)
	img.fill_rect(Rect2i(r.position.x, r.position.y, 1, r.size.y), ROCK_OUTLINE)
	img.fill_rect(Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), ROCK_OUTLINE)


func _draw() -> void:
	if _terrain_tex != null:
		draw_texture(_terrain_tex, Vector2.ZERO)
	_draw_deposits()


func _draw_deposits() -> void:
	for rec in _deposits:
		if int(rec.get("remaining", 0)) <= 0:
			continue
		var center: Vector2 = rec.get("pos", Vector2.ZERO)
		var kind: int = rec.get("kind", Types.ResourceKind.SCRAP)
		if kind == Types.ResourceKind.ICE:
			_draw_ice(center)
		elif kind == Types.ResourceKind.ORE:
			_draw_ore(center)
		else:
			_draw_scrap(center)


func _draw_scrap(center: Vector2) -> void:
	if _scrap_tex != null:
		var sz := Vector2(_scrap_tex.get_width(), _scrap_tex.get_height())
		draw_texture(_scrap_tex, center - sz * 0.5)
		return
	var hw := SCRAP_W * 0.5
	var hh := SCRAP_H * 0.5
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(center.x, center.y - hh),
			Vector2(center.x + hw, center.y + hh),
			Vector2(center.x - hw, center.y + hh),
		]),
		SCRAP_FILL
	)


func _draw_ice(center: Vector2) -> void:
	if _ice_tex != null:
		var sz := Vector2(_ice_tex.get_width(), _ice_tex.get_height())
		draw_texture(_ice_tex, center - sz * 0.5)
		return
	var h := ICE_SIZE * 0.5
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(center.x, center.y - h),
			Vector2(center.x + h, center.y),
			Vector2(center.x, center.y + h),
			Vector2(center.x - h, center.y),
		]),
		ICE_FILL
	)


func _draw_ore(center: Vector2) -> void:
	if _ore_tex != null:
		var sz := Vector2(_ore_tex.get_width(), _ore_tex.get_height())
		draw_texture(_ore_tex, center - sz * 0.5)
		return
	var hw := ORE_W * 0.5
	var hh := ORE_H * 0.5
	var top := hw * 0.55
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(center.x - top, center.y - hh),
			Vector2(center.x + top, center.y - hh),
			Vector2(center.x + hw, center.y + hh),
			Vector2(center.x - hw, center.y + hh),
		]),
		ORE_FILL
	)
