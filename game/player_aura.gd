class_name PlayerAura
extends Node3D
## What sits on and around the player: her ground shadow and Lappland's
## sword-wave counter. (Amiya's 绝影-ready orbit lines and the skill-ready blade
## gleam, the bars floating beside her, are gone: 用户 2026-10-22 删除角色身边漂浮的竖条.)
##
## Lappland's counter: three translucent wolf fangs circling her feet, like
## LoL's three-hit passive rings (用户 2026-10-10: 透明，环绕在角色脚下，见 lol
## 打三环特效; then 从粗到细一颗牙的形状，三颗环绕脚下). Each fang curves along
## the circle, thick at the root and tapering to a point that leads the spin.
## Faint when empty, grey-blue per charge, all three purple and spinning faster
## once the wave is ready. The fangs are Sol's painted batch L1 v2: one fang
## per texture, 42 px canvas centred on the ring, fang at 12 o'clock (outer edge
## r = 20 px, 70°, tip leading on the left); the game turns copies by 120°/240°.
const FANG_TEXTURES := {
	"empty": preload("res://godot_assets/lappland_fang_empty.png"),
	"lit": preload("res://godot_assets/lappland_fang_lit.png"),
	"full": preload("res://godot_assets/lappland_fang_full.png"),
}
const RING_SPIN := 0.9      # rad/s while charging
const RING_SPIN_FULL := 2.6 # rad/s once full
const EMPTY_ALPHA := 0.3
const LIT_ALPHA := 0.6
const FULL_ALPHA := 0.7

var player: Player
var age := 0.0
var shadow: MeshInstance3D
var ring: Node3D
var segments: Array[MeshInstance3D] = []

func _ready() -> void:
	player = get_parent() as Player
	shadow = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.5
	disk.bottom_radius = 0.5
	disk.height = 0.015
	shadow.mesh = disk
	shadow.material_override = CombatVfx.material(CombatVfx.SHADOW, 0.4)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	ring = Node3D.new()
	add_child(ring)
	for i in range(3):
		var quad := QuadMesh.new()
		quad.size = FANG_TEXTURES.full.get_size() * CombatVfx.PIXEL
		var segment := MeshInstance3D.new()
		segment.mesh = quad
		# Lie flat: quad X -> right, texture up -> forward (-Z), normal -> up;
		# then turn the copy to its third of the circle.
		segment.basis = Basis(Vector3.UP, i * TAU / 3.0) * Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
		var mat := CombatVfx.material(Color.WHITE, LIT_ALPHA)
		mat.albedo_texture = FANG_TEXTURES.empty
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# Under enemy warnings (priority 20) and the sprite; above the shadow.
		mat.render_priority = 1
		segment.material_override = mat
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.add_child(segment)
		segments.append(segment)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if is_instance_valid(player.game) and not (player.game.simulation_active() or player.game.base_walk_active()): return
	age += delta
	global_basis = Basis.IDENTITY
	shadow.global_position = Vector3(player.global_position.x, 0.045, player.global_position.z)
	shadow.visible = not player.invulnerable
	var need := player.wave_hits_needed()
	var waves := player.has_sword_wave()
	var full := (player.sword_charge >= need) if waves else player.has_skill() and player.skill_ready_now()
	# The three-hit ring (Lappland's sword wave).
	ring.visible = waves
	if ring.visible:
		ring.global_position = Vector3(player.global_position.x, 0.055, player.global_position.z)
		ring.rotation.y = wrapf(ring.rotation.y + delta * (RING_SPIN_FULL if full else RING_SPIN), 0.0, TAU)
		var pulse := 0.5 + 0.5 * sin(age * TAU * 2.0)
		for i in range(segments.size()):
			var mat := segments[i].material_override as StandardMaterial3D
			var alpha := EMPTY_ALPHA
			if full: alpha = lerpf(FULL_ALPHA - 0.1, FULL_ALPHA, pulse)
			elif player.sword_charge > i: alpha = LIT_ALPHA
			mat.albedo_texture = FANG_TEXTURES.full if full else (FANG_TEXTURES.lit if player.sword_charge > i else FANG_TEXTURES.empty)
			mat.albedo_color = Color(1, 1, 1, alpha)

