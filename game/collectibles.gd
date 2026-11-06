class_name Collectibles
extends RefCounted

## 收藏品与整理箱 (整理箱与收藏品策划案 v0.2): the collectibles a map gives up
## (§3, v0.1 §4.2–4.3), the 整理箱 the warehouse holds them in (§2) and what
## 可露希尔 takes for each box (§2.3).

# --- 收藏品 ---------------------------------------------------------------------

## id -> region ("" = 手办, any map), size, rarity, value (龙门币), one line.
## Five rarities, one each (用户 2026-10-26: 收藏品不可堆叠，分出白、绿、蓝、紫、红
## 五等级，每种收藏品只有一个稀有度等级; 扩充至 50 个，添加明日方舟角色手办):
## eight a region, eighteen figurines.
const ITEMS := {
	# 切尔诺伯格 · 坍塌矿区
	"矿区通行证": {"region": "mine", "size": Vector2i(1, 1), "rarity": Item.GREY, "value": 1200, "text": "塑封已经裂了，照片上的人看不清。"},
	"矿工护身符": {"region": "mine", "size": Vector2i(1, 1), "rarity": Item.GREY, "value": 1500, "text": "源石矿工缝在衣领里的小布包。"},
	"铁皮套娃": {"region": "mine", "size": Vector2i(1, 2), "rarity": Item.GREEN, "value": 3500, "text": "五层，最里面那个被焊死了。"},
	"旧矿灯": {"region": "mine", "size": Vector2i(1, 2), "rarity": Item.GREEN, "value": 4000, "text": "灯泡还亮，电池早没了。"},
	"旧式怀表": {"region": "mine", "size": Vector2i(1, 1), "rarity": Item.BLUE, "value": 7000, "text": "表盖上刻着一座已经不存在的城。"},
	"源石灯罩": {"region": "mine", "size": Vector2i(2, 2), "rarity": Item.BLUE, "value": 9000, "text": "矿灯的罩子，内壁结了一层薄晶。"},
	"学校纪念徽章": {"region": "mine", "size": Vector2i(1, 1), "rarity": Item.PURPLE, "value": 16000, "text": "切尔诺伯格一所中学的校徽。"},
	"帝国勋章": {"region": "mine", "size": Vector2i(1, 1), "rarity": Item.RED, "value": 38000, "text": "乌萨斯帝国的旧勋章，绶带早已褪色。"},
	# 龙门城区
	"茶楼筹码": {"region": "city", "size": Vector2i(1, 1), "rarity": Item.GREY, "value": 1200, "text": "背面写着一个已经关门的茶楼。"},
	"旧版龙门币样钞": {"region": "city", "size": Vector2i(1, 1), "rarity": Item.GREY, "value": 1800, "text": "印着「样本」两个字。"},
	"麻将牌匣": {"region": "city", "size": Vector2i(2, 1), "rarity": Item.GREEN, "value": 4000, "text": "少了一张红中。"},
	"老式收音机": {"region": "city", "size": Vector2i(2, 1), "rarity": Item.GREEN, "value": 4500, "text": "调到哪个台都是同一首歌。"},
	"醒狮摆件": {"region": "city", "size": Vector2i(1, 2), "rarity": Item.BLUE, "value": 7500, "text": "店铺开张时摆在柜台上的那种。"},
	"炎国瓷茶壶": {"region": "city", "size": Vector2i(2, 2), "rarity": Item.BLUE, "value": 10000, "text": "壶底的落款被人磨掉了。"},
	"近卫局纪念章": {"region": "city", "size": Vector2i(1, 1), "rarity": Item.PURPLE, "value": 18000, "text": "发给退休警员的纪念章。"},
	"古玉坠": {"region": "city", "size": Vector2i(1, 1), "rarity": Item.RED, "value": 42000, "text": "温润，挂绳是新换的。"},
	# 萨米 · 冻土林线
	"驯鹿铃铛": {"region": "snow", "size": Vector2i(1, 1), "rarity": Item.GREY, "value": 1200, "text": "摇起来声音很闷。"},
	"兽皮护符": {"region": "snow", "size": Vector2i(1, 1), "rarity": Item.GREY, "value": 1500, "text": "缝着驯鹿毛。"},
	"驯鹿角饰": {"region": "snow", "size": Vector2i(2, 1), "rarity": Item.GREEN, "value": 3800, "text": "一截打磨过的鹿角。"},
	"桦树皮篓": {"region": "snow", "size": Vector2i(1, 2), "rarity": Item.GREEN, "value": 4200, "text": "编得很紧，能装水。"},
	"萨米木雕": {"region": "snow", "size": Vector2i(1, 2), "rarity": Item.BLUE, "value": 7000, "text": "雕的是一只蹲着的狐狸。"},
	"雪境古地图": {"region": "snow", "size": Vector2i(2, 2), "rarity": Item.BLUE, "value": 9500, "text": "画在兽皮上，有几条河已经改道。"},
	"萨满骨笛": {"region": "snow", "size": Vector2i(2, 1), "rarity": Item.PURPLE, "value": 17000, "text": "吹不响，但没人敢扔。"},
	"极光琥珀": {"region": "snow", "size": Vector2i(1, 1), "rarity": Item.RED, "value": 40000, "text": "对着光看，里面有一道绿。"},
	# 叙拉古 · 沃尔西尼旧城区
	"街角咖啡杯": {"region": "siracusa", "size": Vector2i(1, 1), "rarity": Item.GREY, "value": 1200, "text": "杯沿有一道口红印。"},
	"歌剧院旧海报": {"region": "siracusa", "size": Vector2i(1, 2), "rarity": Item.GREY, "value": 1800, "text": "首演那晚的海报。"},
	"银质餐刀匣": {"region": "siracusa", "size": Vector2i(2, 1), "rarity": Item.GREEN, "value": 4200, "text": "十二把，少了一把。"},
	"黄铜打火机": {"region": "siracusa", "size": Vector2i(1, 1), "rarity": Item.GREEN, "value": 4500, "text": "刻着一个名字的缩写。"},
	"陈年酒瓶": {"region": "siracusa", "size": Vector2i(1, 2), "rarity": Item.BLUE, "value": 8000, "text": "封蜡还在。"},
	"陶瓷狼像": {"region": "siracusa", "size": Vector2i(2, 2), "rarity": Item.BLUE, "value": 11000, "text": "家族客厅里摆的那种。"},
	"家族账本": {"region": "siracusa", "size": Vector2i(1, 1), "rarity": Item.PURPLE, "value": 20000, "text": "有几页被撕掉了。"},
	"家族印章": {"region": "siracusa", "size": Vector2i(1, 1), "rarity": Item.RED, "value": 45000, "text": "火漆上压出的是一头狼。"},
	# 明日方舟角色手办 (用户 2026-10-26): from any map.
	"芬手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.GREEN, "value": 4000, "text": "扭蛋款，底座上贴着编号。"},
	"克洛丝手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.GREEN, "value": 4000, "text": "眯着眼睛，手里一把弩。"},
	"杜宾手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.BLUE, "value": 9000, "text": "站得笔直，鞭子卷在手里。"},
	"古米手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.BLUE, "value": 9000, "text": "举着平底锅当盾牌。"},
	"红豆手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.BLUE, "value": 9000, "text": "举着长枪，背后是一把电吉他。"},
	"角峰手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.BLUE, "value": 9000, "text": "抱着一面大盾。"},
	"阿米娅手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.PURPLE, "value": 20000, "text": "罗德岛的领袖，戒指上发着光。"},
	"德克萨斯手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.PURPLE, "value": 20000, "text": "嘴里叼着一根巧克力棒。"},
	"拉普兰德手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.PURPLE, "value": 20000, "text": "双剑出鞘，笑得很开心。"},
	"白面鸮手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.PURPLE, "value": 20000, "text": "一身白，眼睛半睁着。"},
	"蓝毒手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.PURPLE, "value": 20000, "text": "举着弩，表情很认真。"},
	"临光手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.PURPLE, "value": 20000, "text": "盾上是卡西米尔的纹章。"},
	"能天使手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.RED, "value": 50000, "text": "光环和翅膀是另外装上去的。"},
	"银灰手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.RED, "value": 50000, "text": "披风是布做的。"},
	"陈手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.RED, "value": 50000, "text": "赤霄的剑鞘可以拔下来。"},
	"艾雅法拉手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.RED, "value": 50000, "text": "头上的角做得很仔细。"},
	"斯卡蒂手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.RED, "value": 50000, "text": "大剑比她本人还高。"},
	"凯尔希手办": {"region": "", "size": Vector2i(1, 2), "rarity": Item.RED, "value": 50000, "text": "身后站着一只小小的 Mon3tr。"},
}

