class_name Fuel
extends RefCounted

## 燃料储备修订案 v0.6 (用户 2026-11-17). Fuel is a count of units, not an item:
## it sits in 燃料罐 (0–60 each, the can stays when empty) and in the 罗德岛燃料储备
## (RhodesFinance.fuel_reserve: in only, never out). 固体燃料 is fuel pressed into
## blocks of 12 units, made at the 加工部. The exchange trades it by the 燃料桶
## (480 units), which is never an item: bought barrels go into the reserve, sold
## ones come out of the warehouse's cans. One unit burns 10 s and is worth 2/3
## everywhere; the can itself is only a container and an upgrade material.

const TANK := "燃料罐"
const SOLID := "固体燃料"
const BARREL := "燃料桶"
## The old trade pack: a save's 燃料包 becomes OLD_PACK_UNITS in the reserve.
const OLD_PACK := "燃料包"
## The 罗德岛燃料储备's key in RhodesFinance.stock, and what the bill calls it.
const RESERVE := "燃料"

const TANK_FULL := 60
const SOLID_UNITS := 12
const BARREL_UNITS := 480
const OLD_PACK_UNITS := 150
## Value of one unit (Item.value units) and of the empty can.
const UNIT_VALUE := 2.0 / 3.0
const TANK_SHELL := 10
## Seconds one unit keeps a fire going (固体燃料 120 s = 12 units).
const SECONDS_PER_UNIT := 10.0
## The 加工部's recipe: units of fuel per 固体燃料 (no loss, §0.6).
const SOLID_RECIPE_UNITS := 12

static func unit_lmd() -> float:
	return UNIT_VALUE * Economy.LMD_PER_VALUE

static func is_tank(item: Item) -> bool:
	return item != null and item.material_id == TANK

static func is_solid(item: Item) -> bool:
	return item != null and item.material_id == SOLID

## Whether it can be poured into a can or the reserve.
static func is_fuel(item: Item) -> bool:
	return is_tank(item) or is_solid(item)

## Units of fuel it holds.
static func units_of(item: Item) -> int:
	if is_tank(item): return maxi(0, item.fuel)
	if is_solid(item): return item.quantity * SOLID_UNITS
	return 0

static func is_full(item: Item) -> bool:
	return is_tank(item) and item.fuel >= TANK_FULL

static func room_in(tank: Item) -> int:
	return maxi(0, TANK_FULL - tank.fuel) if is_tank(tank) else 0

static func tank_value(units: int) -> int:
	return roundi(TANK_SHELL + clampi(units, 0, TANK_FULL) * UNIT_VALUE)

## Fills a can to `units` and prices it by what it holds.
static func set_fill(tank: Item, units: int) -> void:
	tank.fuel = clampi(units, 0, TANK_FULL)
	tank.unit_value = tank_value(tank.fuel)
	tank.set_quantity(1)

## For a cost or a count, a can counts as one 燃料罐 only when full (§0.1 #7).
static func counts_as(item: Item, id: String) -> bool:
	if item.material_id != id: return false
	return not is_tank(item) or is_full(item)

## " 36/60" after a can's name.
static func suffix(item: Item) -> String:
	return " %d/%d" % [item.fuel, TANK_FULL] if is_tank(item) else ""

## How much of `source` would go into `tank` now (units).
static func pour_amount(source: Item, tank: Item) -> int:
	if not is_tank(tank) or source == tank or not is_fuel(source): return 0
	var room := room_in(tank)
	if is_tank(source): return mini(room, source.fuel)
	return mini(source.quantity, room / SOLID_UNITS) * SOLID_UNITS

## Pours `source` into `tank`: a can gives what fits, 固体燃料 whole blocks.
## Returns the units moved; a 固体燃料 stack left at 0 is for the caller to remove.
static func pour(source: Item, tank: Item) -> int:
	var moved := pour_amount(source, tank)
	if moved <= 0: return 0
	if is_tank(source): set_fill(source, source.fuel - moved)
	else: source.set_quantity(source.quantity - moved / SOLID_UNITS)
	set_fill(tank, tank.fuel + moved)
	return moved

## A can found in the field: anything from empty to full (§3).
static func field_fill(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, TANK_FULL)
