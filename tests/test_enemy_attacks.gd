extends SceneTree
## Attack rules exercised against real navigation, physics, sprites and damage.
var game: GameManager
var results: Array[Dictionary] = []
var failures := 0
var origin := Vector3.ZERO

func _initialize() -> void: call_deferred("run")
func step(n: int = 2) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, ok: bool) -> void:
	results.append({"check": label, "pass": ok})
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func clean() -> void:
	game._clear_field()
	await step()
	game.player.hp = 2400
	game.player.invulnerable = false
	game.player.teleport(origin + Vector3(2, 0, 0))
## What a physical hit of `raw` costs her after her defence (局内构筑与数值策划案 §4).
func taken(raw: float) -> float:
	return CombatStats.physical(raw, game.player.defense_value())
func enemy(type: String) -> Enemy:
	var e := game._spawn_enemy(origin, type == "elite", false, type)
	e.set_physics_process(false)
	e.begin_chase()
	return e
func shots() -> Array:
	return game.get_children().filter(func(n): return n is EnemyProjectile and not n.is_queued_for_deletion())
func markers() -> Array:
	return game.get_children().filter(func(n): return n is CombatMarker and not n.is_queued_for_deletion())
func wall_at(point: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.18, 4, 5)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.global_position = point
	return wall

func run() -> void:
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
	check("mine wave includes ordinary slugs and no elite", get_nodes_in_group("enemies").any(func(e): return e.enemy_type == "slug") and get_nodes_in_group("enemies").all(func(e): return not e.elite))
	# Windups are the warning now, so each is ~0.25 s longer than the old telegraph.
	var expected := [[0.8, 1.35, 440.0], [1.0, 1.8, 440.0], [0.8, 1.15, 344.0], [0.8, 1.0, 392.0], [1.1, 1.8, 368.0], [1.0, 1.5, 520.0], [1.5, 2.6, 560.0]]
	for i in range(7):
		await clean()
		var e := enemy(EnemyAttacks.ORDER[i])
		e._begin_telegraphed_attack()
		var p := e.attack_profile
		check(e.enemy_type + " authored timings and damage", is_equal_approx(p.windup, expected[i][0]) and is_equal_approx(p.interval, expected[i][1]) and is_equal_approx(e.atk * float(p.damage), expected[i][2]) and e.damage_kind == "phys")
		check(e.enemy_type + " starts with physical pose, no warning", e.pose_frame == 1 and markers().is_empty() and e._warning_markers.is_empty())
		e._tick_attack(0.15)
		check(e.enemy_type + " holds distinct charge pose", e.pose_frame == 2 and e.preparing_attack)
		e._tick_attack(float(p.windup) - 0.20)
		check(e.enemy_type + " has last 0.1s weapon flash and cue", e._glint.visible and e._cue_played and game.sound.streams.has("enemy_" + e.enemy_type))
		e._tick_attack(0.051)
		check(e.enemy_type + " releases without warning", e.attack_phase == "strike" and e.pose_frame == 3 and markers().is_empty())
		e._tick_attack(0.101)
		if e.attack_phase == "contact": e._tick_attack(Enemy.CONTACT_TIME + 0.001)
		check(e.enemy_type + " exposes recovery window", e.attack_phase == "recovery" and e.pose_frame == 4)
		e._tick_attack(float(p.recovery) + 0.001)
		check(e.enemy_type + " returns to original idle size", e.pose_frame == 0 and e._sprite.texture.get_size() == Vector2(64, 64) and is_equal_approx(e._sprite.pixel_size, 1.0 / 15))

	await clean()
	var thug := enemy("thug")
	thug._begin_telegraphed_attack()
	var locked := thug.attack_direction
	game.player.teleport(origin + Vector3(-1.0, 0, 0))
	thug._tick_attack(0.81)
	check("thug cannot turn or hit behind during windup", thug.attack_direction == locked and is_equal_approx(game.player.hp, 2400))
	check("100 degree sector includes front and excludes side/outside radius", EnemyAttacks.contains(thug.attack_profile, origin, Vector3.RIGHT, origin + Vector3(2, 0, 0)) and not EnemyAttacks.contains(thug.attack_profile, origin, Vector3.RIGHT, origin + Vector3(0, 0, 1)) and not EnemyAttacks.contains(thug.attack_profile, origin, Vector3.RIGHT, origin + Vector3(2.5, 0, 0)))
	check("miss leaves no dark red cuts", not game.get_children().any(func(n): return n is EnemyAttackVfx and n.kind == "cuts"))
	await clean()
	thug = enemy("thug")
	thug._begin_telegraphed_attack()
	thug._tick_attack(0.81)
	check("front sector hit applies physical damage after defence and post-hit cuts", is_equal_approx(game.player.hp, 2400 - taken(thug._pending_damage)) and game.get_children().any(func(n): return n is EnemyAttackVfx and n.kind == "cuts"))

	for type in ["slug", "brawler"]:
		await clean()
		var e := enemy(type)
		var target := origin + Vector3(float(e.attack_profile.reach) - 0.1, 0, 0)
		game.player.teleport(target)
		e._begin_telegraphed_attack()
		e._tick_attack(0.81)
		var before := e.global_position
		check(type + " does not hit the future dash endpoint early", is_equal_approx(game.player.hp, 2400))
		for frame in range(6): e._tick_attack(1.0 / 60)
		check(type + " lunge stops at the player instead of passing through", e.attack_phase == "contact" and e.global_position.x < target.x and target.x - e.global_position.x <= e.contact_distance() + 0.01 and e.pose_frame == 3)
		check(type + " contact plays a hit spark", game.get_children().any(func(n): return n is EnemyAttackVfx and n.kind == ("bite" if type == "slug" else "stab")))
		check(type + " swept strip hits only once", is_equal_approx(game.player.hp, 2400 - taken(e._pending_damage)))
		var at_contact := e.global_position
		for frame in range(30): e._tick_attack(1.0 / 60)
		check(type + " springs back out of the player after contact", is_equal_approx(at_contact.distance_to(e.global_position), float(e.attack_profile.recoil)) and e.global_position.x < at_contact.x)
		await clean()
		e = enemy(type)
		game.player.teleport(origin + Vector3(0, 0, 3))
		e._begin_telegraphed_attack()
		game.player.teleport(origin + Vector3(0, 0, -3))
		before = e.global_position
		e._tick_attack(0.81)
		for frame in range(8): e._tick_attack(1.0 / 60)
		check(type + " whiffed lunge still travels its full dash with no recoil", is_equal_approx(e._dash_travelled, float(e.attack_profile.dash)) and is_equal_approx(before.distance_to(e.global_position), float(e.attack_profile.dash)) and not e._contacted)
		check(type + " narrow strip excludes side and rear", not EnemyAttacks.contains(e.attack_profile, origin, Vector3.RIGHT, origin + Vector3(1, 0, float(e.attack_profile.width) * 0.5 + 0.01)) and not EnemyAttacks.contains(e.attack_profile, origin, Vector3.RIGHT, origin + Vector3(-0.1, 0, 0)))
		await clean()
		e = enemy(type)
		var wall := wall_at(origin + Vector3(0.5, 0, 0))
		await step()
		e._begin_telegraphed_attack()
		e._tick_attack(0.81)
		e._tick_attack(0.10)
		check(type + " lunge cannot cross a wall or damage through it", e.global_position.x < wall.global_position.x and is_equal_approx(game.player.hp, 2400))
		wall.queue_free()
		await step()

	await clean()
	var ice := enemy("ice_warrior")
	ice._begin_telegraphed_attack()
	game.player.teleport(origin + Vector3(0, 0, 3))
	ice._tick_attack(1.01)
	check("ice miss still produces 0.3s impact cracks", game.get_children().any(func(n): return n is EnemyAttackVfx and n.kind == "ice" and is_equal_approx(n.duration, 0.3)))
	check("ice terminal radius and lane use same locked direction", EnemyAttacks.contains(ice.attack_profile, origin, Vector3.RIGHT, origin + Vector3(3.6, 0, 0)) and not EnemyAttacks.contains(ice.attack_profile, origin, Vector3.RIGHT, origin + Vector3(3.9, 0, 0)))

	await clean()
	var hunter := enemy("ice_hunter")
	game.player.teleport(origin + Vector3(8, 0, 0))
	hunter._begin_telegraphed_attack()
	hunter._tick_attack(0.45)
	game.player.teleport(origin + Vector3(6, 0, 4))
	# Frame-sized steps: the 0.2 s lock flash is shorter than a coarse tick.
	while not hunter._aim_locked: hunter._tick_attack(1.0 / 60)
	locked = hunter.attack_direction
	check("hunter tracks for 0.9s then signals lock with a 3px glint", hunter._glint.visible and hunter._glint.scale.is_equal_approx(Vector3.ONE * 3) and locked.z > 0.4 and absf(hunter._windup_remaining - 0.6) < 0.02)
	for i in range(9): hunter._tick_attack(1.0 / 60)
	check("hunter lock glint holds for 0.2s", hunter._glint.visible)
	game.player.teleport(origin + Vector3(6, 0, -4))
	while hunter._windup_remaining > 0.02: hunter._tick_attack(1.0 / 60)
	check("hunter grants full locked dodge window", shots().is_empty() and hunter.attack_direction == locked)
	hunter._tick_attack(0.03)
	var bullet := shots()[0] as EnemyProjectile
	bullet.set_physics_process(false)
	check("hunter bullet leaves the painted muzzle toward the locked point at speed 22", bullet.direction.is_equal_approx(Vector3(hunter._locked_target.x - hunter._muzzle.x, 0, hunter._locked_target.z - hunter._muzzle.z).normalized()) and bullet.global_position.is_equal_approx(hunter._muzzle) and bullet.speed == 22 and bullet.max_range == 15)

	await clean()
	var leader := enemy("crossbow_leader")
	leader._begin_telegraphed_attack()
	leader._tick_attack(1.11)
	var fan := shots()
	check("leader releases three arrows simultaneously", fan.size() == 3)
	var angles := true
	for i in range(fan.size()):
		fan[i].set_physics_process(false)
		angles = angles and fan[i].direction.is_equal_approx(leader.attack_direction.rotated(Vector3.UP, deg_to_rad((i - 1) * 20))) and is_equal_approx(fan[i].damage, leader._pending_damage) and fan[i].speed == 12 and fan[i].hit_radius == 0.5
	check("fan angles, per-arrow damage and collision diameter match design", angles)
	await clean()
	game.player.teleport(origin + Vector3(4, 0, 0))
	bullet = game.launch_enemy_projectile(origin, origin + Vector3.RIGHT, 1.5, "bullet", 15)
	bullet.set_physics_process(false)
	bullet._physics_process(0.4)
	check("fast bullet swept collision cannot tunnel through player", is_equal_approx(game.player.hp, 2400 - taken(1.5)) and bullet.is_queued_for_deletion())
	await step()
	game.player.hp = 2400
	var wall := wall_at(origin + Vector3(2, 0, 0))
	await step()
	var arrow := game.launch_enemy_projectile(origin, origin + Vector3.RIGHT, 1.0)
	arrow.set_physics_process(false)
	arrow._physics_process(1)
	check("cover blocks arrows before player and makes wood fragments", is_equal_approx(game.player.hp, 2400) and arrow.is_queued_for_deletion() and game.get_children().any(func(n): return n is EnemyAttackVfx and n.kind == "wood"))
	wall.queue_free()
	await step()
	game.player.teleport(origin + Vector3(0, 0, 5))
	bullet = game.launch_enemy_projectile(origin, origin + Vector3.RIGHT, 1.5, "bullet", 15)
	bullet.set_physics_process(false)
	bullet._physics_process(2)
	check("hunter bullet expires at 15 world units", bullet.is_queued_for_deletion() and bullet.travelled <= 15.001)
	await clean()
	game.player.teleport(origin + Vector3(4, 0, 1))
	bullet = game.launch_enemy_projectile(origin, origin + Vector3.RIGHT, 1.5, "bullet", 15)
	bullet.set_physics_process(false)
	game.open_modal("capture")
	bullet._physics_process(0.4)
	check("menus pause projectile position and range consumption", bullet.global_position == origin and bullet.travelled == 0)
	game.close_modal()
	bullet._physics_process(0.4)
	check("sidestepping the locked bullet path avoids damage", is_equal_approx(game.player.hp, 2400) and not bullet.is_queued_for_deletion())
	await clean()
	var fast := enemy("brawler")
	game.player.invulnerable = true
	var starts: Array[int] = []
	for tick in range(400):
		# Keep the opponent in front after each real lunge.
		game.player.teleport(fast.global_position + Vector3(2, 0, 0))
		var previous := fast.attack_phase
		fast._physics_process(1.0 / 60)
		if previous == "idle" and fast.attack_phase == "windup": starts.append(tick)
	# Interval counts from the strike, so one cycle is windup (0.8) + interval (1.0).
	check("brawler cycle is windup plus interval after the strike", starts.size() >= 3 and absf(float(starts[1] - starts[0]) / 60 - 1.8) < 0.04 and absf(float(starts[2] - starts[1]) / 60 - 1.8) < 0.04)

	await clean()
	var e := enemy("crossbow")
	e._attack_timer = 0.5
	e._begin_telegraphed_attack()
	game.open_modal("capture")
	e._physics_process(0.3)
	check("menu pauses enemy windup and cooldown", is_equal_approx(e._windup_remaining, 1.0) and is_equal_approx(e._attack_timer, 0.5))
	game.close_modal()
	e.hitstop_remaining = 0.1
	e._physics_process(0.05)
	check("hitstop pauses both pose and attack", e.pose_frame == 1 and is_equal_approx(e._windup_remaining, 1.0))
	e.hitstop_remaining = 0
	e.begin_return()
	e._tick_attack(2)
	check("return cancels body cues and attack without stray projectile", e.attack_phase == "idle" and not e._glint.visible and shots().is_empty())
	await clean()
	e = enemy("crossbow")
	e._begin_telegraphed_attack()
	e.take_hit(9999)
	e._resolve_attack()
	check("death during windup cannot release an attack", shots().is_empty())

	for region in ["city", "snow"]:
		game.settle(true)
		await game.start_contract(region)
		game.player.set_physics_process(false)
		await clean()
		e = enemy("elite")
		e._begin_telegraphed_attack()
		check(region + " elite keeps red ground warning", e.elite and markers().size() == 1 and e.pending_warning_radius > 0)
		e.begin_return()
		await step()
		check(region + " elite return removes warning", markers().is_empty())
		game._open_vault()
		check(region + " vault retains one elite guardian", game._vault_guardians.size() == 1 and game._vault_guardians[0].elite)

	var image := FieldArt.ENEMY_ATTACKS.get_image()
	var aligned := image.get_size() == Vector2i(320, 448)
	for row in range(7):
		for column in range(5):
			var bounds := image.get_region(Rect2i(column * 64, row * 64, 64, 64)).get_used_rect()
			aligned = aligned and bounds.end.y == 51 and bounds.position.x > 0 and bounds.end.x < 64 and bounds.position.y > 0
	# Eight-direction sheets: an enemy with a baked board turns to face on
	# screen; enemies without one keep the flipped side view.
	game.settle(true)
	await game.start_contract("mine")
	game.player.set_physics_process(false)
	await clean()
	var walker := enemy("thug")
	check("thug uses its eight-direction sheet with a centred cell", walker.directional and walker._sprite.offset == Vector2(0, 19))
	# The camera sits at -z looking +z: world -z is screen south, +x screen west.
	var facings := {Vector3(0, 0, -1): 0, Vector3(1, 0, -1): 1, Vector3(1, 0, 0): 2, Vector3(1, 0, 1): 3, Vector3(0, 0, 1): 4, Vector3(-1, 0, 1): 5, Vector3(-1, 0, 0): 6, Vector3(-1, 0, -1): 7}
	var turned := true
	for world_dir in facings:
		walker._face(world_dir.normalized(), 1.0)
		turned = turned and walker.dir_column == facings[world_dir] and not walker._sprite.flip_h and walker._sprite.texture.region.position == Vector2(facings[world_dir] * 64, 0)
	check("thug picks the sheet column for all eight screen directions without flipping", turned)
	walker._face(Vector3(-1, 0, 0), 1.0)
	walker._face(Vector3(-1, 0, -0.5).normalized(), 1.0 / 60)
	check("small drift past a sector edge does not flicker the facing", walker.dir_column == 6)
	walker._face(Vector3(-1, 0, -1.2).normalized(), 1.0 / 60)
	check("a clear turn past the edge changes the facing", walker.dir_column == 7)
	walker._face(Vector3(0, 0, 1), 1.0)
	walker._begin_telegraphed_attack()
	# clean() puts the player at +2 x, i.e. screen west of the enemy.
	check("attack locks toward the player and uses that column's pose", walker.dir_column == 2 and walker._sprite.texture.region == Rect2(2 * 64, 64, 64, 64))
	var sheet := FieldArt.enemy_dir_pose("thug", 0, 0).atlas.get_image()
	var dir_aligned := sheet.get_size() == Vector2i(512, 320)
	for pose in range(5):
		for column in range(8):
			dir_aligned = dir_aligned and sheet.get_region(Rect2i(column * 64, pose * 64, 64, 64)).get_used_rect().end.y == 51
	var side_idle := FieldArt.ENEMY_ATTACKS.get_image().get_region(Rect2i(0, 0, 64, 64)).get_used_rect().size.y
	var dir_idle := sheet.get_region(Rect2i(0, 0, 64, 64)).get_used_rect().size.y
	check("directional frames share the foot line and match the side-view idle height", dir_aligned and absi(dir_idle - side_idle) <= 2)
	# Walking: frames come from the walk sheet and advance with distance.
	await clean()
	game.player.teleport(origin + Vector3(8, 0, 0))
	var mover := enemy("thug")
	var walk_sheet := FieldArt.enemy_walk_pose("thug", 0, 0).atlas
	var seen_frames := {}
	for tick in range(40):
		mover._physics_process(1.0 / 60)
		if mover.walking: seen_frames[mover._sprite.texture.region.position.y] = true
	check("chasing enemy plays its eight-direction walk sheet", mover.has_walk and mover.walking and mover._sprite.texture.atlas == walk_sheet)
	check("walk cycles through all four frames as it covers ground", seen_frames.size() == 4 and mover.walk_distance > 1.0)
	game.player.teleport(mover.global_position + Vector3(2, 0, 0))
	mover._attack_timer = 5
	for tick in range(3): mover._physics_process(1.0 / 60)
	check("standing in range shows the idle pose, not a walk frame", not mover.walking and mover._sprite.texture.atlas != walk_sheet and mover.pose_frame == 0)
	var walk_image := walk_sheet.get_image()
	var walk_aligned := walk_image.get_size() == Vector2i(512, 256)
	for frame in range(4):
		for column in range(8):
			walk_aligned = walk_aligned and walk_image.get_region(Rect2i(column * 64, frame * 64, 64, 64)).get_used_rect().end.y == 51
	var walk_height := walk_image.get_region(Rect2i(0, 0, 64, 64)).get_used_rect().size.y
	var idle_height := FieldArt.enemy_dir_pose("thug", 0, 0).atlas.get_image().get_region(Rect2i(0, 0, 64, 64)).get_used_rect().size.y
	check("walk frames share the attack sheet foot line and body height", walk_aligned and absi(walk_height - idle_height) <= 3)
	var all_walk := true
	for type in EnemyAttacks.ORDER: all_walk = all_walk and FieldArt.has_walk(type)
	check("all seven ordinary enemies have walk sheets", all_walk)
	# Thug and ice warrior boards drew E turned away; their E column is W mirrored.
	var mirrored := true
	for type in ["thug", "ice_warrior"]:
		var art := FieldArt.enemy_dir_pose(type, 0, 0).atlas.get_image()
		for pose in range(5):
			var west := art.get_region(Rect2i(2 * 64, pose * 64, 64, 64))
			west.flip_x()
			var east := art.get_region(Rect2i(6 * 64, pose * 64, 64, 64))
			for y in range(64):
				for x in range(63):
					# Import rewrites the colour of fully transparent texels, so
					# compare coverage everywhere and colour only where visible.
					var e_px := east.get_pixel(x + 1, y)
					var w_px := west.get_pixel(x, y)
					mirrored = mirrored and (e_px.a > 0.5) == (w_px.a > 0.5) and (w_px.a <= 0.5 or e_px.is_equal_approx(w_px))
		var tips: Array = EnemyDirectionalData.TIPS[type]
		mirrored = mirrored and tips[6] == Vector2(-tips[2].x, tips[2].y)
	check("thug and ice warrior face east with the mirrored west profile", mirrored)
	var all_directional := true
	for type in EnemyAttacks.ORDER:
		var ordinary := enemy(type)
		all_directional = all_directional and ordinary.directional and ordinary._sprite.offset == Vector2(0, 19)
	check("all seven ordinary enemies use eight-direction sheets", all_directional)
	check("enemy weapon trails are rust, never the player's white or grey-blue", EnemyAttackVfx.TRAIL != CombatVfx.WHITE and EnemyAttackVfx.TRAIL != CombatVfx.BLUE and EnemyAttackVfx.TRAIL.r > EnemyAttackVfx.TRAIL.b * 1.5)
	check("all 35 sprites share foot baseline and retain unclipped weapons", aligned)
	FileAccess.open("res://../evidence/enemy-attacks-tests.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": results, "failures": failures}, "  "))
	print("ENEMY_ATTACKS: %d checks / %d failures" % [results.size(), failures])
	game.queue_free()
	await step()
	quit(1 if failures else 0)
