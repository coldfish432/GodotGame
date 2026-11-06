extends SceneTree

## Boss演出策划案_v0_2 (用户 2026-11-04): the bosses' set pieces — the intro,
## phase changes, the fall, her fall, the reset — stay fair: while one plays
## the boss is untouchable and idle and she cannot be hurt; her hands are held
## only through an intro, at most FIRST_INTRO the first time and AGAIN_INTRO
## after; any key skips; the loot comes once the fall has played; time comes
## back to normal; a reset puts the look back.

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

## Game seconds stepped (physics at 60 Hz).
func wait_game(seconds: float) -> void:
	await step(int(ceil(seconds * 60.0)) + 1)

## Until `cond` holds or `frames` pass; true if it held.
func until(cond: Callable, frames: int) -> bool:
	for i in range(frames):
		if cond.call(): return true
		await step(1)
	return cond.call()

func run() -> void:
	BossShow.enabled = true
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 4242
	root.add_child(game)
	await step(8)
	_boards()
	await _patriot()
	await _rat_king()
	await _eikthyrnir()
	await _zaro()
	await _warden()
	await _her_fall()
	print("BOSS SHOW RESULT: %d checks, %d failures" % [checks, failures])
	Engine.time_scale = 1.0
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

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

func show() -> BossShow:
	return game.boss_show

## Sol's B3 rows are on the boards, and every set-piece row names one of them.
func _boards() -> void:
	for id in BossShowCatalog.SHOW_ROWS:
		var rows := int(load("res://art/field/enemy_dir_%s_64.png" % id).get_height() / 64)
		var used: Array = (BossShowCatalog.SHOW_ROWS[id] as Dictionary).values()
		check("%s: its set-piece rows are on its board (%d rows)" % [id, rows], used.all(func(r): return int(r) < rows), used)
		check("%s: its intro badge is in" % id, FieldArt.boss_badge(id) != null)
	# 多帧连贯动作 (§14): every move's beats name rows; those past the board fall back.
	for id in BossCatalog.ANIM:
		var rows := int(load("res://art/field/enemy_dir_%s_64.png" % id).get_height() / 64)
		var moves: Array = BossCatalog.MOVES[id].map(func(m): return str(m.id))
		var named: Array = (BossCatalog.ANIM[id] as Dictionary).keys().filter(func(k): return k != "rampage")
		check("%s: every animated move is one of its moves" % id, named.all(func(k): return moves.has(k)), named)
		check("%s: B4 rows continue its board (%d rows now)" % [id, rows], (BossCatalog.ANIM[id] as Dictionary).values().all(func(b): return (b as Dictionary).values().all(func(r): return int(r) >= 0)))

