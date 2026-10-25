class_name EventScreens
extends RefCounted

## The in-run event screens, laid out as in the prototype (界面策划案 v1.1 #7–#10,
## art/ui_mockup): relic pick, route node map, the Rhodes squad, 坎诺特, the camp
## and the settlement. Each builds onto FieldMenu.stage (absolute 1280×720
## layout); FieldMenu.pick holds what is selected on the screen.
## Data, state and buttons only — no rule text (用户 2026-10-05).

const SOURCE_EN := {"device": "ENHANCEMENT DEVICE", "cache": "COMBAT CACHE", "vault": "SEALED VAULT"}

static func _title(stage: Control, at: Vector2, en_text: String, cn_text: String, sub: String = "", en_color: Color = AK.MUTE) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.add_child(AK.label(en_text, 11, en_color, AK.en()))
	column.add_child(AK.label(cn_text, 34, AK.FG))
	if not sub.is_empty(): column.add_child(AK.label(sub, 13, AK.MUTE))
	AK.put(stage, column, at)

static func _close(stage: Control, menu: FieldMenu, at: Vector2 = Vector2(1216, 12)) -> Button:
	var b := AK.button("✕", "ghost", 18)
	AK.put(stage, b, at, Vector2(52, 52))
	b.pressed.connect(menu.game.close_modal)
	return b

## The ✕ / ✓ pair at the foot of AK event screens.
static func _footer(stage: Control, at: Vector2, width: float, leave: String, confirm: String, on_leave: Callable, on_confirm: Callable, enabled: bool) -> Button:
	var half := width * 0.5
	if not leave.is_empty():
		var out := AK.button("✕ " + leave, "plain", 16)
		AK.style_button(out, "plain")
		AK.put(stage, out, at, Vector2(half, 58))
		out.pressed.connect(on_leave)
	else:
		half = 0.0
	var go := AK.button("✓ " + confirm, "blue", 16)
	AK.put(stage, go, at + Vector2(half, 0), Vector2(width - half, 58))
	go.disabled = not enabled
	go.pressed.connect(on_confirm)
	return go

## NPC portraits (art/characters/npc/prepare_npc.py), drawn at 4x like Lappland's.
const PORTRAITS := {
	"squad": preload("res://art/characters/npc/npc_squad_portrait.png"),
	"trader": preload("res://art/characters/npc/npc_cannot_portrait.png"),
	"closure": preload("res://art/characters/npc/npc_closure_portrait.png"),
}
const PORTRAIT_SCALE := 4

