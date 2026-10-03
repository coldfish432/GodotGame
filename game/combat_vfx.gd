class_name CombatVfx
extends Node3D
## Painted pixel slashes and wave plus small unlit geometry (sparks, the
## Sundial hand). All player effects stay at <= 70% opacity.
const WHITE := Color("e8ecf2")
const BLUE := Color("8a9bb0")
const SHADOW := Color("1c1a24")
const PURPLE := Color("8e5cff")
const LIGHT := Color("cdb4ff")
const PIXEL := 1.0 / 15.0
## Painted effects baked by godot_assets/prepare_lappland_vfx.py: one texel per
## world pixel, attack direction pointing to the top of each texture.
const SLASH_TEXTURES := [
	preload("res://godot_assets/lappland_vfx_slash_1.png"),
	preload("res://godot_assets/lappland_vfx_slash_2.png"),
	preload("res://godot_assets/lappland_vfx_slash_3.png"),
]
const WAVE_TEXTURE := preload("res://godot_assets/lappland_vfx_wave.png")
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

## Faster attacks play the slash faster so it never outlives the next swing.
func speed_up(multiplier: float) -> CombatVfx:
	if kind == "slash" and multiplier > 0:
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

static func afterimage(parent: GameManager, sprite: AnimatedSprite3D, point: Vector3, opacity: float) -> CombatVfx:
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
	fx._ghost.modulate = Color(BLUE, opacity)
	fx._ghost.set_meta("opacity", opacity)
	fx._ghost.position.y = sprite.position.y
	fx.add_child(fx._ghost)
	return fx

func _process(delta: float) -> void:
	if is_instance_valid(game) and not game.simulation_active(): return
	age += delta
	if age >= duration:
		queue_free()
		return
	var progress := age / duration
	for part in _parts:
		var mat := part.material_override as StandardMaterial3D
		mat.albedo_color.a = float(part.get_meta("opacity", 0.65)) * (1.0 if kind == "wave" else 1.0 - progress)
		if part.has_meta("drift"): part.position = part.get_meta("drift") * age * 7.0
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
	if kind == "slash" and stage != 2:
		# Sweeps swing around her; the Sundial X surges straight ahead instead.
		rotation.y += delta * rate * (-4.0 if stage == 1 else 4.0)
		scale.y = 1.0 - progress * 0.8
	if kind == "wave": position.x = PIXEL * (1 if int(age * 12) % 2 else -1)
	if is_instance_valid(_ghost): _ghost.modulate.a = float(_ghost.get_meta("opacity")) * (1 - progress)
