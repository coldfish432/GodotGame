class_name BarrierFx
extends Sprite3D
## The barrier shell over anyone who has one (用户 2026-10-11: 屏障另画以复用,
## 给 Sol 画). One effect for 灰尾's 法抗屏障, 灰尾香主's, and every shield the
## operator carries (灰尾屏障坠, 灰色秩序, 香主铁骨扇, 活木甲 …).
##
## Sol's colour-neutral strips (N2_action_revision_v3.md §2, installed by
## art/install_n2_boards.py into art/field/fx/), all 64×64 cells laid out like
## an enemy cell (feet line y = 51, centre x = 32):
##   barrier_shell   4-frame loop, intact;
##   barrier_cracked 4-frame loop, once half its strength is gone;
##   barrier_break   5 frames, played once when it breaks.
## The game multiplies in the user's colour and draws it at 70% opacity. No hit
## flash (用户: 屏障不要闪光).
##
## Usage: add as a child of the actor, call `follow(feet)` each frame with the
## feet point in the actor's local space, set `cracked`, and `shatter()` when
## it breaks. `size` scales the circle (elites 1.2).

const SHELL := preload("res://art/field/fx/barrier_shell.png")
const CRACKED := preload("res://art/field/fx/barrier_cracked.png")
const BREAK := preload("res://art/field/fx/barrier_break.png")
const OPACITY := 0.7
const LOOP_FPS := 6.0
const BREAK_FPS := 12.0
const CELL := 64
## Texels from the cell centre down to the feet line (y = 51).
const FOOT_TEXELS := 19.0
## One enemy texel (Enemy.PIXEL).
const TEXEL := 1.0 / 15.0

var colour := Color("9fc8ff"):
	set(value):
		colour = value
		modulate = Color(value, OPACITY)
var size := 1.0
var cracked := false
var _time := 0.0
var _breaking := -1.0
static var _cells := {}

func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	shaded = false
	render_priority = 3
	offset = Vector2(0, FOOT_TEXELS)
	modulate = Color(colour, OPACITY)
	visible = false

## One cell of a strip.
static func cell(strip: Texture2D, index: int) -> AtlasTexture:
	var key := "%d|%d" % [strip.get_instance_id(), index]
	if not _cells.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(index * CELL, 0, CELL, CELL)
		atlas.filter_clip = true
		_cells[key] = atlas
	return _cells[key]

## Shows the shell standing on `feet` (the actor's local feet point).
func follow(feet: Vector3) -> void:
	if _breaking >= 0.0: return
	position = feet
	pixel_size = TEXEL * size
	if not visible:
		visible = true
		_time = 0.0
	texture = cell(CRACKED if cracked else SHELL, int(_time * LOOP_FPS) % 4)

## Hides it without the break (silenced, removed).
func hide_shell() -> void:
	if _breaking < 0.0: visible = false

## The shell breaks: the five-frame shatter, then it is gone.
func shatter() -> void:
	if not visible or _breaking >= 0.0: return
	_breaking = 0.0
	texture = cell(BREAK, 0)

func breaking() -> bool:
	return _breaking >= 0.0

func _process(delta: float) -> void:
	if not visible: return
	_time += delta
	if _breaking < 0.0:
		texture = cell(CRACKED if cracked else SHELL, int(_time * LOOP_FPS) % 4)
		return
	_breaking += delta
	var index := int(_breaking * BREAK_FPS)
	if index >= 5:
		_breaking = -1.0
		visible = false
		cracked = false
		return
	texture = cell(BREAK, index)
