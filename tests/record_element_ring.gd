extends SceneTree
## Not a test — a real-renderer clip of 元素反应策划案 v0.2: the one 损伤 ring
## filling by element, a pure burst, its 4 s cooldown, two-element reactions,
## a three-element mix and the ring's decay. No captions (用户: 不要文字);
## prints "MARK <frame> <beat>" so the beats can be found.
## Run with Movie Maker (30 fps, 1280×720):
##   godot --path downfall-godot --script res://tests/record_element_ring.gd --audio-driver Dummy
##        --resolution 1280x720 --fixed-fps 30 --write-movie <dir>/frame.png

var rig: Node
var game: GameManager
var dummies: Array[Enemy] = []

func _initialize() -> void: call_deferred("run")

## Physics on the dummies is off (they would walk and fight), so their rings
## are ticked here, once a drawn frame (--fixed-fps 30).
const DT := 1.0 / 30.0
func step(count: int = 1) -> void:
	for i in range(count):
		await process_frame
		for e in dummies:
			if is_instance_valid(e) and not e._dead:
				e._tick_elements(DT)
				e.stun_timer = maxf(0.0, e.stun_timer - DT)

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func mark(text: String) -> void:
	print("MARK %d %s" % [Engine.get_frames_drawn(), text])

func screen(right: float, down: float) -> Vector3:
	var r := game.camera.global_basis.x
	r.y = 0.0
	var d := game.camera.global_basis.z
	d.y = 0.0
	return r.normalized() * right + d.normalized() * down

func dummy(offset: Vector3) -> Enemy:
	var p := game.player
	var at := game.world_map.nearest_walkable(p.global_position + offset)
	var e := game._spawn_enemy(at, false, false, "thug")
	e.global_position = at
	e.max_health = 2000.0
	e.health = 2000.0
	e.set_physics_process(false)
	dummies.append(e)
	return e

## Her elemental 附加 for the next hits (kind → share), everything else off.
func gear(adds: Dictionary) -> void:
	var p := game.player
	for kind in Elements.KINDS:
		p.stats[Elements.ADD_KEY[kind]] = float(adds.get(kind, 0.0))
		p.stats[Elements.CONV_KEY[kind]] = 0.0

## `count` hits on `e`, `gap` frames apart; its life is topped up so it
## never dies on camera.
func hits(e: Enemy, count: int, raw: float, gap: int = 14) -> void:
	for i in range(count):
		game.player._deal(e, raw, "phys", false)
		e.health = e.max_health
		await step(gap)

func run() -> void:
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["auto_potion"] = false
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 2026
	await game.start_contract("mine")
	await step(20)
	var p := game.player
	p.invulnerable = true
	p.set_physics_process(false)
	game._clear_field()
	await step(5)
	game.camera.size = 8
	var a := dummy(screen(-2.6, -2.2))
	var b := dummy(screen(0.0, -2.6))
	var c := dummy(screen(2.6, -2.2))
	await step(20)

	mark("1 pure 寒冷 fills, bursts (freeze), 4 s cooldown, fills again")
	gear({"cold": 0.5})
	await hits(a, 7, 40.0)
	mark("1b cooldown")
	await hits(a, 4, 40.0, 30)
	await hits(a, 4, 40.0)
	await step(30)

	mark("2 灼燃 + 寒冷 on one ring -> 骤裂")
	gear({"burn": 0.35, "cold": 0.25})
	await hits(b, 9, 40.0)
	await step(40)

	mark("3 寒冷 + 神经 -> 僵直 (freeze)")
	gear({"cold": 0.25, "nerve": 0.35})
	await hits(c, 9, 40.0)
	await step(40)

	mark("4 灼燃 + 侵蚀 -> 源石爆燃 hits the others within 3 m")
	gear({"burn": 0.3, "corr": 0.55})
	await hits(b, 10, 40.0)
	await step(40)

	mark("5 three elements: 灼燃 / 寒冷 / 神经, the two leading react")
	gear({"burn": 0.25, "cold": 0.18, "nerve": 0.18})
	await hits(a, 9, 40.0)
	await step(40)

	mark("6 a part-filled ring decays as a whole after 3 s")
	gear({"cold": 0.2, "nerve": 0.25})
	await hits(c, 4, 40.0)
	await step(30 * 7)
	mark("end")
	await step(10)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
