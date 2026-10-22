class_name GroundHazard
extends Node3D

## A patch of ground that hurts (装备扩充策划案 §2.1, §7): a burning bottle's
## fire, the red circle before a volatile slug bursts. `fuse` seconds of warning
## first; then either one burst (`lasting` 0) or a tick every TICK seconds for
## `lasting` seconds. Hits Lappland inside it, and other enemies too when
## `hurts_enemies` (高能源石虫's blast is 敌我都伤).

const TICK := 0.5

var game: GameManager
var radius := 1.3
var fuse := 0.0
var lasting := 0.0
## Damage per burst, or per tick while it lasts.
var damage := 100.0
var kind := "arts"
var hurts_enemies := false
var source: Enemy
var colour := Color(1.0, 0.45, 0.15, 0.35)
var _tick := 0.0
var _burst_done := false
var _disc: MeshInstance3D

func _ready() -> void:
	game = get_parent() as GameManager
	add_to_group("ground_hazards")
	_disc = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.02
	cylinder.radial_segments = 28
	_disc.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour if fuse <= 0.0 else Color(0.95, 0.2, 0.15, 0.3)
	# On the ground under whoever stands in it, not over them (用户 2026-10-20).
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_disc.material_override = material
	_disc.position.y = 0.06
	add_child(_disc)
	if fuse > 0.0:
		# The fuse is a warning like any other: see-through red with rings
		# counting down to the burst (新敌人攻击案 v1.2).
		_disc.visible = false
		var warning := CombatMarker.create("circle", Vector2(radius, 0.0), fuse)
		warning.name = "Warning"
		add_child(warning)
		warning.position.y = 0.06

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	if fuse > 0.0:
		fuse -= delta
		if fuse > 0.0: return
		(_disc.material_override as StandardMaterial3D).albedo_color = colour
		_disc.visible = true
		if lasting <= 0.0:
			_hit_everything()
			queue_free()
			return
	lasting -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_hit_everything()
	if lasting <= 0.0: queue_free()

func _hit_everything() -> void:
	if lasting <= 0.0 and not _burst_done:
		_burst_done = true
		CombatVfx.spawn(game, Vector3(global_position.x, game.ground_y(global_position) + 0.09, global_position.z), Vector3.FORWARD, "burst", 0, true)
	if is_instance_valid(game.player) and _flat(game.player.global_position) <= radius:
		game.player.take_damage(damage, kind, source if is_instance_valid(source) else null)
	if not hurts_enemies: return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != game or enemy._dead or enemy == source: continue
		if _flat(enemy.global_position) <= radius: enemy.take_hit(damage, kind)

func _flat(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()
