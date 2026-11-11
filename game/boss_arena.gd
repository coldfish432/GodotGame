class_name BossArena
extends Node3D

## A boss floor's arena (Boss战场地策划案_v1_0.md, 用户 2026-10-19): the room
## the map dug for it (ContinuousWorldMap.boss_layout), and on it the gate
## that shuts the way out until the boss falls, the cover its big moves break
## (for good), and the region's device from the original stage: 源石祭坛 and
## 干扰地雷 (7-18), 医疗符文 (CB-10), two fires and the 木裂 totem (萨米),
## the fountain and 叙拉古平民 (IS-10). Numbers are in BossCatalog.
## Props are the Blender pieces (§7, KIT); a box or cylinder stands in for any
## piece that is missing.

## The Blender pieces (tools/blender/kit/build_arena_props.py). Cover models go
## to the region's cover in order; 叙拉古's way out is the family car.
const KIT := "res://art/kit/%s.glb"
const COVER_MODELS := {"mine": ["arena_mine_generator"], "city": ["arena_city_cart"], "snow": ["arena_snow_stump"], "siracusa": ["arena_sira_kiosk", "arena_sira_bench"]}

var game: GameManager
var region := ""
var centre := Vector3.ZERO
var radius := BossCatalog.ARENA_RADIUS
var gate: StaticBody3D
var cover: Array[Dictionary] = []
var mines: Array[Dictionary] = []
var runes: Array[Dictionary] = []
var shrine: Node3D
var shrine_time := 0.0
var _shrine_warned := false
## The ones 爱国者 raised: {node, time, warned} each.
var raised: Array[Dictionary] = []
var totem: Dictionary = {}
var civilians: Array[Enemy] = []

func setup(p_game: GameManager) -> void:
	game = p_game
	region = game.region_id
	var map := game.world_map
	centre = map.arena_centre
	radius = map.arena_radius
	name = "BossArena"
	_build_gate(map.arena_exit)
	var models: Array = COVER_MODELS.get(region, [])
	var list: Array = BossCatalog.ARENAS.get(region, {}).get("cover", [])
	for i in range(list.size()):
		_add_cover(list[i][0], list[i][1], "cover", false, str(models[mini(i, models.size() - 1)]) if not models.is_empty() else "")
	match region:
		"mine": _build_mine()
		"city": _build_city()
		"snow": _build_snow()
		"siracusa": _build_siracusa()
	build_show_props()

func colour() -> Color:
	return BossCatalog.ARENAS.get(region, {}).get("colour", Color.WHITE)

## A point on the floor, `offset` from the centre (+y toward the way out).
func at(offset: Vector2) -> Vector3:
	var p := centre + Vector3(offset.x, 0.0, offset.y)
	p.y = game.ground_y(p)
	return p

## Where summons come in: its mouths on the rim.
func mouths() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for dir in (BossCatalog.ARENAS.get(region, {}).get("mouths", []) as Array):
		out.append(game.world_map.nearest_walkable(at(dir * (radius - 1.5))))
	return out

func inside(point: Vector3, margin: float = 0.0) -> bool:
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= radius + margin

# --- The way out ----------------------------------------------------------------------

## The way out closed (用户 2026-11-05: 门没防住绕开，不要门，直接加空气墙): an
## unseen wall on the arena's rim, tangent at the exit and wider than the
## arena, so nothing gets round it; its red stripes show only as she nears it.
const WALL_HEIGHT := 4.0
const WALL_THICK := 0.6
const WALL_SPAN := 2.4
const WALL_SHADER := preload("res://world/arena_wall.gdshader")
var _wall_mat: ShaderMaterial

func _build_gate(exit: Vector3) -> void:
	gate = StaticBody3D.new()
	gate.name = "ArenaWall"
	gate.collision_layer = 1
	var width := radius * WALL_SPAN
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, WALL_HEIGHT, WALL_THICK)
	shape.shape = box
	gate.add_child(shape)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, WALL_HEIGHT)
	face.mesh = quad
	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = WALL_SHADER
	_wall_mat.set_shader_parameter("height", WALL_HEIGHT)
	face.material_override = _wall_mat
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(face)
	add_child(gate)
	gate.global_position = Vector3(exit.x, game.ground_y(exit) + WALL_HEIGHT * 0.5, exit.z + WALL_THICK)