func _patriot() -> void:
	await go_to("mine", 20)
	var figure := game.outpost_boss
	check("爱国者 waits kneeling before the fight (§2.4)", figure.show_row_name == "kneel" and figure.pose_row() == BossShowCatalog.SHOW_ROWS.patriot.kneel)
	check("矿区's boss floor raises the 游击队旗", is_instance_valid(game.arena.flag))
	await near(figure)
	check("walking in starts the intro", is_instance_valid(show()) and show().playing == "intro" and figure.engaged)
	check("first meeting: her hands are held, at most FIRST_INTRO", show().locked() and show().lock_left <= BossShowCatalog.FIRST_INTRO + 0.01 and game.hands_busy(), show().lock_left)
	check("…the boss stands untouchable", figure.take_hit(1000.0, "true") == 0.0 and figure.staging_left > 0.0)
	check("…and she cannot be hurt", game.player.invuln_timer > 0.0)
	check("…the camera looks at the boss", show().focus() != null)
	check("…no gate drops behind her (用户 2026-11-04: 不要门了)", game.arena.find_children("ShowGate*", "", true, false).is_empty())
	await wait_game(BossShowCatalog.FIRST_INTRO + 0.3)
	check("the intro ends inside FIRST_INTRO", show().playing == "" and not show().locked() and not game.hands_busy())
	check("…he stood up out of the kneel", figure.show_row_name == "")
	check("…the camera is back on her", show().focus() == null)
	check("…the first meeting is remembered", game.base.boss_intro_seen.has("mine:1"))
	check("…the scene takes his first stage", show().stage == 0)
	# 多帧连贯动作 (§14): a thrust winds up on its charge row (its start row is a B4
	# row not on the board yet) and lands on its own row, not the shared sweep's.
	figure._cancel_move()
	figure._start(BossCatalog.move_at(BossCatalog.MOVES.patriot.filter(func(m): return m.id == "thrust")[0], 1))
	await step(2)
	check("戟刺 starts on THRUST-SET (B4)", figure.pose_row() == 16, figure.pose_row())
	await until(func(): return figure._attack_elapsed > 0.4, 120)
	check("…charges on THRUST-WIND", figure.pose_row() == 11, figure.pose_row())
	await until(func(): return figure.attack_phase == "strike", 120)
	check("…holds THRUST as it lands, not the shared sweep row", figure.pose_row() == 5, figure.pose_row())
	await until(func(): return figure.attack_phase == "recovery", 60)
	check("…and follows through on THRUST-FOLLOW (B4)", figure.pose_row() == 17, figure.pose_row())
	figure._cancel_move()
	# A phase change: the tick breaks, a freeze, a flash; the look steps on.
	game.player.invuln_timer = 99.0
	figure.health = figure.max_health * 0.505
	figure.take_hit(figure.max_health * 0.02, "true")
	await step(2)
	check("a phase change breaks the bar's tick and flashes", figure.phase == 2 and (not show().shatters.is_empty() or show().flash_age < 1.0))
	await wait_game(BossCatalog.DOWN_TIME + BossShowCatalog.SHADE_EASE + 0.2)
	check("…and the scene steps to stage 2", show().stage == 1, show().stage)
	# Reset: out of the arena long enough.
	var start: Vector2 = game.world_map.main_path[0]
	game.player.teleport(game.world_map.nearest_walkable(Vector3(start.x, 0, start.y)))
	await step(2)
	figure.reset_whole()
	await wait_game(BossShowCatalog.SHADE_EASE + 0.2)
	check("a reset puts the look back and kneels him again", not figure.engaged and show().stage == -1 and figure.show_row_name == "kneel", [figure.engaged, show().stage, figure._flat_distance(game.player.global_position, game.arena.centre), show().playing])
	await near(figure)
	check("meeting again: a short intro (≤ AGAIN_INTRO)", show().playing == "intro" and show().lock_left <= BossShowCatalog.AGAIN_INTRO + 0.01, show().lock_left)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	show()._input(key)
	check("any key skips the intro", not show().locked() and show().playing == "" and figure.staging_left <= 0.0)
	# The fall.
	await step(2)
	game.player.invuln_timer = 99.0
	var cleared := game.outpost_cleared
	figure.take_hit(figure.max_health * 5.0, "true")
	await step(1)
	check("the killing blow: the fall plays before the loot", figure._dead and is_instance_valid(figure) and not game.outpost_cleared and not cleared)
	check("…time freezes then slows", Engine.time_scale < 1.0, Engine.time_scale)
	check("…he dies standing (B3 row)", figure.pose_row() == BossShowCatalog.SHOW_ROWS.patriot.dies)
	check("…its husk takes the sprite's place", get_nodes_in_group("boss_husks").size() >= 1 and not figure._sprite.visible)
	var done := await until(func(): return game.outpost_cleared, 600)
	check("…then the loot and the way out", done)
	check("…time is back to normal", is_equal_approx(Engine.time_scale, 1.0), Engine.time_scale)
	check("爱国者 stays standing where he fell (站着熄灭)", get_nodes_in_group("boss_husks").any(func(h): return is_instance_valid(h) and h.get_parent() == game.world_map))
	await wait_game(BossShowCatalog.SHADE_EASE + 0.2)
	check("…and the scene is the mine's own again", show().stage == -1 and float(show()._shade.dim) < 0.01, show()._shade)

