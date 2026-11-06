extends SceneTree
## 肉鸽路线图 (策划案 v0.2 §7): the route map from a floor and from a camp, and
## 不期而遇's card. Writes evidence/route-map-*.png. Not part of run_all.
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 10) -> void:
	for i in range(count): await process_frame
func shot(name: String) -> void:
	await step(90)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/route-map-%s.png" % name)
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 4242
	root.add_child(game)
	await step(10)
	# The dispatch desk's floors: the extraction's band and the block's last floor.
	SystemScreens.settings["ui_motion"] = false
	game.base.camps["mine"] = 10
	game.menu.pick = 10
	game.open_station("contracts")
	await shot("dispatch")
	game.close_modal()
	await game.start_contract("mine")
	await step(4)
	game.floor_number = 3
	game._ensure_route()
	game.route_trail = [0, 0, game.route_node.y]
	game.open_modal("route")
	game.menu.show_routes(0)
	await shot("floor")
	game.close_routes()
	game.route_peek = true
	game.open_modal("route")
	game.menu.show_routes(1)
	await shot("peek")
	game.close_routes()
	game.route_peek = false
	# 不期而遇's card.
	for node in game.route_map.cols[game.route_node.x + 1]:
		node.kind = "event"
		node.event = "beacon"
		node.exit = false
	await game.advance(0)
	await step(4)
	game.run_gold = 3
	game.open_modal("event")
	game.menu.show_event()
	await shot("event")
	game.close_modal()
	game.floor_number = 10
	await game._enter_camp()
	await step(2)
	game.leave_camp()
	await shot("camp")
	quit()
