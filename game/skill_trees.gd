class_name SkillTrees
extends RefCounted

## Each operator's tree (精英化与加点策划案_v0_2.md §8), after Grim Dawn's
## skill / modifier / transmuter and 明日方舟's skill levels, 专精 and modules.
##
## type: "signature" (rank 1 free) / "skill" / "modifier" / "passive" /
##       "transmuter" (one of a group active at a time).
## tier: the elite stage that opens the node. max: highest rank; skills with
## "mastery" go past 7 to 10 (专精 1–3), each of those costing 2 points and the
## MASTERY materials, and needing 精英 2. Ranks 5–7 of a skill or signature
## need 精英 1 (§4.0). `parent`: the node that must have a rank first.

const SKILL_CAP_E0 := 4
const MASTERY_POINTS := 2
const TRANSMUTER_POINTS := 2
## 专精 1–3 (PRTS 技能1 专精 recipe, mapped onto materials the game has).
const MASTERY := [
	{"技巧概要·卷3": 5, "提纯源岩": 3, "研磨石": 4},
	{"技巧概要·卷3": 6, "提纯源岩": 6, "化合切削液": 3},
	{"技巧概要·卷3": 10, "D32钢": 4, "改量装置": 4},
]
## Modules (模组, §8): 模组数据块 ×2 each level plus 龙门币 (PRTS 4/5/6 万 × 0.3).
const MODULE_COST := [
	{"lmd": 12000, "materials": {"模组数据块": 2}},
	{"lmd": 15000, "materials": {"模组数据块": 2}},
	{"lmd": 18000, "materials": {"模组数据块": 2}},
]

const TREES := {
	"lappland": {
		"wave": {"name": "剑气", "type": "signature", "tier": 0, "max": 7,
			"text": "命中 3 次蓄满，下一刀放出穿透剑气。剑气系数 %s。"},
		"sundial": {"name": "日晷", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"text": "连斩第 3 段命中后 4 秒内物理闪避 +%s，第 3 段伤害 +%s。"},
		"shadow_hand": {"name": "影落とす時針", "type": "modifier", "tier": 0, "max": 5, "parent": "sundial",
			"text": "第 3 段扫影距离 +%s；命中的敌人减速 %s，持续 2 秒。"},
		"frenzy": {"name": "狂暴攻势", "type": "passive", "tier": 0, "max": 5,
			"text": "连斩不中断时，第 2、3 段攻速 +%s。"},
		"wolf_spirit": {"name": "狼魂", "type": "skill", "tier": 1, "max": 10, "mastery": true,
			"text": "每放出 %s 道剑气，进入 6 秒狼魂：普攻变为法术伤害，攻击力 +%s，剑气蓄力降为 1 次。"},
		"extra_target": {"name": "额外攻击一个目标", "type": "modifier", "tier": 1, "max": 3, "parent": "wolf_spirit",
			"text": "狼魂期间，每次挥砍对 4 米内另一名敌人追加一次 %s 法术斩。"},
		"no_decay": {"name": "远程攻击不再降低攻击力", "type": "modifier", "tier": 1, "max": 5, "parent": "wave",
			"text": "剑气飞行衰减减少 %s。"},
		"shadow_step": {"name": "影步", "type": "passive", "tier": 1, "max": 5,
			"text": "闪避后 1.5 秒内的下一刀暴击率 +%s。"},
		"wave_pack": {"name": "狼群", "type": "transmuter", "group": "wave", "tier": 2, "max": 1,
			"text": "剑气分成 3 道扇形，每道 45%。"},
		"wave_fang": {"name": "獠牙", "type": "transmuter", "group": "wave", "tier": 2, "max": 1,
			"text": "剑气宽度 ×1.6、射程 +4，伤害 −20%。"},
		"wave_hound": {"name": "猎犬", "type": "transmuter", "group": "wave", "tier": 2, "max": 1,
			"text": "剑气追向最近的敌人，射程 −30%。"},
	},
	"amiya_guard": {
		"shadow": {"name": "影霄·绝影", "type": "signature", "tier": 0, "max": 10, "mastery": true,
			"text": "斩击系数 %s，冷却 %s 秒。"},
		"nightrun": {"name": "影霄·奔夜", "type": "skill", "tier": 0, "max": 10, "mastery": true,
			"text": "连斩第 2 段攻击力 +%s；第 2 段后 2 秒内法术闪避 +15%%。"},
		"quilon": {"name": "奎隆佩剑", "type": "passive", "tier": 0, "max": 5,
			"text": "普攻命中让绝影冷却多减 %s 秒。"},
		"kill_stack": {"name": "每击败一个敌人", "type": "modifier", "tier": 1, "max": 3, "parent": "shadow",
			"text": "绝影期间每击败一个敌人攻击力 +%s、法抗 +20，最多 3 层。"},
		"true_after_kill": {"name": "接下来的伤害类型变为真实", "type": "modifier", "tier": 1, "max": 1, "parent": "shadow",
			"text": "绝影击败敌人后，剩下的斩击为真实伤害。"},
		"double_cut": {"name": "二连击", "type": "modifier", "tier": 1, "max": 5, "parent": "nightrun",
			"text": "第 2 段第二刀有 %s 概率再追加一刀。"},
		"shadow_ten": {"name": "十连", "type": "transmuter", "group": "shadow", "tier": 2, "max": 1,
			"text": "斩击 4 → 6 次，每次伤害 −30%。"},
		"shadow_flash": {"name": "一闪", "type": "transmuter", "group": "shadow", "tier": 2, "max": 1,
			"text": "只斩 1 次，系数 ×3.5，真实伤害。"},
		"shadow_moon": {"name": "残月", "type": "transmuter", "group": "shadow", "tier": 2, "max": 1,
			"text": "弹跳范围 4 → 6。"},
	},
}

