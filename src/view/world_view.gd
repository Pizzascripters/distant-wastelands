class_name WorldView
extends Node2D

const GROUND := Color("8A4B2A")
const GRID := Color("7A4024")
const ROCK_FILL := Color("3A241C")
const ROCK_OUTLINE := Color("1A100C")

var _tiles: PackedByteArray = PackedByteArray()


func rebuild(snap: SimSnapshot) -> void:
	_tiles = snap.tiles
	queue_redraw()


func _draw() -> void:
	var world_w := Constants.MAP_W * Constants.TILE
	var world_h := Constants.MAP_H * Constants.TILE
	draw_rect(Rect2(0, 0, world_w, world_h), GROUND)
	var tile := Constants.TILE
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
			var r := Rect2(x * tile + 1, y * tile + 1, tile - 2, tile - 2)
			draw_rect(r, ROCK_FILL, true)
			draw_rect(r, ROCK_OUTLINE, false, 1.0)
