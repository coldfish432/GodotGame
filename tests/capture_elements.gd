extends SceneTree
## Screenshots for 属性伤害与地区装备策划案 v1.1: the 损伤 rings under enemy
## and her bars (evidence/elements-rings.png) and the pack with the rarity
## ladder, the floors in each cell's corner, the resistance row and an orange
## mine weapon's tooltip (evidence/elements-pack.png). Not part of run_all.
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
	root.get_texture().get_image().save_png("res://../evidence/" + label + ".png")

func run() -> void:
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["auto_potion"] = false
	game = GameManager.new()
	game.start_at_base = false
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(30)
	var p := game.player
	p.invulnerable = true
	var at := p.global_position
	var kinds := [["thug", ["cold", "corr"]], ["caster", ["burn"]], ["armed", ["nerve", "cold"]]]
	for i in range(kinds.size()):
		var e := game._spawn_enemy(at + Vector3(2.5 + i * 1.6, 0, -1.0 + i), kinds[i][0] == "armed", false, kinds[i][0])
		e.set_physics_process(false)
		var share := 0.35
		for kind in kinds[i][1]:
			e.elements.fill(kind, e.gauge_threshold() * share, e.gauge_threshold(), Elements.BURST_COOLDOWN)
			share += 0.4
		e.health = e.max_health * 0.7
	p.elements.state.fill("corr", p.max_hp * 0.6 * 0.55, p.max_hp * Elements.HER_THRESHOLD, Elements.HER_COOLDOWN)
	p.elements.state.fill("nerve", p.max_hp * 0.6 * 0.25, p.max_hp * Elements.HER_THRESHOLD, Elements.HER_COOLDOWN)
	await capture("elements-rings")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var region := ["mine", "city", "snow", "siracusa", "mine"]
	for r in range(5):
		var item := LootTables.roll_equipment([Item.Category.WEAPON, Item.Category.CHEST, Item.Category.RING, Item.Category.HANDS, Item.Category.WEAPON][r], ["断镐战斧", "x", "x", "x", "改装砍刀"][r], region[r], 12 + r * 10, r, rng)
		game.try_collect(item)
	var orange := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "mine", 45, Item.ORANGE, rng)
	game.try_collect(orange)
	game.toggle_panel("inventory")
	await step(10)
	game._inventory_panel.hover(orange, game.inventory)
	await capture("elements-pack")
	quit(0)
