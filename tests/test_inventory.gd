extends RefCounted

func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_add_remove_clamp(fails)
	_test_leftover_on_overflow(fails)
	_test_empty_remove(fails)
	_test_unit_carry_caps(fails)
	_test_four_kinds(fails)
	_test_five_kinds(fails)
	_test_two_arg_rejects_ore(fails)
	_test_four_arg_bags_accept_ore(fails)
	_test_four_arg_rejects_food(fails)
	_test_five_arg_bags_accept_food(fails)
	_test_depot_rejects_food(fails)
	return fails


func _test_add_remove_clamp(fails: PackedStringArray) -> void:
	var inv := Inventory.new(10, 8)
	if inv.cap_scrap != 10 or inv.cap_ice != 8:
		fails.append("constructor caps were %d/%d, expected 10/8" % [inv.cap_scrap, inv.cap_ice])
	if inv.scrap != 0 or inv.ice != 0:
		fails.append("new inventory started at %d scrap / %d ice, expected 0/0" % [inv.scrap, inv.ice])

	var leftover := inv.add(Types.ResourceKind.SCRAP, 4)
	if leftover != 0:
		fails.append("add scrap 4 leftover was %d, expected 0" % leftover)
	if inv.scrap != 4:
		fails.append("after add scrap 4, scrap is %d, expected 4" % inv.scrap)
	if inv.ice != 0:
		fails.append("adding scrap changed ice to %d" % inv.ice)
	if inv.free_space(Types.ResourceKind.SCRAP) != 6:
		fails.append("free_space scrap after +4 is %d, expected 6" % inv.free_space(Types.ResourceKind.SCRAP))
	if not inv.can_add(Types.ResourceKind.SCRAP, 6):
		fails.append("can_add scrap 6 should be true with 6 free")
	if inv.can_add(Types.ResourceKind.SCRAP, 7):
		fails.append("can_add scrap 7 should be false with 6 free")

	leftover = inv.add(Types.ResourceKind.ICE, 3)
	if leftover != 0 or inv.ice != 3:
		fails.append("add ice 3 leftover %d ice %d, expected 0/3" % [leftover, inv.ice])

	var taken := inv.remove(Types.ResourceKind.SCRAP, 2)
	if taken != 2 or inv.scrap != 2:
		fails.append("remove scrap 2 took %d leaving %d, expected 2/2" % [taken, inv.scrap])

	leftover = inv.add(Types.ResourceKind.SCRAP, 20)
	if leftover != 12 or inv.scrap != 10:
		fails.append("overflow add leftover %d scrap %d, expected 12/10" % [leftover, inv.scrap])

	taken = inv.remove(Types.ResourceKind.ICE, 100)
	if taken != 3 or inv.ice != 0:
		fails.append("over-remove ice took %d leaving %d, expected 3/0" % [taken, inv.ice])


func _test_leftover_on_overflow(fails: PackedStringArray) -> void:
	var inv := Inventory.new(5, 5)
	if inv.add(Types.ResourceKind.SCRAP, 5) != 0:
		fails.append("filling scrap to cap should leave 0 leftover")
	var leftover := inv.add(Types.ResourceKind.SCRAP, 3)
	if leftover != 3:
		fails.append("overflow leftover was %d, expected 3" % leftover)
	if inv.scrap != 5:
		fails.append("overflow left scrap at %d, expected 5" % inv.scrap)
	if inv.ice != 0:
		fails.append("scrap overflow changed ice to %d" % inv.ice)
	if inv.can_add(Types.ResourceKind.SCRAP, 1):
		fails.append("can_add scrap 1 should be false when full")
	if inv.free_space(Types.ResourceKind.SCRAP) != 0:
		fails.append("free_space scrap when full is %d, expected 0" % inv.free_space(Types.ResourceKind.SCRAP))


func _test_empty_remove(fails: PackedStringArray) -> void:
	var inv := Inventory.new(10, 10)
	var taken := inv.remove(Types.ResourceKind.SCRAP, 1)
	if taken != 0:
		fails.append("empty remove returned %d, expected 0" % taken)
	if inv.scrap != 0 or inv.ice != 0:
		fails.append("empty remove mutated inventory to %d/%d" % [inv.scrap, inv.ice])
	taken = inv.remove(Types.ResourceKind.ICE, 4)
	if taken != 0:
		fails.append("empty ice remove returned %d, expected 0" % taken)