## Talents (天赋): no points; elite stage and module level raise them.
const TALENTS := {
	"lappland": {"name": "精神摧毁", "text": "攻击使目标的特殊能力失效 %s 秒（精英与首领 %s 秒）%s。"},
	"amiya_guard": {"name": "青色怒火", "text": "攻击力与防御力 +%s，绝影期间及之后 3 秒效果加倍。"},
}
const MODULES := {
	"lappland": {"name": "\"幼狼的牙齿\"", "type": "LOR-X", "stats": {"hp": 175.0, "atk": 40.0, "aspd": 6.0}},
	"amiya_guard": {"name": "待调弦的怒火", "type": "AFT-X", "stats": {"atk": 45.0, "res": 4.0}},
}

static func tree(operator_id: String) -> Dictionary:
	return TREES.get(operator_id, {})

static func node(operator_id: String, id: String) -> Dictionary:
	return tree(operator_id).get(id, {})

## Points the next rank of a node costs (rank is the current one).
static func rank_cost(data: Dictionary, rank: int) -> int:
	if str(data.get("type", "")) == "transmuter": return TRANSMUTER_POINTS
	if rank >= 7: return MASTERY_POINTS
	return 1

## The elite stage the next rank needs.
static func rank_elite(data: Dictionary, rank: int) -> int:
	var need := int(data.get("tier", 0))
	if str(data.get("type", "")) in ["skill", "signature"]:
		if rank >= 7: need = maxi(need, 2)
		elif rank >= SKILL_CAP_E0: need = maxi(need, 1)
	return need

## Materials the next rank needs: 专精 only.
static func rank_materials(data: Dictionary, rank: int) -> Dictionary:
	if bool(data.get("mastery", false)) and rank >= 7 and rank < 10: return MASTERY[rank - 7]
	return {}

## Total points spent to reach `rank` (for refunds).
static func spent(data: Dictionary, rank: int) -> int:
	var total := 0
	for r in range(rank):
		if str(data.get("type", "")) == "signature" and r == 0: continue
		total += rank_cost(data, r)
	return total

## Rank label: "3/7", "专精 2".
static func rank_label(data: Dictionary, rank: int) -> String:
	if str(data.get("type", "")) == "transmuter": return "已习得" if rank > 0 else "未习得"
	var top := mini(7, int(data.max))
	if rank > 7: return "专精 %d" % (rank - 7)
	return "%d/%d" % [rank, top]

# --- Values each rank gives (read by Player) ----------------------------------

## 剑气系数: 1.5 + 0.1 per rank above 1.
static func wave_scale(rank: int) -> float:
	return 1.5 + 0.1 * maxi(0, rank - 1)

