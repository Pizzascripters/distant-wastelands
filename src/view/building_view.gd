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
const HABITAT_PLAYER := "res://assets/sprites/placeholder/habitat_player.png"
const HABITAT_ENEMY := "res://assets/sprites/placeholder/habitat_enemy.png"
const DEPOT_PLAYER := "res://assets/sprites/placeholder/depot_player.png"
const DEPOT_ENEMY := "res://assets/sprites/placeholder/depot_enemy.png"
const WALL_PLAYER := "res://assets/sprites/placeholder/wall_player.png"
const WALL_ENEMY := "res://assets/sprites/placeholder/wall_enemy.png"
const TURRET_PLAYER := "res://assets/sprites/placeholder/turret_player.png"
const TURRET_ENEMY := "res://assets/sprites/placeholder/turret_enemy.png"
const WORKSHOP_PLAYER := "res://assets/sprites/placeholder/workshop_player.png"
const LAB_PLAYER := "res://assets/sprites/placeholder/lab_player.png"
const MEDBAY_PLAYER := "res://assets/sprites/placeholder/medbay_player.png"
const GATE_PLAYER := "res://assets/sprites/placeholder/gate_player.png"
const CROSS := Color("E24A3B")
const CROSS_LEN := 6.0
const CROSS_W := 2.0

var _kind: int = Types.BuildingKind.WALL
var _faction: int = Types.Faction.PLAYER
var _aim: Vector2 = Vector2.RIGHT
var _hp: int = -1
var _flash_left: float = 0.0
var _tex: Texture2D
var _tex_key: String = ""
var _applied: bool = false
var _redraws: int = 0


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_ensure_texture()
	set_process(_flash_left > 0.0)


func apply_record(rec: Dictionary) -> void:
	var kind: int = rec.get("kind", Types.BuildingKind.WALL)
	var faction: int = rec.get("faction", Types.Faction.PLAYER)
	var aim: Vector2 = rec.get("aim", Vector2.RIGHT)
	var dirty := not _applied
	_applied = true
	if _kind != kind:
		_kind = kind
		dirty = true
	if _faction != faction:
		_faction = faction
		dirty = true
	if _kind == Types.BuildingKind.TURRET and not _aim.is_equal_approx(aim):
		dirty = true
	_aim = aim
	_ensure_texture()
	# Local origin is the footprint top-left.
	var origin := position
	if rec.has("origin_tile"):
		var tile: Vector2i = rec["origin_tile"]
		origin = Vector2(tile) * float(Constants.TILE)
	elif rec.has("pos"):
		origin = rec["pos"]
	if not position.is_equal_approx(origin):
		position = origin
		dirty = true
	if rec.has("hp"):
		var hp: int = rec["hp"]
		if _hp >= 0 and hp < _hp:
			_flash_left = Constants.HIT_FLASH
			set_process(true)
			dirty = true
		_hp = hp
	if dirty:
		_queue_visual_redraw()


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		set_process(false)
		return
	_flash_left = maxf(0.0, _flash_left - delta)
	if _flash_left <= 0.0:
		set_process(false)
	_queue_visual_redraw()


func _queue_visual_redraw() -> void:
	_redraws += 1
	queue_redraw()


func _draw() -> void:
	var flash := _flash_left > 0.0
	if _tex != null:
		var modulate := FLASH if flash else Color.WHITE
		var sz := Vector2(_tex.get_width(), _tex.get_height())
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, sz), false, modulate)
		if _kind == Types.BuildingKind.TURRET:
			_draw_barrel()
		return
	var fill := FLASH if flash else FILL
	var stripe := STRIPE_PLAYER if _faction == Types.Faction.PLAYER else STRIPE_ENEMY
	match _kind:
		Types.BuildingKind.HABITAT:
			_draw_habitat(fill, stripe)
		Types.BuildingKind.DEPOT:
			_draw_depot(fill, stripe)
		Types.BuildingKind.TURRET:
			_draw_turret(fill, stripe)
		Types.BuildingKind.LAB:
			_draw_lab(fill, stripe)
		Types.BuildingKind.WORKSHOP:
			_draw_workshop(fill, stripe)
		Types.BuildingKind.MEDBAY:
			_draw_medbay(fill, stripe)
		Types.BuildingKind.GATE:
			_draw_gate(fill, stripe)
		_:
			_draw_wall(fill, stripe)


