extends SceneTree
## English text overflow scan (用户 2026-11-24: 看英文是否有溢出文本框的情况).
## In English, opens the base's screens and their tabs, the C and B windows,
## the field's route map and an encounter card, and on each finds visible
## Labels and Buttons whose text runs past the box they sit in (the nearest
## Button / Panel / PanelContainer / ScrollContainer, or the label itself when
## it clips) or over another text. Prints each with its screen and a
## screenshot per screen with findings to evidence/en-overflow-*.png.
## Not in run_all (it needs a window). Run with --rendering-method gl_compatibility.

var game: GameManager
var findings: Array = []
var shot := 0
## Screens shot whether or not they have findings, to look at by eye.
const SHOTS := ["exchange/0/0", "sand/0", "sand/1", "operator/2", "store/2", "stash/0", "exchange/5/0", "exchange/3", "construction", "field/route", "personnel/1"]

func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for c in node.get_children():
		var f := find_game(c)
		if f != null: return f
	return null

## The displayed text and its pixel rect inside `c` (global), or an empty rect.
func text_rect(c: Control) -> Rect2:
	var text := ""
	var align := HORIZONTAL_ALIGNMENT_LEFT
	if c is Label:
		var l := c as Label
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.text.strip_edges().is_empty(): return Rect2()
		text = l.text
		align = l.horizontal_alignment
	elif c is Button:
		var b := c as Button
		if b.text.strip_edges().is_empty(): return Rect2()
		text = b.text
		align = b.alignment
	else: return Rect2()
	text = c.atr(text) if c.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else text
	text = I18n.t(text)
	var font := c.get_theme_font("font")
	var size := c.get_theme_font_size("font_size")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r := c.get_global_rect()
	var x := r.position.x
	if align == HORIZONTAL_ALIGNMENT_CENTER: x = r.position.x + (r.size.x - w) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT: x = r.end.x - w
	return Rect2(x, r.position.y + (r.size.y - size) * 0.5, w, size)

func scroll_of(c: Control) -> ScrollContainer:
	var p := c.get_parent()
	while p is Control:
		if p is ScrollContainer: return p
		p = p.get_parent()
	return null

func box_of(c: Control) -> Control:
	var p := c.get_parent()
	while p is Control:
		if p is Button or p is Panel or p is PanelContainer or p is ScrollContainer: return p
		p = p.get_parent()
	return null

func scan(where: String) -> void:
	await step(6)
	var texts: Array = []
	var bad := 0
	for n in _all(root):
		var c := n as Control
		if c == null or not c.is_visible_in_tree() or c.modulate.a < 0.05: continue
		# Watermarks (big faint words behind a page) are not text to read.
		if c.get_theme_color("font_color").a < 0.3: continue
		var t := text_rect(c)
		if t.size.x <= 0.0: continue
		# A clipping label shows only what fits in it (cut, with an ellipsis).
		if (c is Label and (c as Label).clip_text) or (c is Button and (c as Button).clip_text):
			t = t.intersection(c.get_global_rect())
			if t.size.x <= 0.0: continue
		# Clipped by a scroll area: only the part inside it shows.
		var sc := scroll_of(c)
		if sc != null:
			t = t.intersection(sc.get_global_rect())
			if t.size.x <= 0.0: continue
		var shown := I18n.t(c.text)
		var box := c if (c is Button) else box_of(c)
		if box != null and box != c or c is Button:
			var r: Rect2 = (box as Control).get_global_rect()
			if t.position.x < r.position.x - 3.0 or t.end.x > r.end.x + 3.0:
				findings.append([where, shown, "超出 %d px" % roundi(maxf(r.position.x - t.position.x, t.end.x - r.end.x))])
				bad += 1
		# Off the screen.
		if t.end.x > 1283.0 or t.position.x < -3.0:
			findings.append([where, shown, "出屏"])
			bad += 1
		texts.append([t, shown, c])
	for i in range(texts.size()):
		for j in range(i + 1, texts.size()):
			var a: Rect2 = texts[i][0]
			var b: Rect2 = texts[j][0]
			var ca: Control = texts[i][2]
			var cb: Control = texts[j][2]
			if ca.is_ancestor_of(cb) or cb.is_ancestor_of(ca): continue
			var o := a.intersection(b)
			if o.size.x > 4.0 and o.size.y > 4.0:
				findings.append([where, "%s ↔ %s" % [texts[i][1], texts[j][1]], "重叠"])
				bad += 1
	if bad > 0 or where in SHOTS:
		await RenderingServer.frame_post_draw
		shot += 1
		root.get_texture().get_image().save_png("res://../evidence/en-overflow-%02d-%s.png" % [shot, where.replace("/", "_")])
	print("SCAN %s: %d" % [where, bad])

