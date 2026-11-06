class_name GmSave
extends RefCounted

## GameManager's base save: writing and reading the save file, the coalesced
## write of the hot paths (save_base_soon), and the save's writer lock shared
## with the terminal and ticker (交易终端与盯盘小窗策划案_v1_0.md §3). The
## entry points stay on GameManager (save_base, load_base, writer…).

var game: GameManager
var _lock_left := 0.0
## While claim() waits for the writer lock; _process does nothing meanwhile.
var claiming := false
var _seen_seq := ""
## A terminal or ticker follows this save: the market is saved every few seconds.
var followed := false
## The save's Doctor is out on a contract (the terminal is then read-only).
var saved_active := false
## save_base_soon's pending write and its arguments.
var queued := false
var _queued_args: Array = [false, {}]

func _init(owner: GameManager) -> void:
	game = owner

## Takes the save's writer lock. The game waits for a terminal or ticker to
## step down (saving first), then takes it; a terminal or ticker that finds a
## writer reads instead (§3.1).
func claim() -> void:
	game.save_lock = SaveLock.new(game.save_path, game.app_mode if not game.app_mode.is_empty() else "game")
	var save_lock := game.save_lock
	if save_lock.try_claim() or not game.app_mode.is_empty(): return
	if str(save_lock.current().get("mode", "")) != "game": save_lock.request_release()
	claiming = true
	var waited := 0.0
	while waited < GameManager.RELEASE_WAIT:
		await game.get_tree().create_timer(0.2).timeout
		waited += 0.2
		if save_lock.try_claim(): break
	if not save_lock.holder: save_lock.force_claim()
	claiming = false

## Every BEAT seconds: the writer beats and steps down when the game asks; a
## reader beats, reloads when the writer saved, and takes over when it is gone.
func lock_tick(delta: float) -> void:
	var save_lock := game.save_lock
	if save_lock == null or not game.save_enabled: return
	_lock_left -= delta
	if _lock_left > 0.0: return
	_lock_left = SaveLock.BEAT
	# The game never gives the save up: if a terminal took a lock it thought
	# stale (a long floor build), the game takes it back and asks it to read.
	if not save_lock.still_holder() and game.app_mode.is_empty():
		save_lock.request_release()
		save_lock.force_claim()
	save_lock.beat()
	if save_lock.holder:
		var was := followed
		followed = save_lock.readers_present()
		if followed and not was: game._market_save_left = minf(game._market_save_left, GameManager.MARKET_SAVE_FOLLOWED)
		if save_lock.release_requested():
			game.save_base()
			save_lock.release()
			_seen_seq = ""
			game._refresh_app()
		return
	var d := save_lock.current()
	if not SaveLock.alive(d):
		_reload_from_disk()
		if save_lock.try_claim(): game._refresh_app()
		return
	# A new save, or a new writer: read again.
	var mark := "%s/%d" % [d.get("id", ""), int(d.get("seq", -1))]
	if mark != _seen_seq:
		_seen_seq = mark
		_reload_from_disk()

## A reader picks up what the writer saved: the market, then the account (§3.2).
func _reload_from_disk() -> void:
	var market := game.market
	market.load_file(game.market_path())
	Economy.fx = market.fx_rate()
	game.load_base()
	market.advance_to(BaseState.now())
	Economy.fx = market.fx_rate()
	game._refresh_app()

## Hot paths (pickups, bag moves, flasks): one write at the end of the frame,
## with the last call's arguments, as if that call had saved then.
func save_soon(active_contract: bool, run: Dictionary) -> void:
	if not game.save_enabled or not game.writer(): return
	_queued_args = [active_contract, run]
	if queued: return
	queued = true
	game._flush_queued_save.call_deferred()

func flush() -> void:
	if not queued: return
	queued = false
	game.save_base(_queued_args[0], _queued_args[1])

