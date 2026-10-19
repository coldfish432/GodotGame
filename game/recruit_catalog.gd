class_name RecruitCatalog
extends RefCounted

## 干员寻访 (干员寻访策划案_v0_1.md §2, §9; R1). Every operator but Amiya is
## found in one region: her traces (踪迹) turn up there, and once enough are in,
## the dispatch desk offers that region a 寻访合同 for her. On its floor she
## waits at a 寻访点 with a guard round her; clear it, speak to her (E) and
## extract, and she joins the roster.

## Traces needed before her contract is offered (§13, 用户 2026-10-17: 更慢).
const CLUES_NEEDED := 6
## A floor of her region leaves a trace on this share of floors at the depth
## that suits the operator she is looking with (§13: 不是每层必刷)...
const TRACE_CHANCE := 0.2
## ...and less on floors shallower than that, by this much a floor (用户:
## 随着玩家升级低层更不容易出现), never below TRACE_FLOOR of it.
const TRACE_DECAY := 0.8
const TRACE_FLOOR := 0.1
## Levels a floor of suited depth is worth (精英 0 · Lv1 suits the first floor).
const LEVELS_PER_FLOOR := 3
## Her floor: this many past the contract's start (§2.2: 起点 +4 到 +6).
const FLOOR_OFFSET := Vector2i(4, 6)
## The guard round her: a squad led by an elite.
const GUARDS := 3

## id -> region, and the line PRTS says when her first trace turns up. The
## places follow §4 and the 叙拉古 plan §8 (萨卢佐宅邸 / 罗塞蒂家族).
const RECRUITS := {
	"hellagur": {"region": "mine", "place": "阿撒兹勒诊所的废墟"},
	"rosa": {"region": "mine", "place": "切城中学的残楼"},
	"hoshiguma": {"region": "city", "place": "近卫局的封锁线"},
	"lin": {"region": "city", "place": "下城区的一处茶馆"},
	"typhon": {"region": "snow", "place": "林线深处的猎人营地"},
	"santalla": {"region": "snow", "place": "冻土上的部族祭场"},
	"texas": {"region": "siracusa", "place": "罗塞蒂家族的旧宅"},
	"lappland": {"region": "siracusa", "place": "萨卢佐家族的宅邸"},
}

static func region_of(id: String) -> String:
	return str(RECRUITS.get(id, {}).get("region", ""))

## The operators found in `region`, in RECRUITS order.
static func in_region(region: String) -> Array[String]:
	var out: Array[String] = []
	for id in RECRUITS:
		if RECRUITS[id].region == region: out.append(id)
	return out

## Her floor's distance past the contract's start, fixed per operator so the
## card shows the same floor every time it is offered.
static func floor_offset(id: String) -> int:
	return FLOOR_OFFSET.x + absi(hash(id)) % (FLOOR_OFFSET.y - FLOOR_OFFSET.x + 1)

## The floor an operator at `elite` / `level` is suited to.
static func suited_floor(elite: int, level: int) -> int:
	var total := level
	for stage in range(mini(elite, Progression.LEVEL_CAPS.size())): total += int(Progression.LEVEL_CAPS[stage])
	return 1 + (total - 1) / LEVELS_PER_FLOOR

## The chance a trace is on `floor_number` for an operator suited to `suited`.
static func trace_chance(floor_number: int, suited: int) -> float:
	return TRACE_CHANCE * maxf(TRACE_FLOOR, pow(TRACE_DECAY, maxi(0, suited - floor_number)))

## Each operator leaves the same few traces over and over (用户 2026-10-17: 会发现
## 重复的踪迹，重复的小踪迹不加，大踪迹减半): four small ones worth SMALL_VALUE
## the first time and nothing after, two big ones worth BIG_VALUE the first
## time and half that after. A trace on the floor is big BIG_SHARE of the time.
const TRACE_SMALL: Array[String] = ["s1", "s2", "s3", "s4"]
const TRACE_BIG: Array[String] = ["b1", "b2"]
const SMALL_VALUE := 1
const BIG_VALUE := 2
const BIG_SHARE := 0.25

static func is_big(key: String) -> bool:
	return key in TRACE_BIG

## What finding trace `key` is worth, given whether it was found before.
static func trace_value(key: String, found_before: bool) -> int:
	if is_big(key): return BIG_VALUE / 2 if found_before else BIG_VALUE
	return 0 if found_before else SMALL_VALUE

static func contract_for(id: String) -> Dictionary:
	return {"type": "recruit", "operator": id, "offset": floor_offset(id)}
