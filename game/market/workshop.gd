class_name Workshop
extends RefCounted

## 加工部 (势力与交易所策划案_v0_7.md §2): the PRTS 加工站 recipes
## (掉落物调研_PRTS道具.md §2.1, costs from 罗德岛基建/加工站), byproducts, and
## packing loose supplies into trade goods. Jobs run on real time and finish
## while the game is shut; finished goods go to staging. The queue shows only
## 进行中 / 完成 (no time left, 用户 rule for queues outside the exchange).

## PRTS: T1→T2 100, T2→T3 200, T3→T4 300 龙门币; the carbon line 800 / 2400.
## "minutes" per unit made.
const RECIPES := {
	"固源岩": {"in": {"源岩": 3}, "lmd": 100, "minutes": 2, "tier": 2},
	"固源岩组": {"in": {"固源岩": 5}, "lmd": 200, "minutes": 5, "tier": 3},
	"提纯源岩": {"in": {"固源岩组": 4}, "lmd": 300, "minutes": 15, "tier": 4},
	"糖": {"in": {"代糖": 3}, "lmd": 100, "minutes": 2, "tier": 2},
	"聚酸酯": {"in": {"酯原料": 3}, "lmd": 100, "minutes": 2, "tier": 2},
	"异铁": {"in": {"异铁碎片": 3}, "lmd": 100, "minutes": 2, "tier": 2},
	"异铁组": {"in": {"异铁": 4}, "lmd": 200, "minutes": 5, "tier": 3},
	"酮凝集": {"in": {"双酮": 3}, "lmd": 100, "minutes": 2, "tier": 2},
	"装置": {"in": {"破损装置": 3}, "lmd": 100, "minutes": 2, "tier": 2},
	"全新装置": {"in": {"装置": 4}, "lmd": 200, "minutes": 5, "tier": 3},
	"改量装置": {"in": {"全新装置": 1, "固源岩组": 2, "研磨石": 1}, "lmd": 300, "minutes": 15, "tier": 4},
	"碳素": {"in": {"碳": 3}, "lmd": 800, "minutes": 3, "tier": 3, "build": true},
	"碳素组": {"in": {"碳素": 3}, "lmd": 2400, "minutes": 8, "tier": 4, "build": true},
}
## Trade goods (§2.2): loose supplies packed into one crate.
const PACKS := {
	"工业补给箱": {"in": {"螺栓": 12, "金属板": 6, "胶带": 2}, "lmd": 0, "minutes": 1},
	"电子元件箱": {"in": {"电线": 8, "灯泡": 4, "继电器": 2}, "lmd": 0, "minutes": 1},
	"野外生活包": {"in": {"帆布": 4, "固体燃料": 6, "胶带": 3}, "lmd": 0, "minutes": 1},
	"医疗补给箱": {"in": {"医用耗材包": 3, "糖": 4, "胶带": 2}, "lmd": 0, "minutes": 1},
}
## Rhodes standard gear (装备策划案 §10.3, 用户 2026-10-18: 加工部可制作):
## output name -> base, materials, 龙门币, minutes per piece. Each comes out a
## fresh 精良 piece (GearCatalog.make_rhodes).
const GEAR := {
	"罗德岛制式双刀": {"base": "rhodes_dual_blades", "in": {"装置": 2, "异铁": 2, "研磨石": 1}, "lmd": 1500, "minutes": 30},
	"罗德岛制式剑": {"base": "rhodes_sword", "in": {"装置": 2, "异铁组": 1, "研磨石": 1}, "lmd": 1500, "minutes": 30},
	"罗德岛制式弩": {"base": "rhodes_crossbow", "in": {"装置": 2, "聚酸酯": 2, "研磨石": 1}, "lmd": 1500, "minutes": 30},
	"罗德岛制式法杖": {"base": "rhodes_staff", "in": {"晶体元件": 1, "异铁": 2, "装置": 1}, "lmd": 1500, "minutes": 30},
	"罗德岛外勤制服": {"base": "rhodes_uniform", "in": {"聚酸酯": 2, "帆布": 2}, "lmd": 1000, "minutes": 20},
	"罗德岛制式防护背心": {"base": "rhodes_vest", "in": {"全新装置": 1, "聚酸酯": 2, "金属板": 2}, "lmd": 1400, "minutes": 30},
	"罗德岛制式信标": {"base": "rhodes_beacon", "in": {"电路板": 1, "蓄电池": 1, "晶体元件": 1}, "lmd": 1000, "minutes": 20},
	"罗德岛制式急救包": {"base": "rhodes_medkit", "in": {"医用耗材包": 2, "糖": 2}, "lmd": 800, "minutes": 15},
	"罗德岛干员证章": {"base": "rhodes_badge", "in": {"赤金": 1}, "lmd": 1200, "minutes": 20},
}
## The six T1 materials a byproduct is drawn from (PRTS 加工站).
const BYPRODUCTS := ["源岩", "代糖", "酯原料", "异铁碎片", "双酮", "破损装置"]
const BYPRODUCT_CHANCE := 0.10
const BYPRODUCT_BUILD_CHANCE := 0.10
## Queue slots: one, two from 加工部 Lv2.
const SLOTS_LEVEL := 2

var jobs: Array = []   # {id, output, count, due, byproducts}
var _next_id := 1

static func recipe(output: String) -> Dictionary:
	return RECIPES.get(output, PACKS.get(output, GEAR.get(output, {})))

static func cost_of(output: String, count: int) -> Dictionary:
	var out := {}
	var r := recipe(output)
	for id in r.get("in", {}): out[id] = int(r["in"][id]) * count
	return out

static func slots(level: int) -> int:
	return 2 if level >= SLOTS_LEVEL else 1

func busy() -> int:
	return jobs.size()

## Starts `count` of `output` (materials are taken by the caller). The queue
## runs jobs one after another per slot, so a new job starts after the last.
## `time_factor` shortens the job (科研部: 后勤部Ⅳ, the endless 加工时长 line).
func start(output: String, count: int, now: int, rng: RandomNumberGenerator, time_factor := 1.0) -> Dictionary:
	var r := recipe(output)
	var job := {"id": _next_id, "output": output, "count": count, "due": now + maxi(60, roundi(int(r.minutes) * 60 * count * time_factor)), "byproducts": {}}
	_next_id += 1
	if RECIPES.has(output):
		var chance := BYPRODUCT_BUILD_CHANCE if r.get("build", false) else BYPRODUCT_CHANCE
		for k in range(count):
			if rng.randf() < chance:
				var by: String = BYPRODUCTS[rng.randi() % BYPRODUCTS.size()]
				job.byproducts[by] = int(job.byproducts.get(by, 0)) + 1
	jobs.append(job)
	return job

## Jobs finished by `now`, removed from the queue.
func finished(now: int) -> Array:
	var done: Array = []
	for j in jobs.duplicate():
		if int(j.due) <= now:
			jobs.erase(j)
			done.append(j)
	return done

func to_data() -> Dictionary:
	return {"jobs": jobs, "next_id": _next_id}

func load_data(d: Dictionary) -> void:
	jobs = d.get("jobs", [])
	_next_id = int(d.get("next_id", 1))
