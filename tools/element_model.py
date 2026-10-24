"""属性伤害与地区装备策划案 v1.1 §14 的核对 (用户 2026-10-24: 先核对数值，然后实现).

Plain arithmetic over the numbers in the code, no Godot needed:
    python tools/element_model.py
Prints the tables the spec quotes:
  A. rarity shares, expected panel and expected affix budget per piece, old
     three tiers against the new five (LootTables.QUALITY, RARE_SCALE and the
     loot stair's S curve as in game/loot_tables.gd and game/scaling.gd);
  B. what the elemental lines add against each enemy armour class;
  C. how often a gauge bursts on an enemy, and on her;
  D. how much resistance a body of gear reaches.
"""
import math

# --- The loot stair and S curve (loot_tables.gd, scaling.gd) ------------------------
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

def scale_rare(weights, n_rare):
    """The last n_rare entries share RARE_SCALE of their combined share."""
    others = sum(weights[:-n_rare])
    rare = sum(weights[-n_rare:])
    share = rare / max(others + rare, 1e-9)
    target = share * RARE_SCALE
    total_rare = target * others / (1.0 - target)
    return weights[:-n_rare] + [w / rare * total_rare for w in weights[-n_rare:]]

def normalise(w):
    t = sum(w)
    return [x / t for x in w]

# --- Old: white / blue / gold ---------------------------------------------------------
OLD_QUALITY = {"normal": [70, 25, 5], "guard": [60, 32, 8], "elite": [25, 50, 25], "box": [50, 38, 12], "vault": [0, 45, 55]}
OLD_DEEP = [0.3, 1.6, 4.0]
OLD_RARE_TOP = 12.2
OLD_MID = [0.7, 1.0, 1.3]
OLD_LINES = [0, 1, 2]

def old_shares(table, depth):
    w = list(map(float, OLD_QUALITY[table]))
    s = s_curve(depth)
    for i in range(2): w[i] *= 1 + (OLD_DEEP[i] - 1) * s
    w[2] *= 1 + (OLD_RARE_TOP - 1) * s
    return normalise(scale_rare(w, 1))

# --- New: grey / green / blue / purple / orange (§2.2, §2.3) ---------------------------
# Purple and orange are the rare pair (RARE_SCALE as gold was); purple keeps gold's
# deep curve, orange ×1.5 on top of it.
NEW_QUALITY = {
    "normal": [66, 16, 14, 3.6, 0.4, 0.04],
    "guard":  [57, 16, 19, 7.2, 0.8, 0.08],
    "elite":  [20, 14, 41, 22.5, 2.5, 0.25],
    "box":    [44, 18, 26, 10.8, 1.2, 0.12],
    "vault":  [0, 8, 37, 49.5, 5.5, 0.55],
}
NEW_DEEP = [0.3, 1.0, 2.0]          # grey, green, blue at the top of the stair
NEW_RARE_TOP = [15.2, 22.8, 30.4]  # LootTables.RARE_TOP_QUALITY, ORANGE_TOP_QUALITY, RED_TOP_QUALITY
NEW_MID = [0.69, 0.84, 1.0, 1.225, 1.425, 1.625]     # bands 62–76 / 78–90 / 90–110 / 115–130 / 135–150 / 155–170
NEW_RANDOM = [0, 1, 1, 2, 2, 3]        # a regional line takes one of these slots (§8.1)
NEW_REGION = [0, 0, 0, 0, 0, 0]        # no extra slot: the regional line is one of NEW_RANDOM
NEW_SIGNATURE = [0, 0, 0, 0, 1, 1]
LINE_SCALE = 1.0
REGION_COMBAT = 0.75
SIGNATURE_WORTH = 1.0               # a signature counted as one full line

def new_shares(table, depth):
    w = list(map(float, NEW_QUALITY[table]))
    s = s_curve(depth)
    for i in range(3): w[i] *= 1 + (NEW_DEEP[i] - 1) * s
    for j in range(3): w[3 + j] *= 1 + (NEW_RARE_TOP[j] - 1) * s
    return normalise(scale_rare(w, 3))

def old_budget(sh):
    panel = sum(p * m for p, m in zip(sh, OLD_MID))
    lines = sum(p * n * m for p, n, m in zip(sh, OLD_LINES, OLD_MID))
    return panel, lines

def new_budget(sh):
    panel = sum(p * m for p, m in zip(sh, NEW_MID))
    lines = 0.0
    for p, n, r, g, m in zip(sh, NEW_RANDOM, NEW_REGION, NEW_SIGNATURE, NEW_MID):
        lines += p * m * LINE_SCALE * (n + r * REGION_COMBAT) + p * g * SIGNATURE_WORTH * m * LINE_SCALE
    return panel, lines

def section_a():
    print("## A. 稀有度与预算（每件期望）\n")
    print("| 来源 | 层 | 旧 白/蓝/金 % | 新 灰/绿/蓝/紫/橙/红 % | 面板 旧→新 | 词条 旧→新 |")
    print("|---|---|---|---|---|---|")
    for table in ["normal", "elite", "box", "vault"]:
        for depth in [1, 15, 30, 45, 60, 90]:
            o, n = old_shares(table, depth), new_shares(table, depth)
            op, ol = old_budget(o)
            np_, nl = new_budget(n)
            print("| %s | %d | %s | %s | %.3f → %.3f (%+.0f%%) | %.3f → %.3f (%+.0f%%) |" % (
                table, depth, " / ".join("%.1f" % (x * 100) for x in o), " / ".join("%.2f" % (x * 100) for x in n),
                op, np_, (np_ / op - 1) * 100, ol, nl, (nl / ol - 1) * 100 if ol > 0 else 0))
    print()

