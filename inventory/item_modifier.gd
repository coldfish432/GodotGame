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
	## Flat affixes (复利数值改造清单 C), appended for the same reason. With
	## DEF_FLAT they grow ×1.30 a tier (Scaling.flat_scale).
	ATK_FLAT,
	ARTS_FLAT,
	HP_FLAT,
	## Slot leanings (装备部位拆分与数值案 §4): legs, head, amulet, feet.
	EVASION,
	SKILL_CD_PCT,
	SKILL_PCT,
	STAMINA_REGEN_PCT,
	DASH_COST_PCT,
	## Intrinsics only (底材固有属性表 v1.0): operator experience and the
	## chance a drop is gear.
	EXP_GAIN_PCT,
	DROP_RATE_PCT,
	## 属性伤害与地区装备策划案 v1.1 (appended so saved ids keep their meaning):
	## elemental damage added and converted, its bonuses, damage over time,
	## the five resistances (§3, §6, §7).
	ADD_BURN, ADD_COLD, ADD_CORR, ADD_NERVE,
	CONV_BURN, CONV_COLD, CONV_CORR, CONV_NERVE,
	BURN_DMG_PCT, COLD_DMG_PCT, CORR_DMG_PCT, NERVE_DMG_PCT, NECRO_DMG_PCT,
	BLEED_CHANCE, BURNOUT_CHANCE, FROST_CHANCE, ROT_CHANCE, NECRO_CHANCE, DOT_PCT, DOT_DUR_PCT,
	RES_BURN, RES_COLD, RES_CORR, RES_NERVE, RES_BLEED, RES_ALL_ELEM, RES_CAP,
	## Regional affixes (§8), each region's own.
	CROWD_DMG, CROWD_DR, CONTAM_SLOW, BLAST_TAKEN, ROT_FULL_ASPD, KILL_HEAL, ORE_ATK,
	AMBUSH_DMG, MELEE_TAKEN, HEAL_PCT, DASH_DEF, CHAIN_DMG, DOT_TAKEN_DUR,
	FULL_HP_DMG, COLD_SLOW, FIRE_REGEN, LONE_EVASION, FREEZE_TAKEN, LONE_SKILL,
	STUNNED_DMG, LOW_HP_DMG, DEBT_SLOW, ELITE_TAKEN, BACK_TAKEN, ELITE_KILL_ASPD, DEBT_DMG,
	## Orange signatures (§8): one each region and group, fixed.
	SIG_CASCADE, SIG_CARRIER, SIG_RESONANCE, SIG_BLAZE, SIG_SHIELDWALL, SIG_ESCORT,
	SIG_SHATTER, SIG_TREELINE, SIG_FIRSTBLOOD, SIG_RECKONING, SIG_SILENCE, SIG_BLOODPRICE,
	## 爆发族 / 首领件 lines.
	BUILD_PCT,
}

