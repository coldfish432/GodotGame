class_name AttackCursor
## The game's only two pointers (用户 2026-10-21: 鼠标样式改为 prts 的骨架手，左键
## 攻击敌人时换为剑样式，游戏内只允许出现这两个样式): the PRTS skeleton hand
## everywhere, the sword while the pointer is on an enemy's hit box. Every
## cursor shape (text beam, drag, busy…) is set to the same image, so the
## system's own never shows.
const HAND := "res://ui/art/cursor_hand.png"
const ART := "res://ui/art/cursor_attack.png"
## The hand is Akitum10 (アキタム)'s PRTS pointer, the "normal" one of the pack
## (用户 2026-10-21 downloaded it), its 64 px entry cropped and scaled to 32 px;
## the hotspot is the tip of its spike.
const HAND_HOTSPOT := Vector2(1, 1)
const HOTSPOT := Vector2(1, 1)
const SHAPES := 17   # Input.CursorShape: CURSOR_ARROW … CURSOR_HELP

static var _textures := {}
static var _attack := -1

static func texture(path: String = ART) -> Texture2D:
	if not _textures.has(path): _textures[path] = load(path)
	return _textures[path]

## The sword when `attack`, else the hand, for every cursor shape.
static func apply(attack: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	if _attack == int(attack): return
	_attack = int(attack)
	var art := texture(ART if attack else HAND)
	var spot := HOTSPOT if attack else HAND_HOTSPOT
	for shape in range(SHAPES): Input.set_custom_mouse_cursor(art, shape, spot)

## The system's pointers again, at quit: Input keeps the image otherwise and
## frees it after the renderer (GameManager.release_static_caches).
static func release() -> void:
	if DisplayServer.get_name() == "headless": return
	for shape in range(SHAPES): Input.set_custom_mouse_cursor(null, shape)
	_attack = -1