## A dark side panel with a tinted gradient, an outlined watermark and the
## NPC's portrait standing on the panel's foot (a placeholder figure without one).
static func _side(stage: Control, width: float, tint: Color, watermark: String, figure: Color, portrait: String = "") -> Control:
	var side := Control.new()
	AK.put(stage, side, Vector2.ZERO, Vector2(width, 720))
	side.clip_contents = true
	var gradient := Gradient.new()
	gradient.set_color(0, tint)
	gradient.set_color(1, Color("090b0c"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0.75, 0.9)
	var back := TextureRect.new()
	back.texture = texture
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(back)
	var mark := AK.label(watermark, 104, Color(figure, 0.1), AK.en())
	mark.position = Vector2(-8, 470)
	side.add_child(mark)
	if PORTRAITS.has(portrait):
		var art: Texture2D = PORTRAITS[portrait]
		var image := TextureRect.new()
		image.texture = art
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shown := art.get_size() * PORTRAIT_SCALE
		AK.put(side, image, Vector2(roundf((width - shown.x) * 0.5), 720 - shown.y), shown)
		return side
	var silhouette := Silhouette.new()
	silhouette.colour = figure
	AK.put(side, silhouette, Vector2(width * 0.5 - 75, 200), Vector2(150, 260))
	return side

# --- #7 藏品三选一 -------------------------------------------------------------------

static func builds(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.86)
	var offers: Array = game.build_offers
	var pick := int(menu.pick) if menu.pick is int else -1
	_title(stage, Vector2(60, 40), SOURCE_EN.get(game.offer_source, "ENHANCEMENT DEVICE"), "选择藏品", FieldMenu.OFFER_TITLES.get(game.offer_source, "强化装置"))
	_close(stage, menu)
	var total := offers.size() * 250 + maxi(0, offers.size() - 1) * 70
	for i in range(offers.size()):
		var offer: Dictionary = offers[i]
		var colour: Color = RelicCatalog.RARITY_COLORS[offer.rarity]
		var card := Button.new()
		card.flat = true
		card.focus_mode = Control.FOCUS_NONE
		card.set_meta("label", "选择 " + offer.name)
		AK.put(stage, card, Vector2((1280 - total) * 0.5 + i * 320, 150), Vector2(250, 320))
		var icon := AK.relic_icon(offer, 144)
		AK.put(card, icon, Vector2(53, 3))
		if i == pick: AK.frame(icon, AK.SP, 3.0)
		var tags := HBoxContainer.new()
		tags.alignment = BoxContainer.ALIGNMENT_CENTER
		tags.add_theme_constant_override("separation", 6)
		tags.add_child(AK.tag(RelicCatalog.RARITY_NAMES[offer.rarity], colour))
		tags.add_child(AK.tag(AK.KIND_NAMES.get(offer.kind, offer.kind), AK.PLATE_3, false))
		AK.put(card, tags, Vector2(0, 166), Vector2(250, 20))
		var name := AK.label(offer.name, 20, AK.FG)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		AK.put(card, name, Vector2(0, 194), Vector2(250, 30))
		var effect := AK.label(offer.effect, 14, AK.FG)
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		AK.put(card, effect, Vector2(0, 230), Vector2(250, 60))
		for child in card.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var index := i
		card.pressed.connect(func(): menu.pick = index; builds(menu))
	# The band: the PRTS original of the selected one, refresh, acquire.
	AK.put(stage, AK.rect(Color(0.055, 0.055, 0.055, 0.96), Vector2(0, 608), Vector2(1280, 112)), Vector2(0, 608))
	AK.put(stage, AK.label("ORIGINAL EFFECT · PRTS", 9, AK.DIM, AK.en()), Vector2(60, 632))
	if pick >= 0 and pick < offers.size():
		var original := AK.label(offers[pick].original, 13, AK.MUTE, AK.italic())
		original.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		AK.put(stage, original, Vector2(60, 650), Vector2(620, 50))
	var reroll := AK.button("刷新 %d" % game.reroll_cost(), "plain", 15)
	AK.put(stage, reroll, Vector2(760, 636), Vector2(150, 56))
	reroll.disabled = game.gold_bars() < game.reroll_cost()
	reroll.pressed.connect(func(): menu.pick = -1; game.reroll_offers())
	var take := AK.go_button("获取", "ACQUIRE")
	AK.put(stage, take, Vector2(1000, 632), Vector2(220, 64))
	take.disabled = pick < 0 or pick >= offers.size()
	take.pressed.connect(func():
		if pick >= 0 and pick < offers.size():
			menu.pick = null
			game.choose_build(offers[pick].id))

# --- #8 路线选择 ---------------------------------------------------------------------

## The block's route map (肉鸽路线图策划案 v0.2 §7): ten columns left to right
## and the camp at the end. Walked columns and the next one show names; the one
## after shows only "未知作战" / "未知遭遇"; further on, only floor codes, the
## extraction's and the contract's tags, and the block's last floor. `index`
## is the line picked first (the marker she stood at).
static func routes(menu: FieldMenu, index: int) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.97)
	var map: Dictionary = game.route_map
	var here: Vector2i = game.route_node
	var rows: Array = game.route_choices()
	var pick := clampi(int(menu.pick) if menu.pick is int else index, 0, maxi(0, rows.size() - 1))
	_title(stage, Vector2(84, 18), "INTEGRATED ROUTE", "选择去向")
	var back := AK.button("‹", "ghost", 24)
	AK.put(stage, back, Vector2(24, 26), Vector2(48, 48))
	back.pressed.connect(game.close_routes)
	var money := AK.money("gold", str(game.gold_bars()))
	AK.put(stage, money, Vector2(860, 30))
	var block := int(map.get("block", 0))
	var cols: Array = map.get("cols", [])
	var clear: int = game.route_sight()
	# The map scrolls sideways when it is wider than its room (用户 2026-10-24:
	# 一张图放不下就做可滑动的): drag or the wheel; it opens on the column ahead.
	var view := RouteView.new()
	AK.put(stage, view, Vector2(0, ROUTE_TOP), Vector2(970, 720 - ROUTE_TOP - 40))
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_PASS
	var width := ROUTE_X0 * 2.0 + (cols.size() + 1) * ROUTE_STEP
	layer.custom_minimum_size = Vector2(width, 720 - ROUTE_TOP - 52)
	view.add_child(layer)
	var lines := RouteLines.new()
	AK.put(layer, lines, Vector2.ZERO, layer.custom_minimum_size)
	var ahead_x := ROUTE_X0 + (here.x + 2) * ROUTE_STEP
	var start: float = menu.get_meta("route_scroll", -1.0) if menu.pick is int else -1.0
	if start < 0.0: start = clampf(ahead_x - 330.0, 0.0, maxf(0.0, width - 970.0))
	view.set_deferred("scroll_horizontal", roundi(start))
	view.get_h_scroll_bar().value_changed.connect(func(v: float): menu.set_meta("route_scroll", v))
	var centres := {}   # Vector2i -> centre
	for c in range(cols.size()):
		var col: Array = cols[c]
		for r in range(col.size()):
			centres[Vector2i(c, r)] = Vector2(ROUTE_X0 + (c + 1) * ROUTE_STEP, ROUTE_MID + (r - (col.size() - 1) * 0.5) * ROUTE_ROW)
	var origin := Vector2(ROUTE_X0, ROUTE_MID)
	var camp_at := Vector2(ROUTE_X0 + (cols.size() + 1) * ROUTE_STEP, ROUTE_MID)
	var trail: Array = game.route_trail
	# The lines first, under the nodes.
	for c in range(cols.size() - 1):
		var near_sight := RouteMap.sight(c + 1, here.x, clear)
		if near_sight == "dark" and c + 1 != cols.size() - 1: continue
		for r in range(cols[c].size()):
			for to in map.edges[c][r]:
				var a: Vector2 = centres[Vector2i(c, r)]
				var b: Vector2 = centres[Vector2i(c + 1, int(to))]
				var walked := c + 1 < trail.size() and int(trail[c]) == r and int(trail[c + 1]) == int(to)
				var ahead := c == here.x and r == here.y
				if near_sight == "dark": continue
				lines.links.append([a, b, "walked" if walked else ("ahead" if ahead else "faint")])
	if here.x < 0 and block > 0:
		for r in range(cols[0].size()): lines.links.append([origin, centres[Vector2i(0, r)], "ahead"])
	for r in range(cols[cols.size() - 2].size() if cols.size() > 1 else 0):
		if RouteMap.sight(cols.size() - 2, here.x, clear) != "dark": lines.links.append([centres[Vector2i(cols.size() - 2, r)], centres[Vector2i(cols.size() - 1, 0)], "faint"])
	lines.links.append([centres.get(Vector2i(cols.size() - 1, 0), camp_at), camp_at, "faint"])
	if block > 0: _route_node(layer, origin, "", "小队营地", "here" if here.x < 0 else "done", AK.GREEN)
	# The floor codes along the foot, tags over the dark columns.
	for c in range(cols.size()):
		var x := ROUTE_X0 + (c + 1) * ROUTE_STEP
		var code := AK.floor_code(game.region_id, RouteMap.floor_of(block, c))
		var cell := AK.label(code, 10, AK.FG if c == here.x + 1 else AK.DIM, AK.en())
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		AK.put(layer, cell, Vector2(x - 36, ROUTE_CODES), Vector2(72, 14))
		if RouteMap.sight(c, here.x, clear) == "dark" and c != cols.size() - 1:
			var tags := _route_tags(cols[c])
			if not tags.is_empty(): AK.put(stage, AK.tag(" · ".join(PackedStringArray(tags.map(func(t): return str(t[0])))), tags[0][1]), Vector2(x - 34, ROUTE_CODES - 40))
	for c in range(cols.size()):
		var seen := RouteMap.sight(c, here.x, clear)
		var last := c == cols.size() - 1
		if seen == "dark" and not last: continue
		for r in range(cols[c].size()):
			var node: Dictionary = cols[c][r]
			var at: Vector2 = centres[Vector2i(c, r)]
			var kind := str(node.kind)
			var info := RouteMap.info(kind)
			var state := "far"
			if c == here.x and r == here.y: state = "here"
			elif c < here.x or (c == here.x): state = "walked" if c < trail.size() and int(trail[c]) == r else "done"
			elif c == here.x + 1 and rows.has(r): state = "next"
			var name := RouteMap.kind_name(kind)
			if seen == "fuzzy" and not last:
				name = "未知作战" if RouteMap.is_fight(kind) else "未知遭遇"
				state = "fuzzy"
			var tags := " · ".join(PackedStringArray(_route_tags([node]).map(func(t): return str(t[0]))))
			var b := _route_node(layer, at, tags, name, state, info.color if seen != "fuzzy" else AK.DIM, state == "next" and rows.find(r) == pick)
			if state == "next":
				var line := rows.find(r)
				b.set_meta("label", "进入 " + name)
				b.pressed.connect(func(): menu.pick = line; routes(menu, index))
	_route_node(layer, camp_at, "", "小队营地", "far", AK.GREEN)
	lines.queue_redraw()
	# The picked node's data on the right.
	AK.put(stage, AK.rect(Color(0.055, 0.055, 0.055, 0.96), Vector2(980, 80), Vector2(300, 640)), Vector2(980, 80))
	AK.put(stage, AK.rect(Color("090b0c"), Vector2(980, 80), Vector2(300, 150)), Vector2(980, 80))
	var target := Vector2i(here.x + 1, int(rows[pick])) if not rows.is_empty() else Vector2i(-1, -1)
	var camp_next := not game.in_camp and game.floor_number % FieldCatalog.CAMP_INTERVAL == 0
	var picked := RouteMap.node_at(map, target) if not camp_next else {}
	var kind := str(picked.get("kind", ""))
	var info := RouteMap.info(kind)
	var colour: Color = AK.GREEN if camp_next else info.color
	AK.put(stage, AK.rect(colour, Vector2(980, 227), Vector2(300, 3)), Vector2(980, 227))
	if camp_next:
		AK.put(stage, AK.label("SQUAD CAMP", 10, AK.MUTE, AK.en()), Vector2(996, 96))
		AK.put(stage, AK.label(game.camp_label(game.floor_number), 24, colour), Vector2(996, 112))
	elif not picked.is_empty():
		AK.put(stage, AK.label("%02d" % (RouteMap.col_of(RouteMap.floor_of(block, target.x)) + 1), 80, Color(1, 1, 1, 0.06), AK.en()), Vector2(988, 128))
		AK.put(stage, AK.label(str(info.en), 10, AK.MUTE, AK.en()), Vector2(996, 96))
		AK.put(stage, AK.label(RouteMap.kind_name(kind), 24, colour), Vector2(996, 112))
		var y := 248.0
		var calm := bool(info.get("calm", false))
		var danger := float(info.danger)
		var level := 0 if calm else (1 if danger <= -2.0 else (2 if danger < 3.0 else 3))
		for row in [["危险", level], ["威胁", 0 if calm else 2]]:
			AK.put(stage, AK.label(row[0], 13, AK.MUTE), Vector2(996, y))
			for k in range(3): AK.put(stage, AK.rect(colour if k < int(row[1]) else AK.LINE, Vector2.ZERO, Vector2(22, 8)), Vector2(1196 + k * 26, y + 6))
			y += 30
		AK.put(stage, AK.label("掉落加成", 13, AK.MUTE), Vector2(996, y))
		AK.put(stage, AK.label("+%d%%" % roundi(float(info.reward) * 100), 20, AK.SP, AK.en()), Vector2(1200, y - 6))
		y += 34
		AK.put(stage, AK.rect(AK.LINE, Vector2.ZERO, Vector2(268, 1)), Vector2(996, y))
		y += 12
		for entry in _route_contents(game, picked):
			AK.put(stage, AK.label(entry[0], 14, entry[1]), Vector2(996, y))
			y += 24
	var go := AK.go_button("前进", "PROCEED")
	AK.put(stage, go, Vector2(996, 634), Vector2(268, 66))
	go.disabled = rows.is_empty()
	go.pressed.connect(func(): menu.pick = null; game.advance(pick))

