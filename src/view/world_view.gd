class_name WorldView
extends Node2D

const GRID := Color("7A4024")
const GROUND_FILL := Color("8A4B2A")
const ROCK_FILL := Color("3A241C")
const ROCK_OUTLINE := Color("1A100C")
const GROUND_PATH := "res://assets/sprites/tiles/ground.png"
const ROCK_PATH := "res://assets/sprites/tiles/rock.png"

var _tiles: PackedByteArray = PackedByteArray()
var _ground_tex: Texture2D
var _rock_tex: Texture2D


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_ground_tex = _load_tile(GROUND_PATH)
	_rock_tex = _load_tile(ROCK_PATH)


func _load_tile(path: String) -> Texture2D:
	# FileAccess still sees the PNG after a clone; ResourceLoader remaps to
	# .godot/imported/*.ctex, which is missing until the editor imports.
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() >= 8 and bytes[0] == 0x89 and bytes[1] == 0x50:
		var img := Image.new()
		if img.load_png_from_buffer(bytes) == OK:
			return ImageTexture.create_from_image(img)
	return load(path) as Texture2D


func rebuild(snap: SimSnapshot) -> void:
	_tiles = snap.tiles
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
	if _tiles.is_empty():
		return
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