## The five rarities and their weights, white → red (§4.3).
const RARITIES := [Item.GREY, Item.GREEN, Item.BLUE, Item.PURPLE, Item.RED]
const RARITY_WEIGHTS := [40.0, 28.0, 20.0, 9.0, 3.0]
## Per source: chance of one collectible (收藏品箱 always gives one).
const SAFE_CHANCE := 0.40
const OTHER_POI_CHANCE := 0.03
const VAULT_CHANCE := 0.15
const COLLECTOR_SECOND := 0.30

static func create(id: String) -> Item:
	var data: Dictionary = ITEMS[id]
	var size: Vector2i = data.size
	var item := Item.create(id, Item.Category.COLLECTIBLE, size.x, size.y)
	item.base_id = id
	item.rarity = int(data.rarity)
	# The table is in 龙门币; Item.value is in value units (Economy.LMD_PER_VALUE).
	item.value = int(data.value) / Economy.LMD_PER_VALUE
	item.description = str(data.text)
	item.origin_region = str(data.region)
	return item

static func is_collectible(item: Item) -> bool:
	return item != null and item.category == Item.Category.COLLECTIBLE

## One collectible for a map of `region`: its own pieces and the figurines,
## by rarity weight, leaning rarer deeper down (LootTables.rare_reach).
static func roll(region: String, depth: int, rng: RandomNumberGenerator) -> Item:
	var reach := LootTables.rare_reach(depth)
	var weights: Array = []
	for i in range(RARITY_WEIGHTS.size()): weights.append(float(RARITY_WEIGHTS[i]) * (1.0 + reach * i))
	var rarity: int = RARITIES[LootTables._pick_weighted(weights, rng)]
	var here: Array = ITEMS.keys().filter(func(id): return str(ITEMS[id].region) in [region, ""])
	var pool: Array = here.filter(func(id): return int(ITEMS[id].rarity) == rarity)
	if pool.is_empty(): pool = here
	if pool.is_empty(): return null
	return create(str(pool[rng.randi_range(0, pool.size() - 1)]))

