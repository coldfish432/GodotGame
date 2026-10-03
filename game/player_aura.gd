class_name PlayerAura
extends Node3D
var player: Player
var age := 0.0
var dots: Array[Sprite3D] = []
var lines: Array[Sprite3D] = []
var shadow: MeshInstance3D
var gleam: Sprite3D

func _ready() -> void:
	player = get_parent() as Player
	for i in range(6):
		var sprite := Sprite3D.new()
		var img := Image.create(4 if i < 3 else 3, 4 if i < 3 else 8, false, Image.FORMAT_RGBA8)
		img.fill(CombatVfx.SHADOW)
		img.fill_rect(Rect2i(1, 1, img.get_width() - 2, img.get_height() - 2), Color.WHITE)
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.pixel_size = CombatVfx.PIXEL
		sprite.no_depth_test = true
		sprite.render_priority = 5
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		if i < 3: dots.append(sprite)
		elif i < 5: lines.append(sprite)
		else: gleam = sprite
	shadow = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.5
	disk.bottom_radius = 0.5
	disk.height = 0.015
	shadow.mesh = disk
	shadow.material_override = CombatVfx.material(CombatVfx.SHADOW, 0.4)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if is_instance_valid(player.game) and not (player.game.simulation_active() or player.game.base_walk_active()): return
	age += delta
	global_basis = Basis.IDENTITY
	shadow.global_position = Vector3(player.global_position.x, 0.045, player.global_position.z)
	shadow.visible = not player.invulnerable
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if is_instance_valid(camera) else Vector3.RIGHT
	# Pips sit on the ground just camera-side of the feet so they read as
	# "under her" and never cover the sprite (they skip the depth test).
	var toward_camera := Vector3.BACK
	if is_instance_valid(camera):
		toward_camera = Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
	for i in range(3):
		dots[i].visible = player.has_sword_wave() and player.sword_charge > i
		dots[i].position = right * (i - 1) * 0.27 + toward_camera * (0.4 - abs(i - 1) * 0.08) + Vector3.UP * -0.62
		dots[i].modulate = Color(CombatVfx.PURPLE if player.sword_charge == 3 else CombatVfx.BLUE, 0.7)
	for i in range(2):
		lines[i].visible = player.sword_charge == 3 and player.has_sword_wave()
		var angle := float(int(age * 4) % 2) * PI * 0.5 + i * PI
		lines[i].position = right * cos(angle) * 0.85 + Vector3.UP * (0.45 + sin(angle) * 0.35)
		lines[i].modulate = Color(CombatVfx.PURPLE, 0.7)
	gleam.visible = player.has_sword_wave() and player.sword_charge == 3 and fmod(age, 0.5) < 0.083
	gleam.position = right * 0.4 + Vector3.UP * 0.1
	gleam.modulate = Color(CombatVfx.LIGHT, 0.7)
