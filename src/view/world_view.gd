class_name WorldView
extends Node2D

const TERRAIN_CHUNK_TILES := 32
const GRID := Color("7A4024")
const GROUND_FILL := Color("8A4B2A")
const ROCK_FILL := Color("3A241C")
const ROCK_OUTLINE := Color("1A100C")
const CLIFF_FILL := Color("3A3A42")
const CLIFF_HIGHLIGHT := Color("5A5A64")
const CLIFF_OUTLINE := Color("16161C")
const CRATER_FILL := Color("4A3020")
const CRATER_BOWL := Color("2A1810")
const CRATER_RIM := Color("1A100C")
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
const CLIFF_PATH := "res://assets/sprites/tiles/cliff.png"
const CRATER_PATH := "res://assets/sprites/tiles/crater.png"
const SCRAP_PATH := "res://assets/sprites/placeholder/scrap.png"
const ICE_PATH := "res://assets/sprites/placeholder/ice.png"
const ORE_PATH := "res://assets/sprites/placeholder/ore.png"

var _tiles: PackedByteArray = PackedByteArray()
var _deposits: Array[Dictionary] = []
var _ground_tex: Texture2D
var _rock_tex: Texture2D
var _cliff_tex: Texture2D
var _crater_tex: Texture2D
var _scrap_tex: Texture2D
var _ice_tex: Texture2D
var _ore_tex: Texture2D
var _textures_ready: bool = false
var _chunk_tex: Array = []
var _chunk_gen: PackedInt32Array = PackedInt32Array()
var _chunk_rebuilds: PackedInt32Array = PackedInt32Array()
var _tiles_generation: int = -1
var _last_visible: Rect2i = Rect2i()
var _overlay_redraws: int = 0


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	set_process(true)
	_ensure_textures()


func _process(_delta: float) -> void:
	var vis := _visible_chunk_rect()
	if vis != _last_visible:
		_last_visible = vis
		queue_redraw()


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
	_ensure_textures()
	_ensure_chunk_arrays()
	apply_tiles(snap)
	apply_deposits(snap)
	queue_redraw()


func apply_tiles(snap: SimSnapshot) -> void:
	if snap == null:
		return
	_tiles = snap.tiles
	_ensure_chunk_arrays()
	var n := _chunk_count()
	var gens := snap.chunk_generation
	var rebuilt := false
	if gens.size() == n:
		for i in n:
			if gens[i] == _chunk_gen[i]:
				continue
			if _chunk_tex[i] != null or _chunk_has_content(i):
				_rebuild_chunk(i)
				rebuilt = true
			_chunk_gen[i] = gens[i]
	elif snap.tiles_generation != _tiles_generation:
		for i in n:
			if _chunk_tex[i] != null or _chunk_has_content(i):
				_rebuild_chunk(i)
				rebuilt = true
			_chunk_gen[i] = -1
	_tiles_generation = snap.tiles_generation
	if rebuilt:
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
	_cliff_tex = load_png(CLIFF_PATH)
	_crater_tex = load_png(CRATER_PATH)
	_scrap_tex = load_png(SCRAP_PATH)
	_ice_tex = load_png(ICE_PATH)
	_ore_tex = load_png(ORE_PATH)
	_textures_ready = true


func _chunk_n() -> int:
	return int(Constants.MAP_W / TERRAIN_CHUNK_TILES)


func _chunk_count() -> int:
	var n := _chunk_n()
	return n * n


func _ensure_chunk_arrays() -> void:
	var n := _chunk_count()
	if _chunk_tex.size() == n and _chunk_gen.size() == n and _chunk_rebuilds.size() == n:
		return
	_chunk_tex.resize(n)
	_chunk_gen.resize(n)
	_chunk_gen.fill(-1)
	_chunk_rebuilds.resize(n)
	_chunk_rebuilds.fill(0)


