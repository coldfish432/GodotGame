class_name LapplandKit
extends OperatorKit
## 拉普兰德 · 领主 · 双剑 (用户 2026-10-20: 拉普兰德重新设计). Her combo and
## 剑气 stay in Player (relics and gear hang on them); this kit is her Space.
## - Basic: two single cuts, then the cross of both blades, which takes one
##   more beside the target (Player._lappland_cross).
## - 剑气: three landed hits fill it, the next swing throws the piercing wave;
##   精神摧毁 now rides on the wave (Player.on_wave_hit), not on the blades.
## - Space 日晷 (PRTS 技能 1: 攻击力 +70%, 40% 闪避物理): for a while her ATK
##   and physical evasion rise and a small sundial lies at her feet, its
##   shadow hand counting the time down — one turn over the whole skill, no
##   damage (用户 2026-10-20: 时针只做倒计时，缩小时钟). A physical blow evaded
##   while it runs fills 剑气 at once; with 影落とす時針 it lasts longer and
##   her blades slow what they hit.

const SECONDS := 8.0
## The dial's radius at her feet.
const DIAL_RADIUS := 0.9

var timer := 0.0
var duration := SECONDS
var _dial: Node3D
var _hand: MeshInstance3D
## The hand turns on this, at her feet.
var _hand_pivot: Node3D

func _init(p: Player) -> void:
	super(p, "lappland")

## Her combo and wave are Player's own.
func plays_swing() -> bool: return false

func cooldown_total() -> float:
	return float(SkillTrees.sundial(rank("sundial"))[2])

func atk_pct() -> float:
	return float(SkillTrees.sundial(rank("sundial"))[0]) if timer > 0.0 else 0.0

func evasion_bonus() -> float:
	return float(SkillTrees.sundial(rank("sundial"))[1]) if timer > 0.0 else 0.0

func status_text() -> String:
	return "日晷 %.1f" % timer if timer > 0.0 else ""

## How long it runs: 影落とす時針 adds half a second a rank.
func seconds() -> float:
	return SECONDS + 0.5 * rank("shadow_hand")

## The share of 日晷 already spent, which the hand shows (0 at noon, 1 round).
func spent() -> float:
	return 1.0 - timer / duration if timer > 0.0 else 0.0

func cast(_point: Vector3) -> bool:
	duration = seconds()
	timer = duration
	begin_cast(cooldown_total())
	play("attack_3", -player.global_basis.z, 0.0, player.animation_rate())
	_show_dial()
	return true

func tick(delta: float) -> void:
	super(delta)
	if timer <= 0.0: return
	timer = maxf(0.0, timer - delta)
	if is_instance_valid(_dial):
		_dial.global_position = foot(player.global_position)
		_hand_pivot.rotation.y = -TAU * spent()
	if timer <= 0.0: _hide_dial()

## 吊诡: a physical blow slipped while the dial runs fills her wave.
func on_evade(_attacker: Enemy) -> void:
	if timer <= 0.0: return
	player.add_charge(player.wave_hits_needed())

func interrupt() -> void:
	pass

func reset() -> void:
	super()
	timer = 0.0
	_hide_dial()

# --- The dial at her feet ----------------------------------------------------------

## A flat ring of twelve hour notches and the shadow hand, riding with her.
func _show_dial() -> void:
	_hide_dial()
	if not is_instance_valid(game()): return
	var c := OperatorVfx.colours(id)
	_dial = Node3D.new()
	game().add_child(_dial)
	_dial.global_position = foot(player.global_position)
	var r := DIAL_RADIUS
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.05
	torus.outer_radius = r
	torus.rings = 48
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.material_override = _flat(Color(c.main.r, c.main.g, c.main.b, 0.45))
	_dial.add_child(ring)
	for i in range(12):
		var notch := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.01, 0.16 if i % 3 == 0 else 0.08)
		notch.mesh = box
		notch.material_override = _flat(Color(c.hot.r, c.hot.g, c.hot.b, 0.6 if i % 3 == 0 else 0.35))
		var at := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0)
		notch.position = at * (r - 0.12)
		notch.basis = Basis.looking_at(at)
		_dial.add_child(notch)
	# The hand: a long dark shadow with a pale edge, pointing from her feet.
	_hand = MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.08, 0.01, r * 0.9)
	_hand.mesh = blade
	_hand.material_override = _flat(Color(c.dark.r, c.dark.g, c.dark.b, 0.75))
	var edge := MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(0.03, 0.012, r * 0.85)
	edge.mesh = line
	edge.material_override = _flat(Color(c.hot.r, c.hot.g, c.hot.b, 0.7))
	edge.position = Vector3(0.035, 0.002, 0)
	_hand.add_child(edge)
	var pivot := Node3D.new()
	_dial.add_child(pivot)
	# Noon is up the screen: the camera looks along +Z, so +Z (BACK) is up.
	_hand.position = Vector3(0, 0.01, r * 0.45)
	pivot.add_child(_hand)
	_hand_pivot = pivot

func _hide_dial() -> void:
	if is_instance_valid(_dial): _dial.queue_free()
	_dial = null
	_hand = null
	_hand_pivot = null

static func _flat(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = colour
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2
	return mat
