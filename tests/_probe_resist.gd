extends SceneTree
## Not a test — a balance probe for 抗性为王修订案 v0.4. For one region
## (BAL_REGION) and several depths, she wears what the drops give by then (as
## _probe_balance: per slot the best of 0.6 × depth rolls, points, elite rank,
## combat research by depth), in two ways:
##   drop     the gear as it fell (its resistance lines), no inlays
##   planned  the same plus inlays of the depth's tier: two main-element
##            singles, three 全抗, one dual (beats-region + one more), one 防御
## For each it prints her resistances after the 压制, what an ordinary hit
## costs now against the same hit without elements (by the region's element
## mix and the floor's chance), an elite's big hit and a boss's big hit as a
## share of her life, and a real pack fight with elements on and off.
##   set BAL_REGION=mine
##   godot --headless --path . --script res://tests/_probe_resist.gd --fixed-fps 60

const DEPTHS := [1, 12, 32, 52, 72, 92]
const SCALE := 3.0
var game: GameManager
var rig: Node

func _initialize() -> void: call_deferred("run")

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func ticks(n: int) -> void:
	for i in range(n): await physics_frame

func build(depth: int, region: String, planned: bool) -> void:
	var p := game.player
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + depth
	for slot in p.equipped.keys(): p.unequip(slot)
	var pieces := maxi(1, roundi(0.6 * depth))
	for slot in Item.SLOTS:
		var best: Item = null
		for i in range(pieces):
			var elite := rng.randf() < 0.25
			var rarity := LootTables.roll_quality("elite" if elite else "normal", 0.0, rng, rng.randi_range(maxi(1, depth - 9), depth))
			var id := GearCatalog.pick(slot, region, depth, "elite" if elite else "normal", "", rng)
			if id.is_empty(): continue
			var item := LootTables.roll_equipment(slot, str(GearCatalog.BASES[id].name), region, depth, rarity, rng)
			if slot == Item.Category.WEAPON and not GearCatalog.can_wield(p.operator_id, item): continue
			if best == null or item.rarity > best.rarity or (item.rarity == best.rarity and item.power > best.power): best = item
		if best == null and slot == Item.Category.WEAPON:
			for id in GearCatalog.BASES:
				var b: Dictionary = GearCatalog.BASES[id]
				if int(b.category) != Item.Category.WEAPON: continue
				var c := LootTables.roll_equipment(slot, str(b.name), region, depth, Item.GREY, rng)
				if GearCatalog.can_wield(p.operator_id, c):
					best = c
					break
		if best != null:
			best.inlay = {}
			p.equip(best)
	if planned:
		var tier := 0 if depth < 31 else (1 if depth < 61 else 2)
		var main := str(Elements.LOCAL[region])
		var weak := str(Elements.WEAKNESS[region])
		var other: String = Elements.KINDS.filter(func(k): return k != main and k != weak)[0]
		var plan := {Item.Category.HEAD: ["res_one", [main]], Item.Category.AMULET: ["res_one", [main]],
			Item.Category.CHEST: ["res_all", []], Item.Category.RING: ["res_all", []], Item.Category.HANDS: ["res_all", []],
			Item.Category.FEET: ["res_two", [weak, other]], Item.Category.LEGS: ["def", []]}
		for slot in plan:
			var it: Item = p.equipped.get(slot)
			if it != null: it.inlay = {"id": plan[slot][0], "tier": tier, "kinds": plan[slot][1]}
	var prog := p.progress()
	var start := Progression.start_attributes(p.operator_id)
	var attrs := start.duplicate()
	var points := roundi(minf(119.0, 2.0 + depth * 1.95))
	attrs["tec"] = int(start.tec) + points / 2
	attrs["phy"] = int(start.phy) + points - points / 2
	prog.attributes = attrs
	prog.elite = 0 if depth < 31 else (1 if depth < 61 else 2)
	var combat: Array = []
	for id in ResearchCatalog.NODES.keys():
		if ResearchCatalog.is_combat(str(id)): combat.append(str(id))
	combat.sort_custom(func(a, b): return int(ResearchCatalog.NODES[a][1]) < int(ResearchCatalog.NODES[b][1]))
	game.base.research.done = combat.slice(0, roundi(combat.size() * minf(1.0, depth / 80.0)))
	p._recompute_stats()
	p.hp = p.max_hp