func _ensure_texture() -> void:
	var key := "%d:%d" % [_kind, _faction]
	if _tex_key == key:
		return
	var player := _faction == Types.Faction.PLAYER
	var path := ""
	match _kind:
		Types.BuildingKind.HABITAT:
			path = HABITAT_PLAYER if player else HABITAT_ENEMY
		Types.BuildingKind.DEPOT:
			path = DEPOT_PLAYER if player else DEPOT_ENEMY
		Types.BuildingKind.TURRET:
			path = TURRET_PLAYER if player else TURRET_ENEMY
		Types.BuildingKind.WORKSHOP:
			path = WORKSHOP_PLAYER
		Types.BuildingKind.LAB:
			path = LAB_PLAYER
		Types.BuildingKind.MEDBAY:
			path = MEDBAY_PLAYER
		Types.BuildingKind.GATE:
			path = GATE_PLAYER
		_:
			path = WALL_PLAYER if player else WALL_ENEMY
	_tex = WorldView.load_png(path)
	_tex_key = key


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


func _draw_lab(fill: Color, stripe: Color) -> void:
	_draw_depot(fill, stripe)


func _draw_workshop(fill: Color, stripe: Color) -> void:
	_draw_wall(fill, stripe)


func _draw_medbay(fill: Color, stripe: Color) -> void:
	var tile := float(Constants.TILE)
	var box := Rect2(0.0, 0.0, tile, tile)
	draw_rect(box, fill, true)
	draw_rect(Rect2(0.0, 0.0, tile, STRIPE_H), stripe, true)
	draw_rect(box, OUTLINE, false, 1.0)
	var center := Vector2(tile * 0.5, tile * 0.5 + 1.0)
	draw_line(
		Vector2(center.x, center.y - CROSS_LEN),
		Vector2(center.x, center.y + CROSS_LEN),
		CROSS,
		CROSS_W,
		true
	)
	draw_line(
		Vector2(center.x - CROSS_LEN, center.y),
		Vector2(center.x + CROSS_LEN, center.y),
		CROSS,
		CROSS_W,
		true
	)


func _draw_gate(fill: Color, stripe: Color) -> void:
	var left := Rect2(WALL_INSET, WALL_INSET, 8.0, WALL_SIZE)
	var right := Rect2(22.0, WALL_INSET, 8.0, WALL_SIZE)
	var lintel := Rect2(WALL_INSET, WALL_INSET, WALL_SIZE, 10.0)
	draw_rect(left, fill, true)
	draw_rect(right, fill, true)
	draw_rect(lintel, fill, true)
	draw_rect(Rect2(WALL_INSET, WALL_INSET, WALL_SIZE, STRIPE_H), stripe, true)
	draw_rect(Rect2(WALL_INSET, WALL_INSET, WALL_SIZE, WALL_SIZE), OUTLINE, false, 1.0)
	draw_arc(Vector2(16.0, 14.0), 6.0, PI, TAU, 10, OUTLINE, 1.0, true)


func _draw_wall(fill: Color, stripe: Color) -> void:
	var box := Rect2(WALL_INSET, WALL_INSET, WALL_SIZE, WALL_SIZE)
	draw_rect(box, fill, true)
	draw_rect(Rect2(WALL_INSET, WALL_INSET, WALL_SIZE, STRIPE_H), stripe, true)
	draw_rect(box, OUTLINE, false, 1.0)


func _draw_turret(fill: Color, stripe: Color) -> void:
	var tile := float(Constants.TILE)
	var box := Rect2(0.0, 0.0, tile, tile)
	draw_rect(box, fill, true)
	draw_rect(Rect2(0.0, 0.0, tile, STRIPE_H), stripe, true)
	draw_rect(box, OUTLINE, false, 1.0)
	_draw_barrel()


func _draw_barrel() -> void:
	var tile := float(Constants.TILE)
	var center := Vector2(tile, tile) * 0.5
	var dir := _aim
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	draw_line(center, center + dir * BARREL_LEN, OUTLINE, BARREL_WIDTH, true)
