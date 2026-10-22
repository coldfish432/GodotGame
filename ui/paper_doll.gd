class_name PaperDoll
extends RefCounted

## The 8-slot paper doll laid out like Grim Dawn's (界面美术与布局策划案 v2 §4.1,
## 装备部位拆分与数值案): weapon / chest / legs down the left in tall slots,
## the head at the top centre with the amulet at its upper right and the ring
## at its lower left, hands and feet down the right; the standing portrait in
## the middle. Grim Dawn's off-hand place shows the operator's signature skill;
## its weapon-swap place the elite badge. A 392 × 418 block.

const SIZE := Vector2(392, 418)
const SPOTS := {
	Item.Category.WEAPON: Rect2(12, 8, 88, 112),
	Item.Category.CHEST: Rect2(12, 128, 88, 136),
	Item.Category.LEGS: Rect2(12, 272, 88, 112),
	Item.Category.HEAD: Rect2(156, 8, 80, 80),
	Item.Category.AMULET: Rect2(240, 8, 40, 40),
	Item.Category.RING: Rect2(112, 52, 40, 40),
	Item.Category.HANDS: Rect2(292, 128, 88, 112),
	Item.Category.FEET: Rect2(292, 272, 88, 112),
}
const BADGE := Rect2(112, 8, 40, 40)
const SKILL := Rect2(292, 8, 88, 112)
const PORTRAIT := Rect2(136, 100, 120, 240)
const FOOT := Rect2(104, 388, 184, 28)
const SILHOUETTES := {
	Item.Category.WEAPON: "weapon", Item.Category.HEAD: "head", Item.Category.CHEST: "chest", Item.Category.HANDS: "hands",
	Item.Category.LEGS: "legs", Item.Category.FEET: "feet", Item.Category.AMULET: "amulet", Item.Category.RING: "ring",
}

static var _silhouettes := {}

## What she wears in `slot`; an old save's ARMOR / TRINKET piece shows as the chest / amulet.
static func worn(game: GameManager, slot: int) -> Item:
	var item: Item = game.player.equipped.get(slot)
	if item != null: return item
	if slot == Item.Category.CHEST: return game.player.equipped.get(Item.Category.ARMOR)
	if slot == Item.Category.AMULET: return game.player.equipped.get(Item.Category.TRINKET)
	return null

## Does `item` go in `slot` (old ARMOR / TRINKET pieces in the chest / amulet)?
static func fits(item: Item, slot: int) -> bool:
	return item != null and Item.slot_of(item.category) == slot

static func silhouette(slot: int) -> Texture2D:
	var name: String = SILHOUETTES.get(slot, "")
	if name.is_empty(): return null
	if not _silhouettes.has(name): _silhouettes[name] = load("res://art/ui/kit/sil_%s.png" % name)
	return _silhouettes[name]

## Draws an empty slot's part silhouette, centred, faint (v2 §1.7).
static func draw_silhouette(canvas: CanvasItem, slot: int, size: Vector2) -> void:
	var tex := silhouette(slot)
	if tex == null: return
	var side := 48.0 if minf(size.x, size.y) >= 60.0 else 32.0
	canvas.draw_texture_rect(tex, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), false, Color(1, 1, 1, 0.3))

## The weapon is drawn standing in its tall slot, like Grim Dawn's main hand.
static func draw_item(canvas: CanvasItem, item: Item, slot: int, size: Vector2) -> void:
	if slot == Item.Category.WEAPON and size.y > size.x and item.width > item.height:
		canvas.draw_set_transform(size * 0.5, -PI / 2.0, Vector2.ONE)
		ItemIcons.draw(canvas, item, Rect2(Vector2(-size.y, -size.x) * 0.5, Vector2(size.y, size.x)))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ItemIcons.draw(canvas, item, Rect2(Vector2.ZERO, size))

## The fixed pieces around the slots: the standing portrait, the elite badge
## and the signature-skill card. `scale` shrinks the whole block.
static func decorate(game: GameManager, parent: Control, at: Vector2, scale: float = 1.0) -> void:
	var id := game.player.operator_id
	var art := OperatorScreen.standing(id)
	if art != null:
		var image := TextureRect.new()
		image.texture = art
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		AK.put(parent, image, at + PORTRAIT.position * scale, PORTRAIT.size * scale)
	# A floor shadow under her (no hologram, 用户 2026-10-21).
	var shadow := Shadow.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(parent, shadow, at + Vector2(PORTRAIT.position.x - 10, PORTRAIT.end.y - 12) * scale, Vector2(PORTRAIT.size.x + 20, 20) * scale)
	var p: OperatorProgress = game.progress()
	var badge := AK.label("E%d" % p.elite, int(14 * scale), AK.SP, AK.en())
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", AK.box(Color("1c1a12"), Color("6b5418"), 1))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(parent, badge, at + BADGE.position * scale, BADGE.size * scale)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", AK.box(Color("191710"), Color("7a6320"), 1, 6))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var diamond := Diamond.new()
	diamond.custom_minimum_size = Vector2(32, 32) * scale
	diamond.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(diamond)
	var skill := AK.label(signature_name(id), int(12 * scale), AK.FG)
	skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(skill)
	card.add_child(column)
	AK.put(parent, card, at + SKILL.position * scale, SKILL.size * scale)
	card.tooltip_text = signature_name(id)

## The operator's signature skill (her skill tree's 招牌 node), for the doll's skill card.
static func signature_name(id: String) -> String:
	var tree := SkillTrees.tree(id)
	for node_id in tree:
		if str(tree[node_id].type) == "signature": return str(tree[node_id].name)
	return ""


class Shadow extends Control:
	func _draw() -> void:
		var c := size * 0.5
		for i in range(6):
			var k := 1.0 - i / 6.0
			draw_set_transform(c, 0.0, Vector2(1.0, size.y / size.x))
			draw_circle(Vector2.ZERO, size.x * 0.5 * k, Color(0, 0, 0, 0.08))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class Diamond extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_colored_polygon(AK.diamond(c, r), AK.SP)
		draw_colored_polygon(AK.diamond(c, r * 0.45), Color("191710"))
