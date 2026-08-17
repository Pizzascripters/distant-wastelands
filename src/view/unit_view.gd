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
const PLAYER_PATH := "res://assets/sprites/placeholder/player.png"
const RAIDER_PATH := "res://assets/sprites/placeholder/raider.png"
const GUARD_PATH := "res://assets/sprites/placeholder/guard.png"

var _kind: int = Types.UnitKind.PLAYER
var _aim: Vector2 = Vector2.RIGHT
var _hp: int = -1
var _flash_left: float = 0.0
var _tex: Texture2D
var _tex_kind: int = -999


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_ensure_texture()
	set_process(_flash_left > 0.0)


func apply_record(rec: Dictionary) -> void:
	position = rec["pos"]
	_aim = rec.get("aim", Vector2.RIGHT)
	_kind = rec.get("kind", Types.UnitKind.PLAYER)
	visible = rec.get("alive", true)
	_ensure_texture()
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
	var flash := _flash_left > 0.0
	if _tex != null:
		# Placeholder PNGs already include the aim notch along +X.
		var sz := Vector2(_tex.get_width(), _tex.get_height())
		var modulate := FLASH if flash else Color.WHITE
		draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
		draw_texture_rect(_tex, Rect2(-sz * 0.5, sz), false, modulate)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var fill := FLASH if flash else _fill_for_kind()
	var outline_w := GUARD_OUTLINE_W if _kind == Types.UnitKind.GUARD else OUTLINE_W
	draw_circle(Vector2.ZERO, VISUAL_RADIUS, fill)
	draw_arc(Vector2.ZERO, VISUAL_RADIUS, 0.0, TAU, 28, OUTLINE, outline_w, true)
	var notch_len := RAIDER_NOTCH_LEN if _kind == Types.UnitKind.RAIDER else NOTCH_LEN
	var notch_a := dir * (VISUAL_RADIUS - 2.0)
	var notch_b := dir * (VISUAL_RADIUS + notch_len)
	draw_line(notch_a, notch_b, OUTLINE, 2.0, true)


func _ensure_texture() -> void:
	if _tex_kind == _kind:
		return
	var path := PLAYER_PATH
	match _kind:
		Types.UnitKind.RAIDER:
			path = RAIDER_PATH
		Types.UnitKind.GUARD:
			path = GUARD_PATH
	_tex = WorldView.load_png(path)
	_tex_kind = _kind


func _fill_for_kind() -> Color:
	match _kind:
		Types.UnitKind.RAIDER:
			return RAIDER_FILL
		Types.UnitKind.GUARD:
			return GUARD_FILL
		_:
			return PLAYER_FILL
