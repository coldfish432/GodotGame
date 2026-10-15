class_name ItemModifier
extends Resource

## A general stat/trigger modifier a named weapon or relic-tier Item can
## carry, layered on top of the existing flat "power" formula — plain loot
## keeps using power only; named/relic items add these for real,
## sometimes-tradeoff build-shaping effects (the "魔改肉鸽遗物" ask: an
## Integrated-Strategies-style relic pattern — name, one-line hook, one real
## effect — reimplemented as original items, not copies of actual relics).

enum Stat {
	MAX_HP_PCT,
	MOVE_SPEED_PCT,
	BLADE_COOLDOWN_PCT,
	GOLD_GAIN_PCT,
	POTION_CAPACITY_FLAT,
	## Attack rate, not cooldown: interval = base / (1 + total). Appended last
	## so saved stat ids keep their meaning.
	ATTACK_SPEED_PCT,
	## Stats from 局内构筑与数值策划案 §3, appended for the same reason.
	ATK_PCT,
	ARTS_PCT,
	DEF_FLAT,
	RES_FLAT,
	CRIT_RATE,
	CRIT_DMG,
}

enum Trigger {
	NONE,
	LOW_HP_SHIELD_ONCE_PER_FLOOR,
	SWORD_WAVE,
	## Special-equipment effects (SpecialGear): each deals damage of its own.
	## Appended so saved trigger ids keep their meaning.
	CLEAVE,
	TWIN_WAVE,
	EMBER,
	ARTS_EDGE,
	VEIN_BURST,
	AFTERIMAGE,
	SHIELD_BASH,
	THORNS,
	MOON_WAVE,
}

const TRIGGER_TEXT := {
	Trigger.CLEAVE: "横扫：普攻对目标 1.8 米内其他敌人造成 50% 伤害",
	Trigger.TWIN_WAVE: "双生：释放技能时，剑气再向 ±20° 分出两道 50% 伤害的剑气；绝影打击次数 +1",
	Trigger.EMBER: "余烬：技能命中使敌人灼烧 4 秒，每 0.5 秒受到 10% 法术攻击力的法术伤害",
	Trigger.ARTS_EDGE: "源石刃：普攻附带 18% 法术攻击力的法术伤害",
	Trigger.VEIN_BURST: "源石爆裂：击杀敌人时 30% 概率爆裂，2.5 米内敌人受到 100% 法术攻击力的法术伤害（不连锁）",
	Trigger.AFTERIMAGE: "残影：闪避穿过的敌人受到 120% 攻击力的物理伤害",
	Trigger.SHIELD_BASH: "盾击：格挡或护盾吸收伤害后 3 秒内，下一次攻击追加 150% 防御值的物理伤害",
	Trigger.THORNS: "尖刺：受到攻击时，对攻击者造成 80% 防御值的物理伤害",
	Trigger.MOON_WAVE: "月下：暴击时 35% 概率追加一次 50% 伤害的技能攻击（剑气 / 绝影斩击；不消耗充能、不自我连锁）",
}

@export var stat: Stat = Stat.MAX_HP_PCT
@export var amount: float = 0.0
@export var trigger: Trigger = Trigger.NONE
## Roll quality of a random affix: 0/1/2 shown as Ⅰ/Ⅱ/Ⅲ, at 70% / 100% / 130%
## of the stat's base size (装备与背包界面调研 §5.7, after PoE/Last Epoch tiers).
## −1 marks a fixed modifier (a special item's built-in cost), which has no tier.
@export var tier: int = 1

const TIER_SCALES := [0.7, 1.0, 1.3]
const TIER_MARKS := ["Ⅰ", "Ⅱ", "Ⅲ"]
## Each tier rolls inside its own band of the stat's base size (装备前缀策划案
## §2.8): the averages stay TIER_SCALES.
const TIER_RANGES := [[0.6, 0.8], [0.9, 1.1], [1.2, 1.4]]
## Intrinsic stats and 技能强化 roll within ±20% of their midpoint (§2.8).
const SPREAD := 0.2
const SKILL_BOOST := 0.25

## The midpoint an intrinsic was rolled around; 0 for anything saved before
## values rolled (it then counts as fixed).
@export var mid: float = 0.0

## A random affix of `tier`, its size rolled inside the tier's band.
static func roll_affix(p_stat: Stat, p_tier: int, rng: RandomNumberGenerator) -> ItemModifier:
	var band: Array = TIER_RANGES[clampi(p_tier, 0, 2)]
	var mod := stat_mod(p_stat, float(FieldCatalog.AFFIX_AMOUNTS[p_stat]) * rng.randf_range(band[0], band[1]))
	mod.tier = p_tier
	return mod

## An intrinsic stat rolled within ±SPREAD of `p_mid`.
static func roll_intrinsic(p_stat: Stat, p_mid: float, rng: RandomNumberGenerator) -> ItemModifier:
	var mod := stat_mod(p_stat, p_mid * rng.randf_range(1.0 - SPREAD, 1.0 + SPREAD))
	mod.mid = p_mid
	mod.tier = GearCatalog.IMPLICIT_TIER
	return mod

## 技能强化 (was 剑气强化): skill damage, rolled within ±SPREAD of 25%.
static func roll_skill_boost(rng: RandomNumberGenerator) -> ItemModifier:
	var mod := trigger_mod(Trigger.SWORD_WAVE)
	mod.amount = SKILL_BOOST * rng.randf_range(1.0 - SPREAD, 1.0 + SPREAD)
	mod.mid = SKILL_BOOST
	return mod

