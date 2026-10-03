class_name Loot
extends Node3D

## Ported from DownfallPrototype.Loot, extended for the M2 loot economy:
## a drop is either a plain gold pile (source behavior) or an Item bound for
## GameManager.inventory. Kept separate fields rather than folding gold into
## Item so the original gold pickup path stays untouched.

var game: GameManager
var item: Item  # null means this drop is a plain gold pile
var gold_value: int = 10
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
		color = [Color("a9bacb"), Color("86d2b7"), Color("bc88e8")][item.rarity]
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
			if game.try_collect(item):
				queue_free()
			# else: pack is full — leave the drop for the player to retry
			# after freeing up space, rather than destroying it silently.
		else:
			game.add_gold(gold_value)
			queue_free()
