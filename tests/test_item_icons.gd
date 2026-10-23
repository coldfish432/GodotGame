extends SceneTree

## Equipment icons (装备策划案 §6, E1–E3 batches): every mapped icon exists at its
## native size and fits its tile, every region's droppable names all have art,
## materials and unknown names fall back to text, and the renamed elite weapon
## (镐柄战刃 → 断镐战斧) keeps its icon after loading an old save.

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

const SIZES := {Item.Category.WEAPON: Vector2(72, 32), Item.Category.ARMOR: Vector2(72, 72), Item.Category.TRINKET: Vector2(32, 32),
	Item.Category.CHEST: Vector2(72, 72), Item.Category.AMULET: Vector2(32, 32), Item.Category.HEAD: Vector2(72, 72), Item.Category.HANDS: Vector2(72, 72),
	Item.Category.LEGS: Vector2(72, 72), Item.Category.FEET: Vector2(72, 72), Item.Category.RING: Vector2(32, 32)}
const CELLS := {Item.Category.WEAPON: Vector2i(2, 1), Item.Category.ARMOR: Vector2i(2, 2), Item.Category.TRINKET: Vector2i(1, 1)}
const ICONS := {
	"改装砍刀": Item.Category.WEAPON, "制式短刀": Item.Category.WEAPON, "矿区制式刀": Item.Category.WEAPON,
	"纠察队佩刀": Item.Category.WEAPON, "断镐战斧": Item.Category.WEAPON,
	"矿工护甲": Item.Category.ARMOR, "整合运动制式外套": Item.Category.ARMOR, "纠察队防寒大衣": Item.Category.ARMOR,
	"矿场重型防护服": Item.Category.ARMOR,
	"防尘面罩": Item.Category.TRINKET, "烈酒扁壶": Item.Category.TRINKET, "整合运动面具": Item.Category.TRINKET,
	"源石感应计": Item.Category.TRINKET,
	"指刃": Item.Category.WEAPON, "帮派砍刀": Item.Category.WEAPON, "近卫局警用刀": Item.Category.WEAPON,
	"押运短刃": Item.Category.WEAPON, "炎式环首刀": Item.Category.WEAPON,
	"近卫局制式护甲": Item.Category.ARMOR, "消防署隔热服": Item.Category.ARMOR, "押运防弹背心": Item.Category.ARMOR,
	"特别督察组战术护甲": Item.Category.ARMOR,
	"战术挂饰": Item.Category.TRINKET, "近卫局对讲机": Item.Category.TRINKET, "龙门币钱夹": Item.Category.TRINKET,
	"炎式平安符": Item.Category.TRINKET,
	"破冰刀": Item.Category.WEAPON, "猎刀": Item.Category.WEAPON, "角柄猎刀": Item.Category.WEAPON,
	"科考队开路刀": Item.Category.WEAPON, "雪祀礼刃": Item.Category.WEAPON,
	"冰原毛皮外套": Item.Category.ARMOR, "雪橇巡逻队斗篷": Item.Category.ARMOR, "科考队防寒服": Item.Category.ARMOR,
	"骨片札甲": Item.Category.ARMOR,
	"骨制护符": Item.Category.TRINKET, "角兽骨笛": Item.Category.TRINKET, "兽骨鼓槌": Item.Category.TRINKET,
	"密文板残片": Item.Category.TRINKET,
}

