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
var _disc: Decal

func _ready() -> void:
	game = get_parent() as GameManager
	add_to_group("ground_hazards")
	# Projected down onto the ground so it follows a ramp; a flat disc sank
	# into the uphill half there (用户 2026-10-22: 变成半圆).
	_disc = Decal.new()
	_disc.size = Vector3(radius * 2.0, clampf(radius * 1.2, 1.2, 3.0), radius * 2.0)
	# Ground and props only, not the sprites standing in it.
	_disc.cull_mask = 1
	_disc.texture_albedo = _circle_texture()
	_disc.texture_emission = _circle_texture(true)
	_disc.emission_energy = 0.4
	_disc.modulate = colour if fuse <= 0.0 else Color(0.95, 0.2, 0.15, 0.3)
	add_child(_disc)
	if fuse > 0.0:
		# The fuse is a warning like any other: see-through red with rings
		# counting down to the burst (新敌人攻击案 v1.2).
		_disc.visible = false
		var warning := CombatMarker.create("circle", Vector2(radius, 0.0), fuse)
		warning.name = "Warning"
		add_child(warning)
		warning.position.y = 0.06

static var _circles := {}
## A white disc with a soft one-texel rim, tinted by the decal. The emission
## copy is black outside instead of clear: decal emission ignores alpha.
static func _circle_texture(glow: bool = false) -> ImageTexture:
	if _circles.has(glow): return _circles[glow]
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var a := clampf(32.0 - Vector2(x + 0.5 - 32.0, y + 0.5 - 32.0).length(), 0.0, 1.0)
			image.set_pixel(x, y, Color(a, a, a, 1.0) if glow else Color(1, 1, 1, a))
	_circles[glow] = ImageTexture.create_from_image(image)
	return _circles[glow]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	if fuse > 0.0:
		fuse -= delta
		if fuse > 0.0: return
		_disc.modulate = colour
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
