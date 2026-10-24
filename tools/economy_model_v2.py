"""龙门币经济模型 v2（用户 2026-10-23：改了点东西，重新算龙门币数值）.

Supersedes tools/economy_model.py for income: that model guessed a floor at
6.5 赤金 + 3,000 of materials + 1.1 gear pieces. The code has grown since
(POI loot, 8-slot gear, packs, consignment, the farm, the facility ladder, the
71-node research tree), so this one starts from what a generated floor holds,
measured in the game (a probe over 12 real floors, 4 regions, loot rolled 30×
at five depths, priced with Economy.price), and from the pack being the limit:
a run brings home the most valuable cells that fit.

    PYTHONIOENCODING=utf-8 python tools/economy_model_v2.py
"""
import math

# --- What one floor holds, full clear (probe 2026-10-23, base price, LMD) ---------------
# region: POIs, enemies, materials (value, cells), gear cells, bars; gear value by depth.
FLOOR = {
    "mine":     dict(mat=43200, mat_cells=5.3, gear_cells=33.0, bars=9.0, gear={5: 47600, 25: 192200, 45: 362400, 65: 571900, 85: 733400}),
    "city":     dict(mat=27800, mat_cells=2.5, gear_cells=21.0, bars=8.6, gear={5: 30400, 25: 113600, 45: 231300, 65: 342100, 85: 461600}),
    "snow":     dict(mat=56200, mat_cells=5.6, gear_cells=47.0, bars=16.0, gear={5: 98700, 25: 318600, 45: 602100, 65: 941400, 85: 1258200}),
    "siracusa": dict(mat=32300, mat_cells=3.0, gear_cells=35.5, bars=15.0, gear={5: 67200, 25: 207200, 45: 411700, 65: 627400, 85: 811500}),
}
REGIONS = list(FLOOR)

def gear_value(region, depth):
    pts = sorted(FLOOR[region]["gear"])
    depth = min(max(depth, pts[0]), pts[-1])
    for a, b in zip(pts, pts[1:]):
        if a <= depth <= b:
            t = (depth - a) / (b - a)
            return FLOOR[region]["gear"][a] * (1 - t) + FLOOR[region]["gear"][b] * t
    return FLOOR[region]["gear"][pts[-1]]

# --- Play assumptions -------------------------------------------------------------------
CLEAR = 0.7                  # share of POIs and enemies a run takes on a floor
PACK = [60, 80, 96]          # 10×6, 10×8, 12×8 cells (BaseCatalog.PACK_SIZES), bought 15k / 40k
SAFE = [4, 6, 9]             # safe bag cells
BAR_RATE = {False: 970, True: 995}   # 可露希尔 (3%) / the exchange's changer (0.5%) once built
SALE = {False: 0.80, True: 0.90}     # direct delivery / packs and consignment once open
SUCCESS, OBJECTIVE = 0.75, 0.85
# The best gear taken first: the selected share runs this much denser than the average.
PICK_BONUS = 0.6

def deepest(n): return max(1, round(1 + 89 * (1 - math.exp(-n / 28))))
def tier_of(floor): return (int(floor) - 1) // 10 + 1
INCOME_INDEX = [1.0, 1.49, 1.99, 2.57, 3.28, 4.06, 4.79, 5.46, 6.10, 6.73]
def contract(tier): return 8000 * INCOME_INDEX[tier - 1]

def pack_level(n): return 0 if n <= 1 else (1 if n <= 3 else 2)
def market_open(n): return n >= 10      # 交易所 (喀兰贸易 R2) and the consignment counter

def run_haul(n, region):
    """(base value of what fits, bars, start floor, floors) of run n in `region`."""
    d = deepest(n - 1)
    floors = 5 if n <= 4 else 10
    start = 1 if n <= 4 else (d - 1) // 10 * 10 + 1
    f = FLOOR[region]
    mat_v = mat_c = gear_v = gear_c = bars = 0.0
    for i in range(floors):
        depth = start + i
        mat_v += CLEAR * f["mat"]; mat_c += CLEAR * f["mat_cells"]
        gear_v += CLEAR * gear_value(region, depth); gear_c += CLEAR * f["gear_cells"]
        bars += CLEAR * f["bars"]
    cells = PACK[pack_level(n)] + SAFE[min(2, pack_level(n))] - math.ceil(bars / 10)
    # Fill by value per cell: materials and gear in density order.
    mat_density = mat_v / max(mat_c, 0.1)
    gear_density = gear_v / max(gear_c, 0.1)
    take_gear = lambda room: min(room, gear_c)
    value = 0.0
    if mat_density >= gear_density:
        m = min(cells, mat_c); value += m * mat_density; room = cells - m
        g = take_gear(room); share = g / max(gear_c, 0.1)
        value += g * gear_density * (1 + PICK_BONUS * (1 - share))
    else:
        g = take_gear(cells); share = g / max(gear_c, 0.1)
        value += g * gear_density * (1 + PICK_BONUS * (1 - share))
        room = cells - g; value += min(room, mat_c) * mat_density
    return value, bars, start, floors

def run_income(n):
    """Expected LMD of run n, the four regions alike."""
    total = 0.0
    for region in REGIONS:
        value, bars, start, floors = run_haul(n, region)
        cash = value * SALE[market_open(n)] + bars * BAR_RATE[market_open(n)]
        safe_keep = 0.15
        pay = contract(tier_of(start)) * (floors / 10 if n <= 4 else 1)
        total += cash * (SUCCESS + (1 - SUCCESS) * safe_keep) + pay * SUCCESS * OBJECTIVE
    return total / len(REGIONS)

