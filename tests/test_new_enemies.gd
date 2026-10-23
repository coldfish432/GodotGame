extends SceneTree

## 装备扩充策划案 §2.1 and §7: the sixteen new enemies and their mechanics,
## the player's loss of control (stun / knockback / pull with tenacity and
## diminishing stuns), uninterruptible attacks, and the region pools.

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

func markers() -> Array:
	return game.get_children().filter(func(n): return n is CombatMarker and not n.is_queued_for_deletion())

func spawn(type: String, offset: Vector3, still: bool = true) -> Enemy:
	var enemy := game._spawn_enemy(origin + offset, EnemyAttacks.is_elite_type(type), false, type)
	if still: enemy.set_physics_process(false)
	return enemy

func reset() -> void:
	game._clear_field()
	await step(2)
	p.reset_stats()
	p.teleport(origin)
	p.combat_timer = 0

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(4)
	_data()
	await game.start_contract("city")
	p = game.player
	game.set_process(false)
	p.set_physics_process(false)
	p._sprite.set_process(false)
	await reset()
	await _control()
	await _mechanics()
	await _uninterruptible()
	await _warnings()
	print("NEW ENEMIES RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

const NEW := ["armed", "caster", "shield", "slug_volatile", "picket", "greytail", "greytail_lord", "thrower", "bully", "avenger", "breacher",
	"taint_husk", "distorted_caster", "shattered_champion", "shell_vine", "rock_hornbeast", "fallen_snowpriest"]

func _data() -> void:
	var complete := true
	for type in NEW:
		if not EnemyAttacks.PROFILES.has(type) or not EnemyAttacks.STATS.has(type): complete = false
	check("sixteen new enemies (and 灰尾香主) have a profile and stats", complete)
	var elites := NEW.filter(func(t): return EnemyAttacks.is_elite_type(t))
	check("elites: 武装人员, 灰尾香主, 欺凌者, 寻仇者, 粉碎攻坚手, 木裂战士", elites.size() == 6, elites)
	check("mine elites are 武装人员 now, not thugs", EnemyAttacks.default_type("mine", true, false) == "armed")
	var borrowed := true
	for type in NEW:
		if EnemyAttacks.is_elite_type(type): continue
		if not EnemyAttacks.PROFILES.has(EnemyAttacks.art_type(type)) or EnemyAttacks.art_type(type) == type: borrowed = false
	check("ordinary new enemies borrow an existing sheet", borrowed)
	var pools := true
	for region in EnemyAttacks.REGION_POOLS:
		for slot in EnemyAttacks.REGION_POOLS[region]:
			for type in EnemyAttacks.REGION_POOLS[region][slot]:
				if not EnemyAttacks.PROFILES.has(type): pools = false
	check("region pools only name real enemies", pools)
	# 用户 2026-10-11: the slug chops down with raised claws, the hornbeast butts with lowered horns.
	var slug: Dictionary = EnemyAttacks.PROFILES.slug_volatile
	var beast: Dictionary = EnemyAttacks.PROFILES.rock_hornbeast
	check("高能源石虫 chops in front (sector), no lunge", slug.shape == "sector" and not slug.has("dash"))
	check("岩角兽 butts at close range with knockback, no long charge", beast.shape == "lane" and float(beast.reach) <= 2.5 and beast.has("knockback"))

func _control() -> void:
	check("a stun takes and stops her", p.apply_control("stun", Vector3.RIGHT, 0.0, 0.8) and p.is_controlled() and is_equal_approx(p.control_timer, 0.8))
	p._attack_cooldown = 0
	var foe := spawn("thug", Vector3(1.5, 0, 0))
	var before := foe.health
	p.attack(foe)
	check("no attacking while stunned", foe.health == before)
	p.stamina = 100
	p._dash_cooldown = 0
	check("no dodging while stunned", not p.can_dash())
	check("no flask while stunned", not game.drink(BaseCatalog.create_potion("A")))
	for i in range(60): p._tick_control(1.0 / 60.0)
	check("it ends, then tenacity protects her for 2 s", not p.is_controlled() and p.control_immune > 1.5 and not p.apply_control("stun", Vector3.RIGHT, 0.0, 0.8))
	p.control_immune = 0
	check("a second stun inside 10 s is halved", p.apply_control("stun", Vector3.RIGHT, 0.0, 0.8) and is_equal_approx(p.control_timer, 0.4))
	for i in range(30): p._tick_control(1.0 / 60.0)
	p.control_immune = 0
	check("a third is ignored", not p.apply_control("stun", Vector3.RIGHT, 0.0, 0.8))
	p._clock += 11.0
	check("stuns cap at 1 s", p.apply_control("stun", Vector3.RIGHT, 0.0, 3.0) and is_equal_approx(p.control_timer, 1.0))
	for i in range(70): p._tick_control(1.0 / 60.0)
	p.control_immune = 0
	var start := p.global_position
	p.apply_control("knockback", Vector3.RIGHT, 2.0, 0.3)
	for i in range(30): p._tick_control(1.0 / 60.0)
	check("a knockback moves her about 2 units", absf(p.global_position.x - start.x - 2.0) < 0.6, p.global_position - start)
	p.control_immune = 0
	p.invulnerable = true
	check("dodge invulnerability ignores control", not p.apply_control("stun", Vector3.RIGHT, 0.0, 0.5))
	p.invulnerable = false
	await reset()

func _mechanics() -> void:
	var shield := spawn("shield", Vector3(1.5, 0, 0))
	shield.attack_direction = Vector3.LEFT
	var front := shield.health
	shield.take_hit(1000.0, "true")
	var front_loss := front - shield.health
	shield.attack_direction = Vector3.RIGHT
	var back := shield.health
	shield.take_hit(1000.0, "true")
	check("机动盾兵: 60% less from the front", absf(front_loss - 400.0) < 1.0 and absf((back - shield.health) - 1000.0) < 1.0, [front_loss, back - shield.health])
	var grey := spawn("greytail", Vector3(-1.5, 0, 0))
	check("灰尾: +50 法抗 while the barrier holds", is_equal_approx(grey.effective_res(), grey.res + 50.0) and grey.barrier_up())
	grey.silence(1.0)
	check("精神摧毁 switches the barrier off", not grey.barrier_up())
	grey.silence_timer = 0
	var speed := grey.move_speed
	grey.take_hit(grey.barrier_hp + 10.0, "true")
	check("damage wears it down, then it speeds up", not grey.barrier_up() and is_equal_approx(grey.move_speed, speed * 1.4))
	var shelled := spawn("greytail", Vector3(-3.0, 0, 0))
	shelled._sync_shell()
	check("the shared barrier shell (Sol's strip) stands on its feet while the barrier holds", shelled._shell != null and shelled._shell.visible
		and (shelled._shell.texture as AtlasTexture).atlas == BarrierFx.SHELL and shelled._shell.position.is_equal_approx(shelled._sprite.position))
	shelled.barrier_hp *= 0.4
	shelled._sync_shell()
	check("…cracked once half of it is gone", shelled._shell.cracked and (shelled._shell.texture as AtlasTexture).atlas == BarrierFx.CRACKED)
	shelled.silence(1.0)
	shelled._sync_shell()
	check("…and hides when it is silenced", not shelled._shell.visible)
	shelled.silence_timer = 0
	shelled._sync_shell()
	shelled.take_hit(shelled.barrier_hp + 10.0, "true")
	check("breaking it plays the shatter, no flash", shelled._shell.breaking() and (shelled._shell.texture as AtlasTexture).atlas == BarrierFx.BREAK
		and is_equal_approx(shelled._shell.modulate.a, BarrierFx.OPACITY))
	var lord := spawn("greytail_lord", Vector3(-4.5, 0, 0))
	lord._sync_shell()
	check("灰尾香主: the same shell, purple, 1.2× for an elite", is_equal_approx(lord._shell.size, 1.2) and lord._shell.colour.is_equal_approx(Color("c8b0f0")))
	p.shield = 200.0
	p._physics_process(0.016)
	check("her own shields use the same shell", p._shell.visible and p._shell.texture != null and not p._shell.cracked)
	p.shield = 80.0
	p._physics_process(0.016)
	check("…cracked below half of its peak", p._shell.cracked)
	p.shield = 0.0
	# 用户 2026-10-11: 差不多就接入 — the 17 new enemies on their own boards.
	var own := 0
	for type in EnemyN2Data.TIPS:
		# The B1 bosses and wardens are on these boards too, but only as Boss (test_bosses).
		if BossCatalog.FIGURES.has(type) or type == "civilian": continue
		var e := spawn(type, Vector3(0, 0, 6.0), false)
		if e.directional and e.has_walk and e.sheet_type == type and e._tint == Color.WHITE: own += 1
		e.queue_free()
	# …and the seven of 叙拉古 (N4, 叙拉古敌人设计案 2026-10-16).
	check("all 17 new enemies, 萨卡兹哨兵 (N3) and 叙拉古's seven (N4) draw from their own eight-direction boards, untinted", own == 25 and EnemyN2Data.TIPS.size() == 25 + BossCatalog.FIGURES.size() + 1 and EnemyN2Data.TIPS.has("sentinel") and EnemyN2Data.TIPS.has("family_car"), own)
	# 用户 2026-10-14: 走路一跳一跳的 — every walk frame of a direction stands on
	# one foot line (art/install_n2_boards.py settle_walk).
	var hopping: Array[String] = []
	for type in EnemyN2Data.TIPS.keys() + EnemyDirectionalData.WALK:
		var sheet: Image = (load("res://art/field/enemy_walk_%s_64.png" % type) as Texture2D).get_image()
		if sheet.is_compressed(): sheet.decompress()
		for col in range(8):
			var feet := []
			for row in range(4):
				feet.append(sheet.get_region(Rect2i(col * 64, row * 64, 64, 64)).get_used_rect().end.y)
			if feet.max() != feet.min():
				hopping.append(type)
				break
	check("every enemy's walk keeps its feet on one line", hopping.is_empty(), hopping)
	var slug := spawn("slug_volatile", Vector3(0.5, 0, 0.5))
	var mate := spawn("thug", Vector3(1.0, 0, -0.5))
	var hp := p.hp
	# The auto slot (污染与回血修订) would drink 急救剂 below 40% and top her back up.
	var auto: Variant = SystemScreens.settings.get("auto_potion", "")
	SystemScreens.settings["auto_potion"] = ""
	slug.take_hit(99999.0, "true")
	await step(2)
	var hazard: GroundHazard = null
	for child in game.get_children():
		if child is GroundHazard: hazard = child
	check("高能源石虫 leaves a fused blast", hazard != null and hazard.fuse > 0.0 and hazard.hurts_enemies)
	var mate_hp := mate.health
	for i in range(80): await step(1)
	check("…which hurts her and other enemies (敌我都伤)", p.hp < hp and mate.health < mate_hp, [hp, p.hp, mate_hp, mate.health])
	SystemScreens.settings["auto_potion"] = auto
	await reset()
	# Wherever the floor's cover (CityDressing) leaves the rope a clear line.
	var throw := Vector3(7.0, 0, 0)
	for side in [Vector3(7.0, 0, 0), Vector3(-7.0, 0, 0), Vector3(0, 0, 7.0), Vector3(0, 0, -7.0)]:
		if game.line_of_sight(origin + side, origin):
			throw = side
			break
	var picket := spawn("picket", throw, false)
	picket.begin_chase()
	picket._lasso_cd = 0
	picket._attack_timer = 0
	var distance := picket._flat_distance(picket.global_position, p.global_position)
	check("感染者纠察官 starts a lasso at range", picket._try_special(distance, true) and picket._special == "lasso")
	picket._resolve_lasso()
	check("…and the lasso pulls her in", p.is_controlled() and p.control_kind == "pull")
	await reset()
	var thrower := spawn("thrower", Vector3(5.0, 0, 0), false)
	thrower.begin_chase()
	thrower._begin_telegraphed_attack()
	thrower._windup_remaining = 0
	thrower._attack_elapsed = 99
	check("燃烧瓶投掷者: no red ground while it lights the rag", thrower._warning_markers.is_empty())
	thrower._resolve_attack()
	await step(1)
	var bottle: Molotov = null
	for child in game.get_children():
		if child is Molotov: bottle = child
	var landing := markers()
	check("…the throw puts a red circle where she stands and a bottle in the air", bottle != null and landing.size() == 1 and absf(landing[0].total - Molotov.FLIGHT) < 0.001)
	await step(2)
	check("…the bottle flies an arc above the ground", bottle != null and bottle._bottle.position.y > 0.5, bottle._bottle.position if bottle != null else null)
	for i in range(45): await step(1)
	var fire: GroundHazard = null
	for child in game.get_children():
		if child is GroundHazard: fire = child
	check("燃烧瓶投掷者 leaves fire where it lands", fire != null and fire.lasting > 2.5 and not is_instance_valid(bottle) and markers().is_empty())
	check("…fire ticks at 0.2 of an unweighted hit", fire != null and absf(fire.damage - thrower.atk * 0.2 * (1.0 + game.pressure / EnemyAttacks.PRESSURE_DIVISOR) * game.enemy_attack_multiplier()) < 0.5)
	await reset()
	var priest := spawn("fallen_snowpriest", Vector3(6.0, 0, 0), false)
	var ally := spawn("thug", Vector3(7.0, 0, 1.0))
	priest.begin_chase()
	priest._begin_telegraphed_attack()
	priest._attack_elapsed = 99
	priest._resolve_attack()
	check("陷落雪祀's orb hastens a nearby enemy", ally.status_value("haste") > 0.0)
	await reset()
	var beasts: Array[Enemy] = []
	for i in range(3):
		var beast := spawn("rock_hornbeast", Vector3(4 + i, 0, 3), false)
		beast.herd = 99
		beasts.append(beast)
	for i in range(10): await step(1)
	check("岩角兽 ignore her until one is hit", beasts.all(func(b): return b.state == Enemy.State.IDLE))
	beasts[0].take_hit(10.0, "true")
	check("…then the whole herd comes", beasts.all(func(b): return b.provoked and b.state == Enemy.State.CHASING))
	await reset()
	var avenger := spawn("avenger", Vector3(2, 0, 0))
	var atk := avenger.atk
	avenger.take_hit(avenger.max_health * 0.55, "true")
	check("寻仇者 below half: attack ×1.6", is_equal_approx(avenger.atk, atk * 1.6))
	var champ := spawn("shattered_champion", Vector3(-2, 0, 0))
	champ.take_hit(champ.max_health * 0.75, "true")
	var hp_now := champ.health
	champ._tick_specials(1.0)
	check("木裂战士 below 30% burns itself down (自我泯灭)", champ._annihilating and champ.health < hp_now)
	await reset()
	var box := LootContainer.new()
	box.game = game
	box.kind = "weapon_box"
	box.mimic = true
	game.add_child(box)
	box.global_position = origin + Vector3(2, 0, 0)
	box.open_now()
	await step(2)
	var vine: Enemy = null
	for node in root.get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and node.enemy_type == "shell_vine": vine = node
	check("巨壳藤蔓: the box wakes up as an enemy", vine != null and vine.mimic_kind == "weapon_box")
	await reset()

func _uninterruptible() -> void:
	var bully := spawn("bully", Vector3(4, 0, 0), false)
	bully.begin_chase()
	bully._begin_telegraphed_attack()
	check("欺凌者's charge cannot be interrupted", bully.unstoppable_now())
	bully.interrupt(5.0, true)
	bully.stun(2.0)
	check("…neither by interrupt nor by stun", bully.attack_phase == "windup" and bully.stun_timer == 0.0)
	var breacher := spawn("breacher", Vector3(-4, 0, 0), false)
	breacher.begin_chase()
	breacher._attack_count = 2
	breacher._begin_telegraphed_attack()
	check("粉碎攻坚手's third blow is unstoppable", breacher.unstoppable_now())
	breacher._cancel_attack()
	breacher._attack_count = 0
	breacher._begin_telegraphed_attack()
	check("its first is not", not breacher.unstoppable_now())
	breacher.interrupt(1.0, true)
	check("…so 精神摧毁 can break it", breacher.attack_phase == "idle")
	var thug := spawn("thug", Vector3(2, 0, 2), false)
	thug.begin_chase()
	thug._begin_telegraphed_attack()
	thug.stun(1.0)
	check("an ordinary attack breaks on a stun", thug.attack_phase == "idle" and thug.stun_timer > 0.0)
	await reset()

func _windup(type: String, offset: Vector3) -> Enemy:
	var e := spawn(type, offset)
	e.begin_chase()
	e._begin_telegraphed_attack()
	return e

## 新敌人攻击动画与预警设计案 §六 and the v1.2 warning look.
func _warnings() -> void:
	var quiet := true
	for type in ["shield", "picket", "slug_volatile", "greytail", "taint_husk", "shell_vine", "rock_hornbeast"]:
		var e := _windup(type, Vector3(1.5, 0, 0))
		if not markers().is_empty() or e.warn_shape != "": quiet = false
		e.queue_free()
		await step(1)
	check("ordinary physical attacks put nothing on the ground (§六第 1/12 条)", quiet)
	var picket := spawn("picket", Vector3(7.0, 0, 0))
	picket.begin_chase()
	picket._lasso_cd = 0
	picket._try_special(7.0, true)
	check("…the lasso included: no red line, the rope over its head is the read", picket._special == "lasso" and markers().is_empty())
	await reset()
	var armed := _windup("armed", Vector3(2, 0, 0))
	var circle: Array = markers()
	check("an elite marks the ground once", circle.size() == 1 and circle[0].material_override is ShaderMaterial and not circle[0].unstoppable)
	var full: float = circle[0].total
	for i in range(int(full * 30)): await step(1)
	var half: float = circle[0].progress()
	check("…and its rings spread from the middle as the countdown (about half way at half time)", half > 0.3 and half < 0.7, half)
	check("…the circle is see-through: a plane the size of the radius, not a solid disc", (circle[0].mesh as PlaneMesh).size.is_equal_approx(Vector2.ONE * armed.pending_warning_radius * 2.0))
	await reset()
	var bully := _windup("bully", Vector3(4, 0, 0))
	var lane: Array = markers()
	var lane_size := (lane[0].mesh as PlaneMesh).size if lane.size() == 1 else Vector2.ZERO
	var edge := CombatMarker.WHITE_RIM * 2.0
	check("欺凌者: a 1.4 × 7.0 strip with the white edge of an unstoppable attack (§六第 2/7 条)", lane.size() == 1 and lane[0].unstoppable and lane_size.is_equal_approx(Vector2(1.4 + edge, 7.0 + edge)), lane_size)
	bully._update_attack_visual()
	check("…and a light ring round its body while it winds up", bully._outline.visible)
	var aim := bully.attack_direction
	bully._tick_attack(0.3)
	check("…it holds still while the strip is down, so the charge goes where it points", bully.attack_direction.is_equal_approx(aim))
	await reset()
	var breacher := _windup("breacher", Vector3(2, 0, 0))
	var first: Array = markers()
	check("粉碎攻坚手's first blow: no white edge", first.size() == 1 and not first[0].unstoppable and not breacher._outline.visible)
	breacher._cancel_attack()
	breacher._attack_count = 2
	breacher._begin_telegraphed_attack()
	var third: Array = markers()
	check("…its third has the white edge", third.size() == 1 and third[0].unstoppable)
	await reset()
	var avenger := _windup("avenger", Vector3(2, 0, 0))
	var thrust: Array = markers()
	var thrust_size := (thrust[0].mesh as PlaneMesh).size if thrust.size() == 1 else Vector2.ZERO
	check("寻仇者 opens with a 0.9 × 3.0 strip (§六第 3 条)", avenger.warn_shape == "lane" and thrust_size.is_equal_approx(Vector2(0.9, 3.0)), thrust_size)
	avenger._attack_elapsed = 99
	avenger._windup_remaining = 0
	avenger._resolve_attack()
	var cut: Array = markers()
	check("…the back-cut's circle goes down round its own feet the moment the thrust lands", avenger.attack_phase == "windup" and avenger.warn_shape == "circle"
		and avenger.pending_warning_position.is_equal_approx(avenger.attack_origin) and is_equal_approx(avenger.pending_warning_radius, 1.6) and cut.size() == 1)
	check("…and strikes 0.45 s later from the RECOVER pose", is_equal_approx(avenger._windup_total, 0.45) and avenger.pose_frame == 4)
	await reset()
	var grey := spawn("greytail", Vector3(-2, 0, 0), false)
	grey.silence(2.0)
	await step(2)
	check("a silenced enemy shows the grey × over its head (§六第 8 条)", grey._silence_mark.visible)
	grey.silence_timer = 0.0
	await step(2)
	check("…gone when the silence ends", not grey._silence_mark.visible)
	await reset()
	check("damage weights from §三: 欺凌者 1.5, 高能源石虫 0.7 (§六第 4 条)", is_equal_approx(float(EnemyAttacks.PROFILES.bully.damage), 1.5) and is_equal_approx(float(EnemyAttacks.PROFILES.slug_volatile.damage), 0.7))
	var priest := spawn("fallen_snowpriest", Vector3(6.0, 0, 0), false)
	priest.begin_chase()
	priest._begin_telegraphed_attack()
	priest._attack_elapsed = 99
	priest._resolve_attack()
	var orb: EnemyProjectile = null
	for child in game.get_children():
		if child is EnemyProjectile: orb = child
	check("陷落雪祀 throws an ice orb at speed 12, not the hunter's bullet (§六第 6 条)", orb != null and orb.kind == "ice_orb" and is_equal_approx(orb.speed, 12.0))
	await reset()
	var big := spawn("shattered_champion", Vector3(3, 0, 0))
	var small := spawn("slug_volatile", Vector3(-3, 0, 0))
	check("bigger bodies get a bigger pick box and navigation radius (§六第 11 条)", big._nav_agent.radius > small._nav_agent.radius and big.figure_scale() > 1.0 and small.figure_scale() < 1.0)
	await reset()
	var fuse := spawn("slug_volatile", Vector3(1, 0, 0))
	fuse.take_hit(99999.0, "true")
	await step(2)
	var blast: GroundHazard = null
	for child in game.get_children():
		if child is GroundHazard: blast = child
	check("高能源石虫's fuse is the same see-through warning with a countdown", blast != null and blast.has_node("Warning") and blast.get_node("Warning") is CombatMarker and not blast._disc.visible)
	await reset()
