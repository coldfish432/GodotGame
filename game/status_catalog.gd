class_name StatusCatalog
extends RefCounted
## What counts as a buff or a debuff, and how each one reads in the status bar
## (GPU粒子特效推广策划案 v0.6 §7a P6, §7b P7).
##   KEY_GOOD: for every share a player hex carries, whether more of it is
##     good for her (atk +0.2 good; def −0.3 bad; taken +0.15 bad);
##   ENEMY_GOOD: an enemy status, good for the enemy (a buff) or not;
##   META: hex keys that are bookkeeping, not effects.
## The rings show only timed hexes; the bar lists every hex, the canteen meal
## and the meters' stage penalties.

const KEY_GOOD := {"atk": true, "aspd": true, "def": true, "move": true, "stamina": true, "taken": false}
const META := ["time", "stacks"]
const KEY_NAMES := {"atk": "攻击", "aspd": "攻速", "def": "防御", "move": "移速", "stamina": "体力恢复", "taken": "承受伤害"}
const ENEMY_GOOD := {"haste": true, "slow": false, "frozen": false, "fragile": false, "res_down": false, "weaken": false, "burn": false}
## Names of the hexes that are not potions.
const HEX_NAMES := {"meal": "食堂补给", "corr_burst": "腐蚀", "necro_burst": "凋亡", "boss_shred": "破甲", "boss_awe": "威慑", "boss_curse": "诅咒",
	"boss_zone": "压制", "boss_grenade": "震荡"}

## [buff, debuff] for one hex entry: which way its shares point.
static func hex_sides(entry: Dictionary) -> Array:
	var good := false
	var bad := false
	for key in entry:
		if key in META: continue
		var v := float(entry[key])
		if is_zero_approx(v): continue
		var up: bool = KEY_GOOD.get(key, true)
		if (v > 0.0) == up: good = true
		else: bad = true
	return [good, bad]

## Whether the player's hexes hold a timed buff and a timed debuff (the rings).
static func player_rings(hexes: Dictionary) -> Array:
	var up := false
	var down := false
	for id in hexes:
		var entry: Dictionary = hexes[id]
		if float(entry.get("time", -1.0)) <= 0.0: continue
		var sides := hex_sides(entry)
		up = up or sides[0]
		down = down or sides[1]
	return [up, down]

## [buff, debuff] for an enemy: its timed statuses, stun and silence.
static func enemy_rings(enemy: Enemy) -> Array:
	var up := false
	var down := enemy.stun_timer > 0.0 or enemy.silence_timer > 0.0
	for status in enemy.statuses:
		if float(enemy.statuses[status].get("time", 0.0)) <= 0.0: continue
		if ENEMY_GOOD.get(status, false): up = true
		else: down = true
	return [up, down]

## The status bar's entries, in the order they turned up (caller keeps order).
## Each: {id, name, effect (lines), good, time, total, icon: {potion|glyph}}.
static func bar_entries(game: GameManager) -> Array:
	var out: Array = []
	var p := game.player
	if not is_instance_valid(p): return out
	for id in p.hexes:
		var entry: Dictionary = p.hexes[id]
		var key := str(id)
		if key == "meal": continue
		var sides := hex_sides(entry)
		var item := {"id": key, "name": hex_name(key), "effect": effect_lines(entry), "good": sides[0] and not (sides[1] and not _main_good(key)),
			"time": float(entry.get("time", -1.0)), "icon": icon_for(key)}
		out.append(item)
	if p.hexes.has("meal") or p._buff_max_hp_bonus > 0.0 or p._buff_damage_bonus > 0.0:
		var lines: Array = effect_lines(p.hexes.get("meal", {}))
		if p._buff_max_hp_bonus > 0.0: lines.append("生命上限 +%d" % roundi(p._buff_max_hp_bonus))
		if p._buff_damage_bonus > 0.0: lines.append("伤害 +%d%%" % roundi(p._buff_damage_bonus * 100.0))
		out.append({"id": "meal", "name": "食堂补给", "effect": lines, "good": true, "time": -1.0, "icon": {"glyph": "meal"}})
	if not game.in_base:
		for kind in FeatureCatalog.KINDS:
			if FeatureCatalog.REGION_OF[kind] != game.region_id and kind != "contamination": continue
			var stage := game.features.tier(kind)
			if stage <= 0: continue
			out.append({"id": "stage_%s_%d" % [kind, stage], "name": "%s·%s" % [FeatureCatalog.NAMES[kind], FeatureCatalog.TIER_NAMES[kind][stage]],
				"effect": stage_lines(kind, stage), "good": false, "time": -1.0, "icon": {"glyph": kind}})
	return out

