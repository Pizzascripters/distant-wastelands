class_name Unit
extends Entity

var kind: int = Types.UnitKind.PLAYER
var vel: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.RIGHT
var inventory: Inventory = Inventory.new()
var weapon_cooldown: float = 0.0
var alive: bool = true
var respawn_timer: float = 0.0
var ai_state: int = Types.RaiderState.SPAWNED
var ai_state_time: float = 0.0
var path: Array[Vector2i] = []
var path_recalc_in: float = 0.0
var interact_progress: float = 0.0
var chase_timer: float = 0.0
var stuck_timer: float = 0.0
var stuck_last_pos: Vector2 = Vector2.ZERO
var siege_target_id: int = 0


static func inventory_for(unit_kind: int) -> Inventory:
	match unit_kind:
		Types.UnitKind.PLAYER:
			return Inventory.new(Constants.PLAYER_CARRY_SCRAP, Constants.PLAYER_CARRY_ICE)
		Types.UnitKind.RAIDER:
			return Inventory.new(Constants.RAIDER_CARRY_SCRAP, Constants.RAIDER_CARRY_ICE)
		_:
			return Inventory.new(0, 0)
