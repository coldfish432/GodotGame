class_name SkillTrees
extends RefCounted

## Each operator's tree (精英化与加点策划案_v0_2.md §8), after Grim Dawn's
## skill / modifier / transmuter and 明日方舟's skill levels, 专精 and modules.
##
## type: "signature" (rank 1 free) / "skill" / "modifier" / "passive" /
##       "transmuter" (one of a group active at a time).
## tier: the elite stage that opens the node. max: highest rank; skills with
## "mastery" go past 7 to 10 (专精 1–3), each of those costing 2 points and the
## MASTERY materials, and needing 精英 2. Ranks 5–7 of a skill or signature
## need 精英 1 (§4.0). `parent`: the node that must have a rank first.

const SKILL_CAP_E0 := 4
const MASTERY_POINTS := 2
const TRANSMUTER_POINTS := 2
## 专精 1–3 (PRTS 技能1 专精 recipe, mapped onto materials the game has).
const MASTERY := [
	{"技巧概要·卷3": 5, "提纯源岩": 3, "研磨石": 4},
	{"技巧概要·卷3": 6, "提纯源岩": 6, "化合切削液": 3},
	{"技巧概要·卷3": 10, "D32钢": 4, "改量装置": 4},
]
## Modules (模组, §8): 模组数据块 ×2 each level plus 龙门币 (PRTS 4/5/6 万 × 0.3).
const MODULE_COST := [
	{"lmd": 12000, "materials": {"模组数据块": 2}},
	{"lmd": 15000, "materials": {"模组数据块": 2}},
	{"lmd": 18000, "materials": {"模组数据块": 2}},
]

