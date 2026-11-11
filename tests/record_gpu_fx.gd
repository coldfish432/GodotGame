extends SceneTree
## Not a test — real-renderer clips of GPU粒子特效推广策划案 v0.6, one segment a
## run (GPUFX_REC=<segment>), each labelled in the corner. Prints
## "MARK <frame> <label>" at every beat so stills can be cut.
##   hits     the nine operators' hit sparks (melee / ranged / arts, a crit)
##   bursts   BossVfx.burst on the GPU (sparks, embers, dust, chips, a ring)
##   hazard   a bottle shattering, its fire dying away, a fused blast
##   snow     tracks, the cold's stages easing in, a fire's melt, the blizzard
##   rain     叙拉古 rain: puddles filling, lamps in them, rain rings, splashes
##   lower    龙门下城: wet streets and the lamps in their puddles
##   status   buff / debuff rings on her and on enemies, the status bar
##   post     the full-screen status look: contamination, debt, low life
## Run with Movie Maker (30 fps, 1280×720):
##   set GPUFX_REC=hits
##   godot --path downfall-godot --script res://tests/record_gpu_fx.gd --audio-driver Dummy
##        --resolution 1280x720 --fixed-fps 30 --write-movie <dir>/frame.png

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

func say(text: String) -> void:
	caption.text = text
	print("MARK %d %s" % [Engine.get_frames_drawn(), text])

## A ground offset in screen terms: `right` metres to screen-right, `down` towards the bottom.
func screen(right: float, down: float) -> Vector3:
	var r := game.camera.global_basis.x
	r.y = 0.0
	var d := game.camera.global_basis.z
	d.y = 0.0
	return r.normalized() * right + d.normalized() * down

func dummy(offset: Vector3, life: float = 1e9) -> Enemy:
	var p := game.player
	var at := game.world_map.nearest_walkable(p.global_position + offset)
	var e := game._spawn_enemy(at, false, false)
	e.global_position = at
	e.max_health = life
	e.health = life
	e.set_physics_process(false)
	return e

func run() -> void:
	var segment := OS.get_environment("GPUFX_REC")
	if segment.is_empty(): segment = "hits"
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 2026
	for id in [Operators.LAPPLAND, Operators.AMIYA_GUARD]: game.base.recruit(id)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(24, 92)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	caption.add_theme_font_override("font", AK.cn())
	layer.add_child(caption)
	match segment:
		"hits": await hits()
		"bursts": await bursts()
		"hazard": await hazard()
		"snow": await snow()
		"tracks": await tracks()
		"rain": await rain()
		"lower": await lower()
		"status": await status()
		"post": await post()
	caption.text = ""
	await step(4)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()

func enter(region: String) -> void:
	await game.start_contract(region)
	await step(20)
	game.player.invulnerable = true
	game._clear_field()
	await step(5)

const NAMES := {"lappland": "拉普兰德", "amiya_guard": "阿米娅·剑兔", "hellagur": "赫拉格", "hoshiguma": "星熊", "texas": "德克萨斯", "typhon": "提丰", "rosa": "蔷薇", "lin": "林", "santalla": "寒檀"}

func hits() -> void:
	await enter("mine")
	game.camera.size = 12
	var p := game.player
	var target := dummy(screen(2.2, 0.0))
	await step(10)
	for id in ["lappland", "amiya_guard", "hellagur", "hoshiguma", "texas", "typhon", "rosa", "lin", "santalla"]:
		p.set_operator(id)
		await step(6)
		var kind := "arts" if id in ["lin", "santalla", "amiya_guard"] else "phys"
		say("命中火花：%s（%s）" % [NAMES[id], {"melee": "近战", "ranged": "远程", "arts": "法术"}[OperatorVfx.hit_style(id, kind)]])
		for i in range(5):
			p._deal(target, 10.0, kind, i == 4, 0.0, true)
			await step(9)
		await step(10)

