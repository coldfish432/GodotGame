class_name StatusBar
extends Control
## The status icons above the hotbar (GPU粒子特效推广策划案 v0.6 §7b P7): one
## icon per buff, debuff, canteen meal and meter stage, left to right in the
## order they turned up (用户裁决 3), wrapping upwards when a row is full. A
## clock face sweeps clockwise from twelve over each timed one; the last
## THREE_SECONDS it blinks. The frame is white for a buff, dark red-brown for a
## debuff. No text on the icons; hovering one shows its name, effect and time
## left (用户裁决 4). Field only.

const ICON := 30.0
const GAP := 4.0
const LIFT := 10.0
const BLINK_FROM := 3.0
const GOOD_FRAME := Color(0.92, 0.94, 0.96)
const BAD_FRAME := Color(0.55, 0.22, 0.16)
const MIN_ROW := 300.0

var hud: Hud
## id -> {seq, total}: when each first showed (order) and the longest time it had.
var _seen := {}
var _seq := 0
var entries: Array = []
var _hover := -1
var _pulse := 0.0
## Captures only: shows this icon's tooltip as if hovered (-1 off).
var force_hover := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_pulse += delta
	var game := hud.game if is_instance_valid(hud) else null
	visible = is_instance_valid(game) and hud.visible and not game.in_base
	if not visible:
		entries = []
		return
	refresh(game)
	queue_redraw()

## Rebuilds the entries from the game: order kept by first sighting.
func refresh(game: GameManager) -> void:
	var now: Array = StatusCatalog.bar_entries(game)
	var live := {}
	for e in now:
		var id: String = e.id
		live[id] = true
		var t := float(e.time)
		if not _seen.has(id):
			_seq += 1
			_seen[id] = {"seq": _seq, "total": maxf(t, 0.0)}
		# Refreshed (more time than before): the clock starts over from full.
		elif t > float(_seen[id].get("last", t)) + 0.05: _seen[id].total = t
		_seen[id].total = maxf(float(_seen[id].total), t)
		_seen[id]["last"] = t
		e["seq"] = int(_seen[id].seq)
		e["total"] = float(_seen[id].total)
	for id in _seen.keys():
		if not live.has(id): _seen.erase(id)
	now.sort_custom(func(a, b): return int(a.seq) < int(b.seq))
	entries = now

## Where icon `i` sits: rows over the hotbar, from its left edge.
func icon_rect(i: int) -> Rect2:
	var bar := hud.hotbar_rect()
	var width := maxf(bar.size.x, MIN_ROW)
	var per_row := maxi(1, int((width + GAP) / (ICON + GAP)))
	var row := i / per_row
	var col := i % per_row
	var top := bar.position.y - 6.0 - LIFT - ICON - row * (ICON + GAP)
	return Rect2(bar.position.x + col * (ICON + GAP), top, ICON, ICON)

## Elapsed share of a timed entry (0 just begun, 1 run out); -1 untimed.
static func elapsed(entry: Dictionary) -> float:
	var t := float(entry.time)
	var total := float(entry.get("total", t))
	if t < 0.0 or total <= 0.0: return -1.0
	return clampf(1.0 - t / total, 0.0, 1.0)

func _draw() -> void:
	_hover = -1
	var mouse := get_local_mouse_position()
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var r := icon_rect(i)
		var alpha := 1.0
		var t := float(e.time)
		if t >= 0.0 and t <= BLINK_FROM: alpha = 0.45 + 0.55 * (0.5 + 0.5 * cos(_pulse * TAU * 2.0))
		draw_rect(r, Color(0.08, 0.09, 0.1, 0.85 * alpha))
		_draw_icon(r, e, alpha)
		var share := elapsed(e)
		if share > 0.0: _draw_sweep(r, share, alpha)
		draw_rect(r, Color(GOOD_FRAME if e.good else BAD_FRAME, alpha), false, 2.0)
		if r.has_point(mouse): _hover = i
	if force_hover >= 0 and force_hover < entries.size(): _hover = force_hover
	if _hover >= 0: _draw_tip(entries[_hover], icon_rect(_hover))