func _process(_delta: float) -> void:
	if _wall_mat != null and is_instance_valid(game) and is_instance_valid(game.player):
		_wall_mat.set_shader_parameter("her", game.player.global_position)

func exit_open() -> bool:
	return not is_instance_valid(gate)

## The boss is down: the wall goes and the way out is open.
func open_exit() -> void:
	if is_instance_valid(gate):
		var wall := gate
		var mat := _wall_mat
		_wall_mat = null
		# Shown once in full, then it fades away.
		mat.set_shader_parameter("near", 100.0)
		mat.set_shader_parameter("far", 101.0)
		var tween := wall.create_tween()
		tween.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.8)
		tween.tween_callback(wall.queue_free)
		for c in wall.get_children():
			if c is CollisionShape3D: c.set_deferred("disabled", true)
	gate = null

# --- Cover (§3.3) ----------------------------------------------------------------------

func _add_cover(offset: Vector2, size: Vector2, kind: String, unbreakable: bool = false, model_id: String = "") -> Dictionary:
	var body := StaticBody3D.new()
	body.name = "ArenaCover"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, size.x)
	shape.shape = box
	body.add_child(shape)
	var model := _model(model_id)
	if model != null:
		model.position.y = -size.y * 0.5
		model.rotation.y = float(hash(offset)) * 0.37
		body.add_child(model)
	else:
		body.add_child(_mesh_box(box.size, Color("3a3c42").lerp(colour(), 0.15)))
	add_child(body)
	var p := at(offset)
	body.global_position = p + Vector3.UP * size.y * 0.5
	var entry := {"body": body, "at": p, "radius": size.x * 0.6, "kind": kind, "unbreakable": unbreakable}
	cover.append(entry)
	return entry

## Cover the shape `hits` reaches is broken (and stays broken, Q6).
func break_cover(hits: Callable) -> int:
	var broke := 0
	for entry in cover.duplicate():
		if entry.unbreakable or not is_instance_valid(entry.body): continue
		if not hits.call(entry.at, float(entry.radius)): continue
		_shatter(entry)
		broke += 1
	return broke

func _shatter(entry: Dictionary) -> void:
	if is_instance_valid(entry.body):
		EnemyAttackVfx.spawn(game, Vector3(entry.at.x, entry.at.y + 0.1, entry.at.z), Vector3.FORWARD, "crystal_spikes" if region == "mine" else "ground_shock", float(entry.radius) + 0.6)
		entry.body.queue_free()
	cover.erase(entry)
	if entry == totem: _totem_broken()

func standing_cover() -> int:
	return cover.filter(func(e): return is_instance_valid(e.body)).size()

# --- 矿区: 源石祭坛 and 干扰地雷 ----------------------------------------------------------

func _build_mine() -> void:
	shrine = _shrine_node()
	shrine_time = BossCatalog.SHRINE_EVERY
	for offset in BossCatalog.MINES:
		var node := Node3D.new()
		node.name = "InterferenceMine"
		var body := _model("arena_mine_mine")
		if body == null:
			body = _mesh_cylinder(0.35, 0.18, Color("4a4c52"))
			body.position.y = 0.09
		node.add_child(body)
		var lamp := _mesh_box(Vector3(0.14, 0.08, 0.14), Color("6a6a6a"), true)
		lamp.position.y = 0.26
		node.add_child(lamp)
		add_child(node)
		node.global_position = at(offset)
		mines.append({"node": node, "lamp": lamp, "armed": false, "spent": false})
	# After the mines and the cover, so it keeps clear of them.
	_place_shrine()

## An unarmed mine she stands by (E arms it).
func mine_near(point: Vector3) -> Dictionary:
	for mine in mines:
		if mine.spent or mine.armed or not is_instance_valid(mine.node): continue
		if Vector2(point.x - mine.node.global_position.x, point.z - mine.node.global_position.z).length() < 2.0: return mine
	return {}

func arm_mine(mine: Dictionary) -> void:
	mine.armed = true
	(mine.lamp.material_override as StandardMaterial3D).albedo_color = Color("e8463a")
	game.sound.play("charge")