## Skill damage this 技能强化 gives; old saves carry no amount and mean 25%.
func skill_boost() -> float:
	return amount if amount > 0.0 else SKILL_BOOST

## The [low, high] this line can roll in, or [] when it is fixed (a special
## item's cost, built-in triggers, intrinsics saved before values rolled).
func roll_range() -> Array:
	if trigger == Trigger.SWORD_WAVE: return [SKILL_BOOST * (1.0 - SPREAD), SKILL_BOOST * (1.0 + SPREAD)]
	if trigger != Trigger.NONE: return []
	if is_random_affix():
		var base := float(FieldCatalog.AFFIX_AMOUNTS[stat])
		var band: Array = TIER_RANGES[clampi(tier, 0, 2)]
		return [base * band[0], base * band[1]]
	if tier == GearCatalog.IMPLICIT_TIER and not is_zero_approx(mid):
		var a := mid * (1.0 - SPREAD)
		var b := mid * (1.0 + SPREAD)
		return [minf(a, b), maxf(a, b)]
	return []

func is_rollable() -> bool:
	return not roll_range().is_empty()

## Rerolls the value inside its range (校准 / 精调, §2.8).
func reroll(rng: RandomNumberGenerator) -> void:
	var r := roll_range()
	if r.is_empty(): return
	amount = rng.randf_range(float(r[0]), float(r[1]))

## Where the value sits in its range, 0 (worst) to 1 (best); 0.5 when fixed.
## Every rollable stat here is better higher (costs are fixed, tier −1).
func roll_position() -> float:
	var r := roll_range()
	if r.is_empty() or is_equal_approx(float(r[0]), float(r[1])): return 0.5
	return clampf((amount - float(r[0])) / (float(r[1]) - float(r[0])), 0.0, 1.0)

## "+5%" / "+2.7%": whole numbers from 10 up, one decimal below (§2.8).
static func pct(value: float) -> String:
	var shown := value * 100.0
	if absf(shown) >= 10.0 or absf(shown - roundf(shown)) < 0.05: return "%+d%%" % roundi(shown)
	return "%+.1f%%" % shown

static func stat_mod(p_stat: Stat, p_amount: float) -> ItemModifier:
	var mod := ItemModifier.new()
	mod.stat = p_stat
	mod.amount = p_amount
	return mod

static func trigger_mod(p_trigger: Trigger) -> ItemModifier:
	var mod := ItemModifier.new()
	mod.trigger = p_trigger
	return mod

## The tier an amount corresponds to, for affixes saved before tiers existed.
static func infer_tier(p_stat: Stat, p_amount: float) -> int:
	var base := float(FieldCatalog.AFFIX_AMOUNTS.get(p_stat, 0.0))
	if is_zero_approx(base): return 1
	var ratio := absf(p_amount / base)
	var best := 1
	for i in range(TIER_SCALES.size()):
		if absf(TIER_SCALES[i] - ratio) < absf(TIER_SCALES[best] - ratio): best = i
	return best

func is_random_affix() -> bool:
	return trigger == Trigger.NONE and tier >= 0 and FieldCatalog.AFFIX_AMOUNTS.has(stat)

## With `detailed` (Alt held): the tier and the range this stat can roll in.
func describe_detailed(detailed: bool) -> String:
	var text := describe()
	if text.is_empty() or not is_random_affix(): return text
	text += "  " + TIER_MARKS[clampi(tier, 0, 2)]
	if detailed: text += range_text()
	return text

## "（范围 a ~ b）" for a line that rolls, "" otherwise (shown with Alt).
func range_text() -> String:
	var r := roll_range()
	if r.is_empty(): return ""
	var low := duplicate() as ItemModifier
	var high := duplicate() as ItemModifier
	low.amount = float(r[0])
	high.amount = float(r[1])
	return "（范围 %s ~ %s）" % [low.describe().split(" ")[-1], high.describe().split(" ")[-1]]

func describe() -> String:
	if trigger != Trigger.NONE:
		match trigger:
			Trigger.SWORD_WAVE:
				return "技能强化：技能伤害 " + pct(skill_boost())
			Trigger.LOW_HP_SHIELD_ONCE_PER_FLOOR:
				return "血量过低时免疫一次伤害（每层限一次）"
		return str(TRIGGER_TEXT.get(trigger, ""))
	if is_equal_approx(amount, 0.0):
		return ""
	match stat:
		Stat.MAX_HP_PCT:
			return "生命上限 " + pct(amount)
		Stat.MOVE_SPEED_PCT:
			return "移动速度 " + pct(amount)
		Stat.BLADE_COOLDOWN_PCT:
			return "近战冷却 " + pct(amount)
		Stat.GOLD_GAIN_PCT:
			return "金币获取 " + pct(amount)
		Stat.POTION_CAPACITY_FLAT:
			return "药剂回复 %+d%%" % roundi(amount * BaseCatalog.POTION_HEAL_PER_CAP * 100.0)
		Stat.ATTACK_SPEED_PCT:
			return "攻速 %+.0f" % (amount * 100.0)
		Stat.ATK_PCT:
			return "攻击力 " + pct(amount)
		Stat.ARTS_PCT:
			return "法术攻击力 " + pct(amount)
		Stat.DEF_FLAT:
			return "防御 %+.0f" % amount
		Stat.RES_FLAT:
			return "法抗 %+.0f" % amount
		Stat.CRIT_RATE:
			return "暴击率 " + pct(amount)
		Stat.CRIT_DMG:
			return "暴击伤害 " + pct(amount)
	return ""
