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
}

@export var stat: Stat = Stat.MAX_HP_PCT
@export var amount: float = 0.0
@export var trigger: Trigger = Trigger.NONE

static func stat_mod(p_stat: Stat, p_amount: float) -> ItemModifier:
	var mod := ItemModifier.new()
	mod.stat = p_stat
	mod.amount = p_amount
	return mod

static func trigger_mod(p_trigger: Trigger) -> ItemModifier:
	var mod := ItemModifier.new()
	mod.trigger = p_trigger
	return mod

func describe() -> String:
	if trigger != Trigger.NONE:
		match trigger:
			Trigger.SWORD_WAVE:
				return "幼狼之牙 · 剑气：普攻命中 3 次，下一刀附带 150% 法术攻击力的穿透剑气（法术伤害）"
			Trigger.LOW_HP_SHIELD_ONCE_PER_FLOOR:
				return "血量过低时免疫一次伤害（每层限一次）"
		return ""
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
