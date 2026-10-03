extends SceneTree

## The relic system and stat model of 局内构筑与数值策划案_v1_0.md, against real
## game state: catalog integrity (§10), formulas (§4), offer rules (§8.3),
## sources and rerolls (§8.2), resonance (§9) and every relic's mechanic.

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
func dummy(offset: Vector3, elite: bool = false, defense: float = 0.0, res: float = 0.0, life: float = 100000.0) -> Enemy:
	var enemy := game._spawn_enemy(origin + offset, elite, false, "elite" if elite else "thug")
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
	await _blade()
	await _wolf()
	await _swift()
	await _bulwark()
	await _blood()
	await _ore()
	await _hunter()
	await _field()
	await _bridges()
	print("BUILDS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _catalog() -> void:
	var all := RelicCatalog.all()
	var ids := {}
	var valid_keys := true
	var documented := true
	for relic in all:
		ids[relic.id] = true
		for key in relic.stats: valid_keys = valid_keys and CombatStats.KEYS.has(key)
		documented = documented and not str(relic.source_name).is_empty() and not str(relic.adaptation).is_empty() and not str(relic.hook).is_empty()
	check("66 relics with unique ids (61 in schools + 5 bridges)", all.size() == 66 and ids.size() == 66)
	check("every relic records its 集成战略 source and adaptation", documented)
	check("every stat key is part of the sheet", valid_keys)
	var legacy := ["ore_heart", "pack_plate", "unsealed", "counter", "brace", "gild_guard", "ambush", "rest", "empty_safe", "deep", "safe_salvage", "last_light"]
	check("the twelve original relics keep their ids", legacy.all(func(x): return ids.has(x)))
	var counts := RelicCatalog.school_counts(ids.keys())
	check("each of the eight schools has at least six relics", counts.values().all(func(x): return x >= 6) and counts.size() == 8)
	check("resonance tiers exist for every school", RelicCatalog.SCHOOLS.values().all(func(x): return x.has(2) and x.has(4)))

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
	check("weapon power and affixes feed ATK and crit", is_equal_approx(p.attack_power(), 700 * 1.08) and is_equal_approx(p.crit_rate(), 0.05) and "攻击力 +100" in blade.details())
	p.unequip(Item.Category.WEAPON)
	var armor := Item.create("测试甲", Item.Category.ARMOR, 2, 2, 2.0)
	armor.modifiers = [ItemModifier.stat_mod(ItemModifier.Stat.DEF_FLAT, 40), ItemModifier.stat_mod(ItemModifier.Stat.RES_FLAT, 8)]
	p.equip(armor)
	check("armor power gives life and defence; affixes add DEF and RES", is_equal_approx(p.max_hp, 2400 + 720) and is_equal_approx(p.defense_value(), 280) and is_equal_approx(p.resistance(), 18))
	p.unequip(Item.Category.ARMOR)
	use(["blade_edge", "whetstone"])
	check("flat and percent add in one layer: (600 + 60) x 1.15", is_equal_approx(p.attack_power(), 660 * 1.15))
	use([])

func _offers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var distinct := true
	var never_owned := true
	var bridge_early := false
	var ore_seen := {"mine": 0, "snow": 0}
	var legend := {"device": 0, "vault": 0}
	for i in range(400):
		for region in ["mine", "snow"]:
			var offers := RelicCatalog.roll_offers(region, ["blade_edge"], "device", rng)
			var schools := offers.map(func(x): return x.school)
			distinct = distinct and offers.size() == 3 and schools[0] != schools[1] and schools[1] != schools[2] and schools[0] != schools[2]
			never_owned = never_owned and not offers.any(func(x): return x.id == "blade_edge")
			bridge_early = bridge_early or offers.any(func(x): return x.school == RelicCatalog.BRIDGE)
			ore_seen[region] += offers.filter(func(x): return x.school == "ore").size()
		for source in legend:
			legend[source] += RelicCatalog.roll_offers("city", [], source, rng).filter(func(x): return x.rarity == 2).size()
	check("three offers always come from three different schools", distinct)
	check("owned relics are never offered again", never_owned)
	check("bridges stay out until both schools have two each", not bridge_early)
	check("the mine offers the 源石 school far more than the snow does", ore_seen.mine > ore_seen.snow * 2)
	check("vault offers lean legendary compared with the device", legend.vault > legend.device * 1.5)
	var focused := 0
	var unfocused := 0
	for i in range(400):
		focused += RelicCatalog.roll_offers("snow", ["blade_edge", "whetstone"], "device", rng).filter(func(x): return x.school == "blade").size()
		unfocused += RelicCatalog.roll_offers("snow", ["blade_edge", "howl"], "device", rng).filter(func(x): return x.school == "blade").size()
	check("two relics of a school pull that school toward the offer", focused > unfocused * 1.2, [focused, unfocused])
	var bridged := false
	for i in range(200):
		bridged = bridged or RelicCatalog.roll_offers("city", ["blade_edge", "whetstone", "howl", "pale_spark"], "vault", rng).any(func(x): return x.id == "moon_blades")
	check("with two blade and two wolf the 月下双刃 bridge can appear", bridged)
	var forced := true
	for i in range(100):
		forced = forced and RelicCatalog.roll_offers("snow", ["buckler", "brooch"], "device", rng, 3, "bulwark")[0].school == "bulwark"
	check("pity puts the main school first", forced)
	check("radio offers four", RelicCatalog.roll_offers("city", ["radio"], "device", rng, 4).size() == 4)
	check("resonance hint names the tier a pick would activate", "激活" in RelicCatalog.resonance_hint("whetstone", ["blade_edge"]))

func _sources() -> void:
	# Device: rolled once, kept on reopen, one pick.
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
	# Combat cache: appears once the segment's threat reaches 8.
	game.segment_threat = 0
	game._cache_spawned = false
	for i in range(7):
		dummy(Vector3(4 + i, 0, 6), false, 0, 0, 1).take_hit(10, "true")
	check("seven ordinary kills are not enough for a combat cache", get_nodes_in_group("relic_caches").is_empty() and game.segment_threat == 7)
	dummy(Vector3(2, 0, 2), false, 0, 0, 1).take_hit(10, "true")
	await step()
	var caches := get_nodes_in_group("relic_caches")
	check("the eighth threat drops one combat cache", caches.size() == 1 and (caches[0] as RelicCache).source == "cache")
	var elite := dummy(Vector3(3, 0, 3), true, 0, 0, 1)
	elite.take_hit(10, "true")
	await step()
	check("only one combat cache per segment", get_nodes_in_group("relic_caches").size() == 1)
	var cache := caches[0] as RelicCache
	p.teleport(cache.global_position)
	game._interact()
	var cache_ids: Array = game.build_offers.map(func(x): return x.id)
	check("a cache opens its own offer", game.modal == "build" and game.offer_source == "cache" and cache_ids.size() == 3)
	game.close_modal()
	game._interact()
	check("closing and reopening a cache keeps its offer", game.build_offers.map(func(x): return x.id) == cache_ids)
	var before := game.builds.size()
	check("choosing from a cache claims it", game.choose_build(cache_ids[1]) and game.builds.size() == before + 1)
	await step()
	check("a claimed cache is gone", get_nodes_in_group("relic_caches").is_empty())
	# Vault relic: sealed until every guardian falls.
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
	check("settlement clears relics and their state", game.builds.is_empty() and p.shield == 0.0 and game.build_offers.is_empty())
	await game.start_contract("city")
	game.set_process(false)
	p.set_physics_process(false)
	await reset_arena()

func _blade() -> void:
	var e := dummy(Vector3(0, 0, 2), false, 300)
	check("plain hit into DEF 300 is 300", is_equal_approx(swing(e), 300))
	use(["armor_break"])
	check("破甲刃纹 ignores 40% of defence", is_equal_approx(swing(e), 600 - 180))
	use(["metronome"])
	e.defense = 0
	check("连斩节拍 raises the third stage to 190%", is_equal_approx(swing(e, 2), 600 * 1.9))
	use(["blade_edge", "whetstone"])
	check("锋刃 2 resonance adds 10% crit", is_equal_approx(p.crit_rate(), 0.15))
	use(["blade_edge", "whetstone", "metronome", "armor_break"])
	check("锋刃 4: the third stage always crits for 180%", is_equal_approx(swing(e, 2), 660 * 1.15 * 1.9 * 1.8))
	use(["eagle_edge"])
	check("鹰眼刃纹: a hit that does not crit deals 80%", is_equal_approx(swing(e), 480))
	use(["executioner"])
	e.health = e.max_health * 0.155
	swing(e)
	check("处刑者 executes an ordinary enemy under 15%", e._dead, [e.health, e.max_health])
	var a := dummy(Vector3(0, 0, 2))
	var b := dummy(Vector3(1.2, 0, 2.4))
	use(["broad_blade"])
	swing(a)
	check("宽刃 sweeps a neighbour for half", is_equal_approx(b.max_health - b.health, 300) and is_equal_approx(p.current_aspd(), 90))
	use(["counter"])
	p.take_damage(10, "true")
	check("折刃扣 doubles the next hit after taking damage", is_equal_approx(swing(a), 1200) and is_equal_approx(swing(a), 600))
	await reset_arena()

func _wolf() -> void:
	var e := dummy(Vector3(0, 0, 2), false, 0, 20)
	use(["wolf_fang"])
	check("幼狼之牙·残响 grants the wave without the affix, at 80%", p.has_sword_wave() and is_equal_approx(p.wave_multiplier(), 0.8))
	use(["wolf_fang", "howl"])
	check("狼魂 2: two hits fill the wave", p.wave_hits_needed() == 2)
	use(["wolf_fang", "howl", "pale_spark", "pierce_sigil"])
	var dealt := swing(e)
	var rider := 360 * 1.15 * 0.2 * 1.2 * 0.8
	check("狼魂 4 adds 20% arts ATK as arts damage to every hit", is_equal_approx(dealt, 600 + rider), [dealt, 600 + rider])
	p.sword_charge = 2
	use(["wolf_fang", "howl", "pale_spark", "pierce_sigil", "twin_wave", "ember_wave", "silence"])
	var before := game.get_children().filter(func(n): return n is SwordWave).size()
	swing(e)
	var waves := game.get_children().filter(func(n): return n is SwordWave)
	check("双生剑气 fires three waves", waves.size() - before == 3)
	check("穿透咒印 widens and lengthens them", waves.all(func(w): return is_equal_approx(w.width_scale, 1.6) and is_equal_approx(w.range_bonus, 3.0)))
	for wave in waves: wave.queue_free()
	var target := dummy(Vector3(3, 0, 0), false, 0, 0)
	target._begin_telegraphed_attack()
	p.on_wave_hit(target, 100, null)
	check("余烬剑气 sets a 4 s burn", target.statuses.has("burn") and is_equal_approx(target.statuses.burn.time, 4.0))
	check("噤声印记 interrupts an ordinary windup", target.attack_phase == "idle" and target._attack_timer >= 2.0)
	var life := target.health
	target._tick_statuses(0.51)
	check("burn ticks arts damage every half second", target.health < life)
	use(["suffering"])
	check("苦难咒文 costs a quarter of max life", is_equal_approx(p.max_hp, 1800))
	await reset_arena()

func _swift() -> void:
	use(["light_belt", "clockwork"])
	check("轻装束带 adds 12 攻速 and 6% move", is_equal_approx(p.current_aspd(), 112) and is_equal_approx(p.move_speed, 5.3))
	check("two swift relics reach 迅捷 2", p.school_tier("swift") == 2)
	p._start_dash(Vector3.RIGHT)
	check("haste after the dash", is_equal_approx(p.current_aspd(), 142))
	p._tick_relic_timers(3)
	p.invulnerable = false
	p.dash_remaining = 0
	p.take_damage(10, "true")
	check("发条护腕 adds 40 攻速 after taking damage", is_equal_approx(p.current_aspd(), 152))
	use(["sidestep"])
	seed(5)
	var evaded := 0
	for i in range(400):
		var hp := p.hp
		p.take_damage(1, "phys")
		if p.hp == hp: evaded += 1
		p.hp = p.max_hp
	check("余裕身法 dodges about 15%% of physical hits (%d / 400)" % evaded, evaded > 35 and evaded < 90)
	var e := dummy(Vector3(0, 0, 2))
	use(["gale"])
	p.teleport(origin)
	for i in range(12): swing(e)
	check("风切 stacks to +40 攻速", p.gale_stacks == 10 and is_equal_approx(p.current_aspd(), 140), [p.gale_stacks, p.current_aspd()])
	p._tick_relic_timers(2.1)
	check("and drops after two seconds without a hit", p.gale_stacks == 0)
	use(["afterimage"])
	p.teleport(origin)
	p._dash_cooldown = 0
	p.hitstop_remaining = 0
	p.stamina = 100
	var crossed := dummy(Vector3(1.4, 0, 0))
	p._start_dash(Vector3.RIGHT)
	check("残影步 cuts what the dash passes", is_equal_approx(crossed.max_health - crossed.health, 720))
	p.dash_remaining = 0
	p.invulnerable = false
	p.teleport(origin)
	use(["perfect"])
	var striker := dummy(Vector3(1.5, 0, 0))
	striker.state = Enemy.State.CHASING
	striker._begin_telegraphed_attack()
	striker._windup_remaining = 0.2
	p._dash_cooldown = 0
	p.hitstop_remaining = 0
	p.stamina = 50
	p._start_dash(Vector3.LEFT)
	check("时机感: dodging inside the last 0.35 s readies a crit and refunds stamina", p.perfect_ready and is_equal_approx(p.stamina, 50))
	await reset_arena()

func _bulwark() -> void:
	use(["buckler", "brooch"])
	check("制式小圆盾 + 防蚀胸针: DEF 270, RES 25", is_equal_approx(p.defense_value(), 270) and is_equal_approx(p.resistance(), 25))
	p.reset_floor_state()
	check("坚壁 2: a shield of 15% max life each segment", is_equal_approx(p.shield, 360))
	p.take_damage(500, "true")
	check("防蚀胸针 blocks the first hit of the segment", p.hp == p.max_hp and is_equal_approx(p.shield, 360))
	p.take_damage(500, "true")
	check("then the shield soaks before life", is_equal_approx(p.shield, 0) and is_equal_approx(p.hp, p.max_hp - 140))
	use(["buckler", "brooch", "shield_bash", "heavy_oath"])
	check("重甲誓约: DEF x1.35 and 30% of it as ATK", is_equal_approx(p.defense_value(), 270 * 1.35) and is_equal_approx(p.attack_power(), 600 + 270 * 1.35 * 0.3))
	var e := dummy(Vector3(0, 0, 2))
	var attacker := dummy(Vector3(1, 0, 0), false, 0)
	p.brooch_ready = false
	p.take_damage(800, "phys", attacker)
	check("坚壁 4 answers an attacker with 80% of DEF", is_equal_approx(attacker.max_health - attacker.health, p.defense_value() * 0.8))
	p.shield = 100
	p.take_damage(800, "phys")
	var plain := p.attack_power()
	check("盾反 adds 150% DEF to the next hit after a shield soak", is_equal_approx(swing(e), plain + p.defense_value() * 1.5))
	use(["brace"])
	p.stationary_time = 1
	p.stamina = 100
	p.hp = 2000
	p.take_damage(1000, "true")
	check("街角楔 blocks 60% while standing", is_equal_approx(p.hp, 1600) and p.stamina == 85)
	await reset_arena()

func _blood() -> void:
	use(["nutrient"])
	check("营养原浆: +25% ATK at full life", is_equal_approx(p.attack_power(), 750))
	use(["frenzy"])
	p.hp = p.max_hp * 0.3
	check("濒死狂热: +60 攻速 at 30% life", is_equal_approx(p.current_aspd(), 160))
	use(["frenzy", "field_kit", "tissue", "bloodthirst"])
	p.hp = p.max_hp * 0.4
	check("血契 4: below half, +25% ATK and +20 攻速 more", is_equal_approx(p.attack_power(), 750) and p.current_aspd() > 160)
	var e := dummy(Vector3(0, 0, 2))
	var hp := p.hp
	var dealt := swing(e)
	check("吸血 12% heals from damage dealt", is_equal_approx(p.hp - hp, dealt * 0.12))
	use(["perfume", "thorn_rose"])
	check("舞台香氛 regenerates 1% max life per second on top", is_equal_approx(p.regen_rate(), 48 + 24))
	p.hp = 100
	p.heal(100)
	check("带刺玫瑰: healing +25%", is_equal_approx(p.hp, 225))
	use(["undying"])
	p.hp = 300
	p.take_damage(5000, "true")
	check("不屈之誓 turns a lethal hit into half life", is_equal_approx(p.hp, p.max_hp * 0.5) and p.invuln_timer > 0)
	p.invuln_timer = 0
	p.take_damage(5000, "true")
	check("once per segment", p.hp < 0)
	p.hp = p.max_hp  # or the game settles the contract as a death
	await reset_arena()

func _ore() -> void:
	var ores: Array[Item] = []
	for i in range(3):
		ores.append(FieldCatalog.exclusive("mine"))
		game.inventory.try_add(ores[-1])
	use(["ore_hoarder", "crystal_armor"])
	check("矿工的贪心: +18% life with three ore", is_equal_approx(p.max_hp, 2400 * 1.18))
	check("结晶护甲: +100 DEF with ore", is_equal_approx(p.defense_value(), 300))
	use(["ore_hoarder", "crystal_armor", "active_dust", "crystal_blade"])
	p.hp = p.max_hp
	var hp := p.hp
	game._physics_process(1.0)
	check("源石 2 halves the ore drain (3 x 30)", is_equal_approx(p.hp, hp - 90), [hp, p.hp])
	check("源石 4: +18% ATK and arts with three ore", is_equal_approx(p.attack_power(), 600 * 1.18) and is_equal_approx(p.arts_power(), 360 * (1.18 + 0.18)))
	check("活性源石粉 raises contamination accrual 25%", is_equal_approx(game.contamination_rate(), 3 * BaseCatalog.CONTAMINATION_PER_ORE * 1.25), game.contamination_rate())
	use(["vein_burst"])
	var near := dummy(Vector3(2, 0, 0))
	seed(11)
	var burst := false
	for i in range(30):
		var victim := dummy(Vector3(2.5, 0, 0.5), false, 0, 0, 1)
		victim.take_hit(10, "true")
		if near.health < near.max_health:
			burst = true
			break
	check("矿脉共振 bursts for 100% arts ATK", burst and is_equal_approx(near.max_health - near.health, 360))
	use(["obsession"])
	game.base.contamination = 50
	check("感染者的执念: +25% damage at contamination 50", is_equal_approx(p.attack_multiplier(), 1.25))
	game.base.contamination = 0
	await reset_arena()

func _hunter() -> void:
	var e := dummy(Vector3(0, 0, 2))
	use(["hunter_mark"])
	var marked := swing(e)
	check("猎人标记: +50% into a healthy enemy", is_equal_approx(marked, 900), marked)
	e.health = e.max_health * 0.5
	check("and nothing once it is hurt", is_equal_approx(swing(e), 600))
	use(["frost_trap"])
	var fresh := dummy(Vector3(-1, 0, 2))
	var first := swing(fresh)
	check("冻土绊索 slows on the first hit", fresh.status_value("slow") > 0 and is_equal_approx(first, 600))
	check("and hits slowed enemies 20% harder", is_equal_approx(swing(fresh), 720))
	use(["hunter_mark", "weak_point", "ambush", "trophy"])
	p.combat_timer = 6
	var opener := dummy(Vector3(1, 0, 2), false, 300)
	var expect := (600 * 1.5 * 2.0 * (1.5 + 0.3 + 0.5)) - 300 * 0.7
	check("猎手 4: the first strike crits with +50%, ambush doubles, 致命瞄点 pierces", is_equal_approx(swing(opener), expect))
	var boss := dummy(Vector3(-1, 0, -2), true, 0, 0, 1)
	p.hp = 1000
	boss.take_hit(10, "true")
	check("狩猎本能: an elite kill heals 20% and adds 10 攻速", is_equal_approx(p.hp, 1000 + p.max_hp * 0.2) and is_equal_approx(p.trophy_aspd, 10))
	check("猎手 2: +20% against elites", is_equal_approx(p.target_multiplier(dummy(Vector3(5, 0, 5), true)), 1.2 * 1.5))
	await reset_arena()
	var lone := dummy(Vector3(0, 0, 2))
	use(["lone_wolf"])
	check("孤狼: +45% with one enemy near", is_equal_approx(swing(lone), 870))
	dummy(Vector3(0, 0, 3))
	check("but not with two", is_equal_approx(swing(lone), 600))
	await reset_arena()

func _field() -> void:
	use(["gin_cup"])
	game.run_gold = 120
	check("庆功酒杯: +10 攻速 at 120 unbanked reward", is_equal_approx(p.current_aspd(), 110))
	use(["rush_clause", "suppressor"])
	p.hp = 1000
	game.run_gold = 0
	game.add_gold(10)
	check("加急条款 + 外勤 2: +55% reward and 2% life per pickup", game.run_gold == 15 and is_equal_approx(p.hp, 1048), [game.run_gold, p.hp])
	check("two 外勤 relics add the 外勤 2 reward bonus", is_equal_approx(p.gold_gain_multiplier, 1.0 + 0.3 + 0.25))
	game.pressure = 0
	game._on_enemy_died(dummy(Vector3(9, 0, 9)))
	check("警戒抑制器: a kill raises alert by 1.5 x 0.65", is_equal_approx(game.pressure, 1.5 * 0.65))
	use(["spare_pouch"])
	check("备用药囊: one more flask of room", p.potion_capacity == 4)
	use(["deep", "last_light"])
	game.floor_number = 4
	var mult := p.attack_multiplier()
	check("单程刻度 at depth 4 x 返航灯芯 by extraction state", is_equal_approx(mult, 1.24 * (1.0 if game.is_extraction_floor() else 1.2)))
	game.floor_number = 1
	await reset_arena()

func _bridges() -> void:
	use(["sidestep", "light_belt", "blade_edge", "whetstone", "shadow_chain"])
	p._dash_cooldown = 0
	p.stamina = 100
	p._start_dash(Vector3.LEFT)
	p.dash_remaining = 0
	p.invulnerable = false
	var e := dummy(Vector3(0, 0, 2))
	p.teleport(origin)
	var shadow := swing(e)
	check("无影连斩: hits right after a dodge always crit", is_equal_approx(shadow, 660 * 1.15 * 1.5), shadow)
	use(["buckler", "brooch", "field_kit", "tissue", "iron_blood"])
	p.hp = p.max_hp
	p.heal(500)
	check("铁血: healing past full becomes shield, up to 20%", is_equal_approx(p.shield, 500))
	p.heal(5000)
	check("capped at 20% of max life", is_equal_approx(p.shield, p.max_hp * 0.2))
	use(["snow_howl", "ore_flux"])
	var elite := dummy(Vector3(3, 0, 3), true, 300, 30)
	check("雪原狼嚎: waves hit elites 60% harder", is_equal_approx(p.wave_bonus_against(elite), 1.6))
	p.on_wave_hit(elite, 100, null)
	check("and strip 30% of their defence; 源石灼流 strips 20 resistance", is_equal_approx(elite.effective_defense(), 210) and is_equal_approx(elite.effective_res(), 10))
	use(["moon_blades", "blade_edge", "whetstone"])
	p.perfect_ready = true
	seed(3)
	var waves_before := game.get_children().filter(func(n): return n is SwordWave).size()
	var fired := false
	for i in range(20):
		p.perfect_ready = true
		swing(e)
		if game.get_children().filter(func(n): return n is SwordWave).size() > waves_before:
			fired = true
			break
	check("月下双刃: crits sometimes loose a free wave", fired)
	await reset_arena()
