class_name Terminal
extends RefCounted

## The 陆行舰终端 look (界面美术与布局策划案 v2 §1, 界面动态美术方案 v3): Sol's
## UC kit panels (art/ui/kit, 9-slice), department colours, the corner
## brackets / hazard chip / header line every window carries, and the motion —
## a scan-line reveal when a screen opens, a slanted wipe between big screens,
## titles typing in. Every effect is drawn over the screen and ignores the
## mouse, so a click lands the same during an animation as after it. No sheen,
## no background holograms, no moving portraits (用户 2026-10-21).

const REVEAL_SECONDS := 0.5
const WIPE_IN := 0.36
const WIPE_OUT := 0.4
## Department colours (v2 §1.2): the accent block, header line and brackets.
const DEPT := {
	"bridge": Color("3fd2f2"), "eng": Color("e8b730"), "log": Color("4b9be0"), "med": Color("2fbfa6"),
	"lab": Color("8fb8ff"), "store": Color("ff5fa2"),
}
const STATION_DEPT := {
	"contracts": "bridge", "sand_table": "bridge", "personnel": "bridge", "exchange": "bridge",
	"stash": "eng", "shelves": "eng", "outbound": "eng",
	"loadout": "log", "insurance": "log", "workshop": "log",
	"pharmacy": "med", "report": "med", "research": "lab", "store": "store",
	"construction": "eng", "farm": "med", "canteen": "log", "lift": "bridge",
}

static var _styles := {}

## True unless the player chose 精简 under 设置 → 界面 → 界面动效.
static func motion() -> bool:
	return bool(SystemScreens.settings.get("ui_motion", true))

static func dept_color(station: String) -> Color:
	return DEPT.get(STATION_DEPT.get(station, "bridge"), DEPT.bridge)

## A terminal panel as in the UI prototype (用户 2026-10-21: 不要这个背景材质，
## 改用 ui 示例里的): a dark hull fill fading down, a 1 px edge lit at the top
## and left, the top-left and bottom-right corners cut. "plate" opaque, "glass"
## lets the field show through.
static func panel_style(kind: String = "plate", content_margin: int = 0) -> StyleBox:
	var key := "%s:%d" % [kind, content_margin]
	if _styles.has(key): return _styles[key]
	var style := ChamferBox.new()
	style.glass = kind == "glass"
	style.white = kind == "white"
	for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, content_margin)
	_styles[key] = style
	return style

## The frame every terminal window carries, drawn over `parent`: four corner
## brackets, a hazard chip at the top-left, and a glowing line under a header
## of `header` px (0: none).
static func frame(parent: Control, accent: Color = DEPT.bridge, header: float = 0.0) -> Frame:
	var f := Frame.new()
	f.accent = accent
	f.header = header
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(f)
	return f