const ROUTE_X0 := 44.0
const ROUTE_STEP := 104.0
## The scrolling map's top on the stage; inside it, the nodes' middle row and the floor codes.
const ROUTE_TOP := 90.0
const ROUTE_MID := 270.0
const ROUTE_CODES := 548.0
const ROUTE_ROW := 92.0
const ROUTE_HALF := 34.0

## The tags a column shows even in the dark: the extraction, the contract's marks.
static func _route_tags(col: Array) -> Array:
	var out: Array = []
	for node in col:
		if bool(node.get("exit", false)): out.append(["撤离信标", AK.GREEN])
		match str(node.get("mark", "")):
			"bounty": out.append(["悬赏", AK.SP])
			"search": out.append(["合同", AK.SP])
			"deliver": out.append(["交货", AK.SP])
	return out

## What a node holds, as words (no sentences): who stands there and what is found.
static func _route_contents(game: GameManager, node: Dictionary) -> Array:
	var kind := str(node.kind)
	var out: Array = []
	match kind:
		"trader": out.append(["坎诺特", AK.SP])
		"rest": out.append_array([["罗德岛小队", AK.CYAN], ["营火", AK.FG], ["冲淋装置", AK.FG]])
		"relic": out.append_array([["藏品箱 ×3", Color("c48cff")], ["兴趣点 +2", AK.FG]])
		"elite": out.append(["恶敌", AK.RED])
		"vault": out.append(["密室", AK.SP])
		"fate": out.append(["踪迹", Color("e0782a")])
		"post": out.append([FactionCatalog.name_of(str(node.get("faction", ""))) if not str(node.get("faction", "")).is_empty() else "势力据点", AK.GREEN])
		"event": out.append(["事件", AK.FG])
		"outpost", "boss": out.append(["守卫者" if kind == "outpost" else "首领", AK.RED])
	if not RouteMap.info(kind).get("no_device", false) and not kind in ["outpost", "boss"]: out.append(["强化装置", AK.MUTE])
	for tag in _route_tags([node]): out.append(tag)
	return out

## A node: its tags over its name, the colour as its bottom line. No glyph
## (用户 2026-10-24: 不要图标).
static func _route_node(parent: Control, centre: Vector2, tags: String, name: String, state: String, colour: Color = AK.FG, selected: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var fill: Color = {"done": Color("181c1f"), "walked": Color("2a3034"), "here": AK.PAPER, "next": AK.PLATE_2, "far": Color("181c1f"), "fuzzy": Color("23282b")}[state]
	for s in ["normal", "hover", "pressed", "disabled"]:
		var style := AK.box(fill.lightened(0.08) if s == "hover" and state == "next" else fill)
		if state != "here":
			style.border_color = colour
			style.border_width_bottom = 3 if state in ["next", "far", "walked"] else 1
		b.add_theme_stylebox_override(s, style)
	b.disabled = state != "next"
	if state in ["done", "far"]: b.modulate.a = 0.55
	AK.put(parent, b, centre - Vector2(ROUTE_HALF, 20), Vector2(ROUTE_HALF * 2.0, 40))
	# The four characters on one line (用户 2026-10-24: 每个节点四个字在一行).
	var label := AK.label(name, 13, AK.INK if state == "here" else (AK.MUTE if state == "fuzzy" else AK.FG))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, label, Vector2.ZERO, Vector2(ROUTE_HALF * 2.0, 40))
	if not tags.is_empty():
		var tag := AK.label(tags, 10, AK.GREEN if tags.begins_with("撤离") else AK.SP)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		AK.put(b, tag, Vector2(ROUTE_HALF - 55, 43), Vector2(110, 14))
	if selected: AK.frame(b, AK.SP, 2.0)
	return b

# --- 不期而遇 (肉鸽路线图策划案 v0.2 §5) ---------------------------------------------

## The event's card: name, who speaks and the one line, then its choices as
## cost → gain, a refused one with its reason. Leaving keeps it for later.
static func event_card(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.8)
	var ev := RouteEvents.info(game.event_id())
	var options: Array = game.event_options()
	var height := 250.0 + options.size() * 70.0
	var top := (720.0 - height) * 0.5
	AK.put(stage, AK.rect(AK.PLATE_SOLID, Vector2.ZERO, Vector2(640, height)), Vector2(320, top))
	AK.put(stage, AK.rect(RouteMap.info("event").color, Vector2.ZERO, Vector2(640, 3)), Vector2(320, top))
	_title(stage, Vector2(352, top + 24), "ENCOUNTER", str(ev.get("name", "")), "", AK.MUTE)
	AK.put(stage, AK.label(str(ev.get("speaker", "")), 13, AK.SP), Vector2(352, top + 96))
	var line := AK.label("“%s”" % str(ev.get("line", "")), 16, AK.FG)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	AK.put(stage, line, Vector2(352, top + 118), Vector2(576, 48))
	var y := top + 178.0
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		var b := AK.button(str(opt.text), "plain", 16)
		b.disabled = not str(opt.refusal).is_empty()
		b.set_meta("label", str(opt.text))
		AK.put(stage, b, Vector2(352, y), Vector2(576, 56))
		if b.disabled:
			var why := AK.label(str(opt.refusal), 12, AK.RED)
			why.mouse_filter = Control.MOUSE_FILTER_IGNORE
			AK.put(b, why, Vector2(440, 20), Vector2(130, 16))
		var chosen := i
		b.pressed.connect(func(): game.event_choose(chosen))
		y += 70.0
	var leave := AK.button("✕ 离开", "ghost", 16)
	AK.put(stage, leave, Vector2(352, y), Vector2(576, 48))
	leave.pressed.connect(game.close_modal)

# --- #9 罗德岛小队 -------------------------------------------------------------------

