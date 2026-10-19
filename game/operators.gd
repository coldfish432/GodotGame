class_name Operators
extends RefCounted

## The playable operators, picked at the base before a contract (阿米娅攻击动作与
## 特效设计案 §十, 用户 2026-10-09: 剑兔 first, 术士 later). Each owns how she
## attacks — combo table, damage type and signature — and her sprite sheets;
## gear only rides on top (装备策划案 §2.4).

const LAPPLAND := "lappland"
const AMIYA_GUARD := "amiya_guard"
## Every operator, recruited or not (干员寻访策划案 §9: Amiya first; the rest are
## found region by region, RecruitCatalog).
const ORDER: Array[String] = [AMIYA_GUARD, LAPPLAND, "hellagur", "rosa", "hoshiguma", "lin", "typhon", "santalla", "texas"]
## Whose fighting is built (attack code, skill tree): Lappland and Amiya in
## Player, the recruits of batch R2 in their OperatorKit (entities/kits/).
const KIT := [LAPPLAND, AMIYA_GUARD, "hellagur", "rosa", "hoshiguma", "lin", "typhon", "santalla", "texas"]

const DATA := {
	LAPPLAND: {
		"name": "拉普兰德", "class": "近卫", "branch": "GUARD · LORD", "stars": 5,
		"portrait": "res://ui/art/lappland_portrait.png",
		"signature": "剑气", "damage": "phys",
	},
	AMIYA_GUARD: {
		"name": "阿米娅", "form": "剑兔", "class": "近卫", "branch": "GUARD · ARTS FIGHTER", "stars": 5,
		"portrait": "res://ui/art/amiya_guard_portrait.png",
		"signature": "绝影", "skill_key": "SPC", "damage": "arts",
	},
	# First recruits (干员寻访策划案 §4; Sol batches <CODE>1, prepare_operator_atlas.py).
	"hellagur": {"name": "赫拉格", "class": "近卫", "branch": "GUARD · DREADNOUGHT", "stars": 6,
		"portrait": "res://ui/art/hellagur_portrait.png", "signature": "月相", "damage": "phys"},
	"rosa": {"name": "早露", "class": "狙击", "branch": "SNIPER · BESIEGER", "stars": 6,
		"portrait": "res://ui/art/rosa_portrait.png", "signature": "雪崩击", "damage": "phys"},
	"hoshiguma": {"name": "星熊", "class": "重装", "branch": "DEFENDER · PROTECTOR", "stars": 6,
		"portrait": "res://ui/art/hoshiguma_portrait.png", "signature": "力之锯", "damage": "phys"},
	"lin": {"name": "林", "class": "术师", "branch": "CASTER · PRIMAL", "stars": 6,
		"portrait": "res://ui/art/lin_portrait.png", "signature": "流光乍裂", "damage": "arts"},
	"typhon": {"name": "提丰", "class": "狙击", "branch": "SNIPER · BESIEGER", "stars": 6,
		"portrait": "res://ui/art/typhon_portrait.png", "signature": "永恒狩猎", "damage": "phys"},
	"santalla": {"name": "寒檀", "class": "术师", "branch": "CASTER · SPLASH", "stars": 5,
		"portrait": "res://ui/art/santalla_portrait.png", "signature": "女巫之泪", "damage": "arts"},
	"texas": {"name": "德克萨斯", "class": "先锋", "branch": "VANGUARD · CHARGER", "stars": 5,
		"portrait": "res://ui/art/texas_portrait.png", "signature": "剑雨", "damage": "arts"},
}

## Whether her fighting is built, so she can deploy.
static func has_kit(id: String) -> bool:
	return id in KIT

static func valid(id: String) -> bool:
	return DATA.has(id)

static func info(id: String) -> Dictionary:
	return DATA.get(id, DATA[LAPPLAND])

static func display_name(id: String) -> String:
	var d := info(id)
	return str(d.name) + ("·" + str(d.form) if d.has("form") else "")

## The departure card's picture: the painted portrait when there is one,
## otherwise her standing field sprite facing the viewer.
static func portrait(id: String) -> Texture2D:
	var path := str(info(id).portrait)
	if not path.is_empty() and ResourceLoader.exists(path): return load(path)
	var idle: Texture2D = LapplandAnimator3D.sheet(id, "idle")
	if idle == null: return null
	var frame := AtlasTexture.new()
	frame.atlas = idle
	frame.region = Rect2(0, 0, LapplandAnimator3D.CELL_TEXELS, LapplandAnimator3D.CELL_TEXELS)
	return frame