func _tick_mines() -> void:
	for mine in mines:
		if not mine.armed or mine.spent or not is_instance_valid(mine.node): continue
		var p: Vector3 = mine.node.global_position
		var tripped := false
		for e in game.floor_enemies():
			if Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() <= BossCatalog.MINE_TRIGGER:
				tripped = true
				break
		if not tripped: continue
		mine.spent = true
		mine.node.visible = false
		EnemyAttackVfx.spawn(game, p + Vector3.UP * 0.1, Vector3.FORWARD, "ground_shock_big", BossCatalog.MINE_RADIUS)
		game.sound.play("barrier_break")
		# 用户 2026-11-05: 地雷改为眩晕爱国者 — it stuns what it catches, the boss included.
		for e in game.floor_enemies():
			if Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() > BossCatalog.MINE_RADIUS: continue
			if e is Boss: (e as Boss).mine_stun(BossCatalog.MINE_STUN)
			else: e.stun(BossCatalog.MINE_STUN)

func _shrine_node() -> Node3D:
	var node := Node3D.new()
	node.name = "OriginiumShrine"
	var piece := _model("arena_mine_shrine")
	if piece != null:
		node.add_child(piece)
	else:
		var base := _mesh_cylinder(0.9, 0.8, Color("3a2c22"))
		base.position.y = 0.4
		node.add_child(base)
		var crystal := _mesh_box(Vector3(0.6, 1.4, 0.6), Color("ff9a3c"), true)
		crystal.position.y = 1.4
		node.add_child(crystal)
	add_child(node)
	return node

## The stage's shrine somewhere new (用户 2026-11-05: 祭坛位置随机): inside the
## rim, clear of where he waits, her way in, the mines and the cover.
var _shrine_rng := RandomNumberGenerator.new()
func _place_shrine() -> void:
	if not is_instance_valid(shrine): return
	if _shrine_rng.seed == 0 or shrine.global_position == Vector3.ZERO: _shrine_rng.seed = hash([game.floor_number, game.region_id, centre])
	var keep_clear: Array[Vector3] = [centre, game.world_map.arena_entry]
	for mine in mines:
		if is_instance_valid(mine.node): keep_clear.append(mine.node.global_position)
	for c in cover: keep_clear.append(c.at)
	var best := _random_spot(_shrine_rng, keep_clear, BossCatalog.SHRINE_EDGE, BossCatalog.SHRINE_CLEAR, at(BossCatalog.SHRINE_AT))
	shrine.global_position = Vector3(best.x, game.ground_y(best), best.z)

## A walkable spot in the arena, `edge` in from the rim, kept `clear` (or as far as
## it can) from every point of `keep`.
func _random_spot(rng: RandomNumberGenerator, keep: Array[Vector3], edge: float, clear: float, fallback: Vector3) -> Vector3:
	var best := fallback
	var best_gap := -1.0
	for attempt in range(40):
		var a := rng.randf() * TAU
		var d := rng.randf_range(clear, radius - edge)
		var spot := game.world_map.nearest_walkable(centre + Vector3(cos(a), 0.0, sin(a)) * d)
		if not inside(spot, -edge + 1.0): continue
		var gap := 99.0
		for p in keep: gap = minf(gap, Vector2(spot.x - p.x, spot.z - p.z).length())
		if gap >= clear * 0.6: return Vector3(spot.x, game.ground_y(spot), spot.z)
		if gap > best_gap:
			best_gap = gap
			best = spot
	return Vector3(best.x, game.ground_y(best), best.z)

## Every shrine standing: the stage's own, then the raised ones.
func shrines() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if is_instance_valid(shrine): out.append(shrine)
	for entry in raised:
		if is_instance_valid(entry.node): out.append(entry.node)
	return out

## The shrine whose pulse would reach `point` (null when none does).
func shrine_over(point: Vector3) -> Node3D:
	for node in shrines():
		if Vector2(point.x - node.global_position.x, point.z - node.global_position.z).length() <= BossCatalog.SHRINE_RADIUS: return node
	return null