const TREES := {
	"lappland": {
		"wave": {"name": "剑气", "type": "signature", "tier": 0, "max": 7,
			"text": "命中 3 次蓄满，下一刀放出穿透剑气。剑气系数 %s。"},
		"sundial": {"name": "日晷", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"text": "连斩第 3 段命中后 4 秒内物理闪避 +%s，第 3 段伤害 +%s。"},
		"shadow_hand": {"name": "影落とす時針", "type": "modifier", "tier": 0, "max": 5, "parent": "sundial",
			"text": "第 3 段扫影距离 +%s；命中的敌人减速 %s，持续 2 秒。"},
		"frenzy": {"name": "狂暴攻势", "type": "passive", "tier": 0, "max": 5,
			"text": "连斩不中断时，第 2、3 段攻速 +%s。"},
		"wolf_spirit": {"name": "狼魂", "type": "skill", "tier": 1, "max": 10, "mastery": true,
			"text": "每放出 %s 道剑气，进入 6 秒狼魂：普攻变为法术伤害，攻击力 +%s，剑气蓄力降为 1 次。"},
		"extra_target": {"name": "额外攻击一个目标", "type": "modifier", "tier": 1, "max": 3, "parent": "wolf_spirit",
			"text": "狼魂期间，每次挥砍对 4 米内另一名敌人追加一次 %s 法术斩。"},
		"no_decay": {"name": "远程攻击不再降低攻击力", "type": "modifier", "tier": 1, "max": 5, "parent": "wave",
			"text": "剑气飞行衰减减少 %s。"},
		"shadow_step": {"name": "影步", "type": "passive", "tier": 1, "max": 5,
			"text": "闪避后 1.5 秒内的下一刀暴击率 +%s。"},
		"wave_pack": {"name": "狼群", "type": "transmuter", "group": "wave", "tier": 2, "max": 1,
			"text": "剑气分成 3 道扇形，每道 45%。"},
		"wave_fang": {"name": "獠牙", "type": "transmuter", "group": "wave", "tier": 2, "max": 1,
			"text": "剑气宽度 ×1.6、射程 +4，伤害 −20%。"},
		"wave_hound": {"name": "猎犬", "type": "transmuter", "group": "wave", "tier": 2, "max": 1,
			"text": "剑气追向最近的敌人，射程 −30%。"},
	},
	"amiya_guard": {
		"shadow": {"name": "影霄·绝影", "type": "signature", "tier": 0, "max": 10, "mastery": true,
			"text": "斩击系数 %s，冷却 %s 秒。"},
		"nightrun": {"name": "影霄·奔夜", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"text": "连斩第 2 段攻击力 +%s；第 2 段后 2 秒内法术闪避 +15%%。"},
		"quilon": {"name": "奎隆佩剑", "type": "passive", "tier": 0, "max": 5,
			"text": "普攻命中让绝影冷却多减 %s 秒。"},
		"kill_stack": {"name": "每击败一个敌人", "type": "modifier", "tier": 1, "max": 3, "parent": "shadow",
			"text": "绝影期间每击败一个敌人攻击力 +%s、法抗 +20，最多 3 层。"},
		"true_after_kill": {"name": "接下来的伤害类型变为真实", "type": "modifier", "tier": 1, "max": 1, "parent": "shadow",
			"text": "绝影击败敌人后，剩下的斩击为真实伤害。"},
		"double_cut": {"name": "二连击", "type": "modifier", "tier": 1, "max": 5, "parent": "nightrun",
			"text": "第 2 段第二刀有 %s 概率再追加一刀。"},
		"shadow_ten": {"name": "十连", "type": "transmuter", "group": "shadow", "tier": 2, "max": 1,
			"text": "斩击 4 → 6 次，每次伤害 −30%。"},
		"shadow_flash": {"name": "一闪", "type": "transmuter", "group": "shadow", "tier": 2, "max": 1,
			"text": "只斩 1 次，系数 ×3.5，真实伤害。"},
		"shadow_moon": {"name": "残月", "type": "transmuter", "group": "shadow", "tier": 2, "max": 1,
			"text": "弹跳范围 4 → 6。"},
	},
	# The recruits (干员寻访策划案 §4, §9, R2). "values" are [rank 1, per rank]
	# for each %s in the text, in order; "fmt" says how each one reads
	# (pct / sec / num / int). OperatorKit.value() reads the same numbers.
	"hellagur": {
		"moon": {"name": "月相", "type": "signature", "tier": 0, "max": 10, "mastery": true,
			"values": [[1.0, 0.06], [6.0, -0.15]], "fmt": ["pct", "sec"],
			"text": "空格依次切换新月、弦月、满月。月相系数 %s，冷却 %s 秒。"},
		"drink": {"name": "饮刃", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.015, 0.002]], "fmt": ["pct"],
			"text": "每次命中回复 %s 生命上限；药剂与自动回血效果减半。"},
		"half_guard": {"name": "弦月", "type": "passive", "tier": 0, "max": 5,
			"values": [[0.30, 0.06]], "fmt": ["pct"],
			"text": "弦月期间物理闪避 +%s。"},
		"iai": {"name": "居合", "type": "skill", "tier": 1, "max": 10, "mastery": true,
			"values": [[0.10, 0.05]], "fmt": ["pct"],
			"text": "连斩第 3 段居合伤害 +%s。"},
		"full_reach": {"name": "满月范围扩大", "type": "modifier", "tier": 1, "max": 3, "parent": "moon",
			"values": [[4.0, 1.0]], "fmt": ["int"],
			"text": "满月横扫最多命中 %s 名敌人。"},
		"tenacity": {"name": "坚忍", "type": "passive", "tier": 1, "max": 5,
			"values": [[1.0, 0.25]], "fmt": ["sec"],
			"text": "每个区段一次：受到致命伤害时保留 1 点生命，%s 秒内无敌。"},
		"moon_full": {"name": "满月常驻", "type": "transmuter", "group": "moon", "tier": 2, "max": 1,
			"text": "满月不再结束，直到再按空格；月相跳过新月。"},
		"moon_tenacity": {"name": "坚忍延长", "type": "transmuter", "group": "moon", "tier": 2, "max": 1,
			"text": "坚忍每个区段可触发 2 次，无敌时间 ×3。"},
		"moon_counter": {"name": "弦月反击", "type": "transmuter", "group": "moon", "tier": 2, "max": 1,
			"text": "弦月期间闪避成功后，立刻对攻击者反击一刀。"},
	},
	"hoshiguma": {
		"saw": {"name": "力之锯", "type": "signature", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.60, 0.04], [12.0, -0.25]], "fmt": ["pct", "sec"],
			"text": "架盾 4 秒，持续切割前方扇形，每次 %s；冷却 %s 秒。"},
		"armour": {"name": "战术装甲", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.15, 0.01], [0.20, 0.03]], "fmt": ["pct", "pct"],
			"text": "受到攻击时 %s 概率完全挡下，挡下后 5 秒内攻击力 +%s。"},
		"hannya": {"name": "般若", "type": "passive", "tier": 0, "max": 5,
			"values": [[0.10, 0.04]], "fmt": ["pct"],
			"text": "防御力 +%s。"},
		"ram": {"name": "冲撞", "type": "passive", "tier": 1, "max": 5,
			"values": [[1.0, 0.3]], "fmt": ["num"],
			"text": "连击第 3 段冲撞把敌人击退 %s 米。"},
		"saw_front": {"name": "架盾", "type": "modifier", "tier": 1, "max": 5, "parent": "saw",
			"values": [[0.60, 0.05]], "fmt": ["pct"],
			"text": "力之锯期间正面受到的伤害 −%s。"},
		"oni": {"name": "鬼族之力", "type": "passive", "tier": 1, "max": 5,
			"values": [[0.20, 0.06]], "fmt": ["pct"],
			"text": "生命低于 50%% 时防御力 +%s。"},
		"saw_will": {"name": "战意", "type": "transmuter", "group": "saw", "tier": 2, "max": 1,
			"text": "力之锯期间攻击力 +40%、防御力 +80%。"},
		"saw_thorns": {"name": "荆棘", "type": "transmuter", "group": "saw", "tier": 2, "max": 1,
			"text": "受到攻击时对攻击者造成攻击力 100% 的物理伤害。"},
		"saw_karma": {"name": "业火", "type": "transmuter", "group": "saw", "tier": 2, "max": 1,
			"text": "每个区段一次：生命归零后 5 秒内生命不会低于 1。"},
	},
	"typhon": {
		"hunt": {"name": "永恒狩猎", "type": "signature", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.60, 0.04], [14.0, -0.3]], "fmt": ["pct", "sec"],
			"text": "标记光标处的敌人，接下来 5 次攻击变成落在它身上的箭雨，每支 %s；冷却 %s 秒。"},
		"mire": {"name": "重如沼泥", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.40, 0.05]], "fmt": ["pct"],
			"text": "对每个敌人的第一箭伤害 +%s，并使其移速 −80%%，持续 3 秒。"},
		"steady": {"name": "屏息", "type": "passive", "tier": 0, "max": 5,
			"values": [[0.02, 0.01]], "fmt": ["pct"],
			"text": "连续射击同一目标时，每箭攻击力 +%s，最多 5 层。"},
		"hunt_stun": {"name": "晕眩", "type": "modifier", "tier": 1, "max": 3, "parent": "hunt",
			"values": [[0.4, 0.1]], "fmt": ["sec"],
			"text": "箭雨每轮使标记目标晕眩 %s 秒。"},
		"long_shot": {"name": "远射", "type": "passive", "tier": 1, "max": 5,
			"values": [[0.6, 0.4]], "fmt": ["num"],
			"text": "射程 +%s 米。"},
		"hunt_count": {"name": "追猎", "type": "modifier", "tier": 1, "max": 2, "parent": "hunt",
			"values": [[1.0, 1.0]], "fmt": ["int"],
			"text": "箭雨次数 +%s。"},
		"hunt_twin": {"name": "双箭分射", "type": "transmuter", "group": "hunt", "tier": 2, "max": 1,
			"text": "普攻同时向射程内另一名敌人射出一箭，伤害 60%。"},
		"hunt_wide": {"name": "箭雨扩大", "type": "transmuter", "group": "hunt", "tier": 2, "max": 1,
			"text": "箭雨同时落在标记目标 2.5 米内的敌人身上。"},
		"hunt_fang": {"name": "兽牙加深", "type": "transmuter", "group": "hunt", "tier": 2, "max": 1,
			"text": "锐如兽牙的无视防御上限 +30%。"},
	},
	"rosa": {
		"avalanche": {"name": "雪崩击", "type": "signature", "tier": 0, "max": 10, "mastery": true,
			"values": [[1.0, 0.06], [12.0, -0.25]], "fmt": ["pct", "sec"],
			"text": "向光标方向扇形射出 4 枚叉枪，每枚 %s 并钉住目标 4 秒；冷却 %s 秒。"},
		"siege_bolt": {"name": "攻城弩矢", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.10, 0.05]], "fmt": ["pct"],
			"text": "连射第 3 段的蓄力穿透矢伤害 +%s。"},
		"pin_dot": {"name": "束缚", "type": "passive", "tier": 0, "max": 5,
			"values": [[0.30, 0.04]], "fmt": ["pct"],
			"text": "被钉住的敌人每秒受到攻击力 %s 的物理伤害。"},
		"bolt_slow": {"name": "重矢", "type": "passive", "tier": 1, "max": 5,
			"values": [[0.10, 0.04]], "fmt": ["pct"],
			"text": "弩矢命中使敌人移速 −%s，持续 1.5 秒。"},
		"harpoon_more": {"name": "叉枪", "type": "modifier", "tier": 1, "max": 1, "parent": "avalanche",
			"values": [[1.0, 0.0]], "fmt": ["int"],
			"text": "雪崩击叉枪 +%s 枚。"},
		"pin_time": {"name": "钉牢", "type": "modifier", "tier": 1, "max": 3, "parent": "avalanche",
			"values": [[0.5, 0.5]], "fmt": ["sec"],
			"text": "钉住时间 +%s 秒。"},
		"rosa_split": {"name": "分裂射击", "type": "transmuter", "group": "avalanche", "tier": 2, "max": 1,
			"text": "弩矢命中后分裂，向附近 2 名敌人各射一矢，伤害 40%。"},
		"rosa_pull": {"name": "叉枪拉近", "type": "transmuter", "group": "avalanche", "tier": 2, "max": 1,
			"text": "叉枪把目标向博士方向拉近 2 米。"},
		"rosa_burst": {"name": "钉地爆裂", "type": "transmuter", "group": "avalanche", "tier": 2, "max": 1,
			"text": "钉住结束时爆裂，对 2 米内的敌人造成攻击力 150% 的物理伤害。"},
	},
	"lin": {
		"surge": {"name": "流光乍裂", "type": "signature", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.50, 0.04], [7.0, 0.2]], "fmt": ["pct", "sec"],
			"text": "攻击力 +%s，持续 %s 秒；期间琉璃璧更难破碎，击倒敌人时琉璃璧碎裂并立刻重生。冷却 18 秒。"},
		"array": {"name": "法阵", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.05, 0.05]], "fmt": ["pct"],
			"text": "法阵爆伤害 +%s。"},
		"glass": {"name": "琉璃璧", "type": "passive", "tier": 0, "max": 5,
			"values": [[0.10, 0.01], [8.0, -0.4]], "fmt": ["pct", "sec"],
			"text": "琉璃璧挡下所有伤害；单次伤害超过生命上限的 %s 时碎裂，%s 秒后重新生成。"},
		"taoguang": {"name": "韬光", "type": "passive", "tier": 1, "max": 5,
			"values": [[0.40, 0.08]], "fmt": ["pct"],
			"text": "受击时 %s 概率让流光乍裂冷却减少 0.5 秒。"},
		"shatter_power": {"name": "碎璧", "type": "modifier", "tier": 1, "max": 5, "parent": "glass",
			"values": [[1.2, 0.15]], "fmt": ["pct"],
			"text": "琉璃璧碎裂时对周围造成攻击力 %s 的法术伤害并晕眩 1 秒。"},
		"surge_reach": {"name": "流光", "type": "modifier", "tier": 1, "max": 3, "parent": "surge",
			"values": [[0.30, 0.10]], "fmt": ["pct"],
			"text": "流光乍裂期间法阵范围 +%s。"},
		"lin_linglong": {"name": "玲珑", "type": "transmuter", "group": "surge", "tier": 2, "max": 1,
			"text": "法阵爆使敌人停顿 0.3 秒。"},
		"lin_shelter": {"name": "荫庇", "type": "transmuter", "group": "surge", "tier": 2, "max": 1,
			"text": "物理与法术闪避 +20%。"},
		"lin_glass": {"name": "琉璃璧加固", "type": "transmuter", "group": "surge", "tier": 2, "max": 1,
			"text": "琉璃璧碎裂阈值 ×1.6。"},
	},
	"santalla": {
		"tears": {"name": "女巫之泪", "type": "signature", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.60, 0.03], [10.0, 0.3]], "fmt": ["pct", "sec"],
			"text": "光标附近持续落下冰锥，每根 %s 并附加寒冷，持续 %s 秒。冷却 20 秒。"},
		"orb": {"name": "冰球", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.50, 0.05]], "fmt": ["pct"],
			"text": "第 3 发大冰球溅射伤害 %s。"},
		"cold_power": {"name": "冰寒之力", "type": "passive", "tier": 0, "max": 5,
			"values": [[0.12, 0.03]], "fmt": ["pct"],
			"text": "持续战斗 8 秒后攻击力 +%s。"},
		"chill": {"name": "寒冷", "type": "passive", "tier": 1, "max": 5,
			"values": [[0.20, 0.05]], "fmt": ["pct"],
			"text": "寒冷使敌人移速 −%s。"},
		"tears_rate": {"name": "冰雨", "type": "modifier", "tier": 1, "max": 3, "parent": "tears",
			"values": [[0.05, 0.03]], "fmt": ["sec"],
			"text": "冰锥落下间隔 −%s 秒。"},
		"frost_ward": {"name": "冰霜护身", "type": "passive", "tier": 1, "max": 5,
			"values": [[5.0, 3.0]], "fmt": ["num"],
			"text": "法术抗性 +%s。"},
		"tears_seek": {"name": "冰锥追踪", "type": "transmuter", "group": "tears", "tier": 2, "max": 1,
			"text": "冰锥落在光标附近最近的敌人身上。"},
		"tears_freeze": {"name": "冻结", "type": "transmuter", "group": "tears", "tier": 2, "max": 1,
			"text": "3 秒内受到 3 次寒冷的敌人冻结 1.5 秒。"},
		"tears_ward": {"name": "抗控扩展", "type": "transmuter", "group": "tears", "tier": 2, "max": 1,
			"text": "击退与拉拽的距离也减半。"},
	},
	"texas": {
		"rain": {"name": "剑雨", "type": "signature", "tier": 0, "max": 10, "mastery": true,
			"values": [[1.4, 0.07], [10.0, -0.2]], "fmt": ["pct", "sec"],
			"text": "身边一圈落剑，两段法术伤害各 %s，并晕眩 1.5 秒；冷却 %s 秒。"},
		"express": {"name": "急件", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"values": [[0.20, 0.02]], "fmt": ["pct"],
			"text": "剑雨命中后 3 秒内移速 +%s。"},
		"quickdraw": {"name": "快刀", "type": "passive", "tier": 0, "max": 5,
			"values": [[0.20, 0.05]], "fmt": ["sec"],
			"text": "普攻命中让剑雨冷却减少 %s 秒。"},
		"rain_stun": {"name": "剑雨压制", "type": "modifier", "tier": 1, "max": 3, "parent": "rain",
			"values": [[0.3, 0.2]], "fmt": ["sec"],
			"text": "剑雨晕眩 +%s 秒。"},
		"vanguard": {"name": "尖兵", "type": "passive", "tier": 1, "max": 5,
			"values": [[4.0, 3.0]], "fmt": ["num"],
			"text": "攻速 +%s。"},
		"rain_breath": {"name": "喘息", "type": "modifier", "tier": 1, "max": 3, "parent": "rain",
			"values": [[4.0, 2.0]], "fmt": ["num"],
			"text": "剑雨每命中一名敌人回复 %s 体力。"},
		"rain_wide": {"name": "剑雨扩大", "type": "transmuter", "group": "rain", "tier": 2, "max": 1,
			"text": "剑雨范围 ×1.4。"},
		"rain_triple": {"name": "剑雨三段", "type": "transmuter", "group": "rain", "tier": 2, "max": 1,
			"text": "剑雨落下三段。"},
		"rain_storm": {"name": "剑雨滂沱", "type": "transmuter", "group": "rain", "tier": 2, "max": 1,
			"text": "两段之后 4 秒内每秒向身边最多 4 名敌人落剑，每次 50% 并晕眩 0.2 秒（取自缄默德克萨斯）。"},
	},
}

