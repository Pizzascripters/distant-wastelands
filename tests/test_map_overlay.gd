extends RefCounted

const _MAP := 32
const _CENTER := Vector2i(16, 16)


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_stamp_chebyshev_disk(fails)
	_test_undiscovered_cliff_is_fog(fails)
	_test_discovered_crater_color(fails)
	_test_player_habitat_plots_on_fog(fails)
	_test_enemy_hidden_without_radar(fails)
	_test_radar_reveals_enemies(fails)
	_test_enemy_turret_is_1x1(fails)
	_test_radar_does_not_recolor_terrain(fails)
	_test_sim_stamps_and_snapshot_cache(fails)
	_test_map_view_blocks_fire_and_esc_closes(fails)
	return fails


func _test_stamp_chebyshev_disk(fails: PackedStringArray) -> void:
	var world := World.new()
	var gen := world.discovered_generation
	world.stamp_discovered(_CENTER, Constants.MAP_DISCOVER_RADIUS)
	if world.discovered_generation <= gen:
		fails.append("stamp_discovered should bump discovered_generation")
	var edge := Vector2i(_CENTER.x + Constants.MAP_DISCOVER_RADIUS, _CENTER.y)
	var corner := Vector2i(
		_CENTER.x + Constants.MAP_DISCOVER_RADIUS, _CENTER.y + Constants.MAP_DISCOVER_RADIUS
	)
	var outside := Vector2i(_CENTER.x + Constants.MAP_DISCOVER_RADIUS + 1, _CENTER.y)
	if world.discovered[world.index_of(_CENTER.x, _CENTER.y)] != 1:
		fails.append("stamp missed the center tile")
	if world.discovered[world.index_of(edge.x, edge.y)] != 1:
		fails.append("radius 16 edge tile should be discovered")
	if world.discovered[world.index_of(corner.x, corner.y)] != 1:
		fails.append("Chebyshev corner at 16 should be discovered")
	if world.discovered[world.index_of(outside.x, outside.y)] != 0:
		fails.append("tile at Chebyshev 17 should stay undiscovered")
	var again := world.discovered_generation
	world.stamp_discovered(_CENTER, Constants.MAP_DISCOVER_RADIUS)
	if world.discovered_generation != again:
		fails.append("restamping the same disk should not bump generation")


func _test_undiscovered_cliff_is_fog(fails: PackedStringArray) -> void:
	var tiles := _blank_tiles()
	var discovered := PackedByteArray()
	discovered.resize(_MAP * _MAP)
	discovered.fill(0)
	tiles[_idx(8, 8)] = Types.TileTerrain.CLIFF
	var colors := MapOverlay.paint_model(tiles, discovered, _MAP, _MAP)
	if colors[_idx(8, 8)] != MapOverlay.FOG:
		fails.append("undiscovered cliff should be fog")


func _test_discovered_crater_color(fails: PackedStringArray) -> void:
	var tiles := _blank_tiles()
	var discovered := _all_discovered()
	tiles[_idx(9, 9)] = Types.TileTerrain.CRATER
	var colors := MapOverlay.paint_model(tiles, discovered, _MAP, _MAP)
	if colors[_idx(9, 9)] != MapOverlay.TERRAIN_CRATER:
		fails.append("discovered crater should use the crater color key")


func _test_player_habitat_plots_on_fog(fails: PackedStringArray) -> void:
	var tiles := _blank_tiles()
	var discovered := PackedByteArray()
	discovered.resize(_MAP * _MAP)
	discovered.fill(0)
	var habitat := {
		"id": 1,
		"kind": Types.BuildingKind.HABITAT,
		"faction": Types.Faction.PLAYER,
		"hp": Constants.HABITAT_HP,
		"origin_tile": Vector2i(4, 4),
	}
	var colors := MapOverlay.paint_model(tiles, discovered, _MAP, _MAP, [habitat])
	for dy in 2:
		for dx in 2:
			if colors[_idx(4 + dx, 4 + dy)] != MapOverlay.PLAYER_PAD:
				fails.append("player Habitat should plot on undiscovered tiles")
				return
	if colors[_idx(0, 0)] != MapOverlay.FOG:
		fails.append("fog around an undiscovered Habitat should stay blank")


