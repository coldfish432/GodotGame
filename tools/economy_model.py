"""龙门币经济模型（用户 2026-10-20：先平衡当前龙门币的数值，然后策划科研部）。

Plain arithmetic over the numbers in the code and in 复利数值改造清单.md — no Godot:
    python tools/economy_model.py        prints the tables 龙门币平衡与科研部策划案 quotes
(on this Windows box: PYTHONIOENCODING=utf-8, or the gbk console chokes.)

v1.1 rules (用户 2026-10-20 第二轮):
- settlement pays nothing extra: no objective bonus, no 作战记录 — records drop in the
  field like any other loot, and all field income is what comes home in the pack;
- the contract reward is fixed when the contract is taken and paid on extraction with
  the objective done;
- experience follows 复利清单 J: 227 levels, the n-th needs A × (1 + n/25).

The model:
- one "typical" floor: partial clear (6.5 赤金), materials and order premium 3,000, and
  ~1.1 gear pieces carried home (the pack is the limit), rarity on the 复利 S-curve;
- a run is 5 floors for the first 4 runs, then 10 floors from the deepest camp;
  75% extract, 85% of those with the objective done; a death keeps ~15% (safe bag);
- the deepest floor grows as 90 × (1 − e^(−n/28)): floor 30 near run 11, 60 near run 31.
"""
import math

# --- Income rules ---------------------------------------------------------------------
BAR = 970                 # 可露希尔 buys 赤金 at fx 1000 less 3%
BARS_PER_FLOOR = 6.5      # partial clear; a full clear is 8–9.5 (flat with depth)
MATERIALS = 3000          # 15–20 units at ★1–3 + order premium (flat with depth)
CARRIED = 1.1             # gear pieces brought home per floor
SALE = 0.8                # direct delivery
SUCCESS, OBJECTIVE, DEATH_KEEP = 0.75, 0.85, 0.15

def s_curve(floor):
    f = lambda x: 1 / (1 + math.exp(-(x - 45) / 8))
    return min(max((f(floor) - f(1)) / (f(90) - f(1)), 0), 1)

def gold_share(floor):
    """Normal enemies' gold-gear share on the 复利 table (0.5% → 5%)."""
    return 0.005 + 0.045 * s_curve(floor)

def carried_mult(floor):
    """(1 + rarity) of what comes home: all blue at least, plus the gold found.
    Elites/boxes roll gold ~1.5× normal; ~10 gear drops a floor."""
    return 2 + min(1.0, 10 * 1.5 * gold_share(floor) / CARRIED)

def gear_value(floor): return 10 + 4 * floor
def tier_of(floor): return (int(floor) - 1) // 10 + 1

def drop_income(floor):
    """What one floor puts in the pack, sold at the base."""
    gear = CARRIED * gear_value(floor) * carried_mult(floor) * 100 * SALE
    return BARS_PER_FLOOR * BAR + MATERIALS + gear

def income_index(tier):
    """Drop income per floor at the tier's middle, tier Ⅰ = 1."""
    return drop_income((tier - 1) * 10 + 5.5) / drop_income(5.5)

# Contract reward, rolled when taken: base × I(departure tier) × kind × 0.85–1.15.
CONTRACT_BASE = 8000
CONTRACT_KIND = {"深入 4 层": 0.8, "深入 6 层": 1.1, "深入 9 层": 1.5, "回收": 0.9, "搜索": 1.0, "猎杀": 1.1}

def contract(tier): return CONTRACT_BASE * income_index(tier)

def deepest(n): return max(1, round(1 + 89 * (1 - math.exp(-n / 28))))

def run(n):
    """(start floor, floors, expected income) of run n (1-based)."""
    d = deepest(n - 1)
    floors = 5 if n <= 4 else 10
    start = 1 if n <= 4 else (d - 1) // 10 * 10 + 1
    drops = sum(drop_income(start + i) for i in range(floors))
    pay = contract(tier_of(start)) * (floors / 10 if n <= 4 else 1)
    return start, floors, drops * (SUCCESS + (1 - SUCCESS) * DEATH_KEEP) + pay * SUCCESS * OBJECTIVE

