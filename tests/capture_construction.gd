extends SceneTree
## Engine screenshot of the 基建 page (基建设施修订案_v1_0.md §三):
## evidence/rhodes-engine/construction.png, a mid-game base with some
## facilities raised, some materials short and some upgrades affordable.
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
func shot(label: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/" + label + ".png")
func give(cost: Dictionary) -> void:
	for id in cost:
		var left := int(cost[id])
		while left > 0:
			var m := MaterialCatalog.create(id, left)
			game.base.shelf.append(m)
			left -= m.quantity
func run() -> void:
	var rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await frames(20)
	game = find_game(rig)
	game.gold = 86500
	game.base.console = true
	game.base.set_facility("warehouse", 2)
	game.base.set_facility("store", 3)
	game.base.set_facility("exchange", 2)
	game.base.drone = true
	game.base.racks[Item.Category.WEAPON] = 3
	game.base.racks[Item.Category.MATERIAL] = 2
	game.base.pack_level = 1
	give({"螺栓": 6, "金属板": 2, "碳": 3, "帆布": 3, "胶带": 2, "电路板": 2, "继电器": 2, "家具零件": 1, "灯泡": 1})
	game.open_station("construction")
	await create_timer(1.5).timeout
	await shot("construction")
	quit()
