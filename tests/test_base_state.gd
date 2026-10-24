extends SceneTree

## B1 of 基地玩法策划案_v1_0.md: where every item at the base is (§3.1), what
## settlement sends where (§3.2), warehouse capacity (§3.6, as 仓库修订 用户
## 2026-10-23 made it: one count of cells, no crates or staging), and save
## version 2 with migration from version 1 (§6.2).

var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func item(name: String, category: Item.Category, w: int = 1, h: int = 1) -> Item:
	return Item.create(name, category, w, h, 1.0)

## Every item in exactly one place: the base's lists plus the loadout.
func each_once(game: GameManager, expected: Array) -> bool:
	var all: Array = game.base.all_items()
	all.append_array(game.carried_items())
	# Flasks issued free at departure (药剂进背包) are not part of what is tracked here.
	all = all.filter(func(x): return not x.is_potion())
	for x in expected:
		if all.count(x) != 1: return false
	return all.size() == expected.size()

func run() -> void:
	await rules()
	await through_game()
	print("BASE STATE FAILURES: %d" % failures)
	quit(1 if failures else 0)

func rules() -> void:
	var base := BaseState.new()
	var sword := item("剑", Item.Category.WEAPON, 2, 1)
	var plate := item("甲", Item.Category.ARMOR, 2, 2)
	# 仓库修订 (用户 2026-10-23): one warehouse, its cells set by 仓储部, any kind in any cell.
	check("starts with 60 cells, the same for every kind", range(4).all(func(c): return base.capacity(c) == 60) and base.capacity() == 60)
	check("an item arrives once, straight into the warehouse", base.receive(sword) and not base.receive(sword) and base.location_of(sword) == "shelf")
	check("arrivals are counted one cell each", base.receive(plate) and base.shelf_count() == 2 and base.all_items().size() == 2)
	check("taking it out and putting it back", base.take_from_shelf(sword) and base.location_of(sword) == "" and base.store(sword) == "shelf" and base.location_of(sword) == "shelf")
	check("removing takes it out of the base", base.remove_item(plate) and base.location_of(plate) == "" and not base.remove_item(plate))

	# A full warehouse refuses from the loadout; the item stays where it was.
	var full := BaseState.new()
	for i in range(60): full.shelf.append(item("库存%d" % i, Item.Category.WEAPON))
	var extra := item("第61件", Item.Category.TRINKET)
	check("a full warehouse refuses to store", full.store_target(extra) == "" and full.store(extra) == "" and full.location_of(extra) == "")
	check("arrivals still come in over the count, nothing that comes home is lost", full.receive(extra) and full.shelf_count() == 61)
	full.set_facility("warehouse", 2)
	check("仓储部 Lv2 doubles the room", full.capacity() == 120 and full.shelf_has_room())

	# Stacks: a matching stack takes a stack even when the cells are full.
	var stacks := BaseState.new()
	var bolts := MaterialCatalog.create("螺栓", 1)
	stacks.shelf.append(bolts)
	for i in range(59): stacks.shelf.append(item("填%d" % i, Item.Category.TRINKET))
	var more := MaterialCatalog.create("螺栓", 1)
	check("a full warehouse still merges onto a stack with room", stacks.store(more) == "shelf" and bolts.quantity == 2 and stacks.shelf_count() == 60)
	bolts.set_quantity(bolts.max_stack)
	var over := MaterialCatalog.create("螺栓", 1)
	check("at ×1 a full stack takes no more", stacks.store(over) == "")

	# Save round trip keeps every item and uid.
	var saved := BaseState.new()
	var a := item("A", Item.Category.WEAPON)
	var b := item("B", Item.Category.MATERIAL)
	saved.shelf.append(a)
	saved.receive(b)
	saved.set_facility("warehouse", 3)
	var loaded := BaseState.new()
	var seen := {}
	loaded.load_data(JSON.parse_string(JSON.stringify(saved.to_data())), seen)
	var places := loaded.all_items().map(func(x): return [x.uid, loaded.location_of(x)])
	check("save round trip keeps each item and 仓储部's level",
		places.has([a.uid, "shelf"]) and places.has([b.uid, "shelf"]) and loaded.all_items().size() == 2 and loaded.capacity() == 220)
	var again := BaseState.new()
	again.load_data(JSON.parse_string(JSON.stringify(saved.to_data())), seen)
	check("already-loaded uids are not loaded twice", again.all_items().is_empty())

	# Version 1 migration: everything into the warehouse, over its count if need be.
	var old: Array = []
	for i in range(70): old.append(item("旧武器%d" % i, Item.Category.WEAPON).to_data())
	old.append(item("旧材料", Item.Category.MATERIAL).to_data())
	var migrated := BaseState.new()
	migrated.migrate_v1(old, {})
	check("v1 stash migrates into the warehouse, none lost", migrated.shelf_count() == 71 and migrated.all_items().size() == 71)