func res_line(region: String) -> String:
	var e := game.player.elements
	var main := str(Elements.LOCAL[region])
	var weak := str(Elements.WEAKNESS[region])
	var parts := []
	for k in [main, weak] + Elements.KINDS.filter(func(x): return x != main and x != weak):
		parts.append("%s=%d(gear %d)" % [k, roundi(e.res(k)), roundi(e.res_gear(k))])
	parts.append("arts=%d bleed=%d" % [roundi(game.player.resistance()), roundi(e.res("bleed"))])
	return " ".join(parts)

## Her damage after mitigation and the flat cuts, for a raw hit from `e`.
func landed(e: Enemy, raw: float, kind: String = "phys") -> float:
	var p := game.player
	var amount := p.elements.mitigate(raw, kind, e) * p.elements.taken_mult(e)
	return amount * (1.0 - minf(CombatStats.REDUCTION_CAP, float(p.stats.get("dmg_reduce", 0.0))))

## An ordinary enemy's hit, averaged over the floor's chance, the two ways
## and the region's mix, over the same hit with no elements.
func ordinary_ratio(depth: int, region: String, e: Enemy, raw: float) -> Array:
	e.elem_spec = {}
	var plain := landed(e, raw)
	var w := ElementThreat.weights(region)
	var armed := 0.0
	for k in Elements.KINDS:
		e.elem_spec = {"mode": "convert", "kinds": [k]}
		var c := landed(e, raw)
		e.elem_spec = {"mode": "add", "kinds": [k]}
		var a := landed(e, raw)
		armed += float(w[k]) * (ElementThreat.CONVERT_ODDS * c + (1.0 - ElementThreat.CONVERT_ODDS) * a)
	var chance := ElementThreat.chance(depth, false)
	var mean := chance * armed + (1.0 - chance) * plain
	e.elem_spec = {}
	return [mean / plain, armed / plain, plain / game.player.max_hp]

