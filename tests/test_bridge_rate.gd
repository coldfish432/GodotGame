extends SceneTree

## 立交桥修订案 v0.1 (用户 2026-11-21: 6成，矿洞和叙拉古也要). A run of floors in
## each region, the chance for each floor taken from how many before it went
## without a bridge (M4, as GameManager does): about six floors in ten come
## out with one, in every region, and no long run without. Also: the chance
## table itself, a boss/compact floor never asking, and a floor whose roll
## asks for none getting no module.

## Daily runs walk fewer floors; DOWNFALL_FULL=1 (run_all.ps1 -Full) the lot.
var FLOORS := 40 if OS.get_environment("DOWNFALL_FULL") == "1" else 14
const REGIONS := ["snow", "city", "mine", "siracusa"]

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	var table: Array = ContinuousWorldMap.BRIDGE_STREAK_CHANCE
	check("the chance rises with each floor without a bridge", table[0] < table[1] and table[1] <= table[2])
	check("a run gone two floors without always asks", is_equal_approx(ContinuousWorldMap.bridge_chance_after(2), 1.0) and is_equal_approx(ContinuousWorldMap.bridge_chance_after(9), 1.0))
	check("the run's count of floors without a bridge is saved with the run", RunSave.GAME_KEYS.has("floors_since_bridge"))
	check("a saved floor knows the map generator it was built by", RunSave.MAP_GEN >= 2)
	var map := ContinuousWorldMap.new()
	root.add_child(map)
	var bridged_all := 0
	var floors_all := 0
	for region in REGIONS:
		map.region_id = region
		var without := 1
		var bridged := 0
		var streak := 0
		var longest := 0
		for i in range(FLOORS):
			ContinuousWorldMap.bridge_chance = ContinuousWorldMap.bridge_chance_after(without)
			map.generate(500009 + i * 7919, i + 1)
			if map.bridges.is_empty():
				without += 1
				streak += 1
				longest = maxi(longest, streak)
			else:
				without = 0
				streak = 0
				bridged += 1
		bridged_all += bridged
		floors_all += FLOORS
		print("  %s: %d/%d floors with a bridge, longest run without %d" % [region, bridged, FLOORS, longest])
		check("%s: at least a third of floors have a bridge (%d/%d)" % [region, bridged, FLOORS], bridged * 3 >= FLOORS)
		check("%s: no run of six floors without one (longest %d)" % [region, longest], longest <= 5)
	var share := float(bridged_all) / float(floors_all)
	print("  all regions: %d/%d = %.2f" % [bridged_all, floors_all, share])
	var band := Vector2(0.5, 0.7) if FLOORS >= 40 else Vector2(0.42, 0.78)
	check("about six floors in ten have a bridge (%.2f in %.2f–%.2f)" % [share, band.x, band.y], share >= band.x and share <= band.y)
	# Boss and compact floors never ask; a roll that asks for none digs nothing.
	ContinuousWorldMap.bridge_chance = 1.0
	map.region_id = "snow"
	map.compact_layout = true
	map.generate(4421, 1)
	check("a compact floor asks for no bridge", not map.bridge_wanted and map.bridges.is_empty())
	map.compact_layout = false
	ContinuousWorldMap.bridge_chance = 0.0
	map.generate(4421, 1)
	check("a floor whose roll asks for none has no crossing", not map.bridge_wanted and map._crossings.is_empty() and map.bridges.is_empty())
	ContinuousWorldMap.bridge_chance = 1.0
	print("BRIDGE RATE RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