## 日晷: [evasion after stage 3, stage-3 bonus].
static func sundial(rank: int) -> Array:
	if rank <= 0: return [0.0, 0.0]
	if rank > 7: return [[0.24, 0.28, 0.32][rank - 8], 0.35]
	return [0.08 + 0.02 * (rank - 1), 0.05 * rank]

## 狼魂: [waves to trigger, ATK bonus].
static func wolf_spirit(rank: int) -> Array:
	if rank <= 0: return [0, 0.0]
	if rank > 7: return [3 if rank == 10 else 4, [0.60, 0.70, 0.80][rank - 8]]
	return [4, 0.20 + 0.05 * (rank - 1)]

static func extra_target(rank: int) -> float:
	return [0.0, 0.40, 0.55, 0.70][clampi(rank, 0, 3)]

## 绝影: [strike scale, cooldown].
static func shadow(rank: int) -> Array:
	var scale := 1.0 + 0.06 * maxi(0, mini(rank, 7) - 1)
	var cooldown := 8.0 - (1.5 if rank >= 7 else 0.0)
	if rank > 7:
		scale += 0.12 * (rank - 7)
		cooldown -= 0.5 * (rank - 7)
	return [scale, cooldown]

## 奔夜: stage-2 ATK bonus.
static func nightrun(rank: int) -> float:
	if rank <= 0: return 0.0
	if rank > 7: return [0.36, 0.44, 0.52][rank - 8]
	return 0.04 * rank

static func kill_stack(rank: int) -> float:
	return [0.0, 0.10, 0.15, 0.20][clampi(rank, 0, 3)]

## 精神摧毁 by elite and module level: [seconds, seconds on elites, fragile].
static func mind_break(elite: int, module_level: int) -> Array:
	if elite <= 0: return [0.0, 0.0, 0.0]
	var fragile := 0.0
	if module_level >= 3: fragile = 0.08
	elif module_level >= 2: fragile = 0.04
	if elite == 1: return [1.0, 0.5, 0.0]
	return [6.0 if module_level >= 2 else 5.0, 2.0, fragile]

## 青色怒火 by elite and module level: ATK / DEF bonus.
static func cyan_fury(elite: int, module_level: int) -> float:
	if elite <= 0: return 0.0
	if elite == 1: return 0.04
	if module_level >= 3: return 0.09
	if module_level >= 2: return 0.08
	return 0.07

## The numbers shown in a node's text at `rank` (at least rank 1 for preview).
static func describe(operator_id: String, id: String, rank: int) -> String:
	var data := node(operator_id, id)
	if data.is_empty(): return ""
	var r := maxi(1, rank)
	var text := str(data.text)
	match id:
		"wave": return text % ("%d%%" % roundi(wave_scale(r) * 100))
		"sundial":
			var v := sundial(r)
			return text % ["%d%%" % roundi(v[0] * 100), "%d%%" % roundi(v[1] * 100)]
		"shadow_hand": return text % ["%d%%" % (8 * r), "%d%%" % (6 * r)]
		"frenzy": return text % str(4 * r)
		"wolf_spirit":
			var w := wolf_spirit(r)
			return text % [str(w[0]), "%d%%" % roundi(w[1] * 100)]
		"extra_target": return text % ("%d%%" % roundi(extra_target(r) * 100))
		"no_decay": return text % ("%d%%" % (20 * r))
		"shadow_step": return text % ("%d%%" % (10 * r))
		"shadow":
			var s := shadow(r)
			return text % ["%d%%" % roundi(s[0] * 100), "%.1f" % s[1]]
		"nightrun": return text % ("%d%%" % roundi(nightrun(r) * 100))
		"quilon": return text % ("%.1f" % (0.1 * r))
		"kill_stack": return text % ("%d%%" % roundi(kill_stack(r) * 100))
		"double_cut": return text % ("%d%%" % (8 * r))
	return text

static func talent_text(operator_id: String, elite: int, module_level: int) -> String:
	var data: Dictionary = TALENTS.get(operator_id, {})
	if data.is_empty(): return ""
	if operator_id == "lappland":
		var m := mind_break(maxi(1, elite), module_level)
		return str(data.text) % [str(roundi(m[0])), str(m[1]), "，并使其受到伤害 +%d%%" % roundi(m[2] * 100) if m[2] > 0 else ""]
	return str(data.text) % ("%d%%" % roundi(cyan_fury(maxi(1, elite), module_level) * 100))
