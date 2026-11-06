class_name DamageNumber
extends Label

## Floating combat numbers. With stats in the hundreds and thousands, the
## number is how the player reads defence, resistance and crits at all.
## Every hit, dealt or taken, is in its damage type's colour (用户 2026-11-02):
## white physical, violet arts, each element its own; a crit keeps its colour
## and comes larger with "!". Green healing, blue shield.
##
## They live in the UI layer, not the world SubViewport (PixelDisplay), so
## the text stays sharp; each frame the label is placed over its world point
## through GameManager.screen_point().

const COLORS := {"phys": Color("f2efe6"), "arts": Color("c79bff"), "true": Color("ffffff"),
	"heal": Color("7fe38f"), "shield": Color("8fd0ff"),
	"evade": Color("b8c4cc"),
	# 属性伤害与地区装备策划案 v1.1 §3.2: the elements, bleeding and 凋亡.
	"burn": Elements.COLORS.burn, "cold": Elements.COLORS.cold, "corr": Elements.COLORS.corr, "nerve": Elements.COLORS.nerve,
	"bleed": Elements.COLORS.bleed, "necro": Elements.COLORS.necro}
const LIFE := 0.8
var game: GameManager
var world_point := Vector3.ZERO
var _age := 0.0

static func spawn(owner_game: Node, at: Vector3, value: String, kind: String, big: bool = false) -> DamageNumber:
	var host := owner_game as GameManager
	if host == null or not host.is_inside_tree() or not is_instance_valid(host.number_layer): return null
	var label := DamageNumber.new()
	label.game = host
	label.text = value
	label.add_theme_font_size_override("font_size", 26 if big else 19)
	label.add_theme_color_override("font_color", COLORS.get(kind, Color.WHITE))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No spread: rapid hits on one target stack on the same spot, each its own number (用户 2026-11-02).
	label.world_point = at + Vector3(0, 1.4, 0)
	host.number_layer.add_child(label)
	label._place()
	return label

func _process(delta: float) -> void:
	_age += delta
	modulate.a = clampf(1.6 - _age / LIFE * 1.6, 0.0, 1.0)
	if _age >= LIFE or not is_instance_valid(game):
		queue_free()
		return
	_place()

func _place() -> void:
	var point := game.screen_point(world_point)
	var rise := 46.0 * (1.0 - pow(1.0 - minf(_age / LIFE, 1.0), 2.0))
	position = point + Vector2(-size.x * 0.5, -rise - size.y * 0.5)
