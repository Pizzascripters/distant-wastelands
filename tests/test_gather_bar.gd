extends RefCounted


func run() -> PackedStringArray:
	var fails := PackedStringArray()
	var bar := GatherBar.new()
	if bar.visible:
		fails.append("gather bar should be hidden by default")

	var empty := SimSnapshot.new()
	bar.apply_snapshot(empty)
	if bar.visible or bar.fill_ratio() != 0.0:
		fails.append("empty snapshot should hide the gather bar")

	var deposit_id := 9
	var snap := SimSnapshot.new()
	snap.gather_deposit_id = deposit_id
	snap.gather_progress = Constants.GATHER_CHANNEL * 0.5
	snap.deposits = [{
		"id": deposit_id,
		"kind": Types.ResourceKind.SCRAP,
		"pos": Vector2(80, 96),
		"remaining": 3,
	}]
	bar.apply_snapshot(snap)
	if not bar.visible:
		fails.append("active gather should show the bar")
	if not is_equal_approx(bar.fill_ratio(), 0.5):
		fails.append("fill_ratio is %s, expected 0.5" % str(bar.fill_ratio()))
	if bar.position != Vector2(80, 96):
		fails.append("bar pos is %s, expected (80, 96)" % str(bar.position))

	snap.gather_progress = 0.0
	bar.apply_snapshot(snap)
	if bar.visible:
		fails.append("zero progress should hide the bar")

	bar.free()
	return fails
