class_name Operators
extends RefCounted

## The playable operators, picked at the base before a contract (阿米娅攻击动作与
## 特效设计案 §十, 用户 2026-10-09: 剑兔 first, 术士 later). Each owns how she
## attacks — combo table, damage type and signature — and her sprite sheets;
## gear only rides on top (装备策划案 §2.4).

const LAPPLAND := "lappland"
const AMIYA_GUARD := "amiya_guard"
const ORDER: Array[String] = [LAPPLAND, AMIYA_GUARD]

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
}

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
