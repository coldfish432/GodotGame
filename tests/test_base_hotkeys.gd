extends SceneTree

## 主基地快捷栏 (用户 2026-11-06): every base station has a key of its own,
## shown on a bar along the bottom (the base only); an unlocked one opens what
## E opens there, a locked one only says what it waits for, and what it says
## is what the code checks (BaseHotkeys).

var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

## Presses `id`'s key for a frame.
func press(id: String) -> void:
	var action := BaseHotkeys.action(id)
	Input.action_press(action)
	await step(1)
	Input.action_release(action)
	await step(1)

func close() -> void:
	game.close_modal()
	await step(2)

## What the menu shows: its station kind, or the build site's.
func hud_of() -> BaseHud:
	for n in game.find_children("*", "Control", true, false):
		if n is BaseHud: return n
	return null

func shown() -> String:
	return "%s/%s" % [game.modal, game.menu._station]

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	var base := game.base_map
	_keys(base)
	await _unlocked(base)
	await _locked()
	await _bar()
	await _field_hides()
	print("BASE HOTKEYS RESULT: %d failures" % failures)
	game.queue_free()
	await step(2)
	quit(1 if failures > 0 else 0)

## Every station (but the second lift and the construction sites, which the
## hub reaches) has a key; the keys are rebindable and clash with nothing.
func _keys(base: BaseMap) -> void:
	var ids := BaseHotkeys.ids()
	var missing: Array = []
	for station in base.interactables:
		if station.kind == "build_site" or station.id == "lift2": continue
		if not station.id in ids: missing.append(station.id)
	check("every base station has a key (%d)" % ids.size(), missing.is_empty() and ids.size() == 17, missing)
	check("each key's station exists", ids.all(func(id): return not base.station(id).is_empty()))
	var seen := {}
	var clash: Array = []
	var binds := Keybinds.all()
	for f in Keybinds.FUNCTIONS:
		for b in binds[f[0]]:
			if b == null: continue
			var k := JSON.stringify(b)
			if seen.has(k): clash.append([f[0], seen[k]])
			seen[k] = f[0]
	check("no two functions share a default key", clash.is_empty(), clash)
	var unbound := ids.filter(func(id): return Keybinds.info(BaseHotkeys.action(id)).is_empty() or Keybinds.get_pair(BaseHotkeys.action(id))[0] == null)
	check("each is a Keybinds function with a default key, in the 基地站点 group", unbound.is_empty()
		and ids.all(func(id): return Keybinds.info(BaseHotkeys.action(id))[2] == "基地站点"), unbound)
	var taken := ["interact", "toggle_inventory", "toggle_operator", "camera_turn_left", "camera_turn_right", "camera_tilt_up", "camera_tilt_down",
		"camera_reset", "quick_pack", "toggle_prts", "show_items", "toggle_stations", "toggle_watch"]
	var ours: Array = ids.map(func(id): return JSON.stringify(Keybinds.get_pair(BaseHotkeys.action(id))[0]))
	check("none takes E, B, C, P, Z/X, PgUp/PgDn, Home, Enter, Alt, Tab, K", taken.all(func(t): return not JSON.stringify(Keybinds.get_pair(t)[0]) in ours))
	# Rebinding: the settings move the key, and the old one stops.
	Keybinds.bind(BaseHotkeys.action("stash"), 0, {"key": KEY_F7})
	check("rebinding moves a station's key", Keybinds.short_label(BaseHotkeys.action("stash")) == "F7"
		and InputMap.action_has_event(BaseHotkeys.action("stash"), Keybinds.event_for({"key": KEY_F7})))
	Keybinds.reset()
	check("and reset brings back its default", Keybinds.short_label(BaseHotkeys.action("stash")) == "S")

## Everything open: each key opens what E opens standing at the station.
func _unlocked(base: BaseMap) -> void:
	game.base.dept_lock = false
	for id in ["hub", "exchange", "lab", "farm", "canteen"]: game.base.facilities[id] = 1
	var arrival := base.spawn_point("arrival")
	for id in BaseHotkeys.ids():
		check(id + " is open", not BaseHotkeys.locked(game, id), BaseHotkeys.refusal(game, id))
		# E at the station.
		var station := base.station(BaseHotkeys.station_id(game, id))
		game.player.teleport(station.position)
		await step(1)
		Input.action_press("interact")
		await step(1)
		Input.action_release("interact")
		await step(1)
		var by_e := shown()
		await close()
		game.player.teleport(arrival)
		await step(1)
		await press(id)
		var by_key := shown()
		check("%s's key opens what E opens there (%s)" % [id, by_key], by_e.begins_with("station/") and by_key == by_e, by_e)
		# Keys do nothing while a screen is up.
		var other: String = "dispatch" if id != "dispatch" else "stash"
		await press(other)
		check(id + ": another station's key does nothing over an open screen", shown() == by_key)
		await close()
	# The lift's key is the lift of her own deck.
	game.ride_lift(2)
	await step(2)
	check("on the second deck the lift key is its lift", BaseHotkeys.station_id(game, "lift") == "lift2")
	await press("lift")
	check("and opens the lift", shown() == "station/lift")
	await close()
	game.ride_lift(1)
	await step(2)
	# Before the hub stands its key opens its build site, as E there does.
	game.base.facilities["hub"] = 0
	await press("site_hub")
	check("before the hub is built its key opens its build site", shown() == "station/build_site")
	await close()
	game.base.facilities["hub"] = 1