static func squad(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.8)
	var side := _side(stage, 430, Color("0f2a30"), "RHODES", AK.CYAN, "squad")
	_title(side, Vector2(36, 40), "ENCOUNTER", "罗德岛小队", "外勤支援 · " + AK.floor_code(game.region_id, game.floor_number), AK.CYAN)
	# The paid services while it has some left; 企鹅专递 with a slip, 补给 when
	# 企鹅物流 carried one here (势力特供策划案 §五–§六).
	var services := [["投保", "INSURE", "insure", AK.HP], ["送回", "SEND HOME", "send", AK.GREEN]]
	if game.carried_count(GameManager.SPECIAL_SLIP) > 0: services.append(["企鹅专递", "PENGUIN PARCEL", "parcel", AK.SP])
	if not game.provisions.mailed().is_empty(): services.append(["补给", "SUPPLY", "supply", AK.CYAN])
	var keys := services.map(func(e): return e[2])
	if not menu.squad_service in keys:
		menu.squad_service = keys[0]
		menu.pick = null
	var service := menu.squad_service
	if not game.encounter_used and game.squad_max_uses() > 1:
		AK.put(side, AK.label("服务 %d / %d" % [game.squad_uses_left(), game.squad_max_uses()], 14, AK.CYAN), Vector2(36, 150))
	var width := (770.0 - 12.0 * (services.size() - 1)) / services.size()
	for i in range(services.size()):
		var entry: Array = services[i]
		var on: bool = service == entry[2]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("label", entry[0])
		for st in ["normal", "hover", "pressed"]:
			var style := AK.box(AK.PAPER if on else (AK.PLATE_2.lightened(0.06) if st == "hover" else AK.PLATE_2))
			style.border_color = entry[3]
			style.border_width_left = 4
			b.add_theme_stylebox_override(st, style)
		AK.put(stage, b, Vector2(470 + i * (width + 12.0), 40), Vector2(width, 62))
		AK.put(b, AK.label(entry[1], 9, Color(AK.INK if on else AK.FG, 0.7), AK.en()), Vector2(20, 10))
		AK.put(b, AK.label(entry[0], 20, AK.INK if on else AK.FG), Vector2(20, 22))
		var key: String = entry[2]
		b.pressed.connect(func(): menu.squad_service = key; menu.pick = null; squad(menu))
	match service:
		"parcel":
			_parcel_list(menu, stage, Vector2(470, 120), func(): squad(menu))
			return
		"supply":
			var meal := game.provisions.mailed()
			AK.put(stage, AK.section("企鹅物流 · 冷链", "COLD CHAIN"), Vector2(470, 120))
			AK.put(stage, AK.item_icon(MaterialCatalog.create(meal, 1), Vector2(96, 96)), Vector2(470, 160))
			AK.put(stage, AK.label(meal, 22, AK.FG), Vector2(590, 166))
			AK.put(stage, AK.label(Provisions.meal_text(meal), 15, AK.GREEN), Vector2(590, 204))
			if not Provisions.squad_text(meal).is_empty(): AK.put(stage, AK.label(Provisions.squad_text(meal), 13, AK.CYAN), Vector2(590, 230))
			if not game.run_meal.is_empty(): AK.put(stage, AK.label("当前：%s" % game.run_meal, 13, AK.MUTE), Vector2(590, 256))
			_footer(stage, Vector2(470, 622), 770, "离开", "补给", game.close_modal, func():
				game.squad_supply()
				squad(menu), game.squad_supply_refusal().is_empty())
			return
	var pick: Item = menu.pick if menu.pick is Item else null
	AK.put(stage, AK.section("可投保" if service == "insure" else "可送回"), Vector2(470, 120))
	AK.put(stage, AK.money("gold", str(game.gold_bars()), 16), Vector2(1180, 116))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(470, 150), Vector2(770, 456))
	# Rows at fixed places (not a GridContainer), so nothing shifts under the pointer.
	var list := Control.new()
	scroll.add_child(list)
	var index := 0
	for item in game.carried_items():
		if not item.is_equippable(): continue
		var refusal := game.squad_refusal(item, service)
		var price := game.squad_price(item)
		var row := _item_row(item, str(price), "已投保" if item.insured else item.kind_name(), refusal.is_empty(), item == pick, refusal == "赤金不足")
		var chosen := item
		row.pressed.connect(func(): menu.pick = chosen; squad(menu))
		AK.put(list, row, Vector2((index % 3) * 258, (index / 3) * 66), Vector2(252, 60))
		index += 1
	list.custom_minimum_size = Vector2(770, ceili(index / 3.0) * 66)
	var label := "投保" if service == "insure" else "送回"
	var ok := pick != null and game.squad_refusal(pick, service).is_empty()
	_footer(stage, Vector2(470, 622), 770, "离开", label + (" · %d" % game.squad_price(pick) if pick != null else ""), game.close_modal, func():
		if pick == null: return
		menu.pick = null
		if service == "insure": game.squad_insure(pick)
		else: game.squad_send_home(pick)
		if game.encounter_used and not game.squad_extras(): game.close_modal()
		else: squad(menu), ok)

## 企鹅专递单 (势力特供策划案 §二): pick any number of things from the pack and
## safe bag; one slip sends them all to the warehouse. menu.pick holds the picks.
static func _parcel_list(menu: FieldMenu, stage: Control, at: Vector2, redraw: Callable) -> void:
	var game := menu.game
	var picks: Array = menu.pick if menu.pick is Array else []
	picks = picks.filter(func(i): return game.parcel_items().has(i))
	menu.pick = picks
	AK.put(stage, AK.section("企鹅专递", "PENGUIN PARCEL  ×%d" % game.carried_count(GameManager.SPECIAL_SLIP)), at)
	var all := AK.button("全选", "plain", 12)
	AK.put(stage, all, at + Vector2(650, -4), Vector2(120, 28))
	all.pressed.connect(func(): menu.pick = game.parcel_items(); redraw.call())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, at + Vector2(0, 30), Vector2(770, 456))
	var list := Control.new()
	scroll.add_child(list)
	var index := 0
	for item in game.parcel_items():
		var chosen: Item = item
		var on := picks.has(item)
		var row := _item_row(item, "", item.kind_name(), true, on)
		row.pressed.connect(func():
			var now: Array = menu.pick if menu.pick is Array else []
			if now.has(chosen): now.erase(chosen)
			else: now.append(chosen)
			menu.pick = now
			redraw.call())
		AK.put(list, row, Vector2((index % 3) * 258, (index / 3) * 66), Vector2(252, 60))
		index += 1
	list.custom_minimum_size = Vector2(770, ceili(index / 3.0) * 66)
	_footer(stage, Vector2(at.x, 622), 770, "离开", "专递 · %d 件" % picks.size(), menu.show_camp if game.in_camp else game.close_modal, func():
		game.parcel_send(picks)
		menu.pick = []
		redraw.call(), not picks.is_empty() and game.parcel_refusal().is_empty())

## 企鹅专递 from a camp (撤离与营地修订案: 可露希尔's camp).
static func parcel(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.8)
	var side := _side(stage, 430, Color("2c2a12"), "PENGUIN", AK.SP)
	_title(side, Vector2(36, 40), "PENGUIN LOGISTICS", "企鹅专递", game.camp_label(game.floor_number) if game.in_camp else "", AK.SP)
	var back := AK.button("返回", "plain", 15)
	AK.put(side, back, Vector2(24, 662), Vector2(382, 44))
	back.pressed.connect(func(): menu.show_camp())
	if game.carried_count(GameManager.SPECIAL_SLIP) <= 0:
		menu.show_camp()
		return
	_parcel_list(menu, stage, Vector2(470, 40), func(): parcel(menu))

## One pickable item: icon, name, a sub line, the price on the right.
static func _item_row(item: Item, price: String, sub: String, enabled: bool, selected: bool, short: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(252, 60)
	b.set_meta("item", item)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, AK.box(Color("2b3339") if selected or s == "hover" else AK.PLATE_2))
	b.disabled = not enabled
	if not enabled: b.modulate.a = 0.35
	AK.put(b, AK.item_icon(item, Vector2(48, 48)), Vector2(6, 6))
	var name := AK.item_name(item, 13)
	name.fit_content = false
	name.clip_contents = true
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, name, Vector2(62, 10), Vector2(140, 20))
	var sub_label := AK.label(sub, 11, AK.MUTE)
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, sub_label, Vector2(62, 32))
	var cost := AK.label(price, 15, AK.RED if short else AK.SP, AK.en())
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, cost, Vector2(190, 20), Vector2(52, 20))
	if selected: AK.frame(b)
	return b

# --- #9b 坎诺特 -----------------------------------------------------------------------

static func trader(menu: FieldMenu) -> void:
	TraderScreen.cannot(menu)