## Talents (天赋): no points; elite stage and module level raise them.
const TALENTS := {
	"lappland": {"name": "精神摧毁", "text": "攻击使目标的特殊能力失效 %s 秒（精英与首领 %s 秒）%s。"},
	"amiya_guard": {"name": "青色怒火", "text": "攻击力与防御力 +%s，绝影期间及之后 3 秒效果加倍。"},
	# Recruits: "values" are [精英 1, 精英 2, 模组 2 级, 模组 3 级] per %s.
	"hellagur": {"name": "月盈星亏", "values": [[40.0, 60.0, 70.0, 80.0]], "fmt": ["num"],
		"text": "攻速随损失的生命提升，损失 50%% 时达到 +%s。"},
	"hoshiguma": {"name": "鬼族", "values": [[0.08, 0.12, 0.14, 0.16]], "fmt": ["pct"],
		"text": "生命上限 +%s。"},
	"typhon": {"name": "锐如兽牙", "values": [[0.06, 0.10, 0.10, 0.10], [0.30, 0.50, 0.55, 0.60]], "fmt": ["pct", "pct"],
		"text": "连续射击同一目标时每箭多无视 %s 防御，最多 %s；8 秒不射击清零。"},
	"rosa": {"name": "深入骨髓", "values": [[0.30, 0.60, 0.60, 0.60], [0.30, 0.60, 0.70, 0.80]], "fmt": ["pct", "pct"],
		"text": "攻击精英、首领与重甲敌人时无视 %s 防御，并追加 %s 物理伤害。"},
	"lin": {"name": "计出万全", "values": [[0.20, 0.40, 0.50, 0.60]], "fmt": ["pct"],
		"text": "琉璃璧碎裂阈值 +%s。"},
	"santalla": {"name": "生于冰寒", "values": [[0.5, 0.5, 0.5, 0.5], [5.0, 10.0, 12.0, 15.0]], "fmt": ["pct", "num"],
		"text": "受到的晕眩时间 −%s；法术抗性 +%s。"},
	"texas": {"name": "战术快递", "values": [[0.10, 0.15, 0.17, 0.20]], "fmt": ["pct"],
		"text": "技能伤害 +%s。"},
}
const MODULES := {
	"lappland": {"name": "\"幼狼的牙齿\"", "type": "LOR-X", "stats": {"hp": 175.0, "atk": 40.0, "aspd": 6.0}},
	"amiya_guard": {"name": "待调弦的怒火", "type": "AFT-X", "stats": {"atk": 45.0, "res": 4.0}},
	"hellagur": {"name": "月下刀锋", "type": "DRE-X", "stats": {"hp": 200.0, "atk": 40.0}},
	"hoshiguma": {"name": "般若之盾", "type": "PRO-X", "stats": {"hp": 250.0, "def": 60.0}},
	"typhon": {"name": "猎人的弓弦", "type": "BES-X", "stats": {"atk": 50.0, "aspd": 4.0}},
	"rosa": {"name": "攻城器械", "type": "BES-Y", "stats": {"atk": 45.0, "hp": 150.0}},
	"lin": {"name": "玉门的茶", "type": "PRI-X", "stats": {"atk": 40.0, "res": 5.0}},
	"santalla": {"name": "冻土的巫术", "type": "SPC-X", "stats": {"atk": 40.0, "res": 4.0}},
	"texas": {"name": "企鹅物流的剑", "type": "CHG-X", "stats": {"atk": 35.0, "aspd": 5.0}},
}