## A potion's main effect decides its frame (the side effect comes after).
static func _main_good(id: String) -> bool:
	return id.begins_with("potion_") and not id.ends_with("_after")

static func hex_name(id: String) -> String:
	if id.begins_with("potion_"):
		var type := id.trim_prefix("potion_").trim_suffix("_after")
		var name := str(BaseCatalog.POTIONS.get(type, {}).get("name", type))
		return name + ("（副作用）" if id.ends_with("_after") else "")
	if id.begins_with("boss_"): return str(HEX_NAMES.get(id, "首领压制"))
	return str(HEX_NAMES.get(id, id))

static func icon_for(id: String) -> Dictionary:
	if id.begins_with("potion_"): return {"potion": id.trim_prefix("potion_").trim_suffix("_after")}
	if id.begins_with("boss_"): return {"glyph": "boss"}
	if id == "corr_burst": return {"glyph": "corrode"}
	if id == "necro_burst": return {"glyph": "necro"}
	return {"glyph": "boss"}

## "攻击 +20%" lines from a hex's shares.
static func effect_lines(entry: Dictionary) -> Array:
	var lines: Array = []
	for key in entry:
		if key in META or not KEY_NAMES.has(key): continue
		var v := float(entry[key])
		if is_zero_approx(v): continue
		lines.append("%s %s%d%%" % [KEY_NAMES[key], "+" if v > 0.0 else "−", roundi(absf(v) * 100.0)])
	return lines

## What a meter's stage does (FeatureCatalog / BaseCatalog tiers).
static func stage_lines(kind: String, stage: int) -> Array:
	match kind:
		"cold":
			var t: Array = FeatureCatalog.COLD_TIERS[stage]
			var lines: Array = ["移速 −%d%%" % roundi(float(t[0]) * 100.0), "体力恢复 −%d%%" % roundi(float(t[1]) * 100.0)]
			if float(t[2]) > 0.0: lines.append("攻速 −%d%%" % roundi(float(t[2]) * 100.0))
			if bool(t[3]): lines.append("停止自然回复")
			if float(t[4]) > 0.0: lines.append("每秒流失生命上限 %.1f%%" % (float(t[4]) * 100.0))
			return lines
		"contamination":
			var c: Array = BaseCatalog.CONTAMINATION_TIERS[stage]
			var lines: Array = ["生命上限 −%d%%" % roundi(float(c[1]) * 100.0)]
			if bool(c[3]): lines.append("停止自然回复")
			else: lines.append("自然回复 ×%.1f" % float(c[4]))
			if float(c[2]) > 0.0: lines.append("药剂回复 −%d%%" % roundi(float(c[2]) * 100.0))
			if float(c[5]) > 0.0: lines.append("每秒流失生命上限 %.1f%%" % (float(c[5]) * 100.0))
			return lines
		"debt":
			if stage == 1: return ["家族伤害 +%d%%" % roundi(FeatureCatalog.FEUD_DAMAGE * 100.0), "家族视野 +%d%%" % roundi(FeatureCatalog.FEUD_SIGHT * 100.0)]
			return ["家族伤害 +%d%%" % roundi(FeatureCatalog.FEUD_DAMAGE * 100.0), "清算时刻每 %d 秒一次" % roundi(FeatureCatalog.RECKONING_EVERY)]
	return []
