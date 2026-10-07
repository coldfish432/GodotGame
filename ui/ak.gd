class_name AK
extends RefCounted

## The Arknights-client look (界面策划案 v1.1 §2): palette, fonts and the small
## pieces every screen is built from. Colours are the spec's tokens; fonts are
## system fonts (no font files are bundled until the user decides, spec §8 #5).

const BG := Color("161616")
const PLATE := Color(0.094, 0.094, 0.094, 0.86)
const PLATE_SOLID := Color("202020")
const PLATE_2 := Color("2c2c2c")
const PLATE_3 := Color("383838")
const LINE := Color("3a3a3a")
const LINE_2 := Color("5a5a5a")
const FG := Color("f4f4f4")
const MUTE := Color("a3a3a3")
const DIM := Color("6d6d6d")
const INK := Color("101010")
const PAPER := Color("e9e9e9")
const BLUE := Color("0098dc")       # confirm, start, selected
const HP := Color("27a6ef")         # her life
const SP := Color("f5c000")         # skill points, ready, stars, claimable
const RED := Color("e23c3c")        # enemy, elite, failure
const ORI := Color("e0782a")        # contamination and originium only
const GREEN := Color("8fc31f")      # extraction, kept
const CYAN := Color("5fd0d8")       # Rhodes squad, base markers
const TRADER := Color("e6c25a")     # 坎诺特
const TIER := [Color("9a9a9a"), Color("16a2e8"), Color("ffc400")]
const SPECIAL := Color("c48cff")
## Region codes on the floor plate (LG-04).
const REGION_CODE := {"mine": "CH", "city": "LG", "snow": "SM"}

static var _cn: SystemFont
static var _en: SystemFont

static func cn() -> Font:
	if _cn == null:
		_cn = SystemFont.new()
		_cn.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans SC", "PingFang SC", "Source Han Sans SC"])
		_cn.font_weight = 700
	return _cn

static func en() -> Font:
	if _en == null:
		_en = SystemFont.new()
		_en.font_names = PackedStringArray(["Bahnschrift", "Saira", "Arial Narrow", "Microsoft YaHei UI"])
		_en.font_weight = 700
	return _en

static var _italic: SystemFont
static func italic() -> Font:
	if _italic == null:
		_italic = SystemFont.new()
		_italic.font_names = cn().font_names
		_italic.font_italic = true
	return _italic

static func floor_code(region: String, depth: int) -> String:
	return "%s-%02d" % [REGION_CODE.get(region, "LG"), depth]

static func box(color: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, margin: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, margin)
	return style

static func label(text: String, size: int = 14, color: Color = FG, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else cn())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Buttons: "plain" grey, "blue" confirm, "yellow", "paper" (selected tab), "ghost".
static func button(text: String, kind: String = "plain", size: int = 14) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", cn())
	b.add_theme_font_size_override("font_size", size)
	style_button(b, kind)
	return b

static func style_button(b: Button, kind: String) -> void:
	var base: Color = {"plain": PLATE_3, "blue": BLUE, "yellow": SP, "paper": PAPER, "ghost": Color(0, 0, 0, 0.55), "green": GREEN}.get(kind, PLATE_3)
	var text_color := INK if kind in ["yellow", "paper", "green"] else FG
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := base
		if state == "hover": c = base.lightened(0.12)
		elif state == "pressed": c = base.darkened(0.15)
		elif state == "disabled": c = Color(base.r, base.g, base.b, 0.35)
		var style: StyleBox = box(c, Color.TRANSPARENT, 0, 0)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		if state == "focus": style = StyleBoxEmpty.new()
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", text_color)
	b.add_theme_color_override("font_pressed_color", text_color)
	b.add_theme_color_override("font_disabled_color", Color(text_color.r, text_color.g, text_color.b, 0.45))

## A small tag: dark text on a colour, or light on dark.
static func tag(text: String, color: Color = PAPER, dark_text: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, Color.TRANSPARENT, 0, 0))
	var style: StyleBoxFlat = p.get_theme_stylebox("panel")
	style.content_margin_left = 6
	style.content_margin_right = 6
	p.add_child(label(text, 11, INK if dark_text else FG))
	return p