func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children(): out.append_array(_all(c))
	return out

func station(kind: String, where: String) -> void:
	game.close_modal()
	await step(2)
	game.open_station(kind)
	await scan(where)

func run() -> void:
	I18n.set_language("en")
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_tips"] = false
	SystemScreens.settings["tutorial_step"] = 99
	SystemScreens.settings["story_guide"] = false
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	game.gold = 900000
	game.base.max_facilities()
	for id in ["hellagur", "texas", "lin"]: game.base.recruit(id)
	for f in FactionCatalog.FACTIONS: game.exchange.add_relation(str(f), 2000)
	for id in ["螺栓", "胶带", "帆布", "源岩", "电线"]: game.base.receive(MaterialCatalog.create(id, 12))
	game.inventory.try_add(MaterialCatalog.create("螺栓", 5))
	await scan("hall")
	for t in range(BaseScreens.dispatch_tab + 2):
		BaseScreens.dispatch_tab = t
		await station("contracts", "dispatch/%d" % t)
	for t in range(BaseScreens.STASH_TABS.size()):
		game.menu.stash_tab = t
		await station("stash", "stash/%d" % t)
	for t in range(LoadoutScreens.WORKBENCH_TABS.size()):
		game.menu.workbench_tab = t
		await station("loadout", "workbench/%d" % t)
	for kind in ["construction", "outbound", "pharmacy", "report", "workshop", "farm", "canteen", "lift", "prts"]:
		await station(kind, kind)
	for t in range(2):
		BaseScreens.personnel_tab = t
		await station("personnel", "personnel/%d" % t)
	for t in range(EventScreens.CLOSURE_TABS_BASE.size()):
		game.menu.camp_tab = t
		await station("store", "store/%d" % t)
	for t in range(ResearchScreen.TABS.size()):
		ResearchScreen.tab = t
		await station("research", "research/%d" % t)
	for t in range(2):
		SandTableScreen.tab = t
		await station("sand_table", "sand/%d" % t)
	for t in range(ExchangeScreen.TABS.size()):
		ExchangeScreen.tab = t
		if t == 0:
			for m in range(ExchangeScreen.MODES.size()):
				ExchangeScreen.mode = m
				await station("exchange", "exchange/0/%d" % m)
		elif t == 1:
			for m in range(ExchangeScreen.FX_MODES.size()):
				ExchangeScreen.fx_mode = m
				await station("exchange", "exchange/1/%d" % m)
		elif t == 5:
			for a in range(AssetsScreen.ASSET_TABS.size()):
				AssetsScreen.asset_tab = a
				await station("exchange", "exchange/5/%d" % a)
		else: await station("exchange", "exchange/%d" % t)
	game.close_modal()
	for t in range(3):
		game.menu.operator_tab = t
		game.open_training()
		await scan("operator/%d" % t)
		game.close_modal()
	game.toggle_panel("pause")
	for t in range(BaseScreens.SETTING_TABS.size()):
		game.menu.settings_tab = t
		game.menu.pause_page = 1
		BaseScreens.pause(game.menu)
		await scan("settings/%d" % t)
	game.close_modal()
	# The field: the route map and an encounter.
	await game.start_contract("mine")
	await step(10)
	game.toggle_panel("inventory")
	await scan("field/inventory")
	game.close_modal()
	game.floor_number = 3
	game._ensure_route()
	game.open_modal("route")
	game.menu.show_routes(0)
	await scan("field/route")
	game.close_routes()
	print("EN OVERFLOW: %d findings" % findings.size())
	for f in findings: print("  [%s] %s — %s" % f)
	quit(0)
