extends SceneTree
## A save with everything open, for looking around (用户 2026-11-14: "给我一个全解锁存档").
## Writes save slot 2 by default (`-- --slot=N`, 1–3); refuses a slot that already
## holds a save unless `-- --force`.
##   Godot --headless --path . --script res://tools/make_unlocked_save.gd -- --slot=2
## Opens: the main thread done, every facility at its top level and connected,
## every operator recruited at 精英 2 Lv90 (points left to spend), every lost
## operator back, every research done, every faction at 崇拜, camps to floor 100
## in every region, pack and safe at their top, 10,000,000 龙门币, 1,000 赤金.
var game: GameManager

func _initialize() -> void: call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n): await process_frame

func run() -> void:
	var slot := 2
	var force := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--slot="): slot = clampi(int(a.substr(7)), 1, 3)
		if a == "--force": force = true
	var path := SaveSlots.path(slot - 1)
	if SaveSlots.used(slot - 1) and not force:
		printerr("存档 %d 已有存档，加 -- --force 覆盖" % slot)
		quit(1)
		return
	game = GameManager.new()
	game.save_path = path
	game.save_enabled = true
	root.add_child(game)
	await step(10)
	var base := game.base
	base.story = Story.finished_state()
	base.max_facilities()
	for id in LostCatalog.LOST: base.find_lost(str(id))
	for id in Operators.ORDER:
		base.recruit(id)
		var p := base.progress_for(id)
		while p.elite < 2:
			p.add_exp(p.exp_room())
			p.promote()
		p.add_exp(p.exp_room())
	for id in ResearchCatalog.NODES:
		if not id in base.research.done: base.research.done.append(id)
	for f in FactionCatalog.FACTIONS:
		game.exchange.add_relation(str(f), Exchange.RELATION_MAX)
	for region in FieldCatalog.REGIONS:
		base.unlock_camp(str(region), 100)
	base.pack_level = BaseCatalog.PACK_PRICES.size() - 1
	base.safe_level = BaseCatalog.SAFE_PRICES.size() - 1
	base.camp_upgraded = true
	game.gold = 10000000
	game.base.receive(MaterialCatalog.create(Economy.GOLD_ID, 999))
	game.save_base()
	await step(5)
	print("WROTE ", ProjectSettings.globalize_path(path), "  roster ", base.roster.size(), "  research ", base.research.done.size())
	quit(0)
