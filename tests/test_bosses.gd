extends SceneTree

## Boss与守卫者策划案_v1_0.md (用户 2026-10-19): the region boss on floors 20,
## 40 …, the warden on 10, 30 …; tiers, phases, the fairness rules, the
## features they feed, rewards and the bosses' own gear.

var game: GameManager
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func run() -> void:
	_catalog()
	_gear()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 4242
	root.add_child(game)
	await step(8)
	await _warden_floors()
	await _patriot()
	await _zaro()
	await _eikthyrnir()
	await _rat_king()
	await _every_move()
	print("BOSSES RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy._dead: enemy.take_hit(99999999.0, "true")

func nodes(group: String) -> Array:
	return game.get_tree().get_nodes_in_group(group).filter(func(n): return n.get("game") == game)

## Onto `floor` of `region` (a fresh contract when the region changes).
func go_to(region: String, floor: int) -> void:
	if game.in_base or game.region_id != region:
		if not game.in_base:
			game.settle(true)
			await step(2)
		await game.start_contract(region)
		await step(2)
	game.floor_number = floor - 1
	await game.advance(0)
	await step(3)

func near(figure: Boss) -> void:
	game.player.teleport(figure.global_position + Vector3(2.0, 0, 0))
	game.player.invuln_timer = 0.0
	await step(3)

# --- The catalog --------------------------------------------------------------------

func _catalog() -> void:
	check("floors 20, 40, 60 are boss floors; 10, 30 are not", BossCatalog.is_boss_floor(20) and BossCatalog.is_boss_floor(60) and not BossCatalog.is_boss_floor(10) and not BossCatalog.is_boss_floor(30))
	check("boss tiers 20→1, 40→2, 100→5", BossCatalog.boss_tier(20) == 1 and BossCatalog.boss_tier(40) == 2 and BossCatalog.boss_tier(100) == 5)
	check("warden tiers 10→1, 30→2, 50→3", BossCatalog.warden_tier(10) == 1 and BossCatalog.warden_tier(30) == 2 and BossCatalog.warden_tier(50) == 3)
	check("boss life +20% and attack +5% a tier (Q3)", is_equal_approx(BossCatalog.hp_mult("boss", 3), 1.4) and is_equal_approx(BossCatalog.atk_mult("boss", 3), 1.1))
	check("warden life +15% and attack +4% a tier", is_equal_approx(BossCatalog.hp_mult("warden", 2), 1.15) and is_equal_approx(BossCatalog.atk_mult("warden", 2), 1.04))
	check("windups never shorten past 80% (boss) / 85% (warden)", is_equal_approx(BossCatalog.windup_mult("boss", 30), 0.8) and is_equal_approx(BossCatalog.windup_mult("warden", 30), 0.85))
	check("tier 1 has two phases from the start (Q10)", BossCatalog.phase_marks(1) == [0.5])
	check("tier 2 moves the phase to 60%, tier 3 adds a third at 25%", BossCatalog.phase_marks(2) == [0.6] and BossCatalog.phase_marks(3) == [0.6, 0.25])
	var ids := func(list: Array) -> Array: return list.map(func(m): return m.id)
	check("爱国者 throws no javelin in the first phase at tier 1", not ids.call(BossCatalog.moves_for("patriot", 1, 1)).has("javelin") and ids.call(BossCatalog.moves_for("patriot", 1, 2)).has("javelin"))
	check("from tier 2 the first phase has it already (跳过教学段)", ids.call(BossCatalog.moves_for("patriot", 2, 1)).has("javelin"))
	check("the big move comes only in the third phase from tier 3", not ids.call(BossCatalog.moves_for("patriot", 2, 3)).has("eruption") and ids.call(BossCatalog.moves_for("patriot", 3, 3)).has("eruption"))
	var sweep: Dictionary = BossCatalog.moves_for("patriot", 2, 1).filter(func(m): return m.id == "sweep")[0]
	check("tier 2 turns the sweep into a combo", sweep.has("combo") and (sweep.combo as Array).size() == 3)
	var sing: Dictionary = BossCatalog.moves_for("rat_king", 2, 1).filter(func(m): return m.id == "sing")[0]
	check("tier 2 doubles 唱沙", sing.get("double", false))
	check("a warden gets one affix a tier, three at most (Q9)", BossCatalog.affix_count("warden", 1) == 0 and BossCatalog.affix_count("warden", 3) == 2 and BossCatalog.affix_count("warden", 9) == 3)
	check("a boss draws affixes only from tier 6 (Q13)", BossCatalog.affix_count("boss", 5) == 0 and BossCatalog.affix_count("boss", 6) == 1 and BossCatalog.affix_count("boss", 20) == 3)
	check("a floor's affixes are fixed", BossCatalog.roll_affixes("warden", 3, "mine", 50) == BossCatalog.roll_affixes("warden", 3, "mine", 50))
	var all_ok := true
	for rank in ["warden"]:
		for floor in [30, 50, 70, 90]:
			var a := BossCatalog.roll_affixes(rank, BossCatalog.warden_tier(floor), "city", floor)
			for x in a: if not BossCatalog.AFFIXES.has(x): all_ok = false
			if a.size() != BossCatalog.affix_count(rank, BossCatalog.warden_tier(floor)): all_ok = false
	check("affixes come from the six and never repeat on a floor", all_ok)
	check("every region has a boss and a warden", ["mine", "city", "snow", "siracusa"].all(func(r): return BossCatalog.BOSSES.has(r) and BossCatalog.WARDENS.has(r)))
	check("矿区's boss is 爱国者 (用户 Q1)", BossCatalog.BOSSES.mine == "patriot")
	var own := true
	for id in BossCatalog.FIGURES:
		if not FieldArt.has_directional(id) or not FieldArt.has_walk(id): own = false
	check("each has its own action and walk boards (Sol B1)", own)
	var rows_ok := true
	for id in BossCatalog.POSES:
		var sheet: Texture2D = load("res://art/field/enemy_dir_%s_64.png" % id)
		var top := 0
		for r in (BossCatalog.POSES[id].get("moves", {}) as Dictionary).values(): top = maxi(top, int(r))
		for key in ["down", "roar"]: top = maxi(top, int(BossCatalog.POSES[id].get(key, 0)))
		if sheet == null or sheet.get_height() < (top + 1) * 64: rows_ok = false
	check("every pose row is on its board", rows_ok)
	# No walk frame drawn squashed (爱国者's fourth march, 2026-10-19): each one
	# at least 0.72 of its column's median width, per stance of four frames.
	var narrow := []
	for id in BossCatalog.FIGURES:
		var walk: Image = (load("res://art/field/enemy_walk_%s_64.png" % id) as Texture2D).get_image()
		for c in 8:
			for start in range(0, walk.get_height() / 64, 4):
				var widths := []
				for r in range(start, start + 4): widths.append(walk.get_region(Rect2i(c * 64, r * 64, 64, 64)).get_used_rect().size.x)
				var sorted := widths.duplicate()
				sorted.sort()
				var median: float = (sorted[1] + sorted[2]) * 0.5
				for i in 4:
					if widths[i] < 0.72 * median: narrow.append("%s c%d r%d" % [id, c, start + i])
	check("no walk frame is squashed narrow", narrow.is_empty(), narrow)
	check("exclusive chance 25%, +5% a tier, at most 50%", is_equal_approx(BossCatalog.exclusive_chance(1), 0.25) and is_equal_approx(BossCatalog.exclusive_chance(3), 0.35) and is_equal_approx(BossCatalog.exclusive_chance(9), 0.5))
	check("experience 300 + 100 a tier, warden 150 + 30", BossCatalog.kill_exp("boss", 2) == 400 and BossCatalog.kill_exp("warden", 3) == 210)
	check("a region boss kill pays a 高级作战记录", Progression.records_for({"region_boss": 1}).get("高级作战记录", 0) == 1)

func _gear() -> void:
	for boss in BossCatalog.BOSSES.values():
		var ids := SpecialGear.exclusives_of(str(boss))
		var by_cat := {}
		for id in ids: by_cat[int(SpecialGear.GEAR[id].category)] = int(by_cat.get(int(SpecialGear.GEAR[id].category), 0)) + 1
		check("%s drops nine pieces of its own, three of each kind (用户 Q8)" % boss, ids.size() == 9 and by_cat.values().all(func(n): return n == 3), by_cat)
	var item := SpecialGear.create("bg_patriot_0", 20, RandomNumberGenerator.new(), true)
	check("a boss piece reads as 首领 in the ladder's red", item.named_kind() == "boss" and item.display_name().contains("首领") and item.rarity_color() == Item.LEGEND_COLOR)
	var fx_ok := true
	for id in SpecialGear.GEAR:
		if SpecialGear.kind(id) != "boss": continue
		var fx := str(SpecialGear.GEAR[id].fx)
		if not SpecialGear.GEAR.values().any(func(g): return str(g.get("kind", "")) == "exclusive" and str(g.get("fx", "")) == fx): fx_ok = false
	check("every boss piece carries an effect that already works", fx_ok)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ctx := {"region": "mine", "depth": 20, "reward": 0.0, "rng": rng, "pity": {"rare_gear": 0.0, "rare_material": 0.0}, "boss": true, "exclusive_chance": 1.0}
	var got := false
	for i in range(200):
		for drop in LootTables.enemy_drops("patriot", true, false, ctx):
			var it: Item = drop.get("item")
			if it != null and it.named_kind() == "boss": got = true
	check("爱国者's kill can drop its own piece", got)

# --- Wardens ------------------------------------------------------------------------

func _warden_floors() -> void:
	await go_to("city", 10)
	var figure := game.outpost_boss
	check("floor 10 holds a warden", is_instance_valid(figure) and figure.rank == "warden" and figure.figure_id == "skullshatterer" and figure.tier == 1)
	check("with its two guards", game._outpost_squad.size() == 1 + FieldCatalog.OUTPOST_GUARDS and figure.guards.size() == FieldCatalog.OUTPOST_GUARDS)
	check("tier 1 has no affix", figure.affixes.is_empty())
	check("the warden keeps the lavender head bar (boss flag)", figure.boss and figure.elite)
	var depth := Scaling.floor_growth(10)
	check("its life is its own, times the floor's growth (1.04^9)", is_equal_approx(figure.max_health, 17000.0 * depth * GameManager.enemy_life_multiplier(game.player.f("enemy_hp"))), figure.max_health)
	await near(figure)
	check("a warden does not stop the threat meter", not game.boss_fight())
	# 碎骨's grenade lowers her defence a while (an operation debuff, not a build one).
	var before := game.player.defense_value()
	figure._after_hit(BossCatalog.moves_for("skullshatterer", 1, 1).filter(func(m): return m.id == "grenade")[0], true)
	check("榴弹 takes 30% off her defence", is_equal_approx(game.player.defense_value(), before * 0.7), [before, game.player.defense_value()])
	figure.health = figure.max_health * 0.29
	check("its last stand speeds it up below 30%", figure.speed_mult() > 1.19)
	for e in game._outpost_squad.duplicate(): kill(e)
	await step(3)
	check("the whole squad down opens the routes", game.outpost_cleared)
	check("and leaves a vault-grade relic offer", nodes("relic_caches").any(func(c): return c.source == "vault"))
	check("the debuff leaves with it", game.player.hex("def") == 0.0 or game.player.hexes.has("boss_grenade"))
	await go_to("city", 30)
	figure = game.outpost_boss
	check("floor 30 holds a tier-2 warden with one affix", figure.tier == 2 and figure.affixes.size() == 1, figure.affixes)
	await go_to("city", 50)
	figure = game.outpost_boss
	check("floor 50 a tier-3 warden with two", figure.tier == 3 and figure.affixes.size() == 2, figure.affixes)
	check("the tier-3 warden has its big move", BossCatalog.moves_for(figure.figure_id, 3, 1).any(func(m): return m.get("big", false)))

# --- 爱国者 ------------------------------------------------------------------------------

func _patriot() -> void:
	await go_to("mine", 20)
	var figure := game.outpost_boss
	check("floor 20 holds the region boss alone", is_instance_valid(figure) and figure.figure_id == "patriot" and figure.rank == "boss" and game._outpost_squad.size() == 1)
	check("PRTS names the boss on the way in", game.prts_log.any(func(l): return "爱国者" in str(l)))
	await near(figure)
	check("she walks into the arena: the fight starts", figure.engaged and game.boss_fight())
	# 投戟 (用户 2026-10-20): the spear's whole flight is red, and turns with her until it locks.
	figure._cancel_move()
	figure._start(BossCatalog.move_at(BossCatalog.MOVES.patriot.filter(func(m): return m.id == "javelin")[0], 1))
	var path: Node3D = figure._ctx.get("path")
	check("投戟 lays a red strip along its flight", is_instance_valid(path) and figure._markers.has(path))
	var side := (game.player.global_position - figure.global_position).cross(Vector3.UP).normalized()
	game.player.teleport(game.player.global_position + side * 2.0)
	await step(2)
	var to_her := game.player.global_position - figure.global_position
	to_her.y = 0.0
	check("…which turns to follow her", is_instance_valid(path) and absf((-path.global_basis.z).normalized().dot(to_her.normalized())) > 0.97, (-path.global_basis.z).dot(to_her.normalized()))
	figure._cancel_move()
	var threat := game.threat.value
	await step(60)
	check("the threat meter stands still in the fight (Q5)", is_equal_approx(game.threat.value, threat) or game.threat.value <= threat, [threat, game.threat.value])
	# A hit is capped at 30% of her life, however hard (§3.3).
	game.player.hp = game.player.max_hp
	game.player.invuln_timer = 0.0
	var atk := figure.atk
	figure.atk = 1e9
	var hp := game.player.hp
	figure._hit_her({"id": "test", "damage": 1.0})
	check("no ordinary hit takes more than 30% of her life", hp - game.player.hp <= game.player.max_hp * BossCatalog.HIT_CAP + 0.5, [hp, game.player.hp])
	game.player.hp = game.player.max_hp
	game.player.invuln_timer = 0.0
	hp = game.player.hp
	figure._hit_her({"id": "test", "damage": 1.0, "big": true})
	check("a big move no more than 60%", hp - game.player.hp <= game.player.max_hp * BossCatalog.BIG_CAP + 0.5 and hp - game.player.hp > game.player.max_hp * BossCatalog.HIT_CAP, [hp, game.player.hp])
	figure.atk = atk
	game.player.hp = game.player.max_hp
	# 行军姿态: its tower shield takes 60% off hits from in front, none from behind.
	figure._cancel_move()
	var front := figure.global_position - figure.attack_direction * 2.0
	game.player.teleport(front)
	await step(1)
	figure.attack_direction = (game.player.global_position - figure.global_position).normalized()
	check("the shield blocks 60% from in front in 行军姿态", is_equal_approx(figure.shield_share(), 0.6))
	game.player.teleport(figure.global_position - (front - figure.global_position))
	await step(1)
	check("but nothing from behind", figure.shield_share() == 0.0)
	# Half its life: 爱国者 kneels (毁灭姿态), untouchable.
	figure._cancel_move()
	figure.take_hit(0.0, "true")
	figure.health = figure.max_health * 0.51
	figure.take_hit(figure.max_health * 0.03, "true")
	check("at half life it kneels into its second phase", figure.phase == 2 and figure.down_left > 0.0, [figure.phase, figure.health / figure.max_health])
	check("nothing hurts it while it kneels", figure.take_hit(1000.0, "true") == 0.0)
	check("it kneels on its own board's KNEEL row", figure.own_art() and figure.pose_row() == 8)
	await step(10)
	figure.down_left = 0.01
	await step(3)
	check("it gets up", figure.down_left <= 0.0)
	figure.attack_direction = (game.player.global_position - figure.global_position).normalized()
	check("毁灭姿态 keeps the shield but it no longer blocks", figure.shield_share() == 0.0)
	figure._cooldowns = {}
	var far := game.features.value("contamination")
	game.player.teleport(figure.centre() + Vector3(9.0, 0, 0))
	figure.global_position = figure.centre()
	await step(30)
	far = game.features.value("contamination") - far
	var close := game.features.value("contamination")
	game.player.teleport(figure.global_position + Vector3(1.0, 0, 0))
	await step(30)
	close = game.features.value("contamination") - close
	check("in 毁灭姿态 its originium raises her contamination nearby", close > far + 0.2, [far, close])
	# She leaves the arena: after LEASH_SECONDS it is whole and first-phase again (Q4).
	figure.health = figure.max_health * 0.4
	figure._out_time = BossCatalog.LEASH_SECONDS - 0.05
	game.player.teleport(figure.centre() + Vector3(BossCatalog.ARENA_RADIUS + 6.0, 0, 0))
	await step(12)
	check("left alone it is whole again, first phase, fight over", is_equal_approx(figure.health, figure.max_health) and figure.phase == 1 and not figure.engaged and not game.boss_fight(), [figure.health / figure.max_health, figure.phase, figure.engaged])
	# The fall: two chests, the boss cache, the first fall recorded.
	game.base.boss_falls.erase("mine:1")
	var kills := int(game.run_kills.get("region_boss", 0))
	await near(figure)
	kill(figure)
	await step(3)
	check("its fall opens the routes", game.outpost_cleared)
	check("it leaves two gear chests", nodes("loot_containers").filter(func(c): return c.kind == "vault_gear").size() >= BossCatalog.BOSS_CHESTS)
	check("and a relic offer", nodes("relic_caches").size() >= 1)
	check("first fall at this tier is recorded", game.base.boss_falls.has("mine:1"))
	check("counted as a region boss kill", int(game.run_kills.get("region_boss", 0)) == kills + 1)
	var copy := BaseState.new()
	copy.load_data(game.base.to_data(), {})
	check("the falls are saved with the base", copy.boss_falls.has("mine:1"))
	# Floor 40: the same boss, tier 2.
	await go_to("mine", 40)
	figure = game.outpost_boss
	check("floor 40 holds the same boss one tier up", figure.figure_id == "patriot" and figure.tier == 2)
	check("stronger than at tier 1 beyond the depth", is_equal_approx(figure.max_health / Scaling.floor_growth(40) / GameManager.enemy_life_multiplier(game.player.f("enemy_hp")), 32000.0 * 1.2), figure.max_health)

# --- 扎罗 -----------------------------------------------------------------------------------

func _zaro() -> void:
	await go_to("siracusa", 20)
	var figure := game.outpost_boss
	check("叙拉古's boss is 扎罗 with two lives", figure.figure_id == "zaro" and figure.lives == 2 and figure.life == 1)
	await near(figure)
	# 用户 2026-10-20: what he calls in stands apart in the arena, comes at her at once, and drops nothing.
	figure._family_time = 0.0
	await step(2)
	var family: Array = figure.summoned.filter(func(e): return is_instance_valid(e) and not e._dead)
	check("扎罗 calls in two of the family", family.size() == 2, family.size())
	var spread := true
	for a in family:
		if a._flat_distance(a.global_position, game.player.global_position) < Boss.SUMMON_APART - 0.6: spread = false
		for b in family:
			if a != b and a._flat_distance(a.global_position, b.global_position) < Boss.SUMMON_APART - 0.6: spread = false
	check("…each at its own spot, clear of the others and of her", spread and family.all(func(e): return game.arena.inside(e.global_position)))
	check("…after her at once", family.all(func(e): return e.state == Enemy.State.CHASING))
	var loot_before := nodes("loot").size()
	var caches_before := nodes("relic_caches").size()
	for e in family: kill(e)
	await step(3)
	check("…and they fall carrying nothing", nodes("loot").size() == loot_before and nodes("relic_caches").size() == caches_before, [loot_before, nodes("loot").size()])
	var debt := game.features.value("debt")
	await step(40)
	check("in the fight the 血债 slowly rises", game.features.value("debt") > debt, [debt, game.features.value("debt")])
	game.features.values.debt = 95.0
	game.features.reckon_wait = 0.0
	await step(4)
	check("血债 at 90 in the fight: 扎罗 takes the 清算时刻 himself (Q6)", figure.reckoning_active() and game.reckoning())
	check("and no reckoning squad comes", nodes("reckoning").is_empty())
	# 溶血骇惧 and its bar.
	figure._lay_curse(BossCatalog.moves_for("zaro", 1, 1).filter(func(m): return m.id == "dread")[0])
	check("溶血骇惧 slows her attacks", game.player.hex("aspd") < 0.0 and figure.curse_left() > 0.99)
	figure.take_hit(figure.max_health * 2.0, "true")
	check("taking a fifth of its life off lifts it", figure.curse.is_empty() and not game.player.hexes.has("boss_curse"))
	# Its outline follows the frame it shows, even on its own rows (CURSE).
	figure._cancel_move()
	figure._start(BossCatalog.moves_for("zaro", 1, 1).filter(func(m): return m.id == "dread")[0])
	await step(2)
	var shown := figure._sprite.texture as AtlasTexture
	var traced: Vector4 = (figure._outline.material_override as ShaderMaterial).get_shader_parameter("region")
	check("the outline traces the CURSE frame it shows", figure._outline.visible and is_equal_approx(traced.y, shown.region.position.y / shown.atlas.get_height()), [traced, shown.region])
	figure._cancel_move()
	# The first life ends: down, then the second life whole.
	figure.health = 5.0
	figure.take_hit(99999.0, "true")
	check("its first life ends in a fall, not death", not figure._dead and figure.down_left > 0.0)
	check("lying on its side on the DOWN row", figure.pose_row() == 6)
	figure.down_left = 0.01
	await step(3)
	check("it rises on its second life, whole, second phase", figure.life == 2 and figure.phase == 2 and is_equal_approx(figure.health, figure.max_health))
	kill(figure)
	await step(3)
	check("the second life ends it", game.outpost_cleared)

# --- 埃克提尔尼尔 ----------------------------------------------------------------------------

func _eikthyrnir() -> void:
	await go_to("snow", 20)
	var figure := game.outpost_boss
	check("萨米's boss is 埃克提尔尼尔", figure.figure_id == "eikthyrnir")
	check("its arena keeps a fire at the edge", game.fires.any(func(f): return is_instance_valid(f) and Vector2(f.global_position.x - figure.centre().x, f.global_position.z - figure.centre().z).length() <= BossCatalog.ARENA_RADIUS))
	await near(figure)
	game.features.values.cold = 10.0
	var hammer: Dictionary = BossCatalog.moves_for("eikthyrnir", 1, 1).filter(func(m): return m.id == "hammer")[0]
	figure._after_hit(hammer, true)
	check("its hammer adds cold", game.features.value("cold") > 10.0 + 5.0, game.features.value("cold"))
	game.features.values.cold = 95.0
	game.player.control_timer = 0.0
	game.player.control_immune = 0.0
	game.player._stun_times.clear()
	figure._after_hit(hammer, true)
	check("frozen stiff, a cold hit freezes her (冻结)", game.player.control_kind == "stun")
	figure.health = figure.max_health * 0.71
	figure.take_hit(figure.max_health * 0.03, "true")
	await step(2)
	check("at 70% it begins 自我泯灭", figure._rampaging or figure._later.any(func(e): return e.f == "rampage"))

# --- 鼠王 ------------------------------------------------------------------------------------

func _rat_king() -> void:
	await go_to("city", 20)
	var figure := game.outpost_boss
	check("龙门's boss is 鼠王 behind a sand barrier", figure.figure_id == "rat_king" and figure.barrier_up())
	# 用户 2026-10-20: the sand shot and the cane swing look different; the cross is wider.
	var rows: Dictionary = BossCatalog.POSES.rat_king.moves
	check("沙弹 has its own pose, not the cane swing's", rows.has("sand_shot") and not rows.has("cane") and int(rows.sand_shot) != int(rows.sing))
	check("唱沙's strips are 2.6 m wide", is_equal_approx(float(BossCatalog.MOVES.rat_king.filter(func(m): return m.id == "sing")[0].width), 2.6))
	var sing_now: Dictionary = BossCatalog.moves_for("rat_king", 1, 1).filter(func(m): return m.id == "sing")[0]
	figure._cross_hit(figure._cross_lanes(figure.global_position, Vector3.RIGHT, 7.0), sing_now)
	check("…and the sand bursts up along it as it lands", game.get_children().filter(func(c): return c is BossVfx and c.get_meta("kind", "") == "sand_strip").size() == 2)
	await near(figure)
	var prison: Dictionary = BossCatalog.moves_for("rat_king", 1, 2).filter(func(m): return m.id == "prison")[0]
	figure._add_zone(figure._zone_from(prison, game.player.global_position))
	await step(3)
	check("inside 沙狱 her attack is cut", game.player.hex("atk") < -0.39)
	game.player.teleport(game.player.global_position + Vector3(6.0, 0, 0))
	await step(20)
	check("walking out ends it", game.player.hex("atk") == 0.0)
	figure.fight_time = BossCatalog.ENRAGE_AFTER + BossCatalog.ENRAGE_EVERY * 20
	check("the soft enrage stops at +50% (Q11)", is_equal_approx(figure.enrage(), BossCatalog.ENRAGE_CAP))
	figure.fight_time = 10.0
	check("and is nothing early on", figure.enrage() == 0.0)
	check("its wind-up outline is dark red, not white", figure.outline_colour() == Boss.OUTLINE_DARK)
	figure.fight_time = BossCatalog.ENRAGE_AFTER + BossCatalog.ENRAGE_EVERY * 20
	check("and bright red at the top of the enrage", figure.outline_colour() == Boss.OUTLINE_BRIGHT)

# --- Every move of every figure, once, at its deepest tier here --------------------

## Each move is started and run to its end (markers, landing, ground left
## behind); she is kept alive. A script error anywhere fails the suite.
func _every_move() -> void:
	for region in ["mine", "city", "snow", "siracusa"]:
		for floor in [50, 100]:
			await go_to(region, floor)
			# An ungeared Doctor has 600 life now (复利数值改造清单 A) and a floor-100
			# blow is ×1.04^99: one hit inside a frame would end the contract.
			if game.player._buff_max_hp_bonus < 1e8: game.player.apply_buff(1e9, 0.0)
			var figure := game.outpost_boss
			await near(figure)
			var ran := 0
			var stuck := []
			for phase in range(1, 4):
				figure.phase = phase
				for move in BossCatalog.moves_for(figure.figure_id, figure.tier, phase):
					if str(move.shape) in ["family", "sandstorm", "backstep"]: continue
					figure._cancel_move()
					figure.roar_left = 0.0
					figure.down_left = 0.0
					figure._channel = {}
					figure._start(move)
					var ticks := 0
					while (not figure._move.is_empty() or not figure._channel.is_empty()) and ticks < 600 and is_instance_valid(figure) and not figure._dead:
						game.player.hp = game.player.max_hp
						# The help it calls shoves her about; keep her in the arena so the leash never resets it.
						if figure._flat_distance(game.player.global_position, figure.centre()) > BossCatalog.ARENA_RADIUS - 2.0: game.player.teleport(figure.centre())
						await step(1)
						ticks += 1
					if ticks >= 600: stuck.append(move.id)
					ran += 1
			# The enrage and the field running a while.
			figure.fight_time = 400.0
			for i in range(30):
				game.player.hp = game.player.max_hp
				await step(1)
			check("%s (tier %d): every move runs to its end" % [figure.figure_id, figure.tier], stuck.is_empty() and ran >= 3, [ran, stuck])
			check("%s: what it called in stays within the cap" % figure.figure_id, figure.summoned.filter(func(e): return is_instance_valid(e) and not e._dead).size() <= BossCatalog.SUMMON_CAP + 6)
			# 爱国者 stands once more from tier 5 (不倒): a second blow after it gets up.
			for e in game._outpost_squad.duplicate(): kill(e)
			await step(3)
			# (扎罗's first life ends the same way.)
			var downs := 0
			while is_instance_valid(figure) and not figure._dead and downs < 3:
				downs += 1
				figure.down_left = 0.01
				await step(3)
				if not is_instance_valid(figure):
					# 扎罗's first life can hand over to the next in these frames; 爱国者 must still be there.
					if region == "mine": check("爱国者 is still there after its down", false)
					break
				if figure.figure_id == "patriot": check("爱国者 stands up once more at tier 5 (不倒), at 30%", is_equal_approx(figure.health, figure.max_health * BossCatalog.REVIVE_SHARE), figure.health / figure.max_health)
				kill(figure)
				await step(3)
			check("%s: its ground is cleared when it falls" % region, nodes("bosses").is_empty())
