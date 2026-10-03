class_name RelicCatalog
extends RefCounted

## The in-run relic pool (构筑物). Design and every number: 局内构筑与数值策划案_v1_0.md
## §8–§10. Each entry records the 集成战略 collectible it was adapted from
## (source_name, verified against PRTS — see 局内构筑调研_集成战略藏品.md) and what
## was changed (adaptation), per 策划案_v1_0.md §2.2.
##
## stats: added straight into the player's sheet (CombatStats.KEYS).
## Everything conditional is implemented by id in Player ("relic hooks").

enum Rarity { COMMON, RARE, LEGEND }
const RARITY_NAMES := ["普通", "稀有", "传说"]
const RARITY_COLORS := [Color("c9d3db"), Color("72b8ff"), Color("f3b04a")]
## Offer weights per rarity (common / rare / legend), by where the offer comes
## from. A vault is the harder-won reward and leans rarer, the way StS's large
## chest and RoR2's legendary chest skip the bottom tier.
const RARITY_WEIGHTS := {"device": [60.0, 30.0, 10.0], "cache": [65.0, 30.0, 5.0], "vault": [25.0, 50.0, 25.0]}
## How much more often each region offers a school (§8.4): "去哪里" also means
## "能成什么型" (策划案 §8.1.7).
const REGION_SCHOOL_WEIGHT := {
	"mine": {"ore": 3.0, "bulwark": 2.0, "blood": 2.0},
	"city": {"bulwark": 3.0, "blade": 2.0, "swift": 2.0},
	"snow": {"hunter": 3.0, "wolf": 2.0, "blade": 1.5},
}
## Once two relics of a school are owned it is pulled toward the offer (Hades'
## god weighting) so a build can complete inside one short contract.
const FOCUS_WEIGHT := 2.5
const BRIDGE_WEIGHT := 1.5
## Pity: after this many offers in a row without the main school, the next
## offer is forced to include one (§8.3).
const PITY_AFTER := 2
const REROLL_BASE := 25
const REROLL_STEP := 25
## Combat cache: one per segment once this much threat is defeated (normal 1, elite 3).
const CACHE_THREAT := 8
const ELITE_THREAT := 3

const SCHOOLS := {
	"blade": {"name": "锋刃", "color": Color("e6a35a"), "brief": "物理攻击、暴击与破甲",
		2: {"text": "暴击率 +10%", "stats": {"crit": 0.10}},
		4: {"text": "连斩第三段必定暴击；暴击伤害 +30%", "stats": {"crit_dmg": 0.30}}},
	"wolf": {"name": "狼魂", "color": Color("b48cff"), "brief": "法术攻击与剑气",
		2: {"text": "剑气只需 2 次命中即可蓄满", "stats": {}},
		4: {"text": "普攻附带 20% 法术攻击力的法术伤害", "stats": {}}},
	"swift": {"name": "迅捷", "color": Color("7fd6c2"), "brief": "攻速、移速与闪避",
		2: {"text": "闪避后 2.5 秒内攻速 +30", "stats": {}},
		4: {"text": "闪避冷却 −40%，体力消耗 −10", "stats": {"dash_cd_pct": -0.4, "dash_cost": -10.0}}},
	"bulwark": {"name": "坚壁", "color": Color("8fb3d9"), "brief": "防御、法抗、格挡与护盾",
		2: {"text": "进入每个区段时获得 15% 最大生命的护盾", "stats": {}},
		4: {"text": "受到攻击时，对攻击者造成 80% 防御值的物理伤害", "stats": {}}},
	"blood": {"name": "血契", "color": Color("e0605a"), "brief": "生命、回复与吸血",
		2: {"text": "吸血 +4%", "stats": {"lifesteal": 0.04}},
		4: {"text": "生命低于 50% 时攻击力 +25%、攻速 +20", "stats": {}}},
	"ore": {"name": "源石", "color": Color("ee8a24"), "brief": "原矿、污染与法术侵蚀",
		2: {"text": "原矿造成的失血减半", "stats": {}},
		4: {"text": "每携带 1 块原矿，攻击力与法术攻击力 +6%（至多 5 块）", "stats": {}}},
	"hunter": {"name": "猎手", "color": Color("9fc7e0"), "brief": "先手、单体与精英",
		2: {"text": "对精英伤害 +20%", "stats": {"elite_pct": 0.20}},
		4: {"text": "脱战首击必定暴击，且该次暴击伤害 +50%", "stats": {}}},
	"field": {"name": "外勤", "color": Color("d8c27a"), "brief": "撤离、点金、报酬与深度",
		2: {"text": "合同报酬 +25%", "stats": {"gold_pct": 0.25}},
		4: {"text": "进入可撤离区段时回复 40% 生命，并补 1 瓶标准急救剂", "stats": {}}},
}
const BRIDGE := "bridge"
const SOURCE_BASE := "https://prts.wiki/w/"

