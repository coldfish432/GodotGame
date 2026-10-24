extends SceneTree
## Three save slots (用户 2026-10-23): their files, what the title reads of
## them, deleting (not while a terminal writes one), and the title starting
## the game on the slot picked.
var failures := 0
const DIR := "user://slots_TEST_ONLY"
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1

func clean() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null: return
	for f in dir.get_files(): dir.remove(f)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveSlots.folder = DIR
	clean()
	check("slot 1 is the old save's file, the others their own", SaveSlots.path(0).ends_with("/field_contract_v1.json") and SaveSlots.path(1) != SaveSlots.path(2) and SaveSlots.path(1) != SaveSlots.path(0))
	check("no files: every slot free, the first one first", not SaveSlots.used(0) and not SaveSlots.used(2) and SaveSlots.first_free() == 0)

	# The title: nothing is loaded until a slot is picked.
	var game := GameManager.new()
	var screens := SystemScreens.new()
	screens.game = game
	screens.launch = func(slot: int):
		game.save_path = SaveSlots.path(slot)
		root.add_child(game)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(screens)
	# Never the real settings file.
	SystemScreens._game = null
	screens.show_title()
	await step(2)
	check("the title shows its buttons, not the slots", screens._menu.visible and not screens._slots.visible)
	screens._show_slots(true)
	await step(1)
	check("开始游戏: three slots and 返回 in their place", screens._slots.visible and not screens._menu.visible and screens._slots.get_child_count() == SaveSlots.COUNT + 1)
	check("and no game runs behind it", not game.is_inside_tree())
	await screens._pick(0)
	check("the loading screen is up as the save loads", screens._loading.visible and not screens._title.visible)
	while game.booting: await step(1)
	check("a new save on slot 1 starts the game on its file", game.is_inside_tree() and game.save_path == SaveSlots.path(0) and screens.slot == 0 and not screens._title.visible)
	check("the slot picked is remembered", int(SystemScreens.settings.save_slot) == 0)
	check("a new save deploys Amiya, not the Player's default", game.player.operator_id == Operators.AMIYA_GUARD and game.base.operator == Operators.AMIYA_GUARD)
	game.save_base()
	var s := SaveSlots.summary(0)
	check("saved: slot 1 used, the title reads its 龙门币 and operators", SaveSlots.used(0) and int(s.lmd) == game.gold and int(s.operators) == 1 and int(s.saved) > 0)
	check("the next free slot is 2", SaveSlots.first_free() == 1)
	check("its own game does not make it busy", not SaveSlots.busy(0))
	screens.show_title()
	await step(2)
	check("back on the title the game waits under it", game.is_inside_tree() and game.modal == "title")
	screens._pick(0)
	await step(2)
	check("its own slot again: straight back in", not screens._title.visible and game.modal != "title")
	layer.queue_free()
	game.queue_free()
	await step(3)

	# A terminal of another process writes slot 2: it cannot be deleted.
	var other := FileAccess.open(SaveSlots.path(1), FileAccess.WRITE)
	other.store_string("{\"version\": 3, \"gold\": 500, \"base\": {\"roster\": [\"amiya_guard\", \"hellagur\"]}}")
	other.close()
	var lock := FileAccess.open(SaveSlots.path(1) + ".lock", FileAccess.WRITE)
	lock.store_string(JSON.stringify({"id": "x", "pid": OS.get_process_id() + 1, "mode": "exchange", "beat": SaveLock.now(), "seq": 1}))
	lock.close()
	check("a slot another process writes is busy", SaveSlots.busy(1))
	check("and is not deleted", not SaveSlots.delete(1) and SaveSlots.used(1))
	check("its summary: 500 龙门币, two operators", int(SaveSlots.summary(1).lmd) == 500 and int(SaveSlots.summary(1).operators) == 2)
	check("all three used once slot 3 is: no free slot", (func():
		var f := FileAccess.open(SaveSlots.path(2), FileAccess.WRITE)
		f.store_string("{\"version\": 3}")
		f.close()
		return SaveSlots.first_free() == -1).call())
	check("deleting slot 1 removes its save, backup, market and lock", SaveSlots.delete(0) and not SaveSlots.used(0)
		and not FileAccess.file_exists(SaveSlots.path(0) + ".market") and not FileAccess.file_exists(SaveSlots.path(0) + ".lock") and not FileAccess.file_exists(SaveSlots.path(0) + ".bak"))
	check("and it is free again", SaveSlots.first_free() == 0)
	clean()
	DirAccess.remove_absolute(DIR)
	print("SAVE SLOT TESTS %s" % ("PASSED" if failures == 0 else "FAILURES: %d" % failures))
	quit(0 if failures == 0 else 1)
