class_name RelicCatalog
extends RefCounted

## The in-run relic pool (藏品). Every entry is a real 集成战略 collectible under
## its own name (用户 2026-10-03: 只用集成战略里有的藏品), checked against PRTS —
## see 局内构筑调研_集成战略藏品.md. `original` is its PRTS effect; `effect` is how
## it works here; numbers are rescaled where the original assumed a squad.
## There is no set or school system: a relic is just a relic (用户 2026-10-03).
## Collectibles that deal damage of their own are not here; that kind of
## effect belongs to special equipment (SpecialGear).
##
## stats: added straight into the player's sheet (CombatStats.KEYS).
## fx: named effect parameters, summed across owned relics and read by Player.
## kind: an internal category, used only so a choice spans different kinds of
## relic and so regions lean differently (策划案 §7); players never see it.

enum Rarity { COMMON, RARE, LEGEND }
const RARITY_NAMES := ["低", "中", "高"]
const RARITY_COLORS := [Color("c9d3db"), Color("72b8ff"), Color("f3b04a")]
## Offer weights per rarity (low / mid / high), by where the offer comes from.
const RARITY_WEIGHTS := {"device": [60.0, 30.0, 10.0], "cache": [65.0, 30.0, 5.0], "vault": [25.0, 50.0, 25.0]}
## How much more often each region offers a kind of relic (策划案 §7: the mine
## favours holding out, the city melee and blocking, the snow the opening blow).
const REGION_KIND_WEIGHT := {
	"mine": {"defense": 2.5, "life": 2.0},
	"city": {"attack": 2.0, "defense": 2.0, "tempo": 1.5},
	"snow": {"wave": 2.5, "attack": 1.5},
}
const REROLL_BASE := 25
const REROLL_STEP := 25
## Combat cache: one per segment once this much threat is defeated (normal 1, elite 3).
const CACHE_THREAT := 8
const ELITE_THREAT := 3
const SOURCE_BASE := "https://prts.wiki/w/"

