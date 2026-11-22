extends SceneTree
## 出手打击时机修订案 方案 A (user-confirmed frames 2026-11-22): a basic swing
## starts on its strike frame, the same tick the hit resolves; the action keeps
## its full length (lock unchanged) by holding the last frame. Lappland and
## Amiya first. Run: ./scripts/run-test.sh test_attack_impact.gd 60
var game: GameManager
var p: Player
var failures := 0
var origin := Vector3(0, 0.7, -22)
const CONFIRMED := {"lappland": {"attack_1": 1, "attack_2": 2, "attack_3": 1},
	"amiya_guard": {"attack_1": 1, "attack_2": 1, "attack_3": 1}}
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
func dummy(point: Vector3) -> Enemy:
	game._spawn_enemy(point, true, false)
	var enemy := game.get_child(game.get_child_count() - 1) as Enemy
	enemy.max_health = 1000000
	enemy.health = 1000000
	enemy.defense = 0
	enemy.res = 0
	enemy.set_physics_process(false)
	enemy.global_position = point
	return enemy
func opaque(texture: AtlasTexture) -> int:
	var image := texture.atlas.get_image().get_region(Rect2i(texture.region))
	var n := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5: n += 1
	return n

func run() -> void:
	# Static: the table matches what the user confirmed, every strike frame is
	# inside its action and painted in all five combat rows.
	for id in CONFIRMED:
		var config: Dictionary = LapplandAnimator3D.look_config(id)
		check("%s strike table is the confirmed one" % id, config.get("impact", {}) == CONFIRMED[id])
		var frames := LapplandAnimator3D.frames_for(id)
		for action in CONFIRMED[id]:
			var f: int = CONFIRMED[id][action]
			var inside := true
			var painted := true
			for row in LapplandAnimator3D.COMBAT_ROWS:
				var anim: String = action + "_" + row
				inside = inside and f < frames.get_frame_count(anim)
				if inside: painted = painted and opaque(frames.get_frame_texture(anim, f)) >= 40
			check("%s %s strike frame %d inside the action and painted in 5 rows" % [id, action, f], inside and painted)

	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	game.base.recruit(Operators.LAPPLAND)
	await game.start_contract("mine")
	game._clear_field()
	await step(2)
	game.set_process(false)
	for id in CONFIRMED:
		game.player.set_operator(id)
		await step(1)
		p = game.player
		p.set_physics_process(false)
		p._sprite.set_process(false)
		p.teleport(origin)
		p.stats["crit"] = -1.0
		check("%s is the operator on the field" % id, p.operator_id == id and p._sprite.character == id)
		p.sword_charge = 0
		for rate in [1.0, 1.5]:
			for stage in range(3):
				for node in get_nodes_in_group("enemies"):
					node.remove_from_group("enemies"); node.queue_free()
				var e := dummy(origin + Vector3(0, 0, -1.5))
				p.combo_step = stage
				p._attack_cooldown = 0
				p.hitstop_remaining = 0
				p.sword_charge = 0
				var before := e.health
				var s := p._sprite
				# animation_rate() follows attack speed; set the sprite's rate directly
				# for the r = 1.5 pass through play_attack's own path.
				if rate == 1.0:
					p.attack(e)
				else:
					s.play_attack(Vector3.FORWARD, stage, false, rate)
				var action := "attack_%d" % (stage + 1)
				var f: int = CONFIRMED[id][action]
				var count := s.sprite_frames.get_frame_count(s.animation)
				var tag := "%s %s r%.1f" % [id, action, rate]
				check("%s first drawn frame is the strike frame %d" % [tag, f], s.action_name == action and s.frame == f)
				check("%s lock keeps the full action length" % tag, is_equal_approx(s.action_duration, float(count) / (12.0 * rate)))
				if rate == 1.0:
					check("%s hit resolves on the click tick" % tag, e.health < before)
					check("%s swing_remaining unchanged" % tag, is_equal_approx(p.swing_remaining, float(count) / 12.0))
				# Walk the clock: frames advance from the strike frame, then hold the last.
				var seen: Array[int] = [s.frame]
				var t := 0.0
				var held_ok := true
				while t + 1.0 / 60.0 < s.action_duration - 0.0001:
					p.hitstop_remaining = 0
					s._process(1.0 / 60.0)
					t += 1.0 / 60.0
					var want := mini(count - 1, f + int(t * 12.0 * rate + 0.0001))
					if s.frame != want: held_ok = false
					if seen.back() != s.frame: seen.append(s.frame)
				check("%s frames run %s and hold the last" % [tag, str(seen)], held_ok and seen.back() == count - 1 and seen.front() == f)
				p.hitstop_remaining = 0
				s._process(0.05)
				check("%s action ends on time" % tag, s.action_duration == 0.0)
	print("TEST_ATTACK_IMPACT: %d failures" % failures)
	quit(1 if failures else 0)
