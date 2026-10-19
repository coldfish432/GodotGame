extends SceneTree

## 装备扩充策划案_v1_0.md: the 66 new bases (63 + 3 polearms) and their
## requirements, weapon forms, the 30 enemy exclusives and 6 three-piece sets
## (data, drops, icons), and each effect family on the six trigger points.

var game: GameManager
var p: Player
var failures := 0
var checks := 0
var origin := Vector3(0, 0.7, -22)

func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed and seen != null: print("   seen: ", seen)
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func dummy(offset: Vector3, life: float = 100000.0, type: String = "thug") -> Enemy:
	var enemy := game._spawn_enemy(origin + offset, false, false, type)
	enemy.set_physics_process(false)
	enemy.max_health = life
	enemy.health = life
	enemy.defense = 0
	enemy.res = 0
	return enemy

func swing(enemy: Enemy) -> float:
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.dash_remaining = 0
	p.combo_step = 0
	p.combo_idle = 0
	var before := enemy.health
	p.attack(enemy)
	return before - enemy.health

## Named gear with only its fixed parts (no random affix, no power).
func wear(id: String) -> Item:
	var item := SpecialGear.create(id, 0, RandomNumberGenerator.new())
	item.power = 0
	item.grade = 0
	item.modifiers = item.modifiers.filter(func(m): return m.tier == GearCatalog.IMPLICIT_TIER)
	item.prefixes = [] # named prefixes would skew the numbers
	p.equip(item)
	return item

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(4)
	_catalog()
	_named()
	_drops()
	await game.start_contract("city")
	p = game.player
	game.set_process(false)
	p.set_physics_process(false)
	p._sprite.set_process(false)
	game._clear_field()
	await step(2)
	p.teleport(origin)
	_forms()
	await _effects()
	_sets()
	print("GEAR EXPANSION RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _catalog() -> void:
	var added := GearCatalog.BASES.keys().filter(func(id): return str(id).contains("_x"))
	check("66 new bases (63 + 3 polearms)", added.size() == 66, added.size())
	var counts := {}
	for id in added:
		var b: Dictionary = GearCatalog.BASES[id]
		var key := "%s/%d" % [b.region, b.category]
		counts[key] = int(counts.get(key, 0)) + 1
	check("矿区 8 weapons / 6 armour / 8 trinkets", counts.get("mine/0") == 8 and counts.get("mine/1") == 6 and counts.get("mine/2") == 8, counts)
	check("龙门 8 / 6 / 7, 萨米 8 / 7 / 8", counts.get("city/0") == 8 and counts.get("city/1") == 6 and counts.get("city/2") == 7
		and counts.get("snow/0") == 8 and counts.get("snow/1") == 7 and counts.get("snow/2") == 8, counts)
	var polearms := added.filter(func(id): return str(GearCatalog.BASES[id].get("form", "")) == "polearm")
	check("three polearms, one per region", polearms.size() == 3)
	var names := {}
	var unique := true
	for id in GearCatalog.BASES:
		if names.has(GearCatalog.BASES[id].name): unique = false
		names[GearCatalog.BASES[id].name] = true
	check("every base name is unique", unique)
	# Requirements by the §1 rule: the doc's counts over the 63 (polearms aside).
	var by := {}
	for id in added:
		if str(GearCatalog.BASES[id].get("form", "")) == "polearm": continue
		var item := LootTables.roll_equipment(int(GearCatalog.BASES[id].category), GearCatalog.BASES[id].name, GearCatalog.BASES[id].region, 1, 0, RandomNumberGenerator.new())
		item.grade = 2
		var a := str(Progression.requirement(item).attribute)
		by[a] = int(by.get(a, 0)) + 1
	check("requirements: 体魄 22 · 敏捷 16 · 技巧 15 · 源石技艺 10", by == {"phy": 22, "agi": 16, "tec": 15, "arts": 10}, by)
	var icons := true
	for id in added:
		if ItemIcons.BY_NAME.get(GearCatalog.BASES[id].name, "") != GearCatalog.BASES[id].icon or not ResourceLoader.exists(ItemIcons.DIR + GearCatalog.BASES[id].icon + ".png"): icons = false
	check("every new base has its own icon", icons)
	check("当铺铜牌 raises the delivery price ×1.2", is_equal_approx(float(GearCatalog.BASES[GearCatalog.id_for_name("当铺铜牌")].value), 1.2))

func _named() -> void:
	var exclusives := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "exclusive")
	var pieces := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "set")
	check("30 enemy exclusives, 18 set pieces, 6 sets", exclusives.size() == 30 and pieces.size() == 18 and SpecialGear.SETS.size() == 6)
	var sources := true
	var effects := true
	for id in exclusives:
		if not EnemyAttacks.PROFILES.has(str(SpecialGear.GEAR[id].source_enemy)): sources = false
		if str(SpecialGear.GEAR[id].get("fx", "")).is_empty(): effects = false
	check("every exclusive names a real enemy and an effect", sources and effects)
	var per_set := {}
	for id in pieces: per_set[SpecialGear.GEAR[id].set_id] = int(per_set.get(SpecialGear.GEAR[id].set_id, 0)) + 1
	check("each set has a weapon, an armour and a trinket", per_set.values().all(func(n): return n == 3))
	var icons := true
	for id in exclusives + pieces:
		if not ResourceLoader.exists(ItemIcons.DIR + id + ".png"): icons = false
	check("every named piece has an icon", icons)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var axe := SpecialGear.roll_exclusive("breacher", "city", 1, rng)
	check("an exclusive: fixed 稀有, grade Ⅲ, its intrinsic, one random affix, its name colour", axe != null and axe.rarity == 2 and axe.grade == 3
		and axe.modifiers.filter(func(m): return m.tier == GearCatalog.IMPLICIT_TIER).size() == 2 and axe.modifiers.filter(func(m): return m.tier >= 0).size() == 1
		and axe.rarity_color() == Item.EXCLUSIVE_COLOR and axe.display_name().contains("专属"))
	var boss_axe := SpecialGear.roll_exclusive("breacher", "city", 1, rng, true)
	check("a boss's exclusive is one grade higher", boss_axe.grade == 4)
	check("exclusive weapons keep their form", Progression.requirement(axe).attribute == "phy")
	var copy := Item.from_data(axe.to_data())
	check("named gear survives a save", copy.special == axe.special and copy.named_kind() == "exclusive" and copy.grade == 3)
	var ordinary := true
	for i in range(40):
		if SpecialGear.kind(SpecialGear.roll("city", 1, rng).special) != "special": ordinary = false
	check("special-gear rolls never hand out exclusives or set pieces", ordinary)

