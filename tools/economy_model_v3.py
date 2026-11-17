"""龙门币经济模型 v3（用户 2026-11-13：重跑收入探针）.

Same play assumptions and spending as economy_model_v2.py (imported, not copied);
only what a floor holds is new, from tests/_probe_income.gd run on the code as it
stands (4 regions × 3 seeds × floors 5/25/45/65/85, every enemy's and point's loot
rolled 20×, priced with Economy.price). Two changes in how a run is counted:
  - materials stack over the whole run (each kind's total quantity, ceil by its
    stack), not floor by floor;
  - gear is split by slot, each slot its own value per cell, and the pack takes
    the densest first (so v2's PICK_BONUS is not applied on top).
'other' (collectibles, cases, flasks) is reported but not sold for 龙门币.

    PYTHONIOENCODING=utf-8 python tools/economy_model_v3.py <probe dir with *.log>
"""
import collections, glob, json, math, os, sys

sys.path.insert(0, os.path.dirname(__file__))
import economy_model_v2 as v2

DEPTHS = [5, 25, 45, 65, 85]

def load(probe_dir):
    rows = collections.defaultdict(list)
    for f in glob.glob(os.path.join(probe_dir, "*.log")):
        for line in open(f, encoding="utf-8", errors="replace"):
            if line.startswith("PROBE "):
                r = json.loads(line[6:]); rows[(r["region"], r["depth"])].append(r)
    floor = {}
    for (region, depth), xs in rows.items():
        n = len(xs)
        mats = collections.defaultdict(lambda: [0.0, 1, 0.0])
        slots = collections.defaultdict(lambda: [0.0, 0.0])
        for x in xs:
            for m, (q, stack, unit) in x["mats"].items():
                mats[m][0] += q / n; mats[m][1] = stack; mats[m][2] = unit
            for s, v in x["slots"].items():
                slots[s][0] += v[0] / n; slots[s][1] += v[1] / n
        floor.setdefault(region, {})[depth] = dict(
            pois=sum(x["pois"] for x in xs) / n, enemies=sum(x["enemies"] for x in xs) / n,
            bars=sum(x["bars"] for x in xs) / n, other=sum(x["other"] for x in xs) / n,
            mat=sum(x["mat"] for x in xs) / n, gear=sum(x["gear"] for x in xs) / n,
            gear_cells=sum(x["gear_cells"] for x in xs) / n, mats=dict(mats), slots=dict(slots))
    return floor

def at(region, depth, pick):
    """`pick(floor data)` at `depth`, linear between the probed floors."""
    d = min(max(depth, DEPTHS[0]), DEPTHS[-1])
    for a, b in zip(DEPTHS, DEPTHS[1:]):
        if a <= d <= b:
            t = (d - a) / (b - a)
            return pick(FLOOR[region][a]) * (1 - t) + pick(FLOOR[region][b]) * t
    return pick(FLOOR[region][DEPTHS[-1]])

def run_haul(n, region):
    d = v2.deepest(n - 1)
    floors = 5 if n <= 4 else 10
    start = 1 if n <= 4 else (d - 1) // 10 * 10 + 1
    mats = collections.defaultdict(lambda: [0.0, 1, 0.0])
    slots = collections.defaultdict(lambda: [0.0, 0.0])
    bars = 0.0
    for depth in range(start, start + floors):
        bars += v2.CLEAR * at(region, depth, lambda f: f["bars"])
        for m in set().union(*(FLOOR[region][p]["mats"].keys() for p in DEPTHS)):
            q = at(region, depth, lambda f: f["mats"].get(m, [0.0])[0])
            ref = next(FLOOR[region][p]["mats"][m] for p in DEPTHS if m in FLOOR[region][p]["mats"])
            mats[m][0] += v2.CLEAR * q; mats[m][1] = ref[1]; mats[m][2] = ref[2]
        for s in set().union(*(FLOOR[region][p]["slots"].keys() for p in DEPTHS)):
            slots[s][0] += v2.CLEAR * at(region, depth, lambda f: f["slots"].get(s, [0.0, 0.0])[0])
            slots[s][1] += v2.CLEAR * at(region, depth, lambda f: f["slots"].get(s, [0.0, 0.0])[1])
    # Lots to pack: each material kind in full stacks (the last one partial), each slot's gear.
    lots = []
    for m, (q, stack, unit) in mats.items():
        full, rest = divmod(q, stack)
        if full: lots.append((unit * stack, full, "mat"))
        if rest > 0.05: lots.append((unit * rest, 1, "mat"))
    for s, (value, cells) in slots.items():
        if cells > 0: lots.append((value / cells, cells, "gear"))
    lots.sort(key=lambda l: -l[0])
    room = v2.PACK[v2.pack_level(n)] + v2.SAFE[min(2, v2.pack_level(n))] - math.ceil(bars / 10)
    value = {"mat": 0.0, "gear": 0.0}
    for density, cells, kind in lots:
        take = min(room, cells)
        value[kind] += take * density; room -= take
        if room <= 0: break
    mat_cells = sum(math.ceil(q / stack) for q, stack, _ in mats.values())
    gear_cells = sum(c for _, c in slots.values())
    return value["mat"] + value["gear"], bars, start, floors, value, mat_cells, gear_cells

