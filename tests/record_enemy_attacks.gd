extends SceneTree

## Not a test — a real-time clip of every ordinary enemy's attack, for judging
## whether the windup reads without a ground warning. Nothing is frozen: each
## enemy is spawned, chases and attacks on its own timing. Lappland stands
## still for the first half of each enemy's turn (so hits land and can be
## seen), then strafes sideways (so dodging against the body cues is shown).
## Run with Movie Maker (needs a real renderer, so no --headless):
##   godot --path downfall-godot --script res://tests/record_enemy_attacks.gd
##        --rendering-method gl_compatibility --audio-driver Dummy
##        --resolution 1280x720 --fixed-fps 30 --write-movie <dir>/frame.png

const TURN_FRAMES := 120  # 4 s per enemy at 30 fps
const ROSTER := {
	"mine": [["thug", 2.6], ["slug", 2.4], ["crossbow", 8.0]],
	"city": [["brawler", 3.0], ["crossbow_leader", 8.0]],
	"snow": [["ice_warrior", 3.2], ["ice_hunter", 11.0]],
}

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
	for region in ROSTER:
		await game.start_contract(region)
		game._clear_field()
		await step(2)
		var player := game.player
		player.max_hp = 500  # the clip is about reading attacks; keep her alive
		player.hp = 500
		var origin := ContinuousWorldMap.ENTRY_POSITION
		for entry in ROSTER[region]:
			player.teleport(origin)
			await step(3)
			var enemy := game._spawn_enemy(origin + Vector3(entry[1], 0, 0), false, entry[0] in ["crossbow", "crossbow_leader", "ice_hunter"], entry[0])
			enemy.health = 10000
			enemy.begin_chase()
			for i in range(TURN_FRAMES):
				if i == TURN_FRAMES / 2: player.set_move_target(origin + Vector3(0, 0, 3))
				elif i == TURN_FRAMES * 3 / 4: player.set_move_target(origin + Vector3(0, 0, -3))
				await step(1)
			if is_instance_valid(enemy): enemy.take_hit(100000)
			player.clear_move_target()
			await step(6)
		game.settle(true)
		await step(5)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
