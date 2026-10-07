class_name RelicIcons
extends RefCounted

## Relic icons (美术补全案 §5, batches R1–R4). Native 72×72, drawn at whole
## multiples only (1× in the R window, shop and detail card, 2× on the pick
## card). Ids are the PRTS season + collectible number (art/relics/refs/
## relics_table.json); relics without art keep the first-character plate.
## Finished art is copied from art/relics/batch_R*_v* into art/relics/runtime/.

const DIR := "res://art/relics/runtime/"
const NATIVE := 72
## Relic name → icon id, all 96 relics.
const BY_NAME := {
	"皇帝的恩宠": "is2_058", "贵族刺剑": "is2_059", "老近卫军之锋": "is2_060", "锈蚀刀片": "is2_067",
	"\"复仇者\"": "is2_069", "残破合影": "is2_049", "迷迭香之拥": "is2_051", "撕扯之手": "is2_137",
	"\"黑夜呢喃\"": "is2_052", "《大静谧》": "is2_054", "扼喉之手": "is2_134", "溃决之手": "is4_185",
	"荣耀绶带": "is2_172", "绿叶菜罐头": "is2_168", "叙拉古人的愤怒": "is2_170", "\"噤声\"": "is2_228",
	"轰鸣之手": "is5_186", "古乔治营养原浆": "is3_124", "赏善郎": "is6_099", "《光耀卡西米尔》": "is3_120",
	"《归来》": "is3_121", "《拳经三问》": "is6_175", "折戟-破釜沉舟": "is2_102", "死仇时代的恨意": "is5_229",
	"显圣吊坠": "is2_061", "银餐叉": "is2_062", "损坏的左轮弹巢": "is2_063", "残弩-交叉火力": "is2_111",
	"制式防暴用具": "is2_070", "\"璀璨悲泣\"": "is2_072", "断杖-苦难巫咒": "is2_117", "古高卢银币": "is2_149",
	"《第二经济改革法》": "is2_152", "香草沙士汽水": "is2_153", "迷梦香精": "is2_156", "折戟-浴血": "is2_100",
	"积攒之手": "is2_139", "冰结的躯壳": "is4_127", "疗养体验卡": "is3_122", "疗养特供卡": "is3_123",
	"鸣脊兽": "is6_270", "老磨盘": "is6_269", "紧急活性剂": "is3_125", "国王的新枪": "is2_pcs01",
	"魔王的旗帜": "is5_215", "钝爪-振奋": "is2_096", "\"断剑\"": "is2_197", "投币玩具": "is2_165",
	"骑士戒律·新编": "is2_166", "金酒之杯": "is2_167", "\"永夜的窥视\"": "is4_129", "异铁小圆盾": "is2_055",
	"军团护心镜": "is2_056", "古旧的蒸汽甲胄": "is2_057", "开裂的束缚带": "is2_046", "奇渊面具": "is2_047",
	"教母的信物": "is2_048", "设计师量尺": "is2_076", "\"法术杀手\"": "is2_077", "舞者手链": "is2_078",
	"女皇之愿": "is2_218", "《麻木与庸俗》": "is2_206", "皇族金胸针": "is2_222", "药枚": "is3_118",
	"活木甲": "is4_134", "墙眼": "is6_106", "古堡的子嗣": "is2_pcs04", "魔王的床榻": "is5_214",
	"霜牡的肩甲": "is4_136", "雪牝的护手": "is4_137", "难闻的止血剂": "is2_064", "急救药箱": "is2_065",
	"未知仪器": "is2_066", "活玫瑰": "is2_073", "苍白花冠": "is2_074", "演出用香水": "is2_075",
	"\"迷醉荷谟伊\"": "is2_217", "《坎德之花》": "is2_205", "\"枯木的回声\"": "is4_130", "\"萤灯映牍\"": "is6_102",
	"\"忠义\"": "is2_173", "复还之手": "is4_246", "\"时光之末\"": "is2_174", "米诺斯颂诗": "is4_256",
	"\"静音小队\"": "is2_045", "皮特水果什锦": "is3_006", "\"剑锤\"": "is2_196", "统帅肖像": "is5_216",
	"登天斧": "is6_271", "Friston.P": "is4_257", "圆石祭坛": "is4_207", "友谊之证": "is2_199",
	"锈蚀的铁锤": "is2_035", "幸运硬币": "is2_030", "假面舞会面具": "is2_031", "罗德岛战术电台": "is2_230",
}

static var _cache := {}

static func icon_id(relic: Dictionary) -> String:
	return BY_NAME.get(str(relic.get("name", "")), "")

static func texture_for(relic: Dictionary) -> Texture2D:
	var id := icon_id(relic)
	if id.is_empty(): return null
	var path := DIR + id + ".png"
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
