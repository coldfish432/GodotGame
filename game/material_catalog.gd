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
	"化合切削液": {"star": 3, "kind": "craft", "text": "金属加工中起润滑吸热作用，提高成品合格率。"},
	"扭转醇": {"star": 3, "kind": "craft", "text": "化工中介体，液化后像酒精，常让整个工作间醉醺醺的。"},
	"轻锰矿": {"star": 3, "kind": "craft", "text": "用来产出工业催化剂的金属矿物，加工事故比比皆是。"},
	"晶体元件": {"star": 3, "kind": "craft", "text": "用源石晶体外壳制作的工业原材料。"},
	"褐素纤维": {"star": 3, "kind": "craft", "text": "源石工业衍生物，高强度、高模量的纤维束。"},
	"凝胶": {"star": 3, "kind": "craft", "text": "实验室意外诞生的材料，耐高低温，强度高、重量轻。"},
	"D32钢": {"star": 5, "kind": "craft", "text": "强度超群，能传导源石技艺，将重新订立武器材料的标准。"},
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
