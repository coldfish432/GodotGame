class_name GearCatalog
extends RefCounted

## Equipment bases (装备策划案_v1_0.md §2, §4): every ordinary piece of gear
## is one of these. A base fixes the name, a power factor and an intrinsic
## ("固有") stat that does not use an affix slot. Random affixes still come
## from rarity, as before (LootTables.roll_equipment).
##
## Tiers 0/1/2 (浅/中/深) unlock at segments 1/3/5 (§2.2); elites, guards and
## vaults see them two segments early. The ranged bases (弩/铳) are designed
## but stay out of the pool until there is a ranged operator (§2.4).

## Forms that shoot rather than swing: they cannot attack the air.
const RANGED_FORMS := ["crossbow", "bow", "gun"]
## How a form changes her attack (装备策划案 §2.4, §12, 装备扩充策划案 §3):
## [interval ×, damage ×, reach ×, swing half-angle ×]. Ranged forms and the
## staff scale the operator's own shot or cast and its reach.
const FORMS := {
	"blade": [1.0, 1.0, 1.0, 1.0], "heavy": [1.3, 1.35, 1.2, 1.0], "fist": [0.75, 0.8, 0.8, 1.0],
	"polearm": [1.15, 1.15, 1.4, 0.6],
	"crossbow": [1.0, 1.0, 1.0, 1.0], "bow": [0.85, 0.85, 1.1, 1.0], "gun": [1.4, 1.5, 1.2, 1.0],
	"staff": [1.0, 1.0, 1.0, 1.0],
}
const FORM_NAMES := {"blade": "刃", "heavy": "重", "fist": "拳", "polearm": "长柄", "crossbow": "弩", "bow": "弓", "gun": "铳", "staff": "法杖"}
## Which forms a class can wield (§2.4: 角色装不上本职业以外的形制).
const CLASS_FORMS := {
	"近卫": ["blade", "heavy", "fist", "polearm"],
	"先锋": ["blade", "fist", "polearm"],
	"重装": ["heavy", "blade", "polearm"],
	"狙击": ["crossbow", "bow", "gun"],
	"术师": ["staff"],
}

## The form of a weapon item ("" for anything else).
static func form_of(item: Item) -> String:
	if item == null or item.category != Item.Category.WEAPON: return ""
	var data: Dictionary = SpecialGear.GEAR.get(item.special, {}) if not item.special.is_empty() else base(item.base_id)
	return str(data.get("form", "blade"))

## Whether `operator_id` can wield `item` (true for anything not a weapon).
static func can_wield(operator_id: String, item: Item) -> bool:
	var form := form_of(item)
	if form.is_empty(): return true
	var cls := str(Operators.DATA.get(operator_id, {}).get("class", "近卫"))
	return form in CLASS_FORMS.get(cls, CLASS_FORMS["近卫"])

const S := ItemModifier.Stat
const W := Item.Category.WEAPON
## 装备部位拆分与数值案 (用户 2026-10-21): the old armour bases are chests and
## the old trinkets amulets; head, hands, legs, feet and rings are new (E15).
const A := Item.Category.CHEST
const T := Item.Category.AMULET
const HEAD := Item.Category.HEAD
const CHEST := Item.Category.CHEST
const HANDS := Item.Category.HANDS
const LEGS := Item.Category.LEGS
const FEET := Item.Category.FEET
const AMULET := Item.Category.AMULET
const RING := Item.Category.RING

## Shallow / mid / deep bases open at these floors (the ten-floor camp rhythm).
const TIER_DEPTH := [1, 4, 7]
const EARLY_SOURCES := ["elite", "guard", "vault"]
const EARLY_BY := 2
## Marks an intrinsic modifier (ItemModifier.tier); −1 is a special item's cost.
const IMPLICIT_TIER := -2