# --- Experience (复利清单 J) ------------------------------------------------------------
A = 250                                         # 清单 J proposes 50; 250 maxes a main (60% share) near floor 60
LEVELS = (59, 79, 89)                          # E0 1→60, E1 1→80, E2 1→90
def level_cost(n): return A * (1 + n / 25)     # the n-th level-up, n = 1…227
PHASE_EXP = []
_n = 0
for span in LEVELS:
    PHASE_EXP.append(sum(level_cost(_n + i) for i in range(1, span + 1)))
    _n += span
TOTAL_EXP = sum(PHASE_EXP)

# Per floor (partial clear): 26.6 normal, 2.1 elite, 0.9 leader, a boss or warden every 10.
KILL_EXP = {"normal": 8, "elite": 50, "leader": 120}
KILLS = {"normal": 26.6, "elite": 2.1, "leader": 0.9}
def kill_exp(floor):
    block = (int(floor) - 1) // 10
    boss = (300 + 100 * min(tier_of(floor), 5)) / 10
    return (sum(KILL_EXP[k] * KILLS[k] for k in KILLS) + boss) * (1 + 0.25 * block)
# 作战记录 now drop (same expectation as the old settlement): 1 basic per 10 normal kills,
# 初级 per elite, 中级 per leader, 高级 per boss (every 10 floors).
RECORD_EXP_PER_FLOOR = KILLS["normal"] / 10 * 100 + KILLS["elite"] * 200 + KILLS["leader"] * 500 + 1000 / 10
LMD_PER_RECORD_EXP = 0.5                       # unchanged

def floors_to_max(share):
    """Floors played until an operator taking `share` of the EXP is maxed, and the
    deepest floor at that point."""
    got, played, n = 0, 0, 0
    while got < TOTAL_EXP and n < 400:
        n += 1
        start, floors, _ = run(n)
        for i in range(floors):
            got += share * SUCCESS * (kill_exp(start + i) + RECORD_EXP_PER_FLOOR) \
                 + share * (1 - SUCCESS) * kill_exp(start + i)  # kill EXP is kept on death
            played += 1
    return played, n, deepest(n)

def record_share(floor):
    return RECORD_EXP_PER_FLOOR / (RECORD_EXP_PER_FLOOR + kill_exp(floor))

# --- Sinks -----------------------------------------------------------------------------
RACKS = [0, 6000, 9000, 14000, 14000, 14000, 20000, 20000, 20000]
P_RACKS = [0, 8000, 12000, 25000, 25000, 25000, 45000, 45000, 45000]
def operator_cost(feed_rate, e1, e2, modules):
    feed = TOTAL_EXP * record_share(45) * feed_rate
    return feed + e1 + e2 + sum(modules)
CURRENT = {"operator": 31225 + 6000 + 36000 + 45000,
           "base": 4 * sum(RACKS) + 12000 + 26000 + 15000 + 32000 + 8000 + 15000 + 30000}
PROPOSED = {"operator": operator_cost(LMD_PER_RECORD_EXP, 8000, 60000, (20000, 30000, 40000)),
            "base": 4 * sum(P_RACKS) + 15000 + 40000 + 20000 + 50000 + 10000 + 20000 + 60000}
def fixed_total(p): return 9 * p["operator"] + p["base"]

# --- Research (§四) ---------------------------------------------------------------------
DEPARTMENTS = 7
NODE_PRICE = {1: 20000, 2: 50000, 3: 100000, 4: 220000, 5: 450000, 6: 900000}
NODE_HOURS = {1: 1, 2: 2, 3: 4, 4: 8, 5: 16, 6: 24}
NODE_GATE = {1: 1, 2: 11, 3: 21, 4: 41, 5: 61, 6: 81}   # deepest camp floor
NODES_PER_TIER = {t: DEPARTMENTS for t in NODE_PRICE}   # 7 departments × 6 tiers = 42
PROJECT_BASE = {"S": 4000, "M": 8000, "L": 14000}
ENDLESS_LINES, ENDLESS_BASE, ENDLESS_GROWTH, ENDLESS_CAP = 6, 50000, 1.25, 30

