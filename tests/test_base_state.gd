extends SceneTree

## B1 of 基地玩法策划案_v1_0.md: where every item at the base is (§3.1), what
## settlement sends where (§3.2), staging (§3.4a), shelf capacity (§3.6), and
## save version 2 with migration from version 1 (§6.2).

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
	var ring := item("戒", Item.Category.TRINKET)
	check("starts with one 12-cell rack per category", range(4).all(func(c): return base.capacity(c) == 12))
	check("crate sizes follow the footprint: 1 small, 2 medium, 3+ large",
		BaseCatalog.crate_size(ring) == 0 and BaseCatalog.crate_size(sword) == 1 and BaseCatalog.crate_size(plate) == 2)
	check("an item arrives once as a sealed crate", base.receive(sword) and not base.receive(sword) and base.location_of(sword) == "crate_sealed")
	check("a sealed crate cannot be shelved or staged", not base.shelve(sword) and not base.stage(sword) and base.location_of(sword) == "crate_sealed")
	check("opening reveals it in place", base.open_crate(sword) and not base.open_crate(sword) and base.location_of(sword) == "crate_open")
	check("shelving takes it out of its crate", base.shelve(sword) and base.location_of(sword) == "shelf" and base.crates.is_empty())
	base.receive(plate)
	base.open_crate(plate)
	check("staging takes an opened crate's item", base.stage(plate) and base.location_of(plate) == "staging")
	check("shelf items cannot be staged directly", not base.stage(sword))
	check("staging items can be shelved later", base.shelve(plate) and base.location_of(plate) == "shelf")
	check("unstaging only works on staging", not base.unstage(sword))

	# A full category refuses with a reason, and the item stays where it was.
	var full := BaseState.new()
	for i in range(12): full.shelf.append(item("武器%d" % i, Item.Category.WEAPON))
	var extra := item("第13把", Item.Category.WEAPON)
	full.receive(extra)
	full.open_crate(extra)
	check("a full zone refuses and says how full: %s" % full.shelve_refusal(extra), not full.shelve(extra) and "12/12" in full.shelve_refusal(extra) and full.location_of(extra) == "crate_open")
	check("other zones are unaffected", full.shelf_has_room(Item.Category.ARMOR))
	full.racks[Item.Category.WEAPON] = 2
	check("a second rack adds 12 cells", full.capacity(Item.Category.WEAPON) == 24 and full.shelve(extra))

	# Storing from the loadout: shelf, else staging, else refused.
	var store := BaseState.new()
	for i in range(12): store.shelf.append(item("饰%d" % i, Item.Category.TRINKET))
	var spare := item("多余饰品", Item.Category.TRINKET)
	check("storing into a full zone falls back to staging", store.store_target(spare) == "staging" and store.store(spare) == "staging")
	for i in range(BaseCatalog.STAGING_CAPACITY - 1): store.staging.append(item("堆%d" % i, Item.Category.MATERIAL))
	var refused := item("放不下", Item.Category.TRINKET)
	check("staging holds about three hauls (%d) and then refuses" % BaseCatalog.STAGING_CAPACITY, store.staging.size() == 72 and store.store(refused) == "" and store.location_of(refused) == "")

	# Save round trip keeps every place, rack count and uid.
	var saved := BaseState.new()
	var a := item("A", Item.Category.WEAPON)
	var b := item("B", Item.Category.MATERIAL)
	var c := item("C", Item.Category.ARMOR)
	var d := item("D", Item.Category.TRINKET)
	saved.shelf.append(a)
	saved.staging.append(b)
	saved.receive(c)
	saved.receive(d)
	saved.open_crate(d)
	saved.racks[Item.Category.MATERIAL] = 3
	var loaded := BaseState.new()
	var seen := {}
	loaded.load_data(JSON.parse_string(JSON.stringify(saved.to_data())), seen)
	var places := loaded.all_items().map(func(x): return [x.uid, loaded.location_of(x)])
	check("save round trip keeps each item's place and the racks",
		places.has([a.uid, "shelf"]) and places.has([b.uid, "staging"]) and places.has([c.uid, "crate_sealed"]) and places.has([d.uid, "crate_open"])
		and loaded.racks[Item.Category.MATERIAL] == 3 and loaded.all_items().size() == 4)
	var again := BaseState.new()
	again.load_data(JSON.parse_string(JSON.stringify(saved.to_data())), seen)
	check("already-loaded uids are not loaded twice", again.all_items().is_empty())

	# Version 1 migration: shelves first, overflow to staging, then opened crates.
	var old: Array = []
	for i in range(30): old.append(item("旧武器%d" % i, Item.Category.WEAPON).to_data())
	old.append(item("旧材料", Item.Category.MATERIAL).to_data())
	var migrated := BaseState.new()
	migrated.migrate_v1(old, {})
	check("v1 stash migrates: 12 weapons shelved, 18 staged, material shelved, none lost",
		migrated.shelf_count(Item.Category.WEAPON) == 12 and migrated.staging.size() == 18
		and migrated.shelf_count(Item.Category.MATERIAL) == 1 and migrated.all_items().size() == 31)
	var flood: Array = []
	for i in range(12 + BaseCatalog.STAGING_CAPACITY + 5): flood.append(item("洪%d" % i, Item.Category.ARMOR).to_data())
	var flooded := BaseState.new()
	flooded.migrate_v1(flood, {})
	check("migration overflow beyond staging lands in opened crates, nothing dropped",
		flooded.crates.size() == 5 and flooded.crates.all(func(x): return x.opened) and flooded.all_items().size() == flood.size())

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
	check("extraction: everything found arrives as sealed crates, including gear equipped on the way",
		[found, found_safe, found_gear].all(func(x): return game.base.location_of(x) == "crate_sealed")
		and game.player.equipped.get(Item.Category.ARMOR) == null)
	check("extraction: every item in exactly one place", each_once(game, everything))
	check("protections and run flags are cleared", everything.all(func(x): return not x.gilded and not x.insured and not x.carried_in))
	check("nothing goes straight onto the shelves", game.stash.is_empty())
	game.settle(true)
	check("settling again changes nothing", each_once(game, everything) and game.base.crates.size() == 3)

	# Death: kept carried-in gear stays on her; kept finds become crates; the rest is lost.
	await game.start_contract("city")
	var safe_find := item("安全袋新物", Item.Category.MATERIAL)
	var lost_find := item("遗失新物", Item.Category.TRINKET)
	game.safe_bag.try_add(safe_find)
	game.inventory.try_add(lost_find)
	blade.gilded = true
	game.player.hp = -1
	await step(2)
	check("death: gilded gear she carried in stays equipped", game.in_base and game.player.equipped.get(Item.Category.WEAPON) == blade and not blade.gilded)
	check("death: a find in the safe bag arrives as a crate", game.base.location_of(safe_find) == "crate_sealed")
	check("death: unprotected items are gone from everywhere",
		game.base.location_of(lost_find) == "" and not game.carried_items().has(lost_find)
		and game.base.location_of(charm) == "" and not game.carried_items().has(charm))
	check("death: kit in the pack was not protected and is lost", not game.carried_items().has(kit))

	# Receiving through the game, and the staging rules.
	var crate_item: Item = game.base.crates[0].item
	check("game opens a crate", game.open_crate(crate_item) and game.base.location_of(crate_item) == "crate_open")
	check("a crate's item cannot be brought or sold", not game.bring_item(crate_item) and not game.sell(crate_item))
	check("staging it works", game.stage_item(crate_item) and game.base.location_of(crate_item) == "staging")
	check("staged items cannot be sold (delivered)", not game.sell(crate_item) and game.base.location_of(crate_item) == "staging")
	check("staged items cannot be brought from the warehouse terminal", not game.bring_item(crate_item))
	check("taking it out at staging puts it in the pack", game.unstage_to_pack(crate_item) and game.inventory.items.has(crate_item) and game.base.location_of(crate_item) == "")
	check("storing it again goes to its shelf", game.store_item(crate_item) and game.base.location_of(crate_item) == "shelf")
	check("a shelved item can be brought and sold", game.bring_item(crate_item) and game.store_item(crate_item) and game.sell(crate_item) and game.base.location_of(crate_item) == "")

	# A pack too full to take a staged item: the item stays staged.
	var bulky := item("大件", Item.Category.ARMOR, 2, 2)
	game.base.staging.append(bulky)
	var fillers: Array[Item] = []
	while true:
		var f := item("填充", Item.Category.MATERIAL)
		if not game.inventory.try_add(f): break
		fillers.append(f)
	check("a full pack refuses and the item stays in staging", not game.unstage_to_pack(bulky) and game.base.location_of(bulky) == "staging")
	for f in fillers: game.inventory.remove(f)

	# Save version 2 round trip through the game, then a version 1 file.
	game.save_path = "user://base_state_TEST_ONLY.json"
	game.save_enabled = true
	game.save_base()
	var before := game.base.all_items().map(func(x): return [x.uid, game.base.location_of(x)])
	before.sort()
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check("saves are version 2 with the base section", int(parsed.version) == 2 and parsed.has("base") and not parsed.has("stash"))
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
	check("a version 1 save loads onto the shelves", game.gold == 99 and game.stash.size() == 2 and game.base.crates.is_empty() and game.base.staging.is_empty())
	game.save_enabled = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)
	game.queue_free()
	await step(2)
