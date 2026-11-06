extends SceneTree
## Screenshots of the C window with the roster column (干员独立装备修订案):
## the deployed one, then another in her own set. evidence/gear-sets-*.png.
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
func find(n: Node, pred: Callable) -> Node:
	if pred.call(n): return n
	for c in n.get_children():
		var f := find(c, pred)
		if f != null: return f
	return null
func capture(label: String) -> void:
	await step(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/gear-sets-" + label + ".png")
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
	for id in ["hellagur", "texas", "lin"]: game.base.recruit(id)
	game.choose_operator(Operators.AMIYA_GUARD)
	game.choose_operator("hellagur")
	for category in Item.SLOTS:
		var id := GearCatalog.pick(category, "mine", 8, "box", "", game.rng)
		var piece := LootTables.roll_equipment(category, GearCatalog.BASES[id].name, "mine", 8, Item.PURPLE, game.rng)
		if GearCatalog.can_wield("hellagur", piece): game.player.equip(piece)
	game.choose_operator(Operators.AMIYA_GUARD)
	game.open_training()
	await capture("deployed")
	var chip: Button = find(game.menu, func(n): return n is Button and n.get_meta("operator", "") == "hellagur")
	chip.pressed.emit()
	await capture("hellagur")
	quit(0)
