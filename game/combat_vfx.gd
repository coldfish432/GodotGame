class_name CombatVfx
extends Node3D
## Painted pixel slashes and wave plus small unlit geometry (sparks, the
## Sundial hand). All player effects stay at <= 70% opacity.
const WHITE := Color("e8ecf2")
const BLUE := Color("8a9bb0")
const SHADOW := Color("1c1a24")
const PURPLE := Color("8e5cff")
const LIGHT := Color("cdb4ff")
## Amiya (Guard): black blade, cyan glow (阿米娅攻击动作与特效设计案 §二).
const CYAN := Color("33d6c6")
const CYAN_LIGHT := Color("d2fff7")
const NAVY := Color("24305a")
const PIXEL := 1.0 / 15.0
## Painted effects baked by godot_assets/prepare_lappland_vfx.py: one texel per
## world pixel, attack direction pointing to the top of each texture.
const SLASH_TEXTURES := [
	preload("res://godot_assets/lappland_vfx_slash_1.png"),
	preload("res://godot_assets/lappland_vfx_slash_2.png"),
	preload("res://godot_assets/lappland_vfx_slash_3.png"),
]
const WAVE_TEXTURE := preload("res://godot_assets/lappland_vfx_wave.png")
## Amiya (Guard), painted by Sol (batch A2, A2_vfx_brief_v1.md): one slim
## one-handed blade, dark core and cyan edges; the finisher alone has a bright
## core. Top of each texture = attack direction, like Lappland's.
const AMIYA_SWEEP := preload("res://godot_assets/amiya_vfx_sweep.png")
const AMIYA_DOUBLE := [preload("res://godot_assets/amiya_vfx_double_a.png"), preload("res://godot_assets/amiya_vfx_double_b.png")]
const AMIYA_THRUST := preload("res://godot_assets/amiya_vfx_thrust.png")
const AMIYA_CUTS := [preload("res://godot_assets/amiya_vfx_cut_1.png"), preload("res://godot_assets/amiya_vfx_cut_2.png"), preload("res://godot_assets/amiya_vfx_cut_3.png")]
const AMIYA_FINISHER := preload("res://godot_assets/amiya_vfx_finisher.png")
const AMIYA_BLINK := preload("res://godot_assets/amiya_vfx_blink.png")
const AMIYA_SPARK := preload("res://godot_assets/amiya_vfx_spark.png")
## 奔夜's return cut sits this far beyond the first (6 texels, per the brief).
const DOUBLE_OFFSET := 0.4
## How far ahead of her feet each slash texture is centred (world units).
const SLASH_CENTRES := [1.6, 1.7, 1.7]
## The Sundial X is thrown forward like the sword wave but never leaves as a
## projectile: it surges from just ahead of her to SURGE_TO and fades, with two
## fainter echoes lagging behind it.
const SURGE_FROM := 0.8
const SURGE_TO := 2.6
const SURGE_ECHO_GAP := 0.45
const SURGE_OPACITY := [0.7, 0.4, 0.2]
var age := 0.0
var duration := 0.12
var kind := "slash"
var stage := 0
var magical := false
## Swing speed multiplier (attack speed); scales lifetime and arc spin.
var rate := 1.0
var game: GameManager
var _parts: Array[MeshInstance3D] = []
var _ghost: Sprite3D

static func spawn(parent: Node3D, point: Vector3, direction: Vector3, type: String, combo: int = 0, magic: bool = false) -> CombatVfx:
	var fx := CombatVfx.new()
	fx.game = parent as GameManager
	fx.kind = type
	fx.stage = combo
	fx.magical = magic
	parent.add_child(fx)
	fx.global_position = point
	if direction.length_squared() > 0.001: fx.basis = Basis.looking_at(direction.normalized())
	fx._build()
	return fx

