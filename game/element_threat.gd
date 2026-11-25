class_name ElementThreat
extends RefCounted

## 抗性为王修订案 v0.4 (用户 2026-11-25: 全部按默认): the deeper, the more
## enemies hit with elements. Each enemy rolls once when it is spawned;
## an armed one carries a spec its hits read (PlayerElements.mitigate):
##   mode   "convert" (打的是: a share of each hit is elemental, the total
##          unchanged) or "add" (附带: elemental damage on top)
##   kinds  the elements, one to three; each hit carries all of them
## Pure data and arithmetic; Enemy keeps the spec, GameManager rolls it.

# --- §3.1 the roll ------------------------------------------------------------------

const CHANCE_BASE := 0.10
const CHANCE_STEP := 0.0065
const CHANCE_MAX := 0.75
const ELITE_BONUS := 0.20
const ELITE_MAX := 0.95
## 深部污染 and the other nodes that strengthen enemies ("stat" > 1).
const NODE_BONUS := 0.10

static func chance(floor_number: int, elite: bool, strong_node: bool = false) -> float:
	var c := minf(CHANCE_MAX, CHANCE_BASE + CHANCE_STEP * float(maxi(0, floor_number - 1)))
	if elite: c = minf(ELITE_MAX, c + ELITE_BONUS)
	if strong_node: c += NODE_BONUS
	return clampf(c, 0.0, 1.0)

# --- §3.2 the two ways and the shares ----------------------------------------------------

const CONVERT_ODDS := 0.60
## Floor 1 → floor 101 and on, linear.
const CONVERT_SHARE := [0.40, 0.70]
const ADD_SHARE := [0.15, 0.32]
const SHARE_FLOORS := 100.0

static func _ramp(pair: Array, floor_number: int) -> float:
	var t := clampf(float(floor_number - 1) / SHARE_FLOORS, 0.0, 1.0)
	return lerpf(float(pair[0]), float(pair[1]), t)

static func convert_share(floor_number: int) -> float: return _ramp(CONVERT_SHARE, floor_number)

## 打的是's elemental part, over what its own kind would have let through: 1 at
## the base cap (80, §8 第 9 题), rising CONVERT_SLOPE per 80 points under it.
## (1 − res) ÷ 0.2 would be a slope of 4 — ×5 at 0; 用户 2026-11-25 "先降一档": 2.
const CONVERT_SLOPE := 2.0
static func convert_taken(resistance: float) -> float:
	return clampf(1.0 + (Elements.RES_CAP - maxf(resistance, Elements.RES_MIN)) / Elements.RES_CAP * CONVERT_SLOPE, 0.5, 1.0 + 130.0 / 80.0 * CONVERT_SLOPE)
static func add_share(floor_number: int) -> float: return _ramp(ADD_SHARE, floor_number)

## One main, the rest after it: the region's own 45, the one that beats the
## region (Elements.WEAKNESS) 25, the other two 15 each.
const LOCAL_WEIGHT := 45.0
const WEAK_WEIGHT := 25.0
const OTHER_WEIGHT := 15.0
## §3.4 元素异变: the node's element +30 points, then all scaled back to 100.
const SURGE_POINTS := 30.0

static func weights(region: String, surge: String = "") -> Dictionary:
	var out := {}
	for kind in Elements.KINDS:
		var w := OTHER_WEIGHT
		if Elements.LOCAL.get(region, "") == kind: w = LOCAL_WEIGHT
		elif Elements.WEAKNESS.get(region, "") == kind: w = WEAK_WEIGHT
		out[kind] = w
	if Elements.is_element(surge): out[surge] = float(out[surge]) + SURGE_POINTS
	var total := 0.0
	for kind in out: total += float(out[kind])
	for kind in out: out[kind] = float(out[kind]) / total
	return out

static func pick_kind(region: String, surge: String, rng: RandomNumberGenerator, not_these: Array = []) -> String:
	var w := weights(region, surge)
	var total := 0.0
	for kind in w: if not kind in not_these: total += float(w[kind])
	if total <= 0.0: return str(Elements.LOCAL.get(region, "burn"))
	var roll := rng.randf() * total
	for kind in Elements.KINDS:
		if kind in not_these: continue
		roll -= float(w[kind])
		if roll <= 0.0: return kind
	for kind in Elements.KINDS:
		if not kind in not_these: return kind
	return "burn"

# --- §3.3 elites and bosses --------------------------------------------------------------

## Elites carry two elements from here on, both on every hit.
const ELITE_DUAL_FROM := 51
## Bosses and wardens add an element at a new phase from their third showing.
const BOSS_ADD_TIER := 3

