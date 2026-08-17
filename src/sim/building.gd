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
var food_stock: int = 0
var food_grow_timer: float = 0.0
var ice_debt_timer: float = 0.0


static func inventory_for(kind: int) -> Inventory:
	match kind:
		Types.BuildingKind.HABITAT:
			return Inventory.new(0, Constants.HABITAT_CAP_ICE, 0, 0, 0)
		Types.BuildingKind.DEPOT:
			return Inventory.new(
				Constants.DEPOT_CAP_SCRAP,
				Constants.DEPOT_CAP_ICE,
				Constants.DEPOT_CAP_ORE,
				Constants.DEPOT_CAP_PARTS,
				Constants.DEPOT_CAP_FOOD
			)
		_:
			return Inventory.new()