def run_income(n):
    total = 0.0
    for region in REGIONS:
        value, bars, start, floors, *_ = run_haul(n, region)
        cash = value * v2.SALE[v2.market_open(n)] + bars * v2.BAR_RATE[v2.market_open(n)]
        pay = v2.contract(v2.tier_of(start)) * (floors / 10 if n <= 4 else 1)
        total += cash * (v2.SUCCESS + (1 - v2.SUCCESS) * 0.15) + pay * v2.SUCCESS * v2.OBJECTIVE
    return total / len(REGIONS)

def k(x): return v2.k(x)

if __name__ == "__main__":
    FLOOR = load(sys.argv[1] if len(sys.argv) > 1 else "probe")
    REGIONS = [r for r in ["mine", "city", "snow", "siracusa"] if r in FLOOR]
    print("## 一层能拿到多少（清满，按底价，三个种子平均）\n")
    v2.table(["地区", "兴趣点", "敌人", "材料", "装备 第5层", "第25层", "第45层", "第65层", "第85层", "装备格", "赤金", "其他"],
        [(r, f"{FLOOR[r][45]['pois']:.1f}", f"{FLOOR[r][45]['enemies']:.0f}", k(sum(FLOOR[r][d]['mat'] for d in DEPTHS) / 5))
         + tuple(k(FLOOR[r][d]["gear"]) for d in DEPTHS)
         + (f"{sum(FLOOR[r][d]['gear_cells'] for d in DEPTHS) / 5:.0f}", f"{sum(FLOOR[r][d]['bars'] for d in DEPTHS) / 5:.1f}", k(sum(FLOOR[r][d]['other'] for d in DEPTHS) / 5)) for r in REGIONS])
    print("## 装备每格价值（第 45 层，四地区合计）\n")
    agg = collections.defaultdict(lambda: [0.0, 0.0])
    for r in REGIONS:
        for s, (vv, c) in FLOOR[r][45]["slots"].items(): agg[s][0] += vv; agg[s][1] += c
    tot = sum(vv for vv, _ in agg.values())
    v2.table(["部位", "每格", "占装备总值"], [(s, k(vv / c), f"{vv / tot * 100:.0f}%") for s, (vv, c) in sorted(agg.items(), key=lambda kv: -kv[1][0] / kv[1][1])])
    print("## 每局收入（四地区平均）\n")
    rows, cum, cum_at = [], 0, {}
    for n in range(1, 101):
        inc = run_income(n); cum += inc; cum_at[n] = cum
        if n in (1, 2, 4, 5, 10, 15, 20, 30, 40, 50, 60, 80, 100):
            _, _, start, floors, value, mc, gc = run_haul(n, "mine")
            rows.append((n, v2.deepest(n), start, floors, v2.PACK[v2.pack_level(n)], f"{mc}/{gc:.0f}", k(inc), k(cum)))
    v2.table(["局", "最深层", "出发层", "层数", "背包格", "矿区 材料格/装备格", "本局期望收入", "累计"], rows)
    fixed = v2.BASE_FULL + v2.OPERATORS * (v2.OPERATOR_FIXED + v2.OPERATOR_FEED)
    n_fixed = next((n for n in cum_at if cum_at[n] >= fixed), None)
    n_all = next((n for n in cum_at if cum_at[n] >= fixed + v2.RESEARCH), None)
    print(f"- 基地建满 + 9 名干员练满 {k(fixed)}：第 {n_fixed} 局累计收入追上")
    print(f"- 再加永久研究 {k(v2.RESEARCH)}：第 {n_all} 局追上\n")
    print("## 账本（同 v2 假设）\n")
    fixed_left, research_left = fixed, dict(v2.RESEARCH_BY_TIER)
    s = dict(fixed=0, research=0, proj=0, voy=0); cum = 0; rows = []
    for n in range(1, 101):
        inc = run_income(n); cum += inc; cash = inc
        if n >= 7:
            c = 2 * v2.PROJECT_M * v2.INCOME_INDEX[v2.tier_of(max(1, (v2.deepest(n - 1) - 1) // 10 * 10 + 1)) - 1]
            s["proj"] += c; cash -= c
        if n >= 10 and n % 6 == 0: s["voy"] += v2.VOYAGE; cash -= v2.VOYAGE
        pay = min(max(cash, 0), fixed_left); fixed_left -= pay; s["fixed"] += pay; cash -= pay
        for t in research_left:
            if v2.deepest(n) >= v2.RESEARCH_GATE[t] and n >= 7 and cash > 0:
                pay = min(cash, research_left[t]); research_left[t] -= pay; s["research"] += pay; cash -= pay
        surplus = cum - sum(s.values())
        if n in (5, 10, 15, 20, 30, 40, 50, 60, 80, 100):
            rows.append((n, v2.deepest(n), k(inc), k(cum), k(s["fixed"]), k(s["research"]), k(s["proj"]), k(s["voy"]), k(surplus) if surplus > 1000 else "不足"))
    v2.table(["局", "最深", "本局收入", "累计收入", "固定花销", "永久研究", "课题", "航行", "余额"], rows)
