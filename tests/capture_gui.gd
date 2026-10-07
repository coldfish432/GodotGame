extends SceneTree
## Screenshots of the new field GUI (界面策划案 v1.1): HUD, 干员·背包, R, J, M, pause.
## Writes evidence/gui-*.png. Not part of run_all (no checks).
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
	root.get_texture().get_image().save_png("res://../evidence/gui-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	await game.start_contract("city")
	var stage: Vector3 = game.world_map.try_sample_navigation_position(game.world_map.buff_position, 25.0)
	stage.y = 0.7
	game.player.teleport(stage)
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
	game._clear_field()
	var a := game._spawn_enemy(stage + Vector3(-4, 0, -1), false, false)
	var b := game._spawn_enemy(stage + Vector3(4, 0, -1), true, false)
	for e in [a, b]:
		if e != null: e.health = e.max_health * 0.6
	game.player.sword_charge = 2
	game.add_gold(7)
	for relic in RelicCatalog.all().slice(0, 5): game.builds.append(relic.id)
	game.try_collect(FieldCatalog.exclusive("city"))
	game.broadcast("附近发现罗德岛小队。")
	game.broadcast("本层发现撤离点。")
	game.fog.reveal(game.player.global_position)
	await capture("hud")
	game.toggle_panel("inventory")
	await capture("inventory")
	for item in game.inventory.items:
		if item.is_equippable():
			game._inventory_panel.hover(item, game.inventory, Rect2(600, 200, 40, 40))
			break
	await capture("inventory-hover")
	game.toggle_panel("relics")
	await capture("relics")
	game.toggle_panel("journal")
	await capture("journal")
	game.toggle_panel("map")
	await capture("map")
	game.close_modal()
	game.player.teleport(game.world_map.buff_position)
	game._interact()
	game.menu.pick = 1
	game.menu.show_builds()
	await capture("build")
	game.close_modal()
	game.player.teleport(game.world_map.route_nodes[0].position)
	game._interact()
	await capture("route")
	game.close_modal()
	game.toggle_panel("pause")
	await capture("pause")
	game.close_modal()
	game.encounter = "squad"
	game.encounter_used = false
	game.world_map.encounter_node.visible = true
	game.player.teleport(game.world_map.encounter_node.global_position)
	game._open_encounter()
	await capture("squad")
	game.close_modal()
	game.encounter = "trader"
	game._roll_trader_stock()
	game._open_encounter()
	await capture("trader")
	game.close_modal()
	game.floor_number = 10
	game._enter_camp()
	await capture("camp")
	game.camp_extract()
	await capture("settlement")
	game.close_modal()
	game.open_station("contracts")
	await capture("base-contracts")
	game.close_modal()
	await game.start_contract("snow")
	game.try_collect(FieldCatalog.exclusive("snow"))
	game.add_gold(4)
	for item in game.inventory.items:
		if item.is_equippable():
			item.insured = true
			break
	game.quick_move(game.inventory.items[0], game.inventory)
	game._on_player_died()
	await step(30)
	await capture("settlement-dead")
	game.close_modal()
	game.open_station("contracts")
	await capture("base-contracts")
	game.close_modal()
	await capture("base")
	for station in ["stash", "outbound", "pharmacy", "report", "decon", "loadout", "store"]:
		game.open_station(station)
		await capture("base-" + station)
		game.close_modal()
	game.open_station("contracts")
	game.menu.show_departure("city")
	await capture("base-departure")
	game.close_modal()
	game.toggle_panel("pause")
	await capture("base-settings")
	game.close_modal()
	quit()
