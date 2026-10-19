extends SceneTree
## 干员寻访 R1 and 叙拉古's enemies on screen: the dispatch desk's 寻访合同 card,
## the 人事部 roster, a recruit point under guard, the hall's roster figures,
## and a 叙拉古 floor's families and its car roadblock.
## ../evidence/recruit-<shot>.png.
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 8) -> void:
	for i in range(count): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func save(label: String) -> void:
	await step(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/recruit-" + label + ".png")
func field_shot(at: Vector3, label: String, size: float = 24.0) -> void:
	game.player.teleport(game.world_map.nearest_walkable(at))
	game.camera.size = size
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET * (size / 24.0)
	game._hud.hide()
	await save(label)
	game._hud.show()
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	game.region_id = "city"
	for i in range(RecruitCatalog.CLUES_NEEDED * 2): game._find_clue()
	game.base.recruit("santalla")
	game.base.recruit("hellagur")
	game.refresh_look()
	await step(6)
	game.camera.size = 34.0
	await save("hall")
	game.open_station("contracts")
	game.menu.region_pick = "city"
	game.open_station("contracts")
	game.menu.region_pick = "city"
	BaseScreens.contracts(game.menu)
	await save("dispatch")
	game.close_modal()
	game.open_station("personnel")
	await save("personnel")
	game.close_modal()
	game._pending_contract = RecruitCatalog.contract_for("hoshiguma")
	await game.start_contract("city")
	game.floor_number = game.start_floor + int(game.contract.offset) - 1
	await game.advance(0)
	await step(6)
	game.open_modal("capture")
	if is_instance_valid(game.recruit_node): await field_shot(game.recruit_node.global_position + Vector3(0, 0, 3), "point", 20.0)
	game.close_modal()
	game.settle(false)
	await step(4)
	# A seed whose first floor has the car's roadblock.
	var map := ContinuousWorldMap.new()
	root.add_child(map)
	for i in range(12):
		map.region_id = "siracusa"
		map.generate((i + 1) * 104729, 1)
		if not map.roadblock.is_empty():
			game.fixed_map_seed = (i + 1) * 104729
			break
	map.queue_free()
	await game.start_contract("siracusa")
	await step(6)
	game.open_modal("capture")
	var enemies: Array = game.floor_enemies()
	if not enemies.is_empty(): await field_shot(enemies[0].global_position + Vector3(0, 0, 3), "families", 22.0)
	if is_instance_valid(game._car): await field_shot(game._car.global_position + Vector3(0, 0, 4), "car", 22.0)
	quit()