## 爱国者 raises one at `point` (raise_shrine); false at the cap.
func raise_shrine(point: Vector3) -> bool:
	if region != "mine" or raised.size() >= BossCatalog.SHRINE_RAISED_MAX: return false
	var node := _shrine_node()
	node.global_position = Vector3(point.x, game.ground_y(point), point.z)
	BossVfx.shrine_rise(game, node.global_position)
	raised.append({"node": node, "time": BossCatalog.SHRINE_FIRST, "warned": false})
	return true

## He sets one off now (shrine_call): it pulses and its own count starts over.
func fire_shrine(node: Node3D) -> void:
	if not is_instance_valid(node): return
	if node == shrine:
		shrine_time = BossCatalog.SHRINE_EVERY
		_shrine_warned = false
	for entry in raised:
		if entry.node == node:
			entry.time = BossCatalog.SHRINE_EVERY
			entry.warned = false
	_pulse(node.global_position)

func _tick_shrine(delta: float) -> void:
	if not game.boss_fight(): return
	for entry in raised:
		if not is_instance_valid(entry.node): continue
		entry.time = float(entry.time) - delta
		if float(entry.time) <= BossCatalog.SHRINE_WARN and not entry.warned:
			entry.warned = true
			_warn_shrine(entry.node.global_position)
		if float(entry.time) > 0.0: continue
		entry.time = BossCatalog.SHRINE_EVERY
		entry.warned = false
		_pulse(entry.node.global_position)
	if not is_instance_valid(shrine): return
	shrine_time -= delta
	var p := shrine.global_position
	if shrine_time <= BossCatalog.SHRINE_WARN and not _shrine_warned:
		_shrine_warned = true
		_warn_shrine(p)
	if shrine_time > 0.0: return
	shrine_time = BossCatalog.SHRINE_EVERY
	_shrine_warned = false
	_pulse(p)

func _warn_shrine(p: Vector3) -> void:
	var marker := game.spawn_warning_area(p, BossCatalog.SHRINE_RADIUS, BossCatalog.SHRINE_WARN, true)
	marker.hitstop_owner = null

## One pulse of a shrine at `p`: on her, and a stack on 爱国者 and his help.
func _pulse(p: Vector3) -> void:
	BossVfx.shrine_pulse(game, p, BossCatalog.SHRINE_RADIUS)
	var her := game.player
	if Vector2(her.global_position.x - p.x, her.global_position.z - p.z).length() <= BossCatalog.SHRINE_RADIUS:
		her.take_damage(her.max_hp * BossCatalog.SHRINE_HIT, "true")
		game.features.add("contamination", BossCatalog.SHRINE_CONTAM * game.features.growth_mult("contamination", game.floor_number))
	for e in game.floor_enemies():
		if Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() > BossCatalog.SHRINE_RADIUS: continue
		if e is Boss: (e as Boss).empower()
		else: e.apply_status("haste", BossCatalog.SHRINE_TIME, 1.0)

# --- 龙门: 源石狂暴地板 (BossCatalog.FRENZY_*) -------------------------------------------------

## Her frenzy left (s): she loses life and strips barriers harder while it runs.
var her_frenzy := 0.0
var _frenzy_spark := 0.0
var _frenzy_rng := RandomNumberGenerator.new()
var _frenzy_mat: StandardMaterial3D
const FRENZY_LIGHT := preload("res://world/frenzy_light.gdshader")
const FRENZY_BEAMS_PER_EDGE := 3