func through_game() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	# Loadout: an equipped weapon, a packed trinket, a safe-bag material.
	var blade := item("随身刀", Item.Category.WEAPON, 2, 1)
	var charm := item("随身挂饰", Item.Category.TRINKET)
	var kit := item("随身材料", Item.Category.MATERIAL)
	game.player.equip(blade)
	game.inventory.try_add(charm)
	game.safe_bag.try_add(kit)
	await game.start_contract("mine")
	var found := FieldCatalog.roll_item("mine", 2, game.rng)
	var found_safe := item("袋中新物", Item.Category.MATERIAL)
	var found_gear := item("现场换上的甲", Item.Category.ARMOR, 2, 2)
	check("loot records the region it was found in", found.origin_region == "mine" and FieldCatalog.exclusive("snow").origin_region == "snow")
	game.inventory.try_add(found)
	game.safe_bag.remove(kit)
	game.safe_bag.try_add(found_safe)
	game.inventory.try_add(kit)
	game.player.equip(found_gear)
	game.settle(true)
	await step(2)
	var everything := [blade, charm, kit, found, found_safe, found_gear]
	check("extraction: gear she set out with stays on her, equipped stays equipped",
		game.player.equipped.get(Item.Category.WEAPON) == blade and game.inventory.items.has(charm) and game.inventory.items.has(kit))
	# 仓库修订: finds stay in her bags (and on her) until settlement's 仓库 page puts them away.
	check("extraction: everything found stays where she carried it, including gear equipped on the way",
		game.inventory.items.has(found) and game.safe_bag.items.has(found_safe) and game.player.equipped.get(Item.Category.ARMOR) == found_gear
		and [found, found_safe, found_gear].all(func(x): return game.base.location_of(x) == ""))
	check("extraction: every item in exactly one place", each_once(game, everything))
	check("protections and run flags are cleared", everything.all(func(x): return not x.insured and not x.carried_in))
	check("nothing goes straight into the warehouse", game.stash.is_empty())
	game.settle(true)
	check("settling again changes nothing", each_once(game, everything) and game.stash.is_empty())

	# Death: kept things stay on her; insured gear waits in the queue; the rest is lost.
	await game.start_contract("city")
	var safe_find := item("安全袋新物", Item.Category.MATERIAL)
	var lost_find := item("遗失新物", Item.Category.TRINKET)
	game.safe_bag.try_add(safe_find)
	game.inventory.try_add(lost_find)
	blade.insured = true
	game.player.hp = -1
	await step(2)
	check("death: insured gear she carried in waits in the insurance queue (保全系统修订案 §3)", game.in_base and game.player.equipped.get(Item.Category.WEAPON) == null
		and game.base.insurance_queue.any(func(e): return e.item == blade and int(e.due) - BaseState.now() >= 2 * 3600 - 5 and int(e.due) - BaseState.now() <= 4 * 3600) and not blade.insured)
	check("death: a find in the safe bag stays in the safe bag", game.safe_bag.items.has(safe_find) and game.base.location_of(safe_find) == "")
	check("death: unprotected items are gone from everywhere",
		game.base.location_of(lost_find) == "" and not game.carried_items().has(lost_find)
		and game.base.location_of(charm) == "" and not game.carried_items().has(charm))
	check("death: kit in the pack was not protected and is lost", not game.carried_items().has(kit))
	for e in game.base.insurance_queue: e.due = 0
	check("death: insured gear arrives in the warehouse when its time comes", game.base.tick_insurance().has(blade) and game.base.location_of(blade) == "shelf"
		and game.base.insurance_queue.is_empty())
	game.base.shelf.erase(blade)

	# Storing, bringing and selling through the game.
	check("storing from the safe bag goes into the warehouse", game.store_item(safe_find) and game.base.location_of(safe_find) == "shelf" and not game.safe_bag.items.has(safe_find))
	check("bringing it puts it in the pack", game.bring_item(safe_find) and game.inventory.items.has(safe_find) and game.base.location_of(safe_find) == "")
	check("a stored item can be sold", game.store_item(safe_find) and game.sell(safe_find) and game.base.location_of(safe_find) == "")

	# A pack too full to take an item: it stays in the warehouse.
	var bulky := item("大件", Item.Category.ARMOR, 2, 2)
	game.base.shelf.append(bulky)
	var fillers: Array[Item] = []
	while true:
		var f := item("填充", Item.Category.MATERIAL)
		if not game.inventory.try_add(f): break
		fillers.append(f)
	check("a full pack refuses and the item stays in the warehouse", not game.bring_item(bulky) and game.base.location_of(bulky) == "shelf")
	for f in fillers: game.inventory.remove(f)

	# Save version 2 round trip through the game, then a version 1 file.
	game.save_path = "user://base_state_TEST_ONLY.json"
	game.save_enabled = true
	game.save_base()
	var before := game.base.all_items().map(func(x): return [x.uid, game.base.location_of(x)])
	before.sort()
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check("saves are version 3 with the base section", int(parsed.version) == 3 and parsed.has("base") and not parsed.has("stash"))
	game.base = BaseState.new()
	game.load_base()
	var after := game.base.all_items().map(func(x): return [x.uid, game.base.location_of(x)])
	after.sort()
	check("v2 reload restores every base item to its place", before == after and not before.is_empty())
	var v1 := {"version": 1, "gold": 99, "loadout": [], "active_contract": false, "settlement": [], "rng_state": "1",
		"stash": [item("旧档武器", Item.Category.WEAPON).to_data(), item("旧档材料", Item.Category.MATERIAL).to_data()]}
	var file := FileAccess.open(game.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1))
	file.close()
	game.load_base()
	check("a version 1 save loads onto the shelves (资金 ×100 → 龙门币)", game.gold == 9900 and game.stash.size() == 2 and game.base.all_items().size() == 2)
	game.save_enabled = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)
	game.queue_free()
	await step(2)