static func all() -> Array[Dictionary]:
	return [
		# --- 锋刃 ------------------------------------------------------------
		_r("blade_edge", "磨亮的刃口", "blade", 0, "all", "刀口不必新，只要亮。",
			"攻击力 +15%", {"atk_pct": 0.15}, "皇帝的恩宠", "近战攻击力+15% 原样采用"),
		_r("whetstone", "双刃磨石", "blade", 0, "all", "左手磨右手，右手磨左手。",
			"攻击力 +60，暴击率 +5%", {"atk": 60.0, "crit": 0.05}, "锈蚀刀片", "敌方物理易伤 15% 拆成攻击力与暴击率"),
		_r("metronome", "连斩节拍", "blade", 0, "all", "一、二，然后是最重的三。",
			"连斩第三段伤害倍率 130% → 190%", {}, "折戟-浴血", "近卫攻击后回技力，改为挂在三段连斩的收招上"),
		_r("counter", "折刃扣", "blade", 1, "city", "把疼痛留给下一刀。",
			"受击或格挡后 3 秒内，下一次近战伤害 ×2；生命上限 −8%", {"hp_pct": -0.08}, "赏善郎", "闪避或抵挡后下次伤害 +100%，触发改为受击/格挡并附代价"),
		_r("unsealed", "未签封条", "blade", 1, "mine", "封装之前，再赌一次。",
			"本合同尚未点金时伤害 +45%；受到伤害 +15%", {}, "皇帝的恩宠", "近战增伤改为点金前的攻击增伤"),
		_r("armor_break", "破甲刃纹", "blade", 1, "all", "找到甲片之间的缝。",
			"物理攻击无视目标 40% 防御", {}, "撕扯之手", "无视 70% 防御下调为 40%，对全部物理攻击生效"),
		_r("executioner", "处刑者的余裕", "blade", 1, "all", "最后一刀不用急。",
			"敌人生命越低伤害越高（至多 +50%）；直接斩杀生命低于 15% 的普通敌人", {}, "溃决之手", "斩杀线 20% 下调为 15%，且不斩精英"),
		_r("broad_blade", "宽刃", "blade", 2, "all", "砍向一个人，扫倒一排人。",
			"普攻对目标 1.8 米内其他敌人造成 50% 伤害；攻速 −10", {"aspd": -10.0}, "老近卫军之锋", "近战攻击力+35% 改为普攻横扫（领主职业的群攻定位）"),
		_r("eagle_edge", "鹰眼刃纹", "blade", 2, "all", "要么见血，要么落空。",
			"暴击伤害 +80%；未暴击的攻击伤害 −20%", {"crit_dmg": 0.80}, "叙拉古人的愤怒", "技能后 1 秒攻击 +100% 改为挂在暴击判定上（参考枪火重生·鹰眼瞄具）"),
		# --- 狼魂 ------------------------------------------------------------
		_r("wolf_fang", "幼狼之牙·残响", "wolf", 1, "all", "她不需要那把剑，也记得那道光。",
			"没有剑气词缀也能蓄满剑气（剑气伤害 −20%）；已有词缀时改为剑气伤害 +25%", {}, "古高卢银币", "初始技力改为直接获得剑气技能"),
		_r("pale_spark", "苍白火种", "wolf", 0, "all", "冷的火，也是火。",
			"法术伤害 +20%", {"arts_dmg_pct": 0.20}, "制式防暴用具", "敌方法术易伤 20% 改为自身法术增伤"),
		_r("howl", "狼群呼号", "wolf", 0, "all", "一声，回应它的不止一声。",
			"法术攻击力 +15%，法抗 +5", {"arts_pct": 0.15, "res": 5.0}, "《麻木与庸俗》", "法抗+5 原样采用，附法术攻击力"),
		_r("pierce_sigil", "穿透咒印", "wolf", 0, "all", "让它飞得更远一点。",
			"剑气伤害 +15%、宽度 +60%、射程 +3 米", {"wave_pct": 0.15}, "显圣吊坠", "远程攻击力+15% 改为剑气伤害与范围"),
		_r("ember_wave", "余烬剑气", "wolf", 1, "all", "伤口在冷下来之前，会一直烧。",
			"剑气使敌人灼烧 4 秒：每 0.5 秒受到 10% 法术攻击力的法术伤害", {}, "老者面", "每秒 150% 法术伤害的近身光环改为剑气灼烧"),
		_r("suffering", "苦难咒文", "wolf", 1, "all", "念完它的人，都付了代价。",
			"法术伤害 +60%；生命上限 −25%", {"arts_dmg_pct": 0.60, "hp_pct": -0.25}, "断杖-苦难巫咒", "术师生命-40%/法术伤害+70% 等比下调"),
		_r("silence", "噤声印记", "wolf", 1, "all", "让他们闭嘴，就在出手之前。",
			"剑气打断普通敌人的蓄力，2 秒内不能出手；使精英法抗 −15，持续 5 秒", {}, "拉普兰德·技能「狼魂」（非藏品）", "取自主角本人的沉默；本作唯一不以藏品为底本的狼魂构筑物"),
		_r("twin_wave", "双生剑气", "wolf", 2, "all", "左手一道，右手一道。",
			"释放剑气时，再向 ±20° 发出两道剑气，各 50% 伤害", {}, "损坏的左轮弹巢", "远程攻击力+35% 改为扇形多道剑气"),
		# --- 迅捷 ------------------------------------------------------------
		_r("light_belt", "轻装束带", "swift", 0, "all", "少带一点，多砍两刀。",
			"攻速 +12，移速 +6%", {"aspd": 12.0, "move_pct": 0.06}, "香草沙士汽水", "技力回复转为攻速与移速"),
		_r("clockwork", "发条护腕", "swift", 0, "all", "挨一下，拧紧一圈。",
			"受到伤害后 5 秒内攻速 +40", {}, "冰结的躯壳", "近战受伤后 5 秒攻速+40 原样采用"),
		_r("sidestep", "余裕身法", "swift", 0, "all", "看见了，就躲得开。",
			"物理闪避率 +15%", {"evasion": 0.15}, "设计师量尺", "15% 物理闪避原样采用（上限 60%）"),
		_r("afterimage", "残影步", "swift", 1, "all", "影子先到，刀后到。",
			"闪避穿过的敌人受到 120% 攻击力的物理伤害；闪避冷却 −20%", {"dash_cd_pct": -0.2}, "钝爪-振奋", "再部署 −50% 转为闪避冷却与穿身伤害"),
		_r("gale", "风切", "swift", 1, "all", "越快，越快。",
			"每次命中攻速 +4，至多 +40；2 秒没有命中则清空", {}, "轰鸣之手", "命中叠攻击力改为叠攻速，上限与清空时间下调"),
		_r("perfect", "时机感", "swift", 2, "all", "在刀落下前的那一瞬。",
			"敌人出手前 0.35 秒内开始闪避：下一次攻击必定暴击、伤害 ×1.5，并回复 25 体力", {}, "《光耀卡西米尔》", "闪避后 6 秒攻击+70% 改为精准闪避后的一击"),
		# --- 坚壁 ------------------------------------------------------------
		_r("buckler", "制式小圆盾", "bulwark", 0, "all", "不好看，但挡得住。",
			"防御 +70", {"def": 70.0}, "异铁小圆盾", "防御+15% 改为平加（主角基础防御低，百分比太弱）"),
		_r("brooch", "防蚀胸针", "bulwark", 0, "all", "别在胸口，替你挨第一下。",
			"法抗 +15；每个区段的第一次伤害被完全抵挡", {"res": 15.0}, "皇族金胸针", "部署后抵挡一次改为每区段抵挡一次"),
		_r("brace", "街角楔", "bulwark", 1, "city", "停下来，让他们撞上来。",
			"静止 0.8 秒后，受击时耗 15 体力格挡 60% 伤害；移速 −10%", {"move_pct": -0.10}, "异铁小圆盾", "常驻防御改为静止和体力驱动的格挡"),
		_r("gild_guard", "回收承诺", "bulwark", 1, "city", "你知道有人会来。",
			"携带点金装备时，每区段抵消一次致命攻击；药瓶容量 −1", {"potion_cap": -1.0}, "急救药箱", "生命增益转为点金条件下的致命保护"),
		_r("pack_plate", "折叠支架", "bulwark", 1, "mine", "装满它，撑住下一次塌方。",
			"背包每占 10 格减伤 5%（至多 25%）；移速 −10%", {"move_pct": -0.10}, "军团护心镜", "防御+25% 转为背包占格减伤，增加机动代价"),
		_r("shield_bash", "盾反", "bulwark", 1, "all", "挡下来的，原样还回去。",
			"格挡或护盾吸收伤害后 3 秒内，下一次攻击追加 150% 防御值的物理伤害", {}, "尖刺之手", "以防御计算的每秒法术伤害改为格挡后的一击"),
		_r("heavy_oath", "重甲誓约", "bulwark", 2, "all", "铁有多厚，刀就有多重。",
			"防御 +35%，并获得防御值 30% 的攻击力；闪避体力消耗 +10", {"def_pct": 0.35, "dash_cost": 10.0}, "古旧的蒸汽甲胄", "防御+35% 原样采用，追加防御转攻击与闪避代价"),
		# --- 血契 ------------------------------------------------------------
		_r("field_kit", "战地止血带", "blood", 0, "all", "绷带、夹板、一针镇痛。",
			"生命上限 +20%", {"hp_pct": 0.20}, "难闻的止血剂", "生命+20% 原样采用"),
		_r("tissue", "活性组织", "blood", 0, "all", "它在长，你也在长。",
			"生命上限 +240，生命回复 +20/秒", {"hp": 240.0, "regen": 20.0}, "《坎德之花》", "每秒回复 10 放大到本作量级，附生命上限"),
		_r("perfume", "舞台香氛", "blood", 0, "all", "闻起来像谢幕后的掌声。",
			"每秒回复 1% 最大生命", {"regen_max_pct": 0.01}, "演出用香水", "每秒回复 1% 最大生命原样采用"),
		_r("thorn_rose", "带刺玫瑰", "blood", 0, "all", "它会扎手，也会止血。",
			"受到的治疗与生命回复效果 +25%", {"heal_pct": 0.25}, "活玫瑰", "治疗效果+20% 上调到 25%"),
		_r("nutrient", "营养原浆", "blood", 0, "all", "吃饱了，才砍得动。",
			"生命越高攻击力越高，满血时 +25%", {}, "古乔治营养原浆", "满血时攻击力+30% 下调到 25%"),
		_r("bloodthirst", "嗜血双刃", "blood", 1, "all", "伤口是双向的。",
			"吸血 8%；药瓶治疗 −30%", {"lifesteal": 0.08}, "\"萤灯映牍\"", "击倒时回复生命改为吸血，代价落在药瓶上"),
		_r("frenzy", "濒死狂热", "blood", 1, "all", "越痛，越快。",
			"生命越低攻速越快，生命 30% 时至多 +60", {}, "紧急活性剂", "原样采用"),
		_r("rest", "余温囊", "blood", 1, "snow", "把热留到下一场战斗。",
			"脱战 5 秒后每秒回复 2.5% 生命；战斗中自身回血停止", {}, "演出用香水", "持续恢复改为脱战条件恢复"),
		_r("undying", "不屈之誓", "blood", 2, "all", "还没到倒下的时候。",
			"每区段一次：受到致命伤害时改为回复 50% 生命，并无敌 1.5 秒；生命上限 −10%", {"hp_pct": -0.10}, "复还之手", "每场一次回满改为每区段一次回复一半"),
		# --- 源石 ------------------------------------------------------------
		_r("ore_heart", "矿尘滤芯", "ore", 1, "mine", "让负担成为续航。",
			"命中时，背包每件原矿回复 1% 最大生命（至多 4%）；药瓶治疗减半", {}, "演出用香水", "持续回血转为原矿携带量驱动的命中回血"),
		_r("ore_hoarder", "矿工的贪心", "ore", 0, "mine", "多背一块，多活一会。",
			"每携带 1 件原矿，生命上限 +6%（至多 +30%）", {}, "米诺斯颂诗", "按紧急作战叠层改为按原矿携带量叠层"),
		_r("crystal_armor", "结晶护甲", "ore", 0, "all", "长在甲上的石头，比甲还硬。",
			"防御 +40、法抗 +8；携带原矿时防御再 +60", {"def": 40.0, "res": 8.0}, "军团护心镜", "防御加成追加原矿条件"),
		_r("active_dust", "活性源石粉", "ore", 0, "all", "吸进去一点，就会亮起来。",
			"法术攻击力 +18%；污染累积 +25%", {"arts_pct": 0.18, "contam_pct": 0.25}, "云与漆", "持续真实伤害的代价改为污染累积"),
		_r("crystal_blade", "源石结晶刃", "ore", 1, "all", "刃上长出了不该长的东西。",
			"普攻附带 18% 法术攻击力的法术伤害，攻速 +15；每秒失去 0.5% 最大生命", {"aspd": 15.0}, "\"永夜的窥视\"", "攻击+25%/攻速+25/每秒流失生命，攻击部分改为附加法术伤害"),
		_r("vein_burst", "矿脉共振", "ore", 1, "all", "它们一起碎，一起响。",
			"击杀敌人时 30% 概率源石爆裂：2.5 米内敌人受到 100% 法术攻击力的法术伤害（爆裂不会再引发爆裂）", {}, "藤蔓炮手", "空中单位被击杀后 3000 物理伤害，改为任意击杀的概率法术爆裂"),
		_r("obsession", "感染者的执念", "ore", 2, "all", "病越重，刀越快。",
			"当前污染每 10 点，伤害 +5%（至多 +50%）；受到伤害 +10%", {"taken_pct": 0.10}, "死仇时代的恨意", "双方攻击+20% 改为挂接污染值的增伤与承伤"),
		# --- 猎手 ------------------------------------------------------------
		_r("hunter_mark", "猎人标记", "hunter", 0, "all", "先挑没受伤的。",
			"对生命高于 90% 的敌人伤害 +50%", {}, "魔王的旗帜", "目标生命满时增益改为对满血敌人增伤（参考 RoR2 撬棍）"),
		_r("weak_point", "致命瞄点", "hunter", 0, "all", "找到它，然后只打那里。",
			"暴击伤害 +30%；暴击时无视目标 30% 防御", {"crit_dmg": 0.30}, "残破合影", "敌方防御 −12% 改为暴击破甲"),
		_r("ambush", "冷藏火种", "hunter", 1, "snow", "等候也是一次蓄力。",
			"脱战 5 秒后，首次攻击伤害 ×2；攻击间隔 +15%", {"interval_pct": 0.15}, "显圣吊坠", "固定远程增伤转为脱战后的首次攻击爆发"),
		_r("empty_safe", "空匣瞄具", "hunter", 1, "snow", "留下空位，瞄得更远。",
			"安全袋为空时剑气伤害 +50%；生命上限 −15%", {"hp_pct": -0.15}, "显圣吊坠", "增伤挂接安全袋留空决策，增加生命代价"),
		_r("frost_trap", "冻土绊索", "hunter", 1, "snow", "第一下，就让它跑不掉。",
			"首次命中某个敌人时其移速 −40%，持续 3 秒；对减速中的敌人伤害 +20%", {}, "悬丝傀儡", "对被束缚敌人的持续伤害改为首击减速与追击增伤"),
		_r("trophy", "狩猎本能", "hunter", 1, "all", "猎物越大，回报越多。",
			"击杀精英后回复 20% 生命，并在本区段攻速 +10（可叠加）", {}, "Friston.P", "通过紧急作战永久攻速+5 改为击杀精英后本区段叠加"),
		_r("lone_wolf", "孤狼", "hunter", 2, "all", "她习惯一个人。",
			"6 米内只有 1 名敌人时，伤害 +45%、受到伤害 −20%", {}, "荣耀绶带", "仅阻挡 1 名敌人时攻击+100%，改为附近只有一名敌人"),
		# --- 外勤 ------------------------------------------------------------
		_r("deep", "单程刻度", "field", 1, "all", "每向前一步，刀就更锋利。",
			"每深入一区段伤害 +8%（至多 +48%）；受到伤害 +10%", {}, "突击协议-利刃", "编队数量改为单向推进深度"),
		_r("safe_salvage", "随身药签", "field", 1, "all", "留一个位置给明天。",
			"安全袋每件材料，药瓶治疗 +25%；药瓶容量 −1", {"potion_cap": -1.0}, "活玫瑰", "固定治疗增益转为安全袋材料数量"),
		_r("last_light", "返航灯芯", "field", 1, "all", "知道出口在哪，才敢深入。",
			"当前区段可撤离时减伤 25%；否则伤害 +20%、受到伤害 +10%", {}, "开裂的束缚带", "敌方降攻改为撤离可用状态下的攻防取舍"),
		_r("gin_cup", "庆功酒杯", "field", 1, "all", "钱还没到手，胆子先到了。",
			"每 50 待交付报酬，攻速 +5（至多 +40）", {}, "金酒之杯", "每 5 源石锭攻速+7，改为按待交付报酬计，加上限"),
		_r("radio", "战术电台", "field", 1, "all", "多一个频道，多一种答案。",
			"之后的构筑物选择从三选一变为四选一", {}, "罗德岛战术电台", "招募券多一个选项改为构筑物多一个选项"),
		_r("spare_pouch", "备用药囊", "field", 0, "all", "多一个口袋，多一次机会。",
			"药瓶容量 +1，获得时补 1 瓶标准急救剂；治疗效果 +15%", {"potion_cap": 1.0, "heal_pct": 0.15}, "急救药箱", "生命加成转为药瓶容量"),
		_r("suppressor", "警戒抑制器", "field", 0, "all", "动静小一点。",
			"警戒上升 −35%", {"pressure_pct": -0.35}, "奇渊面具", "敌方攻击 −12% 改为降低警戒累积（警戒直接决定敌伤）"),
		_r("rush_clause", "加急条款", "field", 0, "all", "按件计酬，越快越好。",
			"合同报酬 +30%；拾取报酬时回复 2% 生命", {"gold_pct": 0.30}, "友谊之证", "源石锭掉落+30% 原样采用，追加拾取回复"),
		# --- 桥梁（需同时持有两个体系各 2 件）------------------------------
		_bridge("moon_blades", "月下双刃", ["blade", "wolf"], "刀光与剑气，本是一回事。",
			"暴击时 35% 概率立即射出一道 50% 伤害的剑气（不消耗充能，不会再触发本效果）"),
		_bridge("shadow_chain", "无影连斩", ["swift", "blade"], "人还没站稳，刀已经到了。",
			"闪避后 2 秒内的攻击必定暴击"),
		_bridge("iron_blood", "铁血", ["bulwark", "blood"], "流出来的血，凝成了甲。",
			"满血时溢出的治疗转为护盾（至多 20% 最大生命）"),
		_bridge("snow_howl", "雪原狼嚎", ["hunter", "wolf"], "雪原上，只有一种狼会嚎。",
			"剑气对精英伤害 +60%，并使其防御 −30%，持续 5 秒"),
		_bridge("ore_flux", "源石灼流", ["ore", "wolf"], "法术沿着矿脉流淌。",
			"你的法术伤害使敌人法抗 −20，持续 4 秒"),
	]

