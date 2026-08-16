class_name ProjectileView
extends Node2D

const PLAYER_FILL := Color("3DDC97")
const ENEMY_FILL := Color("C23B22")
const RADIUS := 2.0

var fill: Color = PLAYER_FILL


func apply_record(rec: Dictionary) -> void:
	position = rec["pos"]
	if rec["faction"] == Types.Faction.PLAYER:
		fill = PLAYER_FILL
	else:
		fill = ENEMY_FILL
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, fill)
