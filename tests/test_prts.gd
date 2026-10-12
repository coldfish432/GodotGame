extends SceneTree
## PRTS in the field keeps only necessary notices (用户 2026-10-10: 局内 prts
## 只保留提示必要信息，如背包已满无法拾取，教程类不提示): failed or blocked
## actions pop up as top-centre toasts; events and successes do not.
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await game.start_contract("mine")
	await step(2)
	check("contract start is logged, not popped up", game.prts_toasts.is_empty() and game.prts_log.any(func(l): return "合同开始" in str(l[1])))
	game.broadcast("本层发现撤离点。")
	check("events do not pop up", game.prts_toasts.is_empty())
	# Pack full: picking something up that does not fit.
	var filler := MaterialCatalog.create(Economy.GOLD_ID, 1, "mine")
	while game.inventory.try_add(Item.create("填充", Item.Category.ARMOR, 1, 1)): pass
	var big := Item.create("放不下的剑", Item.Category.WEAPON, 2, 1)
	game.try_collect(big)
	check("a full pack is a notice", game.prts_toasts.size() == 1 and "背包空间不足" in game.prts_toasts[0].text)
	game.prts_toasts.clear()
	game.inventory.items.clear()
	game.try_collect(filler)
	check("a successful pickup is not", game.inventory.items.has(filler) and game.prts_toasts.is_empty())
	for i in range(5): game.notice("通知 %d" % i)
	check("at most three at once, newest kept", game.prts_toasts.size() == GameManager.TOAST_MAX and game.prts_toasts[-1].text == "通知 4")
	game._tick_toasts(GameManager.TOAST_SECONDS + 0.1)
	check("notices fade out", game.prts_toasts.is_empty())
	# No tutorial tips anywhere.
	var p := game.player
	p.invulnerable = false
	p.invuln_timer = 0
	p.hp = p.max_hp * 0.35
	p.take_damage(p.max_hp * 0.1, "true")
	game.spawn_warning_area(p.global_position, 1.0, 0.5)
	game._drop_at(p.global_position + Vector3(2, 0, 0), [{"item": MaterialCatalog.create(Economy.GOLD_ID, 3, "mine")}], 0.5)
	check("no tutorial tips (low life, warnings, drops)", game.prts_toasts.is_empty() and not "PRTS_TIPS" in (game.get_script() as Script).get_script_constant_map())
	game.in_base = true
	game.notice("基地里")
	check("in the base a notice is not a toast", game.prts_toasts.is_empty())
	print("TEST_PRTS: %d failures" % failures)
	quit(1 if failures > 0 else 0)
