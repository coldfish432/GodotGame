class_name GearSlots
extends RefCounted

## The eight gear slots' numbers (装备部位拆分与数值案_v1_0.md, 用户 2026-10-21).
## A full set gives what the old three pieces did: the five armour pieces
## share one armour's panel, the amulet and the ring one trinket's; affixes
## shrink by the slot so a full set's affixes also add up to today's.

const C := Item.Category

## Share of the old piece's panel (§3): armour HP/DEF, trinket ATK/arts.
const PANEL := {
	C.WEAPON: 1.0,
	C.CHEST: 0.32, C.LEGS: 0.22, C.HEAD: 0.18, C.HANDS: 0.14, C.FEET: 0.14,
	C.AMULET: 0.60, C.RING: 0.40,
	C.ARMOR: 1.0, C.TRINKET: 1.0,
}
## Affix and stat-prefix sizes × this (§4); everything but the weapon sums to
## 2.00, the old armour + trinket (用户 2026-10-21: 和现在持平).
const AFFIX := {
	C.WEAPON: 1.0,
	C.CHEST: 0.37, C.AMULET: 0.33, C.LEGS: 0.30, C.HEAD: 0.26, C.HANDS: 0.26, C.RING: 0.26, C.FEET: 0.22,
	C.ARMOR: 1.0, C.TRINKET: 1.0,
}
## Pack footprint (§3).
const SIZE := {
	C.WEAPON: Vector2i(2, 1), C.CHEST: Vector2i(2, 3), C.HEAD: Vector2i(2, 2), C.HANDS: Vector2i(2, 2),
	C.LEGS: Vector2i(2, 2), C.FEET: Vector2i(2, 2), C.AMULET: Vector2i(1, 1), C.RING: Vector2i(1, 1),
	C.ARMOR: Vector2i(2, 2), C.TRINKET: Vector2i(1, 1),
}
## Which slot a drop is (§6): the total drop rate is unchanged (用户 2026-10-21).
const DROP_WEIGHTS := {C.WEAPON: 3.0, C.CHEST: 1.0, C.LEGS: 1.0, C.HEAD: 1.0, C.HANDS: 1.0, C.FEET: 1.0, C.AMULET: 0.6, C.RING: 0.6}
## Prefixes with effects (fx) only on the big three (§5): eight pieces of
## triggers would pile up; stat prefixes go anywhere, scaled by AFFIX.
const FX_SLOTS := [C.WEAPON, C.CHEST, C.AMULET]
## Requirement column (§9).
const REQ_COLUMN := {C.CHEST: "heavy_armor", C.LEGS: "heavy_armor", C.HEAD: "light", C.HANDS: "light", C.FEET: "light", C.AMULET: "gear", C.RING: "gear"}

static func panel(category: int) -> float:
	return float(PANEL.get(category, 1.0))

static func affix(category: int) -> float:
	return float(AFFIX.get(category, 1.0))

static func size(category: int) -> Vector2i:
	return SIZE.get(category, Vector2i(1, 1))

static func fx_allowed(category: int) -> bool:
	return category in FX_SLOTS or category == C.ARMOR or category == C.TRINKET

## A slot for a drop of `group` (ARMOR picks one of the five, TRINKET the
## amulet or the ring), or any slot by DROP_WEIGHTS when `group` is −1.
static func roll(rng: RandomNumberGenerator, group: int = -1) -> int:
	var options: Array = []
	var weights: Array = []
	for slot in DROP_WEIGHTS:
		if group >= 0 and Item.group_of(slot) != group: continue
		options.append(slot)
		weights.append(DROP_WEIGHTS[slot])
	return int(options[LootTables._pick_weighted(weights, rng)])
