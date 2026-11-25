extends SceneTree
## 物品堆里选箱子（用户 2026-11-24: 多兴趣点时没法选开哪个）: with several boxes
## in reach, E opens the one the pointer is on, else the nearest; only that
## one wears the rim.
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = "") -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if str(detail).is_empty() else "  " + str(detail)))

func aim_at(world: Vector3) -> void:
	game._pointer_position = game.camera.unproject_position(world)
	game._has_pointer_position = true

func rims(boxes: Array) -> Array:
	return boxes.map(func(b): return b._rim_on)

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(3)
	await game.start_contract("mine")
	game.player.invulnerable = true
	await step(3)
	var sample: LootContainer = get_nodes_in_group("loot_containers").filter(func(b): return b.game == game)[0]
	var kind := sample.kind
	game._clear_field()
	await step(3)
	var her := game.world_map.nearest_walkable(ContinuousWorldMap.ENTRY_POSITION)
	game.player.teleport(her)
	await step(2)
	her = game.player.global_position
	# Three boxes round her, all within reach, 2 m apart or more.
	var boxes: Array = []
	for i in range(3):
		var box := LootContainer.new()
		box.game = game
		box.kind = kind
		game.add_child(box)
		var off := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 3.0) * (1.3 + 0.3 * i)
		box.global_position = Vector3(her.x + off.x, game.ground_y(her), her.z + off.z)
		boxes.append(box)
	await step(2)
	check("setup: all three in reach", boxes.all(func(b): return her.distance_to(b.global_position) <= LootContainer.REACH), boxes.map(func(b): return her.distance_to(b.global_position)))

	# Pointer off on empty ground: the nearest is the one.
	aim_at(her + Vector3(30, 0, 30))
	await step(2)
	check("pointer elsewhere: the nearest box is picked", game.pick_box() == boxes[0])
	check("…and only it rims", rims(boxes) == [true, false, false], rims(boxes))

	# Pointer on the far one: that one.
	aim_at(boxes[2].global_position)
	await step(2)
	check("pointer on a box: that box is picked", game.pick_box() == boxes[2])
	check("…and only it rims", rims(boxes) == [false, false, true], rims(boxes))
	game._interact()
	await step(2)
	check("E opens the pointed box", game.looting == boxes[2] and boxes[2].opened and not boxes[0].opened and not boxes[1].opened)
	game.close_modal()
	await step(2)

	# The middle one next.
	aim_at(boxes[1].global_position)
	await step(2)
	game._interact()
	await step(2)
	check("E with the pointer on another opens that one", game.looting == boxes[1] and boxes[1].opened and not boxes[0].opened)
	game.close_modal()
	await step(2)

	# A box out of reach under the pointer is not picked: the nearest in reach is.
	var far := LootContainer.new()
	far.game = game
	far.kind = kind
	game.add_child(far)
	far.global_position = Vector3(her.x + 6.0, game.ground_y(her), her.z)
	aim_at(far.global_position)
	await step(2)
	check("a pointed box out of reach is not picked", game.pick_box() == boxes[0])

	print("BOX PICK RESULT: %d failures" % failures)
	game.queue_free()
	await step(3)
	quit(1 if failures else 0)
