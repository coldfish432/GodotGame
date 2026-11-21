extends SceneTree

## 合同板修订案_v0_1.md (用户 2026-11-18): the departments' board, several cards
## taken at once, 交付 / 回收 handed over at the base (the old order board,
## 基地玩法策划案_v1_0.md §3.8). Board rules on their own, then through the game.

var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))
func item(name: String, category: Item.Category, value: int = 10, region: String = "", rarity: int = 0) -> Item:
	var x := Item.create(name, category, 1, 1, 1.0)
	x.value = value
	x.origin_region = region
	x.rarity = rarity
	return x
## A material stack: `units` units worth `unit_value` each (cards count units).
func stack(units: int, unit_value: int, region: String = "") -> Item:
	var x := MaterialCatalog.create("源岩", units, region)
	x.unit_value = unit_value
	x.set_quantity(units)
	return x
## A board with these ORDERS templates taken.
func board_with(ids: Array) -> ContractBoard:
	var board := ContractBoard.new()
	for id in ids: board.add_active({"type": "order", "id": id, "region": str(BaseCatalog.ORDERS[id].get("region", ""))}, str(BaseCatalog.ORDERS[id].dept))
	return board
func ctx(regions: Array = ["mine", "city", "snow", "siracusa"]) -> Dictionary:
	return {"regions": regions, "depts": ["外勤部", "工程部", "医疗部", "后勤部", "加工部"], "extra": {}, "start": func(_r): return 1, "bonus": 10000}

func run() -> void:
	rules()
	posting()
	await through_game()
	print("CONTRACT BOARD FAILURES: %d" % failures)
	quit(1 if failures else 0)

func rules() -> void:
	var fresh := BaseState.new()
	var first: Dictionary = fresh.board.active[0] if fresh.board.active.size() == 1 else {}
	check("a new game has the first contract taken: 工程部 · 回收 源岩 ×6 at 切尔诺伯格",
		str(first.get("type", "")) == "recover" and first.material == "源岩" and int(first.count) == 6 and first.region == "mine" and first.dept == "工程部" and int(first.gold) == 8000 * 9 / 10)
	check("order text names department, item and count: " + BaseCatalog.order_text("eng_mine_materials"),
		BaseCatalog.order_text("eng_mine_materials") == "工程部：材料 ×8（产地：切尔诺伯格）")

	# Matching: category, rarity, origin, exclusives.
	var b := board_with(["eng_mine_materials", "log_fine_weapon", "eng_raw_ore"])
	var mats: Dictionary = b.active[0]
	var fine: Dictionary = b.active[1]
	var ore_card: Dictionary = b.active[2]
	check("material from the mine fits, from elsewhere does not", ContractBoard.matches(mats, item("矿料", Item.Category.MATERIAL, 10, "mine")) and not ContractBoard.matches(mats, item("雪料", Item.Category.MATERIAL, 10, "snow")))
	check("old items without an origin do not fit a regional card", not ContractBoard.matches(mats, item("旧料", Item.Category.MATERIAL)))
	check("fine weapon card refuses a common weapon", not ContractBoard.matches(fine, item("普通刀", Item.Category.WEAPON)) and ContractBoard.matches(fine, item("精良刀", Item.Category.WEAPON, 10, "", Item.BLUE)))
	check("exclusive cards want that exact exclusive", ContractBoard.matches(ore_card, FieldCatalog.exclusive("mine")) and not ContractBoard.matches(ore_card, FieldCatalog.exclusive("city")))

	# Partial delivery, then payout on completion; a finished card leaves.
	var first_part := b.deliver(int(mats.uid), stack(3, 10, "mine"))
	check("first 3 of 8 units: progress, no pay yet", not first_part.done and first_part.gold == 0 and ContractBoard.remaining(mats) == 5)
	var second := b.deliver(int(mats.uid), stack(9, 8, "mine"))
	check("a 9-stack gives only the 5 still asked for", int(second.used) == 5)
	check("completes: (30 + 5×8) ×100 x 1.4 = 9800 龙门币, and leaves the board", second.done and second.gold == 9800 and b.find_active(int(mats.uid)).is_empty())
	check("a finished card takes nothing more", b.deliver(int(mats.uid), stack(2, 10, "mine")).is_empty())
	var ore := b.deliver(int(ore_card.uid), FieldCatalog.exclusive("mine"))
	check("exclusive cards pay their fixed sum", ore.done and ore.gold == 16000)
	check("abandoning drops a taken card", b.abandon(int(fine.uid)) and b.active.is_empty() and not b.abandon(int(fine.uid)))

	# Taking: the cap, one run kind per region, the same card twice.
	var t := ContractBoard.new()
	t.posted = [{"uid": 1, "type": "deep", "region": "mine", "steps": 4, "dept": "外勤部", "age": 0},
		{"uid": 2, "type": "deep", "region": "city", "steps": 4, "dept": "外勤部", "age": 0},
		{"uid": 3, "type": "deep", "region": "mine", "steps": 9, "dept": "外勤部", "age": 0},
		{"uid": 4, "type": "hunt", "region": "mine", "offset": 4, "dept": "外勤部", "age": 0},
		{"uid": 5, "type": "order", "id": "log_trinkets", "region": "", "dept": "后勤部", "age": 0}]
	t.serial = 5
	check("taking moves a card from posted to taken", not t.take(t.posted[0], 3).is_empty() and t.find_posted(1).is_empty() and not t.find_active(1).is_empty())
	check("the same kind in another region is fine", not t.take(t.find_posted(2), 3).is_empty())
	check("a second depth in the same region is refused", t.refusal(t.find_posted(3), 3) == "same" and t.take(t.find_posted(3), 3).is_empty())
	check("a hunt beside the depth is fine", not t.take(t.find_posted(4), 3).is_empty())
	check("three taken: the fourth waits (cap 3)", t.refusal(t.find_posted(5), 3) == "full")
	check("外勤部 1 阶's fourth place takes it", not t.take(t.find_posted(5), 4).is_empty())
	check("run cards for a region: its own and any-region ones", t.run_cards("mine").size() == 2 and t.run_cards("city").size() == 1 and t.deliveries().size() == 1)
	var live := {"type": "deliver", "order": 7, "faction": "rat", "floor": 6, "pay": 10.0, "currency": "lmd", "relation": 5, "region": "snow", "dept": "商务部"}
	var taken := t.take(live, 5)
	check("a live 运送 card gets a uid when taken", int(taken.get("uid", 0)) > 5 and t.refusal(live, 9) == "same")

	var copy := ContractBoard.new()
	copy.load_data(JSON.parse_string(JSON.stringify(t.to_data())))
	check("board save round trip keeps posted, taken and the serial", copy.posted.size() == t.posted.size() and copy.active.size() == t.active.size() and copy.serial == t.serial)
	# An old save's order board: open orders become taken cards, done and empty go.
	var old := ContractBoard.new()
	old.migrate_orders([{"id": "eng_carbon", "state": "open", "delivered": [{"uid": "x", "name": "碳", "value": 10, "count": 3}]}, {"id": "log_trinkets", "state": "done", "delivered": []}, null])
	check("migration: the open order is taken, its deliveries kept", old.active.size() == 1 and old.active[0].id == "eng_carbon" and ContractBoard.delivered_count(old.active[0]) == 3)
	check("no order carries prestige any more", BaseCatalog.ORDERS.values().all(func(o): return not o.has("prestige")))

