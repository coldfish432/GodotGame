extends SceneTree
## Screenshots for 精英化与加点 and 装备扩充: the training page at the base, the
## backpack with the 加点 button and a graded item's tooltip, the HUD level
## line, and a few new enemies. Writes evidence/growth-*.png. Not in run_all.
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 10) -> void:
	for i in range(count): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func capture(label: String) -> void:
	await step(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/growth-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	var p := game.progress()
	p.add_exp(3000)
	p.ranks["sundial"] = 3
	p.ranks["frenzy"] = 2
	game.base.records = {"基础作战记录": 12, "初级作战记录": 3, "高级作战记录": 1}
	game.close_modal()
	game.open_training()
	await capture("training-base")
	game.close_modal()
	await game.start_contract("city")
	var stage: Vector3 = game.world_map.try_sample_navigation_position(game.world_map.buff_position, 25.0)
	stage.y = 0.7
	game.player.teleport(stage)
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
	game._clear_field()
	var x := -6.0
	for type in ["greytail", "thrower", "bully", "breacher"]:
		var e := game._spawn_enemy(stage + Vector3(x, 0, -2), EnemyAttacks.is_elite_type(type), false, type)
		e.set_physics_process(false)
		x += 4.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	game.try_collect(LootTables.roll_equipment(Item.Category.WEAPON, "警用链锤", "city", 21, 1, rng))
	game.try_collect(SpecialGear.create("set_inspectors_1", 3, rng))
	await capture("hud")
	game.toggle_panel("inventory")
	await capture("inventory")
	for item in game.inventory.items:
		if item.grade >= 4:
			game._inventory_panel.hover(item, game.inventory, Rect2(600, 200, 40, 40))
			break
	await capture("tooltip-grade")
	for item in game.inventory.items:
		if item.named_kind() == "set":
			game._inventory_panel.hover(item, game.inventory, Rect2(600, 200, 40, 40))
			break
	await capture("tooltip-set")
	game.open_training()
	await capture("training-field")
	quit(0)
