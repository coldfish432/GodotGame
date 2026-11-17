"""罗德岛日账校准（罗德岛运营与资产管理策划案 v0.12 §2.2，用户 2026-11-14："先做数值校准"）.

Income per run from economy_model_v3.py (its probe logs are kept in
tools/probe_2026-11-13/), spending and play assumptions from economy_model_v2.py.
Adds what the daily bill takes, two runs a day (§2.2), against the same ledger:
  - facility levels: the upkeeping facilities (hub, warehouse, outfit, workshop,
    lab, farm, canteen; BaseCatalog) go from the 3 a new save has to the 22 of a
    full base in step with the ledger's fixed spending;
  - operators aboard: 1 at the start (only 阿米娅), the other eight found by run 30;
  - the tier: the deepest camp unlocked (multiple of 10 at or under the deepest floor);
  - the upkeep materials cost the live ask, about base × ASK.
Prints the bill's share of two runs' income by run, and the ledger with the bill
taken out, for the current constants and the candidates below.

    PYTHONIOENCODING=utf-8 python tools/upkeep_model.py [probe dir]
"""
import math, os, sys

sys.path.insert(0, os.path.dirname(__file__))
import economy_model_v2 as v2
import economy_model_v3 as v3

RUNS_PER_DAY = 2
ASK = 1.1
LEVELS_START, LEVELS_FULL = 3, 22
OPERATORS_START, OPERATORS_FULL, OPERATORS_BY = 1, 9, 30

def camp_tier(n):
    camp = v2.deepest(n) // 10 * 10
    return v2.tier_of(max(1, camp))

def operators(n):
    return OPERATORS_START + round((OPERATORS_FULL - OPERATORS_START) * min(1.0, (n - 1) / (OPERATORS_BY - 1)))

def bill(n, levels, lmd, exp, salary, sal_exp=1.0):
    idx = v2.INCOME_INDEX[camp_tier(n) - 1]
    return lmd * levels * idx ** exp * ASK + salary * idx ** sal_exp * operators(n)

def ledger(lmd, exp, salary, sal_exp=1.0, show=False):
    """The v3 ledger with the bill paid first every day. Returns rows and the
    bill's share of income per checkpoint."""
    fixed = v2.BASE_FULL + v2.OPERATORS * (v2.OPERATOR_FIXED + v2.OPERATOR_FEED)
    fixed_left, research_left = fixed, dict(v2.RESEARCH_BY_TIER)
    s = dict(fixed=0, research=0, proj=0, voy=0, bill=0)
    cum = 0.0; rows = []; shares = {}; debt_runs = 0
    for n in range(1, 101):
        inc = v3.run_income(n); cum += inc; cash = inc
        levels = LEVELS_START + (LEVELS_FULL - LEVELS_START) * (1 - fixed_left / fixed)
        b = bill(n, levels, lmd, exp, salary, sal_exp) / RUNS_PER_DAY   # half a day per run
        s["bill"] += b; cash -= b
        shares[n] = b / inc
        if n >= 7:
            c = 2 * v2.PROJECT_M * v2.INCOME_INDEX[v2.tier_of(max(1, (v2.deepest(n - 1) - 1) // 10 * 10 + 1)) - 1]
            s["proj"] += c; cash -= c
        if n >= 10 and n % 6 == 0: s["voy"] += v2.VOYAGE; cash -= v2.VOYAGE
        pay = min(max(cash, 0), fixed_left); fixed_left -= pay; s["fixed"] += pay; cash -= pay
        for t in research_left:
            if v2.deepest(n) >= v2.RESEARCH_GATE[t] and n >= 7 and cash > 0:
                pay = min(cash, research_left[t]); research_left[t] -= pay; s["research"] += pay; cash -= pay
        surplus = cum - sum(s.values())
        if surplus < 0: debt_runs += 1
        if n in (1, 3, 5, 10, 15, 20, 30, 40, 50, 60, 80, 100):
            rows.append((n, v2.deepest(n), camp_tier(n), f"{levels:.0f}", operators(n), v3.k(inc * RUNS_PER_DAY),
                         v3.k(b * RUNS_PER_DAY), f"{b / inc * 100:.0f}%", v3.k(s["bill"]), v3.k(s["fixed"]), v3.k(s["research"]),
                         v3.k(surplus) if surplus > 1000 else "不足"))
    done_fixed = next((n for n in range(1, 101) if False), None)
    return rows, shares, surplus, debt_runs

HEAD = ["局", "最深", "档", "设施级", "干员", "日收入(2局)", "日开销", "占比", "累计日账", "固定花销", "永久研究", "余额"]

CANDIDATES = [
    ("现行 1500×指数^1.8，薪资 300×指数", 1500, 1.8, 300, 1.0),
    ("候选 A 9000×指数^1.0，薪资 3000×指数", 9000, 1.0, 3000, 1.0),
    ("候选 B 8000×指数^1.2，薪资 3000×指数", 8000, 1.2, 3000, 1.0),
    ("候选 C 7000×指数^1.25，薪资 4000×指数", 7000, 1.25, 4000, 1.0),
]

if __name__ == "__main__":
    probe = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "probe_2026-11-13")
    v3.FLOOR = v3.load(probe)
    v3.REGIONS = [r for r in ["mine", "city", "snow", "siracusa"] if r in v3.FLOOR]
    picks = CANDIDATES
    if len(sys.argv) > 2:
        lmd, exp, sal = float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
        picks = [(f"{lmd:.0f}×指数^{exp}，薪资 {sal:.0f}×指数", lmd, exp, sal, 1.0)]
    for name, lmd, exp, sal, se in picks:
        rows, shares, surplus, debt = ledger(lmd, exp, sal, se)
        print(f"## {name}\n")
        v2.table(HEAD, rows)
        print(f"- 第 21–100 局日账占收入：{min(shares[n] for n in range(21, 101)) * 100:.0f}%–{max(shares[n] for n in range(21, 101)) * 100:.0f}%；余额为负的局数 {debt}\n")