func posting() -> void:
	var rng := RandomNumberGenerator.new()
	var one_exclusive := true
	var points_away := true
	var no_repeats := true
	var full := true
	var kinds_ok := true
	var regions_ok := true
	var ages_out := true
	for seed in range(200):
		rng.seed = seed
		var region: String = ["mine", "city", "snow"][seed % 3]
		var board := ContractBoard.new()
		board.add_active({"type": "order", "id": "eng_raw_ore" if seed % 2 == 0 else "med_city_armor", "region": "mine" if seed % 2 == 0 else "city"}, "工程部")
		var open: Array = ["mine", "city", "snow", "siracusa"] if seed % 4 else ["mine"]
		board.fill(rng, ctx(open), region)
		var all: Array = board.posted + board.active
		one_exclusive = one_exclusive and all.filter(func(c): return ContractBoard.is_exclusive(c)).size() <= 1
		if open.size() > 1: points_away = points_away and board.posted.any(func(c): return not str(c.region).is_empty() and c.region != region)
		var keys := {}
		for c in all: keys[ContractBoard._key(c)] = true
		no_repeats = no_repeats and keys.size() == all.size()
		var slots := 0
		for d in ContractBoard.DEPT_SLOTS: slots += ContractBoard.DEPT_SLOTS[d]
		full = full and board.posted.size() == slots
		kinds_ok = kinds_ok and board.posted.all(func(c): return str(c.type) in ["deep", "hunt", "recover", "order"])
		regions_ok = regions_ok and board.posted.all(func(c): return str(c.region) == "" or str(c.region) in open)
		var uids: Array = board.posted.map(func(c): return int(c.uid))
		board.after_settlement(rng, ctx(open), region)
		var kept := uids.filter(func(u): return not board.find_posted(u).is_empty()).size()
		board.after_settlement(rng, ctx(open), region)
		ages_out = ages_out and kept == uids.size() and uids.all(func(u): return board.find_posted(u).is_empty())
	check("posting: at most one exclusive-item card on the board (200 seeds)", one_exclusive)
	check("posting: something always points away from the last region", points_away)
	check("posting: no card twice", no_repeats)
	check("posting: every department fills its slots", full)
	check("posting: only 深入 / 猎杀 / 回收 / 交付 are posted (运送 comes live)", kinds_ok)
	check("posting: only open regions", regions_ok)
	check("posting: untaken cards stay one settlement and go after two", ages_out)
	var no_workshop := ctx()
	no_workshop.depts = ["外勤部", "工程部", "医疗部", "后勤部"]
	var b := ContractBoard.new()
	b.fill(rng, no_workshop)
	check("a department still missing posts nothing", not b.posted.any(func(c): return c.dept == "加工部"))
	no_workshop.extra = {"后勤部": 1}
	b.fill(rng, no_workshop)
	check("后勤部 1 阶: one more 后勤部 slot", b.posted.filter(func(c): return c.dept == "后勤部").size() == 3)
	var r: Dictionary = b.posted[0]
	check("a reroll swaps a card for another from the same department", b.reroll(int(r.uid), rng, no_workshop) and b.find_posted(int(r.uid)).is_empty() and b.posted.size() == 9)

