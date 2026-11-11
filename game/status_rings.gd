class_name StatusRings
extends Node
## Puts the buff / debuff ring (effects/status_lines.tscn) on whoever has a
## timed buff or debuff (GPU粒子特效推广策划案 v0.6 §7a P6): her, and the
## ENEMY_LIMIT enemies nearest her. One ring per figure, one layer each of
## rising and falling lines however many there are. Rings come from a pool and
## go back to it; nothing in the base. Checked every CHECK seconds.

const SCENE := preload("res://effects/status_lines.tscn")
const ENEMY_LIMIT := 24
const CHECK := 0.1
const PLAYER_RADIUS := 0.42
const PLAYER_HEIGHT := 1.9
const ENEMY_RADIUS := 0.42
const ELITE_RADIUS := 0.55
const BOSS_RADIUS := 0.9

var game: GameManager
var _wait := 0.0
## figure instance id -> StatusLines.
var worn := {}
var _pool: Array[StatusLines] = []

static func create(owner: GameManager) -> StatusRings:
	var rings := StatusRings.new()
	rings.name = "StatusRings"
	rings.game = owner
	owner.add_child(rings)
	return rings

func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0: return
	_wait = CHECK
	refresh()

## Who wears a ring now, and which lines it shows.
func refresh() -> void:
	var wanted := {}
	if is_instance_valid(game) and not game.in_base and is_instance_valid(game.player) and game.player.is_inside_tree():
		var p := game.player
		var sides: Array = StatusCatalog.player_rings(p.hexes)
		if sides[0] or sides[1]: wanted[p.get_instance_id()] = [p, sides, PLAYER_RADIUS, PLAYER_HEIGHT]
		var near: Array = []
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e == null or e._dead or not e.is_inside_tree() or e.game != game: continue
			var es: Array = StatusCatalog.enemy_rings(e)
			if not (es[0] or es[1]): continue
			near.append([e.global_position.distance_squared_to(p.global_position), e, es])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for i in range(mini(ENEMY_LIMIT, near.size())):
			var e: Enemy = near[i][1]
			var r := BOSS_RADIUS if e is Boss else (ELITE_RADIUS if e.elite else ENEMY_RADIUS)
			wanted[e.get_instance_id()] = [e, near[i][2], r, 1.9 if not (e is Boss) else 3.2]
	for id in worn.keys():
		if not wanted.has(id) or not is_instance_valid(worn[id]): _release(id)
	for id in wanted:
		var w: Array = wanted[id]
		var ring = worn.get(id)
		if ring == null or not is_instance_valid(ring):
			ring = _take()
			worn[id] = ring
			if ring.get_parent() != null: ring.get_parent().remove_child(ring)
			(w[0] as Node).add_child(ring)
			ring.position = Vector3.ZERO
		ring.fit(float(w[2]), float(w[3]))
		ring.show_state(bool(w[1][0]), bool(w[1][1]))

func _take() -> StatusLines:
	while not _pool.is_empty():
		var ring: StatusLines = _pool.pop_back()
		if is_instance_valid(ring): return ring
	return SCENE.instantiate() as StatusLines

func _release(id: int) -> void:
	var ring = worn.get(id)
	worn.erase(id)
	if ring == null or not is_instance_valid(ring): return
	ring.show_state(false, false)
	# Back to the pool, out of the figure (which may be freed).
	if ring.get_parent() != null: ring.get_parent().remove_child(ring)
	_pool.append(ring)

func ring_on(figure: Node) -> StatusLines:
	var ring = worn.get(figure.get_instance_id())
	return ring as StatusLines if is_instance_valid(ring) else null

func _exit_tree() -> void:
	for ring in _pool:
		if is_instance_valid(ring): ring.free()
	_pool.clear()
