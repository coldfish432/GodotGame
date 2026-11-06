extends SceneTree
## A hands-on test bench for 仓库形状修订案 v1.0 (用户 2026-11-04: 写相关我可以
## 直接打开界面测的测试). Opens the real game in a window, in the base, with:
## - the warehouse (仓储部 Lv1, 10 × 12) nearly full of mixed shapes;
## - the pack holding pieces to store (one 2×2 that will not fit);
## - two letters waiting in the PRTS inbox, and a few PRTS messages;
## - 阿米娅, 赫拉格, 德克萨斯 and 林 on the roster, the first two each in her own set.
## Nothing is saved: the slot on disk is left as it was. Not in run_all.
##
## Keys while it runs (also listed in the PRTS inbox):
##   F5  the base brings home a 2×2 piece (warehouse, or the inbox when full)
##   F6  PRTS says something (the hall log pops up, then fades)
##   F7  仓储部 one level up (10 × 20 / 30 / 50)
##   F8  empty the pack into fresh test pieces again
##   Enter  the PRTS terminal (the game's own key)

var game: GameManager
var _held := {}

func _initialize() -> void: call_deferred("run")

func step(count: int = 10) -> void:
	for i in range(count): await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func run() -> void:
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	# Never write the player's save from the bench.
	game.save_enabled = false
	SystemScreens.settings["tutorial_tips"] = false
	var base := game.base
	base.set_facility("warehouse", 1)
	base.research.done.erase(ResearchCatalog.id_of_key("rack_cells"))
	base.shelf.clear()
	base.mail.clear()
	# A warehouse three quarters full: weapons, armour, materials of every shape.
	var shapes := [["测试长剑", Item.Category.WEAPON, 1, 3], ["测试重甲", Item.Category.ARMOR, 2, 2], ["测试短刀", Item.Category.WEAPON, 1, 2], ["测试护腕", Item.Category.ARMOR, 2, 1]]
	var i := 0
	while base.shelf_count() < 84 and i < 200:
		var s: Array = shapes[i % shapes.size()]
		base.receive(Item.create("%s%d" % [s[0], i], s[1], s[2], s[3], 1.0))
		i += 1
	for id in ["螺栓", "胶带", "帆布", "碳", "金属板"]: base.receive(MaterialCatalog.create(id, 10))
	_refill_pack()
	# A few more on the roster, 赫拉格 in a set of her own (干员独立装备修订案):
	# the C window's column switches between them; the workbench swaps who deploys.
	for id in ["hellagur", "texas", "lin"]: base.recruit(id)
	game.choose_operator("hellagur")
	_dress()
	game.choose_operator(Operators.AMIYA_GUARD)
	_dress()
	game.player._recompute_stats()
	# Two letters: things the base could not shelve (and the notices).
	for n in range(3): base.post_mail(Item.create("投保送回的护甲%d" % n, Item.Category.ARMOR, 2, 2, 1.0), "罗德岛小队")
	base.mail[-1].time = BaseState.now() - 3600
	base.post_mail(MaterialCatalog.create("帆布", 6), "加工部")
	base.post_mail(MaterialCatalog.create("密封泡沫", 3), "加工部")
	base.mailed.clear()
	game.broadcast("PRTS：测试台已就绪。F5 基地送回一件 2×2 · F6 PRTS 播报 · F7 仓储部升级 · F8 重装背包 · 回车 PRTS 终端。")
	game.broadcast("PRTS：博士，加工部完成 螺栓 ×20。")
	if is_instance_valid(game.menu): game.menu.visible = false
	game.close_modal()

## The deployed one in a set of purple pieces she can wield.
func _dress() -> void:
	for category in Item.SLOTS:
		var id := GearCatalog.pick(category, "mine", 8, "box", "", game.rng)
		var piece := LootTables.roll_equipment(category, GearCatalog.BASES[id].name, "mine", 8, Item.PURPLE, game.rng)
		if GearCatalog.can_wield(game.player.operator_id, piece): game.player.equip(piece)

func _refill_pack() -> void:
	for item in game.inventory.items.duplicate(): game.inventory.remove(item)
	for item in [Item.create("背包里的重甲", Item.Category.ARMOR, 2, 2, 1.0), Item.create("背包里的长枪", Item.Category.WEAPON, 1, 3, 1.0),
			MaterialCatalog.create("螺栓", 12), MaterialCatalog.create("帆布", 4), Item.create("背包里的指环", Item.Category.TRINKET, 1, 1, 1.0)]:
		game.inventory.try_add(item)

func _pressed(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var was: bool = _held.get(key, false)
	_held[key] = down
	return down and not was

func _process(_delta: float) -> bool:
	if game == null or not game.in_base: return false
	if _pressed(KEY_F5):
		game.base.receive(Item.create("送回的装备%d" % Time.get_ticks_msec(), Item.Category.ARMOR, 2, 2, 1.0), false, "罗德岛小队")
		if game.base.mailed.is_empty(): game.broadcast("PRTS：送回的装备已入库。")
	if _pressed(KEY_F6): game.broadcast("PRTS：测试消息 %s。" % Time.get_time_string_from_system())
	if _pressed(KEY_F7):
		var level := mini(game.base.facility_level("warehouse") + 1, BaseCatalog.facility_max("warehouse"))
		game.base.set_facility("warehouse", level)
		game.broadcast("PRTS：仓储部 Lv%d，仓库 %d×%d。" % [level, BaseState.SHELF_COLUMNS, game.base.shelf_height()])
	if _pressed(KEY_F8):
		_refill_pack()
		game.broadcast("PRTS：背包已重新装好测试物品。")
	return false
