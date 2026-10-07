extends SceneTree

## Screenshots of the drop system (掉落物策划案): typed points of interest, an
## opened weapon box, material stacks and the beam on notable drops, and the
## pack with stack counts.

var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/loot-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(5)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	await game.start_contract("city")
	game.player.invulnerable = true
	for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
	for post in get_nodes_in_group("guard_posts"): post.queue_free()
	await step(2)
	var spot := game.world_map.nearest_walkable(ContinuousWorldMap.ENTRY_POSITION + Vector3(6, 0, 0))
	game.player.teleport(spot + Vector3.UP * 0.7)
	var kinds := ["weapon_box", "electronics", "construction", "medical"]
	var boxes: Array[LootContainer] = []
	for i in range(kinds.size()):
		var box := LootContainer.new()
		box.game = game
		box.kind = kinds[i]
		game.add_child(box)
		box.global_position = spot + Vector3(-4.5 + i * 3.0, 0, -3.0)
		boxes.append(box)
	await step(8)
	boxes[2].begin_open()
	await step(20)
	await capture("01-points")
	game.rng.seed = 7
	boxes[0].open_now()
	boxes[1].open_now()
	# A notable drop for the beam.
	var special := Loot.new()
	special.game = game
	special.item = SpecialGear.roll("city", 3, game.rng)
	game.add_child(special)
	special.global_position = spot + Vector3(3.0, 0.1, 1.5)
	var d32 := Loot.new()
	d32.game = game
	d32.item = MaterialCatalog.create("提纯源岩", 2)
	game.add_child(d32)
	d32.global_position = spot + Vector3(-3.0, 0.1, 1.5)
	game.player.teleport(spot + Vector3(0, 0.7, 3.5))
	await step(4)
	await capture("02-opened")
	# Pack with stacks.
	game.inventory.try_add(MaterialCatalog.create("代糖", 17))
	game.inventory.try_add(MaterialCatalog.create("碳", 6))
	game.inventory.try_add(MaterialCatalog.create("赤金", 2))
	game.inventory.try_add(MaterialCatalog.create("装置", 3))
	game.inventory.try_add(MaterialCatalog.create("螺栓", 26))
	game.inventory.try_add(MaterialCatalog.create("电线", 9))
	game.inventory.try_add(MaterialCatalog.create("车用蓄电池", 1))
	game.inventory.try_add(MaterialCatalog.create("木板", 12))
	game.inventory.try_add(MaterialCatalog.create("工具套装", 1))
	game.open_modal("inventory")
	game._inventory_panel.open()
	await step(6)
	await capture("03-pack")
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