func _test_enemy_hidden_without_radar(fails: PackedStringArray) -> void:
	var tiles := _blank_tiles()
	var discovered := _all_discovered()
	var depot := {
		"id": 2,
		"kind": Types.BuildingKind.DEPOT,
		"faction": Types.Faction.ENEMY,
		"hp": Constants.DEPOT_HP,
		"origin_tile": Vector2i(10, 10),
	}
	var unit := {
		"id": 3,
		"kind": Types.UnitKind.RAIDER,
		"faction": Types.Faction.ENEMY,
		"alive": true,
		"hp": Constants.RAIDER_HP,
		"tile": Vector2i(12, 10),
	}
	var colors := MapOverlay.paint_model(tiles, discovered, _MAP, _MAP, [depot], [unit])
	if colors[_idx(10, 10)] != MapOverlay.TERRAIN_EMPTY:
		fails.append("discovered EMPTY under an enemy pad is not a base mark")
	if colors[_idx(12, 10)] != MapOverlay.TERRAIN_EMPTY:
		fails.append("enemy unit should not plot without Radar")


func _test_radar_reveals_enemies(fails: PackedStringArray) -> void:
	var tiles := _blank_tiles()
	var discovered := _all_discovered()
	var radar := {
		"id": 4,
		"kind": MapOverlay.RADAR_KIND,
		"faction": Types.Faction.PLAYER,
		"hp": 50,
		"origin_tile": Vector2i(0, 0),
	}
	var depot := {
		"id": 5,
		"kind": Types.BuildingKind.DEPOT,
		"faction": Types.Faction.ENEMY,
		"hp": Constants.DEPOT_HP,
		"origin_tile": Vector2i(20, 0),
	}
	var far_depot := {
		"id": 6,
		"kind": Types.BuildingKind.DEPOT,
		"faction": Types.Faction.ENEMY,
		"hp": Constants.DEPOT_HP,
		"origin_tile": Vector2i(30, 0),
	}
	var unit := {
		"id": 7,
		"kind": Types.UnitKind.RAIDER,
		"faction": Types.Faction.ENEMY,
		"alive": true,
		"hp": Constants.RAIDER_HP,
		"tile": Vector2i(18, 0),
	}
	var colors := MapOverlay.paint_model(
		tiles, discovered, _MAP, _MAP, [radar, depot, far_depot], [unit], 22
	)
	for dy in 2:
		for dx in 2:
			if colors[_idx(20 + dx, dy)] != MapOverlay.RADAR_BLIP:
				fails.append("enemy depot in Radar range should plot red")
				return
	if colors[_idx(18, 0)] != MapOverlay.RADAR_BLIP:
		fails.append("enemy unit in Radar range should plot")
	if colors[_idx(30, 0)] != MapOverlay.TERRAIN_EMPTY:
		fails.append("enemy depot outside Radar range should not plot")


func _test_enemy_turret_is_1x1(fails: PackedStringArray) -> void:
	var tiles := _blank_tiles()
	var discovered := _all_discovered()
	var radar := {
		"id": 8,
		"kind": MapOverlay.RADAR_KIND,
		"faction": Types.Faction.PLAYER,
		"hp": 50,
		"origin_tile": Vector2i(0, 0),
	}
	var turret := {
		"id": 9,
		"kind": Types.BuildingKind.TURRET,
		"faction": Types.Faction.ENEMY,
		"hp": Constants.TURRET_HP,
		"origin_tile": Vector2i(8, 2),
	}
	var colors := MapOverlay.paint_model(tiles, discovered, _MAP, _MAP, [radar, turret])
	if colors[_idx(8, 2)] != MapOverlay.RADAR_BLIP:
		fails.append("enemy Turret in range should plot 1x1")
	if colors[_idx(9, 2)] != MapOverlay.TERRAIN_EMPTY or colors[_idx(8, 3)] != MapOverlay.TERRAIN_EMPTY:
		fails.append("enemy Turret should not paint a 2x2")


func _test_radar_does_not_recolor_terrain(fails: PackedStringArray) -> void:
	var tiles := _blank_tiles()
	var discovered := _all_discovered()
	tiles[_idx(6, 6)] = Types.TileTerrain.CRATER
	tiles[_idx(7, 6)] = Types.TileTerrain.CLIFF
	var radar := {
		"id": 10,
		"kind": MapOverlay.RADAR_KIND,
		"faction": Types.Faction.PLAYER,
		"hp": 50,
		"origin_tile": Vector2i(0, 0),
	}
	var colors := MapOverlay.paint_model(tiles, discovered, _MAP, _MAP, [radar])
	if colors[_idx(6, 6)] != MapOverlay.TERRAIN_CRATER:
		fails.append("Radar blips must not change the crater color key")
	if colors[_idx(7, 6)] != MapOverlay.TERRAIN_CLIFF:
		fails.append("Radar blips must not change the cliff color key")