func run() -> void:
	var region := OS.get_environment("BAL_REGION")
	if region.is_empty(): region = "mine"
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["auto_potion"] = false
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	for i in range(10): await process_frame
	game = find_game(rig)
	game.fixed_map_seed = 2026
	await game.start_contract(region)
	Engine.time_scale = SCALE
	var main := str(Elements.LOCAL[region])
	var weak := str(Elements.WEAKNESS[region])
	var depths: Array = DEPTHS
	if not OS.get_environment("BAL_DEPTHS").is_empty(): depths = Array(OS.get_environment("BAL_DEPTHS").split(",")).map(func(x): return int(x))
	for depth in depths:
		if depth > 1:
			game.floor_number = depth - 1
			game.start_floor = depth
			await game.advance(0)
		await ticks(30)
		print("FLOOR %s %d penalty=%d arts_pen=%d chance=%.2f/%.2f convert=%.2f add=%.2f bigfloor=%.0f ref=%.0f" % [region, depth, roundi(Elements.penalty(depth)), roundi(Elements.arts_penalty(depth)),
			ElementThreat.chance(depth, false), ElementThreat.chance(depth, true), ElementThreat.convert_share(depth), ElementThreat.add_share(depth), ElementThreat.big_floor(depth), ElementThreat.ref_life(depth)])
		for planned in [false, true]:
			build(depth, region, planned)
			var p := game.player
			var tag := "planned" if planned else "drop"
			print("BUILD %s d=%d %s hp=%.0f def=%.0f | %s" % [region, depth, tag, p.max_hp, p.defense_value(), res_line(region)])
			game._clear_field()
			await ticks(2)
			var normal := game._spawn_enemy(p.global_position + Vector3(0, 0, -4), false, false, str(EnemyAttacks.REGION_POOLS[region].normal[0]))
			normal.set_physics_process(false)
			var o := ordinary_ratio(depth, region, normal, normal.atk)
			print("HIT %s d=%d %s ordinary: plain=%.1f%%hp floor-mean=x%.2f armed-mean=x%.2f" % [region, depth, tag, o[2] * 100.0, o[0], o[1]])
			var bully := game._spawn_enemy(p.global_position + Vector3(2, 0, -4), true, false, "bully")
			bully.set_physics_process(false)
			bully.attack_phase = "strike"
			var bigs := []
			for kinds in [[main], [weak], [Elements.KINDS.filter(func(k): return k != main and k != weak)[0]], [main, weak]]:
				bully.elem_spec = {"mode": "convert", "kinds": kinds}
				p.elements.shred.clear()
				bigs.append("%s=%d%%" % ["+".join(kinds), roundi(landed(bully, bully.atk * 1.5) / p.max_hp * 100.0)])
			p.elements.shred.clear()
			print("BIG %s d=%d %s elite charge: %s" % [region, depth, tag, " ".join(bigs)])
			var boss_kinds := [[main]]
			if BossCatalog.boss_tier(maxi(20, depth)) >= ElementThreat.BOSS_ADD_TIER: boss_kinds = [[main], [main, weak], [main, weak, "x"]]
			var bline := []
			for kinds in boss_kinds:
				var ks: Array = kinds.duplicate()
				if ks.has("x"): ks[2] = Elements.KINDS.filter(func(k): return not k in [main, weak])[0]
				bully.elem_spec = {"mode": "add", "kinds": ks}
				p.elements.shred.clear()
				bline.append("%s=%d%%" % ["+".join(ks), roundi(landed(bully, bully.atk * 2.5) / p.max_hp * 100.0)])
			print("BOSSBIG %s d=%d %s (big rule, as a boss move): %s" % [region, depth, tag, " ".join(bline)])
			p.elements.shred.clear()
			for e in [normal, bully]: e.queue_free()
			await ticks(2)
			for elements_on in [true, false]:
				var r: Array = await pack(elements_on)
				print("PACK %s d=%d %s elements=%s ttk=%.1f left=%d taken=%.2f" % [region, depth, tag, elements_on, r[0] * SCALE, r[1], r[2]])
	Engine.time_scale = 1.0
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()

## The probe's usual pack: two ordinary, one ranged, one elite.
func pack(elements_on: bool) -> Array:
	var p := game.player
	game._clear_field()
	await ticks(2)
	p.hp = p.max_hp
	p.invulnerable = false
	p.elements.shred.clear()
	game.rng_elem.seed = 4242
	var foes: Array[Enemy] = []
	for s in [[-3.0, -3.0, false, false], [0.0, -4.0, false, false], [3.0, -3.0, false, true], [0.0, -6.5, true, false]]:
		var at := game.world_map.nearest_walkable(p.global_position + Vector3(s[0], 0, s[1]))
		var e := game._spawn_enemy(at, s[2], s[3], game._pick_enemy_type(s[2], s[3]))
		if not elements_on: e.elem_spec = {}
		foes.append(e)
	var taken := 0.0
	var t := 0.0
	var last: float = p.hp
	while t < 90.0:
		await physics_frame
		t += 1.0 / 60.0
		if p.hp < last: taken += last - p.hp
		if p.hp < p.max_hp * 0.4: p.hp = p.max_hp
		last = p.hp
		var alive := foes.filter(func(e): return is_instance_valid(e) and not e._dead)
		if alive.is_empty(): break
		if not is_instance_valid(p.attack_target) or p.attack_target._dead:
			alive.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
			p.lock_target(alive[0])
	return [t, foes.filter(func(e): return is_instance_valid(e) and not e._dead).size(), taken / p.max_hp]