func _drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ctx := {"region": "city", "depth": 4, "reward": 0.0, "rng": rng, "pity": {}, "boss": true, "set_seen": {}}
	var found_exclusive := 0
	var found_set := 0
	var growth := 0
	for i in range(4000):
		for drop in LootTables.enemy_drops("breacher", true, false, ctx):
			if not drop.has("item"): continue
			var item: Item = drop.item
			if item.named_kind() == "exclusive": found_exclusive += 1
			elif item.named_kind() == "set": found_set += 1
			if item.material_id in ["近卫芯片组", "模组数据块", "技巧概要·卷3"]: growth += 1
	# 稀有概率 ÷10 (用户 2026-10-18): 25% × 1.07 (floor 4's step) ÷ 10 ≈ 2.7%; sets ≈ 0.5%.
	check("bosses drop their exclusive about 2.7% of the time", found_exclusive > 70 and found_exclusive < 150, found_exclusive)
	check("bosses drop set pieces about 0.5%", found_set > 6 and found_set < 45, found_set)
	check("bosses drop growth materials", growth > 2000, growth)
	ctx.boss = false
	var seen := {"inspectors": true}
	ctx.set_seen = seen
	var inspect := 0
	var total := 0
	for i in range(3000):
		var piece := SpecialGear.roll_set_piece("city", 1, rng, seen)
		total += 1
		if str(SpecialGear.GEAR[piece.special].set_id) == "inspectors": inspect += 1
	check("a set already found this contract comes twice as often", float(inspect) / total > 0.6 and float(inspect) / total < 0.73, float(inspect) / total)

func _forms() -> void:
	p.reset_stats()
	var base_cd := p.current_cooldown()
	var hammer := Item.create("测试锤", Item.Category.WEAPON, 2, 1, 0.0)
	hammer.base_id = GearCatalog.id_for_name("拆迁大锤")
	p.equip(hammer)
	check("heavy: interval ×1.3, reach ×1.2", absf(p.current_cooldown() / base_cd - 1.3) < 0.001 and absf(p.weapon_range() / Player.BLADE_RANGE - 1.2) < 0.001)
	var spear := Item.create("测试矛", Item.Category.WEAPON, 2, 1, 0.0)
	spear.base_id = GearCatalog.id_for_name("炎式朴刀")
	p.equip(spear)
	check("polearm: interval ×1.15, reach ×1.4, a narrower fan", absf(p.current_cooldown() / base_cd - 1.15) < 0.001 and absf(p.weapon_range() / Player.BLADE_RANGE - 1.4) < 0.001 and p.form_factor(3) < 1.0)
	p.unequip(Item.Category.WEAPON)

