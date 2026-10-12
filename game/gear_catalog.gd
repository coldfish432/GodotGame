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
const RANGED_FORMS := ["crossbow", "gun"]
## How a form changes her swing (装备策划案 §2.4, 装备扩充策划案 §3):
## [interval ×, damage ×, reach ×, swing half-angle ×].
const FORMS := {
	"blade": [1.0, 1.0, 1.0, 1.0], "heavy": [1.3, 1.35, 1.2, 1.0], "fist": [0.75, 0.8, 0.8, 1.0],
	"polearm": [1.15, 1.15, 1.4, 0.6],
}

const S := ItemModifier.Stat
const W := Item.Category.WEAPON
const A := Item.Category.ARMOR
const T := Item.Category.TRINKET

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
		"form": "blade", "enemies": ["crossbow", "crossbow_leader"], "icon": "standard_dagger", "text": "缴获来的，编号被锉掉了。"},
	"mine_issue": {"name": "矿区制式刀", "region": "mine", "category": W, "tier": 0, "factor": 1.00, "implicit": [],
		"form": "blade", "icon": "mine_issue_blade", "text": "矿场配发的开路刀，砍支架也砍人。"},
	"mine_saber": {"name": "纠察队佩刀", "region": "mine", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "patrol_saber", "text": "刀鞘不见了，刀还记得它是追人用的。"},
	"mine_pickaxe": {"name": "断镐战斧", "region": "mine", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_PCT, 0.04], [S.MOVE_SPEED_PCT, -0.04]],
		"form": "heavy", "icon": "pickhaft_blade", "text": "镐头断了一半，剩下那半磨成了斧。"},
	"mine_vest": {"name": "矿工护甲", "region": "mine", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "miner_vest", "text": "胸口缝着矿场的编号。"},
	"mine_reunion_coat": {"name": "整合运动制式外套", "region": "mine", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"icon": "reunion_coat", "text": "穿上它的人不需要名字。"},
	"mine_greatcoat": {"name": "纠察队防寒大衣", "region": "mine", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "patrol_winter_coat", "text": "厚得能挡住冻原的风，挡不住矿石病。"},
	"mine_hazard_suit": {"name": "矿场重型防护服", "region": "mine", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.MOVE_SPEED_PCT, -0.04]],
		"icon": "heavy_mine_suit", "text": "给最深的矿道准备的，没来得及发下去。"},
	"mine_dust_mask": {"name": "防尘面罩", "region": "mine", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "dust_mask", "text": "滤芯是黑的，说明它一直在工作。"},
	"mine_flask": {"name": "烈酒扁壶", "region": "mine", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_DMG, 0.10]],
		"icon": "liquor_flask", "text": "摇一摇，还剩一口。"},
	"mine_reunion_mask": {"name": "整合运动面具", "region": "mine", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "reunion_mask", "text": "面具都一样，所以没人记得谁倒下了。"},
	"mine_meter": {"name": "源石感应计", "region": "mine", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.05]],
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
	"city_lgd_vest": {"name": "近卫局制式护甲", "region": "city", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 20.0]],
		"icon": "lgd_vest", "text": "肩上的局徽被刮过，但没刮干净。"},
	"city_fire_suit": {"name": "消防署隔热服", "region": "city", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "fire_suit", "text": "那天烧得最厉害的地方，他们最先进去。"},
	"city_carrier": {"name": "押运防弹背心", "region": "city", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "courier_vest", "text": "插板缺了一块，正好是挨过的那一块。"},
	"city_inspector": {"name": "特别督察组战术护甲", "region": "city", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.MAX_HP_PCT, 0.04]],
		"icon": "inspector_armor", "text": "这身护甲的上一任主人，任期没满两年。"},
	"city_charm": {"name": "战术挂饰", "region": "city", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"icon": "tactical_charm", "text": "挂在背心上的小东西，谁都有一个。"},
	"city_radio": {"name": "近卫局对讲机", "region": "city", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "lgd_radio", "text": "频道里只剩杂音，偶尔有人报位置。"},
	"city_wallet": {"name": "龙门币钱夹", "region": "city", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.04]], "value": 1.5,
		"icon": "lungmen_wallet", "text": "里面的钱早花完了，钱夹本身倒值钱。"},
	"city_talisman": {"name": "炎式平安符", "region": "city", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.05], [S.RES_FLAT, 4.0]],
		"icon": "yan_talisman", "text": "求平安的人，未必平安，但符留下来了。"},
	# --- 萨米 · 冻土林线 (§4.3)
	"snow_icebreaker": {"name": "破冰刀", "region": "snow", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"form": "blade", "enemies": ["ice_warrior"], "icon": "icebreaker_knife", "text": "先敲开冰，再敲开别的。"},
	"snow_skinner": {"name": "猎刀", "region": "snow", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "enemies": ["ice_hunter"], "icon": "skinning_knife", "text": "皮要剥得完整，这是猎人对猎物的礼数。"},
	"snow_antler_knife": {"name": "角柄猎刀", "region": "snow", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"form": "blade", "icon": "antler_hunter_knife", "text": "角是向林子借的，用完要还。"},
	"snow_machete": {"name": "科考队开路刀", "region": "snow", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "blade", "icon": "expedition_machete", "text": "南边城市造的刀，走到这里已经不像南边的了。"},
	"snow_rite_blade": {"name": "雪祀礼刃", "region": "snow", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_PCT, 0.04], [S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "snowpriest_blade", "text": "埋在冻土下面，刃口依然是冷的。"},
	"snow_fur_coat": {"name": "冰原毛皮外套", "region": "snow", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "tundra_fur_coat", "text": "毛朝里穿，雪就进不来。"},
	"snow_cloak": {"name": "雪橇巡逻队斗篷", "region": "snow", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"icon": "sled_patrol_cloak", "text": "披上它，雪地里远远就能认出你是自己人。"},
	"snow_parka": {"name": "科考队防寒服", "region": "snow", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "expedition_parka", "text": "标签上写的温度，这里早就低过了。"},
	"snow_lamellar": {"name": "骨片札甲", "region": "snow", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.MAX_HP_PCT, 0.04]],
		"icon": "bone_lamellar", "text": "每一片骨头，都来自一只认得这片林子的兽。"},
	"snow_amulet": {"name": "骨制护符", "region": "snow", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.ARTS_PCT, 0.05]],
		"icon": "bone_amulet", "text": "刻痕被很多只手摸平了。"},
	"snow_flute": {"name": "角兽骨笛", "region": "snow", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "antler_flute", "text": "吹响时，林子会安静一下。"},
	"snow_drumstick": {"name": "兽骨鼓槌", "region": "snow", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"icon": "bone_drumstick", "text": "敲鼓的人不在了，鼓槌还记得节拍。"},
	"snow_cipher": {"name": "密文板残片", "region": "snow", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.05], [S.CRIT_DMG, 0.10]],
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
	"mine_x09": {"name": "拼装轻甲", "region": "mine", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 20.0]],
		"icon": "mine_x09", "text": "三套甲拆成一套，扣子都对不上。"},
	"mine_x10": {"name": "改装喷射背架", "region": "mine", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "mine_x10", "text": "燃料早就烧完了，背带还结实。"},
	"mine_x11": {"name": "整合运动术师兜袍", "region": "mine", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.ARTS_PCT, 0.05]],
		"icon": "mine_x11", "text": "袖口被烧穿过，从里面。"},
	"mine_x12": {"name": "伪装吉利服", "region": "mine", "category": A, "tier": 1, "factor": 1.00, "implicit": [[S.CRIT_RATE, 0.03]],
		"icon": "mine_x12", "text": "披上它，矿道里就少了一个人。"},
	"mine_x13": {"name": "游击队旧式军大衣", "region": "mine", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "mine_x13", "text": "补丁比原布多，扣子一颗不少。"},
	"mine_x14": {"name": "复合护具", "region": "mine", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.MAX_HP_PCT, 0.04], [S.MOVE_SPEED_PCT, -0.04]],
		"icon": "mine_x14", "text": "罐子、管子、面罩，一样都不能少。"},
	"mine_x15": {"name": "头戴矿灯", "region": "mine", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"icon": "mine_x15", "text": "电池还剩一格。"},
	"mine_x16": {"name": "军用止血带", "region": "mine", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "mine_x16", "text": "扣环上写着上一个人的血型。"},
	"mine_x17": {"name": "劳役编号牌", "region": "mine", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.DEF_FLAT, 20.0]],
		"icon": "mine_x17", "text": "铁皮压的，比戴它的人结实。"},
	"mine_x18": {"name": "切尔文铜币", "region": "mine", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.CRIT_RATE, 0.03]],
		"icon": "mine_x18", "text": "在矿里，它买不到任何东西。"},
	"mine_x19": {"name": "纠察队手铐", "region": "mine", "category": T, "tier": 1, "factor": 1.05, "implicit": [[S.ATK_PCT, 0.04]],
		"icon": "mine_x19", "text": "钥匙不在这里。"},
	"mine_x20": {"name": "游击队臂章", "region": "mine", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "mine_x20", "text": "线是自己缝的，针脚很密。"},
	"mine_x21": {"name": "高能虫囊", "region": "mine", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.05]],
		"icon": "mine_x21", "text": "摸上去是温的，最好别摸。"},
	"mine_x22": {"name": "拆下的施术单元", "region": "mine", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.RES_FLAT, 4.0]],
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
	"city_x09": {"name": "执勤反光雨衣", "region": "city", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"icon": "city_x09", "text": "雨从不停，巡逻也不停。"},
	"city_x10": {"name": "拳馆练功服", "region": "city", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "city_x10", "text": "衣服换过三次，师父没换过。"},
	"city_x11": {"name": "染血白工装", "region": "city", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "city_x11", "text": "洗不掉的部分，就当是颜色。"},
	"city_x12": {"name": "拾荒者伪装衫", "region": "city", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.DEF_FLAT, 20.0]],
		"icon": "city_x12", "text": "外面是破布，里面是钢板。"},
	"city_x13": {"name": "香主绸衫", "region": "city", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 4.0], [S.MAX_HP_PCT, 0.04]],
		"icon": "city_x13", "text": "绸子挡不住刀，挡刀的是别的东西。"},
	"city_x14": {"name": "防爆重甲", "region": "city", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.MOVE_SPEED_PCT, -0.04]],
		"icon": "city_x14", "text": "穿上它就不用跑了，反正也跑不动。"},
	"city_x15": {"name": "执勤警哨", "region": "city", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"icon": "city_x15", "text": "吹响以后，往哪边跑都对。"},
	"city_x16": {"name": "防风打火机", "region": "city", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.ARTS_PCT, 0.05]],
		"icon": "city_x16", "text": "点烟用的，也点别的。"},
	"city_x17": {"name": "老千骰子", "region": "city", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_RATE, 0.03]],
		"icon": "city_x17", "text": "六面都是好点数的那一颗，找不到了。"},
	"city_x18": {"name": "跌打药酒瓶", "region": "city", "category": T, "tier": 1, "factor": 1.05, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "city_x18", "text": "酒是外用的。大部分时候。"},
	"city_x19": {"name": "无人机遥控器", "region": "city", "category": T, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "city_x19", "text": "屏幕上还有信号，飞机不知道在哪。"},
	"city_x20": {"name": "当铺铜牌", "region": "city", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.1]], "value": 1.2,
		"icon": "city_x20", "text": "当掉的东西没赎回来，牌子倒留下了。"},
	"city_x21": {"name": "琉璃护身珠", "region": "city", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.RES_FLAT, 4.0], [S.ARTS_PCT, 0.05]],
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
	"snow_x09": {"name": "角兽长毛披肩", "region": "snow", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "snow_x09", "text": "趴在雪里时，和灌木没有分别。"},
	"snow_x10": {"name": "桦皮护胸", "region": "snow", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "snow_x10", "text": "林子里长出来的东西，林子里的病碰不到它。"},
	"snow_x11": {"name": "林业护具", "region": "snow", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 20.0]],
		"icon": "snow_x11", "text": "设计时只想过倒下来的树。"},
	"snow_x12": {"name": "搜救队绳索背心", "region": "snow", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"icon": "snow_x12", "text": "绳子的另一头，通常没有人。"},
	"snow_x13": {"name": "科考站加热背心", "region": "snow", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "snow_x13", "text": "线缆另一头接着的东西，早就冻住了。"},
	"snow_x14": {"name": "冬牙角盔", "region": "snow", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.MOVE_SPEED_PCT, -0.04]],
		"icon": "snow_x14", "text": "透过它看出去的人，都没有回来。"},
	"snow_x15": {"name": "雪祀羽氅", "region": "snow", "category": A, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.05], [S.RES_FLAT, 4.0]],
		"icon": "snow_x15", "text": "每一根羽毛都在等一场雪。"},
	"snow_x16": {"name": "族树木片", "region": "snow", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "snow_x16", "text": "树倒了以后，部族的人每人分了一片。"},
	"snow_x17": {"name": "鼷兽毛团", "region": "snow", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "snow_x17", "text": "它们挤在一起时，比任何皮袄都暖。"},
	"snow_x18": {"name": "幸运晶石", "region": "snow", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_RATE, 0.03]],
		"icon": "snow_x18", "text": "商贩说它挡过一刀。"},
	"snow_x19": {"name": "骨缝雪镜", "region": "snow", "category": T, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.03]],
		"icon": "snow_x19", "text": "看得少，看得准。"},
	"snow_x20": {"name": "手持定位仪", "region": "snow", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"icon": "snow_x20", "text": "屏幕上的你一直在原地。"},
	"snow_x21": {"name": "角兽银铃", "region": "snow", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "snow_x21", "text": "角兽走在前面，铃声替它认路。"},
	"snow_x22": {"name": "黑雪结晶", "region": "snow", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.05], [S.CRIT_RATE, 0.03]],
		"icon": "snow_x22", "text": "握久了，会忘记为什么握着它。"},
	"snow_x23": {"name": "猎首獠牙串", "region": "snow", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ATK_PCT, 0.04], [S.CRIT_DMG, 0.1]],
		"icon": "snow_x23", "text": "每一颗都有过一个名字。"},
}

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
static func eligible(category: int, region: String, depth: int, source: String) -> Array:
	var early := EARLY_BY if source in EARLY_SOURCES else 0
	var out: Array = []
	for id in BASES:
		var b: Dictionary = BASES[id]
		if int(b.category) != category or b.region != region: continue
		if source == "vault" and int(b.tier) < 1: continue
		if depth + early >= TIER_DEPTH[int(b.tier)]: out.append(id)
	if out.is_empty():  # a vault at depth 1 still opens with something
		for id in BASES:
			if int(BASES[id].category) == category and BASES[id].region == region and int(BASES[id].tier) == 1: out.append(id)
	return out

## Picks a base id. Ordinary enemies drop the weapon they carry; elites their
## region's deepest weapon; everything else draws from the region's table,
## the deepest unlocked tier at weight 2 and the rest at 1 (elites ×2 deep).
static func pick(category: int, region: String, depth: int, source: String, enemy_type: String, rng: RandomNumberGenerator) -> String:
	if category == W:
		if source == "elite":
			for id in BASES:
				if BASES[id].region == region and int(BASES[id].category) == W and int(BASES[id].tier) == 2: return id
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
static func apply(item: Item, id: String) -> void:
	var b: Dictionary = BASES[id]
	item.base_id = id
	item.item_name = b.name
	item.power *= float(b.factor)
	item.description = b.text
	item.value = roundi(item.value * float(b.get("value", 1.0)))
	var implicit: Array[ItemModifier] = []
	for pair in b.implicit:
		var mod := ItemModifier.stat_mod(pair[0], float(pair[1]))
		mod.tier = IMPLICIT_TIER
		implicit.append(mod)
	implicit.append_array(item.modifiers)
	item.modifiers = implicit

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