## The sheet key each of the stats above adds to (Player._recompute_stats).
const SHEET_KEYS := {
	Stat.ADD_BURN: "add_burn", Stat.ADD_COLD: "add_cold", Stat.ADD_CORR: "add_corr", Stat.ADD_NERVE: "add_nerve",
	Stat.CONV_BURN: "conv_burn", Stat.CONV_COLD: "conv_cold", Stat.CONV_CORR: "conv_corr", Stat.CONV_NERVE: "conv_nerve",
	Stat.BURN_DMG_PCT: "burn_dmg_pct", Stat.COLD_DMG_PCT: "cold_dmg_pct", Stat.CORR_DMG_PCT: "corr_dmg_pct",
	Stat.NERVE_DMG_PCT: "nerve_dmg_pct", Stat.NECRO_DMG_PCT: "necro_dmg_pct",
	Stat.BLEED_CHANCE: "bleed_chance", Stat.BURNOUT_CHANCE: "burnout_chance", Stat.FROST_CHANCE: "frost_chance",
	Stat.ROT_CHANCE: "rot_chance", Stat.NECRO_CHANCE: "necro_chance", Stat.DOT_PCT: "dot_pct", Stat.DOT_DUR_PCT: "dot_dur_pct",
	Stat.RES_BURN: "res_burn", Stat.RES_COLD: "res_cold", Stat.RES_CORR: "res_corr", Stat.RES_NERVE: "res_nerve",
	Stat.RES_BLEED: "res_bleed", Stat.RES_ALL_ELEM: "res_all_elem", Stat.RES_CAP: "res_cap",
	Stat.CROWD_DMG: "crowd_dmg", Stat.CROWD_DR: "crowd_dr", Stat.CONTAM_SLOW: "contam_pct", Stat.BLAST_TAKEN: "blast_taken",
	Stat.ROT_FULL_ASPD: "rot_full_aspd", Stat.KILL_HEAL: "kill_heal", Stat.ORE_ATK: "ore_atk",
	Stat.AMBUSH_DMG: "ambush_dmg", Stat.MELEE_TAKEN: "melee_taken", Stat.HEAL_PCT: "heal_pct", Stat.DASH_DEF: "dash_def",
	Stat.CHAIN_DMG: "chain_dmg", Stat.DOT_TAKEN_DUR: "dot_taken_dur",
	Stat.FULL_HP_DMG: "full_hp_dmg", Stat.COLD_SLOW: "cold_pct", Stat.FIRE_REGEN: "fire_regen", Stat.LONE_EVASION: "lone_evasion",
	Stat.FREEZE_TAKEN: "freeze_taken", Stat.LONE_SKILL: "lone_skill",
	Stat.STUNNED_DMG: "stunned_dmg", Stat.LOW_HP_DMG: "low_hp_dmg", Stat.DEBT_SLOW: "debt_pct", Stat.ELITE_TAKEN: "elite_taken",
	Stat.BACK_TAKEN: "back_taken", Stat.ELITE_KILL_ASPD: "elite_kill_aspd", Stat.DEBT_DMG: "debt_dmg",
	Stat.SIG_CASCADE: "sig_cascade", Stat.SIG_CARRIER: "sig_carrier", Stat.SIG_RESONANCE: "sig_resonance",
	Stat.SIG_BLAZE: "sig_blaze", Stat.SIG_SHIELDWALL: "sig_shieldwall", Stat.SIG_ESCORT: "sig_escort",
	Stat.SIG_SHATTER: "sig_shatter", Stat.SIG_TREELINE: "sig_treeline", Stat.SIG_FIRSTBLOOD: "sig_firstblood",
	Stat.SIG_RECKONING: "sig_reckoning", Stat.SIG_SILENCE: "sig_silence", Stat.SIG_BLOODPRICE: "sig_bloodprice",
	Stat.BUILD_PCT: "build_pct",
}
## How each new stat reads: %s is its value (ItemModifier.pct, sign kept);
## "%d" lines are whole points (resistances).
const TEXTS := {
	Stat.ADD_BURN: "命中附加 %s 灼燃伤害", Stat.ADD_COLD: "命中附加 %s 寒冷伤害", Stat.ADD_CORR: "命中附加 %s 侵蚀伤害", Stat.ADD_NERVE: "命中附加 %s 神经伤害",
	Stat.CONV_BURN: "命中伤害的 %s 转为灼燃", Stat.CONV_COLD: "命中伤害的 %s 转为寒冷", Stat.CONV_CORR: "命中伤害的 %s 转为侵蚀", Stat.CONV_NERVE: "命中伤害的 %s 转为神经",
	Stat.BURN_DMG_PCT: "灼燃伤害 %s", Stat.COLD_DMG_PCT: "寒冷伤害 %s", Stat.CORR_DMG_PCT: "侵蚀伤害 %s", Stat.NERVE_DMG_PCT: "神经伤害 %s", Stat.NECRO_DMG_PCT: "凋亡伤害 %s",
	Stat.BLEED_CHANCE: "命中 %s 几率造成流血", Stat.BURNOUT_CHANCE: "命中 %s 几率造成灼烧", Stat.FROST_CHANCE: "命中 %s 几率造成冻伤",
	Stat.ROT_CHANCE: "命中 %s 几率造成源石腐蚀", Stat.NECRO_CHANCE: "命中 %s 几率造成凋亡", Stat.DOT_PCT: "持续伤害 %s", Stat.DOT_DUR_PCT: "持续时间 %s",
	Stat.RES_BURN: "灼燃抗性 %+d", Stat.RES_COLD: "寒冷抗性 %+d", Stat.RES_CORR: "侵蚀抗性 %+d", Stat.RES_NERVE: "神经抗性 %+d",
	Stat.RES_BLEED: "流血抗性 %+d", Stat.RES_ALL_ELEM: "全元素抗性 %+d", Stat.RES_CAP: "元素抗性上限 %+d",
	Stat.CROWD_DMG: "周围每有 1 个敌人，伤害 %s（最多 5 个）", Stat.CROWD_DR: "周围每有 1 个敌人，减伤 %s（最多 5 个）",
	Stat.CONTAM_SLOW: "源石污染上涨 %s", Stat.BLAST_TAKEN: "受到爆炸伤害 %s", Stat.ROT_FULL_ASPD: "目标源石腐蚀叠满时，攻速 %s",
	Stat.KILL_HEAL: "击杀回复 %s 最大生命", Stat.ORE_ATK: "携带源石原矿时，伤害 %s",
	Stat.AMBUSH_DMG: "对未察觉的敌人，第一击伤害 %s", Stat.MELEE_TAKEN: "受到近战伤害 %s", Stat.HEAL_PCT: "受到治疗 %s",
	Stat.DASH_DEF: "闪避后 1 秒内防御 %s", Stat.CHAIN_DMG: "连续命中同一目标，每次伤害 %s（最多 5 层）", Stat.DOT_TAKEN_DUR: "受到的持续伤害时长 %s",
	Stat.FULL_HP_DMG: "对满血敌人伤害 %s", Stat.COLD_SLOW: "寒冷上涨 %s", Stat.FIRE_REGEN: "火堆旁每秒回复 %s 最大生命",
	Stat.LONE_EVASION: "物理闪避 %s，附近没有其他敌人时再翻倍", Stat.FREEZE_TAKEN: "受到冻结的时长 %s", Stat.LONE_SKILL: "附近没有其他敌人时，技能伤害 %s",
	Stat.STUNNED_DMG: "对晕眩中的敌人伤害 %s", Stat.LOW_HP_DMG: "对生命低于 25%% 的敌人伤害 %s", Stat.DEBT_SLOW: "血债上涨 %s",
	Stat.ELITE_TAKEN: "受到精英的伤害 %s", Stat.BACK_TAKEN: "受到来自背后的伤害 %s", Stat.ELITE_KILL_ASPD: "击杀精英后 6 秒内攻速 %s",
	Stat.DEBT_DMG: "血债 60 以上时，伤害 %s",
	Stat.SIG_CASCADE: "晶簇裂解：侵蚀爆发波及 3 米内的敌人，各降防一层", Stat.SIG_CARRIER: "感染者的韧性：污染 60 以上时，防御 +20%",
	Stat.SIG_RESONANCE: "源石共鸣：污染每有 10 点，伤害 +2%", Stat.SIG_BLAZE: "火场：灼燃爆发在原地留下 3 秒地火",
	Stat.SIG_SHIELDWALL: "近卫局盾阵：生命低于 35% 时，受到的伤害 −25%", Stat.SIG_ESCORT: "押运守则：闪避成功后，下一次攻击必定暴击",
	Stat.SIG_SHATTER: "碎冰：冻结中的敌人受到的下一击 +80%", Stat.SIG_TREELINE: "林线行者：寒冷 60 以上时，闪避 +8%",
	Stat.SIG_FIRSTBLOOD: "猎手先机：技能命中满血敌人时，返还 30% 冷却", Stat.SIG_RECKONING: "家族清算：带着流血死去的敌人，把流血传给 3 米内的敌人",
	Stat.SIG_SILENCE: "缄默：血债每有 30 点，减伤 +3%", Stat.SIG_BLOODPRICE: "血的价钱：血债每有 10 点，赤金掉落 +2%",
	Stat.BUILD_PCT: "损伤累积 %s",
}
## Orange signatures (and 抗性上限): the text is the whole line.
const SIGNATURES := [Stat.SIG_CASCADE, Stat.SIG_CARRIER, Stat.SIG_RESONANCE, Stat.SIG_BLAZE, Stat.SIG_SHIELDWALL, Stat.SIG_ESCORT,
	Stat.SIG_SHATTER, Stat.SIG_TREELINE, Stat.SIG_FIRSTBLOOD, Stat.SIG_RECKONING, Stat.SIG_SILENCE, Stat.SIG_BLOODPRICE]
