extends SceneTree
## Engine screenshots of the medical bay in use (B4, evidence/rhodes-engine/b4-*):
## waking injured at the recovery bed, the red scan gate and its reading, the
## front desk's alert state, the pharmacy menu, and contamination on the field HUD.
var game: GameManager
func _initialize() -> void: call_deferred("run")
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func frames(n: int) -> void:
	for i in range(n): await process_frame
func wait(seconds: float) -> void:
	await create_timer(seconds).timeout
func shot(label: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/b4-" + label + ".png")
func place(at: Vector3) -> void:
	game.player.teleport(at)
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
func run() -> void:
	var rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await frames(20)
	game = find_game(rig)
	game.base.contamination = 58
	game.base.injured = true
	game.base.report_unread = true
	game.base.prestige = 60
	var view := game.medical_view
	place(game.base_map.to_world(view._gate_x + 1.5, view._gate_z, BaseMap.PLAYER_Y))
	await wait(0.3)
	place(game.base_map.to_world(view._gate_x - 1.5, view._gate_z, BaseMap.PLAYER_Y))
	await wait(0.3)
	await shot("gate")
	place(game.base_map.station("reception").position + Vector3(0, 0, -1.5))
	await wait(0.3)
	await shot("reception")
	game.open_station("report")
	await shot("report")
	game.close_modal()
	game.open_station("pharmacy")
	await shot("pharmacy")
	game.close_modal()
	game.set_potion(0, "C")
	game.set_potion(2, "B")
	await game.start_contract("mine")
	game.inventory.try_add(FieldCatalog.exclusive("mine"))
	await wait(0.5)
	await shot("field-hud")
	quit()
