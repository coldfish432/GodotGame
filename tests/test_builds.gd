extends SceneTree

## The relic system and stat model of 局内构筑与数值策划案_v1_0.md, against real
## game state: the catalog (every relic a real 集成战略 collectible), formulas,
## offer rules, sources and rerolls, each relic effect, and the special
## equipment that carries the attack effects.

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

## A still enemy with chosen defences and lots of life.
func dummy(offset: Vector3, elite: bool = false, defense: float = 0.0, res: float = 0.0, life: float = 100000.0, type: String = "") -> Enemy:
	var enemy := game._spawn_enemy(origin + offset, elite, false, type if not type.is_empty() else ("elite" if elite else "thug"))
	enemy.set_physics_process(false)
	enemy.max_health = life
	enemy.health = life
	enemy.defense = defense
	enemy.res = res
	return enemy

func swing(enemy: Enemy, stage: int = 0) -> float:
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.dash_remaining = 0
	p.combo_step = stage
	p.combo_idle = 0
	var before := enemy.health
	p.attack(enemy)
	return before - enemy.health

## Special equipment with only its fixed effects (no random affix, no power).
func wear(id: String) -> Item:
	var item := SpecialGear.create(id, 0, RandomNumberGenerator.new())
	item.power = 0
	item.modifiers = item.modifiers.filter(func(m): return m.trigger != ItemModifier.Trigger.NONE)
	p.equip(item)
	return item

## A plain weapon that only carries the sword wave.
func wave_weapon() -> void:
	var item := Item.create("测试剑气刃", Item.Category.WEAPON, 2, 1, 0.0)
	item.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	p.equip(item)

func use(ids: Array) -> void:
	game.builds.assign(ids)
	p._recompute_stats()

