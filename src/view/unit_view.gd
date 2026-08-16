class_name UnitView
extends Node2D

const PLAYER_FILL := Color("3DDC97")
const OUTLINE := Color("1A100C")
const VISUAL_RADIUS := 10.0
const NOTCH_LEN := 6.0

var aim: Vector2 = Vector2.RIGHT
var fill: Color = PLAYER_FILL


func apply_record(rec: Dictionary) -> void:
	position = rec["pos"]
	aim = rec["aim"]
	visible = rec.get("alive", true)
	queue_redraw()


func _draw() -> void:
	var dir := aim
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	draw_circle(Vector2.ZERO, VISUAL_RADIUS, fill)
	draw_arc(Vector2.ZERO, VISUAL_RADIUS, 0.0, TAU, 28, OUTLINE, 1.5, true)
	var notch_a := dir * (VISUAL_RADIUS - 2.0)
	var notch_b := dir * (VISUAL_RADIUS + NOTCH_LEN)
	draw_line(notch_a, notch_b, OUTLINE, 2.0, true)
