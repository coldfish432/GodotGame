class_name ResearchTreeView
extends Control

## 科研部's tree as a map (用户 2026-10-22: 不用一个界面放下，左键拖动，滚轮缩放;
## after 钢铁雄心4's focus tree, 维多利亚3's tech, 缺氧's research): tiers run
## left to right, a band per department and the joint research below, every
## prerequisite drawn as a line with an arrow into the node it opens. Drawn
## by hand under one transform, so panning and zooming are a matrix.

const COLUMN := 250.0
const CARD := Vector2(204, 72)
const ROW_GAP := 14.0
const BAND_PAD := 22.0
const LABEL_W := 150.0
const HEADER := 44.0
const ZOOM := Vector2(0.4, 1.6)
## Under this zoom a card shows its name only.
const DETAIL_ZOOM := 0.62
## A press that moves less than this is a click, not a drag.
const CLICK_SLOP := 5.0

var game: GameManager
var pick := ""
var on_pick: Callable
var on_view: Callable
var offset := Vector2(20, 10)
var zoom := 0.75

var _press := Vector2.ZERO
var _dragging := false
var _moved := 0.0
var _wait := 0.0

static var _cards := {}
static var _bands := {}
static var _extent := Vector2.ZERO

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _cards.is_empty(): _layout()

## Card rectangles and band spans, in canvas units, built once.
static func _layout() -> void:
	var y := HEADER
	for band in ResearchCatalog.BANDS:
		var most := 1
		var per := {}
		var nodes := ResearchCatalog.band_nodes(band)
		for id in nodes:
			var t := ResearchCatalog.tier_of(id)
			per[t] = int(per.get(t, 0)) + 1
			most = maxi(most, int(per[t]))
		var height := BAND_PAD * 2.0 + most * CARD.y + (most - 1) * ROW_GAP
		_bands[band] = Vector2(y, height)
		var used := {}
		for id in nodes:
			var t := ResearchCatalog.tier_of(id)
			var k := int(used.get(t, 0))
			used[t] = k + 1
			_cards[id] = Rect2(Vector2(LABEL_W + (t - 1) * COLUMN, y + BAND_PAD + k * (CARD.y + ROW_GAP)), CARD)
		y += height + 8.0
	_extent = Vector2(LABEL_W + 7 * COLUMN, y)

## The view on `id`: zoom kept, the card brought to the middle.
func centre_on(id: String) -> void:
	if not _cards.has(id): return
	offset = size * 0.5 - (_cards[id] as Rect2).get_center() * zoom
	_clamp()