func _build_city() -> void:
	var floor_node := Node3D.new()
	floor_node.name = "FrenzyFloor"
	# 明日方舟's 活性源石 (tools/blender/kit/build_arena_props.py arena_city_frenzy).
	var tile := _model("arena_city_frenzy")
	if tile != null: floor_node.add_child(tile)
	# The dripping-knife mark painted on its panel, glowing and throbbing.
	var mark := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(BossCatalog.RUNE_HALF * 1.5, BossCatalog.RUNE_HALF * 1.5)
	mark.mesh = plane
	_frenzy_mat = StandardMaterial3D.new()
	_frenzy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_frenzy_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_frenzy_mat.albedo_texture = load("res://art/field/fx/frenzy_mark.png")
	_frenzy_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_frenzy_mat.albedo_color = Color(1.4, 1.1, 1.1, 1.0)
	mark.material_override = _frenzy_mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position.y = 0.016
	floor_node.add_child(mark)
	# Red light rising off all four edges (world/frenzy_light.gdshader): a few thin
	# beams along each, each edge flaring in its own random windows.
	var light_mat := ShaderMaterial.new()
	light_mat.shader = FRENZY_LIGHT
	var beam_rng := RandomNumberGenerator.new()
	beam_rng.seed = 7151
	var h := BossCatalog.RUNE_HALF * 0.96
	for side in range(4):
		for n in range(FRENZY_BEAMS_PER_EDGE):
			var along := (float(n) + beam_rng.randf_range(0.25, 0.75)) / FRENZY_BEAMS_PER_EDGE * 2.0 - 1.0
			var at := Vector3(along * h, 0.0, h) if side == 0 else (Vector3(h, 0.0, -along * h) if side == 1 else (Vector3(-along * h, 0.0, -h) if side == 2 else Vector3(-h, 0.0, along * h)))
			var tall := beam_rng.randf_range(0.8, 1.6)
			var beam := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(0.2, tall)
			beam.mesh = quad
			beam.material_override = light_mat
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.set_instance_shader_parameter("edge", float(side))
			beam.set_instance_shader_parameter("seed", beam_rng.randf())
			beam.position = at + Vector3.UP * tall * 0.5
			floor_node.add_child(beam)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.25, 0.12)
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	glow.position = Vector3.UP * 0.6
	floor_node.add_child(glow)
	add_child(floor_node)
	runes.append({"node": floor_node, "buried": 0.0})
	_place_frenzy()
	# The arena lit warm from above (用户 2026-11-05: 整个场景都太黑了，可以调亮).
	var lamp := OmniLight3D.new()
	lamp.name = "ArenaLamp"
	lamp.light_color = Color(1.0, 0.88, 0.7)
	lamp.light_energy = 3.2
	lamp.omni_range = radius + 6.0
	lamp.omni_attenuation = 0.8
	add_child(lamp)
	lamp.global_position = centre + Vector3.UP * 7.0

func _place_frenzy() -> void:
	if runes.is_empty() or not is_instance_valid(runes[0].node): return
	if _frenzy_rng.seed == 0: _frenzy_rng.seed = hash([game.floor_number, game.region_id, centre, "frenzy"])
	var keep: Array[Vector3] = [centre, game.world_map.arena_entry]
	for entry in cover: keep.append(entry.at)
	var spot := _random_spot(_frenzy_rng, keep, 3.0, 4.0, at(Vector2(0.0, -5.0)))
	# Flush with the floor (用户 2026-11-05: 嵌在地上不要凸出来): the 2 cm tile sits on the ground line.
	(runes[0].node as Node3D).global_position = spot

## 沙狱 landing on the floor covers it a while.
func bury_runes(point: Vector3, reach: float) -> void:
	for rune in runes:
		var p: Vector3 = rune.node.global_position
		if Vector2(p.x - point.x, p.z - point.z).length() <= reach + BossCatalog.RUNE_RADIUS:
			rune.buried = BossCatalog.RUNE_BURIED
			rune.node.visible = false

## The tile under `point` (a 2 m square, as the model).
func rune_under(point: Vector3) -> Dictionary:
	for rune in runes:
		if float(rune.buried) > 0.0: continue
		var p: Vector3 = rune.node.global_position
		if absf(p.x - point.x) <= BossCatalog.RUNE_HALF and absf(p.z - point.z) <= BossCatalog.RUNE_HALF: return rune
	return {}

## Her blows on a barrier while her frenzy runs.
func barrier_mult() -> float:
	return BossCatalog.FRENZY_SHIELD if her_frenzy > 0.0 else 1.0