func reset_arena() -> void:
	game._clear_field()
	await step(2)
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	use([])
	p.reset_stats()
	p.teleport(origin)
	p.combat_timer = 0
	game.run_gold = 0
	game.pressure = 0
	game.floor_number = 1
	game.route_index = 0

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(4)
	await game.start_contract("city")
	p = game.player
	game.set_process(false)
	p.set_physics_process(false)
	p._sprite.set_process(false)
	await reset_arena()
	_catalog()
	_formulas()
	_offers()
	await _sources()
	await _attack()
	await _wave()
	await _tempo()
	await _defense()
	await _life()
	await _misc()
	await _special()
	print("BUILDS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _catalog() -> void:
	var all := RelicCatalog.all()
	var ids := {}
	var complete := true
	var valid_keys := true
	for relic in all:
		ids[relic.id] = true
		complete = complete and relic.name == relic.source_name and not str(relic.original).is_empty() and not str(relic.effect).is_empty()
		for key in relic.stats: valid_keys = valid_keys and CombatStats.KEYS.has(key)
	check("94 relics, unique, each named after its 集成战略 collectible with its original effect", all.size() == 94 and ids.size() == 94 and complete, all.size())
	check("every stat key is part of the sheet", valid_keys)
	var research := FileAccess.get_file_as_string("res://局内构筑调研_集成战略藏品.md")
	var missing := all.filter(func(r): return not r.name.replace("\"", "") in research.replace("\"", ""))
	check("every relic appears in the PRTS research table", missing.is_empty(), missing.map(func(r): return r.name))
	var invented := ["blade_edge", "counter", "unsealed", "ore_heart", "moon_blades", "gaul_coin", "veteran_edge"]
	check("no invented relics remain", invented.all(func(x): return not ids.has(x)))
	check("no set or school system remains", not "SCHOOLS" in RelicCatalog.new().get_script().source_code and not RelicCatalog.new().get_script().source_code.contains("func tier("))
	check("no relic deals damage of its own (that is special equipment)", not ids.has("藤蔓炮手") and not ids.has("尖刺之手") and not ids.has("老者面"))

func _formulas() -> void:
	check("physical: ATK minus DEF", is_equal_approx(CombatStats.physical(600, 100), 500))
	check("physical floor is 10% of the hit", is_equal_approx(CombatStats.physical(600, 900), 60))
	check("arts: scaled by resistance", is_equal_approx(CombatStats.arts(500, 30), 350))
	check("resistance is capped at 80", is_equal_approx(CombatStats.arts(500, 120), 100))
	check("true damage ignores both", is_equal_approx(CombatStats.mitigate(500, "true", 999, 99), 500))
	check("Lappland's base sheet", p.max_hp == 2400 and is_equal_approx(p.attack_power(), 600) and is_equal_approx(p.arts_power(), 360)
		and is_equal_approx(p.defense_value(), 200) and is_equal_approx(p.resistance(), 10) and is_equal_approx(p.current_aspd(), 100) and p.crit_rate() == 0.0)
	var blade := Item.create("测试战刃", Item.Category.WEAPON, 2, 1, 2.5)
	blade.modifiers = [ItemModifier.stat_mod(ItemModifier.Stat.ATK_PCT, 0.08), ItemModifier.stat_mod(ItemModifier.Stat.CRIT_RATE, 0.05)]
	p.equip(blade)
	check("weapon power and affixes feed ATK and crit", is_equal_approx(p.attack_power(), 700 * 1.08) and is_equal_approx(p.crit_rate(), 0.05))
	p.unequip(Item.Category.WEAPON)
	use(["皇帝的恩宠", "贵族刺剑"])
	check("relic percentages add in one layer: 600 × (1 + 0.15 + 0.25)", is_equal_approx(p.attack_power(), 840))
	use([])

func _offers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var distinct := true
	var never_owned := true
	var wave_seen := {"mine": 0, "snow": 0}
	var high := {"device": 0, "vault": 0}
	for i in range(400):
		for region in ["mine", "snow"]:
			var offers := RelicCatalog.roll_offers(region, ["皇帝的恩宠"], "device", rng)
			var kinds := offers.map(func(x): return x.kind)
			distinct = distinct and offers.size() == 3 and kinds[0] != kinds[1] and kinds[1] != kinds[2] and kinds[0] != kinds[2]
			never_owned = never_owned and not offers.any(func(x): return x.id == "皇帝的恩宠")
			wave_seen[region] += offers.filter(func(x): return x.kind == "wave").size()
		for source in high:
			high[source] += RelicCatalog.roll_offers("city", [], source, rng).filter(func(x): return x.rarity == 2).size()
	check("a choice spans three different kinds of relic", distinct)
	check("owned relics are never offered again", never_owned)
	check("the snow offers wave relics far more than the mine does", wave_seen.snow > wave_seen.mine * 1.5, wave_seen)
	check("vault offers lean to high rarity compared with the device", high.vault > high.device * 1.5, high)
	use(["罗德岛战术电台"])
	check("罗德岛战术电台 adds a fourth option", game._roll_relics("device").size() == 4)
	use([])
	check("otherwise three", game._roll_relics("device").size() == 3)

func _sources() -> void:
	p.teleport(game.world_map.buff_device_node.global_position)
	game._interact()
	var first: Array = game.build_offers.map(func(x): return x.id)
	game.close_modal()
	game._interact()
	check("device offer opens with three and does not reroll on reopen", game.modal == "build" and first.size() == 3 and first == game.build_offers.map(func(x): return x.id))
	game.run_gold = 100
	check("reroll costs 25 of the unbanked reward and changes the offer", game.reroll_offers() and game.run_gold == 75 and game.reroll_count == 1)
	check("the next reroll costs 50", game.reroll_cost() == 50 and game.reroll_offers() and game.run_gold == 25)
	check("no reroll without the money", not game.reroll_offers() and game.run_gold == 25)
	var pick: String = game.build_offers[0].id
	check("device pick succeeds once", game.choose_build(pick) and not game.is_buff_available() and game.builds == [pick])
	await reset_arena()
	use(["锈蚀的铁锤"])
	game.reroll_count = 0
	check("锈蚀的铁锤 halves the reroll price (25 → 13)", game.reroll_cost() == 13)
	use([])
	game.segment_threat = 0
	game._cache_spawned = false
	for i in range(7):
		dummy(Vector3(4 + i, 0, 6), false, 0, 0, 1).take_hit(10, "true")
	check("seven ordinary kills are not enough for a combat cache", get_nodes_in_group("relic_caches").is_empty() and game.segment_threat == 7)
	dummy(Vector3(2, 0, 2), false, 0, 0, 1).take_hit(10, "true")
	await step()
	var caches := get_nodes_in_group("relic_caches")
	check("the eighth threat drops one combat cache", caches.size() == 1 and (caches[0] as RelicCache).source == "cache")
	var cache := caches[0] as RelicCache
	p.teleport(cache.global_position)
	game._interact()
	var cache_ids: Array = game.build_offers.map(func(x): return x.id)
	check("a cache opens its own offer", game.modal == "build" and game.offer_source == "cache" and cache_ids.size() == 3)
	game.close_modal()
	game._interact()
	check("closing and reopening a cache keeps its offer", game.build_offers.map(func(x): return x.id) == cache_ids)
	check("choosing from a cache claims it", game.choose_build(cache_ids[1]) and game.builds.has(cache_ids[1]))
	await step()
	check("a claimed cache is gone", get_nodes_in_group("relic_caches").is_empty())
	for i in range(game.world_map.mechanism_nodes.size()): game._mechanisms_done[i] = true
	game._open_vault()
	await step()
	var vault: RelicCache = get_nodes_in_group("relic_caches").filter(func(n): return n.source == "vault")[0]
	p.teleport(vault.global_position)
	game._interact()
	check("the vault relic is sealed while guardians live", vault.sealed and game.modal.is_empty())
	for guardian in game._vault_guardians.duplicate(): guardian.take_hit(1e7, "true")
	await step()
	check("killing the guardians unseals it", not vault.sealed)
	game._interact()
	check("the vault offers its own choice", game.modal == "build" and game.offer_source == "vault")
	game.close_modal()
	game.settle(true)
	check("settlement clears relics and their state", game.builds.is_empty() and p.shield == 0.0 and p.fx.is_empty())
	await game.start_contract("city")
	game.set_process(false)
	p.set_physics_process(false)
	await reset_arena()

func _attack() -> void:
	var e := dummy(Vector3(0, 0, 2))
	use(["锈蚀刀片"])
	check("锈蚀刀片: physical damage +15%", is_equal_approx(swing(e), 690))
	e.defense = 300
	use(["残破合影"])
	check("残破合影: ignores 12% of defence", is_equal_approx(swing(e), 600 - 300 * 0.88))
	use(["撕扯之手", "迷迭香之拥"])
	check("defence ignore stacks and caps at 100%", is_equal_approx(swing(e), 600))
	e.defense = 0
	use(["溃决之手"])
	e.health = e.max_health * 0.5
	check("溃决之手: +25% into an enemy at half life", is_equal_approx(swing(e), 750))
	e.health = e.max_health * 0.205
	swing(e)
	check("溃决之手: an ordinary enemy under 20% is executed", e._dead)
	var boss := dummy(Vector3(1, 0, 2), true)
	boss.health = boss.max_health * 0.1
	use(["扼喉之手"])
	swing(boss)
	check("扼喉之手 never executes an elite", not boss._dead)
	boss.queue_free()
	await step()
	var lone := dummy(Vector3(0, 0, 2))
	use(["荣耀绶带"])
	check("荣耀绶带: +60% with one enemy near", is_equal_approx(swing(lone), 960))
	var crowd := dummy(Vector3(0.5, 0, 3))
	check("but not with two", is_equal_approx(swing(lone), 600))
	crowd.queue_free()
	await step()
	use(["绿叶菜罐头"])
	p._on_wave_released()
	check("绿叶菜罐头: +60% ATK for a second after a wave", is_equal_approx(p.attack_power(), 960))
	p._tick_relic_timers(1.1)
	check("and only for that second", is_equal_approx(p.attack_power(), 600))
	use(["\"噤声\""])
	p.since_wave = 60.0
	check("\"噤声\": +60% after 60 s without a wave", is_equal_approx(p.attack_power(), 960))
	p._on_wave_released()
	check("and back to nothing after a wave", is_equal_approx(p.attack_power(), 600))
	use(["轰鸣之手"])
	for i in range(12): swing(lone)
	check("轰鸣之手: +8% per hit up to +80%", p.hit_stacks == 10 and is_equal_approx(p.attack_power(), 1080))
	p._tick_relic_timers(3.1)
	check("and gone after 3 s without a hit", is_equal_approx(p.attack_power(), 600))
	use(["古乔治营养原浆"])
	check("古乔治营养原浆: +30% at full life", is_equal_approx(p.attack_power(), 780))
	p.hp = p.max_hp * 0.5
	check("+15% at half life", is_equal_approx(p.attack_power(), 690))
	p.hp = p.max_hp
	use(["赏善郎"])
	p._on_block()
	check("赏善郎: a block arms the next hit at ×2", is_equal_approx(swing(lone), 1200) and is_equal_approx(swing(lone), 600))
	use(["《光耀卡西米尔》"])
	p._on_evade()
	check("《光耀卡西米尔》: +70% ATK for 6 s after an evade", is_equal_approx(p.attack_power(), 1020))
	use(["《拳经三问》"])
	p.wave_count = 0
	for i in range(3): p._on_wave_released()
	check("《拳经三问》: +4% per wave released this contract", is_equal_approx(p.attack_power(), 600 * 1.12))
	use(["折戟-破釜沉舟"])
	check("折戟-破釜沉舟: ATK +40%, 攻速 +30, DEF −40%", is_equal_approx(p.attack_power(), 840) and is_equal_approx(p.current_aspd(), 130) and is_equal_approx(p.defense_value(), 120))
	use(["死仇时代的恨意", "开裂的束缚带"])
	check("死仇时代的恨意 and 开裂的束缚带 add up on enemy attack (+20% −7%)", is_equal_approx(game.enemy_attack_multiplier(), 1.13))
	use([])
	var plain := game._spawn_enemy(origin + Vector3(6, 0, 6), false, false, "thug")
	use(["\"黑夜呢喃\""])
	var thinner := game._spawn_enemy(origin + Vector3(7, 0, 6), false, false, "thug")
	check("\"黑夜呢喃\": enemies spawn with 10% less life", is_equal_approx(thinner.max_health, plain.max_health * 0.9))
	var before := plain.max_health
	game._rescale_enemy_life(0.0, -0.1)
	check("and enemies already standing shrink when it is taken", is_equal_approx(plain.max_health, before * 0.9))
	await reset_arena()

func _wave() -> void:
	wave_weapon()
	use(["显圣吊坠", "银餐叉"])
	check("显圣吊坠 + 银餐叉: wave damage +40%", is_equal_approx(p.wave_multiplier(), 1.4))
	use(["制式防暴用具"])
	check("制式防暴用具: arts damage +20% on waves", is_equal_approx(p.wave_bonus_against(dummy(Vector3(5, 0, 5))), 1.2))
	use(["断杖-苦难巫咒"])
	check("断杖-苦难巫咒: arts damage +70%, life −40%", is_equal_approx(p.max_hp, 1440) and is_equal_approx(float(p.stats.arts_dmg_pct), 0.7))
	use(["古高卢银币"])
	p.clear_charge()
	p.reset_floor_state()
	check("古高卢银币: one charge when a segment starts", p.sword_charge == 1)
	use(["《第二经济改革法》"])
	p.clear_charge()
	p.reset_floor_state()
	check("《第二经济改革法》: the wave is full when a segment starts", p.sword_charge == 3)
	use(["香草沙士汽水"])
	p.clear_charge()
	p._tick_relics_in_field(6.05)
	check("香草沙士汽水: one charge every 6 s", p.sword_charge == 1)
	use(["折戟-浴血"])
	p.clear_charge()
	var e := dummy(Vector3(0, 0, 2))
	swing(e, 2)
	check("折戟-浴血: the third stage charges twice", p.sword_charge == 2)
	use(["积攒之手"])
	p.clear_charge()
	p.stamina = 50
	dummy(Vector3(1, 0, 2), false, 0, 0, 1).take_hit(10, "true")
	check("积攒之手: a kill gives a charge and 10 stamina", p.sword_charge == 1 and is_equal_approx(p.stamina, 60))
	await reset_arena()

func _tempo() -> void:
	use(["冰结的躯壳"])
	p.take_damage(10, "true")
	check("冰结的躯壳: +40 攻速 for 5 s after taking damage", is_equal_approx(p.current_aspd(), 140))
	use(["疗养体验卡"])
	p.hurt_timer = 0
	p.combat_timer = 6.0
	var e := dummy(Vector3(0, 0, 2))
	swing(e)
	check("疗养体验卡: +40 攻速 for 10 s after re-engaging", is_equal_approx(p.current_aspd(), 140))
	p.engage_timer = 0
	use(["鸣脊兽"])
	p.since_wave = 40.0
	check("鸣脊兽: +40 攻速 after 40 s without a wave", is_equal_approx(p.current_aspd(), 140))
	p.since_wave = 0
	use(["老磨盘"])
	for i in range(12): p.take_damage(1, "true")
	p.hurt_timer = 0
	check("老磨盘: +6 per hit taken, at most 10", is_equal_approx(p.current_aspd(), 160))
	use(["紧急活性剂"])
	p.hp = p.max_hp * 0.3
	check("紧急活性剂: +60 攻速 at 30% life", is_equal_approx(p.current_aspd(), 160))
	use(["国王的新枪"])
	p.hp = p.max_hp * 0.2
	check("国王的新枪: +50 攻速 below 25% life", is_equal_approx(p.current_aspd(), 150))
	use(["魔王的旗帜"])
	p.hp = p.max_hp
	check("魔王的旗帜: +30 攻速 at full life", is_equal_approx(p.current_aspd(), 130))
	use(["钝爪-振奋"])
	p.hitstop_remaining = 0
	p._dash_cooldown = 0
	p.stamina = 100
	p._start_dash(Vector3.RIGHT)
	check("钝爪-振奋: dash cooldown halved", is_equal_approx(p._dash_cooldown, 0.25))
	p.dash_remaining = 0
	p.invulnerable = false
	use(["投币玩具"])
	game.run_gold = 200
	check("投币玩具: +3 攻速 per 50 unbanked reward", is_equal_approx(p.current_aspd(), 112))
	game.run_gold = 5000
	check("capped at +30", is_equal_approx(p.current_aspd(), 130))
	game.run_gold = 0
	use(["\"永夜的窥视\""])
	var hp := p.hp
	p._tick_relics_in_field(1.0)
	check("\"永夜的窥视\": ATK +25%, 攻速 +25, loses 0.6% life a second", is_equal_approx(p.attack_power(), 750) and is_equal_approx(p.current_aspd(), 125) and is_equal_approx(p.hp, hp - p.max_hp * 0.006))
	await reset_arena()

func _defense() -> void:
	use(["异铁小圆盾"])
	check("异铁小圆盾: DEF +25%", is_equal_approx(p.defense_value(), 250))
	use(["设计师量尺", "\"法术杀手\""])
	check("设计师量尺 / \"法术杀手\": 15% physical and arts evasion", is_equal_approx(p.evasion(), 0.15) and is_equal_approx(p.arts_evasion(), 0.15))
	use(["皇族金胸针", "药枚"])
	p.reset_floor_state()
	check("皇族金胸针 + 药枚: three blocks at the start of a segment", p.blocks_left == 3)
	for i in range(3): p.take_damage(500, "true")
	check("each block stops a whole hit", p.hp == p.max_hp and p.blocks_left == 0)
	p.take_damage(500, "true")
	check("then damage lands", is_equal_approx(p.hp, p.max_hp - 500))
	p.hp = p.max_hp
	use(["活木甲"])
	p.reset_floor_state()
	check("活木甲: a 50% life barrier each segment", is_equal_approx(p.shield, 1200))
	p.shield = 0
	use(["墙眼"])
	var archer := dummy(Vector3(4, 0, 0), false, 0, 0, 100000, "crossbow")
	p.take_damage(1000, "phys", archer)
	check("墙眼: ranged hits deal half", is_equal_approx(p.hp, p.max_hp - 400))
	p.hp = p.max_hp
	use(["古堡的子嗣"])
	p.segment_time = 100.0
	check("古堡的子嗣: DEF +300 and RES +30 after 100 s in a segment", is_equal_approx(p.defense_value(), 500) and is_equal_approx(p.resistance(), 40))
	p.segment_time = 0
	use(["魔王的床榻"])
	check("魔王的床榻: at full life DEF +20%, RES +10", is_equal_approx(p.defense_value(), 240) and is_equal_approx(p.resistance(), 20))
	use(["霜牡的肩甲"])
	dummy(Vector3(1, 0, 0))
	dummy(Vector3(-1, 0, 0))
	p._tick_relics_in_field(0.1)
	check("霜牡的肩甲: two enemies close trigger ATK and DEF +40% for 30 s", p.guard_timer > 0 and is_equal_approx(p.attack_power(), 840) and is_equal_approx(p.defense_value(), 280))
	use(["雪牝的护手"])
	dummy(Vector3(0, 0, 1))
	p._tick_relics_in_field(0.1)
	check("雪牝的护手: three enemies close trigger 攻速 +80 and 50% evasion", p.dance_timer > 0 and is_equal_approx(p.current_aspd(), 180) and is_equal_approx(p.evasion(), 0.5))
	await reset_arena()

func _life() -> void:
	use(["难闻的止血剂", "急救药箱", "未知仪器"])
	check("life relics add up: +105%", is_equal_approx(p.max_hp, 2400 * 2.05))
	use(["活玫瑰"])
	p.hp = 100
	p.heal(100)
	check("活玫瑰: healing +20%", is_equal_approx(p.hp, 220))
	use(["演出用香水", "《坎德之花》"])
	check("演出用香水 + 《坎德之花》: 1% of max life and 30 more a second", is_equal_approx(p.regen_rate(), 48 + 30 + 24))
	use(["\"萤灯映牍\""])
	p.hp = 1000
	dummy(Vector3(3, 0, 3), false, 0, 0, 1).take_hit(10, "true")
	check("\"萤灯映牍\": a kill heals 240", is_equal_approx(p.hp, 1240))
	use(["\"忠义\""])
	for x in [-1, 0, 1]: dummy(Vector3(x, 0, 1.5))
	p._tick_relics_in_field(1.0)
	check("\"忠义\": 150 a second with three enemies close", is_equal_approx(p.hp, 1390))
	use(["复还之手", "\"时光之末\""])
	p.hp = 300
	p.take_damage(5000, "true")
	check("复还之手: the first lethal hit of a segment refills life", is_equal_approx(p.hp, p.max_hp))
	p.invuln_timer = 0
	p.hp = 300
	p.take_damage(5000, "true")
	check("\"时光之末\": the next one leaves 1 life, once a contract", is_equal_approx(p.hp, 1.0))
	p.invuln_timer = 0
	p.reset_floor_state()
	p.hp = 300
	p.take_damage(5000, "true")
	check("复还之手 is back next segment", is_equal_approx(p.hp, p.max_hp))
	p.invuln_timer = 0
	p.hp = 300
	p.take_damage(5000, "true")
	check("but \"时光之末\" is spent", p.hp < 0)
	p.hp = p.max_hp  # or the game settles the contract as a death
	use(["米诺斯颂诗", "Friston.P"])
	dummy(Vector3(-3, 0, -3), true, 0, 0, 1).take_hit(10, "true")
	check("米诺斯颂诗 / Friston.P: an elite kill adds 3% life and 5 攻速", is_equal_approx(p.max_hp, 2400 * 1.03) and is_equal_approx(p.current_aspd(), 105))
	await reset_arena()

func _misc() -> void:
	use(["\"剑锤\""])
	check("\"剑锤\": ATK, DEF and life +10%, one flask less", is_equal_approx(p.attack_power(), 660) and p.potion_capacity == 2)
	use(["统帅肖像"])
	check("统帅肖像: +10% normally", is_equal_approx(p.attack_power(), 660))
	game.route_index = 2
	p._recompute_stats()
	check("and +30% on the deep route", is_equal_approx(p.attack_power(), 780) and is_equal_approx(p.max_hp, 2400 * 1.3))
	game.route_index = 0
	use(["登天斧"])
	check("登天斧: +60% on the first segment", is_equal_approx(p.attack_power(), 960))
	game.floor_number = 4
	p._recompute_stats()
	check("+30% by the fourth", is_equal_approx(p.attack_power(), 780) and is_equal_approx(p.max_hp, 2400 * 1.3))
	game.floor_number = 1
	use(["圆石祭坛"])
	seed(7)
	for i in range(40): p.reset_floor_state()
	check("圆石祭坛: stacks on new segments, at most 10", p.altar_stacks == 10 and is_equal_approx(p.attack_power(), 900))
	use(["友谊之证"])
	game.add_gold(10)
	check("友谊之证: reward +30%", game.run_gold == 13)
	await reset_arena()

func _special() -> void:
	var a := dummy(Vector3(0, 0, 2))
	var b := dummy(Vector3(1.2, 0, 2.4))
	wear("lord_blade")
	swing(a)
	check("领主宽刃 sweeps a neighbour for half", is_equal_approx(b.max_health - b.health, 300))
	wear("crystal_edge")
	var e := dummy(Vector3(-1, 0, 2), false, 0, 0)
	check("源石结晶刃 adds 18% arts ATK to each hit", is_equal_approx(swing(e), 600 + 360 * 0.18))
	wear("twin_fang")
	p.sword_charge = 3
	var before := game.get_children().filter(func(n): return n is SwordWave).size()
	swing(e)
	check("双生狼牙 fires three waves", game.get_children().filter(func(n): return n is SwordWave).size() - before == 3)
	for wave in game.get_children().filter(func(n): return n is SwordWave): wave.queue_free()
	wear("ember_fang")
	var target := dummy(Vector3(3, 0, 0))
	p.on_wave_hit(target, 100, null)
	check("余烬之牙 sets a 4 s burn", target.statuses.has("burn") and is_equal_approx(target.statuses.burn.time, 4.0))
	var life := target.health
	target._tick_statuses(0.51)
	check("burn ticks arts damage every half second", target.health < life)
	wear("moon_edge")
	seed(3)
	p.equipped[Item.Category.WEAPON].modifiers.append(ItemModifier.stat_mod(ItemModifier.Stat.CRIT_RATE, 1.0))
	p._recompute_stats()
	var waves_before := game.get_children().filter(func(n): return n is SwordWave).size()
	var fired := false
	for i in range(20):
		p.sword_charge = 0
		swing(e)
		if game.get_children().filter(func(n): return n is SwordWave).size() > waves_before:
			fired = true
			break
	check("月下刃: crits sometimes loose a free wave", fired)
	p.unequip(Item.Category.WEAPON)
	await reset_arena()
	wear("shadow_bracer")
	p._dash_cooldown = 0
	p.stamina = 100
	var crossed := dummy(Vector3(1.4, 0, 0))
	p._start_dash(Vector3.RIGHT)
	check("残影护腕 cuts what the dash passes", is_equal_approx(crossed.max_health - crossed.health, 720))
	p.dash_remaining = 0
	p.invulnerable = false
	p.teleport(origin)
	wear("spike_plate")
	var attacker := dummy(Vector3(1, 0, 0))
	p.take_damage(800, "phys", attacker)
	check("尖刺重铠 answers an attacker with 80% of DEF", is_equal_approx(attacker.max_health - attacker.health, 160))
	wear("bash_shield")
	p.shield = 100
	p.take_damage(800, "phys")
	var hit := dummy(Vector3(0, 0, 2))
	check("反击塔盾 adds 150% DEF to the next hit after a shield soak", is_equal_approx(swing(hit), 600 + 300))
	await reset_arena()
	wear("vein_core")
	var near := dummy(Vector3(2, 0, 0))
	seed(11)
	var burst := false
	for i in range(30):
		dummy(Vector3(2.5, 0, 0.5), false, 0, 0, 1).take_hit(10, "true")
		if near.health < near.max_health:
			burst = true
			break
	check("共振矿芯 bursts for 100% arts ATK", burst and is_equal_approx(near.max_health - near.health, 360))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var rolled := 0
	for i in range(600):
		if not FieldCatalog.roll_item("snow", 2, rng, 0.0).special.is_empty(): rolled += 1
	check("special gear drops at about 5%% (%d / 600)" % rolled, rolled > 10 and rolled < 60)
	await reset_arena()