func write(active_contract: bool, run: Dictionary) -> void:
	if not game.save_enabled or not game.writer(): return
	# This write is the newest: a queued one has nothing left to add.
	queued = false
	var player := game.player
	var carried := game.carried_items()
	var worn := {}
	for item in player.equipped.values(): worn[item] = true
	var loadout: Array = []
	for item in carried:
		var entry := item.to_data()
		entry["place"] = "safe" if game.safe_bag.items.has(item) else ("equipped" if worn.has(item) else "pack")
		loadout.append(entry)
	var carried_set := {}
	for item in carried: carried_set[item] = true
	var left_behind: Array = []
	for item in game._insured_left_behind:
		if not carried_set.has(item): left_behind.append(item.to_data())
	var data := {"version": 3, "gold": game.gold, "base": game.base.to_data(), "loadout": loadout, "left_behind": left_behind,
		"active_contract": active_contract, "settlement": game.settlement, "rng_state": str(game.rng.state), "rng_streams": game.rng_states(),
		"exchange": game.exchange.to_data(), "workshop": game.workshop.to_data(), "voyage": game.voyage.to_data(), "consign": game.consign.to_data()}
	if not run.is_empty(): data["run"] = run
	var save_path := game.save_path
	# The terminal and ticker only touch these three (交易终端策划案 §3.4):
	# the rest of the save stays as the game left it.
	if not game.app_mode.is_empty() and FileAccess.file_exists(save_path):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if old is Dictionary:
			for key in ["gold", "base", "exchange"]: old[key] = data[key]
			data = old
	game.market.save_file(game.market_path())
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		game.notice("存档写入失败：当前会话仍可继续。")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(save_path): DirAccess.copy_absolute(save_path, save_path + ".bak")
	if DirAccess.rename_absolute(save_path + ".tmp", save_path) != OK:
		game.notice("存档替换失败，旧存档保留。")
	game.save_lock_saved()

func read() -> void:
	flush()
	var save_path := game.save_path
	var base := game.base
	if not FileAccess.file_exists(save_path):
		base.start_locked()
		return
	# An empty save (and backup) is no save: start fresh and keep saving.
	if FileAccess.get_file_as_string(save_path).strip_edges().is_empty() and (not FileAccess.file_exists(save_path + ".bak") or FileAccess.get_file_as_string(save_path + ".bak").strip_edges().is_empty()): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or not int(parsed.get("version", 0)) in [1, 2, 3]:
		if FileAccess.file_exists(save_path + ".bak"):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path + ".bak"))
		if not parsed is Dictionary or not int(parsed.get("version", 0)) in [1, 2, 3]:
			game.notice("无法读取存档；原文件保留，请检查备份。")
			game.save_enabled = false
			return
	# Before version 3 the balance was 资金; it is 龙门币 now, ×100 (经济修订案 §3).
	game.gold = int(parsed.get("gold", 60)) * (1 if int(parsed.get("version", 1)) >= 3 else Economy.LMD_PER_VALUE)
	var seen := {}
	# Version 1 kept one flat warehouse list; it goes onto the shelves (BaseState.place_loose).
	if int(parsed.get("version", 1)) == 1: base.migrate_v1(parsed.get("stash", []), seen)
	else: base.load_data(parsed.get("base", {}), seen)
	game.exchange.load_data(parsed.get("exchange", {}))
	game.workshop.load_data(parsed.get("workshop", {}))
	game.voyage.load_data(parsed.get("voyage", {}))
	game.consign.load_data(parsed.get("consign", {}))
	game.research.apply_globals()
	var player := game.player
	player.set_operator(base.operator)
	game.refresh_look()
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	game.apply_container_sizes()
	player.reset_stats()
	for data in parsed.get("loadout", []):
		var item := Item.from_data(data)
		if seen.has(item.uid): continue
		seen[item.uid] = true
		match data.get("place", "pack"):
			"equipped": player.equip(item)
			"safe": game.safe_bag.try_add(item)
			_: game.inventory.try_add(item)
	base.purge_bound()
	game.refresh_rhodes()
	game.shed_unusable_weapon()
	game.settlement.assign(parsed.get("settlement", []))
	game._insured_left_behind.clear()
	for data in parsed.get("left_behind", []):
		var dropped := Item.from_data(data)
		if not seen.has(dropped.uid) and dropped.insured: game._insured_left_behind.append(dropped)
	saved_active = bool(parsed.get("active_contract", false))
	# The terminal and ticker never settle a run in progress: only the game does.
	if saved_active and game.app_mode.is_empty():
		game.set_rng_states(parsed.get("rng_streams", parsed.get("rng_state", "1")))
		# Saved and quit in the field (RunSave): she goes on where she was.
		var run: Variant = parsed.get("run")
		if run is Dictionary and int(run.get("version", 0)) == RunSave.VERSION:
			game._resume = run
			return
		game._settled = false
		game.settle(false)
		game.set_message("检测到中断合同：按撤退规则回收出发物品，保险结果不会反复重掷。")
