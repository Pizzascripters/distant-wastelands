class_name UnitView
extends Node2D

const PLAYER_FILL := Color("3DDC97")
const RAIDER_FILL := Color("C23B22")
const GUARD_FILL := Color("8B1E13")
const FLASH := Color("F2EDE6")
const OUTLINE := Color("1A100C")
const VISUAL_RADIUS := 10.0
const NOTCH_LEN := 6.0
const RAIDER_NOTCH_LEN := 4.0
const OUTLINE_W := 1.5
const GUARD_OUTLINE_W := 3.0

var _kind: int = Types.UnitKind.PLAYER
var _aim: Vector2 = Vector2.RIGHT
var _hp: int = -1
var _flash_left: float = 0.0


func _ready() -> void:
	set_process(_flash_left > 0.0)


func apply_record(rec: Dictionary) -> void:
	position = rec["pos"]
	_aim = rec.get("aim", Vector2.RIGHT)
	_kind = rec.get("kind", Types.UnitKind.PLAYER)
	visible = rec.get("alive", true)
	if rec.has("hp"):
		var hp: int = rec["hp"]
		if _hp >= 0 and hp < _hp:
			_flash_left = Constants.HIT_FLASH
			set_process(true)
		_hp = hp
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		set_process(false)
		return
	_flash_left = maxf(0.0, _flash_left - delta)
	if _flash_left <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var dir := _aim
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var fill := FLASH if _flash_left > 0.0 else _fill_for_kind()
	var outline_w := GUARD_OUTLINE_W if _kind == Types.UnitKind.GUARD else OUTLINE_W
	var notch_len := RAIDER_NOTCH_LEN if _kind == Types.UnitKind.RAIDER else NOTCH_LEN
	draw_circle(Vector2.ZERO, VISUAL_RADIUS, fill)
	draw_arc(Vector2.ZERO, VISUAL_RADIUS, 0.0, TAU, 28, OUTLINE, outline_w, true)
	var notch_a := dir * (VISUAL_RADIUS - 2.0)
	var notch_b := dir * (VISUAL_RADIUS + notch_len)
	draw_line(notch_a, notch_b, OUTLINE, 2.0, true)


func _fill_for_kind() -> Color:
	match _kind:
		Types.UnitKind.RAIDER:
			return RAIDER_FILL
		Types.UnitKind.GUARD:
			return GUARD_FILL
		_:
			return PLAYER_FILL