func _chunk_has_content(ci: int) -> bool:
	if _tiles.is_empty():
		return false
	var n := _chunk_n()
	var cts := TERRAIN_CHUNK_TILES
	var cx := ci % n
	var cy := int(ci / n)
	var x0 := cx * cts
	var y0 := cy * cts
	for y in range(y0, y0 + cts):
		for x in range(x0, x0 + cts):
			if x >= Constants.MAP_W or y >= Constants.MAP_H:
				continue
			var i := y * Constants.MAP_W + x
			if i >= _tiles.size():
				continue
			if _tiles[i] != Types.TileTerrain.EMPTY:
				return true
	return false


func _rebuild_chunk(ci: int) -> void:
	_ensure_chunk_arrays()
	var n := _chunk_n()
	if ci < 0 or ci >= n * n:
		return
	var cts := TERRAIN_CHUNK_TILES
	var tile := Constants.TILE
	var cx := ci % n
	var cy := int(ci / n)
	var px := cts * tile
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var ground_src := _tile_image(_ground_tex, tile)
	var x0 := cx * cts
	var y0 := cy * cts
	if ground_src != null:
		for y in range(y0, y0 + cts):
			for x in range(x0, x0 + cts):
				img.blit_rect(
					ground_src,
					Rect2i(0, 0, tile, tile),
					Vector2i((x - x0) * tile, (y - y0) * tile)
				)
	else:
		img.fill(GROUND_FILL)
	for i in cts + 1:
		img.fill_rect(Rect2i(mini(i * tile, px - 1), 0, 1, px), GRID)
		img.fill_rect(Rect2i(0, mini(i * tile, px - 1), px, 1), GRID)
	if not _tiles.is_empty():
		var rock_src := _tile_image(_rock_tex, tile)
		var cliff_src := _tile_image(_cliff_tex, tile)
		var crater_src := _tile_image(_crater_tex, tile)
		for y in range(y0, y0 + cts):
			for x in range(x0, x0 + cts):
				var ti := y * Constants.MAP_W + x
				if ti >= _tiles.size():
					continue
				var kind: int = _tiles[ti]
				if kind == Types.TileTerrain.EMPTY:
					continue
				var origin := Vector2i((x - x0) * tile, (y - y0) * tile)
				if kind == Types.TileTerrain.CLIFF:
					if cliff_src != null:
						img.blit_rect(cliff_src, Rect2i(0, 0, tile, tile), origin)
					else:
						_stamp_primitive_cliff(img, origin, tile)
				elif kind == Types.TileTerrain.CRATER:
					if crater_src != null:
						img.blit_rect(crater_src, Rect2i(0, 0, tile, tile), origin)
					else:
						_stamp_primitive_crater(img, origin, tile)
				elif kind == Types.TileTerrain.ROCK:
					if rock_src != null:
						img.blit_rect(rock_src, Rect2i(0, 0, tile, tile), origin)
					else:
						_stamp_primitive_rock(img, origin, tile)
	_chunk_tex[ci] = ImageTexture.create_from_image(img)
	_chunk_rebuilds[ci] += 1


func _visible_chunk_rect() -> Rect2i:
	var n := _chunk_n()
	var all := Rect2i(0, 0, n, n)
	if not is_inside_tree():
		return all
	var vp := get_viewport()
	if vp == null:
		return all
	var xf := get_canvas_transform()
	var inv := xf.affine_inverse()
	var vr := vp.get_visible_rect()
	var corners: Array[Vector2] = [
		inv * vr.position,
		inv * Vector2(vr.end.x, vr.position.y),
		inv * vr.end,
		inv * Vector2(vr.position.x, vr.end.y),
	]
	var min_x := corners[0].x
	var min_y := corners[0].y
	var max_x := corners[0].x
	var max_y := corners[0].y
	for c in corners:
		min_x = minf(min_x, c.x)
		min_y = minf(min_y, c.y)
		max_x = maxf(max_x, c.x)
		max_y = maxf(max_y, c.y)
	var chunk_px := float(TERRAIN_CHUNK_TILES * Constants.TILE)
	var x0 := clampi(int(floor(min_x / chunk_px)) - 1, 0, n - 1)
	var y0 := clampi(int(floor(min_y / chunk_px)) - 1, 0, n - 1)
	var x1 := clampi(int(floor(max_x / chunk_px)) + 1, 0, n - 1)
	var y1 := clampi(int(floor(max_y / chunk_px)) + 1, 0, n - 1)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _ensure_visible_chunks(vis: Rect2i) -> void:
	var n := _chunk_n()
	var gens_ok := _chunk_gen.size() == n * n
	for cy in range(vis.position.y, vis.end.y):
		for cx in range(vis.position.x, vis.end.x):
			var ci := cy * n + cx
			if ci < 0 or ci >= _chunk_tex.size():
				continue
			if _chunk_tex[ci] == null:
				_rebuild_chunk(ci)
				if gens_ok:
					_chunk_gen[ci] = _tiles_generation if _chunk_gen[ci] < 0 else _chunk_gen[ci]


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


