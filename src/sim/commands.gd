class_name InputCommand
extends RefCounted

var tick: int = 0
var player_id: int = 0
var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.RIGHT
var fire: bool = false
var interact: bool = false
var withdraw: bool = false
var build_kind: int = -1
var build_tile: Vector2i = Vector2i.ZERO


func clone() -> InputCommand:
	var copy := InputCommand.new()
	copy.tick = tick
	copy.player_id = player_id
	copy.move = move
	copy.aim = aim
	copy.fire = fire
	copy.interact = interact
	copy.withdraw = withdraw
	copy.build_kind = build_kind
	copy.build_tile = build_tile
	return copy