## The tooltip of `item` with one price row under it.
## `max_height` > 0 caps the text (it scrolls) so it cannot run under buttons.
static func _info(stage: Control, game: GameManager, item: Item, key: String, value: String, at: Vector2, max_height: float = 0.0) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", AK.box(Color("0b0d0f"), AK.LINE_2, 1, 10))
	var column := VBoxContainer.new()
	card.add_child(column)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size.x = 300
	if max_height > 0.0:
		text.fit_content = false
		text.scroll_active = true
		text.custom_minimum_size.y = max_height
	text.add_theme_font_override("normal_font", AK.cn())
	text.add_theme_font_size_override("normal_font_size", 13)
	text.text = ItemTooltip.text(game, item, false, false)
	column.add_child(text)
	var row := HBoxContainer.new()
	row.add_child(AK.label(key, 13, AK.MUTE))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	row.add_child(AK.money("gold", value, 20))
	column.add_child(row)
	AK.put(stage, card, at)

# --- #9c 营地 ------------------------------------------------------------------------

## In a camp, or (`at_base`) her counter at the base: the same shop and 赤金
## buying, no deposit and no way out there (用户：不区分).
## 可露希尔's tabs at the base and in a camp (代售 second, 交易包修订案 §5.1).
const CLOSURE_TABS_BASE := ["商店", "代售", "出售赤金", "换汇", "贷款", "随队物资"]
const CLOSURE_TABS_CAMP := ["商店", "代售", "寄存", "出售赤金", "换汇", "交割", "补给", "处理"]

static func camp(menu: FieldMenu, at_base: bool = false) -> void:
	# 商店 is the Tarkov-style trader screen (药剂与商人界面策划案 §4).
	if menu.camp_tab <= 0:
		TraderScreen.closure(menu, at_base)
		return
	# 代售 (交易所交易包修订案 §5) is a trader screen too.
	if menu.camp_tab == 1:
		TraderScreen.consign(menu, at_base)
		return
	var game := menu.game
	var stage := menu.stage_begin(0.97)
	var side := _side(stage, 380, Color("13321f"), "STORE" if at_base else "CAMP", AK.GREEN, "closure")
	if at_base:
		AK.put(side, AK.label("可露希尔的商店", 26, AK.FG), Vector2(32, 40))
		AK.put(side, AK.label("CLOSURE'S STORE · RHODES ISLAND", 10, AK.MUTE, AK.en()), Vector2(32, 78))
		var back := AK.button("返回", "plain", 15)
		AK.put(side, back, Vector2(24, 662), Vector2(332, 44))
		back.pressed.connect(game.close_modal)
	else:
		var plate := AK.tag(game.camp_label(game.floor_number), AK.PAPER)
		AK.put(side, plate, Vector2(32, 32))
		AK.put(side, AK.label("可露希尔", 30, AK.FG), Vector2(32, 62))
		AK.put(side, AK.label("CLOSURE · RHODES ISLAND", 10, AK.MUTE, AK.en()), Vector2(32, 104))
		var extract := AK.go_button("撤离", "EXTRACT", "green")
		AK.put(side, extract, Vector2(24, 592), Vector2(332, 64))
		extract.pressed.connect(game.camp_extract)
		var on := AK.button("继续 · %s" % AK.floor_code(game.region_id, game.floor_number + 1), "plain", 15)
		AK.put(side, on, Vector2(24, 662), Vector2(332, 44))
		on.pressed.connect(game.leave_camp)
		# 企鹅专递单 (势力特供策划案 §二) with one in the pack.
		if game.carried_count(GameManager.SPECIAL_SLIP) > 0:
			var parcel_button := AK.button("企鹅专递", "yellow", 15)
			AK.put(side, parcel_button, Vector2(24, 532), Vector2(332, 44))
			parcel_button.pressed.connect(menu.show_parcel)
	# 换汇 at the live rate (势力与交易所策划案 §1.3); the loan at the base (§10);
	# forward delivery in a camp (§8.3).
	# 地图特色策划案 §9: 随队物资 at the base; 补给 and 处理 in a camp.
	var tabs := CLOSURE_TABS_BASE if at_base else CLOSURE_TABS_CAMP
	var tab: int = clampi(menu.camp_tab, 0, tabs.size() - 1)
	var redraw := func(): camp(menu, at_base)
	AK.put(stage, AK.toggle(tabs, tab, func(i): menu.camp_tab = i; menu.pick = null; camp(menu, at_base)), Vector2(410, 32))
	tab = ([0, 9, 2, 3, 4, 6] if at_base else [0, 9, 1, 2, 3, 5, 7, 8])[tab]
	if tab in [3, 4, 5]:
		_closure_money(menu, stage, tab, at_base)
		return
	if tab >= 6:
		AK.put(stage, AK.money("gold", str(game.gold_available())), Vector2(950, 38))
		AK.put(stage, AK.money("lmd", Economy.format(game.gold)), Vector2(1070, 38))
		_closure_features(menu, stage, tab, at_base)
		return
	AK.put(stage, AK.money("gold", str(game.gold_available())), Vector2(950, 38))
	AK.put(stage, AK.money("lmd", Economy.format(game.gold)), Vector2(1070, 38))
	var ok := false
	var confirm := Callable()
	match tab:
		1:
			var pick: Item = menu.pick if menu.pick is Item else null
			var can_deposit := func(item: Item) -> bool: return game.deposit_refusal(item) in ["", "赤金不足"]
			var pick_item := func(item: Item): menu.pick = item; camp(menu)
			# Drag a piece from the pack onto the counter to leave it with her.
			var counter := Vector2(410 + game.inventory.width * 40 + 18, 84)
			var deposits := func(item: Item) -> bool: return game.deposit_refusal(item).is_empty()
			var deposit_drop := func(item: Item): game.deposit_item(item); menu.pick = null; camp(menu)
			ItemDrag.zone(stage, counter, Vector2(1264 - counter.x, 560), deposits, deposit_drop)
			var no_drop := func(_item: Item) -> bool: return false
			AK.put(stage, ItemDrag.bag(AK.BagGrid.make(game.inventory, can_deposit, pick_item, pick), no_drop, func(_item): pass), Vector2(410, 84))
			AK.put(stage, AK.section("安全袋"), Vector2(410, 84 + game.inventory.height * 40 + 12))
			AK.put(stage, ItemDrag.bag(AK.BagGrid.make(game.safe_bag, can_deposit, pick_item, pick), no_drop, func(_item): pass), Vector2(410, 84 + game.inventory.height * 40 + 40))
			if pick != null: _info(stage, game, pick, "费用", str(game.deposit_fee(pick)), counter)
			else:
				var well := Panel.new()
				well.add_theme_stylebox_override("panel", AK.box(Color(0, 0, 0, 0.35), AK.LINE, 1))
				well.mouse_filter = Control.MOUSE_FILTER_IGNORE
				AK.put(stage, well, counter, Vector2(360, 200))
				AK.put(stage, AK.label("寄存", 16, AK.DIM), counter + Vector2(156, 88))
			ok = pick != null and game.deposit_refusal(pick).is_empty()
			confirm = func():
				game.deposit_item(pick)
				menu.pick = null
				camp(menu)
		2:
			var have := game.gold_available()
			var amount: int = clampi(int(menu.pick) if menu.pick is int else 10, 0, have)
			var panel := AK.rect(AK.PLATE_2, Vector2(410, 84), Vector2(834, 150))
			stage.add_child(panel)
			AK.put(stage, AK.item_icon(MaterialCatalog.create(Economy.GOLD_ID, maxi(have, 1)), Vector2(96, 96)), Vector2(434, 111))
			var choices := [1, 10, have]
			AK.put(stage, AK.toggle(["1", "10", "全部"], choices.find(amount) if amount in choices else -1, func(i): menu.pick = [1, 10, have][i]; redraw.call()), Vector2(560, 104))
			var flow := HBoxContainer.new()
			flow.add_theme_constant_override("separation", 12)
			flow.add_child(AK.money("gold", str(amount), 24))
			flow.add_child(AK.label("→", 18, AK.MUTE))
			flow.add_child(AK.money("lmd", Economy.format(amount * Economy.closure_bar_price()), 24))
			AK.put(stage, flow, Vector2(560, 160))
			ok = amount > 0
			confirm = func():
				game.sell_gold_bars(amount)
				redraw.call()
	_footer(stage, Vector2(410, 630), 834, "", ["购买", "寄存", "出售"][tab], Callable(), confirm, ok)

