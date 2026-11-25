extends SceneTree
## Not a test — a balance probe. For one region (BAL_REGION) and several
## depths, she wears what the drops give by then (per slot the best of
## 0.6 × depth real rolls, normal/elite mix), attribute points and combat
## research as tools/depth_model.py assumes, and fights the region's real
## enemies one at a time and as a pack. Prints TTK and damage taken.
##   set BAL_REGION=mine
##   godot --headless --path . --script res://tests/_probe_balance.gd --fixed-fps 60

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

func build(depth: int, region: String, full: bool) -> void:
	var p := game.player
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + depth
	for slot in p.equipped.keys(): p.unequip(slot)
	var pieces := maxi(1, roundi(0.6 * depth))
	var count := [0, 0, 0, 0, 0, 0]
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
			p.equip(best)
			count[best.rarity] += 1
	var prog := p.progress()
	var start := Progression.start_attributes(p.operator_id)
	var attrs := start.duplicate()
	if full:
		var points := roundi(minf(119.0, 2.0 + depth * 1.95))
		attrs["tec"] = int(start.tec) + points / 2
		attrs["phy"] = int(start.phy) + points - points / 2
	prog.attributes = attrs
	prog.elite = 0 if depth < 31 else (1 if depth < 61 else 2)
	var done: Array = []
	if full:
		var combat: Array = []
		for id in ResearchCatalog.NODES.keys():
			if ResearchCatalog.is_combat(str(id)): combat.append(str(id))
		combat.sort_custom(func(a, b): return int(ResearchCatalog.NODES[a][1]) < int(ResearchCatalog.NODES[b][1]))
		var take := roundi(combat.size() * minf(1.0, depth / 80.0))
		done = combat.slice(0, take)
	game.base.research.done = done
	p._recompute_stats()
	p.hp = p.max_hp
	var fam := ""
	print("BUILD %s d=%d full=%s rar=%s atk=%.0f arts=%.0f hp=%.0f def=%.0f res=%.0f crit=%.2f cdmg=%.2f aspd=%.2f research=%d %s" % [region, depth, full, count,
		p.attack_power(), p.arts_power(), p.max_hp, p.defense_value(), float(p.stats.get("res", 0.0)), p.crit_rate(), p.crit_damage(), float(p.stats.get("aspd", 0.0)), done.size(), fam])

## One fight; returns [seconds, enemies left, her damage taken / max_hp].
func fight(spawns: Array, cap: float) -> Array:
	var p := game.player
	game._clear_field()
	await ticks(2)
	p.hp = p.max_hp
	p.invulnerable = false
	var foes: Array[Enemy] = []
	for s in spawns:
		var at := game.world_map.nearest_walkable(p.global_position + Vector3(s[0], 0, s[1]))
		var ty: String = s[4] if not str(s[4]).is_empty() else game._pick_enemy_type(s[2], s[3])
		foes.append(game._spawn_enemy(at, s[2], s[3], ty))
	var taken := 0.0
	var t := 0.0
	var last: float = p.hp
	while t < cap:
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
	var left := foes.filter(func(e): return is_instance_valid(e) and not e._dead).size()
	return [t, left, taken / p.max_hp]

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
	var pools: Dictionary = EnemyAttacks.REGION_POOLS[region]
	var types: Array = []
	for role in ["normal", "ranged", "elite"]:
		for ty in pools[role]:
			if not [ty, role] in types: types.append([ty, role])
	for depth in DEPTHS:
		if depth > 1:
			game.floor_number = depth - 1
			game.start_floor = depth
			await game.advance(0)
		await ticks(30)
		print("FLOOR %s %d growth=%.2f contract=%.3f stat=%.2f" % [region, game.floor_number, Scaling.floor_growth(game.floor_number), game.contract_life(), float(game.routes.route_node_info().get("stat", 1.0))])
		for full in [false, true]:
			build(depth, region, full)
			for pair in types:
				var r: Array = await fight([[0.0, -4.0, pair[1] == "elite", pair[1] == "ranged", pair[0]]], 60.0)
				print("FIGHT %s d=%d full=%s %s(%s) ttk=%.1f left=%d taken=%.2f" % [region, depth, full, pair[0], pair[1], r[0], r[1], r[2]])
			var pack := [[-3.0, -3.0, false, false, ""], [0.0, -4.0, false, false, ""], [3.0, -3.0, false, true, ""], [0.0, -6.5, true, false, ""]]
			var r2: Array = await fight(pack, 90.0)
			print("PACK %s d=%d full=%s ttk=%.1f left=%d taken=%.2f" % [region, depth, full, r2[0], r2[1], r2[2]])
	Engine.time_scale = 1.0
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
