class_name WorldView
extends Node2D

const GRID := Color("7A4024")
const GROUND_FILL := Color("8A4B2A")
const ROCK_FILL := Color("3A241C")
const ROCK_OUTLINE := Color("1A100C")
const SCRAP_FILL := Color("C45C26")
const ICE_FILL := Color("A8D8EA")
const SCRAP_W := 20.0
const SCRAP_H := 16.0
const ICE_SIZE := 18.0
const GROUND_PATH := "res://assets/sprites/tiles/ground.png"
const ROCK_PATH := "res://assets/sprites/tiles/rock.png"
const SCRAP_PATH := "res://assets/sprites/placeholder/scrap.png"
const ICE_PATH := "res://assets/sprites/placeholder/ice.png"

var _tiles: PackedByteArray = PackedByteArray()
var _deposits: Array[Dictionary] = []
var _deposit_sig: Dictionary = {}
var _overlay_rev: int = 0
var _terrain_tex: ImageTexture
var _ground_tex: Texture2D
var _rock_tex: Texture2D
var _scrap_tex: Texture2D
var _ice_tex: Texture2D
var _textures_loaded: bool = false


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_load_textures()


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
	_load_textures()
	_tiles = snap.tiles.duplicate()
	_rasterize_terrain()
	_apply_deposits(snap.deposits, true)


func apply_deposits(snap: SimSnapshot) -> void:
	_apply_deposits(snap.deposits, false)


func _apply_deposits(deposits: Array, force: bool) -> void:
	var next := _deposit_signature(deposits)
	if not force and next == _deposit_sig:
		return
	_deposit_sig = next
	_deposits = deposits.duplicate()
	_overlay_rev += 1
	queue_redraw()


func _deposit_signature(deposits: Array) -> Dictionary:
	var sig := {}
	for rec in deposits:
		sig[int(rec.get("id", 0))] = int(rec.get("remaining", 0))
	return sig


func _load_textures() -> void:
	if _textures_loaded:
		return
	_ground_tex = load_png(GROUND_PATH)
	_rock_tex = load_png(ROCK_PATH)
	_scrap_tex = load_png(SCRAP_PATH)
	_ice_tex = load_png(ICE_PATH)
	_textures_loaded = true


func _rasterize_terrain() -> void:
	var tile := Constants.TILE
	var world_w := Constants.MAP_W * tile
	var world_h := Constants.MAP_H * tile
	var img := Image.create(world_w, world_h, false, Image.FORMAT_RGBA8)
	var ground := _tile_image(_ground_tex)
	var rock := _tile_image(_rock_tex)
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			var dest := Vector2i(x * tile, y * tile)
			if ground != null:
				img.blit_rect(ground, Rect2i(0, 0, tile, tile), dest)
			else:
				img.fill_rect(Rect2i(dest.x, dest.y, tile, tile), GROUND_FILL)
	for i in Constants.MAP_W + 1:
		var gx := mini(i * tile, world_w - 1)
		img.fill_rect(Rect2i(gx, 0, 1, world_h), GRID)
	for j in Constants.MAP_H + 1:
		var gy := mini(j * tile, world_h - 1)
		img.fill_rect(Rect2i(0, gy, world_w, 1), GRID)
	if not _tiles.is_empty():
		for y in Constants.MAP_H:
			for x in Constants.MAP_W:
				if _tiles[y * Constants.MAP_W + x] != Types.TileTerrain.ROCK:
					continue
				var dest := Vector2i(x * tile, y * tile)
				if rock != null:
					img.blend_rect(rock, Rect2i(0, 0, tile, tile), dest)
				else:
					img.fill_rect(Rect2i(dest.x + 1, dest.y + 1, tile - 2, tile - 2), ROCK_FILL)
					img.fill_rect(Rect2i(dest.x + 1, dest.y + 1, tile - 2, 1), ROCK_OUTLINE)
					img.fill_rect(Rect2i(dest.x + 1, dest.y + tile - 2, tile - 2, 1), ROCK_OUTLINE)
					img.fill_rect(Rect2i(dest.x + 1, dest.y + 1, 1, tile - 2), ROCK_OUTLINE)
					img.fill_rect(Rect2i(dest.x + tile - 2, dest.y + 1, 1, tile - 2), ROCK_OUTLINE)
	if _terrain_tex == null:
		_terrain_tex = ImageTexture.create_from_image(img)
	else:
		_terrain_tex.update(img)


func _tile_image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var src := tex.get_image()
	if src == null:
		return null
	if src.is_compressed():
		src.decompress()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var tile := Constants.TILE
	if src.get_width() != tile or src.get_height() != tile:
		src.resize(tile, tile, Image.INTERPOLATE_NEAREST)
	return src


func _draw() -> void:
	if _terrain_tex != null:
		draw_texture(_terrain_tex, Vector2.ZERO)
	_draw_deposits()


func _draw_deposits() -> void:
	for rec in _deposits:
		if int(rec.get("remaining", 0)) <= 0:
			continue
		var center: Vector2 = rec.get("pos", Vector2.ZERO)
		if rec.get("kind", Types.ResourceKind.SCRAP) == Types.ResourceKind.ICE:
			_draw_ice(center)
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