static func tree(operator_id: String) -> Dictionary:
	return TREES.get(operator_id, {})

static func node(operator_id: String, id: String) -> Dictionary:
	return tree(operator_id).get(id, {})

## Points the next rank of a node costs (rank is the current one).
static func rank_cost(data: Dictionary, rank: int) -> int:
	if str(data.get("type", "")) == "transmuter": return TRANSMUTER_POINTS
	if rank >= 7: return MASTERY_POINTS
	return 1

## The elite stage the next rank needs.
static func rank_elite(data: Dictionary, rank: int) -> int:
	var need := int(data.get("tier", 0))
	if str(data.get("type", "")) in ["skill", "signature"]:
		if rank >= 7: need = maxi(need, 2)
		elif rank >= SKILL_CAP_E0: need = maxi(need, 1)
	return need

## Materials the next rank needs: 专精 only.
static func rank_materials(data: Dictionary, rank: int) -> Dictionary:
	if bool(data.get("mastery", false)) and rank >= 7 and rank < 10: return MASTERY[rank - 7]
	return {}

## Total points spent to reach `rank` (for refunds).
static func spent(data: Dictionary, rank: int) -> int:
	var total := 0
	for r in range(rank):
		if str(data.get("type", "")) == "signature" and r == 0: continue
		total += rank_cost(data, r)
	return total