func through_game() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	check("the outbound station is exported", not game.base_map.station("outbound").is_empty())
	game.base.board = board_with(["eng_carbon", "log_fine_weapon"])
	var carbon: Dictionary = game.base.board.active[0]
	var weapon_card: Dictionary = game.base.board.active[1]
	var shelf_mat := MaterialCatalog.create("碳", 2)
	shelf_mat.unit_value = 10
	var pack_mat := MaterialCatalog.create("碳", 6)
	pack_mat.unit_value = 15
	var safe_mat := item("安全袋材料", Item.Category.MATERIAL, 50)
	var worn := item("装备着的精良刀", Item.Category.WEAPON, 40, "", Item.BLUE)
	game.base.shelf.append(shelf_mat)
	game.inventory.try_add(pack_mat)
	game.safe_bag.try_add(safe_mat)
	game.player.equip(worn)
	# 仓库修订: no staging, crates or carrying; the warehouse and the bags deliver.
	var deliverable := game.deliverable_items()
	check("deliverable: warehouse, pack and safe bag, not equipped", deliverable.has(shelf_mat) and deliverable.has(pack_mat)
		and deliverable.has(safe_mat) and not deliverable.has(worn))
	check("equipped items are refused", not game.deliver_to_order(int(weapon_card.uid), worn))
	game.safe_bag.remove(safe_mat)
	await step(2)
	check("the board shows a card she can fill", game.warehouse_view.board_state() == "open")
	var gold := game.gold
	check("deliver from the shelf", game.deliver_to_order(int(carbon.uid), shelf_mat) and game.base.location_of(shelf_mat) == "" and game.gold == gold)
	check("deliver from the pack completes: (20 + 6×15) ×100 x 1.5 = 16500 龙门币",
		game.deliver_to_order(int(carbon.uid), pack_mat) and not game.inventory.items.has(pack_mat) and game.gold == gold + 16500, game.gold - gold)
	check("the finished card is gone, the other stays", game.base.board.active.size() == 1 and game.base.board.active[0].id == "log_fine_weapon")

	# Settlement: the board posts; taken cards stay.
	game.player.unequip(Item.Category.WEAPON)
	await game.start_contract("mine")
	game.settle(true)
	await step(2)
	check("after a settlement the board is posted and the taken card stays", game.base.board.posted.size() >= 8 and game.base.board.active.size() == 1)
	game.base.board = board_with(["eng_raw_ore", "med_city_armor"])
	check("cards pointing at each region", game.base.board.pointing_at("mine") == 1 and game.base.board.pointing_at("city") == 1 and game.base.board.pointing_at("snow") == 0)
	game.open_station("contracts")
	check("the mine region button counts its taken cards", _has_text(game.menu, "合同 1"))
	BaseScreens.dispatch_tab = 1
	game.open_station("contracts")
	check("the 合同板 page lists the taken cards and the cap", _contains_text(game.menu, "进行中 2/3") and _contains_text(game.menu, "未封装源石原矿"))
	BaseScreens.dispatch_tab = 0
	game.close_modal()
	game.open_station("outbound")
	check("the outbound page lists the taken 交付 cards, no plain delivery", not _contains_text(game.menu, "直接交付") and _contains_text(game.menu, "未封装源石原矿"))
	game.close_modal()
	game.base.board = ContractBoard.new()
	await step(2)
	check("nothing taken shows the empty state", game.warehouse_view.board_state() == "empty")

	# Saves keep the board; a save from before the board brings its orders over.
	game.base.board = board_with(["log_trinkets"])
	game.save_path = "user://board_TEST_ONLY.json"
	game.save_enabled = true
	game.save_base()
	game.base = BaseState.new()
	game.load_base()
	check("save keeps the board", game.base.board.active.size() == 1 and game.base.board.active[0].id == "log_trinkets")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	parsed.base.erase("contract_board")
	parsed.base["orders"] = [{"id": "eng_bolts", "state": "open", "delivered": []}, null]
	var file := FileAccess.open(game.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()
	game.load_base()
	check("an old save's open order comes over as a taken card", game.base.board.active.size() == 1 and game.base.board.active[0].id == "eng_bolts")
	parsed.base.erase("orders")
	file = FileAccess.open(game.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()
	game.load_base()
	check("a save with neither starts with the first contract", game.base.board.active.size() == 1 and game.base.board.active[0].type == "recover")
	game.save_enabled = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)

func _has_text(node: Node, text: String) -> bool:
	if node is Label and node.text == text: return true
	for child in node.get_children():
		if _has_text(child, text): return true
	return false

func _contains_text(node: Node, text: String) -> bool:
	if (node is Label or node is Button) and text in node.text: return true
	for child in node.get_children():
		if _contains_text(child, text): return true
	return false
