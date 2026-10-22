extends SceneTree

## Not a test — a real-time clip of one boss or warden: it walks an octagon
## round her (every facing, each stance), then plays every phase-1 and phase-2 move of its tier in
## turn, each labelled in the corner. She is invulnerable and is put back a few
## metres away before each move. Pick the figure with BOSS_REC=<region>:<floor>
## (mine:20 is 爱国者, mine:10 弑君者 …). Run with Movie Maker:
##   set BOSS_REC=mine:20
##   godot --path downfall-godot --script res://tests/record_bosses.gd
##        --audio-driver Dummy --resolution 1280x720 --fixed-fps 30
##        --write-movie <dir>/frame.png

const WALK_LEG := 90   # frames at most per side of the walking octagon
const WALK_RADIUS := 3.2
const GAP := 18        # frames between moves
const MOVE_CAP := 330  # frames at most for one move

var rig: Node
var game: GameManager
var caption: Label

func _initialize() -> void: call_deferred("run")

func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

## A walkable spot `reach` from `at`: the first of eight directions whose
## nearest walkable point is really there (not on another terrace).
func near(at: Vector3, reach: float) -> Vector3:
	var best := game.world_map.nearest_walkable(at + Vector3(reach, 0, 0))
	for i in range(8):
		var want := at + Vector3(cos(TAU * i / 8.0), 0, sin(TAU * i / 8.0)) * reach
		var got := game.world_map.nearest_walkable(want)
		if Vector2(got.x - want.x, got.z - want.z).length() < 1.0 and absf(got.y - at.y) < 1.0: return got
		if got.distance_to(at) < best.distance_to(at) and got.distance_to(at) > 1.0: best = got
	return best

func say(text: String) -> void:
	caption.text = text

func run() -> void:
	var spec := OS.get_environment("BOSS_REC").split(":")
	var region := spec[0] if spec.size() > 0 and spec[0] != "" else "mine"
	var floor := int(spec[1]) if spec.size() > 1 else 20
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(440, 44)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	caption.add_theme_font_override("font", AK.cn())
	layer.add_child(caption)

	await game.start_contract(region)
	game.floor_number = floor - 1
	await game.advance(0)
	await step(6)
	var player := game.player
	player.invulnerable = true
	var figure: Boss = game.outpost_boss
	var name := BossCatalog.display_name(figure.figure_id)
	game.camera.size = 16
	var home := figure.global_position
	var side := Vector3(5.0, 0, 2.0)
	player.teleport(game.world_map.nearest_walkable(home + side) + Vector3.UP * 0.7)
	await step(4)

	# Walking: its own AI would stop and wind up within a metre, so the clip
	# steps it by hand at its own speed round an octagon about her (all eight
	# facings), once per stance its board has.
	figure._engage()
	figure.set_physics_process(false)
	var poses: Dictionary = BossCatalog.POSES.get(figure.figure_id, {})
	var stances := [1, 2] if poses.has("walk2") else [1]
	var centre := player.global_position
	for stance in stances:
		figure.phase = stance
		say("%s  第 %d 档  行走%s" % [name, figure.tier, "（第二姿态）" if stance == 2 else ""])
		for corner in range(9):
			var a := TAU * corner / 8.0
			var goal := centre + Vector3(cos(a), 0, sin(a)) * WALK_RADIUS
			for i in range(WALK_LEG):
				var to := goal - figure.global_position
				to.y = 0.0
				if to.length() < 0.15: break
				figure._step_toward(to.normalized(), 1.0 / 30.0)
				figure._advance_animation(1.0 / 30.0)
				player.hp = player.max_hp
				await step(1)
		for i in range(12):
			figure._advance_animation(1.0 / 30.0)
			await step(1)
	figure.phase = 1
	figure.set_physics_process(true)

	# Every move of phases 1 and 2, once each.
	var seen := {}
	for phase in [1, 2]:
		figure.phase = phase
		for move in BossCatalog.moves_for(figure.figure_id, figure.tier, phase):
			if seen.has(move.id): continue
			seen[move.id] = true
			if not is_instance_valid(figure) or figure._dead: break
			figure._cancel_move()
			figure.roar_left = 0.0
			figure.down_left = 0.0
			figure._channel = {}
			var span: Array = move.get("range", [0.0, 3.0])
			var reach := clampf((float(span[0]) + float(span[1])) * 0.5, 1.5, 9.0)
			player.teleport(near(figure.global_position, reach) + Vector3.UP * 0.7)
			await step(GAP)
			say("%s  第 %d 档  阶段 %d  %s（%s）" % [name, figure.tier, phase, str(move.id), str(move.shape)])
			figure._start(move)
			var ticks := 0
			while is_instance_valid(figure) and not figure._dead and (not figure._move.is_empty() or not figure._channel.is_empty()) and ticks < MOVE_CAP:
				player.hp = player.max_hp
				await step(1)
				ticks += 1
			await step(GAP)
	say("")
	await step(6)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