func _tick_runes(delta: float) -> void:
	for rune in runes:
		if float(rune.buried) > 0.0:
			rune.buried = maxf(0.0, float(rune.buried) - delta)
			if float(rune.buried) <= 0.0: rune.node.visible = true
	if _frenzy_mat != null:
		var k := 1.15 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
		_frenzy_mat.albedo_color = Color(k, k * 0.8, k * 0.8, 1.0)
	var her := game.player
	if not rune_under(her.global_position).is_empty(): her_frenzy = BossCatalog.FRENZY_TIME
	if her_frenzy > 0.0:
		her_frenzy = maxf(0.0, her_frenzy - delta)
		if her.hp > 1.0: her.hp = maxf(1.0, her.hp - her.max_hp * BossCatalog.FRENZY_DRAIN * delta)
		_frenzy_spark -= delta
		if _frenzy_spark <= 0.0:
			_frenzy_spark = 0.25
			var c := BossVfx.colours("patriot")
			var fx := BossVfx.make(game, Vector3(her.global_position.x, game.ground_y(her.global_position) + 0.01, her.global_position.z))
			fx.embers(Vector3.UP * 0.6, c.main, c.hot, 6, 0.4, 0.0, 0.7)
	var boss := game.outpost_boss
	if is_instance_valid(boss) and not boss._dead and boss.in_fight() and not rune_under(boss.global_position).is_empty() and boss.rage_left < 0.5:
		boss.empower()

# --- 萨米: two fires and the 木裂 totem -------------------------------------------------------

func _build_snow() -> void:
	totem = _add_cover(BossCatalog.TOTEM_AT, BossCatalog.TOTEM_SIZE, "totem", false, "arena_snow_totem")

## The fires stand where the arena wants them; the first one lit (GmFeatures._spawn_fires).
func fire_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if region != "snow": return out
	for offset in BossCatalog.FIRES: out.append(game.world_map.nearest_walkable(at(offset)))
	return out

## The first 自我泯灭 runs through the totem.
func break_totem() -> void:
	if not totem.is_empty() and is_instance_valid(totem.body): _shatter(totem)

func _totem_broken() -> void:
	var boss := game.outpost_boss
	if is_instance_valid(boss):
		boss._add_zone({"shape": "circle", "at": totem.at, "radius": BossCatalog.TOTEM_ICE_RADIUS, "time": BossCatalog.TOTEM_ICE, "feature": "cold", "rate": BossCatalog.TOTEM_COLD, "colour": "cold"})
	totem = {}

# --- 叙拉古: the fountain and the 叙拉古平民 --------------------------------------------------

func _build_siracusa() -> void:
	_add_cover(BossCatalog.FOUNTAIN_AT, Vector2(BossCatalog.FOUNTAIN_RADIUS * 1.6, 1.0), "fountain", true, "arena_sira_fountain")

## 叙拉古平民 round the edge, sheltering from the rain (spawned once the floor's navigation is up).
func spawn_civilians() -> void:
	if region != "siracusa": return
	for i in range(BossCatalog.CIVILIANS):
		var a := TAU * (i + 0.5) / BossCatalog.CIVILIANS
		var spot := game.world_map.nearest_walkable(at(Vector2(cos(a), sin(a)) * (radius - 2.5)))
		var c := Civilian.new()
		game.add_child(c)
		c.global_position = spot + Vector3.UP * 0.65
		c.global_position.y = game.ground_y(c.global_position) + Enemy.GROUND_LIFT
		c.setup_civilian(game, self)
		civilians.append(c)

# --- Each tick, and a reset ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	_tick_shrine(delta)
	_tick_mines()
	_tick_runes(delta)

## The boss went home whole (离场 8 s): devices back as they were; broken cover stays broken (Q6).
func reset() -> void:
	shrine_time = BossCatalog.SHRINE_EVERY
	_shrine_warned = false
	_place_shrine()
	for entry in raised:
		if is_instance_valid(entry.node): entry.node.queue_free()
	raised.clear()
	for mine in mines:
		mine.armed = false
		mine.spent = false
		if is_instance_valid(mine.node):
			mine.node.visible = true
			(mine.lamp.material_override as StandardMaterial3D).albedo_color = Color("6a6a6a")
	for rune in runes:
		rune.buried = 0.0
		rune.node.visible = true
	her_frenzy = 0.0
	_place_frenzy()

# --- The set pieces' props (Boss演出策划案_v0_2; BossShow drives them) -----------------------
## Blender pieces when they are there (tools/blender/kit), else plain stand-ins.
const SHOW_MODELS := {"flag": "arena_mine_flag", "cloth": "arena_mine_flag_cloth", "mound": "arena_snow_mound", "manhole": "arena_city_manhole"}
const FLAG_AT := Vector2(-5.5, -8.5)
const MANHOLES := [Vector2(-10.0, -2.0), Vector2(10.0, -2.0), Vector2(-10.0, -7.0), Vector2(10.0, -7.0)]
const EYES := [Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(-0.95, 0.2), Vector2(0.95, 0.2)]
var flag: Node3D
var _cloth: MeshInstance3D
var mound: Node3D
var manholes: Array[Node3D] = []
var _umbrellas: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _fountain_tint: MeshInstance3D

