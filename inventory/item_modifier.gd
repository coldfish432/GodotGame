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
	Trigger.TWIN_WAVE: "双生剑气：释放剑气时，再向 ±20° 发出两道 50% 伤害的剑气",
	Trigger.EMBER: "余烬：剑气使敌人灼烧 4 秒，每 0.5 秒受到 10% 法术攻击力的法术伤害",
	Trigger.ARTS_EDGE: "源石刃：普攻附带 18% 法术攻击力的法术伤害",
	Trigger.VEIN_BURST: "源石爆裂：击杀敌人时 30% 概率爆裂，2.5 米内敌人受到 100% 法术攻击力的法术伤害（不连锁）",
	Trigger.AFTERIMAGE: "残影：闪避穿过的敌人受到 120% 攻击力的物理伤害",
	Trigger.SHIELD_BASH: "盾击：格挡或护盾吸收伤害后 3 秒内，下一次攻击追加 150% 防御值的物理伤害",
	Trigger.THORNS: "尖刺：受到攻击时，对攻击者造成 80% 防御值的物理伤害",
	Trigger.MOON_WAVE: "月下：暴击时 35% 概率射出一道 50% 伤害的剑气（不消耗充能、不自我连锁）",
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
	if detailed:
		var low := ItemModifier.stat_mod(stat, float(FieldCatalog.AFFIX_AMOUNTS[stat]) * TIER_SCALES[0]).describe()
		var high := ItemModifier.stat_mod(stat, float(FieldCatalog.AFFIX_AMOUNTS[stat]) * TIER_SCALES[2]).describe()
		text += "（范围 %s ~ %s）" % [low.split(" ")[-1], high.split(" ")[-1]]
	return text

func describe() -> String:
	if trigger != Trigger.NONE:
		match trigger:
			Trigger.SWORD_WAVE:
				return "幼狼之牙 · 剑气：普攻命中 3 次，下一刀附带 150% 法术攻击力的穿透剑气（法术伤害）"
			Trigger.LOW_HP_SHIELD_ONCE_PER_FLOOR:
				return "血量过低时免疫一次伤害（每层限一次）"
		return str(TRIGGER_TEXT.get(trigger, ""))
	if is_equal_approx(amount, 0.0):
		return ""
	match stat:
		Stat.MAX_HP_PCT:
			return "生命上限 %+.0f%%" % (amount * 100.0)
		Stat.MOVE_SPEED_PCT:
			return "移动速度 %+.0f%%" % (amount * 100.0)
		Stat.BLADE_COOLDOWN_PCT:
			return "近战冷却 %+.0f%%" % (amount * 100.0)
		Stat.GOLD_GAIN_PCT:
			return "金币获取 %+.0f%%" % (amount * 100.0)
		Stat.POTION_CAPACITY_FLAT:
			return "药瓶上限 %+d" % int(amount)
		Stat.ATTACK_SPEED_PCT:
			return "攻速 %+.0f" % (amount * 100.0)
		Stat.ATK_PCT:
			return "攻击力 %+.0f%%" % (amount * 100.0)
		Stat.ARTS_PCT:
			return "法术攻击力 %+.0f%%" % (amount * 100.0)
		Stat.DEF_FLAT:
			return "防御 %+.0f" % amount
		Stat.RES_FLAT:
			return "法抗 %+.0f" % amount
		Stat.CRIT_RATE:
			return "暴击率 %+.0f%%" % (amount * 100.0)
		Stat.CRIT_DMG:
			return "暴击伤害 %+.0f%%" % (amount * 100.0)
	return ""