## id: name, region, category, tier, power factor, intrinsic stats, form,
## enemies who carry it, icon, flavour text. `value` multiplies the delivery
## price (龙门币钱夹 only).
const BASES := {
	# --- 切尔诺伯格 · 坍塌矿区 (§4.1)
	"mine_cleaver": {"name": "改装砍刀", "region": "mine", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"form": "blade", "enemies": ["thug"], "icon": "modified_machete", "text": "刀背上还留着焊缝。"},
	"mine_shortblade": {"name": "制式短刀", "region": "mine", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "blade", "icon": "standard_dagger", "text": "缴获来的，编号被锉掉了。"},
	"mine_issue": {"name": "矿区制式刀", "region": "mine", "category": W, "tier": 0, "factor": 1.00, "implicit": [],
		"form": "blade", "icon": "mine_issue_blade", "text": "矿场配发的开路刀，砍支架也砍人。"},
	"mine_saber": {"name": "纠察队佩刀", "region": "mine", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "patrol_saber", "text": "刀鞘不见了，刀还记得它是追人用的。"},
	"mine_pickaxe": {"name": "断镐战斧", "region": "mine", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_PCT, 0.04], [S.MOVE_SPEED_PCT, -0.04]],
		"form": "heavy", "icon": "pickhaft_blade", "text": "镐头断了一半，剩下那半磨成了斧。"},
	"mine_vest": {"name": "矿工护甲", "region": "mine", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.02]],
		"icon": "miner_vest", "text": "胸口缝着矿场的编号。"},
	"mine_reunion_coat": {"name": "整合运动制式外套", "region": "mine", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.02]],
		"icon": "reunion_coat", "text": "穿上它的人不需要名字。"},
	"mine_greatcoat": {"name": "纠察队防寒大衣", "region": "mine", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 2.0], [S.MAX_HP_PCT, 0.01]],
		"icon": "patrol_winter_coat", "text": "厚得能挡住冻原的风，挡不住矿石病。"},
	"mine_hazard_suit": {"name": "矿场重型防护服", "region": "mine", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 15.0], [S.RES_FLAT, 2.0], [S.MOVE_SPEED_PCT, -0.01]],
		"icon": "heavy_mine_suit", "text": "给最深的矿道准备的，没来得及发下去。"},
	"mine_dust_mask": {"name": "防尘面罩", "region": "mine", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.RES_FLAT, 2.0]],
		"icon": "dust_mask", "text": "滤芯是黑的，说明它一直在工作。"},
	"mine_flask": {"name": "烈酒扁壶", "region": "mine", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_DMG, 0.075], [S.MAX_HP_PCT, -0.01]],
		"icon": "liquor_flask", "text": "摇一摇，还剩一口。"},
	"mine_reunion_mask": {"name": "整合运动面具", "region": "mine", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.ATTACK_SPEED_PCT, 0.0375]],
		"icon": "reunion_mask", "text": "面具都一样，所以没人记得谁倒下了。"},
	"mine_meter": {"name": "源石感应计", "region": "mine", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.025], [S.DROP_RATE_PCT, 0.05]],
		"icon": "originium_meter", "text": "罗德岛测绘队的仪器，指针一直贴在头上。"},
	# --- 龙门 (§4.2)
	"city_finger_blade": {"name": "指刃", "region": "city", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "fist", "enemies": ["brawler"], "icon": "finger_blade", "text": "出拳够快的人，刀只需要很短。"},
	"city_gang_chopper": {"name": "帮派砍刀", "region": "city", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"form": "blade", "enemies": ["thug"], "icon": "gang_machete", "text": "刀柄缠的红绳，是哪一家的颜色？"},
	"city_lgd_knife": {"name": "近卫局警用刀", "region": "city", "category": W, "tier": 0, "factor": 1.00, "implicit": [],
		"form": "blade", "icon": "lgd_knife", "text": "刀柄上有编号，登记在册。"},
	"city_escort_blade": {"name": "押运短刃", "region": "city", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"form": "blade", "icon": "courier_dagger", "text": "货要准时到，人要活着到。"},
	"city_ring_saber": {"name": "炎式环首刀", "region": "city", "category": W, "tier": 2, "factor": 1.12, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "yan_ring_saber", "text": "刀法比刀老，刀也比城老。"},
	"city_lgd_vest": {"name": "近卫局制式护甲", "region": "city", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "lgd_vest", "text": "肩上的局徽被刮过，但没刮干净。"},
	"city_fire_suit": {"name": "消防署隔热服", "region": "city", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.RES_FLAT, 2.0]],
		"icon": "fire_suit", "text": "那天烧得最厉害的地方，他们最先进去。"},
	"city_carrier": {"name": "押运防弹背心", "region": "city", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.DEF_FLAT, 10.0], [S.MAX_HP_PCT, 0.01]],
		"icon": "courier_vest", "text": "插板缺了一块，正好是挨过的那一块。"},
	"city_inspector": {"name": "特别督察组战术护甲", "region": "city", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 10.0], [S.CRIT_RATE, 0.015]],
		"icon": "inspector_armor", "text": "这身护甲的上一任主人，任期没满两年。"},
	"city_charm": {"name": "战术挂饰", "region": "city", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.05]],
		"icon": "tactical_charm", "text": "挂在背心上的小东西，谁都有一个。"},
	"city_radio": {"name": "近卫局对讲机", "region": "city", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.SKILL_CD_PCT, -0.0375]],
		"icon": "lgd_radio", "text": "频道里只剩杂音，偶尔有人报位置。"},
	"city_wallet": {"name": "龙门币钱夹", "region": "city", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.GOLD_GAIN_PCT, 0.075]], "value": 1.5,
		"icon": "lungmen_wallet", "text": "里面的钱早花完了，钱夹本身倒值钱。"},
	"city_talisman": {"name": "炎式平安符", "region": "city", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.RES_FLAT, 2.0], [S.MAX_HP_PCT, 0.02]],
		"icon": "yan_talisman", "text": "求平安的人，未必平安，但符留下来了。"},
	# --- 萨米 · 冻土林线 (§4.3)
	"snow_icebreaker": {"name": "破冰刀", "region": "snow", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"form": "blade", "enemies": ["ice_warrior"], "icon": "icebreaker_knife", "text": "先敲开冰，再敲开别的。"},
	"snow_skinner": {"name": "猎刀", "region": "snow", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "skinning_knife", "text": "皮要剥得完整，这是猎人对猎物的礼数。"},
	"snow_antler_knife": {"name": "角柄猎刀", "region": "snow", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"form": "blade", "icon": "antler_hunter_knife", "text": "角是向林子借的，用完要还。"},
	"snow_machete": {"name": "科考队开路刀", "region": "snow", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "blade", "icon": "expedition_machete", "text": "南边城市造的刀，走到这里已经不像南边的了。"},
	"snow_rite_blade": {"name": "雪祀礼刃", "region": "snow", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_PCT, 0.04], [S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "snowpriest_blade", "text": "埋在冻土下面，刃口依然是冷的。"},
	"snow_fur_coat": {"name": "冰原毛皮外套", "region": "snow", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.02]],
		"icon": "tundra_fur_coat", "text": "毛朝里穿，雪就进不来。"},
	"snow_cloak": {"name": "雪橇巡逻队斗篷", "region": "snow", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.02]],
		"icon": "sled_patrol_cloak", "text": "披上它，雪地里远远就能认出你是自己人。"},
	"snow_parka": {"name": "科考队防寒服", "region": "snow", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 3.0]],
		"icon": "expedition_parka", "text": "标签上写的温度，这里早就低过了。"},
	"snow_lamellar": {"name": "骨片札甲", "region": "snow", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 10.0], [S.MAX_HP_PCT, 0.02]],
		"icon": "bone_lamellar", "text": "每一片骨头，都来自一只认得这片林子的兽。"},
	"snow_amulet": {"name": "骨制护符", "region": "snow", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.ARTS_PCT, 0.025]],
		"icon": "bone_amulet", "text": "刻痕被很多只手摸平了。"},
	"snow_flute": {"name": "角兽骨笛", "region": "snow", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.025]],
		"icon": "antler_flute", "text": "吹响时，林子会安静一下。"},
	"snow_drumstick": {"name": "兽骨鼓槌", "region": "snow", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.EXP_GAIN_PCT, 0.075]],
		"icon": "bone_drumstick", "text": "敲鼓的人不在了，鼓槌还记得节拍。"},
	"snow_cipher": {"name": "密文板残片", "region": "snow", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.025], [S.SKILL_CD_PCT, -0.0375]],
		"icon": "cipher_fragment", "text": "读不懂上面的字，但它好像读得懂你。"},
	# --- 装备扩充策划案 §4 (2026-10-11 用户：全上): 63 bases + 3 polearms (长柄).
	"mine_x01": {"name": "工兵锹", "region": "mine", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 20.0]], "form": "heavy",
		"icon": "mine_x01", "text": "锹口磨过，柄上还沾着冻土。"},
	"mine_x02": {"name": "大号管钳", "region": "mine", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]], "form": "heavy",
		"icon": "mine_x02", "text": "本来是拧热泵阀门的。"},
	"mine_x03": {"name": "缠链指虎", "region": "mine", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.1]], "form": "fist",
		"icon": "mine_x03", "text": "矿车上拆下来的链节，一圈一圈缠紧。"},
	"mine_x04": {"name": "纠察队钩刀", "region": "mine", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.MOVE_SPEED_PCT, 0.04]], "form": "blade", "enemies": ["picket"],
		"icon": "mine_x04", "text": "钩背上的磨痕不是砍出来的，是拖出来的。"},
	"mine_x05": {"name": "游击队旧式刺刀", "region": "mine", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATK_PCT, 0.04]], "form": "blade",
		"icon": "mine_x05", "text": "型号停产很多年了，刃口没停过。"},
	"mine_x06": {"name": "施术短刃", "region": "mine", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ARTS_PCT, 0.05]], "form": "blade", "enemies": ["caster"],
		"icon": "mine_x06", "text": "刀柄里嵌着一枚拆下来的施术单元，握久了手心发烫。"},
	"mine_x07": {"name": "攻坚破门锤", "region": "mine", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.CRIT_DMG, 0.1], [S.MOVE_SPEED_PCT, -0.04]], "form": "heavy",
		"icon": "mine_x07", "text": "门开了，门后的东西也是。"},
	"mine_x08": {"name": "帝国突击矛", "region": "mine", "category": W, "tier": 2, "factor": 1.10, "implicit": [[S.CRIT_RATE, 0.03]], "form": "polearm",
		"icon": "mine_x08", "text": "矛杆上的编号是一个营。"},
	"mine_x09": {"name": "拼装轻甲", "region": "mine", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "mine_x09", "text": "三套甲拆成一套，扣子都对不上。"},
	"mine_x10": {"name": "改装喷射背架", "region": "mine", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.DASH_COST_PCT, -0.0625]],
		"icon": "mine_x10", "text": "燃料早就烧完了，背带还结实。"},
	"mine_x11": {"name": "整合运动术师兜袍", "region": "mine", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.ARTS_PCT, 0.0375]],
		"icon": "mine_x11", "text": "袖口被烧穿过，从里面。"},
	"mine_x12": {"name": "伪装吉利服", "region": "mine", "category": A, "tier": 1, "factor": 1.00, "implicit": [[S.EVASION, 0.02], [S.CRIT_RATE, 0.0075]],
		"icon": "mine_x12", "text": "披上它，矿道里就少了一个人。"},
	"mine_x13": {"name": "游击队旧式军大衣", "region": "mine", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.HP_FLAT, 147.0]],
		"icon": "mine_x13", "text": "补丁比原布多，扣子一颗不少。"},
	"mine_x14": {"name": "复合护具", "region": "mine", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.MAX_HP_PCT, 0.03], [S.RES_FLAT, 2.0], [S.MOVE_SPEED_PCT, -0.01]],
		"icon": "mine_x14", "text": "罐子、管子、面罩，一样都不能少。"},
	"mine_x15": {"name": "头戴矿灯", "region": "mine", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.DROP_RATE_PCT, 0.05]],
		"icon": "mine_x15", "text": "电池还剩一格。"},
	"mine_x16": {"name": "军用止血带", "region": "mine", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.HP_FLAT, 98.0]],
		"icon": "mine_x16", "text": "扣环上写着上一个人的血型。"},
	"mine_x17": {"name": "劳役编号牌", "region": "mine", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "mine_x17", "text": "铁皮压的，比戴它的人结实。"},
	"mine_x18": {"name": "切尔文铜币", "region": "mine", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.CRIT_RATE, 0.0225]],
		"icon": "mine_x18", "text": "在矿里，它买不到任何东西。"},
	"mine_x19": {"name": "纠察队手铐", "region": "mine", "category": T, "tier": 1, "factor": 1.05, "implicit": [[S.ATK_PCT, 0.02], [S.ATK_FLAT, 12.0]],
		"icon": "mine_x19", "text": "钥匙不在这里。"},
	"mine_x20": {"name": "游击队臂章", "region": "mine", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.ATTACK_SPEED_PCT, 0.025], [S.MOVE_SPEED_PCT, 0.01]],
		"icon": "mine_x20", "text": "线是自己缝的，针脚很密。"},
	"mine_x21": {"name": "高能虫囊", "region": "mine", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.0375], [S.SKILL_PCT, 0.0625], [S.MAX_HP_PCT, -0.01]],
		"icon": "mine_x21", "text": "摸上去是温的，最好别摸。"},
	"mine_x22": {"name": "拆下的施术单元", "region": "mine", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_FLAT, 24.0], [S.RES_FLAT, 2.0]],
		"icon": "mine_x22", "text": "从一架掉下来的无人机里拆的。"},
	"city_x01": {"name": "拆迁大锤", "region": "city", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.1]], "form": "heavy",
		"icon": "city_x01", "text": "墙上用红漆写过一个字，后来墙没了。"},
	"city_x02": {"name": "铜指虎", "region": "city", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_RATE, 0.03]], "form": "fist",
		"icon": "city_x02", "text": "指节上的磨痕，比铜还亮。"},
	"city_x03": {"name": "消防斧", "region": "city", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATK_PCT, 0.04]], "form": "heavy",
		"icon": "city_x03", "text": "门锁着的时候，它就是钥匙。"},
	"city_x04": {"name": "蝴蝶双刀", "region": "city", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]], "form": "blade", "enemies": ["greytail"],
		"icon": "city_x04", "text": "两把刀，一套拳理。"},
	"city_x05": {"name": "护卫铁尺", "region": "city", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 4.0]], "form": "fist",
		"icon": "city_x05", "text": "不开刃，打在身上也不留口子。"},
	"city_x06": {"name": "警用链锤", "region": "city", "category": W, "tier": 2, "factor": 1.12, "implicit": [[S.ATK_PCT, 0.04], [S.MOVE_SPEED_PCT, -0.04]], "form": "heavy",
		"icon": "city_x06", "text": "警员们说，最好别让它出手。"},
	"city_x07": {"name": "炎式苗刀", "region": "city", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.CRIT_DMG, 0.1], [S.MOVE_SPEED_PCT, -0.04]], "form": "blade",
		"icon": "city_x07", "text": "刀身太长，只能用双手，也只能用一辈子。"},
	"city_x08": {"name": "炎式朴刀", "region": "city", "category": W, "tier": 2, "factor": 1.10, "implicit": [[S.ATK_PCT, 0.04]], "form": "polearm",
		"icon": "city_x08", "text": "柄是木头，刃是旧的，路是自己走的。"},
	"city_x09": {"name": "执勤反光雨衣", "region": "city", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.02]],
		"icon": "city_x09", "text": "雨从不停，巡逻也不停。"},
	"city_x10": {"name": "拳馆练功服", "region": "city", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.EXP_GAIN_PCT, 0.05]],
		"icon": "city_x10", "text": "衣服换过三次，师父没换过。"},
	"city_x11": {"name": "染血白工装", "region": "city", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.HP_FLAT, 98.0]],
		"icon": "city_x11", "text": "洗不掉的部分，就当是颜色。"},
	"city_x12": {"name": "拾荒者伪装衫", "region": "city", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.DEF_FLAT, 10.0], [S.EVASION, 0.01]],
		"icon": "city_x12", "text": "外面是破布，里面是钢板。"},
	"city_x13": {"name": "香主绸衫", "region": "city", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 2.0], [S.CRIT_DMG, 0.025]],
		"icon": "city_x13", "text": "绸子挡不住刀，挡刀的是别的东西。"},
	"city_x14": {"name": "防爆重甲", "region": "city", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 25.0], [S.MOVE_SPEED_PCT, -0.01]],
		"icon": "city_x14", "text": "穿上它就不用跑了，反正也跑不动。"},
	"city_x15": {"name": "执勤警哨", "region": "city", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.02]],
		"icon": "city_x15", "text": "吹响以后，往哪边跑都对。"},
	"city_x16": {"name": "防风打火机", "region": "city", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.ARTS_FLAT, 24.0]],
		"icon": "city_x16", "text": "点烟用的，也点别的。"},
	"city_x17": {"name": "老千骰子", "region": "city", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.DROP_RATE_PCT, 0.075], [S.CRIT_RATE, -0.0075]],
		"icon": "city_x17", "text": "六面都是好点数的那一颗，找不到了。"},
	"city_x18": {"name": "跌打药酒瓶", "region": "city", "category": T, "tier": 1, "factor": 1.05, "implicit": [[S.HP_FLAT, 147.0]],
		"icon": "city_x18", "text": "酒是外用的。大部分时候。"},
	"city_x19": {"name": "无人机遥控器", "region": "city", "category": T, "tier": 1, "factor": 1.05, "implicit": [[S.SKILL_PCT, 0.0625], [S.ATTACK_SPEED_PCT, 0.0125]],
		"icon": "city_x19", "text": "屏幕上还有信号，飞机不知道在哪。"},
	"city_x20": {"name": "当铺铜牌", "region": "city", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.05], [S.GOLD_GAIN_PCT, 0.025]], "value": 1.2,
		"icon": "city_x20", "text": "当掉的东西没赎回来，牌子倒留下了。"},
	"city_x21": {"name": "琉璃护身珠", "region": "city", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.025], [S.RES_FLAT, 2.0]],
		"icon": "city_x21", "text": "有人用技艺烧出来的，冷了以后还在发光。"},
	"snow_x01": {"name": "染污短刀", "region": "snow", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.04]], "form": "blade", "enemies": ["taint_husk"],
		"icon": "snow_x01", "text": "握柄上的手印不是现在这只手的。"},
	"snow_x02": {"name": "伐木斧", "region": "snow", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.ATK_PCT, 0.04]], "form": "heavy",
		"icon": "snow_x02", "text": "斧刃上的漆是南边的颜色。"},
	"snow_x03": {"name": "兽颚指虎", "region": "snow", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]], "form": "fist",
		"icon": "snow_x03", "text": "牙还在，咬合的力气也还在。"},
	"snow_x04": {"name": "凿冰长刀", "region": "snow", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_DMG, 0.1]], "form": "blade",
		"icon": "snow_x04", "text": "冻住的东西，一刀就开。"},
	"snow_x05": {"name": "科考冰镐", "region": "snow", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.03]], "form": "heavy",
		"icon": "snow_x05", "text": "本来是用来挂住自己的。"},
	"snow_x06": {"name": "岩角战锤", "region": "snow", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_PCT, 0.04], [S.MOVE_SPEED_PCT, -0.04]], "form": "heavy",
		"icon": "snow_x06", "text": "角兽自己脱下来的角，比砍下来的重。"},
	"snow_x07": {"name": "裂骨拳刃", "region": "snow", "category": W, "tier": 2, "factor": 1.10, "implicit": [[S.ATTACK_SPEED_PCT, 0.05], [S.CRIT_RATE, 0.03]], "form": "fist",
		"icon": "snow_x07", "text": "战士们把骨头绑在前臂上，省得刀被打落。"},
	"snow_x08": {"name": "林线猎矛", "region": "snow", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.03]], "form": "polearm",
		"icon": "snow_x08", "text": "隔着一臂远，猎物才不会回头咬你。"},
	"snow_x09": {"name": "角兽长毛披肩", "region": "snow", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.EVASION, 0.02]],
		"icon": "snow_x09", "text": "趴在雪里时，和灌木没有分别。"},
	"snow_x10": {"name": "桦皮护胸", "region": "snow", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.RES_FLAT, 2.0]],
		"icon": "snow_x10", "text": "林子里长出来的东西，林子里的病碰不到它。"},
	"snow_x11": {"name": "林业护具", "region": "snow", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "snow_x11", "text": "设计时只想过倒下来的树。"},
	"snow_x12": {"name": "搜救队绳索背心", "region": "snow", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.STAMINA_REGEN_PCT, 0.1125]],
		"icon": "snow_x12", "text": "绳子的另一头，通常没有人。"},
	"snow_x13": {"name": "科考站加热背心", "region": "snow", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.MAX_HP_PCT, 0.02], [S.STAMINA_REGEN_PCT, 0.0375]],
		"icon": "snow_x13", "text": "线缆另一头接着的东西，早就冻住了。"},
	"snow_x14": {"name": "冬牙角盔", "region": "snow", "category": HEAD, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.RES_FLAT, 1.0], [S.MOVE_SPEED_PCT, -0.01]],
		"icon": "snow_x14", "text": "透过它看出去的人，都没有回来。"},
	"snow_x15": {"name": "雪祀羽氅", "region": "snow", "category": A, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.025], [S.SKILL_PCT, 0.0625]],
		"icon": "snow_x15", "text": "每一根羽毛都在等一场雪。"},
	"snow_x16": {"name": "族树木片", "region": "snow", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.02]],
		"icon": "snow_x16", "text": "树倒了以后，部族的人每人分了一片。"},
	"snow_x17": {"name": "鼷兽毛团", "region": "snow", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.STAMINA_REGEN_PCT, 0.075]],
		"icon": "snow_x17", "text": "它们挤在一起时，比任何皮袄都暖。"},
	"snow_x18": {"name": "幸运晶石", "region": "snow", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.DROP_RATE_PCT, 0.05]],
		"icon": "snow_x18", "text": "商贩说它挡过一刀。"},
	"snow_x19": {"name": "骨缝雪镜", "region": "snow", "category": T, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.015], [S.CRIT_DMG, 0.025]],
		"icon": "snow_x19", "text": "看得少，看得准。"},
	"snow_x20": {"name": "手持定位仪", "region": "snow", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.03]],
		"icon": "snow_x20", "text": "屏幕上的你一直在原地。"},
	"snow_x21": {"name": "角兽银铃", "region": "snow", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.RES_FLAT, 2.0], [S.MOVE_SPEED_PCT, 0.01]],
		"icon": "snow_x21", "text": "角兽走在前面，铃声替它认路。"},
	"snow_x22": {"name": "黑雪结晶", "region": "snow", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.0375], [S.SKILL_PCT, 0.0625], [S.MAX_HP_PCT, -0.01]],
		"icon": "snow_x22", "text": "握久了，会忘记为什么握着它。"},
	"snow_x23": {"name": "猎首獠牙串", "region": "snow", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ATK_PCT, 0.02], [S.CRIT_DMG, 0.05]],
		"icon": "snow_x23", "text": "每一颗都有过一个名字。"},
	# --- 叙拉古 · 沃尔西尼旧城区 (§11, 用户 2026-10-18): weapons only; armour and
	# trinkets there still come from the other three tables.
	"sira_stiletto": {"name": "家族细匕首", "region": "siracusa", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "enemies": ["family_soldier"], "icon": "family_stiletto", "text": "家族发的刀，和家族一样，细长，安静。"},
	"sira_knuckles": {"name": "黄铜拳套", "region": "siracusa", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 20.0]],
		"form": "fist", "enemies": ["family_intimidator"], "icon": "brass_knuckles", "text": "用来讲道理的。道理通常只用讲一次。"},
	"sira_switchblade": {"name": "弹簧折刀", "region": "siracusa", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"form": "blade", "icon": "switchblade", "text": "按一下就弹出来，像一句收不回去的话。"},
	"sira_crowbar": {"name": "旧城撬棍", "region": "siracusa", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"form": "heavy", "icon": "old_town_crowbar", "text": "旧城区的门都很老，撬棍比钥匙好使。"},
	"sira_razor": {"name": "理发店剃刀", "region": "siracusa", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "fist", "icon": "barber_razor", "text": "理发店的后门，比前门忙。"},
	"sira_cane_sword": {"name": "手杖剑", "region": "siracusa", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATK_PCT, 0.04]],
		"form": "blade", "icon": "cane_sword", "text": "体面人出门带手杖，手杖里带着别的。"},
	"sira_cleaver": {"name": "肉铺剁骨刀", "region": "siracusa", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_DMG, 0.10]],
		"form": "heavy", "icon": "butcher_cleaver", "text": "肉铺老板欠的账，用这把刀还过一次。"},
	"sira_billhook": {"name": "葡萄园修枝镰", "region": "siracusa", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "polearm", "icon": "vineyard_billhook", "text": "城外的葡萄园也分家族，修枝的人也是。"},
	"sira_eraser_blade": {"name": "灭迹弯刃", "region": "siracusa", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.CRIT_DMG, 0.10], [S.CRIT_RATE, 0.03]],
		"form": "blade", "enemies": ["family_eraser"], "icon": "eraser_curved_blade", "text": "人人都知道它的主人，没人提起它的主人。"},
	"sira_lead_cane": {"name": "角头的灌铅手杖", "region": "siracusa", "category": W, "tier": 2, "factor": 1.12, "implicit": [[S.ATK_PCT, 0.04], [S.MOVE_SPEED_PCT, -0.04]],
		"form": "heavy", "icon": "lead_cane", "text": "他从不带武器。手杖不算。"},
	"sira_wolf_knuckles": {"name": "狼首指虎", "region": "siracusa", "category": W, "tier": 2, "factor": 1.10, "implicit": [[S.ATTACK_SPEED_PCT, 0.05], [S.CRIT_RATE, 0.03]],
		"form": "fist", "icon": "wolfhead_knuckles", "text": "家族的狼头铸在拳上，挨过的人都记得是哪一家。"},
	# --- 远程与法杖 (§12, 用户 2026-10-18: 各地区补远程和法杖武器).
	"mine_r1": {"name": "整合运动手弩", "region": "mine", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "crossbow", "enemies": ["crossbow"], "icon": "reunion_hand_crossbow", "text": "弩臂是旧弹簧钢，弦是新换的。"},
	"mine_r2": {"name": "改装射钉枪", "region": "mine", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "crossbow", "icon": "modified_nail_gun", "text": "本来是钉支架的，现在钉别的。"},
	"mine_r3": {"name": "帝国制式重弩", "region": "mine", "category": W, "tier": 2, "factor": 1.12, "implicit": [[S.ATK_PCT, 0.04], [S.CRIT_DMG, 0.10]],
		"form": "crossbow", "icon": "imperial_heavy_crossbow", "text": "乌萨斯军的库存，整合运动拿走了一半。"},
	"mine_s1": {"name": "拼装施术杖", "region": "mine", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.ARTS_PCT, 0.05]],
		"form": "staff", "icon": "scrap_casting_staff", "text": "铁管里塞着拆下的施术单元，能用就行。"},
	"mine_s2": {"name": "整合运动术师长杖", "region": "mine", "category": W, "tier": 2, "factor": 1.12, "implicit": [[S.ARTS_PCT, 0.05], [S.CRIT_RATE, 0.03]],
		"form": "staff", "icon": "reunion_caster_staff", "text": "杖头的结晶，是从持杖人身上长出来的。"},
	"city_r1": {"name": "近卫局警用手弩", "region": "city", "category": W, "tier": 0, "factor": 1.00, "implicit": [],
		"form": "crossbow", "icon": "lgd_hand_crossbow", "text": "非致命弩箭的弹匣里，混了几支致命的。"},
	"city_r2": {"name": "组长连弩", "region": "city", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "crossbow", "enemies": ["crossbow_leader"], "icon": "leader_repeating_crossbow", "text": "一次三支，总有一支找得到人。"},
	"city_r3": {"name": "拉特兰走私手铳", "region": "city", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.CRIT_DMG, 0.10], [S.CRIT_RATE, 0.03]],
		"form": "gun", "icon": "laterano_smuggled_pistol", "text": "龙门的海关查得很严，所以它很贵。"},
	"city_s1": {"name": "铜铃术杖", "region": "city", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.RES_FLAT, 4.0]],
		"form": "staff", "icon": "bronze_bell_staff", "text": "铃声一响，街口的人就散了。"},
	"city_s2": {"name": "炎式符杖", "region": "city", "category": W, "tier": 2, "factor": 1.12, "implicit": [[S.ARTS_PCT, 0.05], [S.RES_FLAT, 4.0]],
		"form": "staff", "icon": "yan_talisman_staff", "text": "符纸换过很多次，杖还是那根。"},
	"snow_r1": {"name": "萨米猎弓", "region": "snow", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"form": "bow", "icon": "sami_hunting_bow", "text": "弓是自己做的，弦是猎物给的。"},
	"snow_r2": {"name": "冰原猎铳", "region": "snow", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "gun", "enemies": ["ice_hunter"], "icon": "tundra_hunting_gun", "text": "专挑最弱的那一只。"},
	"snow_r3": {"name": "复合角弓", "region": "snow", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_PCT, 0.04], [S.CRIT_RATE, 0.03]],
		"form": "bow", "icon": "composite_horn_bow", "text": "角来自一头老兽，它活得比射它的人久。"},
	"snow_s1": {"name": "桦木巫杖", "region": "snow", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.RES_FLAT, 4.0]],
		"form": "staff", "icon": "birch_shaman_staff", "text": "剥开桦树皮，里面刻着谁也读不懂的纹路。"},
	"snow_s2": {"name": "雪祀仪杖", "region": "snow", "category": W, "tier": 2, "factor": 1.12, "implicit": [[S.ARTS_PCT, 0.05], [S.MAX_HP_PCT, 0.04]],
		"form": "staff", "icon": "snowpriest_staff", "text": "杖指向哪里，雪就落向哪里。"},
	"sira_r1": {"name": "家族枪弩", "region": "siracusa", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "crossbow", "enemies": ["family_crossbow"], "icon": "family_gun_crossbow", "text": "家族配的弩难称精良，但够用。"},
	"sira_r2": {"name": "折叠袖弩", "region": "siracusa", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"form": "crossbow", "icon": "folding_sleeve_crossbow", "text": "藏在袖子里，握手的时候最方便。"},
	"sira_r3": {"name": "猎场双管铳", "region": "siracusa", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_PCT, 0.04], [S.CRIT_DMG, 0.10]],
		"form": "gun", "icon": "double_barrel_gun", "text": "城外的猎场也有规矩：先开枪的人说了算。"},
	"sira_s1": {"name": "律师的施术手杖", "region": "siracusa", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ARTS_PCT, 0.05]],
		"form": "staff", "icon": "lawyer_casting_cane", "text": "法律是叙拉古最好用的武器，其次是这根手杖。"},
	"sira_s2": {"name": "审判庭仪杖", "region": "siracusa", "category": W, "tier": 2, "factor": 1.12, "implicit": [[S.ARTS_PCT, 0.05], [S.CRIT_DMG, 0.10]],
		"form": "staff", "icon": "tribunal_staff", "text": "叙拉古的法庭不判对错，只判谁欠了谁。"},
	"rhodes_crossbow": {"name": "罗德岛制式弩", "region": "rhodes", "value": 1.5, "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "crossbow", "icon": "rhodes_crossbow", "text": "改装记录比它本身还厚。"},
	"rhodes_staff": {"name": "罗德岛制式法杖", "region": "rhodes", "value": 1.5, "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ARTS_PCT, 0.05]],
		"form": "staff", "icon": "rhodes_staff", "text": "医疗部和术师组吵了半年，吵出来这一根。"},
	# --- 罗德岛制式装备 (§10, 用户 2026-10-18): never dropped. Each recruit
	# comes with a set; 加工部 makes more; outside factions buy them.
	"rhodes_dual_blades": {"name": "罗德岛制式双刀", "region": "rhodes", "value": 1.5, "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATK_PCT, 0.04]],
		"form": "blade", "icon": "rhodes_dual_blades", "text": "训练场上教的第一套刀，就是这一套。"},
	"rhodes_sword": {"name": "罗德岛制式剑", "region": "rhodes", "value": 1.5, "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "rhodes_sword", "text": "制式的剑，用的人不制式。"},
	"rhodes_uniform": {"name": "罗德岛外勤制服", "region": "rhodes", "value": 1.5, "category": A, "tier": 1, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.02]],
		"icon": "rhodes_field_uniform", "text": "后勤部发的，尺码总是大一号。"},
	"rhodes_vest": {"name": "罗德岛制式防护背心", "region": "rhodes", "value": 1.5, "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "rhodes_protective_vest", "text": "工程部说它能挡住大多数东西，医疗部说别信。"},
	"rhodes_beacon": {"name": "罗德岛制式信标", "region": "rhodes", "value": 1.5, "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.02]],
		"icon": "rhodes_beacon", "text": "只要它还亮着，就有人知道你在哪。"},
	"rhodes_medkit": {"name": "罗德岛制式急救包", "region": "rhodes", "value": 1.5, "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.02]],
		"icon": "rhodes_medkit", "text": "绷带、止血钳，都是制式的；用的人不是。"},
	"rhodes_badge": {"name": "罗德岛干员证章", "region": "rhodes", "value": 1.5, "category": T, "tier": 1, "factor": 1.05, "implicit": [[S.EXP_GAIN_PCT, 0.05]],
		"icon": "rhodes_badge", "text": "特别颁发，以兹证明。"},
	# --- E15 (装备部位拆分与数值案 §7): head, hands, legs, feet and rings; the art
	# brief is art/items/E15_slot_split_brief_v1.md, placeholders until it lands.
	"mine_head_1": {"name": "矿工安全帽", "region": "mine", "category": HEAD, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "mine_head_1", "text": "帽檐的灯夹空着，灯早就换了钱。"},
	"mine_head_2": {"name": "整合运动兜帽", "region": "mine", "category": HEAD, "tier": 0, "factor": 1.00, "implicit": [[S.ARTS_PCT, 0.025]],
		"icon": "mine_head_2", "text": "兜帽底下是谁，没人在乎。"},
	"mine_head_3": {"name": "纠察队毛皮帽", "region": "mine", "category": HEAD, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 2.0], [S.MAX_HP_PCT, 0.01]],
		"icon": "mine_head_3", "text": "护耳放下来，就听不见矿洞里的哭声。"},
	"mine_head_4": {"name": "重装防爆头盔", "region": "mine", "category": HEAD, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 15.0], [S.RES_FLAT, 2.0], [S.MOVE_SPEED_PCT, -0.01]],
		"icon": "mine_head_4", "text": "视窗只留一条缝，够看清前面的人倒下。"},
	"mine_hands_1": {"name": "帆布劳保手套", "region": "mine", "category": HANDS, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_RATE, 0.015]],
		"icon": "mine_hands_1", "text": "指尖磨薄了，握刀反而更稳。"},
	"mine_hands_2": {"name": "整合运动缠手布", "region": "mine", "category": HANDS, "tier": 0, "factor": 1.00, "implicit": [[S.ATTACK_SPEED_PCT, 0.025]],
		"icon": "mine_hands_2", "text": "缠了一圈又一圈，里面那根红线是谁系的？"},
	"mine_hands_3": {"name": "矿镐护腕", "region": "mine", "category": HANDS, "tier": 1, "factor": 1.05, "implicit": [[S.ATK_PCT, 0.02], [S.DEF_FLAT, 5.0]],
		"icon": "mine_hands_3", "text": "侧面的皮绳换过三次。"},
	"mine_hands_4": {"name": "纠察队铁指护手", "region": "mine", "category": HANDS, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_FLAT, 24.0], [S.CRIT_RATE, 0.015]],
		"icon": "mine_hands_4", "text": "铁指节上的凹痕，都是别人的牙。"},
	"mine_legs_1": {"name": "矿工工装裤", "region": "mine", "category": LEGS, "tier": 0, "factor": 1.00, "implicit": [[S.HP_FLAT, 98.0]],
		"icon": "mine_legs_1", "text": "膝盖上的补丁比原布还厚。"},
	"mine_legs_2": {"name": "整合运动束腿裤", "region": "mine", "category": LEGS, "tier": 0, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.02]],
		"icon": "mine_legs_2", "text": "小腿扎紧，跑起来不绊脚。"},
	"mine_legs_3": {"name": "游击队绑腿", "region": "mine", "category": LEGS, "tier": 1, "factor": 1.05, "implicit": [[S.STAMINA_REGEN_PCT, 0.075], [S.MOVE_SPEED_PCT, 0.01]],
		"icon": "mine_legs_3", "text": "从膝盖缠到脚踝，冻原的老规矩。"},
	"mine_legs_4": {"name": "复合护腿", "region": "mine", "category": LEGS, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.MAX_HP_PCT, 0.01], [S.MOVE_SPEED_PCT, -0.01]],
		"icon": "mine_legs_4", "text": "螺栓拧死的护板，摘下来得用扳手。"},
	"mine_feet_1": {"name": "钢头劳保靴", "region": "mine", "category": FEET, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "mine_feet_1", "text": "钢头磨亮了，踢开过不少门。"},
	"mine_feet_2": {"name": "整合运动帆布鞋", "region": "mine", "category": FEET, "tier": 0, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.02]],
		"icon": "mine_feet_2", "text": "一根鞋带换成了红绳。"},
	"mine_feet_3": {"name": "游击队行军靴", "region": "mine", "category": FEET, "tier": 1, "factor": 1.05, "implicit": [[S.STAMINA_REGEN_PCT, 0.1125]],
		"icon": "mine_feet_3", "text": "靴底的钉子一颗都没少。"},
	"mine_feet_4": {"name": "纠察队毛毡靴", "region": "mine", "category": FEET, "tier": 2, "factor": 1.15, "implicit": [[S.MAX_HP_PCT, 0.02], [S.RES_FLAT, 2.0]],
		"icon": "mine_feet_4", "text": "毡靴外面套着胶鞋，雪水进不来。"},
	"mine_ring_1": {"name": "铁丝绕成的指环", "region": "mine", "category": RING, "tier": 0, "factor": 1.00, "implicit": [[S.ATK_FLAT, 24.0]],
		"icon": "mine_ring_1", "text": "三圈铁丝，绕得很用心。"},
	"mine_ring_2": {"name": "源石碎粒戒", "region": "mine", "category": RING, "tier": 0, "factor": 1.00, "implicit": [[S.ARTS_FLAT, 36.0], [S.MAX_HP_PCT, -0.01]],
		"icon": "mine_ring_2", "text": "那一点光不是宝石，是病。"},
	"mine_ring_3": {"name": "矿车铆钉戒", "region": "mine", "category": RING, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.015], [S.ATK_FLAT, 12.0]],
		"icon": "mine_ring_3", "text": "一颗铆钉敲弯了，就是戒指。"},
	"mine_ring_4": {"name": "整合运动誓约环", "region": "mine", "category": RING, "tier": 2, "factor": 1.15, "implicit": [[S.SKILL_PCT, 0.0625], [S.CRIT_DMG, 0.05]],
		"icon": "mine_ring_4", "text": "红釉一圈，戴上的人不会再摘。"},
	"city_head_1": {"name": "街头鸭舌帽", "region": "city", "category": HEAD, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_RATE, 0.015]],
		"icon": "city_head_1", "text": "帽檐晒褪了色，城里的风没变。"},
	"city_head_2": {"name": "近卫局制式头盔", "region": "city", "category": HEAD, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "city_head_2", "text": "面罩翻上去的时候，才像个人。"},
	"city_head_3": {"name": "消防署防烟头盔", "region": "city", "category": HEAD, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 3.0]],
		"icon": "city_head_3", "text": "后檐很长，挡得住落下来的火。"},
	"city_head_4": {"name": "特别督察组战术头盔", "region": "city", "category": HEAD, "tier": 2, "factor": 1.15, "implicit": [[S.CRIT_RATE, 0.015], [S.DEF_FLAT, 10.0]],
		"icon": "city_head_4", "text": "护目镜扣在顶上，随时能拉下来。"},
	"city_hands_1": {"name": "拳馆缠手带", "region": "city", "category": HANDS, "tier": 0, "factor": 1.00, "implicit": [[S.ATTACK_SPEED_PCT, 0.025]],
		"icon": "city_hands_1", "text": "关节处的颜色洗不掉了。"},
	"city_hands_2": {"name": "近卫局战术手套", "region": "city", "category": HANDS, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_RATE, 0.015]],
		"icon": "city_hands_2", "text": "露出指头，才扣得住扳机。"},
	"city_hands_3": {"name": "押运员护腕", "region": "city", "category": HANDS, "tier": 1, "factor": 1.05, "implicit": [[S.DEF_FLAT, 15.0]],
		"icon": "city_hands_3", "text": "手背上那块钢板挡过一刀。"},
	"city_hands_4": {"name": "消防隔热手套", "region": "city", "category": HANDS, "tier": 2, "factor": 1.15, "implicit": [[S.RES_FLAT, 3.0], [S.MAX_HP_PCT, 0.02], [S.ATTACK_SPEED_PCT, -0.0125]],
		"icon": "city_hands_4", "text": "笨重得很，抓得住烧红的门把。"},
	"city_legs_1": {"name": "拳馆灯笼裤", "region": "city", "category": LEGS, "tier": 0, "factor": 1.00, "implicit": [[S.EVASION, 0.02]],
		"icon": "city_legs_1", "text": "裤脚收紧，扫腿不拖泥。"},
	"city_legs_2": {"name": "近卫局制式长裤", "region": "city", "category": LEGS, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.02]],
		"icon": "city_legs_2", "text": "侧边一道白线，站岗时最显眼。"},
	"city_legs_3": {"name": "押运防刺护腿", "region": "city", "category": LEGS, "tier": 1, "factor": 1.05, "implicit": [[S.DEF_FLAT, 15.0]],
		"icon": "city_legs_3", "text": "护板缝在里层，外面看不出来。"},
	"city_legs_4": {"name": "香主绸裤", "region": "city", "category": LEGS, "tier": 2, "factor": 1.15, "implicit": [[S.EVASION, 0.02], [S.CRIT_DMG, 0.05]],
		"icon": "city_legs_4", "text": "云纹只在光下才看得见。"},
	"city_feet_1": {"name": "功夫布鞋", "region": "city", "category": FEET, "tier": 0, "factor": 1.00, "implicit": [[S.DASH_COST_PCT, -0.0625]],
		"icon": "city_feet_1", "text": "白底黑面，落地没声音。"},
	"city_feet_2": {"name": "外卖员跑鞋", "region": "city", "category": FEET, "tier": 0, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.03], [S.DEF_FLAT, -5.0]],
		"icon": "city_feet_2", "text": "跑得比订单还快。"},
	"city_feet_3": {"name": "近卫局作战靴", "region": "city", "category": FEET, "tier": 1, "factor": 1.05, "implicit": [[S.MOVE_SPEED_PCT, 0.02], [S.DEF_FLAT, 5.0]],
		"icon": "city_feet_3", "text": "鞋尖擦得能照人。"},
	"city_feet_4": {"name": "消防署隔热靴", "region": "city", "category": FEET, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 15.0], [S.RES_FLAT, 2.0], [S.MOVE_SPEED_PCT, -0.01]],
		"icon": "city_feet_4", "text": "反光条在火场里最先被看见。"},
	"city_ring_1": {"name": "炎式玉扳指", "region": "city", "category": RING, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.05]],
		"icon": "city_ring_1", "text": "拇指上的玉，凉得很。"},
	"city_ring_2": {"name": "当铺金戒", "region": "city", "category": RING, "tier": 0, "factor": 1.00, "implicit": [[S.GOLD_GAIN_PCT, 0.05]],
		"icon": "city_ring_2", "text": "当了三回，赎了三回。"},
	"city_ring_3": {"name": "近卫局纪念戒", "region": "city", "category": RING, "tier": 1, "factor": 1.05, "implicit": [[S.HP_FLAT, 147.0]],
		"icon": "city_ring_3", "text": "戒面上的盾什么也没刻。"},
	"city_ring_4": {"name": "龙门老字号金戒", "region": "city", "category": RING, "tier": 2, "factor": 1.15, "implicit": [[S.CRIT_RATE, 0.015], [S.CRIT_DMG, 0.05]],
		"icon": "city_ring_4", "text": "红石头，云纹边，老铺子的手艺。"},
	"snow_head_1": {"name": "冰原毛皮兜帽", "region": "snow", "category": HEAD, "tier": 0, "factor": 1.00, "implicit": [[S.RES_FLAT, 2.0]],
		"icon": "snow_head_1", "text": "抽绳一拉，只剩一双眼睛。"},
	"snow_head_2": {"name": "科考队防风帽", "region": "snow", "category": HEAD, "tier": 1, "factor": 1.05, "implicit": [[S.SKILL_CD_PCT, -0.0375], [S.RES_FLAT, 1.0]],
		"icon": "snow_head_2", "text": "雪镜推到额头上，就是在想事。"},
	"snow_head_3": {"name": "雪祀羽冠", "region": "snow", "category": HEAD, "tier": 2, "factor": 1.15, "implicit": [[S.ARTS_PCT, 0.0375], [S.SKILL_CD_PCT, -0.0375], [S.MAX_HP_PCT, -0.01]],
		"icon": "snow_head_3", "text": "每一根羽毛都有一个名字。"},
	"snow_hands_1": {"name": "冰原兽皮手套", "region": "snow", "category": HANDS, "tier": 0, "factor": 1.00, "implicit": [[S.HP_FLAT, 98.0]],
		"icon": "snow_hands_1", "text": "毛长得盖住了手腕。"},
	"snow_hands_2": {"name": "猎人绑带护手", "region": "snow", "category": HANDS, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_RATE, 0.015]],
		"icon": "snow_hands_2", "text": "一圈一圈缠紧，风钻不进去。"},
	"snow_hands_3": {"name": "科考队加热手套", "region": "snow", "category": HANDS, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.0375]],
		"icon": "snow_hands_3", "text": "电池快没电了，还是暖的。"},
	"snow_hands_4": {"name": "雪祀骨片护腕", "region": "snow", "category": HANDS, "tier": 2, "factor": 1.15, "implicit": [[S.ARTS_FLAT, 24.0], [S.SKILL_PCT, 0.0625]],
		"icon": "snow_hands_4", "text": "红绳绑着骨片，一片一片数过。"},
	"snow_legs_1": {"name": "兽皮护腿", "region": "snow", "category": LEGS, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.02]],
		"icon": "snow_legs_1", "text": "侧边系带，毛边朝外。"},
	"snow_legs_2": {"name": "雪橇队绑腿", "region": "snow", "category": LEGS, "tier": 0, "factor": 1.00, "implicit": [[S.STAMINA_REGEN_PCT, 0.075]],
		"icon": "snow_legs_2", "text": "粗绳绕到脚踝，踩进雪里也不松。"},
	"snow_legs_3": {"name": "科考队防寒裤", "region": "snow", "category": LEGS, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 2.0], [S.MAX_HP_PCT, 0.01]],
		"icon": "snow_legs_3", "text": "膝盖加厚过，跪在冰上也不冷。"},
	"snow_legs_4": {"name": "骨片札裙", "region": "snow", "category": LEGS, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 10.0], [S.ARTS_PCT, 0.025]],
		"icon": "snow_legs_4", "text": "走起来骨片相碰，像有人在低语。"},
	"snow_feet_1": {"name": "驯鹿皮靴", "region": "snow", "category": FEET, "tier": 0, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.02]],
		"icon": "snow_feet_1", "text": "靴尖翘起，绣着一道彩边。"},
	"snow_feet_2": {"name": "雪鞋", "region": "snow", "category": FEET, "tier": 0, "factor": 1.00, "implicit": [[S.DASH_COST_PCT, -0.09375], [S.MOVE_SPEED_PCT, -0.01]],
		"icon": "snow_feet_2", "text": "木框绑在靴子上，雪地里不陷。"},
	"snow_feet_3": {"name": "科考队防滑靴", "region": "snow", "category": FEET, "tier": 1, "factor": 1.05, "implicit": [[S.DASH_COST_PCT, -0.0625], [S.DEF_FLAT, 5.0]],
		"icon": "snow_feet_3", "text": "鞋底的纹深得能卡住石子。"},
	"snow_feet_4": {"name": "冰爪战靴", "region": "snow", "category": FEET, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 10.0], [S.DASH_COST_PCT, -0.0625]],
		"icon": "snow_feet_4", "text": "冰爪咬进冰面，人就不会滑倒。"},
	"snow_ring_1": {"name": "角兽骨戒", "region": "snow", "category": RING, "tier": 0, "factor": 1.00, "implicit": [[S.ATK_FLAT, 24.0]],
		"icon": "snow_ring_1", "text": "骨头磨出来的，一圈凹槽。"},
	"snow_ring_2": {"name": "族树木戒", "region": "snow", "category": RING, "tier": 0, "factor": 1.00, "implicit": [[S.ARTS_FLAT, 24.0]],
		"icon": "snow_ring_2", "text": "木纹细得像指纹。"},
	"snow_ring_3": {"name": "冰晶指环", "region": "snow", "category": RING, "tier": 1, "factor": 1.05, "implicit": [[S.ARTS_FLAT, 24.0], [S.RES_FLAT, 1.0]],
		"icon": "snow_ring_3", "text": "那一点蓝不会化。"},
	"snow_ring_4": {"name": "雪祀银环", "region": "snow", "category": RING, "tier": 2, "factor": 1.15, "implicit": [[S.SKILL_PCT, 0.0625], [S.ARTS_FLAT, 24.0]],
		"icon": "snow_ring_4", "text": "三颗骨珠，三个祷词。"},
	"rhodes_head": {"name": "罗德岛外勤头盔", "region": "rhodes", "value": 1.5, "category": HEAD, "tier": 1, "factor": 1.05, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "rhodes_head", "text": "制式的，戴着它的人不是。"},
	"rhodes_hands": {"name": "罗德岛外勤手套", "region": "rhodes", "value": 1.5, "category": HANDS, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.025]],
		"icon": "rhodes_hands", "text": "指节的护垫是蓝灰色的。"},
	"rhodes_legs": {"name": "罗德岛外勤长裤", "region": "rhodes", "value": 1.5, "category": LEGS, "tier": 1, "factor": 1.05, "implicit": [[S.MAX_HP_PCT, 0.02]],
		"icon": "rhodes_legs", "text": "护膝换过一次，还是同一款。"},
	"rhodes_feet": {"name": "罗德岛外勤战靴", "region": "rhodes", "value": 1.5, "category": FEET, "tier": 1, "factor": 1.05, "implicit": [[S.MOVE_SPEED_PCT, 0.02]],
		"icon": "rhodes_feet", "text": "走过的路比舰上任何人都远。"},
	"rhodes_ring": {"name": "罗德岛干员指环", "region": "rhodes", "value": 1.5, "category": RING, "tier": 1, "factor": 1.05, "implicit": [[S.SKILL_PCT, 0.0625]],
		"icon": "rhodes_ring", "text": "一道蓝灰色的细线，就是证明。"},
	# --- E16 (用户 2026-10-22): the protective line that goes with 制式防护背心;
	# art brief art/items/E16_rhodes_heavy_brief_v1.md, placeholders until it lands.
	"rhodes_head_heavy": {"name": "罗德岛制式防护头盔", "region": "rhodes", "value": 1.5, "category": HEAD, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 2.0]],
		"icon": "rhodes_head_heavy", "text": "面罩放下来，谁也认不出是谁。"},
	"rhodes_hands_heavy": {"name": "罗德岛制式防护臂甲", "region": "rhodes", "value": 1.5, "category": HANDS, "tier": 1, "factor": 1.05, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "rhodes_hands_heavy", "text": "前臂那块白甲，挡刀比挡雨多。"},
	"rhodes_legs_heavy": {"name": "罗德岛制式防护护腿", "region": "rhodes", "value": 1.5, "category": LEGS, "tier": 1, "factor": 1.05, "implicit": [[S.DEF_FLAT, 10.0]],
		"icon": "rhodes_legs_heavy", "text": "护膝的扣带，工程部改过三版。"},
	"rhodes_feet_heavy": {"name": "罗德岛制式防护战靴", "region": "rhodes", "value": 1.5, "category": FEET, "tier": 1, "factor": 1.05, "implicit": [[S.HP_FLAT, 98.0]],
		"icon": "rhodes_feet_heavy", "text": "重是重了点，踩下去心里踏实。"},
	"rhodes_ring_monitor": {"name": "罗德岛生体监测环", "region": "rhodes", "value": 1.5, "category": RING, "tier": 1, "factor": 1.05, "implicit": [[S.MAX_HP_PCT, 0.02]],
		"icon": "rhodes_ring_monitor", "text": "那一点青光还亮着，医疗部就还在等你回去。"},
}

