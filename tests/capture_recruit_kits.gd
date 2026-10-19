extends SceneTree
## 干员寻访 R2 on screen: the departure card and the training screen with all
## nine operators, then each recruit's basic attack and Space skill against a
## small pack on the mine floor. ../evidence/kits-<shot>.png.
var rig: Node
var game: GameManager
const RECRUITS := ["hellagur", "hoshiguma", "typhon", "rosa", "lin", "santalla", "texas"]
func _initialize() -> void: call_deferred("run")
func step(count: int = 8) -> void:
	for i in range(count): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func save(label: String) -> void:
	await step(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/kits-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	for id in RECRUITS: game.base.recruit(id)
	game.choose_operator("hellagur")
	game.menu.show_departure("mine")
	await step(3)
	await save("departure")
	game.close_modal()
	game.menu.show_training()
	await step(3)
	await save("training-hellagur")
	game.close_modal()
	for id in RECRUITS:
		game.show_base()
		await step(3)
		game.choose_operator(id)
		await game.start_contract("mine")
		game._clear_field()
		await step(2)
		var p := game.player
		var origin := ContinuousWorldMap.ENTRY_POSITION
		p.teleport(origin)
		game.camera.size = 20
		game.camera.global_position = origin + GameManager.CAMERA_OFFSET * (20.0 / 24.0)
		var enemies: Array[Enemy] = []
		var ranged: bool = p.kit.ranged()
		var ahead := 5.0 if ranged else 2.0
		for offset in [Vector3(ahead, 0, 0), Vector3(ahead + 1.2, 0, 1.0), Vector3(ahead + 1.2, 0, -1.0)]:
			game._spawn_enemy(origin + offset, false, false)
			var e := game.get_child(game.get_child_count() - 1) as Enemy
			e.max_health = 100000
			e.health = 100000
			e.set_physics_process(false)
			e.global_position = origin + offset
			enemies.append(e)
		p.set_physics_process(false)
		p._attack_cooldown = 0
		p.attack(enemies[0])
		for i in range(5): await physics_frame
		await save(id + "-attack")
		p._attack_cooldown = 0
		p.hitstop_remaining = 0
		p.kit.cooldown = 0
		p.cast_skill(enemies[0].global_position)
		p._attack_cooldown = 0
		p.attack(enemies[0])
		for i in range(14): await physics_frame
		await save(id + "-skill")
		p.set_physics_process(true)
		game.settle(false)
		await step(4)
	print("CAPTURE_RECRUIT_KITS done")
	quit()
