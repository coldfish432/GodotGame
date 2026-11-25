extends SceneTree

## 元素转化与高血量词条修订案 v0.1: 转化 lines in each region's weapon and
## hands pools (its own element), 转为法术 in every weapon pool, one 60% cap
## for all of them, the arts share of a physical hit dealt as arts; 凋亡 on
## any weapon; 对高血量敌人伤害 by max life against 2500 × growth × contract.

var game: GameManager
var checks := 0
var failures := 0
var origin := Vector3.ZERO

func _initialize() -> void: call_deferred("run")
func step(n: int = 2) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	_tables()
	game = GameManager.new()
	game.start_at_base = false
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(10)
	origin = ContinuousWorldMap.ENTRY_POSITION
	origin.y = 0.65
	game.player.set_physics_process(false)
	game.pressure = 0
	SystemScreens.settings["auto_potion"] = false
	_cap()
	await _arts_share()
	await _high_hp()
	print("DOWNFALL TEST_CONVERSION_AFFIXES: %d checks / %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

const S := ItemModifier.Stat
const LOCAL_CONV := {"mine": S.CONV_CORR, "city": S.CONV_BURN, "snow": S.CONV_COLD, "siracusa": S.CONV_NERVE}

func _tables() -> void:
	var ok := true
	for region in LOCAL_CONV:
		var stat: int = LOCAL_CONV[region]
		ok = ok and FieldCatalog.region_pool(region, Item.Category.WEAPON, "blade").has(stat) and FieldCatalog.region_pool(region, Item.Category.HANDS).has(stat)
		for other in LOCAL_CONV:
			if other != region and FieldCatalog.region_pool(other, Item.Category.WEAPON, "blade").has(stat): ok = false
	check("each region's weapon and hands pools convert to its own element, and only there", ok)
	check("转为法术 is in every weapon's general pool", FieldCatalog.AFFIX_POOLS[Item.Category.WEAPON].has(S.CONV_ARTS))
	var rng := RandomNumberGenerator.new()
	var weapon := ItemModifier.roll_affix(S.CONV_COLD, Item.BLUE, rng, 0.5, 1, Item.Category.WEAPON)
	var hands := ItemModifier.roll_affix(S.CONV_COLD, Item.BLUE, rng, 0.5, 1, Item.Category.HANDS)
	var arts := ItemModifier.roll_affix(S.CONV_ARTS, Item.BLUE, rng, 0.5, 1, Item.Category.WEAPON)
	check("a blue's middle: weapon 15%, hands 6%, 转为法术 15%", is_equal_approx(weapon.amount, 0.15) and is_equal_approx(hands.amount, 0.06) and is_equal_approx(arts.amount, 0.15), [weapon.amount, hands.amount, arts.amount])
	check("转为法术 reads as a line of its own", arts.describe().contains("转为法术"), arts.describe())
	var forms := ["blade", "fist", "heavy", "gun", "staff"]
	check("凋亡 rolls on any snow weapon, not only a staff", forms.all(func(f): return FieldCatalog.region_pool("snow", Item.Category.WEAPON, f).has(S.NECRO_CHANCE)))
	check("bleeding still wants an edge or fists", FieldCatalog.region_pool("city", Item.Category.WEAPON, "blade").has(S.BLEED_CHANCE) and not FieldCatalog.region_pool("city", Item.Category.WEAPON, "staff").has(S.BLEED_CHANCE))
	var hp_line := ItemModifier.roll_affix(S.FULL_HP_DMG, Item.BLUE, rng, 0.5, 1, Item.Category.WEAPON)
	var hp_hands := ItemModifier.roll_affix(S.FULL_HP_DMG, Item.BLUE, rng, 0.5, 1, Item.Category.HANDS)
	check("高血量: weapon 15%, hands 5%, and it says 高血量", is_equal_approx(hp_line.amount, 0.15) and is_equal_approx(hp_hands.amount, 0.05) and hp_line.describe().contains("高血量"), [hp_line.amount, hp_hands.amount, hp_line.describe()])

func clear_offence() -> void:
	var p := game.player
	for kind in Elements.KINDS:
		p.stats[Elements.ADD_KEY[kind]] = 0.0
		p.stats[Elements.CONV_KEY[kind]] = 0.0
	for key in ["conv_arts", "arts_dmg_pct", "phys_dmg_pct", "full_hp_dmg", "crowd_dmg", "chain_dmg", "ambush_dmg", "low_hp_dmg", "stunned_dmg", "ore_atk", "debt_dmg"]:
		p.stats[key] = 0.0

func _cap() -> void:
	var p := game.player
	clear_offence()
	p.stats["conv_burn"] = 0.5
	p.stats["conv_arts"] = 0.3
	var parts: Dictionary = p.elements.convert_parts("phys")
	check("elements and 转为法术 share one 60% cap, in proportion", is_equal_approx(p.elements.convert_share("phys"), 0.6) and is_equal_approx(float(parts.burn), 0.375) and is_equal_approx(float(parts.arts), 0.225), parts)
	var arts_parts: Dictionary = p.elements.convert_parts("arts")
	check("an arts hit has no 转为法术: only the elements convert", not arts_parts.has("arts") and is_equal_approx(float(arts_parts.burn), 0.5), arts_parts)
	clear_offence()

func enemy(type: String, elite := false, at := Vector3(1.5, 0, 0)) -> Enemy:
	var e := game._spawn_enemy(origin + at, elite, false, type)
	e.set_physics_process(false)
	e.max_health *= 100.0
	e.health = e.max_health
	return e

func _arts_share() -> void:
	var p := game.player
	var e := enemy("family_intimidator")
	clear_offence()
	p.stats["conv_arts"] = 0.4
	p.stats["arts_dmg_pct"] = 0.2
	var raw := 1000.0
	var expected_phys := CombatStats.mitigate(raw * 0.6, "phys", e.effective_defense(), e.res_against("phys"))
	var expected_arts := CombatStats.mitigate(raw * 0.4 * 1.2, "arts", e.effective_defense(), e.res_against("arts"))
	var before := e.health
	var dealt := p._deal(e, raw, "phys", false)
	check("a physical hit: 60% physical, 40% as arts with the arts bonus", absf(dealt - (expected_phys + expected_arts)) < 0.5 and absf(before - e.health - dealt) < 0.5, [dealt, expected_phys, expected_arts])
	var plain := CombatStats.mitigate(raw, "phys", e.effective_defense(), e.res_against("phys"))
	check("…which beats plain physical on high DEF (家族恫吓者)", dealt > plain * 1.1, [dealt, plain])
	var expected_full_arts := CombatStats.mitigate(raw * 1.2, "arts", e.effective_defense(), e.res_against("arts"))
	var arts_dealt := p._deal(e, raw, "arts", false)
	check("an arts hit is not split", absf(arts_dealt - expected_full_arts) < 0.5, [arts_dealt, expected_full_arts])
	clear_offence()
	e.queue_free()
	await step()

func _high_hp() -> void:
	var p := game.player
	clear_offence()
	var t: float = p.elements.high_hp_threshold()
	check("the line: 2500 × the floor's growth × 合同深入系数", is_equal_approx(t, Elements.HIGH_HP * Scaling.floor_growth(game.floor_number) * game.contract_life()) and is_equal_approx(Elements.HIGH_HP, 2500.0), t)
	var thug := game._spawn_enemy(origin + Vector3(1.5, 0, 0), false, false, "thug")
	var elite := game._spawn_enemy(origin + Vector3(-1.5, 0, 0), true, false, "elite")
	for e in [thug, elite]: e.set_physics_process(false)
	p.stats["full_hp_dmg"] = 0.15
	check("an elite is high-HP, a thug is not", is_equal_approx(p.elements.damage_mult(elite), 1.15) and is_equal_approx(p.elements.damage_mult(thug), 1.0), [elite.max_health, thug.max_health, t])
	elite.health = elite.max_health * 0.3
	check("…and it holds the whole fight, not only the first hit", is_equal_approx(p.elements.damage_mult(elite), 1.15))
	clear_offence()
	for e in [thug, elite]: e.queue_free()
	await step()
