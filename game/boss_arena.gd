class_name BossArena
extends Node3D

## A boss floor's arena (Boss战场地策划案_v1_0.md, 用户 2026-10-19): the room
## the map dug for it (ContinuousWorldMap.boss_layout), and on it the gate
## that shuts the way out until the boss falls, the cover its big moves break
## (for good), and the region's device from the original stage: 源石祭坛 and
## 干扰地雷 (7-18), 医疗符文 (CB-10), two fires and the 木裂 totem (萨米),
## the fountain and 叙拉古平民 (IS-10). Numbers are in BossCatalog.
## Models are placeholders until the Blender pieces (§7) are in.

const GATE_SIZE := Vector3(9.0, 3.2, 0.8)
## The Blender pieces (tools/blender/kit/build_arena_props.py). Cover models go
## to the region's cover in order; 叙拉古's way out is the family car.
const KIT := "res://art/kit/%s.glb"
const GATE_MODEL := {"mine": "arena_mine_gate", "city": "arena_city_shutter", "snow": "arena_snow_logs"}
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

func _build_gate(exit: Vector3) -> void:
	gate = StaticBody3D.new()
	gate.name = "ArenaGate"
	gate.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = GATE_SIZE
	shape.shape = box
	gate.add_child(shape)
	var model := _model(str(GATE_MODEL.get(region, "")))
	if model != null:
		model.position.y = -GATE_SIZE.y * 0.5
		gate.add_child(model)
	elif region == "siracusa":
		# The family car parked across the way out, nose to the piazza (its S idle frame).
		var car := Sprite3D.new()
		car.texture = FieldArt.enemy_dir_pose("family_car", 0, 0)
		car.pixel_size = Enemy.PIXEL * 1.6
		car.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		car.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		car.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		car.offset = Vector2(0, 19)
		car.position.y = -GATE_SIZE.y * 0.5 + 0.1
		gate.add_child(car)
	else:
		gate.add_child(_mesh_box(GATE_SIZE, Color("2a2c34")))
	add_child(gate)
	gate.global_position = Vector3(exit.x, game.ground_y(exit) + GATE_SIZE.y * 0.5, exit.z + 1.0)

func exit_open() -> bool:
	return not is_instance_valid(gate)

## The boss is down: the gate goes and the way out is open.
func open_exit() -> void:
	if is_instance_valid(gate):
		EnemyAttackVfx.spawn(game, gate.global_position, Vector3.FORWARD, "ground_shock_big", 3.0)
		gate.queue_free()
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
	shrine.global_position = at(BossCatalog.SHRINE_AT)
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
		for e in game.floor_enemies():
			if Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() > BossCatalog.MINE_RADIUS: continue
			e.take_hit(game.player.attack_power() * BossCatalog.MINE_DAMAGE, "phys")
			if is_instance_valid(e) and not e._dead: e.apply_status("fragile", BossCatalog.MINE_FRAGILE_TIME, BossCatalog.MINE_FRAGILE)

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

# --- 龙门: 医疗符文 ----------------------------------------------------------------------

func _build_city() -> void:
	for offset in BossCatalog.RUNES:
		var disc: MeshInstance3D = _model("arena_city_rune")
		if disc == null: disc = _mesh_cylinder(BossCatalog.RUNE_RADIUS, 0.02, Color(0.42, 0.9, 0.78, 0.5), true)
		add_child(disc)
		disc.global_position = at(offset) + Vector3.UP * 0.04
		runes.append({"node": disc, "buried": 0.0})

## 沙狱 landing on a rune buries it a while.
func bury_runes(point: Vector3, reach: float) -> void:
	for rune in runes:
		var p: Vector3 = rune.node.global_position
		if Vector2(p.x - point.x, p.z - point.z).length() <= reach + BossCatalog.RUNE_RADIUS:
			rune.buried = BossCatalog.RUNE_BURIED
			rune.node.visible = false

func rune_under(point: Vector3) -> Dictionary:
	for rune in runes:
		if float(rune.buried) > 0.0: continue
		var p: Vector3 = rune.node.global_position
		if Vector2(p.x - point.x, p.z - point.z).length() <= BossCatalog.RUNE_RADIUS: return rune
	return {}

func _tick_runes(delta: float) -> void:
	for rune in runes:
		if float(rune.buried) > 0.0:
			rune.buried = maxf(0.0, float(rune.buried) - delta)
			if float(rune.buried) <= 0.0: rune.node.visible = true
	if not rune_under(game.player.global_position).is_empty():
		game.player.heal(game.player.max_hp * BossCatalog.RUNE_HEAL * delta)

# --- 萨米: two fires and the 木裂 totem -------------------------------------------------------

func _build_snow() -> void:
	totem = _add_cover(BossCatalog.TOTEM_AT, BossCatalog.TOTEM_SIZE, "totem", false, "arena_snow_totem")

## The fires stand where the arena wants them; the first one lit (GameManager._spawn_fires).
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

# --- The models and placeholder meshes -----------------------------------------------------

## A Blender piece as one mesh, lit like the rest of the kit (null when it is not there).
func _model(id: String) -> MeshInstance3D:
	if id.is_empty() or not ResourceLoader.exists(KIT % id): return null
	var m := MeshInstance3D.new()
	m.name = id
	m.mesh = TerraceDressing.kit_mesh(load(KIT % id))
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