static func all() -> Array[Dictionary]:
	return [
		# --- 攻击 ------------------------------------------------------------------
		_r("皇帝的恩宠", "attack", 0, "所有我方近战单位攻击力+15%", "攻击力 +15%", {"atk_pct": 0.15}),
		_r("贵族刺剑", "attack", 1, "所有我方近战单位攻击力+25%", "攻击力 +25%", {"atk_pct": 0.25}),
		_r("老近卫军之锋", "attack", 2, "所有我方近战单位攻击力+35%", "攻击力 +35%", {"atk_pct": 0.35}),
		_r("锈蚀刀片", "attack", 0, "所有敌方单位受到的物理伤害+15%", "造成的物理伤害 +15%", {"phys_dmg_pct": 0.15}),
		_r("\"复仇者\"", "attack", 2, "所有敌方单位受到的物理伤害+35%", "造成的物理伤害 +35%", {"phys_dmg_pct": 0.35}),
		_r("残破合影", "attack", 0, "所有敌方单位防御力-12%", "攻击无视目标 12% 防御", {"def_ignore": 0.12}),
		_r("迷迭香之拥", "attack", 2, "所有敌方单位防御力-30%", "攻击无视目标 30% 防御", {"def_ignore": 0.30}),
		_r("撕扯之手", "attack", 2, "【无畏者】【剑豪】【教官】攻击时无视目标70%的防御力", "攻击无视目标 70% 防御", {"def_ignore": 0.70}),
		_r("\"黑夜呢喃\"", "attack", 0, "所有敌方单位生命-10%", "敌人最大生命 −10%", {}, {"enemy_hp": -0.10}),
		_r("《大静谧》", "attack", 2, "所有敌方单位生命-20%", "敌人最大生命 −20%", {}, {"enemy_hp": -0.20}),
		_r("扼喉之手", "attack", 2, "【重射手】【神射手】【攻城手】的攻击会将生命值30%以下非领袖敌人强制击杀", "命中生命低于 30% 的普通敌人时直接击杀", {}, {"execute": 0.30}),
		_r("溃决之手", "attack", 2, "攻击伤害随目标生命下降最高+50%，并对生命20%以下的敌人强制击杀", "伤害随目标生命降低至多 +50%；命中生命低于 20% 的普通敌人时直接击杀", {}, {"execute": 0.20, "wounded_dmg": 0.50}),
		_r("荣耀绶带", "attack", 1, "所有我方单位仅阻挡1名敌人时，攻击力+100%", "6 米内只有 1 名敌人时攻击力 +60%", {}, {"lone_atk": 0.60}),
		_r("绿叶菜罐头", "attack", 0, "所有干员技能触发后1秒内攻击力+60%", "释放剑气后 1 秒内攻击力 +60%", {}, {"wave_burst_atk": 0.60}),
		_r("叙拉古人的愤怒", "attack", 1, "所有干员技能触发后1秒内攻击力+100%", "释放剑气后 1 秒内攻击力 +100%", {}, {"wave_burst_atk": 1.00}),
		_r("\"噤声\"", "attack", 1, "技能未开启时60秒内攻击力逐渐提升至最高+60%，每次技能结束时失去该加成", "没有释放剑气时，攻击力在 60 秒内逐渐提升至 +60%；释放剑气后归零", {}, {"build_atk": 0.60}),
		_r("轰鸣之手", "attack", 2, "每对一个单位造成伤害就使自身攻击力+15%，最高+150%，5秒未造成伤害则清空", "每次命中攻击力 +8%（至多 +80%）；3 秒没有命中则清空", {}, {"hit_stack_atk": 0.08}),
		_r("古乔治营养原浆", "attack", 0, "干员生命值越高攻击力越高，100%生命值时最多+30%", "生命越高攻击力越高，满血时 +30%", {}, {"full_hp_atk": 0.30}),
		_r("赏善郎", "attack", 1, "我方单位触发闪避或抵挡后，下次攻击造成的伤害+100%", "闪避或抵挡一次攻击后，下一次攻击伤害 +100%", {}, {"avenge": 1.00}),
		_r("《光耀卡西米尔》", "attack", 1, "干员触发闪避后6秒内攻击力+70%", "闪避一次攻击后 6 秒内攻击力 +70%", {}, {"evade_atk": 0.70}),
		_r("《归来》", "attack", 2, "干员触发闪避后6秒内攻击力+130%", "闪避一次攻击后 6 秒内攻击力 +130%", {}, {"evade_atk": 1.30}),
		_r("《拳经三问》", "attack", 1, "干员每使用过一次技能，自身攻击力+5%，最多叠加40层", "每释放一次剑气，本合同攻击力 +4%（至多 +40%）", {}, {"wave_stack_atk": 0.04}),
		_r("折戟-破釜沉舟", "attack", 1, "所有【近卫】干员防御力-40%，但攻击力+40%，攻击速度+30", "攻击力 +40%、攻速 +30；防御 −40%", {"atk_pct": 0.40, "aspd": 30.0, "def_pct": -0.40}),
		_r("死仇时代的恨意", "attack", 1, "所有友方单位和敌人攻击力+20%", "攻击力 +20%；敌人攻击力 +20%", {"atk_pct": 0.20}, {"enemy_atk": 0.20}),
		# --- 剑气 ------------------------------------------------------------------
		_r("显圣吊坠", "wave", 0, "所有我方远程单位攻击力+15%", "剑气伤害 +15%", {"wave_pct": 0.15}),
		_r("银餐叉", "wave", 1, "所有我方远程单位攻击力+25%", "剑气伤害 +25%", {"wave_pct": 0.25}),
		_r("损坏的左轮弹巢", "wave", 2, "所有我方远程单位攻击力+35%", "剑气伤害 +35%", {"wave_pct": 0.35}),
		_r("残弩-交叉火力", "wave", 1, "所有【狙击】干员生命-40%，但攻击力+40%", "剑气伤害 +40%；生命上限 −40%", {"wave_pct": 0.40, "hp_pct": -0.40}),
		_r("制式防暴用具", "wave", 0, "所有敌方单位受到的法术伤害+20%", "造成的法术伤害 +20%", {"arts_dmg_pct": 0.20}),
		_r("\"璀璨悲泣\"", "wave", 2, "所有敌方单位受到的法术伤害+40%", "造成的法术伤害 +40%", {"arts_dmg_pct": 0.40}),
		_r("断杖-苦难巫咒", "wave", 1, "所有【术师】干员生命-40%，但造成的法术伤害+70%", "造成的法术伤害 +70%；生命上限 −40%", {"arts_dmg_pct": 0.70, "hp_pct": -0.40}),
		_r("古高卢银币", "wave", 0, "所有干员初始技力+6", "进入每个区段时剑气充能 +1", {}, {"segment_charge": 1.0}),
		_r("《第二经济改革法》", "wave", 1, "所有干员初始技力+18", "进入每个区段时剑气已蓄满", {}, {"segment_charge": 9.0}),
		_r("香草沙士汽水", "wave", 0, "所有自然回复技能的技力恢复+0.2/s", "每 6 秒自动获得 1 点剑气充能", {}, {"auto_charge": 1.0 / 6.0}),
		_r("迷梦香精", "wave", 1, "所有自然回复技能的技力恢复+0.5/s", "每 3 秒自动获得 1 点剑气充能", {}, {"auto_charge": 1.0 / 3.0}),
		_r("折戟-浴血", "wave", 1, "所有【近卫】干员在攻击后获得2点技力", "连斩第三段命中时，剑气充能额外 +1", {}, {"finisher_charge": 1.0}),
		_r("积攒之手", "wave", 0, "部署费用-12，且击杀敌人后额外获得6点部署费用", "击杀敌人时剑气充能 +1，回复 10 体力", {}, {"kill_charge": 1.0}),
		# --- 节奏 ------------------------------------------------------------------
		_r("冰结的躯壳", "tempo", 0, "近战干员在受到伤害后5秒内，攻击速度+40", "受到伤害后 5 秒内攻速 +40", {}, {"hurt_aspd": 40.0}),
		_r("疗养体验卡", "tempo", 0, "所有干员部署后10秒内攻击速度+40", "脱战后再次出手的 10 秒内攻速 +40", {}, {"engage_aspd": 40.0}),
		_r("疗养特供卡", "tempo", 1, "所有干员部署后10秒内攻击速度+70", "脱战后再次出手的 10 秒内攻速 +70", {}, {"engage_aspd": 70.0}),
		_r("鸣脊兽", "tempo", 1, "所有我方单位技能未开启时40秒内攻速逐渐提升至最高+40，每次技能结束时失去该加成", "没有释放剑气时，攻速在 40 秒内逐渐提升至 +40；释放剑气后归零", {}, {"build_aspd": 40.0}),
		_r("老磨盘", "tempo", 1, "我方单位受到伤害后攻击速度+6（最多叠加10次）", "受到伤害后攻速 +6（本区段至多 10 次）", {}, {"hurt_stack_aspd": 6.0}),
		_r("紧急活性剂", "tempo", 1, "干员生命值越低攻速越快，30%生命值时最多+60", "生命越低攻速越快，30% 生命时 +60", {}, {"low_hp_aspd": 60.0}),
		_r("国王的新枪", "tempo", 0, "目标生命为1时，所有我方单位攻击速度+50", "生命低于 25% 时攻速 +50", {}, {"critical_aspd": 50.0}),
		_r("魔王的旗帜", "tempo", 0, "目标生命值达到上限时，所有干员攻击速度+30", "满血时攻速 +30", {}, {"full_aspd": 30.0}),
		_r("钝爪-振奋", "tempo", 1, "所有【先锋】干员的再部署时间-50%", "闪避冷却 −50%", {"dash_cd_pct": -0.50}),
		_r("\"断剑\"", "tempo", 1, "所有干员生命-30%，但再部署时间-50%", "闪避冷却 −50%、体力消耗 −10；生命上限 −30%", {"dash_cd_pct": -0.50, "dash_cost": -10.0, "hp_pct": -0.30}),
		_r("投币玩具", "tempo", 0, "每有5源石锭，所有我方单位攻击速度+3", "每 50 待交付报酬攻速 +3（至多 +30）", {}, {"gold_aspd": 3.0}),
		_r("骑士戒律·新编", "tempo", 1, "每有5源石锭，所有我方单位攻击速度+5", "每 50 待交付报酬攻速 +5（至多 +50）", {}, {"gold_aspd": 5.0}),
		_r("金酒之杯", "tempo", 2, "每有5源石锭，所有我方单位攻击速度+7", "每 50 待交付报酬攻速 +7（至多 +70）", {}, {"gold_aspd": 7.0}),
		_r("\"永夜的窥视\"", "tempo", 1, "所有干员攻击力+25%，攻击速度+25，但每秒流失25生命值", "攻击力 +25%、攻速 +25；每秒失去 0.6% 最大生命", {"atk_pct": 0.25, "aspd": 25.0}, {"drain": 0.006}),
		# --- 防御 ------------------------------------------------------------------
		_r("异铁小圆盾", "defense", 0, "所有我方单位防御力+15%", "防御 +25%", {"def_pct": 0.25}),
		_r("军团护心镜", "defense", 1, "所有我方单位防御力+25%", "防御 +40%", {"def_pct": 0.40}),
		_r("古旧的蒸汽甲胄", "defense", 2, "所有我方单位防御力+35%", "防御 +55%", {"def_pct": 0.55}),
		_r("开裂的束缚带", "defense", 0, "所有敌方单位攻击力-7%", "敌人攻击力 −7%", {}, {"enemy_atk": -0.07}),
		_r("奇渊面具", "defense", 1, "所有敌方单位攻击力-12%", "敌人攻击力 −12%", {}, {"enemy_atk": -0.12}),
		_r("教母的信物", "defense", 2, "所有敌方单位攻击力-17%", "敌人攻击力 −17%", {}, {"enemy_atk": -0.17}),
		_r("设计师量尺", "defense", 0, "所有我方单位获得15%物理闪避", "物理闪避 15%", {"evasion": 0.15}),
		_r("\"法术杀手\"", "defense", 0, "所有我方单位获得15%法术闪避", "法术闪避 15%", {"evasion_arts": 0.15}),
		_r("舞者手链", "defense", 1, "所有我方单位获得10%物理与法术闪避", "物理与法术闪避 10%", {"evasion": 0.10, "evasion_arts": 0.10}),
		_r("女皇之愿", "defense", 2, "所有我方单位获得15%物理与法术闪避", "物理与法术闪避 15%", {"evasion": 0.15, "evasion_arts": 0.15}),
		_r("《麻木与庸俗》", "defense", 0, "所有我方单位法术抗性+5", "法抗 +10", {"res": 10.0}),
		_r("皇族金胸针", "defense", 1, "所有我方单位法术抗性+15，且部署后抵挡一次伤害", "法抗 +15；每个区段的第一次伤害被抵挡", {"res": 15.0}, {"segment_blocks": 1.0}),
		_r("药枚", "defense", 0, "所有我方单位在部署时获得2层护盾", "进入每个区段时获得 2 层抵挡（各完全抵挡一次伤害）", {}, {"segment_blocks": 2.0}),
		_r("活木甲", "defense", 1, "所有我方近战单位部署时获得相当于最大生命50%的屏障", "进入每个区段时获得 50% 最大生命的屏障", {}, {"segment_shield": 0.50}),
		_r("墙眼", "defense", 1, "受到来自自身攻击范围以外的物理与法术伤害降低50%", "受到的远程攻击伤害 −50%", {}, {"ranged_taken": -0.50}),
		_r("古堡的子嗣", "defense", 1, "所有干员在场上停留100秒后防御力+300，法术抗性+30", "在同一区段停留 100 秒后，防御 +300、法抗 +30", {}, {"linger": 1.0}),
		_r("魔王的床榻", "defense", 0, "目标生命值达到上限时，所有干员防御力+20%，法术抗性+10", "满血时防御 +20%、法抗 +10", {}, {"full_def": 1.0}),
		_r("霜牡的肩甲", "defense", 1, "阻挡2名及以上敌人后，攻击力+40%，防御力+40%，持续30秒", "3 米内有 2 名及以上敌人时，攻击力与防御 +40%，持续 30 秒（之后 30 秒冷却）", {}, {"crowd_guard": 1.0}),
		_r("雪牝的护手", "defense", 2, "阻挡3名及以上敌人后，攻速+80，获得50%物理和法术闪避，持续30秒", "3 米内有 3 名及以上敌人时，攻速 +80、物理与法术闪避 50%，持续 30 秒（之后 30 秒冷却）", {}, {"crowd_dance": 1.0}),
		# --- 生命 ------------------------------------------------------------------
		_r("难闻的止血剂", "life", 0, "所有我方单位生命+20%", "生命上限 +20%", {"hp_pct": 0.20}),
		_r("急救药箱", "life", 1, "所有我方单位生命+35%", "生命上限 +35%", {"hp_pct": 0.35}),
		_r("未知仪器", "life", 2, "所有我方单位生命+50%", "生命上限 +50%", {"hp_pct": 0.50}),
		_r("活玫瑰", "life", 0, "所有我方单位受到的治疗和生命回复效果+20%", "受到的治疗与生命回复 +20%", {"heal_pct": 0.20}),
		_r("苍白花冠", "life", 1, "受到的治疗和生命回复效果+30%", "受到的治疗与生命回复 +30%", {"heal_pct": 0.30}),
		_r("演出用香水", "life", 1, "所有我方单位每秒回复1%的最大生命值", "每秒回复 1% 最大生命", {"regen_max_pct": 0.01}),
		_r("\"迷醉荷谟伊\"", "life", 2, "所有我方单位每秒回复2%的最大生命值", "每秒回复 2% 最大生命", {"regen_max_pct": 0.02}),
		_r("《坎德之花》", "life", 0, "所有我方单位每秒回复10点生命", "每秒回复 30 生命", {"regen": 30.0}),
		_r("\"枯木的回声\"", "life", 1, "所有干员每秒恢复50生命值，但最大生命-25%", "每秒回复 60 生命；生命上限 −25%", {"regen": 60.0, "hp_pct": -0.25}),
		_r("\"萤灯映牍\"", "life", 0, "敌方单位被击倒时，使周围的我方单位回复300点生命值", "击倒敌人时回复 240 生命", {}, {"kill_heal": 240.0}),
		_r("\"忠义\"", "life", 1, "所有我方单位阻挡3名及以上敌人时，每秒回复150点生命", "4 米内有 3 名及以上敌人时，每秒回复 150 生命", {}, {"crowd_regen": 150.0}),
		_r("复还之手", "life", 2, "范围内干员受到致命伤时回复所有生命（每名干员每场1次）", "每个区段一次：受到致命伤害时回满生命", {}, {"death_full": 1.0}),
		_r("\"时光之末\"", "life", 2, "仅一次，在非区域最终战斗中失败时不结束探索，目标生命+1并继续", "本合同一次：受到致命伤害时保留 1 生命并无敌 2 秒", {}, {"death_cling": 1.0}),
		_r("米诺斯颂诗", "life", 1, "每通过一场紧急作战，所有我方单位生命值永久+3%（最多15层）", "每击杀一名精英，本合同生命上限 +3%（至多 15 层）", {}, {"elite_hp_stack": 0.03}),
		# --- 综合与经济 --------------------------------------------------------------
		_r("\"静音小队\"", "attack", 2, "所有我方单位攻击力和防御力+35%，生命+45%", "攻击力与防御 +35%，生命上限 +45%", {"atk_pct": 0.35, "def_pct": 0.35, "hp_pct": 0.45}),
		_r("皮特水果什锦", "life", 0, "可携带干员+3，所有我方单位攻击力、防御力和生命值+3%", "攻击力、防御与生命上限 +6%", {"atk_pct": 0.06, "def_pct": 0.06, "hp_pct": 0.06}),
		_r("\"剑锤\"", "attack", 0, "所有干员部署费用+5，但攻击力、防御力和生命+10%", "攻击力、防御与生命上限 +10%；药瓶容量 −1", {"atk_pct": 0.10, "def_pct": 0.10, "hp_pct": 0.10, "potion_cap": -1.0}),
		_r("统帅肖像", "attack", 1, "所有我方单位攻击力、最大生命值+10%；在险路恶敌中额外+20%", "攻击力与生命上限 +10%；走深部污染带时再 +20%", {"atk_pct": 0.10, "hp_pct": 0.10}, {"route_bonus": 0.20}),
		_r("登天斧", "attack", 2, "所有我方单位攻击力、生命值+60%；每进入一次岁兽残识，攻击力、生命值-30%（最多叠加2次）", "攻击力与生命上限 +60%；每深入一个区段各 −10%（至多 −60%）", {}, {"axe": 0.60}),
		_r("Friston.P", "tempo", 1, "每通过一场紧急作战，所有我方单位攻击速度永久+5（最多15层）", "每击杀一名精英，本合同攻速 +5（至多 15 层）", {}, {"elite_aspd_stack": 5.0}),
		_r("圆石祭坛", "attack", 1, "战斗后有概率使攻击力和防御力永久+5%（最多10层）", "每进入一个新区段，50% 概率本合同攻击力与防御 +5%（至多 10 层）", {}, {"altar": 0.50}),
		_r("友谊之证", "fortune", 0, "战斗掉落的源石锭+30%", "合同报酬 +30%", {"gold_pct": 0.30}),
		_r("锈蚀的铁锤", "fortune", 0, "商店中购买道具所需源石锭-50%", "刷新藏品选项的费用 −50%", {}, {"reroll_discount": 0.50}),
		_r("罗德岛战术电台", "fortune", 1, "战斗后掉落招募券时，增加一个可选项", "之后的藏品选择多一个选项", {}, {"radio": 1.0}),
	]