## The props a boss floor's set pieces need (a warden floor has none).
func build_show_props() -> void:
	if not BossCatalog.is_boss_floor(game.floor_number): return
	match region:
		"mine": _build_flag()
		"city":
			for o in MANHOLES:
				var m := _model(SHOW_MODELS.manhole)
				var lid: Node3D = m if m != null else _mesh_cylinder(0.45, 0.06, Color("3a3c40"))
				add_child(lid)
				lid.global_position = at(o) + Vector3.UP * 0.03
				manholes.append(lid)

# 矿区: 游击队旗 on a pole at the edge — raised by the wind, lit by originium, dropped at his fall.
func _build_flag() -> void:
	flag = Node3D.new()
	flag.name = "PatriotFlag"
	add_child(flag)
	flag.global_position = at(FLAG_AT)
	var m := _model(SHOW_MODELS.flag)
	var cloth := _model(SHOW_MODELS.cloth)
	if m != null and cloth != null:
		flag.add_child(m)
		_cloth = cloth
		_cloth.position = Vector3(0.0, 3.3, 0.0)
		flag.add_child(_cloth)
		return
	var pole := _mesh_cylinder(0.05, 3.4, Color("3a342e"))
	pole.position.y = 1.7
	flag.add_child(pole)
	_cloth = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 0.85)
	quad.center_offset = Vector3(0.65, 0, 0)
	_cloth.mesh = quad
	var mat := _material(Color("b8452a"), false)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cloth.material_override = mat
	_cloth.position = Vector3(0.05, 2.95, 0)
	flag.add_child(_cloth)

func wave_flag() -> void:
	if not is_instance_valid(_cloth): return
	var tween := _cloth.create_tween()
	for i in range(4):
		tween.tween_property(_cloth, "rotation:y", 0.5 if i % 2 == 0 else -0.25, 0.22)
		tween.parallel().tween_property(_cloth, "scale:x", 1.12 if i % 2 == 0 else 0.92, 0.22)
	tween.tween_property(_cloth, "rotation:y", 0.15, 0.4)

func light_flag() -> void:
	if not is_instance_valid(_cloth): return
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = Color(1.0, 0.54, 0.16, 0.0)
	_cloth.material_overlay = glow
	_cloth.create_tween().tween_property(glow, "albedo_color:a", 0.55, 0.8)