static func _r(id: String, title: String, school: String, rarity: int, region: String, hook: String,
		effect: String, stats: Dictionary, source: String, adaptation: String) -> Dictionary:
	return {"id": id, "name": title, "school": school, "rarity": rarity, "region": region, "hook": hook,
		"effect": effect, "stats": stats, "source_name": source, "source_url": SOURCE_BASE + source.uri_encode(),
		"adaptation": adaptation, "requires": []}

## Bridges are this game's own: 集成战略 has set collections (诸王的冠冕 needs three
## 国王 collectibles) and Hades has duo boons; a bridge needs two of each school.
static func _bridge(id: String, title: String, schools: Array, hook: String, effect: String) -> Dictionary:
	var entry := _r(id, title, BRIDGE, Rarity.LEGEND, "all", hook, effect, {}, "诸王的冠冕", "收藏品套装条件改为两个体系各持有 2 件")
	entry.requires = schools
	return entry

static var _index: Dictionary = {}
static func get_relic(id: String) -> Dictionary:
	if _index.is_empty():
		for relic in all(): _index[relic.id] = relic
	return _index.get(id, {})

static func school_name(school: String) -> String:
	return "桥梁" if school == BRIDGE else str(SCHOOLS[school].name)

static func school_color(school: String) -> Color:
	return Color("f3b04a") if school == BRIDGE else SCHOOLS[school].color