## 地图特色 at 可露希尔 (地图特色策划案 §9): the base kits (6), the camp's field
## supplies (7) and its 处理 (8). One row each, bought on the spot.
static func _closure_features(menu: FieldMenu, stage: Control, tab: int, at_base: bool) -> void:
	var game := menu.game
	var redraw := func(): camp(menu, at_base)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	AK.put(stage, rows, Vector2(410, 84), Vector2(834, 0))
	var row_of := func(icon: Item, title: String, detail: String, price: HBoxContainer, action: Button) -> void:
		var row := Control.new()
		row.custom_minimum_size = Vector2(834, 64)
		row.add_child(AK.rect(AK.PLATE_2, Vector2.ZERO, Vector2(834, 64)))
		if icon != null: AK.put(row, AK.item_icon(icon, Vector2(56, 56)), Vector2(4, 4))
		AK.put(row, AK.label(title, 15, AK.FG), Vector2(72, 10))
		AK.put(row, AK.label(detail, 12, AK.MUTE), Vector2(72, 36))
		AK.put(row, price, Vector2(520, 20))
		AK.put(row, action, Vector2(680, 12), Vector2(140, 40))
		rows.add_child(row)
	match tab:
		6:
			for id in FeatureCatalog.KITS:
				var kit: Dictionary = FeatureCatalog.KITS[id]
				var refusal := game.kit_refusal(id)
				var buy := AK.button(refusal if refusal.begins_with("R") else "购买", "blue", 14)
				buy.disabled = not refusal.is_empty()
				buy.set_meta("kit", id)
				var kit_id: String = id
				buy.pressed.connect(func(): game.buy_kit(kit_id); redraw.call())
				var tier := game.deepest_tier()
				row_of.call(null, FeatureCatalog.kit_name(id, tier), "%s −%d%%  ·  ×%d" % [FeatureCatalog.NAMES[kit.feature], roundi(FeatureCatalog.kit_cut(id, tier) * 100), game.base.kit_stock(id)],
					AK.money("lmd", Economy.format(FeatureCatalog.kit_price(id, tier)), 16), buy)
		7:
			for id in FeatureCatalog.CAMP_SUPPLIES:
				var price := game.supply_price(id)
				var buy := AK.button("购买", "blue", 14)
				buy.disabled = game.gold_available() < price or not game.inventory.can_take(game.supply_item(id))
				buy.set_meta("supply", id)
				var supply_id: String = id
				buy.pressed.connect(func(): game.closure_buy_supply(supply_id); redraw.call())
				var detail := ("%d 秒" % int(FeatureCatalog.FUELS[id])) if FeatureCatalog.FUELS.has(id) else ("%s −%d" % [FeatureCatalog.NAMES[FeatureCatalog.SUPPLIES[id].feature], int(FeatureCatalog.SUPPLIES[id].cut)] if float(FeatureCatalog.SUPPLIES[id].cut) > 0.0 else FeatureCatalog.SEALED_ORE_NAME)
				row_of.call(game.supply_item(id), id, detail, AK.money("gold", str(price), 16), buy)
			AK.put(stage, AK.section("背包", "%d / %d" % [game.inventory.occupied_cells(), game.inventory.cell_count()]), Vector2(410, 84 + FeatureCatalog.CAMP_SUPPLIES.size() * 72 + 8))
			AK.put(stage, AK.BagGrid.make(game.inventory), Vector2(410, 84 + FeatureCatalog.CAMP_SUPPLIES.size() * 72 + 38))
		8:
			if game.current_contamination() > 0.0:
				var cleanse := AK.button("污染 −%d" % int(FeatureCatalog.CAMP_CLEANSE), "blue", 14)
				var refusal := game.camp_cleanse_refusal()
				cleanse.disabled = not refusal.is_empty()
				if refusal == "已处理": cleanse.text = refusal
				cleanse.set_meta("service", "cleanse")
				cleanse.pressed.connect(func(): game.camp_cleanse(); redraw.call())
				row_of.call(null, FeatureCatalog.NAMES.contamination, str(roundi(game.current_contamination())), AK.money("gold", str(FeatureCatalog.CAMP_CLEANSE_BARS), 16), cleanse)
			if game.features.value("debt") > 0.0:
				var pay := AK.button("血债 −%d" % int(FeatureCatalog.CAMP_DEBT), "blue", 14)
				pay.disabled = not game.camp_debt_refusal().is_empty()
				pay.set_meta("service", "debt")
				pay.pressed.connect(func(): game.camp_pay_debt(); redraw.call())
				row_of.call(null, FeatureCatalog.NAMES.debt, str(roundi(game.features.value("debt"))), AK.money("gold", str(game.features.camp_debt_price()), 16), pay)

## 可露希尔's money desk: 换汇 (3), the loan (4), forward delivery in a camp (5).
static func _closure_money(menu: FieldMenu, stage: Control, tab: int, at_base: bool) -> void:
	var game := menu.game
	var ex := game.exchange
	var redraw := func(): camp(menu, at_base)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	AK.put(stage, box, Vector2(410, 84), Vector2(834, 0))
	match tab:
		3:
			var amount: int = int(menu.pick) if menu.pick is int else 10000
			box.add_child(MarketWidgets.live(func(): return "龙门币 / 赤金 %.1f   ·   可露希尔价差 %d%%   ·   赤金账户 %.2f" % [Economy.fx, roundi(Economy.closure_spread * 100), ex.gold_account], 14))
			box.add_child(AK.toggle(["1,000", "10,000", "50,000"], [1000, 10000, 50000].find(amount), func(i): menu.pick = [1000, 10000, 50000][i]; redraw.call(), 13))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var to_gold := AK.button("龙门币 %s → 赤金账户" % Economy.format(amount), "blue", 14)
			to_gold.pressed.connect(func(): game.closure_convert(true, amount); redraw.call())
			row.add_child(to_gold)
			var to_lmd := AK.button("赤金账户 → 龙门币 %s" % Economy.format(amount), "plain", 14)
			to_lmd.pressed.connect(func(): game.closure_convert(false, amount / (Economy.fx * (1.0 - Economy.closure_spread))); redraw.call())
			row.add_child(to_lmd)
			box.add_child(row)
		4:
			box.add_child(AK.label("待还 %s   ·   额度 %s   ·   下次结算利率 %d%%%s" % [Economy.format(ex.loan), Economy.format(ex.loan_limit()),
				roundi(ex.loan_rate_now(ex.loan) * 100), "   ·   逾期" if ex.loan_locked() else ""], 15, AK.RED if ex.loan_locked() else AK.FG))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			for n in [10000, 50000]:
				var amount: int = n
				var b := AK.button("借 %s" % Economy.format(amount), "blue", 14)
				b.disabled = ex.loan_locked() or ex.loan + amount > ex.loan_limit()
				b.pressed.connect(func():
					if ex.borrow(amount): game.save_base()
					redraw.call())
				row.add_child(b)
			for n in [10000, -1]:
				var amount: int = ex.loan if n < 0 else n
				var b := AK.button("还 %s" % ("全部" if n < 0 else Economy.format(amount)), "plain", 14)
				b.disabled = ex.loan <= 0 or game.gold < mini(amount, ex.loan)
				b.pressed.connect(func():
					if ex.repay(amount): game.save_base()
					redraw.call())
				row.add_child(b)
			box.add_child(row)
		5:
			var any := false
			for f in ex.forwards:
				if f.dir != "deliver": continue
				any = true
				var pos: Dictionary = f
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 10)
				row.add_child(AK.label("交货 %s ×%d → %s  ·  背包 %d  ·  剩 %s" % [pos.material, int(pos.count), FactionCatalog.name_of(str(pos.faction)),
					game.material_count(str(pos.material)), ExchangeScreen._left(int(pos.expires) - game.market.t)], 14, AK.FG))
				var b := AK.button("交割", "blue", 14)
				b.disabled = game.material_count(str(pos.material)) < int(pos.count)
				b.pressed.connect(func():
					if ex.deliver_forward(int(pos.id)): game.save_base(true)
					redraw.call())
				row.add_child(b)
				box.add_child(row)
			if not any: box.add_child(AK.label("交货合约 0", 14, AK.MUTE))