## Rhodes standard gear (制式保底修订, 用户 2026-10-23): never dropped, never
## made. The workbench issues it free into empty slots for one contract and
## takes it back when the contract ends, whether she comes home or not. Fixed
## numbers: tier Ⅰ, the band's middle, the base's intrinsics, no affixes, no
## prefixes. White until 科研部's 制式换代 makes it blue, then gold
## (BaseState.rhodes_rarity). Bound: no selling, packing, insuring or refitting.
const RHODES := "rhodes"
const RHODES_TIER := 1
const RHODES_RARITY := 0
const RHODES_VALUE := 5
## The choices per slot, in Item.SLOTS order.
const RHODES_KIT := [
	["rhodes_dual_blades", "rhodes_sword", "rhodes_crossbow", "rhodes_staff"],
	["rhodes_head", "rhodes_head_heavy"],
	["rhodes_uniform", "rhodes_vest"],
	["rhodes_hands", "rhodes_hands_heavy"],
	["rhodes_legs", "rhodes_legs_heavy"],
	["rhodes_feet", "rhodes_feet_heavy"],
	["rhodes_beacon", "rhodes_medkit", "rhodes_badge"],
	["rhodes_ring", "rhodes_ring_monitor"],
]

static func is_rhodes(id: String) -> bool:
	return str(base(id).get("region", "")) == RHODES

