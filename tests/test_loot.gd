extends SceneTree

## Drops (掉落物策划案_v1_0.md §8): PRTS materials, enemy-specific tables,
## source ratios, elite guarantees, points of interest and their quota, quality,
## the depth tier cap, bad-luck protection, stacking pickup, warehouse merging,
## unit-counted orders and construction material costs.

var game: GameManager
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func ctx(region: String, depth: int, seed: int, pity: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return {"region": region, "depth": depth, "reward": 0.0, "rng": rng, "pity": pity}

## Puts `cost` on the shelf (one item per unit for supplies that do not stack).
func give(cost: Dictionary) -> void:
	for id in cost:
		var left := int(cost[id])
		while left > 0:
			var m := MaterialCatalog.create(id, left)
			game.base.shelf.append(m)
			left -= m.quantity

func items_of(drops: Array) -> Array:
	return drops.filter(func(d): return d.has("item")).map(func(d): return d.item)

func run() -> void:
	# --- Tables ---------------------------------------------------------------
	var all_prts := true
	for type in LootTables.ENEMY_MATERIALS:
		for tier in ["common", "uncommon", "rare"]:
			for entry in LootTables.ENEMY_MATERIALS[type][tier]:
				if not MaterialCatalog.MATERIALS.has(entry[0]): all_prts = false
	check("every enemy material is a PRTS item in the catalog", all_prts)
	var stack_ok := true
	for id in MaterialCatalog.MATERIALS:
		var m := MaterialCatalog.create(id, 999)
		var star := MaterialCatalog.star(id)
		var data: Dictionary = MaterialCatalog.MATERIALS[id]
		if m.max_stack != int(data.get("stack", MaterialCatalog.STACK[star])) or m.quantity != m.max_stack or m.value != m.unit_value * m.quantity: stack_ok = false
		# 赤金 overrides its stack and value as the in-run money (经济修订案 §2).
		if not MaterialCatalog.is_common(id) and not data.has("stack") and (m.max_stack != MaterialCatalog.STACK[star] or m.unit_value != MaterialCatalog.UNIT_VALUE[star]): stack_ok = false
	check("stack size and value follow rarity (PRTS) or the supply's own figures", stack_ok)

	# Enemies drop only their own materials.
	var own := true
	var c := ctx("city", 1, 11)
	for i in range(400):
		for item in items_of(LootTables.enemy_drops("brawler", false, false, c)):
			if item.is_stackable():
				var allowed := []
				for tier in ["common", "uncommon", "rare"]:
					for e in LootTables.ENEMY_MATERIALS.brawler[tier]: allowed.append(e[0])
				if not item.material_id in allowed: own = false
	check("a brawler drops only brawler materials", own)

	# Source ratios over many normal kills.
	var counts := {"none": 0, "mat": 0, "gold": 0, "gear": 0}
	c = ctx("city", 1, 12)
	var n := 4000
	for i in range(n):
		var drops := LootTables.enemy_drops("thug", false, false, c)
		if drops.is_empty(): counts.none += 1
		elif drops[0].has("gold"): counts.gold += 1
		elif drops[0].item.is_stackable(): counts.mat += 1
		else: counts.gear += 1
	check("normal kills: ~12% nothing, ~60% material, ~20% gold, ~8% gear",
		absf(counts.none / float(n) - 0.12) < 0.03 and absf(counts.mat / float(n) - 0.60) < 0.04
		and absf(counts.gold / float(n) - 0.20) < 0.03 and absf(counts.gear / float(n) - 0.08) < 0.02, counts)
	var slug_gear := false
	for i in range(500):
		for item in items_of(LootTables.enemy_drops("slug", false, false, c)):
			if item.is_equippable(): slug_gear = true
	check("infected slugs never drop gear", not slug_gear)
	var guard_empty := false
	for i in range(300):
		if LootTables.enemy_drops("thug", false, true, c).is_empty(): guard_empty = true
	check("guards always drop something", not guard_empty)

	# Elites: three picks plus the guaranteed 固源岩组.
	var elite_ok := true
	c = ctx("city", 2, 13)
	for i in range(200):
		var drops := LootTables.enemy_drops("elite", true, false, c)
		if drops.size() < 4 or not items_of(drops).any(func(x): return x.material_id == "固源岩组"): elite_ok = false
	check("elites drop at least 4 things including 固源岩组", elite_ok)

	# Weapons are named after what the enemy carries.
	var named := true
	c = ctx("snow", 1, 14)
	for i in range(800):
		for item in items_of(LootTables.enemy_drops("ice_hunter", false, false, c)):
			if item.category == Item.Category.WEAPON and item.special.is_empty() and item.item_name != "猎刀": named = false
	check("ice hunters drop 猎刀", named)

	# Quality distribution for equipment boxes: 50 / 38 / 12.
	var q := [0, 0, 0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	for i in range(5000): q[LootTables.roll_quality("box", 0.0, rng)] += 1
	check("box quality ≈ 50/38/12", absf(q[0] / 5000.0 - 0.5) < 0.03 and absf(q[2] / 5000.0 - 0.12) < 0.02, q)
	var vault_common := 0
	for i in range(1000): if LootTables.roll_quality("vault", 0.0, rng) == 0: vault_common += 1
	check("vault chests never roll common", vault_common == 0)

	# Depth caps affix tiers: no Ⅲ before segment 3.
	var max_tier_shallow := 0
	var max_tier_deep := 0
	for i in range(600):
		for mod in LootTables.roll_equipment(Item.Category.WEAPON, "x", "city", 1, 2, rng).modifiers:
			max_tier_shallow = maxi(max_tier_shallow, mod.tier)
		for mod in LootTables.roll_equipment(Item.Category.WEAPON, "x", "city", 4, 2, rng).modifiers:
			max_tier_deep = maxi(max_tier_deep, mod.tier)
	check("tier Ⅲ only from segment 3", max_tier_shallow <= 1 and max_tier_deep == 2, [max_tier_shallow, max_tier_deep])

	# Points of interest.
	var box_ok := true
	var base_ok := true
	c = ctx("mine", 1, 16)
	for i in range(100):
		for item in items_of(LootTables.container_drops("weapon_box", c)):
			if item.category != Item.Category.WEAPON: box_ok = false
		for item in items_of(LootTables.container_drops("construction", c)):
			if str(MaterialCatalog.MATERIALS[item.material_id].kind) != "base": base_ok = false
		for item in items_of(LootTables.container_drops("armor_box", c)):
			if item.category != Item.Category.ARMOR and item.exclusive_region.is_empty(): box_ok = false
	check("weapon boxes give weapons, armour boxes armour", box_ok)
	check("construction piles give only base materials", base_ok)
	var hardware := true
	var cabinet := true
	var medic := true
	for i in range(100):
		if not items_of(LootTables.container_drops("construction", c)).any(func(x): return x.material_id in ["螺栓", "螺母", "钉子"]): hardware = false
		var e := items_of(LootTables.container_drops("electronics", c))
		if not e.any(func(x): return x.material_id == "电线") or not e.all(func(x): return MaterialCatalog.group(x.material_id) == "电子"): cabinet = false
		if not items_of(LootTables.container_drops("medical", c)).any(func(x): return x.material_id == "医用耗材包"): medic = false
	check("construction piles always give hardware", hardware)
	check("electronics cabinets give only electronics, always wire", cabinet)
	check("medical cabinets always give 医用耗材包", medic)
	var vein := items_of(LootTables.container_drops("ore_vein", c))
	check("ore veins always give 源岩 and 固源岩", vein.any(func(x): return x.material_id == "源岩") and vein.any(func(x): return x.material_id == "固源岩"))
	var quota := true
	for region in ["mine", "city", "snow"]:
		for i in range(50):
			rng.seed = 100 + i
			var plan := LootTables.plan_points(region, 5, rng)
			if plan.size() != 5 or not plan.has("weapon_box") or plan.filter(func(k): return LootTables.POI[k].base).size() < 2: quota = false
			if plan.any(func(k): return float(LootTables.POI[k].region.get(region, 0.0)) <= 0.0): quota = false
	check("each segment: a weapon box, two base points, all native to the region", quota)

	# Bad-luck protection.
	var pity := {"rare_gear": 0.0, "rare_material": 0.0}
	c = ctx("city", 1, 17, pity)
	c.rng.seed = 17
	var rose := false
	for i in range(30):
		var rarity := LootTables._quality_with_pity("box", c, 0.0, true)
		if rarity < 2 and pity.rare_gear > 0.0: rose = true
		if rarity == 2:
			check("rare gear resets the pity counter", pity.rare_gear == 0.0)
			break
	check("pity rises after non-rare effective drops", rose)
	pity.rare_gear = 5.0
	LootTables._quality_with_pity("box", c, 0.0, true)
	check("pity never passes its cap when it rises", pity.rare_gear <= LootTables.RARE_GEAR_PITY_CAP or pity.rare_gear == 0.0)
	var before := float(pity.get("rare_gear", 0.0))
	LootTables._quality_with_pity("normal", c, 0.0, false)
	check("ordinary kills leave the gear pity alone", float(pity.rare_gear) == before)

	# --- In the game ---------------------------------------------------------------
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(4)
	await game.start_contract("city")
	await step(2)
	var boxes := game.get_tree().get_nodes_in_group("loot_containers")
	check("supply pockets are typed points of interest", boxes.size() > 0 and boxes.all(func(b): return b is LootContainer and LootTables.POI.has(b.kind)))
	check("the segment has a weapon box", boxes.any(func(b): return b.kind == "weapon_box"))
	var box: LootContainer = boxes[0]
	game._clear_field()
	box = LootContainer.new()
	box.game = game
	box.kind = "weapon_box"
	game.add_child(box)
	box.global_position = game.player.global_position + Vector3(1.0, 0, 0)
	await step(1)
	game._interact()
	check("E next to a box starts opening it", box.is_channeling())
	game.player.global_position += Vector3(6, 0, 0)
	await step(2)
	check("walking away interrupts", not box.is_channeling() and not box.opened)
	game.player.global_position = box.global_position + Vector3(-1.0, 0, 0)
	game._interact()
	for i in range(80):
		await step(1)
		if box.opened: break
	check("standing still opens it after the channel", box.opened)
	var spilled := game.get_tree().get_nodes_in_group("loot").filter(func(l): return l.game == game and l.item != null)
	check("its weapons spill on the ground", spilled.size() > 0 and spilled.any(func(l): return l.item.category == Item.Category.WEAPON))
	game._interact()
	check("an opened box does not open again", not box.is_channeling())

	# Enemy deaths use the enemy's table.
	game._clear_field()
	var enemy := game._spawn_enemy(game.player.global_position + Vector3(4, 0, 0), false, false, "brawler")
	game.rng.seed = 3
	var before_loot := game.get_tree().get_nodes_in_group("loot").size()
	for i in range(10): game.spawn_enemy_drops(enemy)
	check("enemy deaths scatter drops", game.get_tree().get_nodes_in_group("loot").size() > before_loot)

	# Stacking pickup.
	game._clear_field()
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	var a := MaterialCatalog.create("代糖", 12)
	check("first stack picked up", game.try_collect(a) and game.inventory.count_material("代糖") == 12)
	var b := MaterialCatalog.create("代糖", 15)
	check("second stack merges and spills into a new cell", game.try_collect(b) and game.inventory.count_material("代糖") == 27
		and game.inventory.items.filter(func(x): return x.material_id == "代糖").size() == 2)
	# Fill every cell, then offer more.
	var filler := 0
	while game.inventory.try_add(Item.create("填充", Item.Category.TRINKET, 1, 1)): filler += 1
	var stack: Item = game.inventory.items.filter(func(x): return x.material_id == "代糖")[1]
	var room := stack.room()
	var c3 := MaterialCatalog.create("代糖", 20)
	var took := game.try_collect(c3)
	check("a full pack takes only what fits; the rest stays", not took and c3.quantity == 20 - room and game.inventory.count_material("代糖") == 27 + room, [room, c3.quantity])
	check("the message says how much was left", "留在地上" in game.message)
	var ground := Loot.new()
	ground.game = game
	ground.item = MaterialCatalog.create("碳素组", 1)
	game.add_child(ground)
	ground.global_position = game.player.global_position
	await step(3)
	check("a drop that does not fit stays on the ground", is_instance_valid(ground) and not ground.is_queued_for_deletion())
	check("the stack value is unit × quantity", stack.value == stack.unit_value * stack.quantity)
	var round_trip := Item.from_data(stack.to_data())
	check("stacks save their material and quantity", round_trip.material_id == "代糖" and round_trip.quantity == stack.quantity and round_trip.max_stack == 20)

	# --- At the base ---------------------------------------------------------------
	game.inventory.items.clear()
	game.settle(true)
	await step(2)
	check("back at the base", game.in_base)
	var base: BaseState = game.base
	base.shelf.clear()
	base.staging.clear()
	base.crates.clear()
	base.shelf.append(MaterialCatalog.create("碳", 15))
	var more := MaterialCatalog.create("碳", 8)
	check("storing merges onto the shelf stack", base.store(more) == "shelf" and base.shelf.filter(func(x): return x.material_id == "碳").size() == 2
		and game.material_count("碳") == 23)
	base.staging.append(MaterialCatalog.create("碳", 2))
	var staged: Item = base.staging[0]
	check("shelving from staging merges too", base.shelve(staged) and base.shelf.filter(func(x): return x.material_id == "碳").size() == 2 and game.material_count("碳") == 25)
	var save := base.to_data()
	base.loot_pity.rare_gear = 0.12
	save = base.to_data()
	var copy := BaseState.new()
	copy.load_data(save, {})
	check("pity survives a save", is_equal_approx(float(copy.loot_pity.rare_gear), 0.12))

	# Orders count units.
	base.orders.slots = [{"id": "eng_carbon", "state": "open", "delivered": []}, null]
	var big: Item = base.shelf.filter(func(x): return x.material_id == "碳" and x.quantity == 20)[0]
	var gold_before := game.gold
	check("a 20-stack fills an 8-unit order", game.deliver_to_order(0, big) and base.orders.slots[0].state == "done")
	check("only 8 units left the stack", big.quantity == 12 and base.shelf.has(big))
	check("the order paid 交付价 × 8 × 1.5", game.gold - gold_before == roundi(Economy.price(MaterialCatalog.create("碳", 8)) * 1.5), game.gold - gold_before)
	base.orders.slots = [{"id": "eng_carbon", "state": "open", "delivered": []}, null]
	var small: Item = base.shelf.filter(func(x): return x.material_id == "碳" and x.quantity == 5)[0]
	check("a smaller stack counts its units", game.deliver_to_order(0, small) and base.orders.remaining(0) == 3 and not base.shelf.has(small))
	check("other materials do not match", not base.orders.matches(0, MaterialCatalog.create("碳素", 1)))
	check("the order text names the PRTS item", "碳" in BaseCatalog.order_text("eng_carbon"))

	# Construction takes materials.
	game.gold = 500000
	game._grant(0, 200)
	base.shelf.clear()
	check("racks need their materials", not game.build_rack(Item.Category.WEAPON) and "缺少" in game.rack_refusal(Item.Category.WEAPON))
	base.shelf.append(MaterialCatalog.create("螺栓", 10))
	base.shelf.append(MaterialCatalog.create("金属板", 2))
	var g := game.gold
	check("with 螺栓×4 + 金属板×2 the rack is built", game.build_rack(Item.Category.WEAPON) and game.gold == g - BaseCatalog.RACK_PRICES[1]
		and game.material_count("螺栓") == 6 and game.material_count("金属板") == 0)
	check("the drone needs a micro motor", not game.buy_drone() and "微型电机" in game.drone_refusal())
	give({"电路板": 2, "蓄电池": 2, "家具零件": 2})
	game.inventory.try_add(MaterialCatalog.create("微型电机", 1))
	check("with them it is bought, taking the motor from the pack", game.buy_drone() and game.material_count("微型电机") == 0
		and game.material_count("电路板") == 0 and not game.inventory.items.any(func(x): return x.material_id == "微型电机"))
	give({"帆布": 3, "胶带": 2, "碳": 4})
	check("the pack expansion uses 帆布×3 + 胶带×2 + 碳×2", game.buy_pack_upgrade() and game.material_count("碳") == 2 and game.material_count("帆布") == 0)

	# Common supplies (基建资源策划案).
	var battery := MaterialCatalog.create("车用蓄电池", 5)
	check("a car battery does not stack and takes 3×2", not battery.is_stackable() and battery.quantity == 1 and battery.width == 3 and battery.height == 2 and battery.value == 120)
	var bolts := MaterialCatalog.create("螺栓", 99)
	check("bolts stack to 30", bolts.quantity == 30 and bolts.description.begins_with("通用物资 ★1"))
	check("PRTS materials keep their label", MaterialCatalog.create("碳", 1).description.begins_with("PRTS ★2"))
	give({"燃料罐": 2})
	check("non-stacking supplies are counted and taken one by one", game.material_count("燃料罐") == 2 and game.consume_materials({"燃料罐": 2}) and game.material_count("燃料罐") == 0)
	base.orders.slots = [{"id": "eng_bolts", "state": "open", "delivered": []}, null]
	var pile := MaterialCatalog.create("螺栓", 30)
	base.shelf.append(pile)
	check("the bolts order takes 12 of a 30-stack", game.deliver_to_order(0, pile) and pile.quantity == 18 and base.orders.slots[0].state == "done")

	print("\n%d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