const RESISTS := [Stat.RES_BURN, Stat.RES_COLD, Stat.RES_CORR, Stat.RES_NERVE, Stat.RES_BLEED, Stat.RES_ALL_ELEM]

static func is_signature(p_stat: int) -> bool:
	return p_stat in SIGNATURES

## Flat stats whose size follows the item's tier (清单 C). RES_FLAT is a
## resistance share already and stays the same at every depth.
const FLAT_STATS := [Stat.DEF_FLAT, Stat.ATK_FLAT, Stat.ARTS_FLAT, Stat.HP_FLAT]

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
## The band a random affix rolls in: its item's rarity on the ladder, grey to
## orange (Scaling.BANDS; 属性伤害与地区装备策划案 v1.1 §2.2). −1 marks a fixed modifier (a special item's built-in cost).
@export var tier: int = 1
## What the base size is multiplied by: the item tier's flat growth for flat
## stats (Scaling.flat_scale), 1 for everything else.
@export var scale: float = 1.0

## White / blue / gold sizes, for affixes saved before tiers (always before the
## ladder too, so Item._migrate_ladder moves them on afterwards).
const TIER_SCALES := [0.7, 1.0, 1.3]
const TIER_RANGES := Scaling.BANDS
## Intrinsic stats and 技能强化 roll within ±20% of their midpoint (§2.8).
const SPREAD := 0.2
const SKILL_BOOST := 0.25

