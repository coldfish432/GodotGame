extends SceneTree
## A hands-on bench for the bosses (用户 2026-11-05: 写直接进 boss 房的测试我亲自测,
## 附上对应等级的装备). Opens the real game in a window straight onto a boss
## (or warden) floor, the operator levelled and dressed for that depth:
## - level: the balance model has her maxed (精英 2 Lv90) about floor 60
##   (复利数值改造清单 J); the bench scales her career level-ups linearly by
##   depth up to there (floor 20 ≈ 精英 1 Lv18, 40 ≈ 精英 2 Lv14, 60+ 精英 2 Lv90);
## - gear: a full eight-slot set rolled for that floor and region, at the
##   rarity her stage may wear (精英 0 blue, 精英 1 purple, 精英 2 orange),
##   attribute points spent to meet each piece's need; the rest left unspent,
##   skill points unspent too (the C window spends them);
## - potions: two stacks in the pack.
## She stands just outside the arena: walk in for the intro. Nothing is saved.
## Not in run_all. Start it with tools/play_boss.ps1, or by hand:
##   set DOWNFALL_PLAY_BOSS=mine:20            (region:floor[:operator])
##   godot --path downfall-godot --script res://tests/play_boss.gd
##
## Keys while it runs (also in the PRTS log):
##   F5   fight again (back outside the arena, boss whole, her whole)
##   Shift+F5  the same, with the first-meeting intro again
##   F6   next region, same floor      ] / [ (or F9 / F10)  floor +20 / −20 (re-levelled, re-dressed)
##   F7   she cannot be hurt (on/off)  F8  the boss to its next phase
##   F11  her life and potions full     F12  the boss falls

const REGIONS := ["mine", "city", "snow", "siracusa"]
## Her career level-ups (all stages) are full at this floor.
const MAXED_AT := 60.0
const RARITY_BY_ELITE := [Item.BLUE, Item.PURPLE, Item.ORANGE]

var game: GameManager
var region := "mine"
var floor := 20
var operator := ""
var _held := {}
var _busy := false
var _god := false
## The bench's own strip at the top of the screen (用户 2026-11-05: 把快捷键附到测试画面上方).
var _keys: Label

func _initialize() -> void: call_deferred("run")

func step(count: int = 10) -> void:
	for i in range(count): await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func run() -> void:
	var spec := OS.get_environment("DOWNFALL_PLAY_BOSS").split(":", false)
	if spec.size() > 0 and REGIONS.has(spec[0]): region = spec[0]
	if spec.size() > 1: floor = maxi(10, int(spec[1]) / 10 * 10)
	if spec.size() > 2: operator = spec[2]
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	_build_keys()
	# Never write the player's save from the bench.
	game.save_enabled = false
	SystemScreens.settings["tutorial_tips"] = false
	if is_instance_valid(game.menu): game.menu.visible = false
	game.close_modal()
	if operator.is_empty() or not Operators.DATA.has(operator): operator = Operators.AMIYA_GUARD
	# A fresh base deploys only its starting roster: put her on it (阿米娅 too).
	if not operator in game.base.deployable():
		game.base.recruit(operator)
		if not operator in game.base.roster: game.base.roster.append(operator)
	await _go(false)
	if OS.get_environment("DOWNFALL_PLAY_BOSS_CHECK") == "floors":
		floor += 20
		await _go(false)
		print("CHECK floor change: floor=%d boss=%s tier=%d" % [game.floor_number, _figure().figure_id if _figure() else "none", _figure().tier if _figure() else 0])
		floor = maxi(10, floor - 20)
		await _go(false)
		print("CHECK floor back: floor=%d boss=%s tier=%d" % [game.floor_number, _figure().figure_id if _figure() else "none", _figure().tier if _figure() else 0])
		quit()
		return
	if OS.get_environment("DOWNFALL_PLAY_BOSS_CHECK") != "": await _self_check()

