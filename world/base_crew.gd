class_name BaseCrew
extends Node3D

## Rhodes Island crew walking the base (用户 2026-10-18: 补主基地里行走的罗德岛
## 干员精灵图; art/characters/crew/CR_brief_v1.md): the special envoys and the
## reserve operators stroll between the hall's stations, stop a while and walk
## on. Only the crew whose sheets have arrived walk, so before Sol's batches
## the hall stays as it was. They pass through the player and the props'
## colliders (they follow the navigation mesh), and never block her.

## Everyone but the Doctor, who is the player's to walk.
const CREW := ["sharp", "stormeye", "pith", "touch", "tulip", "mechanist", "misery",
	"reserve_vanguard", "reserve_guard", "reserve_defender", "reserve_sniper", "reserve_caster",
	"reserve_medic", "reserve_supporter", "reserve_specialist"]
const COUNT := 7
## An unhurried walk on board: under half her speed (Player.BASE_MOVE_SPEED 5.5).
const SPEED := 2.3
const PAUSE := Vector2(3.0, 9.0)
## Where they head, layout x/z (BaseMap.STATION_SPOTS and the hall's areas,
## 基地建模改造案 §十七): stations, the main street, the lounge, the sand
## table's sides; now and then a room off the hall. Snapped to the nav mesh.
const SPOTS := [Vector2(78.5, -7.5), Vector2(49.5, -7.5), Vector2(25.5, -17.5), Vector2(64.0, -18.0),
	Vector2(64.0, -30.0), Vector2(30.0, -26.0), Vector2(98.0, -26.0), Vector2(118.0, -26.0), Vector2(10.0, -26.0),
	Vector2(21.0, -38.0), Vector2(30.0, -44.0), Vector2(88.0, -34.0), Vector2(106.0, -20.0), Vector2(40.0, -10.0),
	Vector2(113.0, 4.0), Vector2(140.0, -22.0), Vector2(-20.0, -26.0)]

## Crew at the canteen's tables on the second deck (势力特供策划案 §三): they
## stay at their places on the benches' ends, layout x/z, and do not walk.
const DINER_SPOTS := [Vector2(324.0, -10.0), Vector2(343.0, -16.6), Vector2(355.0, -10.0), Vector2(374.0, -16.6)]
const DINERS := 3

## Tests set this to walk operators that have sheets in place of the crew.
static var pool_override: Array = []

var base_map: BaseMap
var rng := RandomNumberGenerator.new()
## {body: CharacterBody3D, path: PackedVector3Array, step: int, wait: float}
var walkers: Array[Dictionary] = []
var diners: Array[Node3D] = []

func setup(map: BaseMap) -> void:
	base_map = map
	rng.randomize()

## The crew members who can walk: their sheets are in.
static func pool() -> Array:
	if not pool_override.is_empty(): return pool_override
	return CREW.filter(func(id): return LapplandAnimator3D.has_sheets(id))

func _ready() -> void:
	name = "Crew"

func _physics_process(delta: float) -> void:
	if base_map == null: return
	if walkers.is_empty():
		_spawn()
		return
	for walker in walkers: _walk(walker, delta)

func _map() -> RID:
	return base_map.navigation_map_rid()

func _spawn() -> void:
	var ids := pool()
	if ids.is_empty(): return
	# The map answers for the base only once it has synced with the bake
	# (until then the nearest point is the field's or the origin).
	if NavigationServer3D.map_get_iteration_id(_map()) == 0: return
	var probe := base_map.to_world(SPOTS[0].x, SPOTS[0].y, BaseMap.PLAYER_Y)
	var near := NavigationServer3D.map_get_closest_point(_map(), probe)
	if Vector2(near.x - probe.x, near.z - probe.z).length() > 3.0: return
	ids.shuffle()
	for i in range(mini(COUNT, ids.size())):
		var body := CharacterBody3D.new()
		body.name = "Crew_" + str(ids[i])
		body.collision_layer = 0
		body.collision_mask = 0
		var sprite := LapplandAnimator3D.new()
		sprite.character = ids[i]
		body.add_child(sprite)
		add_child(body)
		body.global_position = _spot()
		walkers.append({"body": body, "path": PackedVector3Array(), "step": 0, "wait": rng.randf_range(0.0, PAUSE.y)})
	# The rest of the crew eat upstairs once the canteen has rooms.
	if base_map.rooms.has("mess"):
		var spots := DINER_SPOTS.duplicate()
		spots.shuffle()
		for i in range(mini(DINERS, ids.size() - mini(COUNT, ids.size()))):
			var diner := Node3D.new()
			diner.name = "Diner_" + str(ids[COUNT + i])
			var sprite := LapplandAnimator3D.new()
			sprite.character = ids[COUNT + i]
			diner.add_child(sprite)
			add_child(diner)
			diner.global_position = base_map.to_world(spots[i].x, spots[i].y, BaseMap.PLAYER_Y)
			diners.append(diner)

## A point on the nav mesh by one of the SPOTS, a few metres either way.
func _spot() -> Vector3:
	var spot: Vector2 = SPOTS[rng.randi_range(0, SPOTS.size() - 1)]
	var at := base_map.to_world(spot.x + rng.randf_range(-3.0, 3.0), spot.y + rng.randf_range(-3.0, 3.0), BaseMap.PLAYER_Y)
	var on := NavigationServer3D.map_get_closest_point(_map(), at)
	return Vector3(on.x, BaseMap.PLAYER_Y + base_map.global_position.y, on.z)

func _walk(walker: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = walker.body
	if walker.wait > 0.0:
		walker.wait -= delta
		body.velocity = Vector3.ZERO
		if walker.wait <= 0.0:
			walker.path = NavigationServer3D.map_get_path(_map(), body.global_position, _spot(), true)
			walker.step = 1
		return
	var path: PackedVector3Array = walker.path
	if walker.step >= path.size():
		walker.wait = rng.randf_range(PAUSE.x, PAUSE.y)
		body.velocity = Vector3.ZERO
		return
	var target := Vector3(path[walker.step].x, body.global_position.y, path[walker.step].z)
	var to := target - body.global_position
	var move := SPEED * delta
	if to.length() <= move:
		body.global_position = target
		walker.step += 1
	else:
		body.velocity = to.normalized() * SPEED
		body.global_position += body.velocity * delta
