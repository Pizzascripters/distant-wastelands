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
var _ground_tex: Texture2D
var _rock_tex: Texture2D
var _scrap_tex: Texture2D
var _ice_tex: Texture2D


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_ground_tex = load_png(GROUND_PATH)
	_rock_tex = load_png(ROCK_PATH)
	_scrap_tex = load_png(SCRAP_PATH)
	_ice_tex = load_png(ICE_PATH)


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
	apply_deposits(snap)


func apply_deposits(snap: SimSnapshot) -> void:
	_deposits = snap.deposits.duplicate()
	queue_redraw()


func _draw() -> void:
	var world_w := Constants.MAP_W * Constants.TILE
	var world_h := Constants.MAP_H * Constants.TILE
	var tile := Constants.TILE
	if _ground_tex != null:
		for y in Constants.MAP_H:
			for x in Constants.MAP_W:
				draw_texture_rect(_ground_tex, Rect2(x * tile, y * tile, tile, tile), false)
	else:
		draw_rect(Rect2(0, 0, world_w, world_h), GROUND_FILL)
	for i in Constants.MAP_W + 1:
		var x := i * tile
		draw_line(Vector2(x, 0), Vector2(x, world_h), GRID, 1.0)
	for j in Constants.MAP_H + 1:
		var y := j * tile
		draw_line(Vector2(0, y), Vector2(world_w, y), GRID, 1.0)
	if not _tiles.is_empty():
		for y in Constants.MAP_H:
			for x in Constants.MAP_W:
				if _tiles[y * Constants.MAP_W + x] != Types.TileTerrain.ROCK:
					continue
				if _rock_tex != null:
					draw_texture_rect(_rock_tex, Rect2(x * tile, y * tile, tile, tile), false)
				else:
					var r := Rect2(x * tile + 1, y * tile + 1, tile - 2, tile - 2)
					draw_rect(r, ROCK_FILL, true)
					draw_rect(r, ROCK_OUTLINE, false, 1.0)
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