## How many owned relics each school has. Bridges count toward neither.
static func school_counts(owned: Array) -> Dictionary:
	var counts := {}
	for school in SCHOOLS: counts[school] = 0
	for id in owned:
		var relic := get_relic(id)
		if not relic.is_empty() and counts.has(relic.school): counts[relic.school] += 1
	return counts

## Highest active tier (0, 2 or 4) of a school.
static func tier(counts: Dictionary, school: String) -> int:
	var count := int(counts.get(school, 0))
	return 4 if count >= 4 else (2 if count >= 2 else 0)

## The school with the most owned relics, if it has at least two ("" otherwise).
static func main_school(counts: Dictionary) -> String:
	var best := ""
	for school in counts:
		if int(counts[school]) >= 2 and (best.is_empty() or int(counts[school]) > int(counts[best])): best = school
	return best

static func available(relic: Dictionary, region: String, owned: Array, counts: Dictionary) -> bool:
	if owned.has(relic.id) or not relic.region in [region, "all"]: return false
	for school in relic.requires:
		if int(counts.get(school, 0)) < 2: return false
	return true

## `count` offers from different schools (策划案 §8.1.4: a real divergence).
## Weight = rarity weight for the source × region school weight × focus.
## `force_school` (pity) puts one relic of that school first when one is left.
## A school repeats only when too few schools remain; fewer relics than
## `count` in all leaves the device dormant (empty result).
static func roll_offers(region: String, owned: Array, source: String, rng: RandomNumberGenerator, count: int = 3, force_school: String = "") -> Array[Dictionary]:
	var counts := school_counts(owned)
	var pool: Array[Dictionary] = []
	for relic in all():
		if available(relic, region, owned, counts): pool.append(relic)
	var offers: Array[Dictionary] = []
	if pool.size() < 3: return offers
	var rarity_weights: Array = RARITY_WEIGHTS.get(source, RARITY_WEIGHTS.device)
	var regional: Dictionary = REGION_SCHOOL_WEIGHT.get(region, {})
	for pick in range(mini(count, pool.size())):
		var used_schools := offers.map(func(x): return x.school)
		var candidates := pool.filter(func(x): return not offers.has(x) and not used_schools.has(x.school))
		if pick == 0 and not force_school.is_empty():
			var forced := candidates.filter(func(x): return x.school == force_school)
			if not forced.is_empty(): candidates = forced
		if candidates.is_empty(): candidates = pool.filter(func(x): return not offers.has(x))
		var total := 0.0
		var weights: Array[float] = []
		for relic in candidates:
			var weight := float(rarity_weights[relic.rarity])
			if relic.school == BRIDGE: weight *= BRIDGE_WEIGHT
			else:
				weight *= float(regional.get(relic.school, 1.0))
				if int(counts[relic.school]) >= 2: weight *= FOCUS_WEIGHT
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

## Summed stats of the owned relics plus their active resonance tiers.
static func stat_sheet(owned: Array) -> Dictionary:
	var sheet := CombatStats.empty()
	for id in owned:
		var relic := get_relic(id)
		if not relic.is_empty(): CombatStats.add(sheet, relic.stats)
	var counts := school_counts(owned)
	for school in SCHOOLS:
		var reached := tier(counts, school)
		for step in [2, 4]:
			if reached >= step: CombatStats.add(sheet, SCHOOLS[school][step].stats)
	return sheet

## What taking `id` would do to its school's resonance, for the offer card.
static func resonance_hint(id: String, owned: Array) -> String:
	var relic := get_relic(id)
	if relic.is_empty() or relic.school == BRIDGE: return ""
	var counts := school_counts(owned)
	var now := int(counts[relic.school])
	var school: Dictionary = SCHOOLS[relic.school]
	for step in [2, 4]:
		if now + 1 == step: return "%s %d → %d：激活「%s」" % [school.name, now, now + 1, school[step].text]
	return "%s %d → %d" % [school.name, now, now + 1]
