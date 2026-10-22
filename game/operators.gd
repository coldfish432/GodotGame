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
		"signature": "剑气", "skill": "日晷", "skill_key": "SPC", "damage": "phys",
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

## What her weapon's panel gives (复利数值改造清单 F): ATK for those whose own
## attacks are physical, arts for the arts fighters. Physical hits use ATK and
## arts hits arts power whatever her main stat is.
const MAIN_STAT := {
	LAPPLAND: "atk", AMIYA_GUARD: "arts", "hellagur": "atk", "rosa": "atk", "hoshiguma": "atk",
	"lin": "arts", "typhon": "atk", "santalla": "arts", "texas": "atk",
}

static func main_stat(id: String) -> String:
	return str(MAIN_STAT.get(id, "atk"))

## Her own build (清单 I, PRTS 精英 2 满级 pulled 40% toward 拉普兰德's): life and
## defence multiply the final numbers, so the gap holds at every depth; RES adds.
## ATK has none: her intervals and combo already carry PRTS's ATK gaps.
const STAT_MULT := {
	LAPPLAND: {"hp": 1.00, "def": 1.00, "res": 15.0},
	AMIYA_GUARD: {"hp": 1.07, "def": 1.02, "res": 20.0},
	"hellagur": {"hp": 1.38, "def": 0.95, "res": 0.0},
	"hoshiguma": {"hp": 1.38, "def": 1.59, "res": 0.0},
	"texas": {"hp": 0.90, "def": 0.96, "res": 0.0},
	"rosa": {"hp": 0.85, "def": 0.60, "res": 0.0},
	"typhon": {"hp": 0.83, "def": 0.59, "res": 0.0},
	"lin": {"hp": 0.92, "def": 0.80, "res": 15.0},
	"santalla": {"hp": 0.82, "def": 0.60, "res": 20.0},
}

static func stat_mult(id: String, key: String) -> float:
	return float((STAT_MULT.get(id, STAT_MULT[LAPPLAND]) as Dictionary).get(key, 1.0 if key != "res" else 0.0))

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
