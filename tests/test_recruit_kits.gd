extends SceneTree
## The six other recruits of 干员寻访 R2 (星熊, 提丰, 早露, 林, 寒檀, 德克萨斯;
## 赫拉格 has test_hellagur): each deployable once recruited, her combat
## frames standing on the idle foot line, her tree / talent / module, her
## basic attack and her Space skill doing what 干员寻访策划案 §4 / §9.1 says.
var game: GameManager
var p: Player
var failures := 0
var origin := Vector3(0, 0.7, -22)
const RECRUITS := ["hoshiguma", "typhon", "rosa", "lin", "santalla", "texas"]
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
	enemy.elite = false
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
	for node in game.get_children():
		if node is OperatorShot: node.queue_free()
func swing(enemy: Enemy) -> void:
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.attack(enemy)
func cast(point: Vector3) -> bool:
	p.hitstop_remaining = 0
	return p.cast_skill(point)
func tick(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		p.hitstop_remaining = 0
		p.kit.tick(1.0 / 60.0)
		t += 1.0 / 60.0
func lost(enemy: Enemy) -> float:
	return 100000 - enemy.health if is_instance_valid(enemy) else 100000.0
func near(a: float, b: float) -> bool:
	return absf(a - b) <= maxf(0.5, absf(b) * 0.002)
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
## Fresh field round her: no enemies, at the origin, skill ready.
func fresh() -> void:
	clear_enemies()
	await step(2)
	p.teleport(origin)
	p.reset_combat_state()
	p.kit.reset()
	p._attack_cooldown = 0
	p.hp = p.max_hp
func deploy(id: String) -> void:
	game.show_base()
	await step(2)
	game.choose_operator(id)
	await game.start_contract("mine")
	game._clear_field()
	await step(2)
	game.set_process(false)
	p = game.player
	p.set_physics_process(false)
	p._sprite.set_process(false)
	p.teleport(origin)
	p.stats["crit"] = -1.0
	p.stats["evasion"] = 0.0
	p.stats["evasion_arts"] = 0.0

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	for id in RECRUITS: game.base.roster.append(id)
	check("all six recruited are deployable", RECRUITS.all(func(id): return id in game.base.deployable()))
	for id in RECRUITS:
		game.choose_operator(id)
		var sprite := game.player._sprite
		var ok: bool = game.player.kit != null and game.player.kit.id == id and sprite.character == id and game.player.has_skill() and not game.player.has_sword_wave()
		var aligned := true
		for direction in LapplandAnimator3D.COMBAT_ROWS:
			var idle := body_metrics(sprite.sprite_frames.get_frame_texture("idle_" + direction, 0))
			for action in ["attack_1", "hurt"]:
				var pose := body_metrics(sprite.sprite_frames.get_frame_texture(action + "_" + direction, 0))
				# Windups raise staffs and blades over the head, so only the hurt
				# pose is held to the standing height; every pose keeps the feet.
				if absf(pose.x - idle.x) > 1.5 or (action == "hurt" and (pose.y / idle.y < 0.85 or pose.y / idle.y > 1.15)):
					aligned = false
					print("  %s misaligned %s_%s: feet %.1f vs %.1f, height %.1f vs %.1f" % [id, action, direction, pose.x, idle.x, pose.y, idle.y])
		check(id + ": kit, sheets and skill", ok)
		check(id + ": combat frames stand on the idle foot line", aligned)
		var tree := SkillTrees.tree(id)
		var described := tree.keys().all(func(n): return not SkillTrees.describe(id, n, 1).contains("%s") and not SkillTrees.describe(id, n, 10).contains("%d"))
		check(id + ": 9 nodes, 3 transmuters, talent and module", tree.size() == 9 and tree.values().filter(func(n): return n.type == "transmuter").size() == 3
			and described and SkillTrees.TALENTS.has(id) and SkillTrees.MODULES.has(id) and not SkillTrees.talent_text(id, 2, 3).contains("%s"))
		var vfx_ok := true
		for file in DirAccess.get_files_at("res://godot_assets/"):
			if file.begins_with(id + "_vfx_") and file.ends_with(".png") and load("res://godot_assets/" + file) == null: vfx_ok = false
		check(id + ": painted effects load", vfx_ok)

	# --- 星熊 ------------------------------------------------------------------
	await deploy("hoshiguma")
	await fresh()
	var e := dummy(origin + Vector3(0, 0, -2))
	var atk := p.attack_power()
	swing(e)
	swing(e)
	check("星熊: two bashes of 1.0", near(lost(e), atk * 2.0))
	var before := e.global_position
	swing(e)
	check("星熊: the ram hits 1.4 and knocks back", near(lost(e), atk * 3.4) and e.global_position.distance_to(before) > 0.5)
	p.kit.block_roll = 0.0
	var hp0 := p.hp
	p.take_damage(800, "phys")
	check("星熊: 战术装甲 blocks the blow and lifts ATK", p.hp == hp0 and p.kit.block_timer > 0.0 and p.attack_power() > atk)
	p.kit.block_roll = 1.0
	await fresh()
	var front := dummy(origin + Vector3(0, 0, -2))
	var back := dummy(origin + Vector3(0, 0, 2))
	check("星熊: 力之锯 plants toward the cursor, rooted", cast(front.global_position) and p.kit.rooted() and p.kit.busy())
	tick(1.0)
	check("星熊: the saw cuts the front only", lost(front) > 0.0 and lost(back) == 0.0)
	var dealt_open := 0.0
	hp0 = p.hp
	p.take_damage(800, "phys", front)
	var front_taken := hp0 - p.hp
	hp0 = p.hp
	p.take_damage(800, "phys", back)
	var back_taken := hp0 - p.hp
	check("星熊: blows from the front are mostly stopped", front_taken < back_taken * 0.6 and back_taken > 0.0)
	p.stamina = 100
	p._dash_cooldown = 0
	p._start_dash(Vector3.RIGHT)
	check("星熊: a dodge ends the saw", not p.kit.rooted())

	# --- 提丰 ------------------------------------------------------------------
	await deploy("typhon")
	await fresh()
	check("提丰: reach is a ranged one", p.weapon_range() >= 10.0)
	p._attack_cooldown = 0
	p.attack_direction(Vector3.FORWARD)
	check("提丰: no target, no arrow", game.get_children().filter(func(n): return n is OperatorShot).is_empty())
	e = dummy(origin + Vector3(0, 0, -7))
	atk = p.attack_power()
	swing(e)
	await step(30)
	check("提丰: the first arrow hits 1.6 × 1.4 (重如沼泥) and mires", near(lost(e), atk * 1.6 * 1.4) and e.status_value("slow") >= 0.8)
	var after_first := lost(e)
	swing(e)
	await step(30)
	check("提丰: the next arrow on it is plain 1.6, 锐如兽牙 stacking", near(lost(e) - after_first, atk * 1.6) and p.kit.fang_stacks == 2)
	await fresh()
	var mark := dummy(origin + Vector3(0, 0, -6))
	check("提丰: 永恒狩猎 marks the enemy at the cursor", cast(mark.global_position + Vector3(0.5, 0, 0)) and p.kit.hunt_target == mark and p.kit.hunt_left == 5)
	atk = p.attack_power()
	swing(mark)
	tick(0.6)
	check("提丰: an attack becomes arrow rain on the mark, stunning it", near(lost(mark), atk * 0.6 * 3) and mark.stun_timer > 0.0 and p.kit.hunt_left == 4)

	# --- 早露 ------------------------------------------------------------------
	await deploy("rosa")
	await fresh()
	e = dummy(origin + Vector3(0, 0, -6))
	atk = p.attack_power()
	swing(e)
	await step(30)
	check("早露: a bolt hits 1.4", near(lost(e), atk * 1.4))
	await fresh()
	var heavy := dummy(origin + Vector3(0, 0, -6))
	heavy.elite = true
	swing(heavy)
	await step(30)
	check("早露: 深入骨髓 hits the heavy ones harder", near(lost(heavy), atk * 1.4 * 1.2))
	await fresh()
	var first := dummy(origin + Vector3(0, 0, -4))
	var second := dummy(origin + Vector3(0, 0, -7))
	p.combo_step = 2
	swing(first)
	await step(30)
	check("早露: the charged third bolt goes through both", near(lost(first), atk * 2.2) and near(lost(second), atk * 2.2))
	await fresh()
	var fan: Array[Enemy] = []
	for angle in [-20.0, 20.0]:
		fan.append(dummy(origin + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angle)) * 5.0))
	check("早露: 雪崩击 fires a fan of harpoons", cast(origin + Vector3(0, 0, -5)))
	await step(30)
	check("早露: both flanks pinned in place", fan.all(func(x): return lost(x) > 0.0 and x.status_value("slow") >= 1.0) and p.kit.pins.size() == 2)
	var pinned := lost(fan[0])
	tick(1.05)
	check("早露: the pinned take damage each second", lost(fan[0]) > pinned)

	# --- 林 ---------------------------------------------------------------------
	await deploy("lin")
	await fresh()
	e = dummy(origin + Vector3(0, 0, -4))
	var beside := dummy(origin + Vector3(1.0, 0, -4))
	var apart := dummy(origin + Vector3(4.0, 0, -4))
	atk = p.attack_power()
	swing(e)
	check("林: the array bursts on the target and those beside it", near(lost(e), atk * 0.8) and near(lost(beside), atk * 0.8) and lost(apart) == 0.0)
	check("林: 琉璃璧 is up", p.kit.glass_up)
	hp0 = p.hp
	p.take_damage(100, "arts")
	check("林: a small blow is taken by the glass", p.hp == hp0 and p.kit.glass_up)
	await fresh()
	var close := dummy(origin + Vector3(0, 0, -2))
	hp0 = p.hp
	p.take_damage(1200, "arts")
	check("林: a heavy blow shatters it, blasting and stunning those near", not p.kit.glass_up and p.hp < hp0 and lost(close) > 0.0 and close.stun_timer > 0.0)
	tick(8.1)
	check("林: it grows back", p.kit.glass_up)
	await fresh()
	var plain := p.attack_power()
	var ok_cast := cast(origin)
	check("林: 流光乍裂 lifts her attack", ok_cast and p.attack_power() > plain * 1.4)
	p.kit._shatter()
	var weak := dummy(origin + Vector3(0, 0, -3), 10)
	swing(weak)
	await step(2)
	check("林: a kill during 流光乍裂 reforms the glass at once", p.kit.glass_up)

	# --- 寒檀 ------------------------------------------------------------------
	await deploy("santalla")
	await fresh()
	e = dummy(origin + Vector3(0, 0, -5))
	var by := dummy(origin + Vector3(1.0, 0, -5))
	atk = p.attack_power()
	swing(e)
	await step(30)
	check("寒檀: an ice orb hits 0.9 and chills", near(lost(e), atk * 0.9) and e.status_value("slow") > 0.0 and lost(by) == 0.0)
	p.combo_step = 2
	var before_big := lost(e)
	swing(e)
	await step(40)
	check("寒檀: the third orb splashes the one beside", near(lost(e) - before_big, atk * 1.2) and near(lost(by), atk * 1.2 * 0.5))
	await fresh()
	p.kit.follow_pointer = false
	var cluster: Array[Enemy] = [dummy(origin + Vector3(0, 0, -6)), dummy(origin + Vector3(0.6, 0, -6.4))]
	check("寒檀: 女巫之泪 starts", cast(origin + Vector3(0.3, 0, -6.2)) and p.kit.tears_timer > 0.0)
	tick(4.0)
	check("寒檀: icicles fall round the aim", cluster.any(func(x): return lost(x) > 0.0))
	p.control_immune = 0
	p.apply_control("stun", Vector3.ZERO, 0.0, 1.0)
	check("寒檀: stuns on her last half as long", near(p.control_timer, 0.5))
	p.control_timer = 0

	# --- 德克萨斯 --------------------------------------------------------------
	await deploy("texas")
	await fresh()
	e = dummy(origin + Vector3(0, 0, -2))
	atk = p.attack_power()
	before = p.global_position
	swing(e)
	swing(e)
	swing(e)
	check("德克萨斯: three quick cuts 0.8 / 0.8 / 1.1, standing her ground", near(lost(e), atk * 2.7) and p.global_position.distance_to(before) < 0.01)
	await fresh()
	var inside := dummy(origin + Vector3(0, 0, -2))
	var outside := dummy(origin + Vector3(0, 0, -6))
	atk = p.attack_power()
	check("德克萨斯: 剑雨 falls round her", cast(origin) and p.kit.rooted())
	tick(0.6)
	check("德克萨斯: two waves of arts on those inside, the first stunning", near(lost(inside), atk * 1.4 * 1.1 * 2) and inside.stun_timer > 0.0 and lost(outside) == 0.0)
	check("德克萨斯: then she runs faster", p.kit.move_mult() > 1.0 and not p.kit.rooted())

	print("TEST_RECRUIT_KITS: %d failures" % failures)
	quit(1 if failures > 0 else 0)