## Rank label: "3/7", "专精 2".
static func rank_label(data: Dictionary, rank: int) -> String:
	if str(data.get("type", "")) == "transmuter": return "已习得" if rank > 0 else "未习得"
	var top := mini(7, int(data.max))
	if rank > 7: return "专精 %d" % (rank - 7)
	return "%d/%d" % [rank, top]

# --- Values each rank gives (read by Player) ----------------------------------

## 剑气系数: 1.5 + 0.1 per rank above 1.
static func wave_scale(rank: int) -> float:
	return 1.5 + 0.1 * maxi(0, rank - 1)

## 日晷: [evasion after stage 3, stage-3 bonus].
static func sundial(rank: int) -> Array:
	if rank <= 0: return [0.0, 0.0]
	if rank > 7: return [[0.24, 0.28, 0.32][rank - 8], 0.35]
	return [0.08 + 0.02 * (rank - 1), 0.05 * rank]

## 狼魂: [waves to trigger, ATK bonus].
static func wolf_spirit(rank: int) -> Array:
	if rank <= 0: return [0, 0.0]
	if rank > 7: return [3 if rank == 10 else 4, [0.60, 0.70, 0.80][rank - 8]]
	return [4, 0.20 + 0.05 * (rank - 1)]

static func extra_target(rank: int) -> float:
	return [0.0, 0.40, 0.55, 0.70][clampi(rank, 0, 3)]