## The spec an ordinary or elite enemy rolls ({} when it carries none).
static func roll(floor_number: int, region: String, elite: bool, surge: String, strong_node: bool, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= chance(floor_number, elite, strong_node): return {}
	var mode := "convert" if rng.randf() < CONVERT_ODDS else "add"
	var kinds: Array = [pick_kind(region, surge, rng)]
	if elite and floor_number >= ELITE_DUAL_FROM: kinds.append(pick_kind(region, surge, rng, kinds))
	return {"mode": mode, "kinds": kinds}

## A boss or warden: always its region's element, added to every hit.
static func boss_spec(region: String) -> Dictionary:
	return {"mode": "add", "kinds": [str(Elements.LOCAL.get(region, "burn"))], "boss": true}

## What a boss adds on entering `phase` (2 or 3) at `tier` ("" for nothing):
## phase 2 the element that beats its region, phase 3 one of the other two.
static func boss_phase_kind(region: String, tier: int, phase: int, have: Array, rng: RandomNumberGenerator) -> String:
	if tier < BOSS_ADD_TIER or phase < 2: return ""
	if phase == 2:
		var weak := str(Elements.WEAKNESS.get(region, ""))
		return weak if Elements.is_element(weak) and not weak in have else ""
	var rest: Array = Elements.KINDS.filter(func(k): return not k in have)
	return "" if rest.is_empty() else str(rest[rng.randi() % rest.size()])

# --- §3.5 big hits: not to be taken without the resistance ------------------------------------

## A big hit is 80% its elements (split evenly), 20% its own kind.
const BIG_ELEMENT := 0.80
## Its raw damage is at least this share of the life she should have on the
## floor (封顶 80 → ~30% of it, 0 → ~100%); shallow floors ramp up to it.
const BIG_HP_SHARE := 1.07
## 用户 2026-11-25 (after tests/_probe_resist.gd): full from 81, with 高级 inlays (was 51).
const BIG_RAMP := [0.50, 81]
## The life a full build has on a floor (tests/_probe_balance.gd, four regions'
## mean, 2026-11-25): [floor, life], linear between, flat past the last.
const REF_LIFE := [[1, 3400.0], [12, 4470.0], [32, 4900.0], [52, 6400.0], [72, 8710.0], [92, 8590.0]]

static func ref_life(floor_number: int) -> float:
	if floor_number <= int(REF_LIFE[0][0]): return float(REF_LIFE[0][1])
	for i in range(1, REF_LIFE.size()):
		var a: Array = REF_LIFE[i - 1]
		var b: Array = REF_LIFE[i]
		if floor_number <= int(b[0]):
			return lerpf(float(a[1]), float(b[1]), float(floor_number - int(a[0])) / float(int(b[0]) - int(a[0])))
	return float(REF_LIFE.back()[1])

static func big_share(floor_number: int) -> float:
	var t := clampf(float(floor_number - 1) / float(int(BIG_RAMP[1]) - 1), 0.0, 1.0)
	return lerpf(float(BIG_RAMP[0]), BIG_HP_SHARE, t)

## The least a big hit deals on this floor before any mitigation.
static func big_floor(floor_number: int) -> float:
	return big_share(floor_number) * ref_life(floor_number)

# --- §6 shredding her resistance ------------------------------------------------------------

const SHRED := 15.0
const SHRED_STACKS := 2
const SHRED_SECONDS := 6.0
## Her weapon's 减抗 line on an enemy: one at a time, this long.
const ENEMY_SHRED_SECONDS := 4.0

# --- §3.4 元素异变 on the route map ---------------------------------------------------------

const SURGE_NODES := 3

## Marks SURGE_NODES fight nodes of the map with an element not the region's own.
static func mark_surges(map: Dictionary, region: String, rng: RandomNumberGenerator) -> void:
	var cols: Array = map.get("cols", [])
	var spots: Array = []
	for c in range(cols.size() - 1):
		for r in range((cols[c] as Array).size()):
			var node: Dictionary = cols[c][r]
			if RouteMap.is_fight(str(node.get("kind", ""))) and not bool(node.get("exit", false)): spots.append(Vector2i(c, r))
	var others: Array = Elements.KINDS.filter(func(k): return k != Elements.LOCAL.get(region, ""))
	for i in range(mini(SURGE_NODES, spots.size())):
		var at: Vector2i = spots.pop_at(rng.randi() % spots.size())
		cols[at.x][at.y]["surge"] = str(others[rng.randi() % others.size()])