## One of the recruits' painted effects (Sol batches <CODE>2): `frames` cells
## laid side by side in `texture`. "ground" lies flat with its top toward
## `direction`, centred `ahead` in front; "billboard" faces the camera at
## `height`. Frames run once over `seconds`, or cycle at `fps` when it is
## set (persistent effects: free them yourself, seconds can be large).
static func painted(parent: Node3D, point: Vector3, direction: Vector3, texture: Texture2D, frames: int = 1, seconds: float = 0.15,
		mount: String = "ground", ahead: float = 0.0, height: float = 0.05, fps: float = 0.0, fade: bool = true) -> CombatVfx:
	var fx := CombatVfx.new()
	fx.game = parent as GameManager
	if fx.game == null and parent is Player: fx.game = (parent as Player).game
	fx.kind = "painted"
	fx.duration = seconds
	fx.frame_fps = fps
	fx.fades = fade
	parent.add_child(fx)
	fx.global_position = point
	if direction.length_squared() > 0.001 and mount == "ground": fx.basis = Basis.looking_at(Vector3(direction.x, 0, direction.z).normalized() if Vector2(direction.x, direction.z).length_squared() > 0.0001 else Vector3.FORWARD)
	if texture == null: return fx
	var cell := Vector2(texture.get_width() / maxi(1, frames), texture.get_height())
	for i in range(maxi(1, frames)):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(i * cell.x, 0, cell.x, cell.y)
		var part := fx._decal(frame, ahead, height, Color.WHITE)
		if mount == "billboard":
			part.basis = Basis.IDENTITY
			part.position = Vector3(0, height, 0)
			(part.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		if frames > 1: part.set_meta("pframe", i)
		fx.frame_count = maxi(1, frames)
	return fx

var frame_fps := 0.0
var frame_count := 1
var fades := true

## Faster attacks play the slash faster so it never outlives the next swing.
func speed_up(multiplier: float) -> CombatVfx:
	if kind in ["slash", "amiya_slash"] and multiplier > 0:
		rate = multiplier
		duration /= multiplier
	return self

static func material(color: Color, opacity: float = 0.65) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, minf(opacity, 0.7))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	return mat

func _part(mesh: Mesh, color: Color, opacity: float = 0.65) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material(color, opacity)
	part.material_override.render_priority = 1 if color == SHADOW else (3 if color in [WHITE, LIGHT] else 2)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	_parts.append(part)
	return part