## 绝影: [strike scale, cooldown].
static func shadow(rank: int) -> Array:
	var scale := 1.0 + 0.06 * maxi(0, mini(rank, 7) - 1)
	var cooldown := 8.0 - (1.5 if rank >= 7 else 0.0)
	if rank > 7:
		scale += 0.12 * (rank - 7)
		cooldown -= 0.5 * (rank - 7)
	return [scale, cooldown]

## 奔夜: stage-2 ATK bonus.
static func nightrun(rank: int) -> float:
	if rank <= 0: return 0.0
	if rank > 7: return [0.36, 0.44, 0.52][rank - 8]
	return 0.04 * rank

static func kill_stack(rank: int) -> float:
	return [0.0, 0.10, 0.15, 0.20][clampi(rank, 0, 3)]

## 精神摧毁 by elite and module level: [seconds, seconds on elites, fragile].
static func mind_break(elite: int, module_level: int) -> Array:
	if elite <= 0: return [0.0, 0.0, 0.0]
	var fragile := 0.0
	if module_level >= 3: fragile = 0.08
	elif module_level >= 2: fragile = 0.04
	if elite == 1: return [1.0, 0.5, 0.0]
	return [6.0 if module_level >= 2 else 5.0, 2.0, fragile]

## 青色怒火 by elite and module level: ATK / DEF bonus.
static func cyan_fury(elite: int, module_level: int) -> float:
	if elite <= 0: return 0.0
	if elite == 1: return 0.04
	if module_level >= 3: return 0.09
	if module_level >= 2: return 0.08
	return 0.07