static func is_figurine(id: String) -> bool:
	return ITEMS.has(id) and str(ITEMS[id].region).is_empty()

# --- 整理箱 ---------------------------------------------------------------------

const CASE_KINDS: Array[String] = ["material", "collectible", "potion", "gear"]
const CASE_NAMES := {"material": "材料整理箱", "collectible": "收藏品整理箱", "potion": "药剂整理箱", "gear": "装备整理箱"}
## Its footprint in the warehouse, level 1–4 (§0-4).
const CASE_SIZES := [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(5, 6)]
## Its own grid, by kind, level 1–4 (§2.2).
const CASE_GRIDS := {
	"material": [Vector2i(5, 5), Vector2i(6, 8), Vector2i(8, 10), Vector2i(10, 14)],
	"collectible": [Vector2i(4, 4), Vector2i(5, 6), Vector2i(7, 8), Vector2i(10, 12)],
	"potion": [Vector2i(4, 4), Vector2i(5, 6), Vector2i(6, 8), Vector2i(8, 12)],
	"gear": [Vector2i(4, 5), Vector2i(6, 8), Vector2i(8, 10), Vector2i(10, 14)],
}
const TIERS := 4
const LEVEL_NAMES := ["", "一级", "二级", "三级", "四级"]
## What 可露希尔 takes for a level (§2.3): materials by id, plus a collectible
## of at least that rarity ("collectible": rarity), plus the box one level down.
const RECIPES := [
	{},
	{"帆布": 4, "金属板": 4, "胶带": 4},
	{"帆布": 6, "密封泡沫": 2, "赤金": 2},
	{"碳素": 4, "密封泡沫": 4, "赤金": 5, "collectible": Item.BLUE},
	{"进阶加固建材": 4, "源石碎片": 2, "赤金": 10, "collectible": Item.PURPLE},
]

static func case_name(kind: String, tier: int) -> String:
	return "%s·%s" % [CASE_NAMES.get(kind, "整理箱"), LEVEL_NAMES[clampi(tier, 1, TIERS)]]

static func create_case(kind: String, tier: int) -> Item:
	tier = clampi(tier, 1, TIERS)
	var size: Vector2i = CASE_SIZES[tier - 1]
	var item := Item.create(case_name(kind, tier), Item.Category.CASE, size.x, size.y)
	item.case_kind = kind
	item.case_tier = tier
	item.base_id = "case_%s" % kind
	item.rarity = tier - 1
	item.value = 0
	var grid: Vector2i = CASE_GRIDS[kind][tier - 1]
	item.contents = ItemContainer.new(grid.x, grid.y)
	return item

## Whether a box of `kind` takes `item` (§2.1): never another box.
static func accepts(kind: String, item: Item) -> bool:
	if item == null or item.category == Item.Category.CASE or item.contents != null: return false
	match kind:
		"material": return item.category == Item.Category.MATERIAL and not item.is_potion()
		"collectible": return item.category == Item.Category.COLLECTIBLE
		"potion": return item.is_potion()
		"gear": return item.is_equippable()
	return false

## Into `box`: onto its stacks first, then the first free cell. False (and
## nothing moved) when it is the wrong kind or does not fit whole.
static func put(box: Item, item: Item) -> bool:
	if box == null or not box.is_case() or not accepts(box.case_kind, item) or not box.contents.can_take(item): return false
	return box.contents.add_stack(item) == 0
