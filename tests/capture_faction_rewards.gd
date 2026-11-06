extends SceneTree
## Screenshots for 势力声望解锁策划案 v0.1: the relations page with every rank
## on show, 企鹅物流's desk with 加急专递单, the canteen's 冰原熏肉, a post at
## 崇拜 (its extra shelf and gift) and one at 冷漠 (sells nothing).
## Writes evidence/rank-*.png. Not part of run_all (no checks).
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
	root.get_texture().get_image().save_png("res://../evidence/rank-" + ("en-" if I18n.is_english() else "") + label + ".png")
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	if is_instance_valid(game.system_screens): game.system_screens.hide()
	game.gold = 900000
	var ex := game.exchange
	for f in FactionCatalog.ORDER: ex.rank_gifts[f] = FactionRewards.GIFT_RANKS.duplicate()
	ex.relations = {"karlan": 620, "sami": 1600, "lungmen": 2700, "rhine": 5000, "penguin": 2600, "rat": 300,
		"kazimierz": 1100, "ursus": 5000, "reunion": 40}
	game.base.set_facility("exchange", 1)
	game.base.set_facility("canteen", 1)
	game.base.shelf.append(MaterialCatalog.create("冰原熏肉", 2))
	game.base.shelf.append(MaterialCatalog.create("矿场主事铭牌", 1))
	game.open_station("sand_table")
	SandTableScreen.tab = 1
	game.menu.show_station("sand_table")
	await step(60)
	await capture("relations")
	game.close_modal()
	game.open_exchange()
	await step(60)
	ExchangeScreen.tab = 4
	game.menu.show_station("exchange")
	await capture("penguin-desk")
	game.close_modal()
	game.open_station("canteen")
	await step(150)
	ProvisionScreens.canteen_tab = 1
	ProvisionScreens.meal_pick = "冰原熏肉"
	game.menu.show_station("canteen")
	await step(30)
	await capture("canteen-meat")
	game.close_modal()
	await game.start_contract("mine")
	await step(10)
	game.encounter = "post"
	game.post_faction = "ursus"
	game.post_gifted = false
	game.give_gold_bars(30)
	game.menu.trader_tab = "buy"
	game._open_encounter()
	game.open_modal("post")
	game.menu.show_post()
	await step(90)
	await capture("post-ursus-exalted")
	game.close_modal()
	game.post_faction = "reunion"
	game.open_modal("post")
	game.menu.show_post()
	await step(90)
	await capture("post-reunion-cold")
	quit()