## A recruit's node value at `rank`: rank 1's plus the step per rank above
## it (专精 continues the same line); 0 without a rank.
static func value(operator_id: String, id: String, rank: int, index: int = 0) -> float:
	if rank <= 0: return 0.0
	var values: Array = node(operator_id, id).get("values", [])
	if index >= values.size(): return 0.0
	return float(values[index][0]) + float(values[index][1]) * (rank - 1)

## A recruit's talent value: none before 精英 1, then 精英 1 / 精英 2, and the
## module's levels 2 and 3 at 精英 2.
static func talent_value(operator_id: String, elite: int, module_level: int, index: int = 0) -> float:
	if elite <= 0: return 0.0
	var values: Array = TALENTS.get(operator_id, {}).get("values", [])
	if index >= values.size(): return 0.0
	var column := 0 if elite == 1 else (3 if module_level >= 3 else (2 if module_level >= 2 else 1))
	return float(values[index][column])

static func _format(fmt: String, v: float) -> String:
	match fmt:
		"pct": return "%d%%" % roundi(v * 100)
		"sec": return "%.1f" % v if absf(v - roundf(v)) > 0.01 else str(roundi(v))
		"int": return str(roundi(v))
	return ("%.1f" % v) if absf(v - roundf(v)) > 0.01 else str(roundi(v))