# --- Spending (audit 2026-10-23, game/*), after 用户 2026-10-23 "涨花销": every 龙门币
# sink × COST (rounded in the code: to 1,000 at 10k and over, else 100) ----------------
COST = 2.8
BASE_FULL = 2838000 * COST                # facilities, hub links, racks, pack, safe, console, drone, camp
OPERATOR_FIXED = 158000 * COST            # E1, E2, three module levels
OPERATOR_FEED = 315530 * 0.55 * 0.5 * COST   # records for the share not earned by kills
OPERATORS = 9
RESEARCH_GATE = {1: 0, 2: 11, 3: 21, 4: 41, 5: 61, 6: 81, 7: 90}
RESEARCH_BY_TIER = {t: v * COST for t, v in {1: 230000, 2: 725000, 3: 1600000, 4: 3190000, 5: 6075000, 6: 15300000, 7: 5000000}.items()}
RESEARCH = sum(RESEARCH_BY_TIER.values())
PROJECT_M = 8000 * COST
VOYAGE = 280000 * COST                    # typical route at standard pace (voyage_catalog.gd, goods × 2.8)

# --- The farm (provisions.gd, 用户 2026-10-23: about seed × 1.25 a basin): wheat 6 a basin
# every 2 h, seed 770, sold 200 × 0.8 (作物包 pays about the same) ----
FARM_PER_BASIN_HOUR = (6 * 200 * 0.8 - 770) / 2

def k(x): return f"{x / 1000:,.0f}k" if abs(x) < 1e6 else f"{x / 1e6:,.2f}M"
def table(head, rows):
    print("| " + " | ".join(head) + " |")
    print("|" + "---|" * len(head))
    for r in rows: print("| " + " | ".join(str(x) for x in r) + " |")
    print()

if __name__ == "__main__":
    print("## 一层能拿到多少（清满，按底价）\n")
    table(["地区", "材料", "材料格", "装备 第5层", "装备 第45层", "装备 第85层", "装备格", "赤金"],
          [(r, k(FLOOR[r]["mat"]), FLOOR[r]["mat_cells"], k(gear_value(r, 5)), k(gear_value(r, 45)), k(gear_value(r, 85)), FLOOR[r]["gear_cells"], FLOOR[r]["bars"]) for r in REGIONS])
    print("## 每格价值（材料 vs 装备平均）\n")
    table(["地区", "材料/格", "装备/格 第5层", "第25层", "第45层", "第85层"],
          [(r, k(FLOOR[r]["mat"] / FLOOR[r]["mat_cells"]),) + tuple(k(gear_value(r, d) / FLOOR[r]["gear_cells"]) for d in (5, 25, 45, 85)) for r in REGIONS])
    print("## 每局收入（四地区平均）\n")
    rows, cum, cum_at = [], 0, {}
    for n in range(1, 101):
        inc = run_income(n)
        cum += inc
        cum_at[n] = cum
        if n in (1, 2, 4, 5, 10, 15, 20, 30, 40, 50, 60, 80, 100):
            _, bars, start, floors = run_haul(n, "mine")
            rows.append((n, deepest(n), start, floors, PACK[pack_level(n)], k(inc), k(cum)))
    table(["局", "最深层", "出发层", "层数", "背包格", "本局期望收入", "累计"], rows)
    fixed = BASE_FULL + OPERATORS * (OPERATOR_FIXED + OPERATOR_FEED)
    n_fixed = next(n for n in cum_at if cum_at[n] >= fixed)
    n_all = next((n for n in cum_at if cum_at[n] >= fixed + RESEARCH), None)
    print(f"- 基地建满 {k(BASE_FULL)}，9 名干员练满 {k(OPERATORS * (OPERATOR_FIXED + OPERATOR_FEED))}，合计 {k(fixed)}：第 {n_fixed} 局累计收入追上（最深约 {deepest(n_fixed)} 层）")
    print(f"- 再加永久研究 {k(RESEARCH)}：合计 {k(fixed + RESEARCH)}，第 {n_all} 局追上\n")

    print("## 账本（能买就买；科研部开放后每局两个中课题；第 10 局起每 6 局航行一次）\n")
    fixed_left = fixed
    research_left = dict(RESEARCH_BY_TIER)
    s = dict(fixed=0, research=0, proj=0, voy=0)
    cum = 0
    rows = []
    for n in range(1, 101):
        inc = run_income(n)
        cum += inc
        cash = inc
        if n >= 7:
            c = 2 * PROJECT_M * INCOME_INDEX[tier_of(max(1, (deepest(n - 1) - 1) // 10 * 10 + 1)) - 1]
            s["proj"] += c; cash -= c
        if n >= 10 and n % 6 == 0:
            s["voy"] += VOYAGE; cash -= VOYAGE
        pay = min(max(cash, 0), fixed_left); fixed_left -= pay; s["fixed"] += pay; cash -= pay
        for t in research_left:
            if deepest(n) >= RESEARCH_GATE[t] and n >= 7 and cash > 0:
                pay = min(cash, research_left[t]); research_left[t] -= pay; s["research"] += pay; cash -= pay
        surplus = cum - sum(s.values())
        if n in (5, 10, 15, 20, 30, 40, 50, 60, 80, 100):
            rows.append((n, deepest(n), k(inc), k(cum), k(s["fixed"]), k(s["research"]), k(s["proj"]), k(s["voy"]), k(surplus) if surplus > 1000 else "不足"))
    table(["局", "最深", "本局收入", "累计收入", "固定花销", "永久研究", "课题", "航行", "余额"], rows)
    print(f"## 农业部\n\n- 舰载麦每盆每小时净 {FARM_PER_BASIN_HOUR:,.0f}；72 盆一天（24 小时）约 {k(FARM_PER_BASIN_HOUR * 72 * 24)}，不出击\n")