## A section heading: white bar, bold Chinese, small wide English.
static func section(text: String, en_text: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = FG
	bar.custom_minimum_size = Vector2(4, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(label(text, 14, FG))
	if not en_text.is_empty():
		var e := label(en_text, 10, DIM, en())
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(e)
	return row

## Draws a horizontal bar on `canvas`.
static func draw_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill: Color, back: Color = Color(0, 0, 0, 0.75)) -> void:
	canvas.draw_rect(rect, back)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), fill)

## A star polygon centred on `c`.
static func star(c: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(10):
		var radius := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		points.append(c + Vector2(cos(a), sin(a)) * radius)
	return points

static func diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

const KIND_NAMES := {"attack": "攻击", "defense": "防守", "fortune": "机缘", "life": "生存", "tempo": "节奏", "wave": "剑气"}

## AK's big confirm button: bold Chinese over small wide English (获取 / ACQUIRE).
## The Chinese is also kept as the "label" meta so tests can find it.
static func go_button(cn_text: String, en_text: String, kind: String = "blue", cn_size: int = 20) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("label", cn_text)
	style_button(b, kind)
	var dark := kind in ["yellow", "paper", "green"]
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cn_label := label(cn_text, cn_size, INK if dark else FG)
	cn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(cn_label)
	if not en_text.is_empty():
		var en_label := label(en_text, 9, Color(INK, 0.7) if dark else Color(FG, 0.7), en())
		en_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		en_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(en_label)
	b.add_child(column)
	return b

## Placed absolutely: `node` at `at`, sized `size` when given.
static func put(parent: Node, node: Control, at: Vector2, size: Vector2 = Vector2.ZERO) -> Control:
	node.position = at
	if size != Vector2.ZERO:
		node.custom_minimum_size = size
		node.size = size
	parent.add_child(node)
	return node

static func rect(color: Color, at: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = at
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Tier colour of an item tile: potions green, special gear violet, materials by
## their own star colour, gear by grade.
static func tier_color(item: Item) -> Color:
	if item.is_potion(): return GREEN
	if not item.special.is_empty(): return SPECIAL
	if not item.material_id.is_empty(): return item.rarity_color()
	return TIER[clampi(item.rarity, 0, 2)]

## A depot-style item square of `box` size: rarity glow from the bottom, the icon
## scaled to fit (nearest), or the name when there is no icon; stack count box.
static func item_icon(item: Item, box: Vector2) -> ItemSquare:
	var tile := ItemSquare.new()
	tile.item = item
	tile.custom_minimum_size = box
	tile.size = box
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tile

## A relic square: dark plate, rarity line at the bottom, and the relic's icon at
## a whole multiple of its 72 px (RelicIcons); relics without art show the first
## character big in the rarity colour.
static func relic_icon(relic: Dictionary, side: float) -> Control:
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(side, side)
	tile.size = Vector2(side, side)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c: Color = RelicCatalog.RARITY_COLORS[relic.rarity]
	var style := box(Color("1b1b1b"), LINE, 1)
	style.border_width_bottom = 3
	style.border_color = c
	tile.add_theme_stylebox_override("panel", style)
	var texture := RelicIcons.texture_for(relic)
	if texture != null:
		var scale := maxi(1, floori(side / RelicIcons.NATIVE))
		var art := TextureRect.new()
		art.texture = texture
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.size = texture.get_size() * scale
		art.position = ((Vector2(side, side) - art.size) * 0.5).floor()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(art)
		return tile
	var glyph := label(str(relic.name).replace("\"", "").replace("《", "").left(1), int(side * 0.4), c)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(glyph)
	return tile

## A row of AK segmented buttons; the current one is paper. `on_pick(index)`.
static func toggle(names: Array, current: int, on_pick: Callable, size: int = 14) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for i in range(names.size()):
		var b := button(str(names[i]), "paper" if i == current else "plain", size)
		b.custom_minimum_size = Vector2(88, 38)
		var index := i
		b.pressed.connect(func(): on_pick.call(index))
		row.add_child(b)
	return row

## 赤金 / 龙门币 amount with its glyph, for screen corners.
static func money(kind: String, amount: String, size: int = 20) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var glyph := Glyph.new()
	glyph.kind = kind
	glyph.custom_minimum_size = Vector2(16, 16)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	row.add_child(label(amount, size, SP if kind == "gold" else FG, en()))
	return row

## A selected-state frame (AK's yellow corner box) over `parent`.
static func frame(parent: Control, color: Color = SP, width: float = 2.0) -> void:
	var f := ReferenceRect.new()
	f.border_color = color
	f.border_width = width
	f.editor_only = false
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(f)


class Glyph extends Control:
	var kind := "gold"
	func _draw() -> void:
		var c := size * 0.5
		if kind == "gold":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 4), c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(8, 4)]), AK.SP)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(4, -1), c + Vector2(-4, -1)]), Color("fff6c2"))
		else:
			draw_circle(c, 7, AK.FG)
			draw_circle(c, 4.5, AK.INK)


