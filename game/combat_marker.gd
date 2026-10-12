class_name CombatMarker
extends MeshInstance3D
## A red ground warning (warning_marker.gdshader): see-through, with rings
## spreading from the middle that reach the rim when the strike lands.
const SHADER := preload("res://game/warning_marker.gdshader")
const WHITE_RIM := 0.07
var life := 1.0
## Its whole countdown, so the rings know how far along it is.
var total := 1.0
var hitstop_owner: Enemy
## The attack it warns of cannot be interrupted (white edge).
var unstoppable := false

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

func progress() -> float:
	return clampf(1.0 - life / total, 0.0, 1.0)

func _process(delta: float) -> void:
	var game := _game()
	if game != null and not game.simulation_active(): return
	if is_instance_valid(hitstop_owner) and hitstop_owner.hitstop_remaining > 0: return
	life -= delta
	if material_override is ShaderMaterial: (material_override as ShaderMaterial).set_shader_parameter("progress", progress())
	if life <= 0: queue_free()

func _game() -> GameManager:
	var node := get_parent()
	while node != null and not node is GameManager: node = node.get_parent()
	return node as GameManager