## The dark wedge of time gone, clockwise from twelve, a clock face inside the icon.
func _draw_sweep(r: Rect2, share: float, alpha: float) -> void:
	var c := r.get_center()
	var radius := r.size.x * 0.5 - 1.0
	var points := PackedVector2Array([c])
	var steps := maxi(2, int(40 * share))
	for k in range(steps + 1):
		var a := -PI * 0.5 + TAU * share * float(k) / float(steps)
		points.append(c + Vector2(cos(a), sin(a)) * radius)
	if share < 0.999: draw_colored_polygon(points, Color(0, 0, 0, 0.62 * alpha))
	else: draw_circle(c, radius, Color(0, 0, 0, 0.62 * alpha))
	draw_arc(c, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.25 * alpha), 1.0)

func _draw_icon(r: Rect2, e: Dictionary, alpha: float) -> void:
	var icon: Dictionary = e.icon
	var c := r.get_center()
	var white := Color(0.95, 0.95, 0.95, alpha)
	if icon.has("potion") and BaseCatalog.POTIONS.has(icon.potion):
		var art := ItemIcons.texture_for(BaseCatalog.create_potion(icon.potion))
		if art != null:
			var size := art.get_size().min(r.size - Vector2(4, 4))
			draw_texture_rect(art, Rect2(c - size * 0.5, size), false, Color(1, 1, 1, alpha))
			return
	match str(icon.get("glyph", "")):
		"meal":
			draw_arc(c + Vector2(0, -1), 9, 0.0, PI, 12, white, 2.2)
			draw_line(c + Vector2(-11, -1), c + Vector2(11, -1), white, 2.2)
			draw_line(c + Vector2(-4, -6), c + Vector2(-2, -11), Color(0.9, 0.8, 0.6, alpha), 1.6)
			draw_line(c + Vector2(3, -6), c + Vector2(5, -11), Color(0.9, 0.8, 0.6, alpha), 1.6)
		"cold":
			for k in range(3):
				var d := Vector2.from_angle(PI * k / 3.0) * 10.0
				draw_line(c - d, c + d, Color(0.8, 0.92, 1.0, alpha), 2.0)
		"contamination":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(6, 0), c + Vector2(0, 11), c + Vector2(-6, 0)]), Color(1.0, 0.55, 0.16, alpha))
			draw_line(c + Vector2(0, -11), c + Vector2(0, 11), Color(0.2, 0.08, 0.02, alpha), 1.4)
		"debt":
			draw_line(c + Vector2(-9, 9), c + Vector2(8, -8), Color(0.8, 0.3, 0.25, alpha), 2.6)
			draw_line(c + Vector2(-4, 2), c + Vector2(2, 8), white, 2.0)
		"corrode":
			draw_circle(c + Vector2(0, 3), 6, Color(0.55, 0.8, 0.35, alpha))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(5, 0), c + Vector2(-5, 0)]), Color(0.55, 0.8, 0.35, alpha))
		"necro":
			draw_arc(c, 9, 0.0, TAU, 20, Color(0.6, 0.5, 0.75, alpha), 2.0)
			draw_circle(c, 3, Color(0.6, 0.5, 0.75, alpha))
		_:
			draw_polyline(PackedVector2Array([c + Vector2(-10, -6), c + Vector2(-3, 2), c + Vector2(3, -4), c + Vector2(10, 6)]), Color(0.85, 0.4, 0.3, alpha), 2.4)
			draw_circle(c + Vector2(0, -8), 2.5, white)

## Name, effect lines and time left, over the icon.
func _draw_tip(e: Dictionary, r: Rect2) -> void:
	var font := AK.cn()
	var lines: Array = [I18n.t(str(e.name))]
	for line in e.effect: lines.append(I18n.t(str(line)))
	if float(e.time) >= 0.0: lines.append(I18n.t("剩余 %d 秒") % ceili(float(e.time)))
	var width := 0.0
	for line in lines: width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	var box := Rect2(r.position.x, r.position.y - 8 - lines.size() * 17 - 8, width + 16, lines.size() * 17 + 8)
	var width_max := maxf(size.x, get_viewport_rect().size.x)
	box.position.x = clampf(box.position.x, 4.0, maxf(4.0, width_max - box.size.x - 4.0))
	draw_rect(box, Color(0.05, 0.06, 0.07, 0.92))
	draw_rect(box, GOOD_FRAME if e.good else BAD_FRAME, false, 1.0)
	for i in range(lines.size()):
		draw_string(font, box.position + Vector2(8, 18 + i * 17), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AK.FG if i > 0 else Color.WHITE)
