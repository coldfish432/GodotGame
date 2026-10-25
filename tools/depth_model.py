"""层数只决定稀有度 (用户 2026-10-24: 低层只掉灰、绿等常见的，高层掉高稀有度的).

Gear stops growing ×1.48 every ten floors: a piece's numbers come from its
rarity alone, and depth only decides which rarities drop. This model works out
what she wears on each floor, how much stronger that makes her than on floor 1,
and so how fast enemies may grow for the fight to feel the same at every depth.

    python tools/depth_model.py

Assumptions (stated, to be checked in play):
  - She wears the best of the gear she has seen: per slot, the rarity at the
    top PERCENTILE of the drops of the last WINDOW floors (normal + elite mix).
  - Attribute points: 2 + 1.95 a floor up to 119 (清单 J), half 技巧 half 体魄.
  - 科研战斗研究: +89% ATK / HP / DEF at full, reached linearly by floor 80.
  - 前缀特效族: up to ×1.4 offence and toughness by floor 90 (前缀放大案 §5 aimed
    at ×2.0 at (8), worn rarely in full).
  - Affix lines: each line ≈ +4% of a stat, a body has 8 pieces.
"""
import math, sys

# --- The loot stair and S curve (game/loot_tables.gd, game/scaling.gd) ---------------
STAIR_STEP_ENDS = [3, 6, 9, 10]
STAIR_TOP, STAIR_BLOCKS = 35, 9
S_MID, S_WIDTH = 45.0, 8.0
RARE_SCALE = 0.1

def stair(depth):
    block = (max(depth, 1) - 1) // 10
    if block >= STAIR_BLOCKS: return STAIR_TOP
    place = (max(depth, 1) - 1) % 10 + 1
    step = 0
    while place > STAIR_STEP_ENDS[step]: step += 1
    return min(block * 4 + step, STAIR_TOP)

def logistic(x): return 1.0 / (1.0 + math.exp(-(x - S_MID) / S_WIDTH))

def s_curve(depth):
    q = 1.0 + stair(depth) * 90.0 / STAIR_TOP
    return min(1.0, max(0.0, (logistic(q) - logistic(1.0)) / (logistic(91.0) - logistic(1.0))))

# --- The new rule: odds only (用户 2026-10-24: 不按层解锁，只用掉率限制，概率低
# 但刷十万百万只也能刷出来). Each source has its shares on floor 1 and at the
# stair's top (floor 90); in between every rarity's weight moves log-linearly
# along the loot S curve, so a red is one in a million pieces on floor 1 and
# one in a thousand at the top.
SHALLOW = {
    "normal": [80.0, 19.0, 1.0, 0.01, 0.001, 0.0001],
    "elite":  [55.0, 38.0, 7.0, 0.1, 0.01, 0.001],
}
DEEP_SHARES = {
    "normal": [29.5, 23.8, 41.7, 4.2, 0.7, 0.1],
    "elite":  [5.4, 12.6, 74.0, 6.7, 1.1, 0.15],
}
MID = [0.69, 0.84, 1.0, 1.225, 1.425, 1.625]
LINES = [0, 1, 1, 2, 2, 3]

def shares(table, depth):
    s = s_curve(depth)
    w = [math.exp(math.log(max(a, 1e-9)) * (1 - s) + math.log(max(b, 1e-9)) * s) if a > 0 or b > 0 else 0.0
         for a, b in zip(SHALLOW[table], DEEP_SHARES[table])]
    t = sum(w)
    return [x / t for x in w]

# --- What she wears -------------------------------------------------------------------
# She keeps the best piece she has found for each slot: PER_FLOOR gear drops a
# slot per floor (normal + elite mix), all floors so far count.
PER_FLOOR = 0.6
ELITE_SHARE = 0.25

def worn(depth):
    """Expected (panel, lines) of the best piece of a slot found by `depth`."""
    # P(best < r) = Π over pieces of P(piece < r).
    log_below = [0.0] * 7   # index r: log P(every piece is below r)
    for f in range(1, depth + 1):
        n, e = shares("normal", f), shares("elite", f)
        mix = [(1 - ELITE_SHARE) * n[i] + ELITE_SHARE * e[i] for i in range(6)]
        for r in range(1, 7):
            below = sum(mix[:r]) if r < 6 else 1.0
            log_below[r] += PER_FLOOR * math.log(max(below, 1e-12))
    p_best = []
    for r in range(6):
        p_le = math.exp(log_below[r + 1]) if r < 5 else 1.0
        p_lt = math.exp(log_below[r]) if r > 0 else 0.0
        p_best.append(max(0.0, p_le - p_lt))
    panel = sum(p * m for p, m in zip(p_best, MID))
    lines = sum(p * l for p, l in zip(p_best, LINES))
    top = max(range(6), key=lambda i: p_best[i])
    return panel, lines, top, p_best