## DOWNFALL_PLAY_BOSS_CHECK=1: report what was set up, walk in, then quit.
func _self_check() -> void:
	var p := game.base.progress_for(operator)
	var worn := game.player.equipped.values()
	var figure := _figure()
	var d := Vector2(game.player.global_position.x - game.world_map.arena_centre.x, game.player.global_position.z - game.world_map.arena_centre.z).length()
	print("CHECK player_operator=%s sprite=%s" % [game.player.operator_id, game.player._sprite.character])
	print("CHECK region=%s floor=%d op=%s elite=%d level=%d attr_left=%d skill_left=%d worn=%d rarities=%s hp=%d atk=%d" % [region, floor, operator, p.elite, p.level, p.attribute_points, p.skill_points,
		worn.size(), str(worn.map(func(i): return i.rarity)), roundi(game.player.max_hp), roundi(game.player.f("atk") if game.player.has_method("f") else 0.0)])
	print("CHECK boss=%s engaged=%s her_from_centre=%.1f potions=%d" % [figure.figure_id if figure else "none", figure.engaged if figure else false, d,
		game.inventory.items.filter(func(i): return i.potion_type != "").size()])
	await step(20)
	root.get_texture().get_image().save_png("res://logs/play_boss_check_before.png")
	if figure != null:
		game.player.teleport(game.world_map.nearest_walkable(figure.global_position + Vector3(4, 0, 0)) + Vector3.UP * 0.7)
		await step(90)
		var dd := Vector2(game.player.global_position.x - game.world_map.arena_centre.x, game.player.global_position.z - game.world_map.arena_centre.z).length()
		print("CHECK teleported to %.1f from centre; los=%s; boss at %.1f from centre" % [dd, game.line_of_sight(figure.global_position, game.player.global_position),
			Vector2(figure.global_position.x - game.world_map.arena_centre.x, figure.global_position.z - game.world_map.arena_centre.z).length()])
		print("CHECK after walking in: engaged=%s show=%s" % [figure.engaged, game.boss_show.playing if is_instance_valid(game.boss_show) else "none"])
		root.get_texture().get_image().save_png("res://logs/play_boss_check_in.png")
	quit()

## Onto the floor, levelled and dressed for it, just outside the arena.
func _go(first_intro: bool) -> void:
	_busy = true
	if not game.in_base:
		game.settle(true)
		await step(20)
	game.close_modal()
	if first_intro: game.base.boss_intro_seen.clear()
	game.choose_operator(operator)
	if game.player.operator_id != operator: game.broadcast("PRTS：换不成 %s，仍是 %s。" % [operator, game.player.operator_id])
	_level_and_dress()
	await game.start_contract(region)
	await step(4)
	game.floor_number = floor - 1
	await game.advance(0)
	# At the door before a frame is drawn, the camera already there (no jump from the floor's start).
	_to_the_door()
	game.camera.global_position = game.camera_target() + game.camera_offset()
	await step(2)
	_potions()
	game.player.invulnerable = _god
	_refresh_keys()
	var what := "Boss" if BossCatalog.is_boss_floor(floor) else "守卫者"
	var p := game.base.progress_for(operator)
	game.broadcast("PRTS：试玩台 · %s 第 %d 层（%s 第 %d 档）· %s Lv%d · 装备 %s。" % [region, floor, what, BossCatalog.boss_tier(floor) if what == "Boss" else (floor + 10) / 20,
		Progression.ELITE_NAMES[p.elite], p.level, ["蓝", "紫", "橙"][p.elite]])
	game.broadcast("PRTS：F5 再打一次（Shift+F5 含首次亮相）· F6 换地区 · ] / [ 层数 ±20 · F7 无敌 · F8 下一阶段 · F11 回满 · F12 击败。")
	_busy = false

## 精英 / level for the depth, points as a career that reached it would have
## them; attributes spent to wear the set, the rest kept.
func _level_and_dress() -> void:
	var p := OperatorProgress.create(operator)
	var steps := roundi(clampf(float(floor) / MAXED_AT, 0.0, 1.0) * float(Progression.levels_before(2) + Progression.LEVEL_CAPS[2] - 1))
	# 精英 0 has LEVEL_CAPS[0] − 1 level-ups, then 精英 1, then 精英 2.
	var elite := 0
	while elite < 2 and steps > Progression.levels_before(elite + 1): elite += 1
	p.elite = elite
	p.level = clampi(steps - Progression.levels_before(elite) + 1, 1, Progression.LEVEL_CAPS[elite])
	p.attribute_points = Progression.level_attribute_points(elite, p.level) + Progression.PROMOTION_ATTRIBUTE_POINTS * elite
	p.skill_points = Progression.level_skill_points(elite, p.level) + Progression.PROMOTION_SKILL_POINTS * elite
	game.base.progress[operator] = p
	# The set: rolled for this floor and region at her stage's rarity.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%s" % [region, floor, operator])
	var pieces: Array[Item] = []
	for category in Item.SLOTS:
		var piece: Item = null
		for attempt in range(12):
			var id := GearCatalog.pick(category, region, floor, "box", "", rng)
			var roll := LootTables.roll_equipment(category, GearCatalog.BASES[id].name, region, floor, int(RARITY_BY_ELITE[elite]), rng)
			if category != Item.Category.WEAPON or GearCatalog.can_wield(operator, roll):
				piece = roll
				break
		if piece != null: pieces.append(piece)
	# Attributes to wear them, most needed first.
	for piece in pieces:
		var req := Progression.requirement(piece)
		if req.is_empty(): continue
		var key := str(req.attribute)
		var short := int(req.value) - p.attribute(key)
		if short > 0 and short <= p.attribute_points:
			p.attributes[key] = p.attribute(key) + short
			p.attribute_points -= short
	var player := game.player
	for category in Item.SLOTS: player.unequip(category)
	var worn := 0
	for piece in pieces:
		if Progression.refusal(piece, p).is_empty():
			player.equip(piece)
			worn += 1
	player._recompute_stats()
	player.hp = player.max_hp
	if worn < pieces.size(): game.broadcast("PRTS：%d 件装备属性不够，没穿上。" % (pieces.size() - worn))

