extends SceneTree
## 赫拉格 (干员寻访 R2, HellagurKit): deployable once recruited, his sheets and
## combat frames, the three-cut combo healing on every hit, flasks and
## regeneration at half (用户 2026-10-16), 月盈星亏's attack speed, and 月相
## cycling 新月 → 弦月 → 满月, plus 坚忍 and a dodge interrupting.
var game: GameManager
var p: Player
var failures := 0
var origin := Vector3(0, 0.7, -22)
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
func dummy(point: Vector3, hp: float = 100000) -> Enemy:
	game._spawn_enemy(point, true, false)
	var enemy := game.get_child(game.get_child_count() - 1) as Enemy
	enemy.max_health = 100000
	enemy.health = hp
	enemy.defense = 0
	enemy.res = 0
	enemy.set_physics_process(false)
	enemy.global_position = point
	return enemy
func clear_enemies() -> void:
	for node in get_nodes_in_group("enemies"):
		node.remove_from_group("enemies")
		node.queue_free()
func cast(point: Vector3) -> bool:
	p.hitstop_remaining = 0
	return p.cast_skill(point)
func swing(enemy: Enemy) -> void:
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.attack(enemy)
func tick(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		p.hitstop_remaining = 0
		p.kit.tick(1.0 / 60.0)
		t += 1.0 / 60.0
func lost(enemy: Enemy) -> float:
	return 100000 - enemy.health
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	game.choose_operator("hellagur")
	check("not recruited: he cannot be chosen", game.player.operator_id != "hellagur")
	game.base.roster.append("hellagur")
	check("recruited with his kit built: deployable", "hellagur" in game.base.deployable() and Operators.has_kit("hellagur"))
	game.choose_operator("hellagur")
	check("chosen: his kit and sheets", game.player.kit is HellagurKit and game.player._sprite.character == "hellagur"
		and game.player._sprite.sprite_frames.has_animation(&"fullmoon_south") and game.player._sprite.sprite_frames.get_frame_count(&"halfmoon_west") == 3)
	check("his tree, talent and module exist", SkillTrees.tree("hellagur").size() == 9 and SkillTrees.TALENTS.has("hellagur") and SkillTrees.MODULES.has("hellagur")
		and not SkillTrees.describe("hellagur", "moon", 1).contains("%s"))
	await game.start_contract("mine")
	game._clear_field()
	await step(2)
	game.set_process(false)
	p = game.player
	p.set_physics_process(false)
	p._sprite.set_process(false)
	p.teleport(origin)
	p.stats["crit"] = -1.0
	check("no sword charge: 月相 is on Space", not p.has_sword_wave() and p.has_skill() and p.skill_ready_now())

	# Combo: 1.0 / 1.0 / 1.3 physical, every landed hit heals 1.5% max HP.
	var e := dummy(origin + Vector3(0, 0, -2))
	var atk := p.attack_power()
	p.hp = p.max_hp * 0.5
	var hp0 := p.hp
	swing(e)
	check("stage 1 cuts for ATK", is_equal_approx(lost(e), atk))
	check("the hit heals him 1.5% max HP", is_equal_approx(p.hp - hp0, p.max_hp * HellagurKit.HIT_HEAL))
	swing(e)
	swing(e)
	check("stages 2 and 3: 1.0 and the 1.3 iai", is_equal_approx(lost(e), atk * 3.3))
	check("the combo loops", p.combo_step == 0)

	# 饮刃: flasks and self-regeneration at half; the talent's attack speed.
	check("flask healing halved", is_equal_approx(p.potion_heal_multiplier, 0.5 * maxf(0.2, 1.0 + BaseCatalog.POTION_HEAL_PER_CAP * float(p.stats.potion_cap))))
	check("regeneration halved", p.kit.regen_factor() == 0.5)
	game.base.progress_for("hellagur").elite = 2
	p.hp = p.max_hp * 0.5
	check("月盈星亏: +60 attack speed at half life (精英 2)", is_equal_approx(p.kit.aspd_bonus(), 60.0))
	p.hp = p.max_hp
	check("no bonus at full life", is_equal_approx(p.kit.aspd_bonus(), 0.0))
	game.base.progress_for("hellagur").elite = 0

	# 月相: 新月 arms a heavy two-hit cleave on the next cut.
	clear_enemies()
	await step(1)
	e = dummy(origin + Vector3(0, 0, -2))
	atk = p.attack_power()
	check("Space opens 新月", cast(e.global_position) and p.kit.newmoon_armed and p.kit.status_text() == "新月")
	check("cooldown starts", is_equal_approx(p.skill_cooldown_left(), 6.0) and not cast(e.global_position))
	swing(e)
	check("新月's first cut lands 1.75", is_equal_approx(lost(e), atk * HellagurKit.NEWMOON_SCALE))
	tick(0.12)
	check("the second follows: 3.5 in all, and the phase is spent", is_equal_approx(lost(e), atk * HellagurKit.NEWMOON_SCALE * 2) and not p.kit.newmoon_armed)

	# 弦月: double cuts with ATK +40% and evasion, for 6 s.
	tick(6.0)
	clear_enemies()
	await step(1)
	e = dummy(origin + Vector3(0, 0, -2))
	var plain := p.attack_power()
	check("Space opens 弦月", cast(e.global_position) and p.kit.half_timer > 0.0 and p.evasion() >= HellagurKit.HALF_EVASION - 0.001)
	check("弦月 lifts ATK by 40%", is_equal_approx(p.attack_power(), plain * 1.4 / 1.0))
	atk = p.attack_power()
	swing(e)
	tick(0.1)
	check("弦月 cuts twice for 0.8 each", is_equal_approx(lost(e), atk * HellagurKit.HALF_SCALE * 2))
	tick(6.0)
	check("弦月 runs out", p.kit.half_timer == 0.0 and is_equal_approx(p.attack_power(), plain))

	# 满月: wide sweeps over up to 3 enemies.
	clear_enemies()
	await step(1)
	var pack: Array[Enemy] = [dummy(origin + Vector3(0, 0, -2)), dummy(origin + Vector3(1.2, 0, -2.2)), dummy(origin + Vector3(-1.2, 0, -2.2)), dummy(origin + Vector3(0.4, 0, -3.2))]
	var behind := dummy(origin + Vector3(0, 0, 3))
	check("Space opens 满月", cast(pack[0].global_position) and p.kit.full_timer > 0.0)
	p.combo_step = 0
	swing(pack[0])
	var struck := pack.filter(func(x): return lost(x) > 0).size()
	check("满月 sweeps exactly three enemies ahead", struck == 3 and lost(behind) == 0)
	check("the cycle returns to 新月", p.kit.phase_next == 0)

	# 坚忍 (rank 1): one lethal blow a segment leaves him on 1 life.
	game.base.progress_for("hellagur").ranks["tenacity"] = 1
	p.hp = 10
	p.invuln_timer = 0
	p.take_damage(99999, "true")
	check("坚忍 keeps him on 1 life, untouchable a moment", p.hp == 1.0 and p.invuln_timer > 0.0)
	p.invuln_timer = 0
	p.hp = 10
	p.take_damage(99999, "true")
	check("only once a segment", p.hp <= 0.0)
	p.hp = p.max_hp
	game.base.progress_for("hellagur").ranks.erase("tenacity")

	# A dodge stops the pending 新月 second cut.
	tick(10.0)
	clear_enemies()
	await step(1)
	e = dummy(origin + Vector3(0, 0, -2))
	p.kit.phase_next = 0
	cast(e.global_position)
	swing(e)
	var after_first := lost(e)
	p.stamina = 100
	p._dash_cooldown = 0
	p._start_dash(Vector3.RIGHT)
	tick(0.2)
	check("a dodge drops the second 新月 cut", is_equal_approx(lost(e), after_first))

	# The HUD and the hotbar read his skill.
	check("hotbar skill slot shows his cooldown", game._hud._hotbar_slots()[2].get("cooldown_total", 0.0) > 0.0)
	print("TEST_HELLAGUR: %d failures" % failures)
	quit(1 if failures > 0 else 0)
