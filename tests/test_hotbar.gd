extends SceneTree
## Hotbar contents and keybindings (用户 2026-10-10): eight slots, Grim Dawn
## style keybinds with primary/secondary for every function, dedicated keys
## for each skill and flask (mouse side buttons too), bindings never shared.
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
func codes(action: String) -> Array:
	return InputMap.action_get_events(action).map(func(e): return e.physical_keycode if e is InputEventKey else -e.button_index)
func run() -> void:
	SystemScreens.settings["hotbar"] = []
	SystemScreens.settings["keybinds"] = {}
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	check("eight slots: dodge, 绝影, three flasks, three empty", Hotbar.SLOTS == 8 and Hotbar.slots().map(func(s): return s.action) == ["dash", "shadow", "potion_A", "potion_B", "potion_C", "", "", ""])
	check("slot keys default to right mouse, Space, Q, 1–5 (用户 2026-10-20)", ["hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_8"].map(func(id): return codes(id)) == [[-MOUSE_BUTTON_RIGHT], [KEY_SPACE], [KEY_Q], [KEY_1], [KEY_5]])
	check("every function is rebindable with a primary and a secondary", Keybinds.FUNCTIONS.size() >= 20 and Keybinds.all().values().all(func(p): return p.size() == 2))
	check("no movement keys (用户 2026-10-22: 移除 wasd 移动方式)", Keybinds.FUNCTIONS.all(func(f): return not str(f[0]).begins_with("move_")) and not InputMap.has_action("move_up"))
	check("dedicated skill and flask keys start unbound", codes("potion_A").is_empty() and codes("operator_skill").is_empty() and codes("dash").is_empty())
	# A flask on a mouse side button, as its own key.
	check("a flask can take a mouse side button", Keybinds.bind("potion_A", 0, {"mouse": MOUSE_BUTTON_XBUTTON1}) and codes("potion_A") == [-MOUSE_BUTTON_XBUTTON1])
	check("its label reads 侧键 1", Keybinds.short_label("potion_A") == "侧键 1")
	# Taking a key another function has takes it from that function.
	Keybinds.bind("toggle_map", 1, {"key": KEY_Q})
	check("a binding moves, never shared", codes("toggle_map") == [KEY_M, KEY_Q] and codes("hotbar_3").is_empty())
	check("Esc and left mouse cannot be bound", not Keybinds.bind("interact", 0, {"key": KEY_ESCAPE}) and not Keybinds.bind("interact", 0, {"mouse": MOUSE_BUTTON_LEFT}) and codes("interact") == [KEY_E])
	Keybinds.bind("interact", 1, null)
	check("clearing leaves the other binding", codes("interact") == [KEY_E])
	SystemScreens.settings["keybinds"] = {"interact": [{"key": KEY_ESCAPE}, "junk"], "nonsense": [{"key": KEY_K}]}
	check("bad saved bindings fall back per binding", Keybinds.get_pair("interact") == [null, null] and Keybinds.get_pair("toggle_map")[0].key == KEY_M)
	Keybinds.reset()
	check("恢复默认 restores every binding", codes("hotbar_3") == [KEY_Q] and codes("toggle_map") == [KEY_M] and codes("potion_A").is_empty())
	# Slot contents.
	Hotbar.set_action(5, "shadow")
	check("putting 绝影 in slot 6 empties slot 2 (never on the bar twice)", Hotbar.slots()[5].action == "shadow" and Hotbar.slots()[1].action == "")
	Hotbar.reset()
	# Flasks: the slot and the dedicated key drink their own kind.
	await game.start_contract("mine")
	await step(2)
	for item in game.carried_potions():
		game.inventory.remove(item)
		game.safe_bag.remove(item)
	for t in ["A", "B", "B"]: game.inventory.try_add(BaseCatalog.create_potion(t))
	var p := game.player
	p.hp = p.max_hp * 0.4
	game.perform_hotbar_action("potion_B")
	check("a flask slot drinks its own kind", game.carried_potions().filter(func(x): return x.potion_type == "B").size() == 1 and game.carried_potions().size() == 2)
	check("one with none of its kind does nothing", not game.use_potion_type("C") and game.carried_potions().size() == 2)
	game.perform_hotbar_action("dash")
	check("a dodge slot asks for a dodge", p._dash_buffered)
	p._dash_buffered = false
	# The HUD: LMB + eight slots, hit-testing and the picker.
	var hud: Hud = game._hud
	hud.visible = true
	check("the bar shows LMB, eight slots and the auto-potion slot last", hud._hotbar_slots().filter(func(s): return not s.has("item")).size() == 2 + Hotbar.SLOTS and hud._hotbar_slots()[-1].get("auto", false))
	var slot6 := hud._slot_rect(6).get_center()
	check("a point on slot 6 is slot index 5", hud.hotbar_slot_at(slot6) == 5 and hud.hotbar_slot_at(hud._slot_rect(0).get_center()) == -1 and hud.hotbar_slot_at(Vector2(640, 300)) == -2)
	hud.picker_slot = 5
	var rows := hud._picker_rows()
	check("the picker lists every choice above the slot", rows.size() == Hotbar.CHOICES.size() and rows.all(func(r): return r[0].end.y < hud.hotbar_rect().position.y))
	var gel_row: Rect2 = rows.filter(func(r): return r[1] == "potion_B")[0][0]
	check("and reports the choice under the cursor", hud.picker_choice_at(gel_row.get_center()) == "potion_B")
	hud.picker_slot = -1
	# The auto-potion slot (用户 2026-10-15): A or B only, drinks below the low
	# threshold and keeps going, a flask at a time, until at or above the high one.
	var auto_at := hud._config_rect(Hotbar.AUTO).get_center()
	check("the last slot hit-tests as the auto slot", hud.hotbar_slot_at(auto_at) == Hotbar.AUTO)
	hud.picker_slot = Hotbar.AUTO
	check("its picker offers empty, 急救剂 and 缓释凝胶 only", hud._picker_rows().map(func(r): return r[1]) == ["potion_B", "potion_A", ""])
	hud.picker_slot = -1
	Hotbar.set_action(Hotbar.AUTO, "potion_C")
	check("抑制喷剂 cannot go in it", Hotbar.auto_potion() == "")
	Hotbar.set_action(Hotbar.AUTO, "potion_A")
	check("急救剂 goes in, and stays on the bar too", Hotbar.auto_potion() == "potion_A" and Hotbar.slots()[2].action == "potion_A")
	SystemScreens.settings["auto_potion_low"] = 0.4
	SystemScreens.settings["auto_potion_high"] = 0.9
	for item in game.carried_potions():
		game.inventory.remove(item)
		game.safe_bag.remove(item)
	for i in range(4): game.inventory.try_add(BaseCatalog.create_potion("A"))
	game._auto_drinking = false
	game._auto_potion_gap = 0.0
	p.hp = p.max_hp * 0.5
	game._tick_auto_potion(0.01)
	check("above the low threshold she does not drink", game.carried_potions().size() == 4)
	p.hp = 100.0
	var heal := BaseCatalog.POTION_A_HEAL * game._potion_heal_factor * p.potion_heal_multiplier
	var needed := ceili((p.max_hp * 0.9 - 100.0) / heal)
	game._tick_auto_potion(0.01)
	check("below it she drinks one", game.carried_potions().size() == 3)
	game._tick_auto_potion(0.1)
	check("the next waits for the gap", game.carried_potions().size() == 3)
	for i in range(20): game._tick_auto_potion(GameManager.AUTO_POTION_GAP)
	check("then one after another until at or above the high threshold", game.carried_potions().size() == 4 - mini(needed, 4) and (p.hp_ratio() >= 0.9 or game.carried_potions().is_empty()))
	var left := game.carried_potions().size()
	p.hp = p.max_hp * 0.6
	for i in range(5): game._tick_auto_potion(GameManager.AUTO_POTION_GAP)
	check("between the thresholds after that it stays off", game.carried_potions().size() == left)
	Hotbar.set_action(Hotbar.AUTO, "potion_B")
	for i in range(2): game.inventory.try_add(BaseCatalog.create_potion("B"))
	p.hp = 100.0
	game._slow_heal_left = 0.0
	game._tick_auto_potion(GameManager.AUTO_POTION_GAP)
	var gels := game.carried_potions().filter(func(x): return x.potion_type == "B").size()
	for i in range(3): game._tick_auto_potion(GameManager.AUTO_POTION_GAP)
	check("a gel waits for the last gel to finish", game._slow_heal_left > 0.0 and game.carried_potions().filter(func(x): return x.potion_type == "B").size() == gels)
	Hotbar.set_action(Hotbar.AUTO, "")
	SystemScreens.settings["auto_potion_low"] = 0.8
	SystemScreens.settings["auto_potion_high"] = 0.3
	check("a high threshold under the low one is read as the low one", Hotbar.auto_thresholds() == [0.8, 0.8])
	print("TEST_HOTBAR: %d failures" % failures)
	quit(1 if failures > 0 else 0)
