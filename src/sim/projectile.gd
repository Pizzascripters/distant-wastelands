class_name Projectile
extends RefCounted

var id: int = 0
var faction: int = Types.Faction.PLAYER
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var damage: int = 0
var life: float = 0.0
var ignore_gate_id: int = 0
