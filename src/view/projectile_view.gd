class_name ProjectileView
extends Node2D

const PLAYER_FILL := Color("3DDC97")
const ENEMY_FILL := Color("C23B22")
const RADIUS := 2.0
const PLAYER_PATH := "res://assets/sprites/placeholder/projectile_player.png"
const ENEMY_PATH := "res://assets/sprites/placeholder/projectile_enemy.png"

var fill: Color = PLAYER_FILL
var _faction: int = Types.Faction.PLAYER
var _tex: Texture2D
var _tex_faction: int = -999


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_ensure_texture()


func apply_record(rec: Dictionary) -> void:
	position = rec["pos"]
	_faction = rec["faction"]
	if _faction == Types.Faction.PLAYER:
		fill = PLAYER_FILL
	else:
		fill = ENEMY_FILL
	_ensure_texture()
	queue_redraw()


func _draw() -> void:
	if _tex != null:
		var sz := Vector2(_tex.get_width(), _tex.get_height())
		draw_texture(_tex, -sz * 0.5)
		return
	draw_circle(Vector2.ZERO, RADIUS, fill)


func _ensure_texture() -> void:
	if _tex_faction == _faction:
		return
	var path := PLAYER_PATH if _faction == Types.Faction.PLAYER else ENEMY_PATH
	_tex = WorldView.load_png(path)
	_tex_faction = _faction
