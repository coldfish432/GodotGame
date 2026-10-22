extends SceneTree

## Not a test — a real-time clip of one boss or warden's attacks, for checking
## their effects (用户 2026-10-20: 完善各 boss 的攻击特效，通过录制视频验证).
## Every move of phases 1–3 at its tier, each labelled in the corner; she is
## invulnerable and is put a few metres off before each. Prints
## "MARK <frame> <move> start|land" so stills can be cut at the right frames.
## Pick the figure with BOSS_REC=<region>:<floor>, e.g. mine:100. Run with Movie Maker:
##   set BOSS_REC=mine:100
##   godot --path downfall-godot --script res://tests/record_boss_fx.gd
##        --audio-driver Dummy --resolution 1280x720 --fixed-fps 30
##        --write-movie <dir>/frame.png
## BOSS_REC_ONLY=<id,id> keeps only those moves.

const GAP := 14        # frames between moves
const MOVE_CAP := 330  # frames at most for one move
const AFTER := 24      # frames kept after a move ends, for what it leaves

var rig: Node
var game: GameManager
var caption: Label
var frame := 0

func _initialize() -> void: call_deferred("run")

func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
		frame += 1

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func near(at: Vector3, reach: float) -> Vector3:
	var best := game.world_map.nearest_walkable(at + Vector3(reach, 0, 0))
	for i in range(8):
		var want := at + Vector3(cos(TAU * i / 8.0), 0, sin(TAU * i / 8.0)) * reach
		var got := game.world_map.nearest_walkable(want)
		if Vector2(got.x - want.x, got.z - want.z).length() < 1.0 and absf(got.y - at.y) < 1.0: return got
		if got.distance_to(at) < best.distance_to(at) and got.distance_to(at) > 1.0: best = got
	return best

func run() -> void:
	var spec := OS.get_environment("BOSS_REC").split(":")
	var region := spec[0] if spec.size() > 0 and spec[0] != "" else "mine"
	var floor := int(spec[1]) if spec.size() > 1 else 100
	var only := OS.get_environment("BOSS_REC_ONLY").split(",", false)
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
	game.camera.size = 24
	player.teleport(near(figure.global_position, 4.0) + Vector3.UP * 0.7)
	await step(4)
	figure._engage()
	var seen := {}
	for phase in [1, 2, 3]:
		for move in BossCatalog.moves_for(figure.figure_id, figure.tier, phase):
			if seen.has(move.id) or str(move.shape) in ["family", "sandstorm", "backstep"]: continue
			if not only.is_empty() and not str(move.id) in only: continue
			seen[move.id] = true
			if not is_instance_valid(figure) or figure._dead: break
			figure.phase = phase
			figure._cancel_move()
			figure.roar_left = 0.0
			figure.down_left = 0.0
			figure._channel = {}
			var span: Array = move.get("range", [0.0, 3.0])
			var reach := clampf((float(span[0]) + float(span[1])) * 0.5, 1.5, 7.0)
			player.teleport(near(figure.global_position, reach) + Vector3.UP * 0.7)
			# 引爆祭坛 only fires with her by a shrine.
			if str(move.shape) == "shrine_call" and is_instance_valid(game.arena) and not game.arena.shrines().is_empty():
				player.teleport(near(game.arena.shrines()[0].global_position, 1.5) + Vector3.UP * 0.7)
			await step(GAP)
			caption.text = "%s  第 %d 档  阶段 %d  %s（%s）" % [name, figure.tier, phase, str(move.id), str(move.shape)]
			print("MARK %d %s start" % [Engine.get_frames_drawn(), move.id])
			figure._start(move)
			var ticks := 0
			var landed := false
			while is_instance_valid(figure) and not figure._dead and (not figure._move.is_empty() or not figure._channel.is_empty()) and ticks < MOVE_CAP:
				player.hp = player.max_hp
				var seg_before := figure._seg
				await step(1)
				ticks += 1
				if not landed and (figure._seg != seg_before or figure._move.is_empty()):
					landed = true
					print("MARK %d %s land" % [Engine.get_frames_drawn(), move.id])
			await step(AFTER)
	caption.text = ""
	await step(6)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
