class_name ThreatMeter
extends RefCounted
## 威胁值 (用户 2026-10-14). It fills by itself while she is on a floor; a full
## meter sends a patrol onto the floor and starts again from empty. Each patrol
## on the same floor is stronger than the last, exponentially; a new floor
## starts the patrols over at their weakest and keeps 30% of what had not yet
## filled. A 萨卡兹哨兵 that sees her puts up its red "!" and the meter fills
## faster for as long as it shows; it runs to a reachable spot, holds there,
## and runs again when it next sees her. Shown as a bar only, never a number.
##   no gain: camps, near the Rhodes squad, menus that stop the field
##   gain:    near 坎诺特 and while shopping, the box window, everywhere else

const FULL := 100.0
## 2–3 patrols over a full clear of a floor (用户 2026-10-14): the meter's fill
## time is the floor's expected clear time over TARGET_WAVES; the carried 30%
## and any sentinels' "!" bring it toward 3. The clear time is estimated from
## the floor's enemies, at SECONDS_PER_ENEMY (tests/sim_clear_time.gd, bot runs
## that kill everything and search every point).
const TARGET_WAVES := 2.3
const SECONDS_PER_ENEMY := {"mine": 11.0, "city": 12.5, "snow": 14.5, "siracusa": 12.0}
## 叙拉古's 血债 is its own meter now (地图特色策划案 §4, 用户 2026-10-19: 血债和
## 警戒分开): the 威胁值 fills there as everywhere else.
const FILL_MIN := 150.0
## 255: the snow fields as the other regions (用户 2026-10-14: 雪原也改为150–255 秒).
const FILL_MAX := 255.0
## Share of the unfilled meter kept on reaching the next floor.
const CARRY := 0.3
const SQUAD_CALM_RADIUS := 8.0
## PRTS says the Doctor is being tracked once the meter passes this (博士主角叙事修订案 §4).
const TRACKED_AT := 0.75

## 萨卡兹哨兵 (用户 2026-10-14): seen her -> red "!" and the meter fills faster ->
## it runs to a reachable spot -> stands there SENTINEL_HOLD s, not running ->
## then, if it sees her again, another spot; and so on until it is killed.
## Each sentinel showing its "!" adds SENTINEL_BOOST x the floor's own rate.
const SENTINEL_BOOST := 1.0
## Share of floors with a sentinel; never more than one on a floor.
const SENTINEL_CHANCE := 0.1
const SENTINEL_HOLD := 8.0
## On seeing her it starts and turns to her this long before it runs.
const SENTINEL_STARTLE := 0.5
## Its next spot: walkable, reachable on the navmesh, this far from where it
## stood, as far from her as it can find.
const SENTINEL_RUN_MIN := 8.0
const SENTINEL_RUN_MAX := 16.0

## A patrol: PATROL_SIZE enemies, one an elite from wave PATROL_ELITE_FROM on.
const PATROL_SIZE := 3
const PATROL_ELITE_FROM := 3
## Over the floor's own ordinary enemies, then ×PATROL_GROWTH every wave after.
const PATROL_HP := 1.5
const PATROL_ATK := 1.25
const PATROL_GROWTH := 1.35
## Where it enters: this far from her along the main path.
const SPAWN_MIN := 16.0
const SPAWN_MAX := 32.0

## Patrols drop no ordinary loot: only, rarely, one rare piece of this region's
## gear at the floor's grade. Elites twice as likely.
const RARE_CHANCE := 0.03
const RARE_CHANCE_PER_WAVE := 0.01
const RARE_CHANCE_MAX := 0.10

var value := 0.0
## Seconds this floor takes to fill the meter from empty (plan_floor).
var fill_seconds := 200.0
## Patrols sent onto this floor so far.
var wave := 0

func reset() -> void:
	value = 0.0
	wave = 0

## Next floor: patrols start again from the first, 30% of the meter stays.
func next_floor() -> void:
	value *= CARRY
	wave = 0

## Sets this floor's fill time from its enemies at the start.
func plan_floor(region: String, enemies: int) -> void:
	fill_seconds = clampf(enemies * float(SECONDS_PER_ENEMY.get(region, 12.0)) / TARGET_WAVES, FILL_MIN, FILL_MAX)

func per_second() -> float:
	return FULL / fill_seconds

## Adds `amount`; true when that fills it (the meter is then empty again).
func add(amount: float) -> bool:
	value += amount
	if value < FULL: return false
	value = 0.0
	return true

func ratio() -> float:
	return clampf(value / FULL, 0.0, 1.0)

## The life and attack multiplier of patrol wave `w` (1 is the first).
static func strength(w: int) -> Vector2:
	var grow := pow(PATROL_GROWTH, maxi(w, 1) - 1)
	return Vector2(PATROL_HP * grow, PATROL_ATK * grow)

static func rare_chance(w: int, elite: bool) -> float:
	var chance := minf(RARE_CHANCE_MAX, RARE_CHANCE + RARE_CHANCE_PER_WAVE * (maxi(w, 1) - 1))
	return chance * (2.0 if elite else 1.0)
