class_name CombatMarker
extends MeshInstance3D
## A red ground warning (warning_marker.gdshader): see-through, with rings
## spreading from the middle that reach the rim when the strike lands.
const SHADER := preload("res://game/warning_marker.gdshader")
const WHITE_RIM := 0.07
## Grid spacing in metres; each vertex sits on the ground under it, so a
## warning on a ramp lies along it instead of half sinking in.
const STEP := 0.3
## Height over the ground at every vertex.
const LIFT := 0.05
var life := 1.0
## Its whole countdown, so the rings know how far along it is.
var total := 1.0
var hitstop_owner: Enemy
## The attack it warns of cannot be interrupted (white edge).
var unstoppable := false
var _plane: PlaneMesh
var _laid_on := Transform3D()
var _laid := false

## `shape` is "circle" (size.x = radius) or "lane" (size = width, length).
static func create(shape: String, size: Vector2, lifetime: float, p_unstoppable: bool = false) -> CombatMarker:
	var marker := CombatMarker.new()
	marker.life = lifetime
	marker.total = maxf(lifetime, 0.01)
	marker.unstoppable = p_unstoppable
	var edge := WHITE_RIM if p_unstoppable else 0.0
	var extent := Vector2(size.x * 2.0, size.x * 2.0) if shape == "circle" else size
	extent += Vector2.ONE * edge * 2.0
	var plane := PlaneMesh.new()
	plane.size = extent
	plane.subdivide_width = clampi(ceili(extent.x / STEP) - 1, 0, 64)
	plane.subdivide_depth = clampi(ceili(extent.y / STEP) - 1, 0, 64)
	marker._plane = plane
	marker.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = 20
	material.set_shader_parameter("size", extent)
	material.set_shader_parameter("shape", 0 if shape == "circle" else 1)
	material.set_shader_parameter("white_rim", edge)
	material.set_shader_parameter("progress", 0.0)
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return marker

## Its flat size in metres (white edge included); the mesh itself is bent onto the ground.
func footprint() -> Vector2:
	return _plane.size if _plane != null else Vector2.ZERO

func progress() -> float:
	return clampf(1.0 - life / total, 0.0, 1.0)

func _process(delta: float) -> void:
	var game := _game()
	if not _laid or not global_transform.is_equal_approx(_laid_on): _lay_on_ground(game)
	if game != null and not game.simulation_active(): return
	if is_instance_valid(hitstop_owner) and hitstop_owner.hitstop_remaining > 0: return
	life -= delta
	if material_override is ShaderMaterial: (material_override as ShaderMaterial).set_shader_parameter("progress", progress())
	if life <= 0: queue_free()

## Bends the grid onto the ground below it: every vertex to the ground height
## under its own x/z. Spawners place the marker after adding it, and some move
## it, so this runs whenever the marker has moved.
func _lay_on_ground(game: GameManager) -> void:
	_laid = true
	_laid_on = global_transform
	if game == null or game.in_base or not is_instance_valid(game.world_map) or _plane == null: return
	var arrays := _plane.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var xf := global_transform
	var inverse := xf.affine_inverse()
	for i in range(verts.size()):
		var at := xf * Vector3(verts[i].x, 0.0, verts[i].z)
		at.y = game.ground_y(at) + LIFT
		verts[i].y = (inverse * at).y
	arrays[Mesh.ARRAY_VERTEX] = verts
	var bent := ArrayMesh.new()
	bent.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = bent

## The GameManager above it, found again whenever its ancestry may have changed.
var _game_found := false
var _game_node: GameManager

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED: _game_found = false

func _game() -> GameManager:
	if _game_found: return _game_node
	var node := get_parent()
	while node != null and not node is GameManager: node = node.get_parent()
	_game_node = node as GameManager
	_game_found = true
	return _game_node