def table(head, rows):
    print("| " + " | ".join(head) + " |")
    print("|" + "---|" * len(head))
    for r in rows: print("| " + " | ".join(str(x) for x in r) + " |")
    print()

def k(x): return f"{x / 1000:,.0f}k" if abs(x) < 1e6 else f"{x / 1e6:,.2f}M"
ROMAN = "Ⅰ Ⅱ Ⅲ Ⅳ Ⅴ Ⅵ Ⅶ Ⅷ Ⅸ Ⅹ".split()

if __name__ == "__main__":
    print("## 每层掉落收入（撤离成功）\n")
    table(["层", "装备价值", "带回倍率", "赤金", "材料", "装备", "合计"],
          [(f, gear_value(f), f"{carried_mult(f):.2f}", k(BARS_PER_FLOOR * BAR), k(MATERIALS),
            k(drop_income(f) - BARS_PER_FLOOR * BAR - MATERIALS), k(drop_income(f))) for f in (1, 10, 30, 50, 70, 90)])

    print("## 收入指数与合同报酬\n")
    table(["档", "层", "I(档)", "档位系数", "合同报酬（中值）", "范围（×类型 0.8–1.5 × 0.85–1.15）"],
          [(ROMAN[t - 1], f"{(t-1)*10+1}–{t*10}", f"{income_index(t):.2f}", f"{1.48 ** (t - 1):.1f}", k(contract(t)),
            f"{k(contract(t) * 0.8 * 0.85)}–{k(contract(t) * 1.5 * 1.15)}") for t in range(1, 11)])

    print("## 经验（复利清单 J，A = %d）\n" % A)
    table(["阶段", "升级次数", "经验", "占比"],
          [(f"精英 {i}", LEVELS[i], f"{PHASE_EXP[i]:,.0f}", f"{PHASE_EXP[i] / TOTAL_EXP:.0%}") for i in range(3)] +
          [("合计", sum(LEVELS), f"{TOTAL_EXP:,.0f}", "100%")])
    table(["层", "击杀经验/层", "作战记录经验/层", "记录占比"],
          [(f, f"{kill_exp(f):,.0f}", f"{RECORD_EXP_PER_FLOOR:,.0f}", f"{record_share(f):.0%}") for f in (1, 11, 21, 41, 61, 81)])
    table(["主力分到的经验", "打的层数", "第几局", "此时最深层"],
          [(f"{s:.0%}",) + floors_to_max(s) for s in (1.0, 0.6, 0.4)])
    rows, keep = [], A
    for a in (50, 100, 150, 200, 250, 300):
        A = a
        tot = sum(level_cost(n) for n in range(1, 228))
        globals()["TOTAL_EXP"] = tot
        rows.append((a, f"{tot:,.0f}") + floors_to_max(0.6)[1:])
    A = keep
    globals()["TOTAL_EXP"] = sum(PHASE_EXP)
    table(["A", "练满总经验", "主力 60%：第几局练满", "此时最深层"], rows)
    feed = TOTAL_EXP * record_share(45)
    print(f"- 练满一人要喂的作战记录经验约 {feed:,.0f}（按第 45 层的记录占比），每点 {LMD_PER_RECORD_EXP} 龙门币 → {k(feed * LMD_PER_RECORD_EXP)}\n")

    print("## 进度与累计收入\n")
    cum, rows, cum_at = 0, [], {}
    for n in range(1, 81):
        start, floors, inc = run(n)
        cum += inc
        cum_at[n] = cum
        if n in (1, 4, 6, 10, 15, 20, 30, 40, 50, 60, 70, 80):
            rows.append((n, deepest(n), start, floors, k(inc), k(cum)))
    table(["局", "最深层", "出发层", "层数", "本局期望收入", "累计"], rows)

    print("## 固定花销总量\n")
    for name, p in (("现状", CURRENT), ("调整后", PROPOSED)):
        total = fixed_total(p)
        n = next((n for n in cum_at if cum_at[n] >= total), None)
        print(f"- {name}：单个干员 {k(p['operator'])}，基地 {k(p['base'])}，9 干员 + 基地 {k(total)}；"
              f"累计收入在第 {n} 局追上（最深约 {deepest(n)} 层）")
    print()

    print("## 科研：永久研究\n")
    total_nodes = sum(NODE_PRICE[t] * NODES_PER_TIER[t] for t in NODE_PRICE)
    table(["研究阶", "需要的最深营地", "单价", "时长", "节点数", "本阶合计"],
          [(ROMAN[t - 1], "无" if t == 1 else f"第 {NODE_GATE[t] - 1} 层", k(NODE_PRICE[t]), f"{NODE_HOURS[t]} 小时",
            NODES_PER_TIER[t], k(NODE_PRICE[t] * NODES_PER_TIER[t])) for t in NODE_PRICE])
    hours = sum(NODE_HOURS[t] * NODES_PER_TIER[t] for t in NODE_PRICE)
    print(f"- 合计 {sum(NODES_PER_TIER.values())} 项，{k(total_nodes)}，研究时长 {hours} 小时（两个研究位约 {hours / 2 / 24:.1f} 天）\n")

    print("## 科研：限时课题每次出击价格\n")
    table(["档"] + list(PROJECT_BASE), [(ROMAN[t - 1],) + tuple(k(b * income_index(t)) for b in PROJECT_BASE.values()) for t in range(1, 11)])

    print("## 科研：无限研究\n")
    table(["级", "单级价格", "累计"],
          [(lv, k(ENDLESS_BASE * ENDLESS_GROWTH ** (lv - 1)), k(sum(ENDLESS_BASE * ENDLESS_GROWTH ** i for i in range(lv))))
           for lv in (1, 5, 10, 15, 20, 25, 30)])

    print("## 调整后的账本（能买就买；科研部开放后每局两个中课题；第 10 局起每 6 局航行一次约 30 万）\n")
    fixed_left = fixed_total(PROPOSED)
    research_left = {t: NODE_PRICE[t] * NODES_PER_TIER[t] for t in NODE_PRICE}
    cum = s_fixed = s_research = s_proj = s_voy = 0
    rows = []
    for n in range(1, 81):
        start, floors, inc = run(n)
        cum += inc
        cash = inc
        if n >= 7:
            c = 2 * PROJECT_BASE["M"] * income_index(tier_of(start)); s_proj += c; cash -= c
        if n >= 10 and n % 6 == 0:
            s_voy += 300000; cash -= 300000
        pay = min(max(cash, 0), fixed_left); fixed_left -= pay; s_fixed += pay; cash -= pay
        for t in NODE_PRICE:
            if deepest(n) >= NODE_GATE[t] and n >= 7 and cash > 0:
                pay = min(cash, research_left[t]); research_left[t] -= pay; s_research += pay; cash -= pay
        surplus = cum - s_fixed - s_research - s_proj - s_voy
        if n in (5, 10, 16, 20, 30, 40, 50, 60, 70, 80):
            per, lv, acc = max(surplus, 0) / ENDLESS_LINES, 0, 0
            while lv < ENDLESS_CAP and acc + ENDLESS_BASE * ENDLESS_GROWTH ** lv <= per:
                acc += ENDLESS_BASE * ENDLESS_GROWTH ** lv; lv += 1
            rows.append((n, deepest(n), k(inc), k(cum), k(s_fixed), k(s_research), k(s_proj), k(s_voy),
                         k(surplus) if surplus > 1000 else "不足", lv))
    table(["局", "最深", "本局收入", "累计收入", "固定花销", "永久研究", "课题", "航行", "余额", f"余额全投无限研究（{ENDLESS_LINES} 条平分）的等级"], rows)

    print("## 课题占每局收入\n")
    for n in (10, 30, 50, 70):
        start, floors, inc = run(n)
        c = 2 * PROJECT_BASE["M"] * income_index(tier_of(start))
        print(f"- 第 {n} 局（出发第 {start} 层）：收入 {k(inc)}，两个中课题 {k(c)}，占 {c / inc:.0%}")
