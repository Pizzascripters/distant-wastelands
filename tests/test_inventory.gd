extends RefCounted

func run() -> PackedStringArray:
	var fails := PackedStringArray()
	_test_add_remove_clamp(fails)
	_test_leftover_on_overflow(fails)
	_test_empty_remove(fails)
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