func _effects() -> void:
	p.reset_stats()
	p.teleport(origin)
	wear("mi_thug_0")
	var foe := dummy(Vector3(1.5, 0, 0), 5.0)
	var aspd := p.current_aspd()
	swing(foe)
	await step(2)
	check("暴徒的改刃: a kill gives +12 攻速 for 4 s", is_equal_approx(p.current_aspd() - aspd, 12.0), p.current_aspd() - aspd)
	p.reset_stats()
	wear(_id("攻坚重锤"))
	var big := dummy(Vector3(1.5, 0, 0))
	for i in range(3):
		swing(big)
		p._attack_cooldown = 0
	check("攻坚重锤: every third hit stuns", big.stun_timer > 0.0)
	p.reset_stats()
	wear(_id("绞盘护腕"))
	p.stamina = 100
	p._dash_cooldown = 0
	p._start_dash(Vector3.RIGHT)
	check("绞盘护腕: a dodge makes the next attack a crit", p.gear_fx.force_crit)
	p.reset_stats()
	wear(_id("灰尾屏障坠"))
	p.gear_fx.since_hurt = 8.1
	p.gear_fx.tick(0.01)
	check("灰尾屏障坠 (空闲时): 8 s without damage gives a 15% barrier", absf(p.shield - p.max_hp * 0.15) < 1.0, p.shield)
	p.reset_stats()
	wear(_id("置换指骨"))
	p.gear_fx.since_attack = 5.1
	p.gear_fx.tick(0.01)
	check("置换指骨 (空闲时): 5 s without attacking speeds her up", p.gear_fx.move_mult() > 1.29)
	var target := dummy(Vector3(1.5, 0, 0))
	var hit := swing(target)
	check("…and the next hit adds 80% arts", hit > p.attack_power() + p.arts_power() * 0.7, hit)
	p.reset_stats()
	wear(_id("劈冰者"))
	var full := dummy(Vector3(1.5, 0, 0), 1000000.0)
	var fresh_hit := swing(full)
	p.unequip(Item.Category.WEAPON)
	var plain_hit := swing(full)
	# 劈冰者 is a heavy weapon: its form adds ×1.35 on top of the +50%.
	check("劈冰者: +50% against enemies above 80% life", absf(fresh_hit / plain_hit - 1.5 * 1.35) < 0.05, fresh_hit / plain_hit)
	p.reset_stats()
	wear(_id("纠察官的套索"))
	var low := dummy(Vector3(1.5, 0, 0), 100000.0)
	low.health = 20000.0
	var low_hit := swing(low)
	p.unequip(Item.Category.WEAPON)
	var low_plain := swing(low)
	check("纠察官的套索: +30% below 30% life", absf(low_hit / low_plain - 1.3) < 0.05, low_hit / low_plain)
	p.reset_stats()
	wear(_id("不明罐装呼吸器"))
	p.hp = p.max_hp * 0.2
	var def := p.defense_value()
	p.take_damage(10.0, "true")
	check("不明罐装呼吸器: under 35% a hit raises defence 50% for 5 s", absf(p.defense_value() / def - 1.5) < 0.01)
	p.reset_stats()
	wear(_id("赏金账簿"))
	var elite := game._spawn_enemy(origin + Vector3(1.5, 0, 0), true, false, "elite")
	elite.set_physics_process(false)
	elite.health = 1.0
	var before := game.get_children().filter(func(c): return c is Loot).size()
	p.on_kill(elite)
	check("赏金账簿: an elite kill drops one more 赤金", game.get_children().filter(func(c): return c is Loot).size() == before + 1)
	elite.queue_free()
	p.reset_stats()
	game._clear_field()
	await step(1)

func _id(name: String) -> String:
	for id in SpecialGear.GEAR:
		if SpecialGear.GEAR[id].name == name: return id
	return ""

func _sets() -> void:
	p.reset_stats()
	var def := p.defense_value()
	wear("set_inspectors_1")
	wear("set_inspectors_2")
	# The vest's own 防御 +20 plus the 2-piece +40.
	check("特别督察组 2 件: defence +40", is_equal_approx(p.defense_value() - def, 60.0), p.defense_value() - def)
	p.reset_stats()
	wear("set_nameless_0")
	wear("set_nameless_1")
	wear("set_nameless_2")
	for i in range(3): p.gear_fx.on_kill(dummy(Vector3(3, 0, 0), 1.0))
	check("无名者 3 件: three kills store three 接替 for the signature", int(p.gear_fx.stacks.get("relay", 0)) == 3 and is_equal_approx(p.gear_fx.spend_signature_bonus(), 1.9))
	check("…spent at once", int(p.gear_fx.stacks.get("relay", 0)) == 0)
	p.reset_stats()
	wear("set_fire_watch_0")
	wear("set_fire_watch_1")
	check("执火守望 2 件: +8% life", float(p.stats.hp_pct) >= 0.08)
	var foe := dummy(Vector3(1.0, 0, 0))
	for i in range(3): p.gear_fx.on_hurt(10.0, null)
	check("执火守望 needs all three for the quake", foe.health == foe.max_health)
	wear("set_fire_watch_2")
	for i in range(3): p.gear_fx.on_hurt(10.0, null)
	check("执火守望 3 件: three hits in 2 s quake around her", foe.health < foe.max_health)
	var piece := SpecialGear.create("set_fire_watch_0", 1, RandomNumberGenerator.new())
	var tip := ItemTooltip.text(game, piece, false, false)
	check("the tooltip lists the set with its bonuses", tip.contains("执火守望 3/3") and tip.contains("2 件：") and tip.contains("3 件："), tip)
	p.reset_stats()