## id is the collectible's own name, so a relic's identity is its PRTS entry.
static func _r(title: String, kind: String, rarity: int, original: String, effect: String, stats: Dictionary, fx: Dictionary = {}) -> Dictionary:
	return {"id": title, "name": title, "kind": kind, "rarity": rarity, "region": "all", "original": original,
		"effect": effect, "stats": stats, "fx": fx, "source_name": title, "source_url": SOURCE_BASE + title.replace("\"", "").uri_encode()}

static var _index: Dictionary = {}
static func get_relic(id: String) -> Dictionary:
	if _index.is_empty():
		for relic in all(): _index[relic.id] = relic
	return _index.get(id, {})

static func available(relic: Dictionary, region: String, owned: Array) -> bool:
	return not owned.has(relic.id) and relic.region in [region, "all"]

## `count` offers of different kinds where possible (策划案 §8.1.4: a real
## choice), weighted by the source's rarity weights and the region's leanings.
## Fewer relics than three in all leaves the device dormant (empty result).
static func roll_offers(region: String, owned: Array, source: String, rng: RandomNumberGenerator, count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for relic in all():
		if available(relic, region, owned): pool.append(relic)
	var offers: Array[Dictionary] = []
	if pool.size() < 3: return offers
	var rarity_weights: Array = RARITY_WEIGHTS.get(source, RARITY_WEIGHTS.device)
	var regional: Dictionary = REGION_KIND_WEIGHT.get(region, {})
	for pick in range(mini(count, pool.size())):
		var used := offers.map(func(x): return x.kind)
		var candidates := pool.filter(func(x): return not offers.has(x) and not used.has(x.kind))
		if candidates.is_empty(): candidates = pool.filter(func(x): return not offers.has(x))
		var total := 0.0
		var weights: Array[float] = []
		for relic in candidates:
			var weight := float(rarity_weights[relic.rarity]) * float(regional.get(relic.kind, 1.0))
			weights.append(weight)
			total += weight
		var roll := rng.randf() * total
		var chosen: Dictionary = candidates.back()
		for i in range(candidates.size()):
			roll -= weights[i]
			if roll <= 0.0:
				chosen = candidates[i]
				break
		offers.append(chosen)
	return offers

## Summed plain stats of the owned relics.
static func stat_sheet(owned: Array) -> Dictionary:
	var sheet := CombatStats.empty()
	for id in owned:
		var relic := get_relic(id)
		if not relic.is_empty(): CombatStats.add(sheet, relic.stats)
	return sheet

## Summed effect parameters of the owned relics (`execute` takes the highest).
static func fx_sum(owned: Array) -> Dictionary:
	var total := {}
	for id in owned:
		var relic := get_relic(id)
		if relic.is_empty(): continue
		for key in relic.fx:
			if key == "execute": total[key] = maxf(float(total.get(key, 0.0)), float(relic.fx[key]))
			else: total[key] = float(total.get(key, 0.0)) + float(relic.fx[key])
	return total
