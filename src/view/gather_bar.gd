class_name GatherBar
extends Node2D

const TRACK := Color(0, 0, 0, 0.65)
const FILL := Color("F2EDE6")
const BAR_W := 20.0
const BAR_H := 3.0
const OFFSET_Y := -14.0

var _fill: float = 0.0


func _init() -> void:
	z_index = 8
	visible = false


func apply_snapshot(snap: SimSnapshot) -> void:
	_fill = 0.0
	visible = false
	if snap == null or snap.gather_deposit_id <= 0 or snap.gather_progress <= 0.0:
		queue_redraw()
		return
	var pos := _deposit_pos(snap, snap.gather_deposit_id)
	if pos.x < 0.0:
		queue_redraw()
		return
	position = pos
	_fill = clampf(snap.gather_progress / Constants.GATHER_CHANNEL, 0.0, 1.0)
	visible = _fill > 0.0
	queue_redraw()


func fill_ratio() -> float:
	return _fill


func _deposit_pos(snap: SimSnapshot, deposit_id: int) -> Vector2:
	for rec in snap.deposits:
		if int(rec.get("id", 0)) != deposit_id:
			continue
		if int(rec.get("remaining", 0)) <= 0:
			return Vector2(-1, -1)
		return rec.get("pos", Vector2(-1, -1))
	return Vector2(-1, -1)


func _draw() -> void:
	if not visible or _fill <= 0.0:
		return
	var origin := Vector2(-BAR_W * 0.5, OFFSET_Y)
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), TRACK)
	if _fill > 0.0:
		draw_rect(Rect2(origin, Vector2(BAR_W * _fill, BAR_H)), FILL)