## A new save: the departments shut, nothing built. Locked keys say what the
## code waits for and open nothing.
func _locked() -> void:
	game.base.start_locked()
	for id in ["exchange", "lab", "farm", "canteen"]: game.base.facilities[id] = 0
	game.exchange.relations["karlan"] = 0
	var expect := {
		"exchange": ["需要%s关系 %s" % [FactionCatalog.name_of("karlan"), Exchange.rank_name(2)], "负责干员 %s 失散" % LostCatalog.name_of("tulip"), "需要交易所 Lv1"],
		"research": ["负责干员 %s 失散" % LostCatalog.name_of("pith"), "需要科研部 Lv%d" % ResearchCatalog.OPEN_LEVEL],
		"farm": ["负责干员 %s 失散" % LostCatalog.name_of("touch"), "需要农业部 Lv1"],
		"canteen": ["负责干员 %s 失散" % LostCatalog.name_of("touch"), "需要食堂 Lv1"],
		"workshop": ["负责干员 %s 失散" % LostCatalog.name_of("mechanist")],
		"sand_table": ["负责干员 %s 失散" % LostCatalog.name_of("stormeye")],
	}
	var locked: Array = BaseHotkeys.ids().filter(func(id): return BaseHotkeys.locked(game, id))
	locked.sort()
	var want: Array = expect.keys()
	want.sort()
	check("on a new save exactly these are locked: %s" % str(locked), locked == want)
	for id in expect:
		check(id + "'s needs are the code's", str(BaseHotkeys.needs_of(game, id)) == str(expect[id]), BaseHotkeys.needs_of(game, id))
	# The same conditions the code gates on.
	check("交易所: the same relation its building waits for", game.facilities.gate_refusal("exchange") == expect.exchange[0] and not game.exchange.unlocked())
	check("科研部: research refuses with the same level", game.research.refusal("logistics_1") == expect.research[1])
	check("加工部 and the voyage: the same lost operators the screens show", game.dept_refusal("workshop") == expect.workshop[0] and game.dept_refusal("voyage") == expect.sand_table[0])
	for id in expect:
		game.set_message("")
		await press(id)
		check(id + "'s key opens nothing and says what it waits for", game.modal.is_empty() and game.message == BaseHotkeys.refusal(game, id)
			and game.message.begins_with(BaseHotkeys.name_of(id) + "：") and (expect[id] as Array).all(func(n): return n in game.message), game.message)
	# Once met, they open.
	game.base.find_lost("mechanist")
	await press("workshop")
	check("机械师 back: the workshop key opens the 加工站", shown() == "station/workshop")
	await close()
	game.exchange.relations["karlan"] = Exchange.RANK_AT[2]
	check("the relation met, the exchange still waits for 郁金香 and its build", str(BaseHotkeys.needs_of(game, "exchange")) == str(expect.exchange.slice(1)))
	game.base.find_lost("tulip")
	game.base.facilities["exchange"] = 1
	await press("exchange")
	check("built: the exchange key opens the exchange", shown() == "station/exchange")
	await close()

## The bar: one slot per station, its key on it, a click is the key.
func _bar() -> void:
	var hud: BaseHud = hud_of()
	var bar := hud.hotkey_bar
	await step(1)
	check("the bar shows in the base, a slot per station", hud.visible and bar.is_visible_in_tree() and bar.size.x == BaseHud.HotkeyBar.width())
	var quick := hud.quick_bar
	check("it stays clear of the quick buttons", bar.position.x + bar.size.x < quick.position.x)
	# 用户 2026-11-06: PRTS, 干员 and the menu in the same look, each with its key; no 合同 or 基建.
	var names: Array = range(quick.count()).map(func(k): return quick.name_of(k))
	var keys: Array = range(quick.count()).map(func(k): return quick.key_of(k))
	check("the quick buttons are PRTS / 干员 / 菜单 with Enter / C / Esc (%s %s)" % [names, keys],
		names == ["PRTS", "干员", "菜单"] and keys == ["Enter", "C", "Esc"])
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	for k in range(quick.count()):
		tap.position = BaseHud.SlotBar.slot_rect(k).get_center()
		quick._gui_input(tap)
		await step(1)
		var opened := game.modal
		check("clicking %s opens it (%s)" % [names[k], opened], opened == ["station", "training", "pause"][k] and (k != 0 or game.menu._station == "prts"))
		await close()
	var i := BaseHotkeys.ids().find("canteen")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = BaseHud.HotkeyBar.slot_rect(i).get_center()
	game.set_message("")
	bar._gui_input(click)
	await step(1)
	check("clicking a locked slot only says what it waits for", game.modal.is_empty() and game.message == BaseHotkeys.refusal(game, "canteen"), game.message)
	click.position = BaseHud.HotkeyBar.slot_rect(BaseHotkeys.ids().find("pharmacy")).get_center()
	bar._gui_input(click)
	await step(1)
	check("clicking an open slot opens it", shown() == "station/pharmacy")
	await close()
	game.toggle_panel("training")
	await step(1)
	check("the bar hides while a window is open", not bar.is_visible_in_tree())
	game.toggle_panel("training")
	await step(1)

## Not in the field.
func _field_hides() -> void:
	var hud: BaseHud = hud_of()
	await game.start_contract("mine")
	await step(2)
	check("on a contract the bar is gone", not hud.hotkey_bar.is_visible_in_tree())
	game.set_message("")
	await press("pharmacy")
	check("and its keys do nothing there", game.modal.is_empty() or game.modal != "station")
	game.settle(true)
	await step(2)
