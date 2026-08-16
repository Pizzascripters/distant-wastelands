class_name LootView
extends Node2D

const FILL := Color("E2C044")
const SIZE := 10.0


func apply_record(rec: Dictionary) -> void:
	position = rec["pos"]
	queue_redraw()


func _draw() -> void:
	var half := SIZE * 0.5
	draw_rect(Rect2(-half, -half, SIZE, SIZE), FILL)