func drop_flag() -> void:
	if not is_instance_valid(flag): return
	var tween := flag.create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(flag, "rotation:z", 1.35, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# 萨米: the ice he waits in, the first time (§4.4).
func has_mound() -> bool:
	return is_instance_valid(mound)

func raise_mound(where: Vector3) -> void:
	if region != "snow" or is_instance_valid(mound): return
	mound = Node3D.new()
	mound.name = "IceMound"
	add_child(mound)
	mound.global_position = Vector3(where.x, game.ground_y(where), where.z)
	var m := _model(SHOW_MODELS.mound)
	if m != null:
		mound.add_child(m)
		return
	var ice := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 1.2
	dome.height = 1.9
	dome.radial_segments = 10
	dome.rings = 5
	ice.mesh = dome
	var mat := _material(Color(0.72, 0.88, 0.95, 0.88), false)
	mat.roughness = 0.2
	mat.metallic_specular = 0.8
	ice.material_override = mat
	ice.scale = Vector3(1.0, 0.85, 1.0)
	ice.position.y = 0.5
	mound.add_child(ice)

func crack_mound() -> void:
	if not is_instance_valid(mound): return
	var tween := mound.create_tween()
	for i in range(5):
		tween.tween_property(mound, "position:x", mound.position.x + (0.04 if i % 2 == 0 else -0.04), 0.05)
	tween.tween_property(mound, "position:x", mound.position.x, 0.05)

func break_mound() -> void:
	if not is_instance_valid(mound): return
	var c := BossVfx.colours("eikthyrnir")
	var fx := BossVfx.make(game, mound.global_position + Vector3.UP * 0.01)
	fx.chips(Vector3.UP * 0.8, 50, 1.0, Color("cfeefa"), 4.0)
	fx.dust(Vector3.UP * 0.4, c.dust, 18, 1.2, 0.0, 1.5)
	mound.queue_free()
	mound = null

# 龙门: the lids jump before 鼠潮 (§3.5).
func rattle_manholes(seconds: float) -> void:
	if not manholes.is_empty() and game.sound != null: game.sound.play("ratking_manhole")
	for i in range(manholes.size()):
		var lid := manholes[i]
		if not is_instance_valid(lid): continue
		var tween := lid.create_tween()
		tween.tween_interval(seconds * 0.15 * i)
		for k in range(3):
			tween.tween_property(lid, "position:y", lid.position.y + 0.12, 0.07)
			tween.tween_property(lid, "position:y", lid.position.y, 0.09)

# 叙拉古: umbrellas in the lanes, wolves' eyes at the edge, the fountain going dark red.
func show_family_umbrellas() -> void:
	if region != "siracusa" or not _umbrellas.is_empty(): return
	for mouth in mouths():
		var u := Node3D.new()
		add_child(u)
		u.global_position = mouth
		var canopy := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = 0.6
		cone.height = 0.3
		canopy.mesh = cone
		canopy.material_override = _material(Color("15151a"), false)
		canopy.position.y = 1.9
		u.add_child(canopy)
		var stick := _mesh_cylinder(0.02, 1.9, Color("15151a"))
		stick.position.y = 0.95
		u.add_child(stick)
		_umbrellas.append(u)
		var tween := u.create_tween()
		tween.tween_interval(1.6)
		tween.tween_property(u, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		tween.tween_callback(func(): if is_instance_valid(u): u.queue_free(); _umbrellas.erase(u))

func wolf_eyes(on: bool) -> void:
	for e in _eyes:
		if is_instance_valid(e): e.queue_free()
	_eyes.clear()
	if not on: return
	for o in EYES:
		var pair := Node3D.new()
		add_child(pair)
		pair.global_position = at(o * (radius + 0.5)) + Vector3.UP * 0.9
		for side in [-1.0, 1.0]:
			var eye := _mesh_box(Vector3(0.09, 0.05, 0.05), Color("ff3a2a"), true)
			eye.position.x = side * 0.13
			eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pair.add_child(eye)
		_eyes.append(pair)

func tint_fountain(k: float) -> void:
	if region != "siracusa": return
	if not is_instance_valid(_fountain_tint):
		_fountain_tint = _mesh_cylinder(BossCatalog.FOUNTAIN_RADIUS * 0.75, 0.02, Color(0.35, 0.03, 0.05, 0.0))
		add_child(_fountain_tint)
		_fountain_tint.global_position = at(BossCatalog.FOUNTAIN_AT) + Vector3.UP * 0.62
	var mat := _fountain_tint.material_override as StandardMaterial3D
	_fountain_tint.create_tween().tween_property(mat, "albedo_color:a", clampf(k, 0.0, 1.0) * 0.75, 1.5)

# --- The models and stand-in meshes --------------------------------------------------------

## A Blender piece as one mesh, lit like the rest of the kit (null when it is not there).
func _model(id: String) -> MeshInstance3D:
	if id.is_empty() or not ResourceLoader.exists(KIT % id): return null
	var m := MeshInstance3D.new()
	m.name = id
	# The stump keeps its bark showing like the fallen pines (2026-11-11).
	m.mesh = TerraceDressing.kit_mesh(load(KIT % id), 1.0, TerraceDressing.LOG_SNOW_BIAS if id == "arena_snow_stump" else 0.0)
	return m

func _mesh_box(size: Vector3, c: Color, glow: bool = false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = _material(c, glow)
	return m

func _mesh_cylinder(r: float, h: float, c: Color, glow: bool = false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	cyl.radial_segments = 24
	m.mesh = cyl
	m.material_override = _material(c, glow)
	return m

static func _material(c: Color, unshaded: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	if unshaded: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