## Issued for one contract: kept off the shelves, the markets and the workbench's refits.
static func bound(item: Item) -> bool:
	return item != null and not item.base_id.is_empty() and is_rhodes(item.base_id)

## One piece of Rhodes standard gear at `rarity`. A ring or amulet is all ATK,
## or all arts for an operator who fights with a staff.
static func make_rhodes(id: String, rarity: int = RHODES_RARITY, operator_id: String = Operators.AMIYA_GUARD) -> Item:
	var b := base(id)
	var category := Item.slot_of(int(b.category))
	var size := GearSlots.size(category)
	rarity = clampi(rarity, 0, 2)
	var item := Item.create(str(b.name), category as Item.Category, size.x, size.y, Scaling.gear_power(RHODES_TIER, rarity, 0.5))
	item.origin_region = RHODES
	item.rarity = rarity
	item.grade = RHODES_TIER
	if Item.is_jewel_slot(category): item.atk_share = 0.0 if "staff" in _forms(operator_id) else 1.0
	apply(item, id)
	item.value = RHODES_VALUE
	item.value_base = RHODES_VALUE
	return item

## The choices for `slot` (Item.SLOTS) that `operator_id` can use.
static func rhodes_choices(slot: int, operator_id: String) -> Array:
	var i := Item.SLOTS.find(slot)
	if i < 0: return []
	var forms := _forms(operator_id)
	return (RHODES_KIT[i] as Array).filter(func(id): return int(BASES[id].category) != W or str(BASES[id].form) in forms)

