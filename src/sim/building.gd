class_name Building
extends RefCounted

var id: int = 0
var kind: int = Types.BuildingKind.HABITAT
var faction: int = Types.Faction.PLAYER
var origin_tile: Vector2i = Vector2i.ZERO
var hp: int = 0
var hp_max: int = 0
var inventory: Inventory = Inventory.new()
var fire_cooldown: float = 0.0
var aim: Vector2 = Vector2(1, 0)