func _test_sim_stamps_and_snapshot_cache(fails: PackedStringArray) -> void:
	var sim := Sim.new()
	sim.setup(Constants.DEFAULT_SEED)
	var spawn := Constants.PLAYER_SPAWN_TILE
	if sim.world.discovered[sim.world.index_of(spawn.x, spawn.y)] != 1:
		fails.append("setup should stamp the spawn disk")
	var outside := Vector2i(spawn.x + Constants.MAP_DISCOVER_RADIUS + 1, spawn.y)
	if sim.world.in_bounds(outside.x, outside.y):
		if sim.world.discovered[sim.world.index_of(outside.x, outside.y)] != 0:
			fails.append("setup stamp should not mark Chebyshev 17")
	var first := sim.snapshot()
	if first.discovered.size() != Constants.MAP_W * Constants.MAP_H:
		fails.append("snapshot.discovered should be MAP_W * MAP_H")
	if first.discovered_generation != sim.world.discovered_generation:
		fails.append("snapshot.discovered_generation should match the world")
	var second := sim.snapshot()
	if second.discovered_generation != first.discovered_generation or second.discovered != first.discovered:
		fails.append("unchanged discovered_generation should reuse the cached discovered buffer")
	var gen := sim.world.discovered_generation
	var player := sim.get_player()
	if player == null:
		fails.append("setup missing player")
		return
	player.pos = sim.world.tile_center(spawn.x + 8, spawn.y)
	sim.tick()
	if sim.world.discovered_generation == gen:
		fails.append("player tile change should stamp discovery")
	var dest := Vector2i(spawn.x + 8, spawn.y)
	if sim.world.discovered[sim.world.index_of(dest.x, dest.y)] != 1:
		fails.append("new player tile should be discovered")


func _test_map_view_blocks_fire_and_esc_closes(fails: PackedStringArray) -> void:
	var script: GDScript = load("res://src/view/game_view.gd")
	if script == null:
		fails.append("failed to load game_view.gd")
		return
	var view: Node = script.new()
	var overlay := MapOverlay.new()
	view._map_overlay = overlay
	overlay.set_open(true)
	if not view._map_open():
		fails.append("open overlay should report map open")
	var cmd := InputCommand.new()
	view._apply_world_click(cmd, true, true, false)
	if cmd.fire or cmd.build_kind >= 0:
		fails.append("map overlay must block fire and confirm-place")
	view._build_kind = Types.BuildingKind.WALL
	view._toggle_map()
	if view._map_open():
		fails.append("M should close an open map")
	overlay.set_open(true)
	view._build_kind = Types.BuildingKind.WALL
	view._set_map_open(true)
	if view._build_kind != -1:
		fails.append("opening the map should cancel build mode")
	view._on_pause_action()
	if view._map_open():
		fails.append("Esc should close the map without pausing")
	if view._is_paused():
		fails.append("Esc on an open map must not pause")
	var snap := SimSnapshot.new()
	snap.buildings = [{
		"id": 1,
		"kind": Types.BuildingKind.DEPOT,
		"faction": Types.Faction.PLAYER,
		"hp": Constants.DEPOT_HP,
		"origin_tile": Vector2i(2, 2),
		"pos": Vector2(2 * Constants.TILE, 2 * Constants.TILE),
	}]
	overlay.set_open(true)
	view._on_cancel_pressed(snap, true, Vector2(80, 80), false)
	if view._map_open():
		fails.append("RMB should close the map")
	overlay.set_open(true)
	view._on_cancel_pressed(snap, false, Vector2.ZERO, false)
	if view._map_open():
		fails.append("Q should close the map")
	overlay.free()
	view.free()


func _blank_tiles() -> PackedByteArray:
	var tiles := PackedByteArray()
	tiles.resize(_MAP * _MAP)
	tiles.fill(Types.TileTerrain.EMPTY)
	return tiles


func _all_discovered() -> PackedByteArray:
	var discovered := PackedByteArray()
	discovered.resize(_MAP * _MAP)
	discovered.fill(1)
	return discovered


func _idx(x: int, y: int) -> int:
	return y * _MAP + x