class ItemSquare extends Control:
	var item: Item
	var dim := false
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		if item == null: return
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color("2b2b2b"))
		var c := AK.tier_color(item)
		for i in range(8):
			var t := float(i) / 8
			draw_rect(Rect2(0, s.y * (0.4 + 0.6 * t), s.x, s.y * 0.6 / 8 + 1), Color(c.r, c.g, c.b, 0.06 + 0.32 * t))
		draw_rect(Rect2(0, s.y - 3, s.x, 3), c)
		var texture := ItemIcons.texture_for(item)
		if texture != null:
			var k := minf(1.0, minf((s.x - 6) / texture.get_width(), (s.y - 8) / texture.get_height()))
			if s.x >= texture.get_width() * 2 + 6 and s.y >= texture.get_height() * 2 + 8: k = 2.0
			var shown := texture.get_size() * k
			draw_texture_rect(texture, Rect2(((s - shown) * 0.5).floor(), shown), false)
		else:
			# No icon yet: as many characters of the name as fit.
			var font_size := 12 if s.x < 60 else 14
			var shown_name := item.item_name
			while shown_name.length() > 1 and AK.cn().get_string_size(shown_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > s.x - 6:
				shown_name = shown_name.left(shown_name.length() - 1)
			var w := AK.cn().get_string_size(shown_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(AK.cn(), Vector2((s.x - w) * 0.5, s.y * 0.5 + 5), shown_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, AK.FG)
		if item.is_stackable():
			var count := str(item.quantity)
			var cw := AK.en().get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_rect(Rect2(s.x - cw - 6, s.y - 18, cw + 6, 14), Color.BLACK)
			draw_string(AK.en(), Vector2(s.x - cw - 3, s.y - 7), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		if dim: draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.62))


## A clickable bag (pack or safe bag) for shop and camp screens: tiles where the
## items lie, those `allowed` refuses dimmed, the `selected` one outlined yellow.
## `on_pick(item)` fires on a click on an allowed item.
class BagGrid extends Control:
	const CELL := 40
	var container: ItemContainer
	var allowed: Callable
	var on_pick: Callable
	var selected: Item

	static func make(bag: ItemContainer, allow: Callable = Callable(), pick: Callable = Callable(), current: Item = null) -> BagGrid:
		var grid := BagGrid.new()
		grid.container = bag
		grid.allowed = allow
		grid.on_pick = pick
		grid.selected = current
		grid.custom_minimum_size = Vector2(bag.width, bag.height) * CELL
		return grid

	func _ready() -> void:
		for item in container.items:
			var ok: bool = not allowed.is_valid() or allowed.call(item)
			var tile := Button.new()
			tile.focus_mode = Control.FOCUS_NONE
			tile.flat = true
			tile.position = Vector2(item.grid_x, item.grid_y) * CELL
			tile.size = Vector2(item.width, item.height) * CELL - Vector2.ONE
			tile.set_meta("item", item)
			var square := AK.item_icon(item, tile.size)
			square.dim = not ok
			tile.add_child(square)
			if item == selected: AK.frame(tile)
			if ok and on_pick.is_valid():
				var shown := item
				tile.pressed.connect(func(): on_pick.call(shown))
			add_child(tile)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(container.width, container.height) * CELL), Color(0, 0, 0, 0.55))
		for x in range(container.width + 1): draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, container.height * CELL), Color(1, 1, 1, 0.07))
		for y in range(container.height + 1): draw_line(Vector2(0, y * CELL), Vector2(container.width * CELL, y * CELL), Color(1, 1, 1, 0.07))
