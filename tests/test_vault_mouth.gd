extends SceneTree

## 密室 mouth (用户 2026-11-22 试玩: 密室入口像是有空气墙，入口只有一侧边上可以通行).
## The mouth (E, tell, glow) is where the vault's lane leaves the room it
## starts from; a pillar in that room (a fenced yard in Lungmen) had passed for
## it, so E stood by the pillar and the way in was metres on. On a run of
## floors with a vault, in every region: the rock just past the mouth is the
## vault's own (floor once carved), and once open she walks straight through
## its middle, half the lane's width or more on the navmesh and clear of
## every collider.

var SEEDS := 5 if OS.get_environment("DOWNFALL_FULL") == "1" else 3
const REGIONS := ["city", "mine", "snow", "siracusa"]

var failures := 0
var game: GameManager

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func step(count: int = 4) -> void:
	for i in range(count): await process_frame

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	root.add_child(game)
	await step()
	var vaults := 0
	var own_rock := 0
	var through := 0
	for region in REGIONS:
		for i in range(SEEDS):
			game.world_map.force_vault = 1
			game.fixed_map_seed = 31337 + i * 7717
			await game.start_contract(region)
			await step()
			var map := game.world_map
			if not map.has_vault:
				game.settle(true)
				await step(3)
				continue
			vaults += 1
			var mouth: Vector2 = map.vault_mouth
			var inward: Vector2 = map.vault_inward
			var across := inward.orthogonal()
			# Sealed: rock just past the mouth, floor once the vault is carved.
			var past: Vector2 = mouth + inward * 0.6
			var sealed_rock: bool = map._surface.distance_near(past) < 0.0
			map.vault_seal.open()
			await step(6)
			var opened_floor: bool = map._surface.distance_near(past) >= 0.0
			if sealed_rock and opened_floor: own_rock += 1
			# Open: cross-sections a metre and 2.5 m in; the walkable run through
			# the lane's middle at least half its width (a warped lane may graze
			# the rock at one side; the pillar stood in the middle).
			var nav: RID = map._generated_root.get_navigation_map()
			var space := map.get_world_3d().direct_space_state
			var params := PhysicsShapeQueryParameters3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = 0.3
			params.shape = sphere
			var half: float = map.vault_half_width - 0.8
			var stuck := []
			for depth in [1.0, 2.5]:
				var free := {}
				for k in range(-int(half / 0.25), int(half / 0.25) + 1):
					var p: Vector2 = mouth + inward * depth + across * (k * 0.25)
					var q := Vector3(p.x, map.ground_height(p), p.y)
					var c := NavigationServer3D.map_get_closest_point(nav, q)
					params.transform = Transform3D(Basis(), q + Vector3.UP * 0.9)
					free[k] = Vector2(c.x - q.x, c.z - q.z).length() <= 0.25 and space.intersect_shape(params, 1).is_empty()
				var run := 0
				if free[0]:
					var lo := 0
					while free.get(lo - 1, false): lo -= 1
					var hi := 0
					while free.get(hi + 1, false): hi += 1
					run = hi - lo
				if run * 0.25 < half: stuck.append("%.2f m walkable through the middle at %.1f m in (lane half width %.2f)" % [run * 0.25, depth, half])
			if stuck.is_empty(): through += 1
			print("%s %d mouth %s inward %s: sealed rock %s, floor once open %s, blocked %s" % [region, game.fixed_map_seed, str(mouth.snapped(Vector2(0.1, 0.1))), str(inward.snapped(Vector2(0.01, 0.01))), sealed_rock, opened_floor, str(stuck)])
			game.settle(true)
			await step(3)
	check("vaults built (%d)" % vaults, vaults >= REGIONS.size())
	check("each mouth is at the vault's own rock, not a pillar's (%d/%d)" % [own_rock, vaults], own_rock == vaults)
	check("once open, she walks through the middle of the lane, half its width or more (%d/%d)" % [through, vaults], through == vaults)
	print("failures %d" % failures)
	game.queue_free()
	await step()
	quit(1 if failures > 0 else 0)
