class_name StoryCard
extends Control

## 主线引导 on screen (主基地线性叙事与教程策划案 v0.2 §五). In the base only:
## - the objective card: TutorialCard's plate at the same spot, a yellow 主线
##   tag, the beat's name, one row per goal with a box that ticks itself. The
##   新手引导 card goes first; this one waits while that one is up.
## - the dialogue: when a beat begins and she next walks the base, the screen
##   dims and its lines come one at a time: the speaker's full-body standing
##   art at 2× on the left (none for PRTS or before her art is in), the box
##   beside it, 继续 to go on, Esc to skip the rest.
## Story holds the beats and their checks; the state is BaseState.story.
## Only the real game shows it (game.system_screens set), or a test that sets
## `forced`.

const CHECK_SECONDS := 0.25
const DIM := 0.6
## The standing art (120×240) at 2×, its feet on the bottom edge; the box to its right.
const STANDING := Vector2(240, 480)
const STANDING_AT := Vector2(56, 720 - 480)
const TALK_LEFT := 320.0
## Standing art drawn facing left (UB 可露希尔, ST1a 杜宾): mirrored, so every
## speaker looks toward the box.
const MIRROR := ["可露希尔", "杜宾"]
const LINE_WIDTH := 640.0

var game: GameManager
var forced := false
## The beat whose lines are up ("" none) and which line.
var speaking := ""
var line_index := 0
var _lines: Array = []
var _check_left := 0.0
var _card: PanelContainer
var _card_title: Label
var _goals: VBoxContainer
var _dim: ColorRect
var _talk: PanelContainer
var _face: TextureRect
var _speaker: Label
var _line: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()
	_build_talk()

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(TutorialCard.WIDTH, 0)
	var plate := AK.box(AK.PLATE, AK.SP, 0, 12)
	plate.border_width_left = 3
	_card.add_theme_stylebox_override("panel", plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	head.add_child(_tag("主线", AK.SP))
	_card_title = AK.label("", 15, AK.FG)
	_card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_card_title)
	column.add_child(AK.rect(AK.LINE, Vector2.ZERO, Vector2(TutorialCard.WIDTH - 24, 1)))
	_goals = VBoxContainer.new()
	_goals.add_theme_constant_override("separation", 4)
	column.add_child(_goals)
	_card.visible = false
	add_child(_card)

func _build_talk() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, DIM)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)
	_talk = PanelContainer.new()
	var plate := AK.box(AK.PLATE, AK.SP, 0, 14)
	plate.border_width_left = 3
	_talk.add_theme_stylebox_override("panel", plate)
	_face = TextureRect.new()
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.position = STANDING_AT
	_face.size = STANDING
	_face.visible = false
	add_child(_face)
	var row := HBoxContainer.new()
	_talk.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)
	_speaker = AK.label("", 15, AK.SP)
	column.add_child(_speaker)
	_line = AK.label("", 14, AK.FG)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(LINE_WIDTH, 0)
	# It wraps instead: English keeps the full size (AK.fit would shrink it).
	_line.remove_meta("fit_size")
	column.add_child(_line)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(foot)
	var next := AK.button("继续", "yellow", 12)
	next.custom_minimum_size = Vector2(88, 30)
	next.pressed.connect(advance)
	foot.add_child(next)
	_talk.visible = false
	add_child(_talk)

static func _tag(text: String, colour: Color) -> Label:
	var tag := AK.label(text, 11, AK.INK)
	var tag_plate := AK.box(colour, Color.TRANSPARENT, 0, 0)
	tag_plate.content_margin_left = 6
	tag_plate.content_margin_right = 6
	tag.add_theme_stylebox_override("normal", tag_plate)
	return tag

func _active() -> bool:
	return is_instance_valid(game) and is_instance_valid(game.player) and (forced or is_instance_valid(game.system_screens))

func _process(delta: float) -> void:
	if not _active() or not Story.is_on():
		_card.visible = false
		if not speaking.is_empty(): _end_talk()
		return
	if not speaking.is_empty():
		if game.modal != "story": _end_talk()
		return
	var state: Dictionary = game.base.story
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_SECONDS
		if Story.update(game, state): game.save_base(not game.in_base)
	var calm: bool = game.in_base and game.base_walk_active() and game.modal.is_empty() and not game.transitioning
	var beats := Story.active(state)
	if calm:
		for b in beats:
			if not b.id in state.seen:
				start_talk(b)
				return
	_card.visible = calm and not beats.is_empty() and not (is_instance_valid(game.tutorial_card) and game.tutorial_card.visible)
	if _card.visible: _fill_card(state, beats)

func _fill_card(state: Dictionary, beats: Array) -> void:
	_card_title.text = " · ".join(beats.map(func(b): return I18n.t(b.title)))
	for child in _goals.get_children():
		_goals.remove_child(child)
		child.queue_free()
	for b in beats:
		for g in b.goals:
			var done: bool = g[0] in state.done
			if done and g[0] in b.get("hide_done", []): continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var box := Panel.new()
			box.custom_minimum_size = Vector2(14, 14)
			box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			box.add_theme_stylebox_override("panel", AK.box(AK.GREEN if done else Color.TRANSPARENT, AK.GREEN if done else AK.FG, 2, 0))
			row.add_child(box)
			var text := AK.label(g[1], 13, AK.GREEN if done else AK.FG)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.custom_minimum_size = Vector2(TutorialCard.WIDTH - 50, 0)
			text.remove_meta("fit_size")
			row.add_child(text)
			_goals.add_child(row)
	_card.reset_size()
	_card.position = Vector2(TutorialCard.RIGHT - _card.size.x, TutorialCard.BOTTOM - _card.size.y)

## A beat's lines, one at a time, over the base (modal "story").
func start_talk(b: Dictionary) -> void:
	var state: Dictionary = game.base.story
	if not b.id in state.seen: state.seen.append(b.id)
	game.save_base()
	_lines = Story.lines_of(state, b)
	if _lines.is_empty(): return
	speaking = b.id
	line_index = 0
	game.open_modal("story")
	_card.visible = false
	_dim.visible = true
	_talk.visible = true
	_show_line()

func advance() -> void:
	if speaking.is_empty(): return
	line_index += 1
	if line_index >= _lines.size(): _end_talk()
	else: _show_line()

## Esc: the rest of the lines are skipped.
func go_back() -> bool:
	if speaking.is_empty(): return false
	_end_talk()
	return true

func _end_talk() -> void:
	speaking = ""
	_dim.visible = false
	_talk.visible = false
	_face.visible = false
	if game.modal == "story": game.close_modal()

func _show_line() -> void:
	var who: String = _lines[line_index][0]
	_speaker.text = who
	_line.text = _lines[line_index][1]
	var path: String = Story.PORTRAITS.get(who, "")
	_face.texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	_face.visible = _face.texture != null
	_face.flip_h = who in MIRROR
	_talk.reset_size()
	_talk.position = Vector2(TALK_LEFT, 720.0 - 60.0 - _talk.size.y)