## The midpoint an intrinsic was rolled around; 0 for anything saved before
## values rolled (it then counts as fixed).
@export var mid: float = 0.0
## The rarity band an intrinsic rolls in (底材固有属性表 v1.0: intrinsics
## fluctuate like affixes); −1 for intrinsics rolled ±SPREAD before that.
@export var band: int = -1

## A random affix on an item of `rarity` and `item_tier`, rolled in the
## rarity's band at `position` (Scaling.roll_position; −1 rolls evenly);
## `slot` picks the slot's own size (FieldCatalog.SLOT_AFFIX_AMOUNTS), kept in
## `scale` as a share of the base size.
static func roll_affix(p_stat: Stat, rarity: int, rng: RandomNumberGenerator, position: float = -1.0, item_tier: int = 1, slot: int = Item.Category.WEAPON) -> ItemModifier:
	var at := rng.randf() if position < 0.0 else position
	var mod := stat_mod(p_stat, 0.0)
	mod.tier = clampi(rarity, 0, Item.RARITY_MAX)
	mod.scale = (Scaling.flat_scale(item_tier) if p_stat in FLAT_STATS else 1.0) * FieldCatalog.slot_ratio(p_stat, slot)
	mod.amount = float(FieldCatalog.AFFIX_AMOUNTS[p_stat]) * mod.scale * Scaling.band_value(rarity, at)
	return mod

## An intrinsic stat around `p_mid` (the blue middle): in the item's rarity
## band at `position` (−1 rolls evenly) when `rarity` ≥ 0, else ±SPREAD.
## A cost (a drawback) does not roll (底材固有属性表 v1.0).
static func roll_intrinsic(p_stat: Stat, p_mid: float, rng: RandomNumberGenerator, rarity: int = -1, position: float = -1.0) -> ItemModifier:
	var mod := stat_mod(p_stat, p_mid)
	mod.tier = GearCatalog.IMPLICIT_TIER
	if is_cost(p_stat, p_mid): return mod
	mod.mid = p_mid
	if rarity >= 0:
		mod.band = clampi(rarity, 0, Item.RARITY_MAX)
		mod.amount = p_mid * Scaling.band_value(mod.band, rng.randf() if position < 0.0 else position)
	else:
		mod.amount = p_mid * rng.randf_range(1.0 - SPREAD, 1.0 + SPREAD)
	return mod

## Whether `value` of `stat` is a drawback: against the direction its affix
## rolls (技能冷却 and 闪避体力消耗 are better negative).
static func is_cost(p_stat: Stat, value: float) -> bool:
	return value * signf(float(FieldCatalog.AFFIX_AMOUNTS.get(p_stat, 1.0))) < 0.0

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
		var base := float(FieldCatalog.AFFIX_AMOUNTS[stat]) * scale
		var band: Array = TIER_RANGES[clampi(tier, 0, Item.RARITY_MAX)]
		return [base * band[0], base * band[1]]
	if tier == GearCatalog.IMPLICIT_TIER and not is_zero_approx(mid):
		var low: float = float(Scaling.band(band)[0]) if band >= 0 else 1.0 - SPREAD
		var high: float = float(Scaling.band(band)[1]) if band >= 0 else 1.0 + SPREAD
		var a := mid * low
		var b := mid * high
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
			return "赤金获取 " + pct(amount)
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
		Stat.ATK_FLAT:
			return "攻击力 %+.0f" % amount
		Stat.ARTS_FLAT:
			return "法术攻击力 %+.0f" % amount
		Stat.HP_FLAT:
			return "生命 %+.0f" % amount
		Stat.EVASION:
			return "物理闪避 " + pct(amount)
		Stat.SKILL_CD_PCT:
			return "技能冷却 " + pct(amount)
		Stat.SKILL_PCT:
			return "技能伤害 " + pct(amount)
		Stat.STAMINA_REGEN_PCT:
			return "体力回复 " + pct(amount)
		Stat.DASH_COST_PCT:
			return "闪避体力消耗 " + pct(amount)
		Stat.EXP_GAIN_PCT:
			return "经验获取 " + pct(amount)
		Stat.DROP_RATE_PCT:
			return "装备掉率 " + pct(amount)
	if TEXTS.has(stat):
		var text: String = TEXTS[stat]
		if is_signature(stat): return text
		if text.contains("%+d"): return text % roundi(amount)
		return text % (pct(amount).trim_prefix("+") if text.begins_with("命中") else pct(amount))
	return ""