func _test_unit_carry_caps(fails: PackedStringArray) -> void:
	var player := Unit.inventory_for(Types.UnitKind.PLAYER)
	if player.cap_scrap != Constants.PLAYER_CARRY_SCRAP or player.cap_ice != Constants.PLAYER_CARRY_ICE:
		fails.append(
			"player caps were %d/%d, expected %d/%d"
			% [player.cap_scrap, player.cap_ice, Constants.PLAYER_CARRY_SCRAP, Constants.PLAYER_CARRY_ICE]
		)
	if player.scrap != 0 or player.ice != 0:
		fails.append("player inventory started at %d/%d, expected 0/0" % [player.scrap, player.ice])
	var raider := Unit.inventory_for(Types.UnitKind.RAIDER)
	if raider.cap_scrap != Constants.RAIDER_CARRY_SCRAP or raider.cap_ice != Constants.RAIDER_CARRY_ICE:
		fails.append(
			"raider caps were %d/%d, expected %d/%d"
			% [raider.cap_scrap, raider.cap_ice, Constants.RAIDER_CARRY_SCRAP, Constants.RAIDER_CARRY_ICE]
		)
	var guard := Unit.inventory_for(Types.UnitKind.GUARD)
	if guard.cap_scrap != 0 or guard.cap_ice != 0:
		fails.append("guard caps were %d/%d, expected 0/0" % [guard.cap_scrap, guard.cap_ice])
	if player.cap_ore != Constants.PLAYER_CARRY_ORE or player.cap_parts != Constants.PLAYER_CARRY_PARTS:
		fails.append(
			"player ore/parts caps were %d/%d, expected %d/%d"
			% [player.cap_ore, player.cap_parts, Constants.PLAYER_CARRY_ORE, Constants.PLAYER_CARRY_PARTS]
		)
	if raider.cap_ore != Constants.RAIDER_CARRY_ORE or raider.cap_parts != Constants.RAIDER_CARRY_PARTS:
		fails.append(
			"raider ore/parts caps were %d/%d, expected %d/%d"
			% [raider.cap_ore, raider.cap_parts, Constants.RAIDER_CARRY_ORE, Constants.RAIDER_CARRY_PARTS]
		)
	if guard.cap_ore != 0 or guard.cap_parts != 0:
		fails.append("guard ore/parts caps were %d/%d, expected 0/0" % [guard.cap_ore, guard.cap_parts])
	if player.cap_food != Constants.PLAYER_CARRY_FOOD:
		fails.append("player food cap was %d, expected %d" % [player.cap_food, Constants.PLAYER_CARRY_FOOD])
	if raider.cap_food != Constants.RAIDER_CARRY_FOOD:
		fails.append("raider food cap was %d, expected %d" % [raider.cap_food, Constants.RAIDER_CARRY_FOOD])
	if guard.cap_food != 0:
		fails.append("guard food cap was %d, expected 0" % guard.cap_food)


func _test_four_kinds(fails: PackedStringArray) -> void:
	var inv := Inventory.new(4, 4, 4, 4)
	var leftover := inv.add(Types.ResourceKind.ORE, 3)
	if leftover != 0 or inv.ore != 3:
		fails.append("add ore 3 leftover/ore %d/%d, expected 0/3" % [leftover, inv.ore])
	leftover = inv.add(Types.ResourceKind.PARTS, 2)
	if leftover != 0 or inv.parts != 2:
		fails.append("add parts 2 leftover/parts %d/%d, expected 0/2" % [leftover, inv.parts])
	leftover = inv.add(Types.ResourceKind.ORE, 5)
	if leftover != 4 or inv.ore != 4:
		fails.append("ore overflow leftover %d ore %d, expected 4/4" % [leftover, inv.ore])
	var taken := inv.remove(Types.ResourceKind.PARTS, 1)
	if taken != 1 or inv.parts != 1:
		fails.append("remove parts 1 took %d leaving %d, expected 1/1" % [taken, inv.parts])


func _test_two_arg_rejects_ore(fails: PackedStringArray) -> void:
	var inv := Inventory.new(999, 999)
	if inv.cap_ore != 0 or inv.cap_parts != 0:
		fails.append("two-arg caps ore/parts %d/%d, expected 0/0" % [inv.cap_ore, inv.cap_parts])
	var leftover := inv.add(Types.ResourceKind.ORE, 1)
	if leftover != 1 or inv.ore != 0:
		fails.append("two-arg add ore leftover/ore %d/%d, expected 1/0" % [leftover, inv.ore])
	leftover = inv.add(Types.ResourceKind.PARTS, 1)
	if leftover != 1 or inv.parts != 0:
		fails.append("two-arg add parts leftover/parts %d/%d, expected 1/0" % [leftover, inv.parts])
	if inv.can_add(Types.ResourceKind.ORE, 1):
		fails.append("two-arg can_add ore 1 should be false")


