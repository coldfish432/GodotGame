extends SceneTree

## 整理箱与收藏品策划案 v0.2 (用户 2026-10-25): collectibles from the map's
## points of interest, sold to 可露希尔, asked for by orders and given to a
## faction in a gift; 整理箱 in the warehouse that count as one item, take
## only their kind, open with a double click and go up a level in place; the
## workbench shows the whole warehouse on the 仓管台's tabs; 投保台 takes
## insurance off.

var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if passed or detail == null else "  " + str(detail)))
func find(node: Node, pred: Callable) -> Node:
	if pred.call(node): return node
	for child in node.get_children():
		var found := find(child, pred)
		if found != null: return found
	return null
func ctx(region: String, depth: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {"region": region, "depth": depth, "reward": 0.0, "rng": rng, "pity": {}}
func found_in(drops: Array) -> Array:
	return drops.filter(func(d): return d.get("item") != null).map(func(d): return d.item)

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 2025
	root.add_child(game)
	await step(8)
	game.base.set_facility("warehouse", 2)
	_collectibles()
	_loot()
	_cases()
	await _case_ui()
	_trade()
	_gifts()
	_orders_and_insurance()
	await _workbench()
	print("CASES FAILURES %d" % failures)
	quit(1 if failures else 0)

func _collectibles() -> void:
	var seal := Collectibles.create("家族印章")
	check("a collectible is its own kind: not gear, not a material, 1×1 red worth 45,000",
		seal.is_collectible() and not seal.is_equippable() and seal.category != Item.Category.MATERIAL and seal.rarity == Item.RED and Economy.price(seal) == 45000 and seal.origin_region == "siracusa")
	# 用户 2026-10-26: 五等级（白绿蓝紫红），扩充至 50 个，添加明日方舟角色手办.
	var ids: Array = Collectibles.ITEMS.keys()
	check("50 collectibles: eight a region, eighteen figurines", ids.size() == 50
		and ["mine", "city", "snow", "siracusa"].all(func(r): return ids.filter(func(id): return Collectibles.ITEMS[id].region == r).size() == 8)
		and ids.filter(func(id): return Collectibles.is_figurine(id)).size() == 18)
	check("white, green, blue, purple or red, never orange", ids.all(func(id): return int(Collectibles.ITEMS[id].rarity) in Collectibles.RARITIES) and not Collectibles.RARITIES.has(Item.ORANGE))
	check("each region has every rarity", ["mine", "city", "snow", "siracusa"].all(func(r): return Collectibles.RARITIES.all(func(k): return ids.any(func(id): return Collectibles.ITEMS[id].region == r and int(Collectibles.ITEMS[id].rarity) == k))))
	check("they never stack", not Collectibles.create("能天使手办").is_stackable())
	# 用户 2026-10-26: 手办可以是高清图 — shrunk smoothly to the 1×2 icon size for the grids.
	var art := ImageTexture.create_from_image(Image.create(512, 1024, false, Image.FORMAT_RGBA8))
	var icon := ItemIcons._icon_sized(art, Collectibles.create("能天使手办"))
	check("a hi-res figurine fits its 1×2 icon box (32×72), keeping its 1:2 shape", ItemIcons.is_hires(art) and icon.get_size() == Vector2(32, 64), icon.get_size())
	check("可露希尔 buys collectibles", Consignment.takes(seal) and FactionCatalog.category_of(seal) == "collectible")
	check("no trade pack takes them", not Packs.packable(seal))
	game.inventory.try_add(seal)
	check("they cannot be insured", not game.insure(seal) and not seal.insured)
	game.inventory.remove(seal)
	check("they come back from a save", Item.from_data(seal.to_data()).is_collectible() and Item.from_data(seal.to_data()).base_id == "家族印章")
	var old := seal.to_data()
	old.value = 45000
	check("a save with the old 100× worth loads at the table's", Economy.price(Item.from_data(old)) == 45000)

func _loot() -> void:
	var collector := 0
	var safe := 0
	var other := 0
	var wrong_region := false
	for i in range(400):
		var c := ctx("city", 1, 1000 + i)
		var got := found_in(LootTables.container_drops("collector_box", c)).filter(func(x): return x.is_collectible())
		if not got.is_empty(): collector += 1
		for x in got:
			if x.origin_region != "city" and not Collectibles.is_figurine(x.base_id): wrong_region = true
		if found_in(LootTables.container_drops("safe", ctx("city", 1, 5000 + i))).any(func(x): return x.is_collectible()): safe += 1
		if found_in(LootTables.container_drops("construction", ctx("city", 1, 9000 + i))).any(func(x): return x.is_collectible()): other += 1
	check("a 收藏品箱 always holds one", collector == 400, collector)
	check("only its own region's collectibles, or a figurine", not wrong_region)
	var figures := 0
	for i in range(400):
		var got: Item = Collectibles.roll("snow", 1, ctx("snow", 1, 20000 + i).rng)
		if Collectibles.is_figurine(got.base_id): figures += 1
	check("figurines turn up in any region", figures > 40 and figures < 300, figures)
	check("a 保险柜 holds one about 40% of the time", absf(safe / 400.0 - 0.4) < 0.08, safe)
	check("any other point now and then (~3% on floor 1)", other > 0 and other < 30, other)
	check("the 收藏品箱 is a point of interest kind with a model", LootTables.POI.has("collector_box") and LootContainer.MODELS.has("collector_box"))
	check("each region has its own 收藏品箱 model", ["mine", "city", "snow", "siracusa"].all(func(r): return ResourceLoader.exists(str(LootContainer.MODELS.get("collector_" + r, "")))))

func _cases() -> void:
	var base := game.base
	base.shelf.clear()
	var box := Collectibles.create_case("material", 1)
	check("a level-1 material box: 2×2 outside, 5×5 inside", box.width == 2 and box.height == 2 and box.contents.width == 5 and box.contents.height == 5)
	check("the four levels lie 2×2, 2×3, 3×4, 5×6", range(1, 5).map(func(t): var b := Collectibles.create_case("gear", t); return Vector2i(b.width, b.height)) == [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(5, 6)])
	base.receive(box)
	var bolts := MaterialCatalog.create("螺栓", 10)
	var tape := MaterialCatalog.create("胶带", 5)
	game.inventory.try_add(bolts)
	base.receive(tape)
	check("from the pack into a box", game.box_item(box, bolts) and box.contents.items.has(bolts) and not game.inventory.items.has(bolts))
	check("from the shelves into a box", game.box_item(box, tape) and box.contents.items.has(tape) and not base.shelf.has(tape))
	check("the box takes its own 2×2, what it holds nothing", base.shelf_count() == 4)
	check("…but it is still in the warehouse", game.stash.has(bolts) and base.location_of(bolts) == "shelf" and game.material_count("螺栓") == 10)
	check("crafting takes from inside a box", game.consume_materials({"螺栓": 4}) and bolts.quantity == 6)
	var blade := Item.create("箱外刀", Item.Category.WEAPON, 1, 2, 1.0)
	game.inventory.try_add(blade)
	check("the wrong kind does not go in", not game.box_item(box, blade) and game.inventory.items.has(blade))
	game.inventory.remove(blade)
	var other := Collectibles.create_case("material", 1)
	base.receive(other)
	check("no box inside a box", not game.box_item(box, other))
	check("a box never goes into the pack", not game.bring_item(box) and base.shelf.has(box))
	check("an item in a box comes out to the pack", game.bring_item(tape) and game.inventory.items.has(tape) and not box.contents.items.has(tape))
	# A drop on the box's cells puts the item in; elsewhere it lands on the shelves.
	BaseScreens.shelf_drop(game, tape, Vector2i(box.grid_x + 1, box.grid_y + 1))
	check("dropped on the box's cells it goes in", box.contents.items.has(tape))
	BaseScreens.shelf_drop(game, tape, Vector2i(6, 3))
	check("dropped on a free cell it comes out there", base.shelf.has(tape) and tape.grid_x == 6 and tape.grid_y == 3 and not box.contents.items.has(tape))
	var back := Item.from_data(box.to_data())
	check("a box keeps what it holds through a save", back.is_case() and back.case_kind == "material" and back.case_tier == 1 and back.contents.items.size() == 1 and back.contents.items[0].material_id == "螺栓")
	base.shelf.erase(other)

func _case_ui() -> void:
	game.menu.stash_tab = 0
	game.open_station("stash")
	await step(1)
	check("the 仓管台's tabs: 全部 武器 防具 饰品 药剂 材料 收藏品 拆包", BaseScreens.STASH_TABS == ["全部", "武器", "防具", "饰品", "药剂", "材料", "收藏品", "拆包"])
	var box: Item = game.base.shelf.filter(func(x): return x.is_case())[0]
	var grid: BaseScreens.FlowGrid = find(game.menu, func(n): return n is BaseScreens.FlowGrid)
	check("the warehouse grid opens boxes", grid != null and grid.on_open.is_valid())
	if grid != null: grid.on_open.call(box)
	await step(1)
	var window: AK.BagGrid = find(game.menu, func(n): return n is AK.BagGrid and n.container == box.contents)
	check("a double click opens the box's own window, which takes drops", BaseScreens.open_box == box and window != null and window.accept.is_valid())
	game.go_back()
	await step(1)
	check("Esc shuts the box first, the 仓管台 stays", BaseScreens.open_box == null and game.modal == "station")
	game.close_modal()

func _trade() -> void:
	var base := game.base
	for id in ["帆布", "金属板", "胶带", "密封泡沫", "赤金"]: base.receive(MaterialCatalog.create(id, MaterialCatalog.stack_size(id)))
	check("level 2 needs a level-1 box of its kind", game.case_refusal("collectible", 2) != "")
	check("level 1 is traded for goods", game.case_refusal("collectible", 1) == "" and game.trade_case("collectible", 1))
	var small: Item = base.shelf.filter(func(x): return x.is_case() and x.case_kind == "collectible")[0]
	var vase := Collectibles.create("炎国瓷茶壶")
	base.receive(vase)
	game.box_item(small, vase)
	var at := Vector2i(small.grid_x, small.grid_y)
	check("level 2 takes the level-1 box and goods", game.trade_case("collectible", 2))
	var big: Item = base.shelf.filter(func(x): return x.is_case() and x.case_kind == "collectible")[0]
	check("…turning it into a level-2 box with what it held", big.case_tier == 2 and big.contents.items.has(vase) and not base.shelf.has(small)
		and base.shelf.filter(func(x): return x.is_case() and x.case_kind == "collectible").size() == 1)
	check("…where it lay when it still fits", Vector2i(big.grid_x, big.grid_y) == at or not base.shelf_fits(big, at.x, at.y))
	check("level 3 asks for a blue collectible on top", game.case_refusal("collectible", 3) != "")

func _gifts() -> void:
	var base := game.base
	var a := Collectibles.create("醒狮摆件")
	var b := Collectibles.create("帝国勋章")
	base.receive(a)
	game.inventory.try_add(b)
	var gift := game.make_gift([a, b])
	check("a gift takes the collectibles and holds them", gift != null and GameManager.is_gift(gift) and Economy.price(gift) == 7500 + 38000 and not game.stash.has(a) and not game.inventory.items.has(b))
	check("a city piece counts ×1.5 for 龙门商会", game.gift_gain(gift, "lungmen") == roundi((7500 * 1.5 + 38000) / 1000.0))
	check("…and a mine piece for 乌萨斯西北矿场", game.gift_gain(gift, "ursus") == roundi((7500 + 38000 * 1.5) / 1000.0))
	check("a gift is not sold, packed, boxed or delivered", not Consignment.takes(gift) and not Packs.packable(gift) and not Collectibles.accepts("material", gift) and not base.orders.matches(0, gift))
	var saved := Item.from_data(gift.to_data())
	check("a gift survives a save with what it holds", GameManager.is_gift(saved) and saved.contents.items.size() == 2 and game.gift_gain(saved, "lungmen") == game.gift_gain(gift, "lungmen"))
	var before := game.exchange.relation("lungmen")
	check("giving it raises the relation", game.best_gift("lungmen") == gift and game.give_gift(gift, "lungmen") and game.exchange.relation("lungmen") == before + 49)
	check("…and it is gone", not game.stash.has(gift))

func _orders_and_insurance() -> void:
	var t: Dictionary = BaseCatalog.ORDERS["log_siracusa_collectible"]
	var board := OrderBoard.new()
	board.slots = [{"id": "log_siracusa_collectible", "state": "open", "delivered": []}]
	check("an order asks for a 叙拉古 collectible, blue or better", t.category == Item.Category.COLLECTIBLE
		and board.matches(0, Collectibles.create("陶瓷狼像")) and not board.matches(0, Collectibles.create("银质餐刀匣")) and not board.matches(0, Collectibles.create("古玉坠")))
	var coat := Item.create("投保外套", Item.Category.CHEST, 2, 2, 1.0)
	coat.insured = true
	game.base.receive(coat)
	check("投保台 takes insurance off a piece in the warehouse", game.uninsure(coat) and not coat.insured)

func _workbench() -> void:
	LoadoutScreens.depot_tab = 0
	game.open_station("loadout")
	await step(1)
	check("the workbench uses the same tabs, without 拆包", LoadoutScreens.DEPOT_TABS == BaseScreens.STASH_TABS.slice(0, 7))
	var grid: BaseScreens.FlowGrid = find(game.menu, func(n): return n is BaseScreens.FlowGrid)
	check("全部 is the warehouse as it lies, 10 columns at 40 px", grid != null and grid.columns == BaseState.SHELF_COLUMNS and grid.cell == LoadoutScreens.ALL_CELL
		and grid.items.size() == game.base.shelf.size() and grid.move_to.is_valid())
	LoadoutScreens.depot_tab = 5
	game.open_station("loadout")
	await step(1)
	grid = find(game.menu, func(n): return n is BaseScreens.FlowGrid)
	check("材料 lists materials, boxed ones too", grid != null and grid.items.any(func(x): return x.material_id == "螺栓") and grid.items.all(func(x): return x.category == Item.Category.MATERIAL))
	LoadoutScreens.depot_tab = 0
	game.close_modal()