# --- #10 行动结束 / 失败 ----------------------------------------------------------------

const FATE_TAGS := {"安全袋保全": ["保留", AK.GREEN], "投保送回": ["投保", AK.HP]}

static func settlement(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.97)
	var view: Dictionary = game.settlement_view
	var ok: bool = view.get("extracted", false)
	var accent := AK.GREEN if ok else AK.RED
	stage.add_child(AK.rect(accent, Vector2.ZERO, Vector2(1280, 6)))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(AK.tag(view.get("plate", ""), AK.PAPER))
	head.add_child(AK.label("%s · %s" % [FieldCatalog.REGIONS[view.region].name, view.get("time", "")], 12, AK.MUTE))
	AK.put(stage, head, Vector2(48, 44))
	AK.put(stage, AK.label("行动结束" if ok else "行动失败", 52, AK.FG if ok else AK.RED), Vector2(48, 76))
	AK.put(stage, AK.label("MISSION ACCOMPLISHED" if ok else "MISSION FAILED", 12, AK.SP if ok else AK.RED, AK.en()), Vector2(50, 146))
	var cells: Array = []
	if ok:
		cells = [["赤金", str(view.get("gold", 0)), AK.SP], ["合同报酬", "+" + Economy.format(view.reward), AK.FG],
			["深度", AK.floor_code(view.region, view.depth), AK.FG], ["可交付订单", str(view.get("orders", 0)), AK.SP]]
	else:
		var n := {"安全袋保全": 0, "投保送回": 0, "遗失": 0}
		for entry in view.pack + view.safe + view.worn: n[entry.reason] = int(n.get(entry.reason, 0)) + 1
		cells = [["保留", "%d 件" % n["安全袋保全"], AK.GREEN], ["投保", "%d 件" % n["投保送回"], AK.HP],
			["丢失", "%d 件" % n["遗失"], AK.RED], ["深度", AK.floor_code(view.region, view.depth), AK.FG]]
	stage.add_child(AK.rect(AK.PLATE, Vector2(48, 176), Vector2(330, 136)))
	for i in range(4):
		var at := Vector2(48 + (i % 2) * 165, 176 + (i / 2) * 68)
		AK.put(stage, AK.label(cells[i][0], 11, AK.MUTE), at + Vector2(12, 10))
		AK.put(stage, AK.label(cells[i][1], 22, cells[i][2], AK.en()), at + Vector2(12, 28))
		stage.add_child(AK.rect(AK.LINE, at + Vector2(0, 67), Vector2(165, 1)))
	# 作战记录 by kill count (精英化与加点策划案 §4.2), on success or failure.
	var records: Dictionary = view.get("records", {})
	var record_parts: Array[String] = []
	for record in Progression.RECORDS:
		if int(records.get(record, 0)) > 0: record_parts.append("%s ×%d" % [record.replace("作战记录", ""), int(records[record])])
	stage.add_child(AK.rect(AK.PLATE, Vector2(48, 368), Vector2(330, 30)))
	AK.put(stage, AK.tag("作战记录", AK.SP), Vector2(58, 375))
	var after_tag := maxf(130.0, 58.0 + AK.cn().get_string_size(I18n.t("作战记录"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0 + 10.0)
	AK.put(stage, AK.label(" · ".join(record_parts) if not record_parts.is_empty() else "—", 12, AK.FG), Vector2(after_tag, 374))
	# The contract's objective (§6 B1): done or not, and what it paid.
	var objective: Dictionary = view.get("contract", {})
	if not str(objective.get("goal", "")).is_empty():
		stage.add_child(AK.rect(AK.PLATE, Vector2(48, 318), Vector2(330, 44)))
		AK.put(stage, AK.tag("合同目标", AK.SP), Vector2(58, 330))
		AK.put(stage, AK.label(objective.goal, 12, AK.FG if objective.done else AK.MUTE), Vector2(130, 322))
		AK.put(stage, AK.label(("✓ " + str(objective.bonus)) if objective.done else "未完成", 11, AK.GREEN if objective.done else AK.RED), Vector2(130, 340))
	var sprite := TextureRect.new()
	sprite.texture = Operators.portrait(game.player.operator_id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not ok: sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	AK.put(stage, sprite, Vector2(129, 408), Vector2(168, 168))
	var back := AK.go_button("返回罗德岛", "RETURN")
	AK.put(stage, back, Vector2(48, 624), Vector2(330, 60))
	back.pressed.connect(game.close_modal)
	# 仓库修订 (用户 2026-10-23): a 仓库 page beside the bags, to put away what came home.
	var tab: int = clampi(menu.settle_tab, 0, SETTLE_TABS.size() - 1)
	AK.put(stage, AK.toggle(SETTLE_TABS, tab, func(i): menu.settle_tab = i; settlement(menu), 13), Vector2(1100, 14))
	if tab == 1:
		_settle_store(menu, stage)
		return
	# The bags as they came out, enlarged, items where they were.
	var worn: Array = view.worn
	var worn_h := 1
	for entry in worn: worn_h = maxi(worn_h, entry.h)
	var pack_size: Vector2i = view.pack_size
	var safe_size: Vector2i = view.safe_size
	var scale := minf(820.0 / (pack_size.x * 40.0), 560.0 / ((maxi(worn_h, safe_size.y) + pack_size.y) * 40.0))
	scale = minf(scale, 1.8)
	var y := 44.0
	var x := 420.0
	AK.put(stage, AK.section("装备", "EQUIPPED"), Vector2(x, y))
	for entry in worn:
		var grid := FateGrid.make(Vector2i(entry.w, entry.h), [_at_origin(entry)], ok, scale)
		AK.put(stage, grid, Vector2(x, y + 28))
		x += entry.w * 40 * scale + 8
	x = maxf(x + 14, 420 + 3 * 80 * scale * 0.5)
	AK.put(stage, AK.section("安全袋", "SAFE"), Vector2(x, y))
	AK.put(stage, FateGrid.make(safe_size, view.safe, ok, scale), Vector2(x, y + 28))
	y += 28 + maxi(worn_h, safe_size.y) * 40 * scale + 16
	AK.put(stage, AK.section("背包", "PACK %d×%d" % [pack_size.x, pack_size.y]), Vector2(420, y))
	AK.put(stage, FateGrid.make(pack_size, view.pack, ok, scale), Vector2(420, y + 28))

const SETTLE_TABS := ["结算", "仓库"]

## Settlement's 仓库 page: the warehouse on the left, the pack and safe bag on
## the right; a click or a drag puts an item away, 一键入库 puts all of them.
static func _settle_store(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var redraw := func(): settlement(menu)
	var full := base.shelf_count() >= base.capacity()
	AK.put(stage, AK.section("仓库", "DEPOT  %d / %d" % [base.shelf_count(), base.capacity()]), Vector2(420, 44))
	if full: AK.put(stage, AK.tag("已满", AK.RED, false), Vector2(640, 46))
	var stores := func(item: Item) -> bool: return game.carried_items().has(item) and not game.player.equipped.values().has(item)
	var depot := ScrollContainer.new()
	depot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var depot_rows := maxi(12, ceili(game.stash.size() / 10.0))
	var grid := BaseScreens.FlowGrid.make(game.stash, 10, depot_rows, func(_it): pass, func(_it): pass)
	grid.dragging(stores, func(item: Item): game.store_item(item); redraw.call())
	grid.cards = true
	depot.add_child(grid)
	AK.put(stage, depot, Vector2(420, 76), Vector2(414, 12 * 40))
	var carried: Array = game.inventory.items + game.safe_bag.items
	AK.put(stage, AK.section("背包 · 安全袋", "CARRIED  %d" % carried.size()), Vector2(860, 44))
	var bag := BaseScreens.FlowGrid.make(carried, 9, 10, func(item: Item): game.store_item(item); redraw.call(), func(_it): pass)
	bag.dragging(func(_it): return false, func(_it): pass)
	bag.cards = true
	AK.put(stage, bag, Vector2(860, 76))
	var all := AK.go_button("一键入库", "STORE ALL")
	all.disabled = carried.is_empty() or (full and not carried.any(func(it): return base.shelf_merge_room(it) >= it.quantity))
	all.pressed.connect(func(): game.store_all_carried(); redraw.call())
	AK.put(stage, all, Vector2(860, 624), Vector2(360, 60))

static func _at_origin(entry: Dictionary) -> Dictionary:
	var copy := entry.duplicate()
	copy.x = 0
	copy.y = 0
	return copy


## A bag at settlement, scaled up: items where they lay. On a death the kept and
## insured keep their colour with a corner tag, the lost are dimmed.
class FateGrid extends Control:
	const CELL := 40
	var cells := Vector2i.ZERO
	var entries: Array = []
	var extracted := true

	static func make(size_cells: Vector2i, shown: Array, ok: bool, k: float) -> FateGrid:
		var grid := FateGrid.new()
		grid.cells = size_cells
		grid.entries = shown
		grid.extracted = ok
		grid.scale = Vector2(k, k)
		grid.size = Vector2(size_cells) * CELL
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return grid

	func _ready() -> void:
		for entry in entries:
			var square := AK.item_icon(entry.item, Vector2(entry.w, entry.h) * CELL - Vector2.ONE)
			square.position = Vector2(entry.x, entry.y) * CELL
			square.dim = not extracted and entry.reason == "遗失"
			add_child(square)
			if not extracted and FATE_TAGS.has(entry.reason):
				var tag := AK.tag(FATE_TAGS[entry.reason][0], FATE_TAGS[entry.reason][1])
				tag.scale = Vector2(0.6, 0.6)
				tag.position = square.position
				add_child(tag)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(cells) * CELL), Color(0, 0, 0, 0.55))
		for x in range(cells.x + 1): draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, cells.y * CELL), Color(1, 1, 1, 0.07))
		for y in range(cells.y + 1): draw_line(Vector2(0, y * CELL), Vector2(cells.x * CELL, y * CELL), Color(1, 1, 1, 0.07))