func _stamp_primitive_cliff(img: Image, origin: Vector2i, tile: int) -> void:
	var ledge := Rect2i(origin.x + 2, origin.y + 8, tile - 4, tile - 14)
	img.fill_rect(ledge, CLIFF_FILL)
	img.fill_rect(Rect2i(ledge.position.x, ledge.position.y, ledge.size.x, 4), CLIFF_HIGHLIGHT)
	img.fill_rect(Rect2i(ledge.position.x, ledge.position.y, ledge.size.x, 1), CLIFF_OUTLINE)
	img.fill_rect(Rect2i(ledge.position.x, ledge.end.y - 1, ledge.size.x, 1), CLIFF_OUTLINE)
	img.fill_rect(Rect2i(ledge.position.x, ledge.position.y, 1, ledge.size.y), CLIFF_OUTLINE)
	img.fill_rect(Rect2i(ledge.end.x - 1, ledge.position.y, 1, ledge.size.y), CLIFF_OUTLINE)


func _stamp_primitive_crater(img: Image, origin: Vector2i, tile: int) -> void:
	var cx := origin.x + tile / 2
	var cy := origin.y + tile / 2
	var outer := tile / 2 - 2
	var inner := maxi(outer - 4, 3)
	_fill_disk(img, cx, cy, outer, CRATER_FILL)
	_fill_disk(img, cx, cy, inner, CRATER_BOWL)
	_stroke_disk(img, cx, cy, outer, CRATER_RIM)


func _fill_disk(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, color)


func _stroke_disk(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	var inner2 := maxi(radius - 1, 0) * maxi(radius - 1, 0)
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			var d2 := (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if d2 <= r2 and d2 > inner2:
				img.set_pixel(x, y, color)


func _draw() -> void:
	_ensure_chunk_arrays()
	var vis := _visible_chunk_rect()
	_last_visible = vis
	_ensure_visible_chunks(vis)
	var n := _chunk_n()
	var chunk_px := float(TERRAIN_CHUNK_TILES * Constants.TILE)
	for cy in range(vis.position.y, vis.end.y):
		for cx in range(vis.position.x, vis.end.x):
			var ci := cy * n + cx
			if ci < 0 or ci >= _chunk_tex.size():
				continue
			var tex: ImageTexture = _chunk_tex[ci]
			if tex == null:
				continue
			draw_texture(tex, Vector2(float(cx) * chunk_px, float(cy) * chunk_px))
	_draw_deposits(vis)


func _deposit_chunk(rec: Dictionary) -> Vector2i:
	if rec.has("tile"):
		var tile: Vector2i = rec["tile"]
		return Vector2i(
			int(tile.x / TERRAIN_CHUNK_TILES),
			int(tile.y / TERRAIN_CHUNK_TILES)
		)
	var pos: Vector2 = rec.get("pos", Vector2.ZERO)
	var t := Constants.TILE
	return Vector2i(
		int(floor(pos.x / float(t)) / TERRAIN_CHUNK_TILES),
		int(floor(pos.y / float(t)) / TERRAIN_CHUNK_TILES)
	)


func _draw_deposits(vis: Rect2i = Rect2i()) -> void:
	if vis.size == Vector2i.ZERO:
		vis = _visible_chunk_rect()
	for rec in _deposits:
		if int(rec.get("remaining", 0)) <= 0:
			continue
		if not vis.has_point(_deposit_chunk(rec)):
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