## The opening scan: a dark curtain over `target` lifts from the top behind a
## bright line (v3 §2). Added last so it lies over the content.
static func reveal(target: Control, accent: Color = DEPT.bridge) -> void:
	if not motion() or not is_instance_valid(target): return
	var curtain := Curtain.new()
	curtain.accent = accent
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.z_index = 50
	target.add_child(curtain)
	var tween := curtain.create_tween()
	tween.tween_property(curtain, "progress", 1.0, REVEAL_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(curtain.queue_free)

## A title typing in: the text is whole from the start (tests read it), only
## its visible share grows.
static func type_in(label: Label, seconds: float = 0.35) -> void:
	if not motion() or not is_instance_valid(label): return
	label.visible_ratio = 0.0
	label.create_tween().tween_property(label, "visible_ratio", 1.0, seconds)

## The slanted wipe between big screens: two dark plates close in from the
## sides (hazard yellow and holo cyan edges), the Rhodes mark, then open.
## `swap` runs at the moment they meet. Mouse passes through.
static func wipe(host: Node, swap: Callable = Callable()) -> void:
	_wipe(host, swap, false)

## The second half only: the plates start shut and open on a screen that is
## already built (opening a station, which tests click at once).
static func wipe_open(host: Node) -> void:
	_wipe(host, Callable(), true)

static func _wipe(host: Node, swap: Callable, open_only: bool) -> void:
	if not motion() or not is_instance_valid(host) or not host.is_inside_tree():
		if swap.is_valid(): swap.call()
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	var plates := Wipe.new()
	plates.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(plates)
	host.get_tree().root.add_child(layer)
	var tween := plates.create_tween()
	if open_only:
		plates.closed = 1.0
		tween.tween_interval(0.08)
	else:
		tween.tween_property(plates, "closed", 1.0, WIPE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if swap.is_valid(): tween.tween_callback(swap)
	tween.tween_property(plates, "closed", 0.0, WIPE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(layer.queue_free)


class ChamferBox extends StyleBox:
	const CUT := 12.0
	var glass := false
	## The medical deck's 白舱 skin: a matte light grey, kept well off white.
	var white := false
	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var x := rect.position.x
		var y := rect.position.y
		var w := rect.size.x
		var h := rect.size.y
		var c := minf(CUT, minf(w, h) * 0.25)
		var points := PackedVector2Array([Vector2(x + c, y), Vector2(x + w, y), Vector2(x + w, y + h - c),
			Vector2(x + w - c, y + h), Vector2(x, y + h), Vector2(x, y + c)])
		var top := Color(0.055, 0.071, 0.082, 0.78 if glass else 0.95)
		var bottom := Color(0.039, 0.051, 0.063, 0.86 if glass else 0.97)
		if white:
			top = Color("aeb7bc")
			bottom = Color("98a2a8")
		var fill := PackedColorArray()
		for pt in points: fill.append(top.lerp(bottom, (pt.y - y) / maxf(h, 1.0)))
		RenderingServer.canvas_item_add_polygon(to_canvas_item, points, fill)
		# The edge: lit along the top and left, the seam colour elsewhere.
		var lit := Color("d3dade") if white else Color("6b7880")
		var seam := Color("7c878d") if white else Color("3b4146")
		var dark := Color("5f6a70") if white else Color("2a3035")
		var ring := PackedVector2Array([points[5], points[0], points[1], points[2], points[3], points[4], points[5]])
		var colours := PackedColorArray([lit, lit, seam, seam, dark, seam, lit])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, ring, colours, 1.0)


class Frame extends Control:
	var accent := Color("3fd2f2")
	var header := 0.0
	static var _hazard: Texture2D
	func _draw() -> void:
		var s := size
		var arm := 14.0
		var w := 2.0
		var o := -4.0
		for corner in [Vector2(o, o), Vector2(s.x - o, o), Vector2(o, s.y - o), Vector2(s.x - o, s.y - o)]:
			var dx := arm if corner.x < s.x * 0.5 else -arm
			var dy := arm if corner.y < s.y * 0.5 else -arm
			draw_rect(Rect2(Vector2(minf(corner.x, corner.x + dx), corner.y - (0.0 if dy > 0 else w)), Vector2(arm, w)), accent)
			draw_rect(Rect2(Vector2(corner.x - (0.0 if dx > 0 else w), minf(corner.y, corner.y + dy)), Vector2(w, arm)), accent)
		if _hazard == null: _hazard = load("res://art/kit/textures/painted/base_hazard.png")
		if _hazard != null:
			# Just above the top edge, so it never covers a title.
			draw_texture_rect_region(_hazard, Rect2(14, -6, 72, 4), Rect2(0, 0, 72, 4))
		if header > 0.0:
			for i in range(3):
				var a := 0.9 - i * 0.35
				draw_rect(Rect2(12, header - 1 + i, s.x * 0.55, 1), Color(accent, a * 0.6))
			draw_rect(Rect2(12, header - 1, s.x * 0.35, 1), accent)


class Curtain extends Control:
	var accent := Color("3fd2f2")
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()
	func _draw() -> void:
		var y := size.y * progress
		draw_rect(Rect2(0, y, size.x, size.y - y), Color(AK.BG, 0.96))
		for i in range(6):
			draw_rect(Rect2(0, y - i * 2, size.x, 2), Color(accent, (0.55 - i * 0.09) * (1.0 - progress * 0.6)))
		draw_rect(Rect2(0, y - 1, size.x, 2), Color(1, 1, 1, 0.85 * (1.0 - progress)))


class Wipe extends Control:
	const SKEW := 120.0
	var closed := 0.0:
		set(v):
			closed = v
			queue_redraw()
	static var _logo: Texture2D
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var reach := (w * 0.5 + SKEW) * closed
		var left := PackedVector2Array([Vector2(-SKEW, 0), Vector2(reach - SKEW, 0), Vector2(reach, h), Vector2(-SKEW, h)])
		var right := PackedVector2Array([Vector2(w - reach, 0), Vector2(w + SKEW, 0), Vector2(w + SKEW, h), Vector2(w - reach + SKEW, h)])
		var dark := Color("07090b")
		draw_colored_polygon(left, dark)
		draw_colored_polygon(right, dark)
		if closed > 0.02:
			draw_line(Vector2(reach - SKEW, 0), Vector2(reach, h), Color("e8b730"), 6.0)
			draw_line(Vector2(w - reach, 0), Vector2(w - reach + SKEW, h), Color("3fd2f2"), 6.0)
		if closed > 0.85:
			if _logo == null: _logo = load("res://art/kit/textures/base_rhodes_logo.png")
			if _logo != null:
				var side := 72.0
				draw_texture_rect(_logo, Rect2(Vector2(w, h) * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(1, 1, 1, (closed - 0.85) / 0.15 * 0.9))