## The route map's sideways scroll: the wheel and a drag on empty ground move it.
class RouteView extends ScrollContainer:
	const WHEEL := 80

	func _ready() -> void:
		vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button != null and button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			scroll_horizontal -= WHEEL
			accept_event()
		elif button != null and button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			scroll_horizontal += WHEEL
			accept_event()
		var motion := event as InputEventMouseMotion
		if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			scroll_horizontal -= roundi(motion.relative.x)
			accept_event()


## The links of the route map (用户 2026-10-24: 做成这种弧线连接): each leaves
## its node's right side level and bends into the next node's left side.
## Walked solid grey, the lines on from here dashed white, the rest faint.
class RouteLines extends Control:
	var links: Array = []   # [from centre, to centre, "walked" / "ahead" / "faint"]
	const HALF := 34.0
	const SEGMENTS := 24

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for link in links:
			var points := arc(link[0], link[1])
			match str(link[2]):
				"walked": draw_polyline(points, Color("8a949a"), 2.0, true)
				"ahead": _dashed(points, Color.WHITE, 2.0, 6.0)
				_: draw_polyline(points, Color("3a4246"), 1.5, true)

	## A cubic curve from the right edge of `a` to the left edge of `b`, its
	## handles level so it leaves and arrives flat.
	static func arc(a: Vector2, b: Vector2) -> PackedVector2Array:
		var from := a + Vector2(HALF, 0)
		var to := b - Vector2(HALF, 0)
		var reach := maxf(12.0, (to.x - from.x) * 0.55)
		var c1 := from + Vector2(reach, 0)
		var c2 := to - Vector2(reach, 0)
		var out := PackedVector2Array()
		for i in range(SEGMENTS + 1):
			var t := float(i) / SEGMENTS
			var u := 1.0 - t
			out.append(from * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + to * t * t * t)
		return out

	func _dashed(points: PackedVector2Array, colour: Color, width: float, dash: float) -> void:
		var on := true
		var left := dash
		for i in range(1, points.size()):
			var a := points[i - 1]
			var b := points[i]
			var length := a.distance_to(b)
			var at := 0.0
			while at < length:
				var run := minf(left, length - at)
				if on: draw_line(a.lerp(b, at / length), a.lerp(b, (at + run) / length), colour, width, true)
				at += run
				left -= run
				if left <= 0.0:
					on = not on
					left = dash


## A placeholder figure until the portraits are drawn (界面策划案 §8).
class Silhouette extends Control:
	var colour := AK.FG

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		draw_circle(Vector2(w * 0.5, 48), 30, Color(colour, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - 20, 84), Vector2(w * 0.5 + 20, 84), Vector2(w - 8, size.y), Vector2(8, size.y)]), Color("262a2c"))

# --- 火堆 (地图特色策划案 §5.3) -------------------------------------------------

## The pack's fuels, one row each: what it is, how many, how long one burns.
## A click burns one piece and closes.
static func fuel(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.55)
	var fuels := game.pack_fuels()
	var height := 60.0 + fuels.size() * 64.0
	var top := (720.0 - height) * 0.5
	stage.add_child(AK.rect(AK.PLATE_SOLID, Vector2(440, top), Vector2(400, height)))
	var fire := game.fuel_fire
	if is_instance_valid(fire):
		AK.put(stage, AK.label("%d / %d s" % [ceili(fire.burn_left), int(FeatureCatalog.FIRE_MAX)], 13, AK.MUTE, AK.en()), Vector2(456, top + 14))
	var y := top + 44.0
	for id in FeatureCatalog.FUELS:
		if not fuels.has(id): continue
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.set_meta("fuel", id)
		for s in ["normal", "hover", "pressed", "disabled"]:
			row.add_theme_stylebox_override(s, AK.box(Color("2b3339") if s == "hover" else AK.PLATE_2))
		row.disabled = is_instance_valid(fire) and fire.burn_left >= FeatureCatalog.FIRE_MAX
		AK.put(stage, row, Vector2(452, y), Vector2(376, 56))
		AK.put(row, AK.item_icon(MaterialCatalog.create(id, 1), Vector2(48, 48)), Vector2(4, 4))
		AK.put(row, AK.label("%s ×%d" % [id, int(fuels[id])], 15, AK.FG), Vector2(64, 16))
		AK.put(row, AK.label("%d s" % int(FeatureCatalog.FUELS[id]), 14, AK.SP, AK.en()), Vector2(300, 18))
		for child in row.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fuel_id: String = id
		row.pressed.connect(func():
			game.burn_fuel(fuel_id)
			game.close_modal())
		y += 64.0
	var back := AK.button("✕", "plain", 14)
	AK.put(stage, back, Vector2(796, top + 8), Vector2(36, 30))
	back.pressed.connect(game.close_modal)