func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.5
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed: _zoom_at(button.position, 1.12 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				if button.pressed:
					_dragging = true
					_press = button.position
					_moved = 0.0
				else:
					_dragging = false
					if button.button_index == MOUSE_BUTTON_LEFT and _moved < CLICK_SLOP:
						var hit := card_at(button.position)
						if not hit.is_empty() and on_pick.is_valid(): on_pick.call(hit)
					_report()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_moved += motion.relative.length()
		offset += motion.relative
		_clamp()
		queue_redraw()
		accept_event()

func _zoom_at(at: Vector2, factor: float) -> void:
	var next := clampf(zoom * factor, ZOOM.x, ZOOM.y)
	offset = at - (at - offset) * (next / zoom)
	zoom = next
	_clamp()
	queue_redraw()
	_report()

## Keeps some of the tree on screen whatever the drag.
func _clamp() -> void:
	var span := _extent * zoom
	offset.x = clampf(offset.x, size.x * 0.5 - span.x, size.x * 0.5)
	offset.y = clampf(offset.y, size.y * 0.5 - span.y, size.y * 0.5)

func _report() -> void:
	if on_view.is_valid(): on_view.call(offset, zoom)

## The node under a point of the view ("" if none).
func card_at(at: Vector2) -> String:
	var p := (at - offset) / zoom
	for id in _cards:
		if (_cards[id] as Rect2).has_point(p): return str(id)
	return ""

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d1216"))
	if game == null: return
	var r := game.research
	draw_set_transform(offset, 0.0, Vector2(zoom, zoom))
	var font := AK.cn()
	# Tier columns and their marks.
	for t in range(1, 8):
		var x := LABEL_W + (t - 1) * COLUMN
		draw_rect(Rect2(Vector2(x - 23, 0), Vector2(2, _extent.y)), Color(AK.LINE, 0.35))
		draw_string(AK.en(), Vector2(x, 30), ResearchCatalog.tier_label(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, AK.MUTE)
	# Department bands.
	for band in ResearchCatalog.BANDS:
		var span: Vector2 = _bands[band]
		var colour: Color = ResearchCatalog.DEPARTMENT_COLORS[band]
		draw_rect(Rect2(Vector2(0, span.x), Vector2(_extent.x, span.y)), Color(colour, 0.06))
		draw_rect(Rect2(Vector2(0, span.x), Vector2(6, span.y)), colour)
		draw_string(font, Vector2(18, span.x + 36), I18n.t(ResearchCatalog.DEPARTMENT_NAMES[band]), HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 30, 22, AK.FG)
	# Every prerequisite: done ones in their department's colour, the picked
	# node's own in gold, drawn under the cards.
	var near := {}
	for p in ResearchCatalog.prerequisite_nodes(pick): near[p + ">" + pick] = true
	for u in ResearchCatalog.unlocks(pick): near[pick + ">" + u] = true
	for pass_index in range(2):
		for id in _cards:
			for p in ResearchCatalog.prerequisite_nodes(str(id)):
				var lit := near.has(p + ">" + str(id))
				if lit != (pass_index == 1): continue
				var colour: Color = AK.SP if lit else (Color(ResearchCatalog.DEPARTMENT_COLORS[ResearchCatalog.department_of(p)], 0.75) if r.is_done(p) else Color(AK.LINE_2, 0.45))
				_link(_cards[p], _cards[id], colour, 4.0 if lit else 2.0, ResearchCatalog.tier_of(p) == ResearchCatalog.tier_of(str(id)))
	for id in _cards: _card(str(id), _cards[id], r, font)

func _link(from: Rect2, to: Rect2, colour: Color, width: float, same_tier: bool) -> void:
	var points: PackedVector2Array
	var tip: Vector2
	var heading: Vector2
	if same_tier:
		var a := Vector2(from.get_center().x, from.end.y)
		tip = Vector2(to.get_center().x, to.position.y)
		points = PackedVector2Array([a, tip])
		heading = Vector2.DOWN
	else:
		var a := Vector2(from.end.x, from.get_center().y)
		tip = Vector2(to.position.x, to.get_center().y)
		var half := (COLUMN - CARD.x) * 0.5
		var last := tip.x - half
		if to.position.x - from.end.x <= COLUMN:
			# Next tier: down the gutter between them.
			points = PackedVector2Array([a, Vector2(last, a.y), Vector2(last, tip.y), tip])
		else:
			# Further: out into the gutter after its own card, along the gap
			# above the card it opens, and down the gutter before it, so it
			# never runs across a card in between.
			var first := from.end.x + half
			var lane := to.position.y - ROW_GAP * 0.5
			points = PackedVector2Array([a, Vector2(first, a.y), Vector2(first, lane), Vector2(last, lane), Vector2(last, tip.y), tip])
		heading = Vector2.RIGHT
	draw_polyline(points, colour, width, true)
	var side := heading.orthogonal() * 6.0
	draw_colored_polygon(PackedVector2Array([tip, tip - heading * 11.0 + side, tip - heading * 11.0 - side]), colour)

func _card(id: String, box: Rect2, r: Research, font: Font) -> void:
	var colour: Color = ResearchCatalog.DEPARTMENT_COLORS[ResearchCatalog.department_of(id)]
	var done := r.is_done(id)
	var running := r.is_running(id)
	var reachable := r.missing_prerequisite(id).is_empty()
	var fill := Color(colour, 0.30) if done else (AK.PLATE_3 if reachable else AK.PLATE_2)
	draw_rect(box, fill)
	draw_rect(Rect2(box.position, Vector2(6, box.size.y)), colour if done or reachable else Color(colour, 0.4))
	if id == pick: draw_rect(box.grow(3.0), AK.SP, false, 3.0)
	elif running: draw_rect(box, AK.SP, false, 2.0)
	elif reachable and not done: draw_rect(box, Color(colour, 0.8), false, 1.5)
	# Combat nodes carry a diamond.
	if ResearchCatalog.is_combat(id):
		var c := box.position + Vector2(box.size.x - 14, 14)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), colour if done or reachable else Color(colour, 0.45))
	var text := AK.FG if done or reachable else AK.MUTE
	if zoom < DETAIL_ZOOM:
		draw_string(font, box.position + Vector2(16, box.size.y * 0.5 + 9), I18n.t(ResearchCatalog.name_of(id)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 34, 24, text)
		return
	draw_string(font, box.position + Vector2(16, 26), I18n.t(ResearchCatalog.name_of(id)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 40, 17, text)
	draw_string(font, box.position + Vector2(16, 46), I18n.t(ResearchCatalog.effect_text(id)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 22, 12, AK.MUTE)
	var foot: String
	var foot_colour := AK.MUTE
	if done:
		foot = I18n.t("已完成")
		foot_colour = colour
	elif running:
		foot = "%d%%" % roundi(r.progress(id) * 100.0)
		foot_colour = AK.SP
		draw_rect(Rect2(box.position + Vector2(0, box.size.y - 4), Vector2(box.size.x * r.progress(id), 4)), AK.SP)
	else:
		foot = "%s   %d h" % [Economy.format(ResearchCatalog.price(id)), ResearchCatalog.hours(id)]
	draw_string(AK.en(), box.position + Vector2(16, 64), foot, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 22, 12, foot_colour)
