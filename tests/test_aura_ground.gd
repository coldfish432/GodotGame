extends SceneTree

## 用户 2026-11-24: 桥上时拉普兰德的三环在桥下. Her shadow and the three-fang ring
## sit on the ground under her: a bridge's deck when she is up on it, the road
## when she is under it.

var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func aura() -> PlayerAura:
	for child in game.player.get_children():
		if child is PlayerAura: return child
	return null

func run() -> void:
	# A floor with a bridge: the contract's first floor is built from seed + 7919.
	ContinuousWorldMap.bridge_chance = 1.0
	var map := ContinuousWorldMap.new()
	root.add_child(map)
	var seed_with := 0
	for i in range(12):
		map.region_id = "mine"
		map.generate((i + 1) * 104729 + 7919, 1)
		if not map.bridges.is_empty():
			seed_with = (i + 1) * 104729
			break
	map.queue_free()
	check("a mine floor with a bridge", seed_with != 0)
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = seed_with
	root.add_child(game)
	await step(8)
	game.choose_operator(Operators.LAPPLAND)
	await game.start_contract("mine")
	await step(6)
	var bridges: Array = game.world_map.bridges
	check("the floor has its bridge", not bridges.is_empty())
	if bridges.is_empty():
		quit(1)
		return
	var bridge: Dictionary = bridges[0]
	var a := aura()
	game.player.invulnerable = false
	for at in [["on the deck", float(bridge.top)], ["on the road under it", float(bridge.base)]]:
		game.player.global_position = Vector3(bridge.centre.x, at[1], bridge.centre.y)
		game.player.velocity = Vector3.ZERO
		a._process(0.016)
		check("%s: the ring is at her feet" % at[0], a.ring.visible and absf(a.ring.global_position.y - (at[1] + 0.055)) < 0.01, a.ring.global_position.y)
		check("%s: the shadow is at her feet" % at[0], absf(a.shadow.global_position.y - (at[1] + 0.045)) < 0.01, a.shadow.global_position.y)
	print("AURA GROUND FAILURES: %d" % failures)
	quit(1 if failures else 0)