func bursts() -> void:
	await enter("mine")
	game.camera.size = 14
	var p := game.player
	var at := p.global_position + screen(3.0, 0.0)
	var fx := BossVfx.make(game, Vector3(at.x, game.ground_y(at) + 0.02, at.z))
	say("BossVfx.burst（GPU）：火花")
	fx.sparks(Vector3.UP * 0.4, Color(1, 0.5, 0.2), Color(1, 1, 0.8), 30, 5.0)
	await step(30)
	say("BossVfx.burst（GPU）：余烬")
	fx = BossVfx.make(game, Vector3(at.x, game.ground_y(at) + 0.02, at.z))
	fx.embers(Vector3.UP * 0.2, Color(1, 0.45, 0.15), Color(1, 0.9, 0.6), 30, 1.2)
	await step(40)
	say("BossVfx.burst（GPU）：尘雾")
	fx = BossVfx.make(game, Vector3(at.x, game.ground_y(at) + 0.02, at.z))
	fx.dust(Vector3.UP * 0.2, Color(0.6, 0.55, 0.5), 16, 0.8)
	await step(40)
	say("BossVfx.burst（GPU）：碎石")
	fx = BossVfx.make(game, Vector3(at.x, game.ground_y(at) + 0.02, at.z))
	fx.chips(Vector3.UP * 0.1, 26, 0.6, Color(0.55, 0.5, 0.45), 4.0)
	await step(40)
	say("BossVfx.burst（GPU）：人物脚下自动外移成环")
	var near := BossVfx.make(game, Vector3(p.global_position.x, game.ground_y(p.global_position) + 0.02, p.global_position.z))
	near.burst({"at": Vector3.UP * 0.3, "amount": 40, "time": 0.8, "speed": [1.0, 2.5], "radius": 0.5, "additive": true, "colours": [Color(0.8, 0.9, 1), Color(0.4, 0.6, 1), Color(0.2, 0.3, 1, 0)]})
	await step(50)

func hazard() -> void:
	await enter("city")
	game.camera.size = 13
	var p := game.player
	var at := game.world_map.nearest_walkable(p.global_position + screen(3.0, 0.5))
	say("燃烧瓶碎裂：玻璃碎片 + 火焰（湍流）")
	var bottle := Molotov.new()
	bottle.game = game
	bottle.start = at + screen(3.0, -2.0) + Vector3.UP * 1.5
	bottle.target = at
	bottle.fire_time = 3.0
	game.add_child(bottle)
	await step(30)
	await step(60)
	say("火面：粒子随剩余时间变少，最后 1 秒熄灭")
	await step(40)
	say("引信危险区：微粒向内收，引爆时爆发")
	game.spawn_hazard(game.world_map.nearest_walkable(p.global_position + screen(2.5, 2.5)), 1.6, 1.2, 0.0, 0.0, "arts", false, null)
	await step(70)

func snow() -> void:
	await enter("snow")
	game.camera.size = 18
	var p := game.player
	var w := game.field_weather
	game.features.values.cold = 0.0
	w.snap()
	say("萨米：寒冷 0，薄雪；走过留下拖痕、踢起雪粒")
	# Along the main path (open ground): her, and three enemies a little behind.
	var path: PackedVector2Array = game.world_map.main_path
	var route: Array = []
	for i in range(mini(path.size(), 6)):
		route.append(game.world_map.nearest_walkable(Vector3(path[i].x, 0, path[i].y)))
	var walkers: Array = []
	for i in range(3): walkers.append(dummy(Vector3.ZERO))
	var steps := 150
	for k in range(steps):
		var t := float(k) / float(steps - 1) * 2.0
		var here := _along(route, t)
		var ahead := _along(route, minf(t + 0.02, 2.0))
		p.velocity = (ahead - here) * 30.0
		p.global_position = here + Vector3.UP * 0.7
		for i in range(walkers.size()):
			(walkers[i] as Enemy).global_position = game.world_map.nearest_walkable(_along(route, maxf(t - 0.12 * (i + 1), 0.0)) + screen(0.8 * (i - 1), 0.0))
		await step(1)
	p.velocity = Vector3.ZERO
	await step(40)
	say("寒冷 0 → 60（失温）：积雪约 5 秒渐变变厚")
	game.features.values.cold = 60.0
	await step(200)
	var fires: Array = game.map_features.fires
	if not fires.is_empty():
		say("点燃火堆：周围融雪")
		fires[0].feed(120.0)
		p.global_position = game.world_map.nearest_walkable(fires[0].global_position + Vector3(3.5, 0, 0)) + Vector3.UP * 0.7
		await step(90)
	say("寒冷 92：暴风雪（轻微遮盖）")
	game.features.values.cold = 92.0
	await step(220)
	say("寒冷 100：暴风雪（中等遮盖）+ 阵风")
	game.features.values.cold = 100.0
	w._gust_wait = 2.0
	await step(260)
	say("寒冷降到 80：暴风雪退去（渐变）")
	game.features.values.cold = 80.0
	await step(200)

