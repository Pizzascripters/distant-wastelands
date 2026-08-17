extends RefCounted

const _CLIFF_START := Vector2i(8, 8)
const _CLIFF_DIR := Vector2i(1, 0)
const _CLIFF_LEN := 4
const _CRATER_CENTER := Vector2i(24, 24)
const _CRATER_R := 2


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_predicates(fails)
	_test_pathfind_skips_features(fails)
	_test_can_place_rejects(fails)
	_test_seeded_stamps(fails)
	return fails


func _test_predicates(fails: PackedStringArray) -> void:
	var world := World.new()
	world.set_terrain(4, 4, Types.TileTerrain.CLIFF)
	world.set_terrain(6, 6, Types.TileTerrain.CRATER)
	if world.is_walkable(4, 4) or world.is_walkable(6, 6):
		fails.append("is_walkable should be false on CLIFF and CRATER")
	if not World.is_solid_terrain(Types.TileTerrain.CLIFF):
		fails.append("is_solid_terrain should be true for CLIFF")
	if not World.is_solid_terrain(Types.TileTerrain.CRATER):
		fails.append("is_solid_terrain should be true for CRATER")
	if not World.is_solid_terrain(Types.TileTerrain.ROCK):
		fails.append("is_solid_terrain should be true for ROCK")
	if World.is_solid_terrain(Types.TileTerrain.EMPTY):
		fails.append("is_solid_terrain should be false for EMPTY")
	var player := _unit(Types.UnitKind.PLAYER)
	var raider := _unit(Types.UnitKind.RAIDER)
	if not world.blocks_movement(4, 4, player) or not world.blocks_movement(4, 4, raider):
		fails.append("blocks_movement should be true on CLIFF for player and raider")
	if not world.blocks_movement(6, 6, player) or not world.blocks_movement(6, 6, raider):
		fails.append("blocks_movement should be true on CRATER for player and raider")


func _test_pathfind_skips_features(fails: PackedStringArray) -> void:
	var world := World.new()
	world.set_terrain(2, 0, Types.TileTerrain.CLIFF)
	world.set_terrain(2, 1, Types.TileTerrain.CRATER)
	var path := Pathfind.find_path(world, Vector2i(0, 0), Vector2i(4, 0))
	if path.is_empty():
		fails.append("A* should path around a one-tile cliff/crater wall")
		return
	for tile in path:
		if world.get_terrain(tile.x, tile.y) == Types.TileTerrain.CLIFF:
			fails.append("A* stepped on a CLIFF at %s" % tile)
			return
		if world.get_terrain(tile.x, tile.y) == Types.TileTerrain.CRATER:
			fails.append("A* stepped on a CRATER at %s" % tile)
			return


func _test_can_place_rejects(fails: PackedStringArray) -> void:
	var world := _world_with_depot()
	world.set_terrain(10, 10, Types.TileTerrain.CLIFF)
	if Rules.can_place(world, null, Types.BuildingKind.WALL, Vector2i(10, 10)):
		fails.append("can_place should reject CLIFF")
	world.set_terrain(10, 10, Types.TileTerrain.CRATER)
	if Rules.can_place(world, null, Types.BuildingKind.WALL, Vector2i(10, 10)):
		fails.append("can_place should reject CRATER")


func _test_seeded_stamps(fails: PackedStringArray) -> void:
	var world := World.new()
	Mapgen.stamp_cliff(world, _CLIFF_START, _CLIFF_DIR, _CLIFF_LEN)
	Mapgen.stamp_crater(world, _CRATER_CENTER, _CRATER_R)
	var cliff_tiles := _expected_cliff_tiles()
	for tile in cliff_tiles:
		if world.get_terrain(tile.x, tile.y) != Types.TileTerrain.CLIFF:
			fails.append("4-tile cliff stamp missed %s" % tile)
			return
	var crater_tiles := _expected_crater_tiles()
	for tile in crater_tiles:
		if world.get_terrain(tile.x, tile.y) != Types.TileTerrain.CRATER:
			fails.append("r=2 crater stamp missed %s" % tile)
			return
	var seen := {}
	for tile in cliff_tiles:
		seen[tile] = true
	for tile in crater_tiles:
		seen[tile] = true
	for y in range(0, 40):
		for x in range(0, 40):
			var t := Vector2i(x, y)
			if seen.has(t):
				continue
			if world.get_terrain(x, y) != Types.TileTerrain.EMPTY:
				fails.append("seeded stamp wrote unexpected terrain at %s" % t)
				return


func _expected_cliff_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var p := _CLIFF_START
	for _i in _CLIFF_LEN:
		tiles.append(p)
		p += _CLIFF_DIR
	return tiles


func _expected_crater_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var r2 := _CRATER_R * _CRATER_R
	for y in range(_CRATER_CENTER.y - _CRATER_R, _CRATER_CENTER.y + _CRATER_R + 1):
		for x in range(_CRATER_CENTER.x - _CRATER_R, _CRATER_CENTER.x + _CRATER_R + 1):
			var dx := x - _CRATER_CENTER.x
			var dy := y - _CRATER_CENTER.y
			if dx * dx + dy * dy <= r2:
				tiles.append(Vector2i(x, y))
	return tiles


func _unit(kind: int) -> Unit:
	var unit := Unit.new()
	unit.kind = kind
	unit.faction = Types.Faction.PLAYER if kind == Types.UnitKind.PLAYER else Types.Faction.ENEMY
	unit.alive = true
	return unit


func _world_with_depot() -> World:
	var world := World.new()
	var depot := Building.new()
	depot.id = world.alloc_id()
	depot.kind = Types.BuildingKind.DEPOT
	depot.faction = Types.Faction.PLAYER
	depot.origin_tile = Vector2i(2, 2)
	depot.hp = Constants.DEPOT_HP
	depot.hp_max = Constants.DEPOT_HP
	depot.inventory = Inventory.new(Constants.DEPOT_CAP_SCRAP, Constants.DEPOT_CAP_ICE)
	depot.inventory.add(Types.ResourceKind.SCRAP, Constants.WALL_COST)
	world.buildings[depot.id] = depot
	world.occupy(depot)
	return world
