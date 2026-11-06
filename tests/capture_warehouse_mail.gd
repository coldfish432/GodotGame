extends SceneTree
## Screenshots of 仓库形状修订案 v1.0: the 仓管台's 10 × 12 grid, the PRTS
## terminal's 消息 and 邮件 pages, and the hall log right after PRTS speaks.
## Writes evidence/warehouse-mail-*.png. Not in run_all.
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
	root.get_texture().get_image().save_png("res://../evidence/warehouse-mail-" + label + ".png")
	print("captured ", label)
func run() -> void:
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_step"] = TutorialCard.STEPS.size()
	SystemScreens.settings["tutorial_tips"] = false
	SystemScreens.settings["story_guide"] = false
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	var base := game.base
	# A warehouse filled near the top with a mix of shapes, then arrivals past it.
	var kinds := [["螺栓", 1, 1], ["长剑", 2, 1], ["重甲", 2, 2], ["长弓", 1, 3]]
	var i := 0
	while base.shelf_count() < base.capacity() - 3 and i < 400:
		var k: Array = kinds[i % kinds.size()]
		var it := Item.create("%s%d" % [k[0], i], Item.Category.WEAPON if k[1] > 1 or k[2] > 1 else Item.Category.TRINKET, k[1], k[2], 1.0)
		if not base.shelf_has_room(it): it = Item.create("小件%d" % i, Item.Category.TRINKET, 1, 1, 1.0)
		base.receive(it)
		i += 1
	for n in range(6): base.receive(Item.create("送回的装备%d" % n, Item.Category.ARMOR, 2, 2, 1.0), false, "罗德岛小队")
	await step(5)
	game.open_station("stash")
	await capture("stash")
	game.close_modal()
	await step(5)
	await capture("hall-log")
	game.inventory.try_add(Item.create("长刀", Item.Category.WEAPON, 1, 3, 1.0))
	game.inventory.try_add(MaterialCatalog.create("螺栓", 8))
	game.open_station("loadout")
	await capture("workbench")
	game.close_modal()
	game.broadcast("PRTS：博士，加工部完成 螺栓 ×20。")
	game.open_station("prts")
	await capture("prts-inbox")
	game.close_modal()
	quit(0)
