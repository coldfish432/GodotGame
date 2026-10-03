extends SceneTree

## Not a test — a real-time combat clip for judging the attack animation and
## effects in motion, which still screenshots cannot show. Nothing is frozen:
## enemies chase and telegraph, the player attacks through Player.attack() on
## cooldown, the sword wave charges from real hits, and Shift is pressed
## through the input system. Enemies are placed on all four sides so every
## authored direction (and the mirrored east side) gets played.
## Run with Movie Maker (needs a real renderer, so no --headless):
##   godot --path downfall-godot --script res://tests/record_lappland.gd
##        --rendering-method gl_compatibility --audio-driver Dummy
##        --resolution 1280x720 --fixed-fps 30 --write-movie <dir>/frame.png
## Optional user arg after "--": region id (mine, city or snow; default mine).

const SIDES := [Vector3(0, 0, 2.6), Vector3(0, 0, -2.6), Vector3(2.6, 0, 0), Vector3(-2.6, 0, 0)]
const FRAMES_PER_SIDE := 75  # 2.5 s at 30 fps
const DASH_AT := [50, 125, 200, 275]

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
	var args := OS.get_cmdline_user_args()
	var region: String = args[0] if args.size() > 0 else "mine"
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	await game.start_contract(region)
	game._clear_field()
	await step(2)
	var player := game.player
	var weapon := Item.create("幼狼之牙演示剑", Item.Category.WEAPON, 2, 1)
	weapon.rarity = 1
	weapon.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	player.equip(weapon)
	player.max_hp = 200  # the clip is about visuals; keep her alive through it
	player.hp = 200
	var origin := ContinuousWorldMap.ENTRY_POSITION
	player.teleport(origin)
	await step(5)
	var frame := 0
	for side in SIDES:
		game._spawn_enemy(player.global_position + side, false, false)
		var enemy := game.get_child(game.get_child_count() - 1) as Enemy
		enemy.health = 30
		enemy.begin_chase()
		for i in range(FRAMES_PER_SIDE):
			if frame in DASH_AT: Input.action_press("dash")
			elif frame - 1 in DASH_AT: Input.action_release("dash")
			if is_instance_valid(enemy) and not enemy._dead:
				if player.is_target_in_range(enemy):
					player.clear_move_target()
					player.attack(enemy)
				else:
					player.set_move_target(enemy.global_position)
			await step(1)
			frame += 1
		if is_instance_valid(enemy) and not enemy._dead:
			enemy.take_hit(10000)
		await step(3)
	await step(15)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
