class_name MaterialCatalog
extends RefCounted

## Materials (掉落物策划案 §2). Every one is a PRTS item under its own name,
## with its PRTS rarity (★1–★5) and a short paraphrase of its PRTS
## description — see 掉落物调研_PRTS道具.md. Materials stack; one stack is one
## item (one pack cell, one crate, one shelf slot).

## PRTS rarity -> stack size, unit value, colour (掉落物策划案 §2.1).
const STACK := {1: 20, 2: 20, 3: 10, 4: 5, 5: 3}
const UNIT_VALUE := {1: 4, 2: 8, 3: 18, 4: 40, 5: 90}
const STAR_COLORS := {1: Color("b8b8b8"), 2: Color("cbd75a"), 3: Color("4fb3f6"), 4: Color("c48af0"), 5: Color("f3b04a")}

## kind: "craft" (养成材料, enemy drops) or "base" (基建材料, points of interest).
## Common supplies (基建资源策划案 §1, after Tarkov's barter items and Duckov's
## hardware) carry "source": "common" and a "group"; they may override the
## star's stack size ("stack": 1 = does not stack), take more than one cell
## ("size") and set their own unit value ("value").
const MATERIALS := {
	"源岩": {"star": 1, "kind": "craft", "text": "常见于源石挥发殆尽后的地区，比源石更易采集。"},
	"固源岩": {"star": 2, "kind": "craft", "text": "内含密集微孔，可吸附源石气体分解物，多用于防护夹层。"},
	"固源岩组": {"star": 3, "kind": "craft", "text": "固源岩压缩定型后的产物，易碎。"},
	"提纯源岩": {"star": 4, "kind": "craft", "text": "高度提纯，有着规则的切割面；工艺成本急剧上升。"},
	"代糖": {"star": 1, "kind": "craft", "text": "有着微弱的甜味，也许可以吃；溶液常用于化工。"},
	"糖": {"star": 2, "kind": "craft", "text": "用自然原材制作的糖料，不是用来当零食吃的。"},
	"酯原料": {"star": 1, "kind": "craft", "text": "近代工业的关键材料之一，但这只是原料。"},
	"聚酸酯": {"star": 2, "kind": "craft", "text": "强度略有不足，可做基础物件，也是缓释药物的常用成分。"},
	"异铁碎片": {"star": 1, "kind": "craft", "text": "大规模金属原料加工的副产物，可塑性强、难氧化。"},
	"异铁": {"star": 2, "kind": "craft", "text": "碎片相变聚合而成，是较稳定的形态。"},
	"异铁组": {"star": 3, "kind": "craft", "text": "偶然形成的异铁组合，硬度下降、纯度上升。"},
	"双酮": {"star": 1, "kind": "craft", "text": "极少量非单酮制剂，工程干员用它粘结结构。"},
	"酮凝集": {"star": 2, "kind": "craft", "text": "少量多态酮制剂，能把繁杂工艺简化成单纯的化学反应。"},
	"破损装置": {"star": 1, "kind": "craft", "text": "曾被拼装在敌人的武器和防具上，战损后内部元件仍有价值。"},
	"装置": {"star": 2, "kind": "craft", "text": "收缴来的机械装置，相对完整，主板上塞满电子元件。"},
	"全新装置": {"star": 3, "kind": "craft", "text": "重构后解决了主板空间问题，但能耗更高。"},
	"改量装置": {"star": 4, "kind": "craft", "text": "大量私自改造的装置，扩容提速但牺牲了稳定性。"},
	"研磨石": {"star": 3, "kind": "craft", "text": "不起爆、不粉化、不开裂，用于加工武器零件。"},
	# 炎国's own, sold by 龙门商会: 定向重铸 (前缀放大与特效阶等案 §3).
	"玄纹墨": {"star": 5, "kind": "craft", "source": "yan", "text": "炎国匠坊调的墨，描进器物的纹路里就不会褪。"},
	"化合切削液": {"star": 3, "kind": "craft", "text": "金属加工中起润滑吸热作用，提高成品合格率。"},
	"扭转醇": {"star": 3, "kind": "craft", "text": "化工中介体，液化后像酒精，常让整个工作间醉醺醺的。"},
	"轻锰矿": {"star": 3, "kind": "craft", "text": "用来产出工业催化剂的金属矿物，加工事故比比皆是。"},
	"晶体元件": {"star": 3, "kind": "craft", "text": "用源石晶体外壳制作的工业原材料。"},
	"褐素纤维": {"star": 3, "kind": "craft", "text": "源石工业衍生物，高强度、高模量的纤维束。"},
	"凝胶": {"star": 3, "kind": "craft", "text": "实验室意外诞生的材料，耐高低温，强度高、重量轻。"},
	"D32钢": {"star": 5, "kind": "craft", "text": "强度超群，能传导源石技艺，将重新订立武器材料的标准。"},
	# Growth (精英化与加点策划案 §3.2, PRTS names and rarities).
	"近卫芯片": {"star": 3, "kind": "craft", "text": "记录近卫干员特殊训练数据的存储芯片，用于干员晋升。"},
	"近卫芯片组": {"star": 4, "kind": "craft", "text": "一组近卫芯片，训练数据更完整。"},
	"芯片助剂": {"star": 4, "kind": "craft", "text": "制造芯片用的催化剂，合成双芯片的必备材料；价值高，产量小。"},
	"近卫双芯片": {"star": 5, "kind": "craft", "text": "两组芯片与助剂合成的高阶芯片，用于近卫干员的精英 2 晋升。"},
	"技巧概要·卷1": {"star": 2, "kind": "craft", "text": "技能训练用的书籍，入门篇。"},
	"技巧概要·卷2": {"star": 3, "kind": "craft", "text": "技能训练用的书籍，进阶篇。"},
	"技巧概要·卷3": {"star": 4, "kind": "craft", "text": "技能训练用的书籍，专精篇。"},
	"模组数据块": {"star": 5, "kind": "craft", "text": "解锁干员模组所需的数据。"},
	# 作战记录 drop in the field (龙门币平衡与科研部策划案 v1.1 §2.1) and go to 人事部
	# when they come home; worth next to nothing to sell, they are for experience.
	"基础作战记录": {"star": 2, "kind": "record", "value": 1, "text": "记录了基础作战经验的影像资料。"},
	"初级作战记录": {"star": 3, "kind": "record", "value": 1, "text": "记录了初级作战经验的影像资料。"},
	"中级作战记录": {"star": 4, "kind": "record", "value": 1, "text": "记录了中级作战经验的影像资料。"},
	"高级作战记录": {"star": 5, "kind": "record", "value": 1, "text": "记录了高级作战经验的影像资料。"},
	"碳": {"star": 2, "kind": "base", "text": "碳原料，用于开发罗德岛的基础设施。"},
	"碳素": {"star": 3, "kind": "base", "text": "碳素砖，轻、纯度高、好加工，用于开发基础设施。"},
	"碳素组": {"star": 4, "kind": "base", "text": "一组碳素砖，每一块都饱含着燃烧的工业之魂。"},
	"基础加固建材": {"star": 2, "kind": "base", "text": "改造房间前用来加固承重部位的基本建筑工程材料。"},
	"进阶加固建材": {"star": 3, "kind": "base", "text": "用于土木结构较脆弱区域的房间改造。"},
	"家具零件": {"star": 3, "kind": "base", "text": "用以合成家具的零件：桌腿、扶手、坐垫，什么都有。"},
	## The in-run money too (经济修订案 §2): PRTS ★3, stacks of 10, 可露希尔 buys one for 1000 龙门币.
	"赤金": {"star": 3, "kind": "base", "stack": 10, "value": 10, "text": "提纯精炼后的金条，可以换取大量龙门币。"},
	"源石碎片": {"star": 5, "kind": "base", "text": "从重度污染地区回收，有高感染威胁，是危险物质。"},
	"螺栓": {"star": 1, "kind": "base", "group": "建材", "source": "common", "stack": 30, "text": "最常见的紧固件，盖什么都用得上。"},
	"螺母": {"star": 1, "kind": "base", "group": "建材", "source": "common", "stack": 30, "text": "和螺栓配对使用，总是先找不到它。"},
	"钉子": {"star": 1, "kind": "base", "group": "建材", "source": "common", "stack": 30, "text": "一盒铁钉，木结构和临时隔板的基础。"},
	"木板": {"star": 1, "kind": "base", "group": "建材", "source": "common", "size": Vector2i(2, 1), "text": "拆下来的板材，搭架子、钉隔板都行。"},
	"金属板": {"star": 2, "kind": "base", "group": "建材", "source": "common", "text": "裁好的薄钢板，货架和箱体的骨架材料。"},
	"软管": {"star": 2, "kind": "base", "group": "建材", "source": "common", "stack": 10, "size": Vector2i(2, 1), "text": "波纹软管，管线、通风和冷却都要用。"},
	"密封泡沫": {"star": 3, "kind": "base", "group": "建材", "source": "common", "size": Vector2i(1, 2), "text": "发泡密封剂，填缝隔热，防尘防水。"},
	"胶带": {"star": 1, "kind": "base", "group": "日用", "source": "common", "text": "万能胶带，能修的都能修。"},
	"帆布": {"star": 2, "kind": "base", "group": "日用", "source": "common", "size": Vector2i(2, 1), "text": "厚实的防水帆布，背包和遮蔽物的面料。"},
	"电线": {"star": 1, "kind": "base", "group": "电子", "source": "common", "text": "一捆铜芯电线，任何电路的起点。"},
	"电源线": {"star": 2, "kind": "base", "group": "电子", "source": "common", "stack": 10, "size": Vector2i(2, 1), "text": "带插头的电源线，设备接电必备。"},
	"灯泡": {"star": 2, "kind": "base", "group": "电子", "source": "common", "text": "还能亮的灯泡，照明设施的耗材。"},
	"继电器": {"star": 3, "kind": "base", "group": "电子", "source": "common", "text": "相位控制继电器，自动化设备的开关。"},
	"电路板": {"star": 3, "kind": "base", "group": "电子", "source": "common", "text": "从设备上拆下的印刷电路板，元件基本完好。"},
	"微型电机": {"star": 4, "kind": "base", "group": "电子", "source": "common", "stack": 3, "size": Vector2i(2, 2), "value": 60, "text": "小型电动机，驱动无人机和机械臂。"},
	"蓄电池": {"star": 2, "kind": "base", "group": "能源", "source": "common", "text": "可充电电池，便携设备的电源。"},
	"车用蓄电池": {"star": 4, "kind": "base", "group": "能源", "source": "common", "stack": 1, "size": Vector2i(3, 2), "value": 120, "text": "沉重的车用蓄电池，能给整套设施供电。"},
	"固体燃料": {"star": 1, "kind": "base", "group": "燃料", "source": "common", "text": "块状燃料，取暖和野外加热的耗材。"},
	"燃料罐": {"star": 3, "kind": "base", "group": "燃料", "source": "common", "stack": 1, "size": Vector2i(2, 2), "value": 50, "text": "装满的金属燃料罐，发电机的口粮。"},
	"扳手": {"star": 3, "kind": "base", "group": "工具", "source": "common", "stack": 5, "text": "棘轮扳手，拆装设备的常用工具。"},
	"工具套装": {"star": 4, "kind": "base", "group": "工具", "source": "common", "stack": 1, "size": Vector2i(2, 2), "value": 100, "text": "一整箱工具，工程部最想要的东西。"},
	"医用耗材包": {"star": 3, "kind": "base", "group": "医疗", "source": "common", "text": "注射器、纱布和消毒用品的打包件。"},
	# Trade goods (势力与交易所策划案 §2.2): packed by 加工部, sold to outside factions.
	"工业补给箱": {"star": 3, "kind": "base", "source": "trade", "stack": 1, "size": Vector2i(2, 2), "value": 120, "text": "加工部打包的螺栓、金属板和胶带，外部势力按箱收购。"},
	"电子元件箱": {"star": 3, "kind": "base", "source": "trade", "stack": 1, "size": Vector2i(2, 2), "value": 115, "text": "电线、灯泡和继电器打成的一箱电子件。"},
	"野外生活包": {"star": 3, "kind": "base", "source": "trade", "stack": 1, "size": Vector2i(2, 2), "value": 78, "text": "帆布、固体燃料和胶带，寒地营地的过冬物资。"},
	"医疗补给箱": {"star": 3, "kind": "base", "source": "trade", "stack": 1, "size": Vector2i(2, 2), "value": 108, "text": "医用耗材、糖和胶带装成的一箱医疗补给。"},
	# Trade packs (交易所交易包修订案 §2, 用户 2026-10-23): the exchange's only
	# goods; "value" is the face (Packs.PACKS). The crates above are the old
	# trade goods, turned into packs when a save loads (§7.3).
	"建材包": {"star": 3, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 100, "text": "加工部封装的标准建材包，交易所按包报价。"},
	"电子包": {"star": 3, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 120, "text": "加工部封装的标准电子包，交易所按包报价。"},
	"医疗包": {"star": 3, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 100, "text": "加工部封装的标准医疗包，交易所按包报价。"},
	"燃料包": {"star": 3, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 100, "text": "加工部封装的标准燃料包，交易所按包报价。"},
	"寒地物资包": {"star": 3, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 100, "text": "加工部封装的标准寒地物资包，交易所按包报价。"},
	"源石包": {"star": 3, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 120, "text": "加工部封装的标准源石包，交易所按包报价。"},
	"养成材料包": {"star": 4, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 300, "text": "加工部封装的标准养成材料包，交易所按包报价。"},
	"违禁品包": {"star": 4, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 200, "text": "来路不明的货封在一起，只有黑市收。拆不开。"},
	"武器包": {"star": 4, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 400, "text": "按价值封装的一箱武器，加了封条，拆不开。"},
	"防具包": {"star": 4, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 400, "text": "按价值封装的一箱防具，加了封条，拆不开。"},
	"饰品包": {"star": 4, "kind": "base", "source": "pack", "stack": 5, "size": Vector2i(2, 2), "value": 400, "text": "按价值封装的一箱饰品，加了封条，拆不开。"},
	# 萨米林地部族's goods (交易所事件表 §0.1: 萨米出口医药原材料).
	"林地草药": {"star": 2, "kind": "base", "source": "sami", "stack": 20, "text": "萨米林地人采集晾干的草药，是医药原材料。"},
	"鞣制兽皮": {"star": 3, "kind": "base", "source": "sami", "stack": 5, "size": Vector2i(2, 1), "text": "岩角兽的皮，鞣制后防寒耐磨。"},
	# 势力特供 (势力特供策划案_v0_2 §二): each sold by one faction, used up in one department.
	"高能燃料": {"star": 4, "kind": "base", "source": "special", "stack": 5, "text": "喀兰贸易给登山车队调的高能燃料，罗德岛号的引擎也吃得下。"},
	"下城区耳目": {"star": 3, "kind": "base", "source": "special", "stack": 5, "text": "鼠王手下线人的一次口信，传闻是真是假，他们比报纸先知道。"},
	"高纯源岩助熔剂": {"star": 4, "kind": "base", "source": "special", "stack": 5, "text": "乌萨斯西北矿场冶炼用的助熔剂，加进炉子里出料又快又多。"},
	"萨米冰原苔": {"star": 4, "kind": "base", "source": "special", "stack": 5, "text": "萨米林地人从冰原上采来的苔藓，敷上后伤势和病痛都会退去。"},
	"骑士工坊专利授权": {"star": 5, "kind": "base", "source": "special", "stack": 3, "text": "卡西米尔商业联合会出售的一次性专利授权，研究可以少走许多弯路。"},
	"企鹅专递单": {"star": 4, "kind": "base", "source": "special", "stack": 5, "text": "企鹅物流的专递单，交给罗德岛小队或营地，多少东西都直接送回仓库。"},
	"残党向导": {"star": 3, "kind": "base", "source": "special", "stack": 5, "text": "整合运动残党里熟悉地形的人，愿意指出这一层藏东西的地方。"},
	"闪耀作物种子": {"star": 4, "kind": "base", "source": "special", "stack": 10, "text": "莱茵生命生态科培育的种子，长成后会在暗处发光。"},
	"闪耀作物·变种种子": {"star": 5, "kind": "base", "source": "special", "stack": 5, "text": "生态科还在观察的变种，长得慢，光更亮。"},
	# 农业部 and 食堂 (§四–§五): crops and the 补给 cooked from them.
	"舰载麦": {"star": 1, "kind": "base", "source": "farm", "text": "农业部水培槽里长的麦子，舰上每顿饭的底料。"},
	"块茎薯": {"star": 1, "kind": "base", "source": "farm", "text": "耐储存的块茎，食堂的主食。"},
	"温室豆": {"star": 2, "kind": "base", "source": "farm", "text": "补光灯下长的豆子，蛋白质的来源。"},
	"闪耀作物": {"star": 4, "kind": "base", "source": "farm", "stack": 5, "text": "莱茵生命的闪耀作物，收下来还在微微发光。"},
	"闪耀作物·变种": {"star": 5, "kind": "base", "source": "farm", "stack": 3, "text": "变种的闪耀作物，光很亮，味道也更浓。"},
	"舰内口粮": {"star": 2, "kind": "base", "source": "meal", "stack": 5, "text": "食堂压制的口粮块。"},
	"食堂便当": {"star": 3, "kind": "base", "source": "meal", "stack": 5, "text": "主食、配菜和豆子装成的便当。"},
	"闪耀定食": {"star": 4, "kind": "base", "source": "meal", "stack": 3, "text": "闪耀作物做主菜的定食，盘子里也亮着。"},
	"变种盛宴": {"star": 5, "kind": "base", "source": "meal", "stack": 3, "text": "变种闪耀作物做的大餐，食堂一天只做得出几份。"},
}