func _box(size: Vector3, color: Color, point: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := _part(mesh, color)
	part.position = point
	return part

func _build() -> void:
	match kind:
		"slash":
			duration = 0.2 if stage == 2 else 0.12
			# The released wave's swing is tinted toward the arts purple.
			var tint := LIGHT if magical else Color.WHITE
			if stage == 2:
				# Echoes first so the leading X draws on top of them.
				for echo in range(2, -1, -1):
					var x := _decal(SLASH_TEXTURES[2], SURGE_FROM, 0.04 + (2 - echo) * 0.004, tint)
					x.set_meta("surge", echo)
					x.set_meta("opacity", SURGE_OPACITY[echo])
			else:
				_decal(SLASH_TEXTURES[stage], SLASH_CENTRES[stage], 0.04 + stage * 0.01, tint)
			if stage == 2:
				# A lone 1 px shadow line vanished on the mine and city floors;
				# the shadow now frames a pale core so it reads on every map.
				var hand := _box(Vector3(PIXEL * 3, 0.02, 3.4 + PIXEL * 2), SHADOW, Vector3(0, 0.015, -1.7))
				hand.set_meta("hand", true)
				var hand_core := _box(Vector3(PIXEL, 0.02, 3.4), BLUE, Vector3(0, 0.03, -1.7))
				hand_core.set_meta("hand", true)
		"spark", "burst", "mist":
			duration = 0.2 if kind == "mist" else (0.15 if magical else 0.1)
			if kind == "burst": duration = 0.2
			var count := 6 if magical else 4
			for i in range(count):
				var size := Vector3.ONE * PIXEL * (2 if kind == "mist" else 1)
				var outline := _box(size + Vector3.ONE * PIXEL, SHADOW, Vector3.ZERO)
				var chip := _box(size, PURPLE if magical else WHITE, Vector3.ZERO)
				var drift := Vector3(cos(i * TAU / count + PI / 4), 0.4 + (i % 2) * 0.5, sin(i * TAU / count + PI / 4))
				outline.set_meta("drift", drift)
				chip.set_meta("drift", drift)
			if kind == "spark":
				for tilt in [-0.7, 0.7]:
					var border := _box(Vector3(0.5 + 2 * PIXEL, PIXEL * 3, PIXEL * 3), SHADOW, Vector3.ZERO)
					border.rotation.y = tilt
					var line := _box(Vector3(0.5, PIXEL, PIXEL), LIGHT if magical else WHITE, Vector3.ZERO)
					line.rotation.y = tilt
		"amiya_slash":
			match stage:
				0: _decal(AMIYA_SWEEP, SLASH_CENTRES[0], 0.04, Color.WHITE)
				1:
					# 奔夜: the same blade cuts and cuts back, the return a beat
					# behind and further out (用户 2026-10-09: 符合单手剑).
					duration = 0.16
					_decal(AMIYA_DOUBLE[0], SLASH_CENTRES[0], 0.04, Color.WHITE)
					_decal(AMIYA_DOUBLE[1], SLASH_CENTRES[0] + DOUBLE_OFFSET, 0.05, Color.WHITE).set_meta("late", true)
				_:
					# Thrust: the wedge's bottom edge sits at her feet.
					_decal(AMIYA_THRUST, AMIYA_THRUST.get_height() * PIXEL * 0.5, 0.04, Color.WHITE)
		"amiya_spark":
			# Two painted frames: burst, then chips further out.
			duration = 0.12
			for i in range(2):
				var frame := AtlasTexture.new()
				frame.atlas = AMIYA_SPARK
				frame.region = Rect2(i * 11, 0, 11, 11)
				var part := _decal(frame, 0.0, 0.3, Color.WHITE)
				part.set_meta("frame", i)
		"flurry":
			# One 绝影 cut at chest height. The caller steps five of them
			# near-parallel across the target: one sword striking again. The
			# painted cut runs across its texture, so turn it onto the slant.
			duration = 0.1
			var cut_part := _decal(AMIYA_CUTS[randi() % AMIYA_CUTS.size()], 0.0, 0.8, Color.WHITE)
			cut_part.basis = Basis(Vector3.UP, PI * 0.5) * cut_part.basis
		"finisher":
			# One heavy straight cleave through the target, bright core: the
			# only bright-cored cut she has.
			duration = 0.18
			_decal(AMIYA_FINISHER, 0.0, 0.05, Color.WHITE)
		"strike_flash":
			# A 绝影 strike while she is unseen: a burst of blade light on the
			# enemy at chest height, there and gone in a few frames.
			duration = 0.09
			var frame := AtlasTexture.new()
			frame.atlas = AMIYA_SPARK
			frame.region = Rect2(0, 0, 11, 11)
			_decal(frame, 0.0, 0.85, Color.WHITE).scale = Vector3.ONE * 2.0
		"blink":
			# Her path, tiled from her start point to where she lands; stretch()
			# sets the length.
			duration = 0.2
			var trail := _decal(AMIYA_BLINK, 0.5, 0.03, Color.WHITE)
			trail.set_meta("blink", true)
		"wave":
			duration = 999.0 # lifetime belongs to SwordWave
			# Crescent at the wave's position, its painted echoes trailing behind.
			var length := WAVE_TEXTURE.get_height() * PIXEL
			_decal(WAVE_TEXTURE, -(length * 0.5 - 0.35), 0.02, Color.WHITE)

## A painted effect lying flat on the ground, its top edge toward this
## effect's forward (-Z), centred `ahead` units in front of the origin.
func _decal(texture: Texture2D, ahead: float, height: float, tint: Color) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = texture.get_size() * PIXEL
	var part := _part(quad, tint, 0.7)
	var mat := part.material_override as StandardMaterial3D
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.render_priority = 2
	part.set_meta("opacity", 0.7)
	# Quad X -> right, quad Y (texture up) -> forward, quad normal -> up.
	part.basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	part.position = Vector3(0, height, -ahead)
	return part

## Lay a "blink" trail `length` world units ahead, repeating its tile.
func stretch(length: float) -> CombatVfx:
	length = maxf(PIXEL, length)
	for part in _parts:
		if not part.has_meta("blink"): continue
		var quad := part.mesh as QuadMesh
		quad.size.y = length
		part.position.z = -length * 0.5
		var mat := part.material_override as StandardMaterial3D
		mat.uv1_scale = Vector3(1, length / (AMIYA_BLINK.get_height() * PIXEL), 1)
		mat.texture_repeat = true
	return self

static func afterimage(parent: GameManager, sprite: AnimatedSprite3D, point: Vector3, opacity: float, tint: Color = BLUE) -> CombatVfx:
	var fx := CombatVfx.new()
	fx.game = parent
	fx.kind = "ghost"
	fx.duration = 0.25
	parent.add_child(fx)
	fx.global_position = point
	fx._ghost = Sprite3D.new()
	fx._ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	fx._ghost.flip_h = sprite.flip_h
	fx._ghost.pixel_size = sprite.pixel_size
	fx._ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fx._ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fx._ghost.modulate = Color(tint, opacity)
	fx._ghost.set_meta("opacity", opacity)
	fx._ghost.position.y = sprite.position.y
	fx.add_child(fx._ghost)
	return fx

func _process(delta: float) -> void:
	# Effects pause with the game, not with the base: a dash's afterimages in
	# the hall must fade too (用户 2026-10-07).
	if is_instance_valid(game) and not (game.simulation_active() or game.base_walk_active()): return
	age += delta
	if age >= duration:
		queue_free()
		return
	var progress := age / duration
	for part in _parts:
		var mat := part.material_override as StandardMaterial3D
		mat.albedo_color.a = float(part.get_meta("opacity", 0.65)) * (1.0 if kind == "wave" or not fades else 1.0 - progress)
		if part.has_meta("pframe"):
			var shown := (int(age * frame_fps) % frame_count) if frame_fps > 0.0 else mini(frame_count - 1, int(progress * frame_count))
			part.visible = shown == int(part.get_meta("pframe"))
		if part.has_meta("drift"): part.position = part.get_meta("drift") * age * 7.0
		if part.has_meta("late"): part.visible = progress >= 0.4
		if part.has_meta("frame"): part.visible = int(progress * 2.0) == int(part.get_meta("frame"))
		if part.has_meta("surge"):
			# Ease out: fast off the blades, settling as it fades.
			var travel := 1.0 - (1.0 - progress) * (1.0 - progress)
			var ahead := SURGE_FROM + (SURGE_TO - SURGE_FROM) * travel - int(part.get_meta("surge")) * SURGE_ECHO_GAP * travel
			part.position.z = -ahead
		if part.has_meta("hand"):
			# Pivot at the feet (the fx origin) like a clock hand, not mid-line.
			if not part.has_meta("rest"): part.set_meta("rest", part.position)
			part.rotation.y = lerpf(-0.7, 0.7, progress)
			part.position = Basis(Vector3.UP, part.rotation.y) * (part.get_meta("rest") as Vector3)
	if kind in ["slash", "amiya_slash"] and stage != 2:
		# Sweeps swing around her; the Sundial X surges straight ahead instead.
		rotation.y += delta * rate * (-4.0 if stage == 1 else 4.0)
		scale.y = 1.0 - progress * 0.8
	if kind == "wave": position.x = PIXEL * (1 if int(age * 12) % 2 else -1)
	if is_instance_valid(_ghost): _ghost.modulate.a = float(_ghost.get_meta("opacity")) * (1 - progress)
	if kind == "strike_flash": scale = Vector3.ONE * (1.0 + progress * 1.5)

