extends SceneTree
## The standalone terminal and ticker (交易终端与盯盘小窗策划案_v1_0.md): one
## writer per save, readers that follow it, the game taking the save back, the
## merged save, read-only trading, and no settling of a run in progress.
var failures := 0
const SAVE := "user://test_terminal.json"
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1

func clean() -> void:
	var dir := DirAccess.open("user://")
	for f in dir.get_files():
		if f.begins_with("test_terminal.json"): dir.remove(f)

func make(mode: String) -> GameManager:
	var g := GameManager.new()
	g.save_path = SAVE
	g.save_enabled = true
	g.app_mode = mode
	g.fixed_market_seed = 77
	root.add_child(g)
	return g

## Waits (real time) until `cond` holds, at most `seconds`.
func wait_for(cond: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if cond.call(): return true
		await create_timer(0.1).timeout
		left -= 0.1
	return cond.call()

func run() -> void:
	MarketState.tz_override = 0
	clean()
	# --- The lock on its own --------------------------------------------------------
	var a := SaveLock.new(SAVE, "exchange")
	var b := SaveLock.new(SAVE, "ticker")
	check("the first one claims the save", a.try_claim() and a.holder)
	check("a second one cannot while the first beats", not b.try_claim() and not b.holder)
	var stale := a.current()
	stale.beat = SaveLock.now() - SaveLock.STALE - 5
	var f := FileAccess.open(a.lock_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(stale))
	f.close()
	check("a stale lock (a crash) is free to take", b.try_claim() and b.holder)
	b.request_release()
	check("the game's request reaches a ticker writer", b.release_requested())
	b.release()
	check("stepping down frees the lock and the request", a.current().is_empty() and not FileAccess.file_exists(b.release_path()))
	var reader := SaveLock.new(SAVE, "ticker")
	check("no reader yet", not b.readers_present())
	reader.beat()
	check("a reader's beat makes the writer save often", b.readers_present())
	reader.leave()
	check("and stops when it leaves", not b.readers_present())
	a.holder = false
	clean()
	# --- The game writes; a terminal reads and follows ----------------------------
	var game := make("")
	await step(10)
	game.gold = 123456
	game.save_base()
	check("the game holds the save", game.writer() and str(game.save_lock.current().get("mode", "")) == "game")
	var term := make("exchange")
	await step(10)
	check("a terminal opened beside the game reads", not term.writer() and term.gold == 123456)
	check("and is read-only while the game is open", term.trade_block() == "只读 · 游戏中")
	var pack := MaterialCatalog.create("建材包", 1)
	term.base.shelf.append(pack)
	term.base.set_facility("exchange", 1)
	check("a read-only terminal refuses trades", not term.exchange.sell_item(pack, "lungmen") and not term.exchange.convert(true, 1000.0))
	check("it never saves", (func(): var before := FileAccess.get_modified_time(SAVE); term.save_base(); return FileAccess.get_modified_time(SAVE) == before).call())
	game.gold = 222222
	game.save_base()
	check("it follows the game's saves", await wait_for(func(): return term.gold == 222222, 6.0))
	check("its market keeps up with the clock", absi(term.market.t - BaseState.now()) <= MarketState.TICK * 2)
	# --- The game closes: the terminal takes over and saves only its three keys --
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	raw["kept_by_game"] = "untouched"
	var w := FileAccess.open(SAVE, FileAccess.WRITE)
	w.store_string(JSON.stringify(raw))
	w.close()
	game.queue_free()
	await step(2)
	check("with the game gone the terminal writes", await wait_for(func(): return term.writer(), 6.0))
	check("and may trade", term.trade_block() == "")
	term.gold = 333333
	term.save_base()
	raw = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check("its save changes gold, base and exchange only", int(raw.gold) == 333333 and str(raw.get("kept_by_game", "")) == "untouched")
	# --- The game comes back: the terminal steps down, saving first -------------
	term.gold = 444444
	var again := make("")
	check("the game asks the terminal to step down and gets the save", await wait_for(func(): return again.save_lock != null and again.writer(), 8.0))
	await step(10)
	check("the terminal saved before stepping down", again.gold == 444444 and not term.writer())
	check("and is read-only again", term.trade_block() == "只读 · 游戏中")
	again.queue_free()
	term.queue_free()
	await step(4)
	# --- A run in progress is never settled outside the game ---------------------
	raw = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	raw["active_contract"] = true
	raw["gold"] = 555555
	w = FileAccess.open(SAVE, FileAccess.WRITE)
	w.store_string(JSON.stringify(raw))
	w.close()
	var lock_left := FileAccess.file_exists(SAVE + ".lock")
	var mid := make("exchange")
	await step(10)
	check("no lock left behind by closed windows", not lock_left)
	check("mid-run the terminal writes but only reads for the player", mid.writer() and mid.trade_block() == "只读 · 局内")
	check("and does not settle the run", mid.gold == 555555 and bool(JSON.parse_string(FileAccess.get_file_as_string(SAVE)).get("active_contract", false)))
	mid.save_base()
	check("its save keeps the run in progress", bool(JSON.parse_string(FileAccess.get_file_as_string(SAVE)).get("active_contract", false)))
	var tick := make("ticker")
	await step(6)
	check("the ticker only looks", tick.trade_block() == "只读" and is_instance_valid(tick.ticker))
	check("the ticker lists the rate first", tick.ticker.ids()[0] == FactionCatalog.FX)
	check("the command lines", Array(GameManager.app_args("exchange")).has("--exchange") and Array(GameManager.app_args("ticker")).has("--ticker"))
	mid.queue_free()
	tick.queue_free()
	await step(4)
	clean()
	print("TEST_TERMINAL: %d failures" % failures)
	quit(1 if failures > 0 else 0)
