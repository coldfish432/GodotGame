extends SceneTree

## Screenshots of the equipment icons in the real inventory (装备策划案 §6):
## all 13 mine items in the pack across the three rarities, three of them worn,
## and the tooltip with its icon, for the mine (E1), Lungmen (E2) and Sami (E3).
## Output: evidence/item-icons-<region>-*.png.

var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/item-icons-" + label + ".png")

const MINE := [
	["改装砍刀", Item.Category.WEAPON], ["制式短刀", Item.Category.WEAPON], ["矿区制式刀", Item.Category.WEAPON],
	["纠察队佩刀", Item.Category.WEAPON], ["断镐战斧", Item.Category.WEAPON],
	["矿工护甲", Item.Category.ARMOR], ["整合运动制式外套", Item.Category.ARMOR], ["纠察队防寒大衣", Item.Category.ARMOR],
	["矿场重型防护服", Item.Category.ARMOR],
	["防尘面罩", Item.Category.TRINKET], ["烈酒扁壶", Item.Category.TRINKET], ["整合运动面具", Item.Category.TRINKET],
	["源石感应计", Item.Category.TRINKET],
]
const CITY := [
	["指刃", Item.Category.WEAPON], ["帮派砍刀", Item.Category.WEAPON], ["近卫局警用刀", Item.Category.WEAPON],
	["押运短刃", Item.Category.WEAPON], ["炎式环首刀", Item.Category.WEAPON],
	["近卫局制式护甲", Item.Category.ARMOR], ["消防署隔热服", Item.Category.ARMOR], ["押运防弹背心", Item.Category.ARMOR],
	["特别督察组战术护甲", Item.Category.ARMOR],
	["战术挂饰", Item.Category.TRINKET], ["近卫局对讲机", Item.Category.TRINKET], ["龙门币钱夹", Item.Category.TRINKET],
	["炎式平安符", Item.Category.TRINKET],
]
const SNOW := [
	["破冰刀", Item.Category.WEAPON], ["猎刀", Item.Category.WEAPON], ["角柄猎刀", Item.Category.WEAPON],
	["科考队开路刀", Item.Category.WEAPON], ["雪祀礼刃", Item.Category.WEAPON],
	["冰原毛皮外套", Item.Category.ARMOR], ["雪橇巡逻队斗篷", Item.Category.ARMOR], ["科考队防寒服", Item.Category.ARMOR],
	["骨片札甲", Item.Category.ARMOR],
	["骨制护符", Item.Category.TRINKET], ["角兽骨笛", Item.Category.TRINKET], ["兽骨鼓槌", Item.Category.TRINKET],
	["密文板残片", Item.Category.TRINKET],
]

func make(entry: Array, rarity: int, region: String) -> Item:
	var category: int = entry[1]
	var item := LootTables.roll_equipment(category, entry[0], region, 3, rarity, game.rng)
	item.origin_region = region
	return item

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(5)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	await game.start_contract("mine")
	game.player.invulnerable = true
	for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
	await step(2)
	game.rng.seed = 11
	for set in [["mine", MINE], ["city", CITY], ["snow", SNOW]]:
		await show(set[0], set[1])
	await show_specials()
	quit(0)

## One region's 13 items: three worn (rare), ten in the pack across rarities.
func show(region: String, items: Array) -> void:
	game.inventory.items.clear()
	for category in [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET]:
		if game.player.equipped.has(category): game.player.unequip(category)
	var worn := [3, 8, 12]
	for i in worn: game.player.equip(make(items[i], 2, region))
	var shown: Array[Item] = []
	for i in range(items.size()):
		if i in worn: continue
		var item := make(items[i], i % 3, region)
		if game.inventory.try_add(item): shown.append(item)
		else: print("did not fit: ", items[i][0])
	game.open_modal("inventory")
	game._inventory_panel.open()
	await step(6)
	await capture(region + "-01-pack")
	game._inventory_panel.hover(shown[4], game.inventory)
	await step(3)
	await capture(region + "-02-tooltip")
	print("%s: %d pack items + 3 worn" % [region, shown.size()])

## E4: the nine special pieces and three regional exclusives.
func show_specials() -> void:
	game.inventory.items.clear()
	for category in [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET]:
		if game.player.equipped.has(category): game.player.unequip(category)
	game.player.equip(SpecialGear.create("crystal_edge", 3, game.rng))
	game.player.equip(SpecialGear.create("spike_plate", 3, game.rng))
	game.player.equip(SpecialGear.create("vein_core", 3, game.rng))
	var shown: Array[Item] = []
	for id in ["lord_blade", "twin_fang", "ember_fang", "moon_edge", "bash_shield", "shadow_bracer"]:
		var item := SpecialGear.create(id, 3, game.rng)
		if game.inventory.try_add(item): shown.append(item)
	for region in ["city", "mine", "snow"]:
		var ex := FieldCatalog.exclusive(region)
		if game.inventory.try_add(ex): shown.append(ex)
	game.open_modal("inventory")
	game._inventory_panel.open()
	await step(6)
	await capture("special-01-pack")
	game._inventory_panel.hover(shown[0], game.inventory)
	await step(3)
	await capture("special-02-tooltip")
	print("special: %d pack items + 3 worn" % shown.size())
