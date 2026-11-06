extends SceneTree

## 干员独立装备修订案 v1.0 (用户 2026-11-04: 每个干员可穿一套装备，已解锁的可在
## 干员界面切换查看): each operator keeps her own set, a change of who deploys
## swaps it whole, the pack is shared, the set is saved, old saves give the
## worn set to whoever deploys, and the C window shows any operator on the
## roster in her own set — to look, not to deploy.

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
func find(n: Node, pred: Callable) -> Node:
	if pred.call(n): return n
	for c in n.get_children():
		var f := find(c, pred)
		if f != null: return f
	return null

func piece(category: int) -> Item:
	var id := GearCatalog.pick(category, "mine", 3, "box", "", game.rng)
	return LootTables.roll_equipment(category, GearCatalog.BASES[id].name, "mine", 3, Item.BLUE, game.rng)

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	root.add_child(game)
	await step(8)
	var amiya := Operators.AMIYA_GUARD
	game.choose_operator(amiya)
	game.base.recruit("hellagur")
	var helmet := piece(Item.Category.HEAD)
	var boots := piece(Item.Category.FEET)
	var chest := piece(Item.Category.CHEST)
	game.player.equip(helmet)
	game.player.equip(boots)
	var bag_thing := MaterialCatalog.create("螺栓", 3)
	game.inventory.try_add(bag_thing)
	var bare := game.operator_view("hellagur").max_hp
	game.choose_operator("hellagur")
	check("a new deployer starts in her own (empty) set", game.player.operator_id == "hellagur" and game.player.equipped.is_empty())
	check("the one who left keeps hers", game.base.gear_of(amiya).values().has(helmet) and game.base.gear_of(amiya).values().has(boots))
	check("the pack is shared", game.inventory.items.has(bag_thing))
	game.player.equip(chest)
	game.choose_operator(amiya)
	check("back: she wears her own again", game.player.equipped.values().has(helmet) and game.player.equipped.values().has(boots) and not game.player.equipped.values().has(chest))
	check("and 赫拉格 keeps hers", game.base.gear_of("hellagur").values() == [chest])
	# The C window shows anyone on the roster in her own set.
	var view := game.operator_view("hellagur")
	check("the view of 赫拉格 counts her own set", view != game.player and view.equipped.values() == [chest] and view.max_hp > bare and view.hp == view.max_hp)
	check("the view of the deployed one is herself", game.operator_view(amiya) == game.player)
	game.open_training()
	await step(2)
	var chip: Button = find(game.menu, func(n): return n is Button and n.get_meta("operator", "") == "hellagur")
	check("the C window lists the roster", chip != null and find(game.menu, func(n): return n is Button and n.get_meta("operator", "") == amiya) != null)
	if chip != null: chip.pressed.emit()
	await step(1)
	var doll_slot: Node = find(game.menu, func(n): return n is LoadoutScreens.DollSlot and n.item == chest)
	check("her doll shows her own pieces, not the deployed one's", doll_slot != null and find(game.menu, func(n): return n is LoadoutScreens.DollSlot and n.item == helmet) == null)
	check("a click shows her, without deploying her", game.viewed_id() == "hellagur" and game.player.operator_id == amiya and game.base.operator == amiya)
	var progress := game.base.progress_for("hellagur")
	progress.attribute_points = 1
	var mine := game.progress().attribute_points
	var key: String = Progression.ATTRIBUTES[0]
	game.add_attribute_point(key)
	check("points spent while viewing her are hers", progress.attribute_points == 0 and game.progress().attribute_points == mine)
	game.close_modal()
	game.open_training()
	check("opening C again starts at the deployed one", game.viewed_id() == amiya)
	game.close_modal()
	# Saved; an old save has no sets.
	var copy := BaseState.new()
	copy.load_data(JSON.parse_string(JSON.stringify(game.base.to_data())), {})
	check("the sets are saved", copy.gear_of("hellagur").size() == 1 and (copy.gear_of("hellagur").values()[0] as Item).uid == chest.uid)
	var old := BaseState.new()
	old.load_data({}, {})
	check("an old save: no stored sets (the worn one stays with whoever deploys)", old.gear_sets.is_empty())
	print("GEAR SETS FAILURES: %d" % failures)
	quit(1 if failures else 0)
