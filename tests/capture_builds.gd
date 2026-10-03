extends SceneTree

## Rendered frames of the relic system (局内构筑与数值策划案 §8.5): the offer
## cards, a built-up HUD, combat numbers and enemy health bars, and the
## inventory's stat sheet. Writes evidence/builds-*.png.

var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 10) -> void:
	for i in range(count): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func capture(label: String) -> void:
	await step(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/builds-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	await game.start_contract("snow")
	game.builds.assign(["howl", "wolf_fang"])
	game.player._recompute_stats()
	game.player.teleport(game.world_map.buff_position)
	game._interact()
	await capture("offer")
	game.choose_build(game.build_offers[0].id)
	game.builds.assign(["howl", "wolf_fang", "pale_spark", "ember_wave", "blade_edge", "whetstone", "moon_blades"])
	game.player._recompute_stats()
	game.player.reset_floor_state()
	var stage: Vector3 = game.world_map.try_sample_navigation_position(game.world_map.buff_position, 25.0)
	stage.y = 0.7
	game._clear_field()
	game.player.teleport(stage)
	game.camera.size = 16
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
	var targets: Array[Enemy] = []
	for offset in [Vector3(2, 0, 0), Vector3(2.5, 0, 1.2), Vector3(-2, 0, 1)]:
		var enemy := game._spawn_enemy(stage + offset, offset.x < 0, false)
		enemy.set_physics_process(false)
		enemy.max_health = 20000
		enemy.health = 20000
		targets.append(enemy)
	for i in range(4):
		game.player._attack_cooldown = 0
		game.player.hitstop_remaining = 0
		game.player.attack(targets[0])
		await step(3)
	game.player.sword_charge = game.player.wave_hits_needed()
	game.player._attack_cooldown = 0
	game.player.hitstop_remaining = 0
	game.player.attack(targets[0])
	for i in range(6): await physics_frame
	game.player.take_damage(700, "phys")
	await capture("combat")
	game.open_modal("inventory")
	game._inventory_panel.open()
	await capture("inventory")
	game.close_modal()
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