# --- B. Elemental lines against armour --------------------------------------------------
K_RATIO = {"thug (DEF 100)": 100, "brawler (DEF 220)": 220, "elite (DEF 300)": 300, "car (DEF 480)": 480}
K0 = 600.0

def gain(add, conv, res, df):
    """Damage multiplier of a hit with `add` added and `conv` converted, against
    elemental resistance `res` and DEF `df` (K and DEF grow alike, so the floor
    cancels out)."""
    phys = K0 / (K0 + df)
    elem = max(0.1, min(1.5, 1 - res / 100.0))
    base = phys
    new = (1 - conv) * phys + (add + conv) * elem
    return new / base

def section_b():
    print("## B. 元素词条的输出增益（对比同一把无元素武器）\n")
    builds = [("武器附加 6%（蓝）", 0.06, 0.0), ("武器 6% + 戒指 2.5% + 前缀 4%", 0.125, 0.0),
              ("附加 12.5% + 深层转化 25%", 0.125, 0.25), ("附加 12.5% + 首领件转化 35%", 0.125, 0.35)]
    print("| 词条 | 敌人 | 本地 50 | 中立 20 | 弱点 −5 |")
    print("|---|---|---|---|---|")
    for label, add, conv in builds:
        for enemy, df in K_RATIO.items():
            print("| %s | %s | %+.0f%% | %+.0f%% | %+.0f%% |" % (label, enemy, (gain(add, conv, 50, df) - 1) * 100,
                (gain(add, conv, 20, df) - 1) * 100, (gain(add, conv, -5, df) - 1) * 100))
    print("\n对照：武器 攻击 +8% 一条 = +8%（同一满额）。敌人元素抗性：默认 20，本地 +30，弱点 −25，精英再 +10。\n")

# --- C. Bursts ----------------------------------------------------------------------
THRESHOLD = {"普通": 0.20, "精英": 0.30, "首领": 0.08}
HITS_TO_KILL = {"普通": 3.0, "精英": 10.0, "首领": 120.0}
DF = {"普通": 100, "精英": 300, "首领": 400}

def burst_count(kind, add, conv, res):
    """Bursts one enemy of `kind` gives before it dies (gauge = elemental damage dealt)."""
    phys = K0 / (K0 + DF[kind])
    elem = max(0.1, 1 - res / 100.0)
    per_hit_total = (1 - conv) * phys + (add + conv) * elem
    elem_share = (add + conv) * elem / per_hit_total
    return elem_share / THRESHOLD[kind]

def section_c():
    print("## C. 一个敌人死前能爆发几次（损伤 = 元素伤害；阈值 普通 20%/精英 30%/首领 8% 最大生命）\n")
    print("| 词条 | 敌人 | 中立 20 | 弱点 −5 | 本地 50 |")
    print("|---|---|---|---|---|")
    for label, add, conv in [("附加 6%", 0.06, 0.0), ("附加 12.5%", 0.125, 0.0), ("附加 12.5% + 转化 25%", 0.125, 0.25)]:
        for kind in THRESHOLD:
            print("| %s | %s | %.2f | %.2f | %.2f |" % (label, kind, burst_count(kind, add, conv, 20),
                burst_count(kind, add, conv, -5), burst_count(kind, add, conv, 50)))
    print("\n（首领 8 秒冷却另有上限：120 刀约 60 秒，最多 7 次。）\n")
    print("## C2. 她身上：阈值 60% 最大生命，普通一击约 10% 生命\n")
    print("| 层 | 敌人元素占比 | 她的抗性 | 一击元素部分 | 几击爆发 |")
    print("|---|---|---|---|---|")
    for depth, share in [(5, 0.25), (15, 0.375), (45, 0.5), (65, 0.5), (95, 0.5)]:
        penalty = 0 if depth <= 20 else min(40, 5 * ((depth - 11) // 10))
        for res in [0, 40, 80]:
            eff = res - penalty
            mult = max(0.1, min(1.5, 1 - eff / 100.0))
            part = 0.10 * share * mult
            print("| %d | %.0f%% | %d（实际 %d） | %.1f%% 生命 | %.0f |" % (depth, share * 100, res, eff, part * 100, 0.60 / part))
    print()

# --- D. Resistance a body reaches ------------------------------------------------------
RES_CHANCE = [0.25, 0.40, 0.60, 1.0, 1.0]
RES_MULT = [0.6, 0.8, 1.0, 1.2, 1.4]

def section_d():
    print("## D. 七件非武器、全部同一种单抗（中值 10 × 稀有度系数）\n")
    print("| 稀有度 | 每件 | 七件 |")
    print("|---|---|---|")
    names = ["灰", "绿", "蓝", "紫", "橙"]
    for i, n in enumerate(names):
        print("| %s | %.0f | %.0f |" % (n, 10 * RES_MULT[i], 70 * RES_MULT[i]))
    print("\n上限 80；91 层起压制 −40，要 80 才回到实际 40。\n")

if __name__ == "__main__":
    section_a()
    section_b()
    section_c()
    section_d()
