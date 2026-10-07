class_name Loot
extends Node3D

## Ported from DownfallPrototype.Loot, extended for the M2 loot economy:
## a drop is either a plain gold pile (source behavior) or an Item bound for
## GameManager.inventory. Kept separate fields rather than folding gold into
## Item so the original gold pickup path stays untouched.

var game: GameManager
var item: Item  # null means this drop is a plain gold pile
var gold_value: int = 1   # 赤金 (a plain pile; the field now drops 赤金 as items)
var pickup_delay := 0.0
var is_search_point := false
## Vault spoils stay sealed until the vault's guardian is dead, so the room is
## a fight rather than a free pickup at the end of a long walk.
var sealed := false

func _ready() -> void:
	add_to_group("loot")
	var is_item := item != null
	var color := Color(0.35, 0.55, 1.0) if is_item else Color(1.0, 0.75, 0.15)
	if is_item:
		color = item.rarity_color()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4 if is_item else 0.35
	sphere.height = sphere.radius * 2.0
	mesh.mesh = sphere
	if is_search_point:
		add_to_group("search_points")
		var chest := BoxMesh.new()
		chest.size = Vector3(1.25, 0.8, 0.85)
		mesh.mesh = chest
		color = Color("827357")
		var label := Label3D.new()
		label.text = "补给箱"
		label.position.y = 1.1
		label.font_size = 24
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	elif is_item and not item.material_id.is_empty():
		# A material: a small crate in its PRTS rarity colour.
		var crate := BoxMesh.new()
		crate.size = Vector3(0.45, 0.35, 0.45)
		mesh.mesh = crate
	elif is_item:
		match item.effect:
			"raw_ore":
				var crystal := PrismMesh.new()
				crystal.size = Vector3(0.55, 1.0, 0.55)
				mesh.mesh = crystal
				color = Color("ee8a24")
			"riot_shield":
				var shield := BoxMesh.new()
				shield.size = Vector3(0.85, 0.9, 0.2)
				mesh.mesh = shield
				color = Color("54c8d4")
			"frozen_relic":
				var ring := TorusMesh.new()
				ring.inner_radius = 0.18
				ring.outer_radius = 0.42
				mesh.mesh = ring
				color = Color("be97f1")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if is_item and not is_search_point:
		mat.emission_enabled = true
		mat.emission = color
	mesh.material_override = mat
	add_child(mesh)
	if is_item and is_notable(): _add_beam(color)

## Rare equipment, special gear and ★4+ materials get a light beam (掉落物策划案 §6).
func is_notable() -> bool:
	if item == null: return false
	if not item.special.is_empty() or not item.exclusive_region.is_empty(): return true
	if not item.material_id.is_empty(): return MaterialCatalog.star(item.material_id) >= 4
	return item.is_equippable() and item.rarity >= 2

func _add_beam(color: Color) -> void:
	var beam := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	var tall := not item.special.is_empty()
	shape.top_radius = 0.06
	shape.bottom_radius = 0.12
	shape.height = 5.0 if tall else 3.0
	beam.mesh = shape
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(color, 0.45)
	glow.emission_enabled = true
	glow.emission = color
	beam.material_override = glow
	beam.position.y = shape.height * 0.5
	add_child(beam)
	if is_instance_valid(game) and game.sound != null: game.sound.play("build")

func _process(delta: float) -> void:
	if is_instance_valid(game) and not game.simulation_active(): return
	pickup_delay -= delta
	if pickup_delay > 0: return
	if not is_search_point: rotate_y(deg_to_rad(90.0) * delta)
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	if sealed: return
	if global_position.distance_to(game.player.global_position) < 1.25:
		if item != null:
			if not game.passes_pickup_filter(item): return
			if game.try_collect(item):
				queue_free()
			elif item.is_stackable() and item.quantity <= 0:
				queue_free()
			else:
				# Retry in a moment, not every frame (keeps the message readable).
				pickup_delay = 1.0
			# else: pack is full — leave the drop for the player to retry
			# after freeing up space, rather than destroying it silently.
		else:
			game.add_gold(gold_value)
			queue_free()
