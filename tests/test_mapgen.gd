extends RefCounted

func test_seed1_deterministic() -> PackedStringArray:
	var fails := PackedStringArray()
	var a := Mapgen.generate(1)
	var b := Mapgen.generate(1)
	if a.tiles != b.tiles:
		fails.append("seed 1 tile hash differs across two runs (%d vs %d)" % [_tile_hash(a.tiles), _tile_hash(b.tiles)])
	if a.tiles.size() != Constants.MAP_W * Constants.MAP_H:
		fails.append("world tile count is %d, expected %d" % [a.tiles.size(), Constants.MAP_W * Constants.MAP_H])
	return fails


func test_connectivity_seeds() -> PackedStringArray:
	var fails := PackedStringArray()
	for s in [1, 2, 3, 4, 5]:
		var world := Mapgen.generate(s)
		if not Mapgen.validate_connectivity(world):
			fails.append("seed %d failed connectivity assert without extra carving" % s)
	return fails


func test_corridor_empty() -> PackedStringArray:
	var fails := PackedStringArray()
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	for y in range(Constants.CORRIDOR_H_Y0, Constants.CORRIDOR_H_Y1 + 1):
		for x in range(Constants.CORRIDOR_H_X0, Constants.CORRIDOR_H_X1 + 1):
			if Mapgen.is_building_footprint(x, y):
				continue
			if world.get_terrain(x, y) != Types.TileTerrain.EMPTY:
				fails.append("L-corridor H tile (%d,%d) is not EMPTY" % [x, y])
				return fails
	for y in range(Constants.CORRIDOR_V_Y0, Constants.CORRIDOR_V_Y1 + 1):
		for x in range(Constants.CORRIDOR_V_X0, Constants.CORRIDOR_V_X1 + 1):
			if Mapgen.is_building_footprint(x, y):
				continue
			if world.get_terrain(x, y) != Types.TileTerrain.EMPTY:
				fails.append("L-corridor V tile (%d,%d) is not EMPTY" % [x, y])
				return fails
	return fails


func test_camps_reserved() -> PackedStringArray:
	var fails := PackedStringArray()
	var world := Mapgen.generate(Constants.DEFAULT_SEED)
	_assert_rect_empty_of_rocks(fails, world, Constants.PLAYER_CAMP_RECT, "player camp")
	_assert_rect_empty_of_rocks(fails, world, Constants.ENEMY_CAMP_RECT, "enemy camp")
	if not Constants.PLAYER_CAMP_RECT.has_point(Constants.PLAYER_SPAWN_TILE):
		fails.append("player spawn is outside PLAYER_CAMP_RECT")
	if not Constants.ENEMY_CAMP_RECT.has_point(Constants.ENEMY_DEPOT_TILE):
		fails.append("enemy depot is outside ENEMY_CAMP_RECT")
	if not Constants.PLAYER_CAMP_RECT.has_point(Constants.PLAYER_HABITAT_TILE):
		fails.append("player habitat is outside PLAYER_CAMP_RECT")
	if not Constants.PLAYER_CAMP_RECT.has_point(Constants.PLAYER_DEPOT_TILE):
		fails.append("player depot is outside PLAYER_CAMP_RECT")
	if not Constants.ENEMY_CAMP_RECT.has_point(Constants.ENEMY_HABITAT_TILE):
		fails.append("enemy habitat is outside ENEMY_CAMP_RECT")
	return fails


func _assert_rect_empty_of_rocks(fails: PackedStringArray, world: World, rect: Rect2i, label: String) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if world.get_terrain(x, y) == Types.TileTerrain.ROCK:
				fails.append("%s reserved rect has rock at (%d,%d)" % [label, x, y])
				return


func _tile_hash(tiles: PackedByteArray) -> int:
	var h := 0
	for i in tiles.size():
		h = (h * 31 + int(tiles[i])) & 0x7fffffff
	return h
