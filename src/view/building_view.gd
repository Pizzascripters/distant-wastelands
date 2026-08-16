class_name BuildingView
extends Node2D

const FILL := Color("4A5560")
const FLASH := Color("F2EDE6")
const STRIPE_PLAYER := Color("3DDC97")
const STRIPE_ENEMY := Color("C23B22")
const OUTLINE := Color("1A100C")
const STRIPE_H := 4.0
const WALL_INSET := 2.0
const WALL_SIZE := 28.0
const BARREL_LEN := 18.0
const BARREL_WIDTH := 4.0

var _kind: int = Types.BuildingKind.WALL
var _faction: int = Types.Faction.PLAYER
var _aim: Vector2 = Vector2.RIGHT
var _hp: int = -1
var _flash_left: float = 0.0


func _ready() -> void:
	set_process(_flash_left > 0.0)


func apply_record(rec: Dictionary) -> void:
	_kind = rec.get("kind", Types.BuildingKind.WALL)
	_faction = rec.get("faction", Types.Faction.PLAYER)
	_aim = rec.get("aim", Vector2.RIGHT)
	# Local origin is the footprint top-left.
	if rec.has("origin_tile"):
		var tile: Vector2i = rec["origin_tile"]
		position = Vector2(tile) * float(Constants.TILE)
	elif rec.has("pos"):
		position = rec["pos"]
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
	var fill := FLASH if _flash_left > 0.0 else FILL
	var stripe := STRIPE_PLAYER if _faction == Types.Faction.PLAYER else STRIPE_ENEMY
	match _kind:
		Types.BuildingKind.HABITAT:
			_draw_habitat(fill, stripe)
		Types.BuildingKind.DEPOT:
			_draw_depot(fill, stripe)
		Types.BuildingKind.TURRET:
			_draw_turret(fill, stripe)
		_:
			_draw_wall(fill, stripe)


func _draw_habitat(fill: Color, stripe: Color) -> void:
	var tile := float(Constants.TILE)
	var size := tile * 2.0
	var box := Rect2(0.0, 0.0, size, size)
	var dome_c := Vector2(size * 0.5, 0.0)
	draw_circle(dome_c, tile, fill)
	draw_rect(box, fill, true)
	draw_rect(Rect2(0.0, 0.0, size, STRIPE_H), stripe, true)
	draw_rect(box, OUTLINE, false, 1.0)
	draw_arc(dome_c, tile, PI, TAU, 24, OUTLINE, 1.0, true)


func _draw_depot(fill: Color, stripe: Color) -> void:
	var tile := float(Constants.TILE)
	var size := tile * 2.0
	var box := Rect2(0.0, 0.0, size, size)
	var inner := Rect2(tile * 0.5, tile * 0.5, tile, tile)
	draw_rect(box, fill, true)
	draw_rect(Rect2(0.0, 0.0, size, STRIPE_H), stripe, true)
	draw_rect(box, OUTLINE, false, 1.0)
	draw_rect(inner, OUTLINE, false, 1.0)


func _draw_wall(fill: Color, stripe: Color) -> void:
	var box := Rect2(WALL_INSET, WALL_INSET, WALL_SIZE, WALL_SIZE)
	draw_rect(box, fill, true)
	draw_rect(Rect2(WALL_INSET, WALL_INSET, WALL_SIZE, STRIPE_H), stripe, true)
	draw_rect(box, OUTLINE, false, 1.0)


func _draw_turret(fill: Color, stripe: Color) -> void:
	var tile := float(Constants.TILE)
	var box := Rect2(0.0, 0.0, tile, tile)
	var center := Vector2(tile, tile) * 0.5
	draw_rect(box, fill, true)
	draw_rect(Rect2(0.0, 0.0, tile, STRIPE_H), stripe, true)
	draw_rect(box, OUTLINE, false, 1.0)
	var dir := _aim
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	draw_line(center, center + dir * BARREL_LEN, OUTLINE, BARREL_WIDTH, true)