def doctor(depth):
    panel, lines, r, _ = worn(depth)
    p = 3.1 * panel * 1.05
    points = min(119.0, 2 + depth * 1.95)
    tec = phy = points / 2
    research = 1 + 0.89 * min(1.0, depth / 80.0)
    family = 1 + 0.4 * min(1.0, depth / 90.0)
    affix = 1 + 0.04 * lines * 8 / 8   # a line per piece worth ~4% of its stat
    atk = (150 + 220 * p) * (1 + 0.12 + 0.0028 * tec) * research * family * affix
    hp = (600 + 1300 * p) * (1 + 0.04 + 0.0035 * phy) * research * family * affix
    df = (50 + 80 * p) * (1 + 0.0035 * phy) * research
    return dict(atk=atk, hp=hp, df=df, rarity=r)

def fmt(x):
    if x >= 0.001: return "%.1f%%" % (x * 100)
    return "1/%s" % format(round(1 / x), ",") if x > 0 else "0"

NAMES = ["灰", "绿", "蓝", "紫", "橙", "红"]

def table():
    base = doctor(1)
    print("## 她穿什么、比第 1 层强多少（攻击 / 生命）\n")
    print("| 层 | 普通敌人掉落 灰/绿/蓝/紫/橙/红 | 她常穿 | 攻击 ×第 1 层 | 生命 ×第 1 层 |")
    print("|---|---|---|---|---|")
    rows = []
    for f in [1, 5, 10, 11, 15, 20, 30, 31, 40, 50, 51, 60, 70, 71, 80, 90, 100, 120]:
        d = doctor(f)
        sh = shares("normal", f)
        ra, rh = d["atk"] / base["atk"], d["hp"] / base["hp"]
        rows.append((f, ra, rh))
        print("| %d | %s | %s | %.2f | %.2f |" % (f, " / ".join(fmt(x) for x in sh), NAMES[d["rarity"]], ra, rh))
    return rows

def fit(rows, upto=90):
    """The per-floor growth whose curve sits closest to her own (log least squares)."""
    pts = [(f, r) for f, r, _ in rows if f <= upto]
    num = sum((f - 1) * math.log(r) for f, r in pts)
    den = sum((f - 1) ** 2 for f, r in pts)
    hp_pts = [(f, h) for f, _, h in rows if f <= upto]
    num_h = sum((f - 1) * math.log(h) for f, h in hp_pts)
    return math.exp(num / den), math.exp(num_h / den)

CURVE_FLOORS = [1, 10, 20, 30, 40, 50, 60, 70, 80, 90]

def curve():
    """Enemy growth that follows her own (the mean of ATK and HP), floor by floor."""
    base = doctor(1)
    out = []
    for f in CURVE_FLOORS:
        d = doctor(f)
        out.append(round(math.sqrt(d["atk"] / base["atk"] * d["hp"] / base["hp"]), 2))
    return out

if __name__ == "__main__":
    rows = table()
    print("\n## 敌人成长曲线（跟她的攻击与生命的几何平均）\n")
    print("| 层 | " + " | ".join(str(f) for f in CURVE_FLOORS) + " |")
    print("|---|" + "---|" * len(CURVE_FLOORS))
    print("| ×第 1 层 | " + " | ".join("%.2f" % v for v in curve()) + " |")
    g_atk, g_hp = fit(rows)
    print("\n## 敌人每层成长（让每层的手感和第 1 层一样）\n")
    print("- 敌人生命与防御跟她的攻击：×%.4f / 层（90 层 ×%.1f）" % (g_atk, g_atk ** 89))
    print("- 敌人攻击跟她的生命：×%.4f / 层（90 层 ×%.1f）" % (g_hp, g_hp ** 89))
    print("\n## 用一条曲线时每层的偏差（她的攻击 ÷ 敌人生命，1.00 = 和第 1 层一样）\n")
    g = round((g_atk + g_hp) / 2, 3)
    print("取 ×%.3f / 层：\n" % g)
    print("| 层 | 输出手感 | 承伤手感 |")
    print("|---|---|---|")
    for f, ra, rh in rows:
        print("| %d | %.2f | %.2f |" % (f, ra / g ** (f - 1), rh / g ** (f - 1)))
