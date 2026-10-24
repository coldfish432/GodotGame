extends SceneTree
## Amiya (Guard): operator switch, arts combo with 奔夜's double cut, and
## 影霄·绝影 as an active skill like 剑圣's Q (targeted, four bouncing strikes,
## untouchable, cooldown cut by basic hits). 阿米娅实现记录.md.
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
	enemy.defense = 500
	enemy.res = 0
	enemy.set_physics_process(false)
	enemy.global_position = point # spawning may nudge it onto open floor
	return enemy
func clear_enemies() -> void:
	for node in get_nodes_in_group("enemies"):
		node.remove_from_group("enemies")
		node.queue_free()
## (foot line, body height) in texels from the texture centre; rows under 3
## opaque texels (blade lines) are ignored. Same measure as test_lappland.
func body_metrics(texture: Texture2D) -> Vector2:
	var image := texture.get_image()
	var top := -1
	var foot := -1
	for y in range(image.get_height()):
		var count := 0
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.5: count += 1
		if count >= 3:
			if top < 0: top = y
			foot = y
	return Vector2(foot + 1 - image.get_height() / 2.0, foot + 1 - top)
func swing(enemy: Enemy) -> void:
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.attack(enemy)
## Advance her pending cuts and the shadow strike by `seconds`.
func tick(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		p.hitstop_remaining = 0
		p._tick_amiya(1.0 / 60.0)
		t += 1.0 / 60.0
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	game.base.recruit(Operators.LAPPLAND)
	game.choose_operator(Operators.AMIYA_GUARD)
	var data := game.base.to_data()
	var copy := BaseState.new()
	copy.load_data(data, {})
	check("operator choice survives save roundtrip", copy.operator == Operators.AMIYA_GUARD)
	var bad := data.duplicate()
	bad["operator"] = "nobody"
	copy.load_data(bad, {})
	check("unknown operator falls back to Amiya", copy.operator == Operators.AMIYA_GUARD)
	check("player switched to Amiya with her sheets", game.player.is_amiya() and game.player._sprite.character == Operators.AMIYA_GUARD
		and game.player._sprite.sprite_frames.has_animation(&"shadow_south") and game.player._sprite.sprite_frames.get_frame_count(&"idle_south") == 2)
	# Standing attack frames keep the idle foot line and body size in every
	# direction, so switching sheets does not lift or resize her (A1 v2 rows too).
	var frames := game.player._sprite.sprite_frames
	var aligned := true
	for direction in LapplandAnimator3D.COMBAT_ROWS:
		var idle := body_metrics(frames.get_frame_texture("idle_" + direction, 0))
		for action in ["attack_1", "attack_2", "attack_3", "hurt"]:
			var pose := body_metrics(frames.get_frame_texture(action + "_" + direction, 0))
			if absf(pose.x - idle.x) > 1.5 or pose.y / idle.y < 0.88 or pose.y / idle.y > 1.12:
				aligned = false
				print("  misaligned %s_%s: feet %.1f vs %.1f, height %.1f vs %.1f" % [action, direction, pose.x, idle.x, pose.y, idle.y])
	check("combat frames keep walk foot line and body size", aligned)
	await game.start_contract("mine")
	game._clear_field()
	await step(2)
	game.set_process(false)
	p = game.player
	p.set_physics_process(false)
	p._sprite.set_process(false)
	p.teleport(origin)
	p.stats["crit"] = -1.0 # no random crits in the arithmetic below
	check("no charge for her: 绝影 is an active skill, ready at start", not p.has_sword_wave() and p.shadow_ready())

	# Basic attacks: arts, the 奔夜 double cut, the thrust; each landed cut
	# shortens 绝影's cooldown by a second (剑圣 Q).
	var e := dummy(origin + Vector3(0, 0, -2))
	var atk := p.attack_power()
	p.shadow_cooldown = Player.SHADOW_COOLDOWN
	swing(e)
	var cuts := Player.AMIYA_COMBO
	check("stage 1 is one arts hit (defence ignored)", is_equal_approx(100000 - e.health, atk * cuts[0][0]))
	check("a landed cut takes SHADOW_REFUND off the cooldown", is_equal_approx(p.shadow_cooldown, Player.SHADOW_COOLDOWN - Player.SHADOW_REFUND))
	swing(e)
	check("stage 2 first cut lands at once", is_equal_approx(100000 - e.health, atk * (cuts[0][0] + cuts[1][0])))
	tick(0.1)
	check("stage 2 second cut follows and refunds again", is_equal_approx(100000 - e.health, atk * (cuts[0][0] + cuts[1][0] + cuts[1][1])) and absf(p.shadow_cooldown - (Player.SHADOW_COOLDOWN - 3.0 * Player.SHADOW_REFUND - 0.1)) < 0.02)
	var before := p.global_position
	swing(e)
	check("stage 3 thrust hits and does not move her", is_equal_approx(100000 - e.health, atk * (cuts[0][0] + cuts[1][0] + cuts[1][1] + cuts[2][0])) and p.global_position.distance_to(before) < 0.01)
	check("combo loops back to stage 1", p.combo_step == 0)
	check("on cooldown it cannot be cast", not p.cast_shadow(e.global_position) and not p.shadow_active)
	tick(Player.SHADOW_COOLDOWN)
	check("the cooldown runs out on its own", p.shadow_ready())

	# Cast: aimed near a pack, hits four different enemies, bouncing to the
	# nearest fresh one each time; untouchable; back beside the first target.
	clear_enemies()
	await step(1)
	p.teleport(origin)
	check("nothing near the cursor: no cast, no cooldown", not p.cast_shadow(origin + Vector3(0, 0, -4)) and p.shadow_ready())
	var a := dummy(origin + Vector3(0, 0, -4))
	var b := dummy(origin + Vector3(1.5, 0, -5))
	var c := dummy(origin + Vector3(3.0, 0, -5.5))
	var d := dummy(origin + Vector3(4.5, 0, -6))
	var far := dummy(origin + Vector3(-12, 0, -4))
	var too_far := dummy(origin + Vector3(0, 0, -9))
	check("out of range: no cast", not p.cast_shadow(too_far.global_position) and p.shadow_ready())
	check("cast on the enemy near the cursor", p.cast_shadow(a.global_position + Vector3(0.6, 0, 0)) and p.shadow_primary == a and p.invulnerable)
	check("the cooldown starts at once", is_equal_approx(p.shadow_cooldown, Player.SHADOW_COOLDOWN))
	check("her body vanishes for the skill", not p._sprite.visible)
	var hp_before := p.hp
	p.take_damage(5000, "phys")
	check("untouchable during the strikes", p.hp == hp_before)
	var check_hidden := true
	tick(0.08)
	check("first strike lands on the cast target at once (real time)", is_equal_approx(100000 - a.health, atk) and Vector2(p.global_position.x - a.global_position.x, p.global_position.z - a.global_position.z).length() < 1.0)
	var flashes := 0
	for i in range(36):
		p.hitstop_remaining = 0
		p._tick_amiya(1.0 / 60.0)
		for node in game.get_children():
			if node is CombatVfx and node.kind == "strike_flash" and not node.has_meta("counted"):
				node.set_meta("counted", true)
				flashes += 1
		if i < 30: check_hidden = check_hidden and (p._sprite.visible == not p.shadow_active)
	var all_hit := true
	for x in [a, b, c, d]: all_hit = all_hit and is_equal_approx(100000 - x.health, atk)
	check("four strikes, one on each enemy, 1.0 ATK arts each", all_hit and p.shadow_strikes == 4)
	check("one blade flash on each struck enemy, body hidden throughout", flashes == Player.SHADOW_STRIKES and check_hidden)
	check("enemies beyond the bounce range are untouched", far.health == 100000 and too_far.health == 100000)
	check("she reappears beside the first target, vulnerable again", not p.shadow_active and not p.invulnerable and p._sprite.visible
		and Vector2(p.global_position.x - a.global_position.x, p.global_position.z - a.global_position.z).length() < 1.0)
	check("the cooldown does not tick during the strikes", p.shadow_cooldown > Player.SHADOW_COOLDOWN - 0.7)

	# A lone target takes the first strike in full and the rest at half.
	clear_enemies()
	await step(1)
	p.teleport(origin)
	p.shadow_cooldown = 0.0
	var lone := dummy(origin + Vector3(0, 0, -3))
	p.cast_shadow(lone.global_position)
	tick(0.8)
	check("alone: one full strike plus three repeats at a quarter", is_equal_approx(100000 - lone.health, atk * (1.0 + 3 * Player.SHADOW_REPEAT_SCALE)))

	# A strike that kills frees the body before the next one picks (real
	# frames pass between strikes in play); it bounces on without error.
	clear_enemies()
	await step(1)
	p.teleport(origin)
	p.shadow_cooldown = 0.0
	var gone := dummy(origin + Vector3(0, 0, -3), atk * 0.5)
	var after := dummy(origin + Vector3(1.5, 0, -3.5), 50000)
	p.cast_shadow(gone.global_position)
	tick(0.08)
	await step(2) # the kill is freed here
	tick(0.6)
	check("a freed kill bounces on to the next and the strikes finish", not is_instance_valid(gone) and after.health < 50000 and not p.shadow_active)

	# A dodge interrupts everything (用户 2026-10-10): 绝影 mid-strikes stops
	# where she is, its cooldown spent; the pending 奔夜 cut never lands.
	clear_enemies()
	await step(1)
	p.teleport(origin)
	p.shadow_cooldown = 0.0
	p.stamina = 100
	p._dash_cooldown = 0
	var q1 := dummy(origin + Vector3(0, 0, -3))
	var q2 := dummy(origin + Vector3(1.5, 0, -3.5))
	var q3 := dummy(origin + Vector3(3, 0, -4))
	p.cast_shadow(q1.global_position)
	tick(0.12)
	var struck_before := [q1, q2, q3].filter(func(x): return x.health < 100000).size()
	var at := p.global_position
	p._start_dash(Vector3.BACK)
	check("a dodge breaks off 绝影: body back, cooldown spent", not p.shadow_active and p._sprite.visible and p.shadow_cooldown > 0.0 and p.dash_remaining > 0)
	tick(0.6)
	check("no further strikes land after the dodge", [q1, q2, q3].filter(func(x): return x.health < 100000).size() == struck_before and struck_before < 3)
	check("she dodged from where she was, not from the first target", Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() > 1.0)
	p.reset_combat_state()
	clear_enemies()
	await step(1)
	p.teleport(origin)
	p._dash_cooldown = 0
	p.stamina = 100
	var e2 := dummy(origin + Vector3(0, 0, -2))
	p.combo_step = 1
	swing(e2)
	var after_first_cut := e2.health
	p._start_dash(Vector3.BACK)
	tick(0.2)
	check("a dodge cancels 奔夜's pending second cut and the attack lock", e2.health == after_first_cut and not p.has_target() and p.combo_step == 0)
	p.reset_combat_state()

	# Relic charge gains shorten her cooldown instead.
	p.shadow_cooldown = 5.0
	p.add_charge(2)
	check("charge gains refund her cooldown", is_equal_approx(p.shadow_cooldown, 5.0 - 2.0 * Player.SHADOW_REFUND))

	# Skill relics and gear reach 绝影 (用户 2026-10-15): 折戟-浴血's stage-3
	# charge and 月下's extra strike.
	p.reset_combat_state()
	clear_enemies()
	await step(1)
	p.teleport(origin)
	var e3 := dummy(origin + Vector3(0, 0, -2))
	var drops := []
	for bonus in [0.0, 1.0]:
		p.fx["finisher_charge"] = bonus
		p.shadow_cooldown = 6.0
		p.combo_step = 2
		swing(e3)
		tick(0.6)
		drops.append(6.0 - p.shadow_cooldown)
		p.reset_combat_state()
	p.fx.erase("finisher_charge")
	check("折戟-浴血: stage 3 refunds one more charge for Amiya", is_equal_approx(drops[1] - drops[0], Player.SHADOW_REFUND))
	var weapon: Item = p.equipped.get(Item.Category.WEAPON)
	var lent := weapon == null
	if lent:
		weapon = Item.create("测试弩", Item.Category.WEAPON, 1, 3)
		p.equipped[Item.Category.WEAPON] = weapon
	if weapon != null:
		var moon := ItemModifier.trigger_mod(ItemModifier.Trigger.MOON_WAVE)
		weapon.modifiers.append(moon)
		p.stats["crit"] = 5.0
		var moon_flashes := 0
		for i in range(30):
			var vfx_before := game.get_children().filter(func(n): return n is CombatVfx and n.kind == "strike_flash").size()
			p.combo_step = 0
			swing(e3)
			moon_flashes += game.get_children().filter(func(n): return n is CombatVfx and n.kind == "strike_flash").size() - vfx_before
			p.reset_combat_state()
		check("月下: crits add 绝影 strikes for Amiya", moon_flashes > 0)
		var moon_hp := e3.health
		p._amiya_moon_strike(e3)
		check("月下 strike deals damage", e3.health < moon_hp)
		weapon.modifiers.erase(moon)
		p.stats["crit"] = -1.0
		if lent: p.equipped.erase(Item.Category.WEAPON)
	else:
		check("Amiya holds a weapon for the 月下 check", false)

	# Switching back restores Lappland untouched.
	game.in_base = true
	game.choose_operator(Operators.LAPPLAND)
	check("back to Lappland: affix-gated wave, 3 charges", not p.is_amiya() and p.wave_hits_needed() == 3 and p._sprite.signature_action == "wave")
	print("TEST_AMIYA: %d failures" % failures)
	quit(1 if failures > 0 else 0)