func rain() -> void:
	ContinuousWorldMap.force_weather = "rain"
	await enter("siracusa")
	ContinuousWorldMap.force_weather = ""
	game.camera.size = 16
	var w := game.field_weather
	say("叙拉古雨夜：积水 0.4，雨点落地溅起水花")
	await step(90)
	say("积水涨满（加速演示，实际 90 秒）+ 涟漪 + 路灯倒影")
	for i in range(90):
		w.puddle_fill = minf(1.0, w.puddle_fill + 0.0067)
		await step(1)
	var p := game.player
	var start := p.global_position
	say("走动：路灯倒影随视线移动")
	for i in range(120):
		p.global_position = game.world_map.nearest_walkable(start + screen(0.08 * i, 0.0)) + Vector3.UP * 0.7
		await step(1)
	await step(30)

func lower() -> void:
	ContinuousWorldMap.force_city_variant = "lower"
	await enter("city")
	ContinuousWorldMap.force_city_variant = ""
	game.camera.size = 16
	say("龙门下城：常湿地面，积水里有霓虹/路灯倒影")
	var p := game.player
	var start := p.global_position
	for i in range(150):
		p.global_position = game.world_map.nearest_walkable(start + screen(0.06 * i, 0.02 * i)) + Vector3.UP * 0.7
		await step(1)
	await step(30)

func status() -> void:
	await enter("mine")
	game.camera.size = 11
	var p := game.player
	var a := dummy(screen(2.6, 0.0))
	var b := dummy(screen(-2.6, 0.3))
	var c := dummy(screen(0.4, 2.4))
	await step(10)
	say("增益：竖线环绕、向上，尖端朝上")
	p.add_hex("potion_F", {"atk": 0.2, "aspd": 0.1}, 20.0)
	await step(70)
	say("再加一个增益：仍只有一层")
	p.add_hex("potion_G", {"move": 0.25, "stamina": 0.6}, 12.0)
	await step(50)
	say("减益：竖线向下，尖端朝下；增减益同时显示")
	p.add_hex("boss_shred", {"def": -0.3}, 6.0)
	await step(80)
	say("敌人：加速（上）、减速（下）、眩晕+加速（上下）")
	a.apply_status("haste", 20.0, 0.3)
	b.apply_status("slow", 20.0, 0.3)
	c.stun_timer = 20.0
	c.apply_status("haste", 20.0, 0.3)
	await step(90)
	say("快捷栏上方图标栏：按出现先后，时钟扇形计时；悬停显示效果")
	game.features.values.contamination = 65.0
	var sb: StatusBar = game._hud.status_bar
	for i in range(4):
		sb.force_hover = i
		await step(35)
	sb.force_hover = -1
	game.features.values.contamination = 0.0
	await step(20)

func post() -> void:
	await enter("mine")
	game.camera.size = 18
	say("全屏：源石污染 30（淡）")
	game.features.values.contamination = 30.0
	await step(60)
	say("全屏：源石污染 65（中度）")
	game.features.values.contamination = 65.0
	await step(70)
	say("全屏：源石污染 95（重度）")
	game.features.values.contamination = 95.0
	await step(70)
	game.features.values.contamination = 0.0
	say("全屏：低血量")
	game.player.invulnerable = true
	var hp := game.player.hp
	for i in range(80):
		game.player.hp = game.player.max_hp * 0.08
		await step(1)
	game.player.hp = hp
	await step(40)
	game.settle(true)
	await step(5)
	await enter("siracusa")
	say("全屏：血债 70（仇家，心跳脉动）")
	game.features.values.debt = 70.0
	await step(110)
	say("全屏：血债 95（清算，心跳更快）")
	game.features.values.debt = 95.0
	await step(110)

## A point `t` along a list of route points (t 0 the first, 1 the second, …).
func _along(route: Array, t: float) -> Vector3:
	if route.is_empty(): return game.player.global_position
	var i := clampi(int(floor(t)), 0, route.size() - 2) if route.size() > 1 else 0
	if route.size() == 1: return route[0]
	var f := clampf(t - i, 0.0, 1.0)
	return game.world_map.nearest_walkable((route[i] as Vector3).lerp(route[i + 1], f))

## A short look at the tracks alone (cold 60, so the snow lies deep).
func tracks() -> void:
	await enter("snow")
	game.camera.size = 12
	game.features.values.cold = 60.0
	game.field_weather.snap()
	var p := game.player
	var path: PackedVector2Array = game.world_map.main_path
	var route: Array = []
	for i in range(mini(path.size(), 3)): route.append(game.world_map.nearest_walkable(Vector3(path[i].x, 0, path[i].y)))
	say("拖痕：走过的地方雪被压下")
	for k in range(90):
		p.global_position = _along(route, float(k) / 89.0 * 0.6) + Vector3.UP * 0.7
		await step(1)
	await step(30)