static func star(id: String) -> int:
	return int(MATERIALS[id].star) if MATERIALS.has(id) else 1

static func is_common(id: String) -> bool:
	return str(MATERIALS.get(id, {}).get("source", "")) == "common"

## "建材" / "电子" … for common supplies, "养成材料" / "基建材料" for PRTS ones.
static func group(id: String) -> String:
	var data: Dictionary = MATERIALS.get(id, {})
	if data.has("group"): return str(data.group)
	return "基建材料" if str(data.get("kind", "")) == "base" else "养成材料"

static func stack_size(id: String) -> int:
	var data: Dictionary = MATERIALS[id]
	return int(data.get("stack", STACK[int(data.star)]))

static func color(id: String) -> Color:
	return STAR_COLORS[clampi(star(id), 1, 5)]

## A stack of `count` of material `id` (clamped to its stack size).
static func create(id: String, count: int, region: String = "") -> Item:
	var data: Dictionary = MATERIALS[id]
	var size: Vector2i = data.get("size", Vector2i(1, 1))
	var item := Item.create(id, Item.Category.MATERIAL, size.x, size.y)
	item.material_id = id
	item.max_stack = stack_size(id)
	item.unit_value = int(data.get("value", UNIT_VALUE[int(data.star)]))
	item.description = "%s ★%d · %s" % ["通用物资" if is_common(id) else "PRTS", int(data.star), data.text]
	item.origin_region = region
	item.set_quantity(clampi(count, 1, item.max_stack))
	return item
