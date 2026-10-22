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
		if not MaterialCatalog.is_common(id) and not data.has("stack") and not data.has("value") and (m.max_stack != MaterialCatalog.STACK[star] or m.unit_value != MaterialCatalog.UNIT_VALUE[star]): stack_ok = false
	check("stack size and value follow rarity (PRTS) or the supply's own figures", stack_ok)

	# Enemies drop only their own materials.
	var own := true
	var c := ctx("city", 1, 11)
	for i in range(400):
		for item in items_of(LootTables.enemy_drops("brawler", false, false, c)):
			if item.is_stackable() and not item.is_potion():
				var allowed := []
				for tier in ["common", "uncommon", "rare"]:
					for e in LootTables.ENEMY_MATERIALS.brawler[tier]: allowed.append(e[0])
				# Growth materials (精英化案 §3.2) drop from everyone.
				for e in LootTables.GROWTH_DROPS.normal: allowed.append(e[0])
				if not item.material_id in allowed: own = false
	check("a brawler drops only brawler materials", own)

	# Source ratios over many normal kills.
	var counts := {"none": 0, "mat": 0, "gold": 0, "gear": 0}
	c = ctx("city", 1, 12)
	var n := 4000
	for i in range(n):
		# The odd 标准急救剂 (POTION_DROP) is counted on its own below.
		var drops := LootTables.enemy_drops("thug", false, false, c).filter(func(d): return not (d.has("item") and d.item.is_potion()))
		if drops.is_empty(): counts.none += 1
		elif drops[0].has("gold"): counts.gold += 1
		elif drops[0].item.is_stackable(): counts.mat += 1
		else: counts.gear += 1
	# 用户 2026-10-17: 爆率降低 — a normal enemy drops something about 37% of the time.
	var w: Array = LootTables.ENEMY_SOURCE.normal.weights
	var total: float = w.reduce(func(a, b): return a + b, 0.0)
	check("normal kills follow the table: ~63% nothing, ~23% material, ~8% gold, ~7% gear",
		# The odd 技巧概要 (3%) or exclusive (0.5%) comes on top of the table.
		absf(counts.none / float(n) - w[0] / total * 0.965) < 0.03 and absf(counts.mat / float(n) - w[1] / total - 0.02) < 0.03
		and absf(counts.gold / float(n) - w[2] / total) < 0.02 and absf(counts.gear / float(n) - w[3] / total) < 0.02, counts)
	var potions := 0
	for i in range(3000):
		potions += LootTables.enemy_drops("thug", false, false, c).filter(func(d): return d.has("item") and d.item.is_potion()).size()
	check("now and then a normal enemy drops a 标准急救剂 (~3%)", absf(potions / 3000.0 - LootTables.POTION_DROP.normal) < 0.015, potions)
	var slug_gear := false
	for i in range(500):
		for item in items_of(LootTables.enemy_drops("slug", false, false, c)):
			# Its own exclusive (蜕下的虫壳, 装备扩充 §5.1) is the one exception.
			if item.is_equippable() and item.named_kind() != "exclusive": slug_gear = true
	check("infected slugs never drop gear but their exclusive", not slug_gear)
	var guard_empty := 0
	for i in range(1000):
		if LootTables.enemy_drops("thug", false, true, c).is_empty(): guard_empty += 1
	# 62.5% from the table, a little more with chips, books and exclusives.
	check("guards drop something about 2/3 of the time", 1.0 - guard_empty / 1000.0 > 0.6 and 1.0 - guard_empty / 1000.0 < 0.73)

	# 用户 2026-10-17: 一个敌人最多爆一个材料 + 一件装备，材料只会 ×1 — elites,
	# guards, normal enemies and bosses alike (赤金 and flasks apart).
	var capped := true
	var elite_mat := true
	for kind in [["elite", true, false, false], ["thug", false, true, false], ["thug", false, false, false], ["breacher", true, false, true]]:
		c = ctx("city", 6, 13)
		c.boss = kind[3]
		for i in range(300):
			var items := items_of(LootTables.enemy_drops(kind[0], kind[1], kind[2], c)).filter(func(x): return not x.is_potion())
			var mats := items.filter(func(x): return not x.is_equippable())
			var gear := items.filter(func(x): return x.is_equippable())
			if mats.size() > 1 or gear.size() > 1 or mats.any(func(x): return x.quantity != 1): capped = false
			if kind[0] == "elite" and mats.size() != 1: elite_mat = false
	check("an enemy drops at most one material ×1 and one piece of gear", capped)
	check("an elite always drops one material (its 固源岩组 at least)", elite_mat)

	# Weapons are named after what the enemy carries.
	var named := true
	c = ctx("snow", 1, 14)
	for i in range(800):
		for item in items_of(LootTables.enemy_drops("ice_hunter", false, false, c)):
			if item.category == Item.Category.WEAPON and item.special.is_empty() and item.item_name != "冰原猎铳": named = false
	check("ice hunters drop 冰原猎铳", named)

	# Quality distribution for equipment boxes: 50 / 38 / 12.
	var q := [0, 0, 0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	for i in range(5000): q[LootTables.roll_quality("box", 0.0, rng)] += 1
	# 稀有概率 ÷10 (用户 2026-10-18): 12% rare → 1.2%, common and fine keep their 50:38.
	check("box quality ≈ 56.1/42.7/1.2", absf(q[0] / 5000.0 - 0.561) < 0.03 and absf(q[2] / 5000.0 - 0.012) < 0.006, q)
	var vault_common := 0
	for i in range(1000): if LootTables.roll_quality("vault", 0.0, rng) == 0: vault_common += 1
	check("vault chests never roll common", vault_common == 0)

	# 复利数值改造清单 B: an affix rolls in its piece's rarity band; within a
	# tier, the floor's tenth rolls higher than its first.
	var gold_bands := true
	var early := 0.0
	var late := 0.0
	for i in range(600):
		var first := LootTables.roll_equipment(Item.Category.WEAPON, "x", "city", 11, 2, rng)
		var tenth := LootTables.roll_equipment(Item.Category.WEAPON, "x", "city", 20, 2, rng)
		for mod in first.modifiers: if mod.is_random_affix(): gold_bands = gold_bands and mod.tier == 2
		early += first.power_position()
		late += tenth.power_position()
	check("gold affixes roll in the gold band; a tier's tenth floor rolls higher than its first", gold_bands and late > early * 1.5, [early / 600.0, late / 600.0])

	# 掉落阶梯 (用户 2026-10-18): deeper floors drop better gear and materials.
	var stairs := []
	for f in range(1, 121): stairs.append(LootTables.stair(f))
	var climbs := true
	for f in range(1, stairs.size()): climbs = climbs and stairs[f] >= stairs[f - 1]
	check("the stair never steps down with depth (floor 11 above floor 10)", climbs and LootTables.stair(11) > LootTables.stair(10), stairs)
	check("steps at floors 1–3, 4–6, 7–9, 10; deep full from floor 40, the top from floor 90", LootTables.stair(3) == 0 and LootTables.stair(4) == 1 and LootTables.stair(7) == 2
		and LootTables.stair(10) == 3 and LootTables.stair(21) == 8 and LootTables.stair(40) == 15 and LootTables.deep(40) == 1.0 and LootTables.deep(90) == 1.0
		and LootTables.stair(90) == LootTables.STAIR_TOP and LootTables.stair(91) == LootTables.STAIR_TOP and LootTables.stair(300) == LootTables.STAIR_TOP)
	var rare_share := func(depth: int, table: String) -> float:
		var r := RandomNumberGenerator.new()
		r.seed = 31
		var hits := 0
		for i in range(40000): if LootTables.roll_quality(table, 0.0, r, depth) == 2: hits += 1
		return hits / 40000.0
	var shallow_rare: float = rare_share.call(1, "normal")
	var mid_rare: float = rare_share.call(15, "normal")
	var deep_rare: float = rare_share.call(40, "normal")
	# 用户 2026-10-18: 以普通敌人装备稀有 5% 为顶 — 2.5% on floor 40, 5% from floor 90.
	var top_rare: float = rare_share.call(90, "normal")
	var mid_top: float = rare_share.call(65, "normal")
	check("a normal enemy's gear is rare ~0.5% on floor 1, ~2.5% on floor 40, 5% from floor 90 on", absf(shallow_rare - 0.005) < 0.0015 and absf(deep_rare - 0.0247) < 0.004
		and mid_rare > shallow_rare and mid_rare < deep_rare and mid_top > deep_rare and mid_top < top_rare and absf(top_rare - 0.05) < 0.005
		and absf(rare_share.call(150, "normal") - top_rare) < 0.005, [shallow_rare, mid_rare, deep_rare, mid_top, top_rare])
	# Along the S curve (复利数值改造清单 B): same ends, slow early, fast mid.
	check("an elite's gear is rare ~2.5% on floor 1, ~7.8% from 90, rising between", absf(rare_share.call(1, "elite") - 0.025) < 0.004 and rare_share.call(40, "elite") > rare_share.call(20, "elite") and rare_share.call(60, "elite") > rare_share.call(40, "elite") and absf(rare_share.call(90, "elite") - 0.0777) < 0.008)
	# Past the top, good prefixes get likelier floor by floor.
	var good_share := func(depth: int) -> float:
		var g := LootTables.past_top(depth)
		var good := PrefixCatalog.grade_weight(1, g) + PrefixCatalog.grade_weight(2, g)
		var all_w := 0.0
		for grade in PrefixCatalog.GRADE_WEIGHTS: all_w += PrefixCatalog.grade_weight(grade, g)
		return good / all_w
	check("good prefixes (+1/+2) stay at 35% down to floor 90", is_equal_approx(good_share.call(1), 0.35) and is_equal_approx(good_share.call(90), 0.35))
	check("then rise floor by floor: 91 > 90, 130 > 91, 250 > 130", good_share.call(91) > good_share.call(90) and good_share.call(130) > good_share.call(91) and good_share.call(250) > good_share.call(130),
		[good_share.call(91), good_share.call(130), good_share.call(250)])
	var rolled_good := func(depth: int) -> float:
		var r := RandomNumberGenerator.new()
		r.seed = 34
		var good := 0
		var seen_n := 0
		for i in range(3000):
			for entry in LootTables.roll_equipment(Item.Category.WEAPON, "x", "city", depth, 1, r).prefixes:
				# Effect families do not follow the grade odds (前缀放大与特效阶等案 §3).
				if not PrefixFamilies.family_of(str(entry.id)).is_empty(): continue
				seen_n += 1
				if int(PrefixCatalog.get_entry(str(entry.id)).grade) >= 1: good += 1
		return good / float(maxi(seen_n, 1))
	var g90: float = rolled_good.call(90)
	var g130: float = rolled_good.call(130)
	check("dropped gear shows it: good prefixes ~35% on floor 90, ~55% on floor 130", absf(g90 - 0.35) < 0.04 and absf(g130 - 0.545) < 0.05, [g90, g130])
	var mat_rare := func(depth: int) -> float:
		var cm := ctx("city", depth, 32)
		var hits := 0
		for i in range(30000):
			cm.pity = {}
			var m := LootTables._enemy_material("thug", cm)
			if m.material_id == "全新装置": hits += 1
		return hits / 30000.0
	var m1: float = mat_rare.call(1)
	var m40: float = mat_rare.call(40)
	check("an enemy's rare material: ~0.3% on floor 1, ~2% from floor 40", absf(m1 - 0.003) < 0.0015 and absf(m40 - 0.0205) < 0.004, [m1, m40])
	var finds := func(depth: int) -> int:
		var cb := ctx("mine", depth, 33)
		var found := 0
		for i in range(20000):
			for d in LootTables.container_drops("ore_vein", cb): if d.has("item") and d.item.material_id == "源石碎片": found += 1
		return found
	var f1: int = finds.call(1)
	var f40: int = finds.call(40)
	check("an ore vein's 源石碎片: ~0.3% on floor 1, ~0.9% from floor 40", absf(f1 / 20000.0 - 0.003) < 0.0015 and absf(f40 / 20000.0 - 0.009) < 0.003, [f1, f40])

	# Points of interest.
	var box_ok := true
	var base_ok := true
	c = ctx("mine", 1, 16)
	for i in range(100):
		for item in items_of(LootTables.container_drops("weapon_box", c)):
			if item.category != Item.Category.WEAPON: box_ok = false
		for item in items_of(LootTables.container_drops("construction", c)):
			# The mine's piles may hold a 源石矿封装器 too (地图特色策划案 §3.3).
			if FeatureCatalog.is_supply(item): continue
			if str(MaterialCatalog.MATERIALS[item.material_id].kind) != "base": base_ok = false
		for item in items_of(LootTables.container_drops("armor_box", c)):
			if not Item.is_armor_slot(item.category) and item.exclusive_region.is_empty(): box_ok = false
	check("weapon boxes give weapons, armour boxes armour", box_ok)
	check("construction piles give only base materials", base_ok)
	var hardware := true
	var cabinet := true
	var medic := true
	for i in range(100):
		if not items_of(LootTables.container_drops("construction", c)).any(func(x): return x.material_id in ["螺栓", "螺母", "钉子"]): hardware = false
		var e := items_of(LootTables.container_drops("electronics", c))
		if not e.any(func(x): return x.material_id == "电线") or not e.all(func(x): return MaterialCatalog.group(x.material_id) == "电子" or x.material_id in ["芯片助剂", "技巧概要·卷1"]): cabinet = false
		if not items_of(LootTables.container_drops("medical", c)).any(func(x): return x.material_id == "医用耗材包"): medic = false
	check("construction piles always give hardware", hardware)
	check("electronics cabinets give only electronics (and the odd 芯片助剂 / 技巧概要), always wire", cabinet)
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
	# Lungmen's districts tilt the kinds: the slums keep medicine and safes,
	# and the weapon box goes to a warehouse yard when there is one.
	var tilted := 0
	var plain := 0
	var yard_box := true
	for i in range(200):
		rng.seed = 900 + i
		tilted += LootTables.plan_points("city", 6, rng, ["slum", "slum", "slum", "slum", "slum", "slum"]).filter(func(k): return k in ["medical", "safe"]).size()
		rng.seed = 900 + i
		plain += LootTables.plan_points("city", 6, rng).filter(func(k): return k in ["medical", "safe"]).size()
		rng.seed = 900 + i
		if LootTables.plan_points("city", 6, rng, ["street", "slum", "yard", "street", "site", "slum"])[2] != "weapon_box": yard_box = false
	check("slum points are medicine and safes far more often", tilted > plain * 2)
	check("the weapon box stands in the warehouse yard", yard_box)

	# Bad-luck protection.
	var pity := {"rare_gear": 0.0, "rare_material": 0.0}
	c = ctx("city", 1, 17, pity)
	c.rng.seed = 17
	var rose := false
	var reset := false
	for i in range(3000):
		var rarity := LootTables._quality_with_pity("box", c, 0.0, true)
		if rarity < 2 and pity.rare_gear > 0.0: rose = true
		if rarity == 2:
			reset = pity.rare_gear == 0.0
			break
	check("rare gear resets the pity counter", reset)
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
	# E opens it at once beside the pack (用户 2026-10-13: 打开容器不需要读条).
	game._interact()
	check("E next to a box opens it at once, with the pack and its grid", box.opened and game.looting == box and game.modal == "inventory" and game._inventory_panel.visible)
	# The field runs on (用户 2026-10-13: 开容器时改为不是暂停的); she stands at the box.
	var stood := game.player.global_position
	game.player.set_move_target(stood + Vector3(4, 0, 0))
	await step(20)
	check("the field runs on while she searches, and she stays at the box", game.simulation_active() and game.hands_busy() and Vector2(game.player.global_position.x - stood.x, game.player.global_position.z - stood.z).length() < 0.2)
	game.notice("测试提示")
	await step(2)
	check("a notice shows over the open pack", game._inventory_panel._notice.visible and game._inventory_panel._notice.text == "测试提示")
	# Then each item is searched in turn (塔科夫's search) into the box's grid.
	var on_ground := func() -> int: return game.get_tree().get_nodes_in_group("loot").filter(func(l): return l.game == game and l.item != null).size()
	var state := box.search_state()
	check("the contents are searched one item at a time (%d to find)" % int(state.get("total", 0)), not state.is_empty() and int(state.found) == 0 and box.storage.items.is_empty() and box.is_searching())
	var first_cell := box.search_cell()
	# 用户 2026-10-17: every item still to find shows as the outline of its cells.
	var outlines := box.pending_rects()
	var placed_pending: Array = box._pending.filter(func(it): return it.grid_x >= 0)
	check("before anything is found, each item's cells are outlined", outlines.size() == placed_pending.size() and outlines.size() > 0
		and placed_pending.all(func(it): return outlines.has(Rect2i(it.grid_x, it.grid_y, it.width, it.height))), [outlines.size(), placed_pending.size()])
	check("the magnifier sits on the top-left item's cell", first_cell == box._pending.map(func(it): return Vector2i(it.grid_x, it.grid_y)).filter(func(v): return v.x >= 0).reduce(func(a, v): return v if v.y < a.y or (v.y == a.y and v.x < a.x) else a))
	for i in range(900):
		await step(1)
		if not box.storage.items.is_empty(): break
	check("the first item turns up in that cell of the box's grid, not on the ground", box.storage.items.size() == 1 and on_ground.call() == 0 and Vector2i(box.storage.items[0].grid_x, box.storage.items[0].grid_y) == first_cell)
	var got: Item = box.storage.items[0]
	var got_rect := Rect2i(got.grid_x, got.grid_y, got.width, got.height)
	check("it fills its outline exactly, and that outline is gone", outlines.has(got_rect) and not box.pending_rects().has(got_rect) and box.pending_rects().size() == outlines.size() - 1)
	for i in range(3000):
		await step(1)
		if box.fully_searched(): break
	check("searched to the end, its weapons wait in the box", box.fully_searched() and box.storage.items.any(func(it): return it.category == Item.Category.WEAPON))
	var in_box := box.storage.items.size()
	game.take_all(box)
	check("taking all moves them into the pack", box.storage.items.size() < in_box and box.looted() == box.storage.items.is_empty())
	game.close_modal()
	check("closing the window ends the looting", game.looting == null and game.modal.is_empty())
	box.storage.items.clear()
	box._refresh()
	game._interact()
	check("an emptied box does not open again", game.looting == null and game.modal.is_empty())
	# Closing the window pauses the search: a construction heap holds several items.
	var heap := LootContainer.new()
	heap.game = game
	heap.kind = "construction"
	game.add_child(heap)
	heap.global_position = game.player.global_position + Vector3(0, 0, 1.0)
	await step(1)
	game._interact()
	for i in range(1500):
		await step(1)
		if int(heap.search_state().get("found", 0)) >= 1: break
	game.close_modal()
	await step(30)
	var found_before: int = heap.search_state().get("found", 0)
	check("closing the window pauses the search and keeps what was found (%d of %d)" % [found_before, int(heap.search_state().get("total", 0))], not heap.is_searching() and found_before >= 1 and not heap.fully_searched() and heap.storage.items.size() >= 1)
	game._interact()
	check("E takes the search up at the next item", heap.is_searching() and int(heap.search_state().found) == found_before and game.looting == heap)
	game.player.invulnerable = false
	game.player.take_damage(30.0)
	await step(2)
	check("a hit shuts the box's window so she can answer it", game.looting == null and game.modal.is_empty() and not heap.is_searching())
	# Near a box it can still use, she sees its yellow rim; walking off clears it.
	game.player.global_position = heap.global_position + Vector3(-1.5, 0, 0)
	await step(2)
	var rim_near: bool = heap._rim_on
	game.player.global_position = heap.global_position + Vector3(-9.0, 0, 0)
	await step(2)
	check("a box she can use wears a yellow rim while she is near it", rim_near and not heap._rim_on)

	# 用户 2026-10-18: 兴趣点里刷的材料不堆叠，一个最多一个，可以重复.
	var singles := true
	var repeats := false
	var cs := ctx("city", 12, 41)
	for kind in ["construction", "depot", "camp", "tool_box", "electronics", "medical", "ore_vein", "vault_base", "safe"]:
		for i in range(200):
			var ids := {}
			for d in LootTables.container_drops(kind, cs):
				if d.has("gold"):
					if not d.get("single", false): singles = false
					continue
				if d.item.category != Item.Category.MATERIAL or d.item.is_potion(): continue
				if d.item.quantity != 1: singles = false
				if ids.has(d.item.material_id): repeats = true
				ids[d.item.material_id] = true
	check("every material from a point of interest is a single one", singles)
	check("the same material can turn up twice in one point of interest", repeats)
	check("a safe's 赤金 is a single bar", game._drop_item({"gold": 600, "single": true}).quantity == 1)

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
	game.base.max_facilities()
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
