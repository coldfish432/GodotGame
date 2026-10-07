extends SceneTree
var game: GameManager
var p: Player
var failures := 0
var checks: Array[Dictionary] = []
var origin := Vector3(0, 0.7, -22)
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
func dummy(point: Vector3) -> Enemy:
	game._spawn_enemy(point, true, false)
	var enemy := game.get_child(game.get_child_count() - 1) as Enemy
	# Defenceless and sturdy, so every check below reads raw damage.
	enemy.max_health = 100000
	enemy.health = 100000
	enemy.defense = 0
	enemy.res = 0
	enemy.set_physics_process(false)
	return enemy
func swing(enemy: Enemy) -> void:
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.attack(enemy)
## (foot line, body height) in texels measured from the texture centre, which
## is the billboard's anchor. Rows under 3 opaque texels (blade lines) are ignored.
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
func waves() -> Array[Node]:
	return game.get_children().filter(func(n): return n is SwordWave and not n.is_queued_for_deletion())
func clear_waves() -> void:
	for wave in waves():
		game.remove_child(wave)
		wave.queue_free()
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await game.start_contract("mine")
	game._clear_field()
	await step(2)
	game.set_process(false)
	p = game.player
	p.set_physics_process(false)
	p._sprite.set_process(false)
	p.teleport(origin)
	var weapon := Item.create("测试幼狼之牙", Item.Category.WEAPON, 2, 1)
	weapon.rarity = 2
	weapon.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE), ItemModifier.stat_mod(ItemModifier.Stat.ATTACK_SPEED_PCT, 0.10)]
	p.equip(weapon)
	check("wave affix and attack speed stack", p.has_sword_wave() and is_equal_approx(p.blade_cooldown, Player.BASE_BLADE_COOLDOWN / 1.1))
	var restored := Item.from_data(weapon.to_data())
	check("affix survives save roundtrip with tooltip", restored.modifiers[0].trigger == ItemModifier.Trigger.SWORD_WAVE and "幼狼之牙" in restored.details())
	var enemy := dummy(origin + Vector3(0, 0, 2))
	for i in range(3):
		var before := enemy.health
		swing(enemy)
		check("melee hit %d deals ATK x combo scale and adds exactly one charge" % (i + 1), is_equal_approx(before - enemy.health, 600.0 * Player.COMBO_SCALES[i]) and p.sword_charge == i + 1)
		check("combo pose %d selected" % (i + 1), p._sprite.action_name == "attack_" + str(i + 1))
	check("third hit readies without firing", waves().is_empty() and p.combo_step == 0 and is_equal_approx(p.hitstop_remaining, 0.05))
	p._tick_combat(20)
	check("full charge persists indefinitely", p.sword_charge == 3)
	swing(enemy)
	check("fourth hit releases and does not re-charge", p.sword_charge == 0 and waves().size() == 1 and p.combo_step == 0 and p._sprite.action_name == "wave")
	var wave := waves()[0] as SwordWave
	wave.set_physics_process(false)
	check("wave snapshots 150% of arts ATK as arts damage", is_equal_approx(wave.damage, 540.0) and wave.kind == "arts")
	var second := dummy(origin + Vector3(0, 0, 5))
	var off_axis := dummy(origin + Vector3(1, 0, 5))
	var past_range := dummy(origin + Vector3(0, 0, 10))
	var first_hp := enemy.health
	wave._physics_process(0.45)
	check("swept wave penetrates multiple enemies at full speed", is_equal_approx(enemy.health, first_hp - 540) and second.health == 100000 - 540 and is_equal_approx(wave.travelled, 6.3))
	check("wave width rejects off-axis targets and does not charge", off_axis.health == 100000 and p.sword_charge == 0)
	wave._physics_process(0.3)
	check("range capped to nine and each enemy hit once", wave.is_queued_for_deletion() and is_equal_approx(wave.travelled, 9) and second.health == 100000 - 540 and past_range.health == 100000)
	check("wave gives no enemy hitstop", second.hitstop_remaining == 0)
	clear_waves()
	swing(enemy)
	check("combo restarts at first after wave", p._sprite.action_name == "attack_1")
	p._tick_combat(3.9)
	check("partial charge lasts until four seconds", p.sword_charge == 1)
	p._tick_combat(0.11)
	check("partial charge expires and combo resets", p.sword_charge == 0 and p.combo_step == 0)
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.attack_direction(Vector3.FORWARD)  # away from the dummies: a true air swing
	check("whiff animates but adds no charge", p.sword_charge == 0 and p._sprite.action_name == "attack_1")
	swing(enemy)
	p._tick_combat(3.5)
	swing(enemy)
	p._tick_combat(1)
	check("new hit refreshes partial expiry", p.sword_charge == 2)
	p.take_damage(0.5)
	check("hurt preserves charge and selects recoil", p.sword_charge == 2 and p._sprite.action_name == "hurt")
	p.hitstop_remaining = 0
	p._start_dash(Vector3.RIGHT)
	check("dash keeps charges and grants invulnerability", p.sword_charge == 2 and p.invulnerable and p._sprite.action_name == "dash")
	var ghosts := game.get_children().filter(func(n): return n is CombatVfx and n.kind == "ghost")
	check("dash leaves three afterimages", ghosts.size() == 3)
	p._tick_combat(0.281)
	check("dash invulnerability ends at 0.28 seconds", not p.invulnerable)
	p.teleport(origin)
	p.sword_charge = 3
	p._attack_cooldown = 0
	p.attack_direction(Vector3.FORWARD)  # away from the dummies: a true air swing
	check("full charge can release on empty ground", waves().size() == 1 and p.sword_charge == 0)
	clear_waves()
	p.sword_charge = 3
	var other := Item.create("无词缀剑", Item.Category.WEAPON, 2, 1)
	p.equip(other)
	check("weapon swap clears stored charge", p.sword_charge == 0 and not p.has_sword_wave())
	swing(enemy)
	check("ordinary weapons never charge", p.sword_charge == 0)
	p.equip(weapon)
	p.sword_charge = 3
	p.unequip(Item.Category.WEAPON)
	check("unequip clears charge", p.sword_charge == 0)
	var armor := Item.create("非法词缀防具", Item.Category.ARMOR, 2, 2)
	armor.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	p.equip(armor)
	check("non-weapon trigger cannot activate wave", not p.has_sword_wave())
	p.equip(weapon)
	p.sword_charge = 2
	game.open_modal("inventory")
	p._physics_process(10)
	check("menu pause stops charge expiry", p.sword_charge == 2)
	game.close_modal()
	p.reset_floor_state()
	check("floor transition preserves charge but resets combo", p.sword_charge == 2 and p.combo_step == 0)
	p.clear_charge()
	var bystander := dummy(origin + Vector3(-2, 0, 0))
	for e in [enemy, bystander]:
		e.state = Enemy.State.CHASING
		e._begin_telegraphed_attack()
	swing(enemy)
	var a := enemy._windup_remaining
	var b := bystander._windup_remaining
	enemy._physics_process(0.016)
	bystander._physics_process(0.016)
	check("hitstop pauses hit enemy only; other telegraph advances", enemy._windup_remaining == a and bystander._windup_remaining < b and Engine.time_scale == 1)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5, 3, 0.2)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.global_position = origin + Vector3(0, 0, 3.5)
	await step(2)
	var blocked_wave := SwordWave.new()
	blocked_wave.position = origin
	blocked_wave.direction = Vector3.BACK
	game.add_child(blocked_wave)
	blocked_wave.set_physics_process(false)
	var second_hp := second.health
	blocked_wave._physics_process(0.6)
	check("wall stops wave before enemies behind it", blocked_wave.is_queued_for_deletion() and blocked_wave.travelled < 3.5 and second.health == second_hp)
	wall.queue_free()
	# A dodge pressed during a hit's freeze frames must still come out.
	p.teleport(origin)
	p.stamina = 100
	p._dash_cooldown = 0
	p.dash_remaining = 0
	p.invulnerable = false
	p.hitstop_remaining = 0.05
	Input.action_press("dash")
	p._physics_process(0.016)
	Input.action_release("dash")
	check("dash pressed in hitstop waits instead of firing", not p.invulnerable and p.hitstop_remaining > 0)
	p._physics_process(0.05)
	p._physics_process(0.016)
	check("dash pressed in hitstop fires once hitstop ends", p.invulnerable and p.dash_remaining > 0)
	p._physics_process(0.016)
	check("buffered dash fires only once", not p._dash_buffered and p.stamina > 70 and p.stamina < 80)
	p.reset_combat_state()
	p.teleport(origin)
	# Whiffs must not spend one-shot relic bonuses (赏善郎 after an evade).
	game.builds.append("赏善郎")
	p._recompute_stats()
	p._on_evade()
	p._attack_cooldown = 0
	p.attack_direction(Vector3.FORWARD)  # away from the dummies: a true air swing
	check("whiff keeps 赏善郎 armed", p.avenge_ready)
	var counter_hp := enemy.health
	p.teleport(origin)
	swing(enemy)
	check("next landed hit spends 赏善郎 for double damage", not p.avenge_ready and is_equal_approx(counter_hp - enemy.health, 1200.0))
	game.builds.erase("赏善郎")
	p._recompute_stats()
	p.combat_timer = 6.0
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.attack_direction(Vector3.FORWARD)  # away from the dummies: a true air swing
	check("whiff does not reset out-of-combat timer", p.combat_timer == 6.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9329
	var eligible := 0
	var rolled := 0
	var valid := true
	var cooldown_rolls := 0
	var speed_rolls := {}
	for i in range(4000):
		var item := FieldCatalog.roll_item(["mine", "city", "snow"][i % 3], 2, rng)
		if not item.special.is_empty(): continue  # special gear carries fixed effects of its own
		var count := 0
		for mod in item.modifiers:
			if mod.trigger == ItemModifier.Trigger.SWORD_WAVE: count += 1
			if mod.stat == ItemModifier.Stat.BLADE_COOLDOWN_PCT and mod.trigger == ItemModifier.Trigger.NONE: cooldown_rolls += 1
			if mod.stat == ItemModifier.Stat.ATTACK_SPEED_PCT and mod.trigger == ItemModifier.Trigger.NONE:
				speed_rolls[item.category] = int(speed_rolls.get(item.category, 0)) + 1
		if item.category == Item.Category.WEAPON and item.rarity > 0: eligible += 1
		if count > 0: rolled += 1
		valid = valid and count <= 1 and item.modifiers.size() <= item.rarity and (count == 0 or (item.category == Item.Category.WEAPON and item.rarity >= 1))
	check("loot only rolls one wave on eligible weapons within affix budget", valid and rolled > 0)
	check("attack speed rolls on weapons and trinkets only, cooldown affix retired", cooldown_rolls == 0 and speed_rolls.has(Item.Category.WEAPON) and speed_rolls.has(Item.Category.TRINKET) and not speed_rolls.has(Item.Category.ARMOR))
	check("provisional chance produces expected distribution", float(rolled) / eligible > 0.15 and float(rolled) / eligible < 0.35)
	var sprite := p._sprite
	var total := 0
	for direction in LapplandAnimator3D.COMBAT_ROWS:
		for action in LapplandAnimator3D.ACTIONS:
			total += sprite.sprite_frames.get_frame_count(action + "_" + direction)
	check("70 authored combat frames at 12 fps", total == 70 and sprite.sprite_frames.get_animation_speed("wave_south") == 12)
	sprite._facing_index = 0
	sprite._start_action("attack_1")
	check("east mirrors west combat frames", sprite.flip_h and sprite.animation == "attack_1_west")
	check("attack animations fit base cooldown", 4.0 / 12.0 + 0.05 < Player.BASE_BLADE_COOLDOWN)
	# Attack speed: weapon + trinket add up, divide the interval, and the swing
	# animation and slash play faster so they still finish before the next one.
	var charm := Item.create("测试挂饰", Item.Category.TRINKET, 1, 1)
	charm.modifiers = [ItemModifier.stat_mod(ItemModifier.Stat.ATTACK_SPEED_PCT, 0.4)]
	p.equip(charm)
	check("weapon and trinket attack speed add up", is_equal_approx(p.attack_speed, 1.5) and is_equal_approx(p.blade_cooldown, Player.BASE_BLADE_COOLDOWN / 1.5))
	p.teleport(origin)
	p.sword_charge = 0
	p.combo_step = 2
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.attack_direction(Vector3.FORWARD)  # away from the dummies: a true air swing
	var slash: CombatVfx = game.get_children().filter(func(n): return n is CombatVfx and n.kind == "slash").back()
	check("fast swing animation fits the shorter interval", p._sprite.action_name == "attack_3" and is_equal_approx(p._sprite.action_duration, 4.0 / 18.0) and p._sprite.action_duration + 0.05 < p.blade_cooldown)
	check("slash effect speeds up with the swing", is_equal_approx(slash.duration, 0.2 / 1.5) and is_equal_approx(slash.rate, 1.5))
	# Painted effects: each combo stage and the wave use their baked texture,
	# laid flat on the ground (quad normal up) at one texel per world pixel.
	var painted := true
	for stage in range(3):
		var fx := CombatVfx.spawn(game, origin, Vector3.BACK, "slash", stage)
		var decal: MeshInstance3D = fx._parts[0]
		var mat := decal.material_override as StandardMaterial3D
		painted = painted and mat.albedo_texture == CombatVfx.SLASH_TEXTURES[stage] and decal.global_basis.z.normalized().is_equal_approx(Vector3.UP) and (decal.mesh as QuadMesh).size.is_equal_approx(CombatVfx.SLASH_TEXTURES[stage].get_size() * CombatVfx.PIXEL)
		fx.queue_free()
	var wave_fx := CombatVfx.spawn(game, origin, Vector3.BACK, "wave", 0, true)
	painted = painted and (wave_fx._parts[0].material_override as StandardMaterial3D).albedo_texture == CombatVfx.WAVE_TEXTURE
	wave_fx.queue_free()
	check("combo slashes and sword wave use the painted pixel textures", painted)
	# Sundial X: surges straight ahead like the wave, echoes lagging, no swing.
	var surge := CombatVfx.spawn(game, origin, Vector3.BACK, "slash", 2)
	var lead: MeshInstance3D = surge._parts.filter(func(part): return part.has_meta("surge") and part.get_meta("surge") == 0)[0]
	var echo: MeshInstance3D = surge._parts.filter(func(part): return part.has_meta("surge") and part.get_meta("surge") == 2)[0]
	var start_z := lead.position.z
	var start_yaw := surge.rotation.y
	surge._process(surge.duration * 0.5)
	var mid_z := lead.position.z
	surge._process(surge.duration * 0.45)
	check("Sundial X surges forward without leaving as a projectile", mid_z < start_z and lead.position.z < mid_z and -lead.position.z <= CombatVfx.SURGE_TO + 0.01 and is_equal_approx(surge.rotation.y, start_yaw))
	check("Sundial X echoes trail behind the leading cut", echo.position.z > lead.position.z)
	surge.queue_free()
	# Wave: the pointed (convex) crescent leads at the top, echoes below it.
	var wave_image := CombatVfx.WAVE_TEXTURE.get_image()
	var widest_row := 0
	var widest := 0
	for y in range(wave_image.get_height()):
		var count := 0
		for x in range(wave_image.get_width()):
			if wave_image.get_pixel(x, y).a > 0.5: count += 1
		if count > widest:
			widest = count
			widest_row = y
	check("sword wave crescent leads with echoes trailing", widest_row < wave_image.get_height() / 2)
	var released := CombatVfx.spawn(game, origin, Vector3.BACK, "slash", 0, true)
	check("the release swing is tinted arts purple", (released._parts[0].material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color(CombatVfx.LIGHT, 0.7)))
	released.queue_free()
	p._sprite._process(0.12)
	check("fast swing reaches its last frame early", p._sprite.frame == 2)
	p._sprite.cancel_action()
	charm.modifiers.append(ItemModifier.stat_mod(ItemModifier.Stat.BLADE_COOLDOWN_PCT, 0.15))
	p._recompute_stats()
	check("interval modifiers still scale the attack-speed interval", is_equal_approx(p.blade_cooldown, Player.BASE_BLADE_COOLDOWN * 1.15 / 1.5))
	charm.modifiers.pop_back()
	p.unequip(Item.Category.TRINKET)
	charm.modifiers = [ItemModifier.stat_mod(ItemModifier.Stat.ATTACK_SPEED_PCT, -0.5)]
	p.equip(charm)
	check("slower attacks lengthen the interval but not the animation", is_equal_approx(p.blade_cooldown, Player.BASE_BLADE_COOLDOWN / 0.6) and p.animation_rate() == 1.0)
	p.unequip(Item.Category.TRINKET)
	var old_save := weapon.to_data()
	old_save.mods = [{"stat": ItemModifier.Stat.BLADE_COOLDOWN_PCT, "amount": -0.08, "trigger": ItemModifier.Trigger.NONE}]
	var converted := Item.from_data(old_save)
	p.equip(converted)
	check("saved cooldown affix loads as equivalent attack speed", converted.modifiers[0].stat == ItemModifier.Stat.ATTACK_SPEED_PCT and is_equal_approx(p.blade_cooldown, Player.BASE_BLADE_COOLDOWN * 0.92) and "攻速 +9" in converted.details())
	p.equip(weapon)
	# Switching from walk to an attack must not resize or lift her: compare
	# the body's foot line and height against the idle frame per direction.
	var aligned := true
	for direction in LapplandAnimator3D.COMBAT_ROWS:
		var idle := body_metrics(sprite.sprite_frames.get_frame_texture("idle_" + direction, 0))
		for action in ["attack_1", "attack_2", "wave"]:
			var pose := body_metrics(sprite.sprite_frames.get_frame_texture(action + "_" + direction, 0))
			var same_feet := absf(pose.x - idle.x) <= 1.5
			var same_size := pose.y / idle.y > 0.88 and pose.y / idle.y < 1.12
			if not (same_feet and same_size):
				aligned = false
				print("  misaligned %s_%s: feet %.1f vs %.1f, height %.1f vs %.1f" % [action, direction, pose.x, idle.x, pose.y, idle.y])
	check("combat frames keep walk foot line and body size", aligned)
	var file := FileAccess.open("res://../evidence/lappland-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "eligible_weapons": eligible, "wave_weapons": rolled}, "  "))
	file.close()
	print("TEST_LAPPLAND: %d checks / %d failures" % [checks.size(), failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)
