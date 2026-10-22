extends SceneTree
## Not a test — a real-time clip of one operator's attack effects (用户
## 2026-10-20: 给角色也做攻击特效): a three-hit combo on a small still pack,
## then her Space skill, then another combo. Prints "MARK <frame> <what>".
## OP_REC=<operator id>, e.g. hellagur. Run with Movie Maker:
##   set OP_REC=hellagur
##   godot --path downfall-godot --script res://tests/record_operator_fx.gd
##        --audio-driver Dummy --resolution 1280x720 --fixed-fps 30
##        --write-movie <dir>/frame.png
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
func mark(what: String) -> void:
	print("MARK %d %s land" % [Engine.get_frames_drawn(), what])

## `gap` frames between swings (赫拉格's heavy blade gets more).
var gap := 14

func combo(p: Player, target: Enemy, label: String, swings: int = 3) -> void:
	for i in range(swings):
		p._attack_cooldown = 0
		p.hitstop_remaining = 0
		p.attack(target)
		mark("%s%d" % [label, i + 1])
		await step(gap)

func run() -> void:
	var id := OS.get_environment("OP_REC")
	if id == "": id = "lappland"
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	for other in Operators.ORDER: game.base.recruit(other)
	game.choose_operator(id)
	await game.start_contract("mine")
	game._clear_field()
	await step(2)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(440, 44)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	caption.add_theme_font_override("font", AK.cn())
	layer.add_child(caption)
	caption.text = Operators.display_name(id)
	var p := game.player
	p.invulnerable = true
	var origin := ContinuousWorldMap.ENTRY_POSITION
	p.teleport(origin)
	game.camera.size = 16
	game.camera.global_position = origin + Vector3(2.0, 0, 0) + GameManager.CAMERA_OFFSET * (16.0 / 24.0)
	var ranged: bool = p.kit != null and p.kit.ranged()
	var ahead := 5.0 if ranged else 1.8
	var enemies: Array[Enemy] = []
	var spots := [Vector3(ahead, 0, 0), Vector3(ahead + 1.4, 0, 1.2), Vector3(ahead + 1.4, 0, -1.2)]
	# 赫拉格's third thrust runs through a line: five in a row, the fifth past its four.
	if id == "hellagur":
		spots = []
		for i in range(5): spots.append(Vector3(1.6 + 0.8 * i, 0, 0.15 * (i % 2)))
		gap = 22
	for offset in spots:
		var e := game._spawn_enemy(origin + offset, false, false)
		e.max_health = 1e9
		e.health = 1e9
		e.set_physics_process(false)
		enemies.append(e)
	# Her physics stays on: it counts the hitstop down, and the pose waits on it.
	await step(10)
	# 拉普兰德: three hits fill 剑气, the fourth throws it (and silences).
	await combo(p, enemies[0], "atk", 4 if id == "lappland" else 3)
	if id == "hellagur":
		await step(20)
		await combo(p, enemies[0], "atk2")
	p.hitstop_remaining = 0
	if p.kit != null: p.kit.cooldown = 0
	p.shadow_cooldown = 0.0
	p.set_physics_process(true)
	p.cast_skill(enemies[0].global_position)
	mark("skill")
	if id == "lappland":
		# Fight on under 日晷 until its hand has gone round.
		# Player ticks the kit, so her physics stays on for the countdown.
		await step(20)
		var kit := p.kit as LapplandKit
		var rounds := 0
		while kit.timer > 0.0 and rounds < 12:
			p.hp = p.max_hp
			await combo(p, enemies[0], "dial")
			await step(10)
			rounds += 1
		await step(30)
	else:
		for i in range(80):
			p.hp = p.max_hp
			await step(1)
		await combo(p, enemies[0], "after")
	await step(20)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
