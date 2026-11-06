class_name FactionRewards
extends RefCounted

## 势力声望解锁策划案 v0.1 (用户 2026-11-02 拍板): the gifts each faction sends
## the first time she reaches 友好, 尊敬, 崇敬 and 崇拜; the goods its shelf
## carries from 崇敬; the badge it sends at 崇拜, which works in the warehouse
## while the relation stays at 崇敬 or above; and its posts by rank.
## The price table and the rank discounts live in Exchange.

## §2.4: the ranks that send a gift, once each.
const GIFT_RANKS := [2, 3, 4, 5]
## 友好: the two cheapest plain goods on its shelf, this many of each.
const FRIEND_COUNT := 5
## 崇敬: this much in its own currency, at 龙门币 worth.
const REVERED_LMD := 30000.0
## 尊敬 sends its specials whose door is at or below it; one with a higher door
## comes with that rank's gift instead.
const HONORED := 3

## §三 崇敬 goods: material -> [faction, the map it is used on ("" = at the base)].
const GOODS := {
	"近卫局通行证": ["lungmen", "city"],
	"下城区黑市名录": ["rat", "city"],
	"莱茵实验抑制剂": ["rhine", ""],
	"雪山向导绳": ["karlan", "snow"],
	"矿场勘探图": ["ursus", "mine"],
	"残党暗号": ["reunion", "mine"],
	"冰原熏肉": ["sami", ""],
	"商业联合会担保函": ["kazimierz", ""],
	"加急专递单": ["penguin", ""],
}
const GOODS_RANK := 4
## 莱茵实验抑制剂 arrives as a flask (BaseCatalog.POTIONS "rhine").
const FLASK_OF := {"莱茵实验抑制剂": "rhine"}
## 企鹅物流 has no shelf: its 加急专递单 is bought at its desk, like 企鹅专递单.
const EXPRESS := "加急专递单"
const EXPRESS_PRICE := 28000

## §三 崇拜 badges: faction -> material.
const BADGES := {
	"lungmen": "商会荣誉理事章", "rat": "老鼠王的信物", "rhine": "莱茵合作研究员证",
	"karlan": "喀兰贸易金卡", "ursus": "矿场主事铭牌", "reunion": "残党联络人",
	"sami": "萨米部族护符", "kazimierz": "骑士竞技场赞助证", "penguin": "企鹅物流 VIP 卡",
}
const BADGE_RANK := 4

## The effects.
const PASS_THREAT := 0.7          # 近卫局通行证: threat grows × this on its floor
const ROPE_COLD := 0.5            # 雪山向导绳: cold grows × this on its floor
const SURVEY_VEINS := 2           # 矿场勘探图: this many more ore veins
const COUNCIL_PAY := 1.1          # 商会荣誉理事章: 龙门's posts and 坎诺特 pay × this
const RESEARCHER_GROW := 0.8      # 莱茵合作研究员证: crops grow in × this of the time
const AMULET_FIRE := 2.0          # 萨米部族护符: a fire warms × this
const ARENA_CFD := 0.5            # 骑士竞技场赞助证: 差价合约 opening fee × this
const EXPRESS_WAIT := 0.5         # 加急专递单: an insured piece's return wait × this
const KARLAN_PORT := "谢拉格"      # 喀兰贸易金卡: voyages there are free

## §四 posts: odds by rank, the extra shelf from 尊敬, the 崇拜 gift each meeting.
const POST_ODDS := [1.0, 1.0, 1.2, 1.2, 1.5, 1.5]
const POST_EXTRA_RANK := 3
const POST_EXTRA := {
	"rat": ["改量装置", "微型电机"], "reunion": ["提纯源岩", "糖组"],
	"ursus": ["异铁组", "提纯源岩"], "sami": ["碳素组", "糖组"],
}
const POST_GIFT := {"sami": ["萨米冰原苔", 1], "ursus": ["固源岩", 3], "rat": ["装置", 1], "reunion": ["残党向导", 1]}

static func is_good(material: String) -> bool:
	return GOODS.has(material)

static func is_badge(material: String) -> bool:
	return BADGES.values().has(material)

static func badge_faction(material: String) -> String:
	for f in BADGES:
		if BADGES[f] == material: return f
	return ""

## The badge of `faction` works: in the warehouse, and the relation at 崇敬 or above.
static func badge_on(game: GameManager, faction: String) -> bool:
	if game == null or not BADGES.has(faction) or game.exchange.rank(faction) < BADGE_RANK: return false
	var id: String = BADGES[faction]
	for item in game.base.stock():
		if item.material_id == id: return true
	return false

## The goods for the faction's shelf from 尊敬 at its posts.
static func post_extra(faction: String, rank: int) -> Array:
	return POST_EXTRA.get(faction, []) if rank >= POST_EXTRA_RANK else []

## A bought good as it reaches her: 莱茵实验抑制剂 as its flask.
static func as_goods(material: String, count: int) -> Item:
	if FLASK_OF.has(material):
		var flask := BaseCatalog.create_potion(str(FLASK_OF[material]), 1)
		flask.set_quantity(mini(count, flask.max_stack))
		return flask
	return MaterialCatalog.create(material, count)

## What reaching `rank` with `faction` sends: {material: count}, and 龙门币
## worth in its currency under "money".
static func gift(faction: String, rank: int) -> Dictionary:
	var out := {}
	match rank:
		2:
			var plain: Array = FactionSpecials.plain_shelf(faction).filter(func(m): return MaterialCatalog.MATERIALS.has(m) and not Packs.is_pack(m))
			plain.sort_custom(func(a, b): return MaterialCatalog.create(a, 1).unit_value < MaterialCatalog.create(b, 1).unit_value)
			for m in plain.slice(0, 2): out[m] = FRIEND_COUNT
			if plain.is_empty() and faction == "penguin": out["企鹅专递单"] = 1
		3, 4, 5:
			for m in FactionSpecials.ITEMS:
				if FactionSpecials.faction_of(m) == faction and maxi(HONORED, FactionSpecials.rank_needed(m)) == rank: out[m] = 1
			if rank == HONORED and faction == GameManager.DIRECTED_FACTION: out[GameManager.DIRECTED_MATERIAL] = 1
			if rank == 4: out["money"] = REVERED_LMD
			if rank == 5: out[BADGES[faction]] = 1
	return out
