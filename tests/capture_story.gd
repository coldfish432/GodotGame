extends SceneTree
## Screenshots of the 主线引导 (StoryCard): 苏醒's dialogue, the objective card,
## 杜宾's name plate (no picture yet), 可露希尔's picture, the greyed regions.
## Writes evidence/story-*.png. Not in run_all.
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
	root.get_texture().get_image().save_png("res://../evidence/story-" + ("en-" if I18n.is_english() else "") + label + ".png")
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_step"] = TutorialCard.STEPS.size()
	SystemScreens.settings["tutorial_tips"] = false
	SystemScreens.settings["story_guide"] = true
	BaseCrew.pool_override = ["dobermann", "kaltsit"]
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.base.story = Story.fresh()
	var story := game.story_card
	story.forced = true
	await step(20)
	story.advance()
	await capture("wake-amiya")
	story.advance()
	await step(20)
	await capture("card-wake")
	game.open_station("contracts")
	await capture("regions")
	game.close_modal()
	for g in ["first_contract", "crate", "shelve", "order", "treat"]: game.base.story.done.append(g)
	game.base.story.seen.append("return")
	game.base.story.counts["contract"] = 1
	await step(20)
	await capture("outfit-dobermann")
	story.go_back()
	await step(10)
	await capture("card-outfit")
	for g in ["bench_equip", "insure"]: game.base.story.done.append(g)
	await step(20)
	await capture("hub-closure")
	story.go_back()
	await step(5)
	story.start_talk(Story.beat("voyage"))
	await capture("voyage-kaltsit")
	story.go_back()
	await step(5)
	story.start_talk(Story.beat("outfit"))
	await capture("outfit-dobermann-art")
	story.go_back()
	await step(10)
	await capture("card-hub")
	# 杜宾 and 凯尔希 walking the base, close up.
	game.story_card.forced = false
	SystemScreens.settings["story_guide"] = false
	for walker in game.base_map.crew.walkers:
		walker.body.global_position = game.player.global_position + Vector3(randf_range(-3, 3), 0, randf_range(1, 3))
	await step(60)
	game.zoom_camera(-4)
	await step(30)
	await capture("crew")
	quit(0)