## A whole set, the first choice in each slot.
static func rhodes_kit(operator_id: String = Operators.AMIYA_GUARD, rarity: int = RHODES_RARITY) -> Array[Item]:
	var out: Array[Item] = []
	for slot in Item.SLOTS:
		var fit := rhodes_choices(slot, operator_id)
		if not fit.is_empty(): out.append(make_rhodes(str(fit[0]), rarity, operator_id))
	return out

static func _forms(operator_id: String) -> Array:
	var cls := str(Operators.DATA.get(operator_id, {}).get("class", "近卫"))
	return CLASS_FORMS.get(cls, CLASS_FORMS["近卫"])

## Names that changed (they follow the art, §2.3), and the generic names of
## gear saved before bases existed, mapped by region to the shallow baseline.
const RENAMED := {"镐柄战刃": "断镐战斧", "冰原猎刀": "角柄猎刀"}
const LEGACY_BASELINE := {
	"外勤战刃": {"mine": "mine_issue", "city": "city_lgd_knife", "snow": "snow_antler_knife"},
	"防护甲胄": {"mine": "mine_vest", "city": "city_lgd_vest", "snow": "snow_fur_coat"},
}

static var _by_name := {}

static func id_for_name(item_name: String) -> String:
	if _by_name.is_empty():
		for id in BASES: _by_name[BASES[id].name] = id
	return _by_name.get(RENAMED.get(item_name, item_name), "")