func _potions() -> void:
	for item in game.inventory.items.duplicate():
		if item.potion_type != "": game.inventory.remove(item)
	for i in range(2):
		var flask := BaseCatalog.create_potion("A")
		flask.quantity = flask.max_stack
		game.inventory.try_add(flask)

## Just outside the arena, on the way in.
func _to_the_door() -> void:
	var map := game.world_map
	var centre := map.arena_centre if map.arena_centre != Vector3.INF else game.player.global_position
	var entry := map.arena_entry
	var out := entry - centre
	out.y = 0.0
	out = out.normalized() if out.length_squared() > 0.01 else Vector3.FORWARD
	var at := map.nearest_walkable(entry + out * 3.0)
	if Vector2(at.x - centre.x, at.z - centre.z).length() <= BossCatalog.ARENA_RADIUS + 0.5:
		var start: Vector2 = map.main_path[maxi(0, map.main_path.size() - 4)]
		at = map.nearest_walkable(Vector3(start.x, 0, start.y))
	game.player.teleport(at + Vector3.UP * 0.7)
	game.player.hp = game.player.max_hp
	game.player.invuln_timer = 0.0

func _figure() -> Boss:
	for e in game.get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(e) and not e._dead and e.game == game: return e
	return null

func _build_keys() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.position = Vector2(300, 84)
	back.size = Vector2(680, 62)
	layer.add_child(back)
	_keys = Label.new()
	_keys.position = Vector2(308, 86)
	_keys.size = Vector2(664, 58)
	_keys.add_theme_font_override("font", AK.cn())
	_keys.add_theme_font_size_override("font_size", 13)
	_keys.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_keys)
	_refresh_keys()

func _refresh_keys() -> void:
	if _keys == null: return
	var names := {"mine": "矿区", "city": "龙门", "snow": "萨米", "siracusa": "叙拉古"}
	var what := "Boss" if BossCatalog.is_boss_floor(floor) else "守卫者"
	_keys.text = "试玩台 · %s 第 %d 层（%s）· 无敌 %s
F5 再打一次  Shift+F5 含首次亮相  F6 换地区  ] / [ 层数 ±20  F7 无敌  F8 下一阶段  F11 回满  F12 击败" % [
		names.get(region, region), floor, what, "开" if _god else "关"]

func _pressed(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var was: bool = _held.get(key, false)
	_held[key] = down
	return down and not was

func _process(_delta: float) -> bool:
	if game == null or _busy: return false
	var shift := Input.is_physical_key_pressed(KEY_SHIFT)
	if _pressed(KEY_F5): _go(shift)
	if _pressed(KEY_F6):
		region = REGIONS[(REGIONS.find(region) + 1) % REGIONS.size()]
		_go(false)
	# ] / [ too: on many laptops F9/F10 are the machine's own keys (用户 2026-11-05: f9 f10不起作用).
	if _pressed(KEY_F9) or _pressed(KEY_BRACKETRIGHT):
		floor += 20
		_go(false)
	if _pressed(KEY_F10) or _pressed(KEY_BRACKETLEFT):
		floor = maxi(10, floor - 20)
		_go(false)
	if game.in_base: return false
	if _pressed(KEY_F7):
		_god = not _god
		game.player.invulnerable = _god
		game.broadcast("PRTS：无敌 %s。" % ("开" if _god else "关"))
		_refresh_keys()
	var figure := _figure()
	if _pressed(KEY_F8) and figure != null:
		var marks: Array = figure._marks
		if not marks.is_empty():
			var next := float(marks.max())
			figure.health = figure.max_health * (next + 0.004)
			figure.take_hit(figure.max_health * 0.02, "true")
		elif figure.lives > figure.life:
			figure.take_hit(figure.max_health * 5.0, "true")
		else:
			game.broadcast("PRTS：已经是最后一个阶段。")
	if _pressed(KEY_F11):
		game.player.hp = game.player.max_hp
		_potions()
	if _pressed(KEY_F12) and figure != null:
		figure.staging_left = 0.0
		figure.take_hit(figure.max_health * 50.0, "true")
	return false
