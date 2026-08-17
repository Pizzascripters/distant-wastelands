class_name Types

enum Faction { PLAYER, ENEMY }
enum BuildingKind { HABITAT, DEPOT, WALL, TURRET }
enum UnitKind { PLAYER, RAIDER, GUARD }
enum ResourceKind { SCRAP, ICE, ORE, PARTS }
enum TileTerrain { EMPTY, ROCK }
enum Outcome { NONE, PLAYER_WIN, PLAYER_LOSE }
enum OutcomeReason { NONE, HABITAT_DESTROYED, LIFE_SUPPORT }
enum RaiderState {
	SPAWNED,
	PATH_TO_DEPOT,
	LOOT,
	PATH_HOME,
	CHASE,
	PATH_TO_HABITAT,
	ATTACK_HABITAT,
	SIEGE,
	DEAD_DROP,
}