## Bases registered at run time (tests; later the ranged bases), looked up
## after BASES.
static var extra_bases := {}

static func base(id: String) -> Dictionary:
	return BASES.get(id, extra_bases.get(id, {}))

## Bases of a slot in a region that a source may drop at a depth (§2.2–2.3).
## The old ARMOR / TRINKET read as the chest / amulet (Item.slot_of).
static func eligible(category: int, region: String, depth: int, source: String) -> Array:
	category = Item.slot_of(category)
	var early := EARLY_BY if source in EARLY_SOURCES else 0
	var out: Array = []
	for id in BASES:
		var b: Dictionary = BASES[id]
		if int(b.category) != category or not b.region in FieldCatalog.gear_regions(region, category): continue
		if source == "vault" and int(b.tier) < 1: continue
		if depth + early >= TIER_DEPTH[int(b.tier)]: out.append(id)
	if out.is_empty():  # a vault at depth 1 still opens with something
		for id in BASES:
			if int(BASES[id].category) == category and BASES[id].region in FieldCatalog.gear_regions(region, category) and int(BASES[id].tier) == 1: out.append(id)
	return out

## Picks a base id. Ordinary enemies drop the weapon they carry; elites their
## region's deepest weapon; everything else draws from the region's table,
## the deepest unlocked tier at weight 2 and the rest at 1 (elites ×2 deep).
static func pick(category: int, region: String, depth: int, source: String, enemy_type: String, rng: RandomNumberGenerator) -> String:
	category = Item.slot_of(category)
	if category == W:
		if source == "elite":
			var deep: Array = []
			for id in BASES:
				if BASES[id].region in FieldCatalog.gear_regions(region, W) and int(BASES[id].category) == W and int(BASES[id].tier) == 2: deep.append(id)
			if deep.size() == 1: return deep[0]
			if deep.size() > 1: return deep[rng.randi_range(0, deep.size() - 1)]
		var carried := _carried(enemy_type, region)
		if not carried.is_empty(): return carried
	var ids := eligible(category, region, depth, source)
	var top := 0
	for id in ids: top = maxi(top, int(BASES[id].tier))
	var weights: Array = []
	for id in ids:
		var tier := int(BASES[id].tier)
		var w := 2.0 if tier == top else 1.0
		if source == "elite" and tier == 2: w *= 2.0
		weights.append(w)
	var total := 0.0
	for w in weights: total += w
	var roll := rng.randf() * total
	for i in range(ids.size()):
		roll -= float(weights[i])
		if roll <= 0.0: return ids[i]
	return ids.back()

