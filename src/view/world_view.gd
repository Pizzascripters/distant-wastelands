class_name WorldView
extends Node2D

const GRID := Color("7A4024")
const GROUND_PATH := "res://assets/sprites/tiles/ground.png"
const ROCK_PATH := "res://assets/sprites/tiles/rock.png"

var _tiles: PackedByteArray = PackedByteArray()
var _ground_tex: Texture2D
var _rock_tex: Texture2D


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_ground_tex = load(GROUND_PATH) as Texture2D
	_rock_tex = load(ROCK_PATH) as Texture2D


func rebuild(snap: SimSnapshot) -> void:
	_tiles = snap.tiles
	queue_redraw()


func _draw() -> void:
	var world_w := Constants.MAP_W * Constants.TILE
	var world_h := Constants.MAP_H * Constants.TILE
	var tile := Constants.TILE
	if _ground_tex == null:
		return
	for y in Constants.MAP_H:
		for x in Constants.MAP_W:
			var cell := Rect2(x * tile, y * tile, tile, tile)
			draw_texture_rect(_ground_tex, cell, false)
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