func _rat_king() -> void:
	await go_to("city", 20)
	var figure := game.outpost_boss
	check("鼠王 is not there before the fight (§3.4)", not figure._sprite.visible)
	check("龙门's boss floor has its manholes", game.arena.manholes.size() == BossArena.MANHOLES.size())
	await near(figure)
	await wait_game(BossShowCatalog.FIRST_INTRO + 0.3)
	check("…he is there once the intro has played", figure._sprite.visible and show().playing == "")
	game.player.invuln_timer = 99.0
	figure.take_hit(figure.max_health * 5.0, "true")
	await step(1)
	check("鼠王 pours away as sand (化沙离去)", int((show()._husk.material_override as ShaderMaterial).get_shader_parameter("mode")) == 1)
	await until(func(): return game.outpost_cleared, 600)
	await step(120)
	check("…and leaves nothing standing", get_nodes_in_group("boss_husks").filter(func(h): return is_instance_valid(h) and h.get_parent() == game).is_empty())

func _eikthyrnir() -> void:
	await go_to("snow", 20)
	var figure := game.outpost_boss
	check("木裂 waits in the ice the first time (§4.4)", game.arena.has_mound() and not figure._sprite.visible)
	await near(figure)
	await wait_game(BossShowCatalog.FIRST_INTRO + 0.3)
	check("…breaks out of it", not game.arena.has_mound() and figure._sprite.visible)
	game.player.invuln_timer = 99.0
	figure.health = figure.max_health * 0.505
	figure.take_hit(figure.max_health * 0.02, "true")
	await wait_game(BossCatalog.ROAR_TIME + 0.2)
	check("a phase deepens his collapse", figure.collapse > 0.0)
	await until(func():
		var f := game.outpost_boss
		if is_instance_valid(f) and not f._dead: f.take_hit(f.max_health * 5.0, "true")
		return game.outpost_cleared, 900)
	check("his fall clears the floor", game.outpost_cleared)

func _zaro() -> void:
	await go_to("siracusa", 20)
	var figure := game.outpost_boss
	check("扎罗 sleeps before the fight (§5.4)", figure.asleep)
	await near(figure)
	await wait_game(BossShowCatalog.FIRST_INTRO + 0.3)
	check("…wakes in the intro", not figure.asleep and figure.eyes_open)
	game.player.invuln_timer = 99.0
	figure.take_hit(figure.max_health * 5.0, "true")
	await step(1)
	check("the first life down: down, not dead", not figure._dead and figure.down_left > 0.0)
	await wait_game(1.0)
	check("…goes up as black mist (husk, sprite hidden)", not figure._sprite.visible)
	await wait_game(BossCatalog.DOWN_TIME)
	check("…and stands as the wolf", figure.life == 2 and figure._sprite.visible)
	figure.take_hit(figure.max_health * 5.0, "true")
	await until(func(): return game.outpost_cleared, 600)
	check("the second life's fall clears the floor", game.outpost_cleared)
	await wait_game(BossShowCatalog.SHADE_EASE + 0.2)
	check("…the fountain comes clear again", not is_instance_valid(game.arena._fountain_tint) or (game.arena._fountain_tint.material_override as StandardMaterial3D).albedo_color.a < 0.05)

func _warden() -> void:
	await go_to("mine", 10)
	var figure: Boss = null
	for e in game.get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(e) and e.rank == "warden": figure = e
	check("floor 10 holds a warden", is_instance_valid(figure))
	if not is_instance_valid(figure): return
	game.player.teleport(figure.global_position + Vector3(2.0, 0, 0))
	await step(3)
	figure._engage()
	await step(1)
	check("a warden's intro holds nobody's hands", not game.hands_busy())
	figure.take_hit(figure.max_health * 5.0, "true")
	await step(1)
	check("a warden's fall is no slow motion", Engine.time_scale >= 0.02 and figure._dead)
	await wait_game(BossShowCatalog.WARDEN_FINALE + 0.5)
	check("…and it is gone soon", not is_instance_valid(figure))
	check("time back to normal", is_equal_approx(Engine.time_scale, 1.0))

func _her_fall() -> void:
	await go_to("city", 40)
	var figure := game.outpost_boss
	await near(figure)
	show().skip()
	await step(2)
	game.player.invuln_timer = 0.0
	game.player.hp = 0.0
	await step(2)
	check("her fall in a boss fight: its winning pose first", show().playing == "victory" and not game._settled)
	await wait_game(BossShowCatalog.VICTORY + 0.3)
	check("…then the fall is settled", game._settled)
