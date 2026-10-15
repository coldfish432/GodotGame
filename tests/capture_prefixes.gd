extends SceneTree
## Named prefixes on screen (装备前缀策划案): ground plates with each prefix in
## its grade colour, a tooltip with the prefix lines (and Alt ranges), and the
## workbench's 重铸 / 校准 / 精调. ../evidence/prefix-plates.png,
## prefix-tooltip.png, prefix-workbench.png.
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

func sample(rng: RandomNumberGenerator, base: String, ids: Array) -> Item:
	var category := int(GearCatalog.BASES[GearCatalog.id_for_name(base)].category)
	var item := LootTables.roll_equipment(category, base, "mine", 5, 2, rng)
	item.prefixes = ids.map(func(id): return PrefixCatalog.roll_entry(id, rng))
	PrefixCatalog.refresh_value(item)
	return item

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	game.fixed_map_seed = 2026
	await game.start_contract("mine")
	game.player.invulnerable = true
	for node in get_nodes_in_group("enemies"): node.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var items := [sample(rng, "断镐战斧", ["deadly", "frenzying"]), sample(rng, "矿工护甲", ["tattered"]),
		sample(rng, "防尘面罩", ["snowpriest"]), sample(rng, "改装砍刀", ["damaged"]), sample(rng, "矿区制式刀", ["legendary", "riot"])]
	var at := game.player.global_position
	for i in range(items.size()):
		var loot := Loot.new()
		loot.game = game
		loot.item = items[i]
		loot.pickup_delay = 99.0
		game.add_child(loot)
		loot.global_position = at + Vector3(-2.0 + i * 1.0, 0, 1.6 + (i % 2) * 0.9)
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
	await step(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/prefix-plates.png")
	# The tooltip, as the pack shows it (Alt held: ranges).
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.05, 0.05, 0.96)
	back.position = Vector2(40, 30)
	back.size = Vector2(1200, 660)
	layer.add_child(back)
	for i in range(2):
		var tip := RichTextLabel.new()
		tip.bbcode_enabled = true
		tip.position = Vector2(60 + i * 600, 40)
		tip.size = Vector2(560, 640)
		tip.add_theme_font_override("normal_font", AK.cn())
		tip.add_theme_font_size_override("normal_font_size", 15)
		tip.text = ItemTooltip.text(game, items[0] if i == 0 else items[4], i == 1, false)
		layer.add_child(tip)
	await step(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/prefix-tooltip.png")
	layer.queue_free()
	# The workbench with the axe picked.
	game.inventory.try_add(items[0])
	game.in_base = true
	game.gold = 50000
	game.open_modal("station")
	game.open_station("loadout")
	await step(4)
	var menu: FieldMenu = game.menu
	if menu != null:
		menu.pick = items[0]
		BaseScreens.departure(menu, "", "loadout")
	await step(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/prefix-workbench.png")
	print("menu found: ", menu != null)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
