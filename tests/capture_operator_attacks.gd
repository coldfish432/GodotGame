extends SceneTree
## Each operator's three basic attacks on screen (用户 2026-10-20: 干员之间攻击
## 模组和特效做出差异): 赫拉格's thrusts with the third running through a line,
## 林's great third array, and everyone else's own shapes, shot a few frames
## after each swing. ../evidence/opfx-<id>-<stage>.png.
var rig: Node
var game: GameManager
const OPERATORS := ["lappland", "amiya_guard", "hellagur", "hoshiguma", "texas", "lin", "santalla", "typhon", "rosa"]
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
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/opfx-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	for id in OPERATORS:
		if not id in game.base.roster: game.base.recruit(id)
	var only := OS.get_environment("DOWNFALL_OPS")
	for id in OPERATORS:
		if not only.is_empty() and not id in only.split(","): continue
		game.show_base()
		await step(3)
		game.choose_operator(id)
		await game.start_contract("mine")
		game._clear_field()
		await step(2)
		var p := game.player
		var origin := ContinuousWorldMap.ENTRY_POSITION
		p.teleport(origin)
		game.camera.size = 14
		game.camera.global_position = origin + Vector3(2.5, 0, 0) + GameManager.CAMERA_OFFSET * (14.0 / 24.0)
		var ranged: bool = p.kit != null and p.kit.ranged()
		var first := 4.5 if ranged else 1.6
		var spots: Array[Vector3] = []
		if id == "hellagur":
			for i in range(5): spots.append(Vector3(first + 0.8 * i, 0, 0.15 * (i % 2)))
		else:
			spots = [Vector3(first, 0, 0), Vector3(first + 1.0, 0, 0.9), Vector3(first + 1.0, 0, -0.9), Vector3(first + 2.6, 0, 0.3)]
		var enemies: Array[Enemy] = []
		for offset in spots:
			game._spawn_enemy(origin + offset, false, false)
			var e := game.get_child(game.get_child_count() - 1) as Enemy
			e.max_health = 100000
			e.health = 100000
			e.set_physics_process(false)
			e.global_position = origin + offset
			enemies.append(e)
		p.set_physics_process(false)
		for stage in range(3):
			p.combo_step = stage
			p._attack_cooldown = 0
			p.hitstop_remaining = 0
			p.attack(enemies[0])
			for i in range(3): await physics_frame
			await save("%s-%d" % [id, stage + 1])
			for i in range(30): await physics_frame
		if p.has_skill():
			# Her Space a moment after it goes off (日晷's dial, a phase, an array).
			p.hitstop_remaining = 0
			if p.kit != null: p.kit.cooldown = 0.0
			p.cast_skill(enemies[0].global_position)
			for i in range(40): await physics_frame
			await save("%s-skill" % id)
		p.set_physics_process(true)
		game.settle(false)
		await step(4)
	print("CAPTURE_OPERATOR_ATTACKS done")
	quit()