## The numbers shown in a node's text at `rank` (at least rank 1 for preview).
static func describe(operator_id: String, id: String, rank: int) -> String:
	var data := node(operator_id, id)
	if data.is_empty(): return ""
	var r := maxi(1, rank)
	var text := str(data.text)
	if data.has("values"):
		var shown: Array = []
		for i in range(data.values.size()): shown.append(_format(str(data.fmt[i]), value(operator_id, id, r, i)))
		return text % shown
	if not "%" in text: return text
	match id:
		"wave": return text % ("%d%%" % roundi(wave_scale(r) * 100))
		"sundial":
			var v := sundial(r)
			return text % ["%d%%" % roundi(v[0] * 100), "%d%%" % roundi(v[1] * 100)]
		"shadow_hand": return text % ["%d%%" % (8 * r), "%d%%" % (6 * r)]
		"frenzy": return text % str(4 * r)
		"wolf_spirit":
			var w := wolf_spirit(r)
			return text % [str(w[0]), "%d%%" % roundi(w[1] * 100)]
		"extra_target": return text % ("%d%%" % roundi(extra_target(r) * 100))
		"no_decay": return text % ("%d%%" % (20 * r))
		"shadow_step": return text % ("%d%%" % (10 * r))
		"shadow":
			var s := shadow(r)
			return text % ["%d%%" % roundi(s[0] * 100), "%.1f" % s[1]]
		"nightrun": return text % ("%d%%" % roundi(nightrun(r) * 100))
		"quilon": return text % ("%.1f" % (0.1 * r))
		"kill_stack": return text % ("%d%%" % roundi(kill_stack(r) * 100))
		"double_cut": return text % ("%d%%" % (8 * r))
	return text

static func talent_text(operator_id: String, elite: int, module_level: int) -> String:
	var data: Dictionary = TALENTS.get(operator_id, {})
	if data.is_empty(): return ""
	if data.has("values"):
		var shown: Array = []
		for i in range(data.values.size()): shown.append(_format(str(data.fmt[i]), talent_value(operator_id, maxi(1, elite), module_level, i)))
		return str(data.text) % shown
	if operator_id == "lappland":
		var m := mind_break(maxi(1, elite), module_level)
		return str(data.text) % [str(roundi(m[0])), str(m[1]), "，并使其受到伤害 +%d%%" % roundi(m[2] * 100) if m[2] > 0 else ""]
	return str(data.text) % ("%d%%" % roundi(cyan_fury(maxi(1, elite), module_level) * 100))