func _test_four_arg_bags_accept_ore(fails: PackedStringArray) -> void:
	var pile := Loot.new()
	if pile.inventory.add(Types.ResourceKind.ORE, 3) != 0 or pile.inventory.ore != 3:
		fails.append("Loot four-arg bag rejected ore")
	var player := Unit.inventory_for(Types.UnitKind.PLAYER)
	if player.add(Types.ResourceKind.ORE, Constants.PLAYER_CARRY_ORE) != 0:
		fails.append("player bag rejected a full ore pack")
	var raider := Unit.inventory_for(Types.UnitKind.RAIDER)
	if raider.add(Types.ResourceKind.PARTS, Constants.RAIDER_CARRY_PARTS) != 0:
		fails.append("raider bag rejected parts")
	var depot := Inventory.new(
		Constants.DEPOT_CAP_SCRAP,
		Constants.DEPOT_CAP_ICE,
		Constants.DEPOT_CAP_ORE,
		Constants.DEPOT_CAP_PARTS
	)
	if depot.add(Types.ResourceKind.ORE, 6) != 0 or depot.ore != 6:
		fails.append("depot four-arg bag rejected ore")


func _test_five_kinds(fails: PackedStringArray) -> void:
	var inv := Inventory.new(4, 4, 4, 4, 4)
	var leftover := inv.add(Types.ResourceKind.FOOD, 3)
	if leftover != 0 or inv.food != 3:
		fails.append("add food 3 leftover/food %d/%d, expected 0/3" % [leftover, inv.food])
	leftover = inv.add(Types.ResourceKind.FOOD, 5)
	if leftover != 4 or inv.food != 4:
		fails.append("food overflow leftover %d food %d, expected 4/4" % [leftover, inv.food])
	var taken := inv.remove(Types.ResourceKind.FOOD, 1)
	if taken != 1 or inv.food != 3:
		fails.append("remove food 1 took %d leaving %d, expected 1/3" % [taken, inv.food])


func _test_four_arg_rejects_food(fails: PackedStringArray) -> void:
	var inv := Inventory.new(999, 999, 999, 999)
	if inv.cap_food != 0:
		fails.append("four-arg food cap is %d, expected 0" % inv.cap_food)
	var leftover := inv.add(Types.ResourceKind.FOOD, 1)
	if leftover != 1 or inv.food != 0:
		fails.append("four-arg add food leftover/food %d/%d, expected 1/0" % [leftover, inv.food])
	if inv.can_add(Types.ResourceKind.FOOD, 1):
		fails.append("four-arg can_add food 1 should be false")


func _test_five_arg_bags_accept_food(fails: PackedStringArray) -> void:
	var pile := Loot.new()
	if pile.inventory.add(Types.ResourceKind.FOOD, 3) != 0 or pile.inventory.food != 3:
		fails.append("Loot five-arg bag rejected food")
	var player := Unit.inventory_for(Types.UnitKind.PLAYER)
	if player.add(Types.ResourceKind.FOOD, Constants.PLAYER_CARRY_FOOD) != 0:
		fails.append("player bag rejected a full food pack")
	var raider := Unit.inventory_for(Types.UnitKind.RAIDER)
	if raider.add(Types.ResourceKind.FOOD, Constants.RAIDER_CARRY_FOOD) != 0:
		fails.append("raider bag rejected food")


func _test_depot_rejects_food(fails: PackedStringArray) -> void:
	if Constants.DEPOT_CAP_FOOD != 0:
		fails.append("DEPOT_CAP_FOOD is %d, expected 0" % Constants.DEPOT_CAP_FOOD)
	var depot := Inventory.new(
		Constants.DEPOT_CAP_SCRAP,
		Constants.DEPOT_CAP_ICE,
		Constants.DEPOT_CAP_ORE,
		Constants.DEPOT_CAP_PARTS,
		Constants.DEPOT_CAP_FOOD
	)
	if depot.cap_food != 0:
		fails.append("depot cap_food is %d, expected 0" % depot.cap_food)
	var leftover := depot.add(Types.ResourceKind.FOOD, 6)
	if leftover != 6 or depot.food != 0:
		fails.append("depot accepted food leftover/food %d/%d" % [leftover, depot.food])
	if depot.can_add(Types.ResourceKind.FOOD, 1):
		fails.append("depot can_add food 1 should be false")
