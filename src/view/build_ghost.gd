class_name BuildGhost
extends Node2D

const VALID_FILL := Color("3DDC97")
const INVALID_FILL := Color("C23B22")
const OPACITY := 0.4

var fill: Color = Color(VALID_FILL, OPACITY)


func apply(tile: Vector2i, valid: bool) -> void:
	position = Vector2(tile) * float(Constants.TILE)
	var base := VALID_FILL if valid else INVALID_FILL
	fill = Color(base, OPACITY)
	queue_redraw()


func _draw() -> void:
	var tile := float(Constants.TILE)
	draw_rect(Rect2(0.0, 0.0, tile, tile), fill)