## The weapon an enemy type carries, its own region's version first.
static func _carried(enemy_type: String, region: String) -> String:
	if enemy_type.is_empty(): return ""
	var fallback := ""
	for id in BASES:
		if enemy_type in BASES[id].get("enemies", []):
			if BASES[id].region == region: return id
			if fallback.is_empty(): fallback = id
	return fallback

## Makes `item` this base: name, power factor, intrinsic stats, flavour text.
## With `rng`, intrinsics roll in the item's rarity band where its panel sits
## (底材固有属性表 v1.0: intrinsics fluctuate like the rest of the piece).
static func apply(item: Item, id: String, rng: RandomNumberGenerator = null) -> void:
	var b: Dictionary = BASES[id]
	var position := item.power_position()
	item.base_id = id
	item.item_name = b.name
	item.power *= float(b.factor)
	item.description = b.text
	item.value = roundi(item.value * float(b.get("value", 1.0)))
	var implicit := implicits_for(item, id, rng, position)
	implicit.append_array(item.modifiers)
	item.modifiers = implicit

## Base `id`'s intrinsics on `item`, as players see them (no slot multiplier,
## 用户 2026-10-21); flat ones grow with the item's tier (复利数值改造清单 C).
## Without `rng` they sit at the blue middle.
static func implicits_for(item: Item, id: String, rng: RandomNumberGenerator, position: float = -1.0) -> Array[ItemModifier]:
	var implicit: Array[ItemModifier] = []
	for pair in BASES[id].implicit:
		var scale := Scaling.flat_scale(maxi(item.grade, 1)) if int(pair[0]) in ItemModifier.FLAT_STATS else 1.0
		var mod: ItemModifier
		if rng != null: mod = ItemModifier.roll_intrinsic(pair[0], float(pair[1]) * scale, rng, item.rarity, position)
		else:
			mod = ItemModifier.stat_mod(pair[0], float(pair[1]) * scale)
			mod.tier = IMPLICIT_TIER
		mod.scale = scale
		implicit.append(mod)
	return implicit

## For loading: fills `base_id` on gear saved before it existed (name only;
## old items keep their stats).
static func backfill(item: Item) -> void:
	if not item.base_id.is_empty() or not item.is_equippable() or not item.special.is_empty() or not item.exclusive_region.is_empty(): return
	if RENAMED.has(item.item_name): item.item_name = RENAMED[item.item_name]
	var id := id_for_name(item.item_name)
	if id.is_empty() and LEGACY_BASELINE.has(item.item_name):
		id = LEGACY_BASELINE[item.item_name].get(item.origin_region, "")
		if not id.is_empty(): item.item_name = BASES[id].name
	if not id.is_empty() and int(BASES[id].category) == item.category: item.base_id = id
