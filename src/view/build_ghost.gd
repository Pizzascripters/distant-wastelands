class_name BuildGhost
extends Node2D

const VALID_FILL := Color("3DDC97")
const INVALID_FILL := Color("C23B22")
const OPACITY := 0.4

var fill: Color = Color(VALID_FILL, OPACITY)
var _span: int = 1


func apply(tile: Vector2i, valid: bool, span: int = 1) -> void:
	position = Vector2(tile) * float(Constants.TILE)
	var base := VALID_FILL if valid else INVALID_FILL
	fill = Color(base, OPACITY)
	_span = maxi(span, 1)
	queue_redraw()


func _draw() -> void:
	var tile := float(Constants.TILE)
	var size := tile * float(_span)
	draw_rect(Rect2(0.0, 0.0, size, size), fill)
