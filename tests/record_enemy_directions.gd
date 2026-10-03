extends SceneTree

## Not a test — a real-time clip of enemies with eight-direction sheets
## approaching and attacking from all eight sides, to judge the turnaround
## art in motion. Enemies without a board are skipped.
## Run with Movie Maker (needs a real renderer, so no --headless):
##   godot --path downfall-godot --script res://tests/record_enemy_directions.gd
##        --rendering-method gl_compatibility --audio-driver Dummy
##        --resolution 640x360 --fixed-fps 15 --write-movie <dir>/frame.png [-- walk]

const TURN_FRAMES := 45  # 3 s per side at 15 fps
const REGION_OF := {"thug": "mine", "crossbow": "mine", "slug": "mine", "brawler": "city", "crossbow_leader": "city", "ice_warrior": "snow", "ice_hunter": "snow"}

var rig: Node
var game: GameManager

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

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	for type in EnemyAttacks.ORDER:
		if not FieldArt.has_directional(type): continue
		await game.start_contract(REGION_OF[type])
		game._clear_field()
		await step(2)
		# At the native 640x360 capture size the HUD panel covers the centre.
		if is_instance_valid(game._hud): game._hud.visible = false
		var player := game.player
		player.max_hp = 500
		player.hp = 500
		var origin := ContinuousWorldMap.ENTRY_POSITION
		# "-- walk": start 7 units out on four sides so the approach is walked.
		var walk_mode := OS.get_cmdline_user_args().has("walk")
		var reach := 7.0 if walk_mode or EnemyAttacks.PROFILES[type].shape == "projectile" else 3.0
		for side in (range(0, 8, 2) if walk_mode else range(8)):
			player.teleport(origin)
			await step(2)
			var offset := Vector3.FORWARD.rotated(Vector3.UP, side * PI / 4) * reach
			var enemy := game._spawn_enemy(origin + offset, false, EnemyAttacks.PROFILES[type].shape == "projectile", type)
			enemy.health = 10000
			enemy.begin_chase()
			for i in range(TURN_FRAMES): await step(1)
			if is_instance_valid(enemy): enemy.queue_free()
			await step(2)
		game.settle(true)
		await step(3)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