func run() -> void:
	# 装备扩充策划案 §4: the 66 new bases are mapped too (39 + 66); E13 v1 11, E6 v1 7, E14 v1 22.
	check("all 39 E1–E3 items are mapped", ICONS.keys().all(func(n): return ItemIcons.BY_NAME.has(n)) and ItemIcons.BY_NAME.size() == 145, ItemIcons.BY_NAME.size())
	for item_name in ICONS:
		var category: int = ICONS[item_name]
		var cells: Vector2i = CELLS[category]
		var item := Item.create(item_name, category as Item.Category, cells.x, cells.y)
		var texture := ItemIcons.texture_for(item)
		check("%s has an icon at %s" % [item_name, SIZES[category]], texture != null and texture.get_size() == SIZES[category],
			texture.get_size() if texture != null else null)
		var tile := Vector2(cells) * InventoryPanel.CELL - Vector2(2, 2)
		check("%s fits inside its rarity border" % item_name, texture != null and texture.get_width() <= tile.x - 4 and texture.get_height() <= tile.y - 4)
	for id in GearCatalog.BASES:
		var b: Dictionary = GearCatalog.BASES[id]
		# E15 (装备部位拆分与数值案 §7): head, hands, legs, feet and rings show their
		# slot's placeholder at the slot's size until Sol's art lands under the id.
		if str(b.icon) == str(id):
			var probe := Item.create(str(b.name), int(b.category) as Item.Category, 1, 1)
			probe.base_id = id
			var tex := ItemIcons.texture_for(probe)
			check("E15 base %s shows an icon at its slot's size" % id, tex != null and tex.get_size() == SIZES[int(b.category)], tex.get_size() if tex != null else null)
			continue
		check("base %s「%s」uses its own icon" % [id, b.name], ItemIcons.BY_NAME.get(b.name, "") == b.icon and ResourceLoader.exists(ItemIcons.DIR + b.icon + ".png"))
	for enemy in ["thug", "crossbow", "crossbow_leader", "brawler", "ice_warrior", "ice_hunter"]:
		var carried := GearCatalog._carried(enemy, "mine")
		check("%s carries a weapon with an icon" % enemy, not carried.is_empty() and ItemIcons.BY_NAME.has(GearCatalog.BASES[carried].name))
	# E4: special gear and regional exclusives.
	for id in SpecialGear.GEAR:
		var gear := SpecialGear.create(id, 3, RandomNumberGenerator.new())
		var tex := ItemIcons.texture_for(gear)
		check("special %s has its icon" % gear.item_name, tex != null and tex.get_size() == SIZES[gear.category], tex.get_size() if tex != null else null)
	for region in ["mine", "city", "snow"]:
		var ex := FieldCatalog.exclusive(region)
		var tex := ItemIcons.texture_for(ex)
		var tile := Vector2(ex.width, ex.height) * InventoryPanel.CELL - Vector2(2, 2)
		check("exclusive %s has an icon that fits its tile" % ex.item_name, tex != null and tex.get_width() <= tile.x - 4 and tex.get_height() <= tile.y - 4,
			tex.get_size() if tex != null else null)
	var ore := ItemIcons.texture_for(FieldCatalog.exclusive("mine"))
	check("the ore icon is 32×72", ore != null and ore.get_size() == Vector2(32, 72))
	for id in ["raw_originium", "twin_fang", "ember_fang", "moon_edge", "crystal_edge", "vein_core"]:
		check("%s has an emit mask" % id, ResourceLoader.exists(ItemIcons.DIR + id + "_emit.png"))
	# E16 (2026-10-23): the Rhodes protective line shows Sol's art, not the placeholder.
	for id in ["rhodes_head_heavy", "rhodes_hands_heavy", "rhodes_legs_heavy", "rhodes_feet_heavy", "rhodes_ring_monitor"]:
		var probe := Item.create(str(GearCatalog.BASES[id].name), int(GearCatalog.BASES[id].category) as Item.Category, 1, 1)
		probe.base_id = id
		check("E16 %s uses its own icon" % id, ItemIcons.path_for(probe) == ItemIcons.DIR + id + ".png")
	for id in ["rhodes_head_heavy", "rhodes_ring_monitor"]:
		check("%s has an emit mask" % id, ResourceLoader.exists(ItemIcons.DIR + id + "_emit.png"))
	# M1: every PRTS material (and 赤金) has a 32×32 icon; materials and
	# potions without art yet still fall back to text.
	var prts_missing := []
	for id in MaterialCatalog.MATERIALS:
		# Trade goods and 萨米 goods are not PRTS items; they borrow supplies icons.
		if MaterialCatalog.MATERIALS[id].get("source", "") in ["common", "trade", "pack", "sami", "yan", "special", "farm", "meal"]: continue
		var tex := ItemIcons.texture_for(MaterialCatalog.create(id, 1))
		if tex == null or tex.get_size() != Vector2(32, 32): prts_missing.append(id)
	check("every PRTS material has a 32×32 icon", prts_missing.is_empty(), prts_missing)
	check("赤金 has its icon", ItemIcons.icon_id(MaterialCatalog.create(Economy.GOLD_ID, 3)) == "pure_gold")
	var unmapped: Array = MaterialCatalog.MATERIALS.keys().filter(func(id): return not ItemIcons.MATERIALS.has(id))
	check("every material id has an icon id", unmapped.is_empty(), unmapped)
	check("源石碎片 has an emit mask", ResourceLoader.exists(ItemIcons.DIR + "originium_shard_emit.png"))
	# M2: common supplies fill 36 px per cell minus the margin (1 cell = 32,
	# 2 = 72, 3 = 108); three items wait for a redraw and stay text.
	var held := ["医用耗材包", "固体燃料"]
	var wrong := []
	for id in MaterialCatalog.MATERIALS:
		if MaterialCatalog.MATERIALS[id].get("source", "") != "common" or held.has(id): continue
		var item := MaterialCatalog.create(id, 1)
		var tex := ItemIcons.texture_for(item)
		var want := Vector2(32 if item.width == 1 else item.width * 36, 32 if item.height == 1 else item.height * 36)
		if tex == null or tex.get_size() != want: wrong.append([id, tex.get_size() if tex else null, want])
	check("every accepted common supply has an icon sized to its cells", wrong.is_empty(), wrong)
	for id in held: check("%s waits for its redraw (text)" % id, ItemIcons.texture_for(MaterialCatalog.create(id, 1)) == null)
	for type in ["A", "B"]:
		var tex := ItemIcons.texture_for(BaseCatalog.create_potion(type))
		check("potion %s has a 32×32 icon" % type, tex != null and tex.get_size() == Vector2(32, 32))
	# 用户 2026-10-10 (消耗品的图标改为原画): potion C uses its M3 v1 art until the
	# M3 v2 redraw lands (M23_revision_v2.md).
	check("potion C shows its interim M3 v1 art", ItemIcons.texture_for(BaseCatalog.create_potion("C")) != null)
	check("items without art fall back to text", ItemIcons.texture_for(Item.create("外勤战刃", Item.Category.WEAPON, 2, 1)) == null)
	var old := Item.create("镐柄战刃", Item.Category.WEAPON, 2, 1, 2.0)
	var loaded := Item.from_data(old.to_data())
	check("an old 镐柄战刃 loads as 断镐战斧 with its icon", loaded.item_name == "断镐战斧" and ItemIcons.texture_for(loaded) != null, loaded.item_name)
	var old_knife := Item.from_data(Item.create("冰原猎刀", Item.Category.WEAPON, 2, 1, 2.0).to_data())
	check("an old 冰原猎刀 loads as 角柄猎刀 with its icon", old_knife.item_name == "角柄猎刀" and ItemIcons.texture_for(old_knife) != null, old_knife.item_name)
	for pair in [["originium_meter", Vector2(32, 32)], ["lgd_radio", Vector2(32, 32)], ["tactical_charm", Vector2(32, 32)],
			["cipher_fragment", Vector2(32, 32)], ["snowpriest_blade", Vector2(72, 32)]]:
		var emit: Texture2D = load(ItemIcons.DIR + pair[0] + "_emit.png")
		check("%s's emit mask matches its sprite" % pair[0], emit != null and emit.get_size() == pair[1])
	print("\n%d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
