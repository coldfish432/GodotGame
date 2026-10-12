class_name EnemyAttackVfx
extends Node3D
## Physical marks and fragments appear only when an attack is released.
var game: GameManager
var age := 0.0
var duration := 0.15
var kind := "slash"
var direction := Vector3.RIGHT
var reach := 2.4
var owner_enemy: Enemy
## The ally a 陷落雪祀 orb hastens: the link follows it.
var target_enemy: Enemy
## A swing's width in degrees (its profile's angle).
var spread := 100.0
## Enemy weapon trails are rust, never Lappland's white / grey-blue arcs, so a
## swing on screen always says whose it is.
const TRAIL := Color("a24a36")

static func part(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = point
	return node

static func stroke(parent: Node3D, start: Vector3, end: Vector3, width: float, color: Color) -> MeshInstance3D:
	var line := part(parent, (start + end) * 0.5, Vector3(width, width, maxf(0.001, start.distance_to(end))), color)
	if start.distance_squared_to(end) > 0.00001: line.basis = Basis.looking_at((end - start).normalized())
	return line

static func spawn(manager: GameManager, point: Vector3, forward: Vector3, type: String, length: float = 2.4, angle: float = 100.0) -> EnemyAttackVfx:
	var fx := EnemyAttackVfx.new()
	fx.game = manager
	fx.kind = type
	fx.direction = Vector3(forward.x, 0, forward.z).normalized() if Vector2(forward.x, forward.z).length_squared() > 0.0001 else Vector3.RIGHT
	fx.reach = length
	fx.spread = angle
	manager.add_child(fx)
	fx.global_position = point
	fx._build()
	return fx

func _build() -> void:
	var side := direction.cross(Vector3.UP)
	match kind:
		"cuts":
			duration = 0.15
			for i in range(3):
				var start := side * (i - 1) * 0.22
				stroke(self, start - direction * 0.3, start + direction * 0.5, 0.065, Color("6b2428"))
		"ice":
			duration = 0.3
			for i in range(6):
				var ray := Vector3(cos(i * TAU / 6), 0, sin(i * TAU / 6))
				stroke(self, Vector3.ZERO, ray * 0.8, 0.065, Color("bbdfea"))
				part(self, ray * 0.6 + Vector3.UP * 0.15, Vector3(0.09, 0.14, 0.09), Color("e4eff4"))
		"wood":
			duration = 0.18
			for i in range(4):
				stroke(self, side * (i - 1.5) * 0.12, side * (i - 1.5) * 0.2 - direction * 0.18 + Vector3.UP * 0.12, 0.06, Color("bc9761"))
		"muzzle":
			duration = 0.06
			stroke(self, Vector3.ZERO, direction * 0.27, 0.10, Color("fff3c7"))
		"sector":
			duration = 0.10
			_arc(reach, spread, 0.065, TRAIL)
		"thrust":
			duration = 0.10
			stroke(self, Vector3.ZERO, direction * reach, 0.07, TRAIL)
		"bite":
			# Slug connects: amber originium sparks spray from the jaws.
			duration = 0.16
			for i in range(5):
				var ray := direction.rotated(Vector3.UP, deg_to_rad(-60 + i * 30))
				stroke(self, ray * 0.1, ray * 0.45 + Vector3.UP * 0.1 * (i % 2), 0.07, Color("ffb347"))
		"stab":
			# Fist blade connects: a rust X at the point of impact.
			duration = 0.14
			for tilt in [-45.0, 45.0]:
				var ray := direction.rotated(Vector3.UP, deg_to_rad(tilt))
				stroke(self, -ray * 0.3, ray * 0.3, 0.08, TRAIL)

		# --- 新敌人攻击动画与预警设计案 §四 ------------------------------------------
		"shield_flash":
			# 机动盾兵: a white edge flashes along the shield face.
			duration = 0.10
			stroke(self, -side * 0.45, side * 0.45, P * 1.5, Color("f4f6f4"))
		"claw_cracks":
			# 高能源石虫: two orange cracks where the claws land, three sparks.
			duration = 0.20
			for tilt in [-18.0, 18.0]:
				var ray := direction.rotated(Vector3.UP, deg_to_rad(tilt))
				stroke(self, -ray * 0.15, ray * 0.45, P, Color("ff9a4a"))
			for i in range(3): part(self, side * (i - 1) * 0.25 + Vector3.UP * 0.1, Vector3.ONE * P, Color("ffd875"))
		"ground_shock", "ground_shock_purple", "ground_shock_big":
			# 武装人员 / 灰尾香主 / 粉碎攻坚手: a shock ring and cracks; the third
			# blow's ring is wider and throws up stones.
			duration = 0.30
			var colour := Color("c060a0") if kind == "ground_shock_purple" else Color("b8b4aa")
			var big := kind == "ground_shock_big"
			_ring(reach * (0.9 if big else 0.7), P * 1.5, colour)
			for i in range(2):
				var ray := direction.rotated(Vector3.UP, deg_to_rad(70 + i * 140))
				stroke(self, Vector3.ZERO, ray * reach * 0.6, P, Color("4a4640"))
			if big:
				for i in range(3): part(self, direction.rotated(Vector3.UP, i * TAU / 3) * 0.4 + Vector3.UP * 0.2, Vector3.ONE * P * 2, Color("8a8478"))
		"crystal_spikes":
			# 术师: three black originium spikes lit orange inside; they shatter.
			duration = 0.40
			for i in range(3):
				var at := direction.rotated(Vector3.UP, i * TAU / 3 + 0.4) * reach * 0.45
				var tall := (4 + i) * P
				part(self, at + Vector3.UP * tall * 0.5, Vector3(P * 2, tall, P * 2), Color("16161a"))
				part(self, at + Vector3.UP * tall * 0.45, Vector3(P, tall * 0.6, P * 2.1), Color("ff8a2a"))
		"rune":
			# 歪曲施法者: two dark blue rings and four rays, spreading out.
			duration = 0.30
			_ring(reach * 0.5, P, Color("3a4ab0"))
			_ring(reach * 0.85, P, Color("3a4ab0"))
			for i in range(4):
				var ray := direction.rotated(Vector3.UP, i * TAU / 4 + PI / 4)
				stroke(self, ray * reach * 0.5, ray * reach * 0.85, P, Color("5a6ad0"))
		"slash_line":
			# 寻仇者's thrust: a straight rust stroke.
			duration = 0.10
			stroke(self, Vector3.ZERO, direction * reach, 0.07, TRAIL)
		"slash_arc":
			# ...and its back-cut: a short arc round itself.
			duration = 0.12
			_arc(reach, 160.0, 0.07, TRAIL)
		"splinter_arc":
			# 木裂战士: a teal cut.
			duration = 0.14
			_arc(reach * 0.8, 120.0, 0.08, Color("4ab8a0"))
		"rope":
			# The lasso: a 1 px brown line, out in 0.2 s and back in 0.15 s.
			duration = 0.35
			var line := stroke(self, Vector3.ZERO, direction, P, Color("7a5230"))
			line.name = "Rope"
		"dust", "snow_puff":
			duration = 0.30
			part(self, Vector3.ZERO, Vector3.ONE * P * 3, Color("9a948a") if kind == "dust" else Color("e8eef2"))
		"glide_trail":
			duration = 0.30
			stroke(self, Vector3.ZERO, -direction * 0.3, P, Color("a8c8f0"))
		"wood_chip":
			duration = 0.40
			part(self, side * randf_range(-0.2, 0.2) + direction * 0.05, Vector3.ONE * P, Color("a8b8a0"))
		"vine_burst":
			# 巨壳藤蔓: four leaves fly out.
			duration = 0.30
			for i in range(4):
				var ray := direction.rotated(Vector3.UP, deg_to_rad(-60 + i * 40))
				part(self, ray * 0.2 + Vector3.UP * 0.1 * (i % 2), Vector3(P * 2, P, P), Color("6aa84a"))
		"horn_arc":
			# 岩角兽: the horns flick up in a white arc; a puff of dust.
			duration = 0.10
			_arc(0.5, 120.0, P, Color("f4f6f4"))
			part(self, Vector3.DOWN * 0.3, Vector3.ONE * P * 3, Color("9a948a"))
		"haste_link":
			# 陷落雪祀: a thin purple line to the hastened ally, a ring round it.
			duration = 0.30
			stroke(self, Vector3.ZERO, direction * reach, P, Color("b070f0"))
			var halo := Node3D.new()
			halo.name = "Halo"
			add_child(halo)
			halo.position = direction * reach + Vector3.DOWN * 0.3
			for i in range(8):
				var a := Vector3(cos(i * TAU / 8), 0, sin(i * TAU / 8)) * 0.5
				var b := Vector3(cos((i + 1) * TAU / 8), 0, sin((i + 1) * TAU / 8)) * 0.5
				stroke(halo, a, b, P, Color("c890ff"))

const P := 1.0 / 15.0

## An arc of strokes `degrees` wide, centred on `direction`.
func _arc(radius: float, degrees: float, width: float, colour: Color) -> void:
	var steps := maxi(4, int(degrees / 9.0))
	for i in range(steps):
		var a := direction.rotated(Vector3.UP, deg_to_rad(-degrees * 0.5 + i * degrees / steps)) * radius
		var b := direction.rotated(Vector3.UP, deg_to_rad(-degrees * 0.5 + (i + 1) * degrees / steps)) * radius
		stroke(self, a, b, width, colour)

func _ring(radius: float, width: float, colour: Color) -> void:
	for i in range(20):
		var a := Vector3(cos(i * TAU / 20), 0, sin(i * TAU / 20)) * radius
		var b := Vector3(cos((i + 1) * TAU / 20), 0, sin((i + 1) * TAU / 20)) * radius
		stroke(self, a, b, width, colour)

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	if is_instance_valid(owner_enemy) and owner_enemy.hitstop_remaining > 0: return
	if kind == "thrust" and is_instance_valid(owner_enemy): global_position = owner_enemy.global_position + Vector3.UP * 0.2
	age += delta
	var t := clampf(age / duration, 0.0, 1.0)
	if kind in ["ice", "wood"]:
		for child in get_children():
			if child.position.y > 0.1: child.position += (Vector3.UP + child.position.normalized()) * delta
	match kind:
		"rope":
			# Out over 0.2 s, back over 0.15 s, from the thrower's hand.
			if is_instance_valid(owner_enemy): global_position = owner_enemy.global_position + Vector3.UP * 0.3
			var out := age / 0.2 if age < 0.2 else 1.0 - (age - 0.2) / 0.15
			var length := maxf(0.001, clampf(out, 0.0, 1.0) * reach)
			var line := get_node("Rope") as MeshInstance3D
			(line.mesh as BoxMesh).size.z = length
			line.position = direction * length * 0.5
		"rune", "ground_shock", "ground_shock_purple", "ground_shock_big":
			scale = Vector3.ONE * (1.0 + t * 0.35)
		"dust", "snow_puff":
			scale = Vector3.ONE * (1.0 + t)
			position.y += delta * 0.6
		"wood_chip", "vine_burst":
			for child in get_children():
				child.position += (child.position.normalized() * 1.5 + Vector3.DOWN * t * 2.0) * delta
		"crystal_spikes":
			# The last quarter: the spikes break apart.
			if t > 0.75:
				for child in get_children(): child.position += Vector3(child.position.x, 0, child.position.z).normalized() * delta * 2.0
		"haste_link":
			if is_instance_valid(target_enemy) and has_node("Halo"): (get_node("Halo") as Node3D).global_position = target_enemy.global_position + Vector3.DOWN * 0.3
	if age >= duration: queue_free()
