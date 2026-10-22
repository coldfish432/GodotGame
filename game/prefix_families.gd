class_name PrefixFamilies
extends RefCounted

## Effect prefix families (前缀放大与特效阶等案_v1_0.md §3, 用户 2026-10-21):
## every effect prefix belongs to a family, and a family's 阶等 is how many
## worn pieces carry it, up to (8). (1)(2)(3)(5)(7) raise its number, (4)(6)(8)
## each add a special effect, and a higher 阶等 keeps everything below it. At
## most three families work at once: the three of highest 阶等, ties by the
## paper doll's order. Only (8) deals damage of its own.
##
## The table and the 阶等 arithmetic are static; one instance per player
## keeps the runtime state (stacks, timers, the mark) and answers her hooks.

const MAX_TIER := 8
const ACTIVE_MAX := 3
## Which 阶等 sets the number: (4) keeps (3)'s, (6) keeps (5)'s, (8) keeps (7)'s.
const VALUE_TIERS := [1, 2, 3, 5, 7]
const SPECIAL_TIERS := [4, 6, 8]

## id: name, region (3× likelier there, "" anywhere), the W / A / T prefix ids
## and names (an old id keeps its old name), the five numbers and the texts.
## `%s` in a number line is the current number.
const FAMILIES := {
	"riot": {"name": "暴动", "region": "mine",
		"prefixes": [["riot", "暴动的", "Rioting", "W"], ["riot_a", "骚乱的", "Unruly", "A"], ["riot_t", "喧嚣的", "Clamorous", "T"]],
		"values": [0.006, 0.012, 0.02, 0.03, 0.04],
		"number": "6 米内每名敌人攻击力 %s（至多 5 名）",
		"specials": ["怒潮：击杀后 5 秒内攻速 +4，至多 5 层", "众怒：周围 4 名以上敌人时受到伤害 −15%；计数上限 8 名",
			"暴乱：怒潮满 5 层时，普攻在落点引发冲击，对 3 米内敌人造成 60% 攻击力的物理伤害"]},
	"familial": {"name": "家族", "region": "",
		"prefixes": [["familial", "家族的", "Familial", "W"], ["familial_a", "世家的", "Patrician", "A"], ["familial_t", "门第的", "Highborn", "T"]],
		"values": [0.03, 0.06, 0.10, 0.15, 0.20],
		"number": "生命高于 90% 时攻击力 %s",
		"specials": ["门第：门槛降到 70%；第一次跌破门槛时得到 10% 生命上限的护盾（20 秒一次）", "家声：满血时暴击率 +12%；击杀回复 3% 生命",
			"族长：生命高于门槛时攻击无视 30% 防御；跌破门槛时对 4 米内敌人造成 300% 攻击力的物理伤害并击退"]},
	"guerrilla": {"name": "游击", "region": "",
		"prefixes": [["guerrilla_w", "游猎的", "Roving", "W"], ["guerrilla_a", "机动的", "Mobile", "A"], ["guerrilla", "游击的", "Guerrilla", "T"]],
		"values": [0.04, 0.08, 0.12, 0.18, 0.25],
		"number": "闪避后 2 秒内攻击力 %s",
		"specials": ["突袭：闪避后的下一击必定暴击", "回身：闪避穿过敌人时返还 40% 闪避体力；闪避冷却 −20%",
			"游击战：闪避穿过的敌人受到 150% 攻击力的物理伤害，减速 40%，持续 2 秒"]},
	"forest": {"name": "林栖", "region": "snow",
		"prefixes": [["forest_w", "林语的", "Whispering", "W"], ["forestdweller", "林栖的", "Forest-Dwelling", "A"], ["forest_t", "林荫的", "Shaded", "T"]],
		"values": [0.004, 0.006, 0.008, 0.012, 0.016],
		"number": "空闲 3 秒后，每秒回复生命上限的 %s",
		"specials": ["林荫：空闲时受到伤害 −20%", "林隐：空闲时 12 米外的敌人失去目标；威胁累积 −40%",
			"林之主：空闲判定缩短到 1 秒；空闲时打出的第一击伤害 +200% 并必定暴击"]},
	"fickle": {"name": "诡意", "region": "",
		"prefixes": [["fickle_w", "诡变的", "Shifting", "W"], ["fickle_a", "诡秘的", "Cryptic", "A"], ["fickle", "诡意的", "Fickle", "T"]],
		"values": [0.4, 0.6, 0.8, 1.0, 1.3],
		"number": "每层随机属性，数值 ×%s",
		"specials": ["诡变：每 60 秒换一次属性，换的瞬间回复 5% 生命", "诡秘：再多一种属性",
			"诡运：诡意属性 ×2；每次换属性后的 3 秒内，攻击必定暴击"]},
	"shadow": {"name": "疾影", "region": "",
		"prefixes": [["shadow_w", "疾影的", "Fleet", "W"], ["shadow_a", "掠影的", "Skimming", "A"], ["shadow_t", "轻影的", "Featherlight", "T"]],
		"values": [0.03, 0.06, 0.09, 0.12, 0.16],
		"number": "闪避冷却与闪避体力消耗 −%s",
		"specials": ["连影：4 秒内的第二次闪避不耗体力", "残影：闪避后原地留下残影，吸引附近敌人 1.5 秒",
			"影袭：残影消失时爆开，对 3 米内敌人造成 200% 攻击力的物理伤害"]},
	"rampart": {"name": "坚壁", "region": "",
		"prefixes": [["rampart_w", "坚壁的", "Ramparted", "W"], ["rampart_a", "城垣的", "Walled", "A"], ["rampart_t", "磐石的", "Bedrock", "T"]],
		"values": [0.015, 0.03, 0.05, 0.08, 0.11],
		"number": "受到伤害 −%s",
		"specials": ["磐石：单次超过 15% 生命上限的伤害，再减 30%", "城垣：每 15 秒自动抵挡一次伤害",
			"不动：抵挡伤害时，对 3 米内敌人反震 250% 防御值的物理伤害并眩晕 1 秒"]},
	"blood": {"name": "嗜血", "region": "",
		"prefixes": [["abyssal", "深海的", "Abyssal", "W"], ["blood_a", "潮涌的", "Surging", "A"], ["blood_t", "渊潮的", "Undertow", "T"]],
		"values": [0.006, 0.012, 0.02, 0.03, 0.04],
		"number": "吸血 %s",
		"specials": ["潮涌：吸血溢出的部分转为护盾，上限 10% 生命", "渊潮：击杀精英回复 15% 生命；生命低于 30% 时吸血翻倍",
			"深海之主：护盾满时，普攻附带护盾值 10% 的法术伤害"]},
	"hunter": {"name": "猎首", "region": "",
		"prefixes": [["knightly", "骑士的", "Knightly", "W"], ["hunter_a", "猎首的", "Headhunting", "A"], ["hunter_t", "悬赏的", "Bountied", "T"]],
		"values": [0.03, 0.06, 0.10, 0.15, 0.20],
		"number": "对精英伤害 %s",
		"specials": ["标记：命中精英时标记它，被标记的精英受到伤害 +8%", "悬赏：精英死亡时技能冷却清零，5 秒内攻速 +20",
			"处决：被标记的精英生命低于 15% 时直接击杀；Boss 改为受到 500% 攻击力的伤害"]},
	"rite": {"name": "术式", "region": "",
		"prefixes": [["rite_w", "符文的", "Runed", "W"], ["rite_a", "秘仪的", "Rite-Bound", "A"], ["rite_t", "法印的", "Sigiled", "T"]],
		"values": [0.03, 0.06, 0.10, 0.15, 0.20],
		"number": "技能伤害 %s",
		"specials": ["回响：释放技能后 3 秒内攻速 +20", "连咏：技能 25% 概率不进冷却", "大术式：每第 3 次技能自动再释放一次"]},
	"stealth": {"name": "潜伏", "region": "",
		"prefixes": [["stealthy", "潜伏的", "Stealthy", "W"], ["stealth_a", "隐匿的", "Hidden", "A"], ["stealth_t", "无声的", "Silent", "T"]],
		"values": [0.04, 0.08, 0.12, 0.18, 0.24],
		"number": "威胁累积 −%s；对没发现你的敌人伤害同样提高",
		"specials": ["预警：巡逻队到达前提示方向", "暗杀：对没发现你的敌人，第一击必定暴击", "无声：击杀没发现你的敌人时隐身 2 秒"]},
	"inhibit": {"name": "抑制", "region": "",
		"prefixes": [["inhibit_w", "净化的", "Purifying", "W"], ["inhibited", "抑制的", "Inhibited", "A"], ["inhibit_t", "隔离的", "Sealed", "T"]],
		"values": [0.05, 0.10, 0.15, 0.22, 0.30],
		"number": "污染累积 −%s；法抗 +%d",
		"specials": ["净化：污染造成的生命上限惩罚减半", "隔离：每进一层清除 10 点污染", "反噬：污染不再流失生命；每 10 点污染攻击力 +4%"]},
}
const ORDER: Array[String] = ["riot", "familial", "guerrilla", "forest", "fickle", "shadow", "rampart", "blood", "hunter", "rite", "stealth", "inhibit"]
## 抑制's 法抗 by the same five steps.
const INHIBIT_RES := [1.0, 2.0, 3.0, 5.0, 7.0]

## The family of prefix `id`, "" for any other prefix.
static func family_of(id: String) -> String:
	for fam in FAMILIES:
		for p in FAMILIES[fam].prefixes:
			if p[0] == id: return fam
	return ""

## Its number at 阶等 `tier` (0 below (1)).
static func value(fam: String, tier: int) -> float:
	var at := -1
	for i in range(VALUE_TIERS.size()):
		if tier >= VALUE_TIERS[i]: at = i
	return 0.0 if at < 0 else float(FAMILIES[fam].values[at])

static func value_index(tier: int) -> int:
	var at := -1
	for i in range(VALUE_TIERS.size()):
		if tier >= VALUE_TIERS[i]: at = i
	return at

## How many pieces carry each family, in paper-doll order of first sight.
static func count(equipped: Dictionary) -> Dictionary:
	var counts := {}
	for slot in Item.SLOTS:
		var item: Item = equipped.get(slot)
		if item == null: continue
		var seen := {}
		for entry in item.prefixes:
			var fam := family_of(str(entry.get("id", "")))
			if fam.is_empty() or seen.has(fam): continue
			seen[fam] = true
			counts[fam] = mini(MAX_TIER, int(counts.get(fam, 0)) + 1)
	return counts

## The families that work: the ACTIVE_MAX of highest 阶等, ties by first sight.
static func active(counts: Dictionary) -> Dictionary:
	var order: Array = counts.keys()
	var first := {}
	for i in range(order.size()): first[order[i]] = i
	order.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]) or (int(counts[a]) == int(counts[b]) and int(first[a]) < int(first[b])))
	var out := {}
	for fam in order.slice(0, ACTIVE_MAX): out[fam] = counts[fam]
	return out

## "暴动（2）".
static func label(fam: String, tier: int) -> String:
	return "%s（%d）" % [FAMILIES[fam].name, tier]

## The number's line at `tier`.
static func number_text(fam: String, tier: int) -> String:
	var v := value(fam, tier)
	if fam == "fickle": return FAMILIES[fam].number % ("%.1f" % v)
	if fam == "inhibit": return FAMILIES[fam].number % [ItemModifier.pct(v).trim_prefix("+"), roundi(INHIBIT_RES[maxi(0, value_index(tier))])]
	var shown := ItemModifier.pct(v)
	if FAMILIES[fam].number.contains("−%s"): shown = shown.trim_prefix("+")
	return FAMILIES[fam].number % shown

## Every line for `tier`: the number, then each special up to it; the next
## special not yet reached comes last with its 阶等, for the tooltip to grey.
static func lines(fam: String, tier: int) -> Array:
	var out: Array = [[number_text(fam, maxi(tier, 1)), true]]
	for i in range(SPECIAL_TIERS.size()):
		var at: int = SPECIAL_TIERS[i]
		if tier >= at: out.append(["（%d）%s" % [at, FAMILIES[fam].specials[i]], true])
		else:
			out.append(["（%d）%s" % [at, FAMILIES[fam].specials[i]], false])
			break
	return out

# --- Runtime --------------------------------------------------------------------

var player: Player
## Family → 阶等, only the ones that work.
var tiers := {}
## Every family worn, working or not.
var worn := {}
var timers := {}
var cooldowns := {}
var rage := 0
var mark: Enemy
var casts := 0
var _above_threshold := true
var _rampart_ready := true
var _decoys: Array[Dictionary] = []
var fickle_keys: Array = []
var _fickle_clock := 0.0
var _idle_strike_used := false

func _init(p_player: Player) -> void:
	player = p_player

func tier(fam: String) -> int:
	return int(tiers.get(fam, 0))

func has_special(fam: String, at: int) -> bool:
	return tier(fam) >= at

func refresh(equipped: Dictionary) -> void:
	worn = count(equipped)
	tiers = active(worn)
	if tier("fickle") > 0 and fickle_keys.size() != fickle_count(): reroll_fickle()
	elif tier("fickle") == 0: fickle_keys.clear()

func reset() -> void:
	timers.clear()
	cooldowns.clear()
	rage = 0
	mark = null
	casts = 0
	_above_threshold = true
	_rampart_ready = true
	_decoys.clear()
	_idle_strike_used = false

func on(name: String) -> bool:
	return float(timers.get(name, 0.0)) > 0.0

func _start(name: String, seconds: float) -> void:
	timers[name] = maxf(float(timers.get(name, 0.0)), seconds)

func _ready_cd(name: String) -> bool:
	return float(cooldowns.get(name, 0.0)) <= 0.0

# --- Sheet ----------------------------------------------------------------------

## Flat contributions to her sheet.
func static_sheet() -> Dictionary:
	var s := {}
	if tier("shadow") > 0:
		s["dash_cd_pct"] = -value("shadow", tier("shadow"))
		s["dash_cost_pct"] = -value("shadow", tier("shadow"))
	if tier("rampart") > 0: s["taken_pct"] = -value("rampart", tier("rampart"))
	if tier("blood") > 0: s["lifesteal"] = value("blood", tier("blood"))
	if tier("hunter") > 0: s["elite_pct"] = value("hunter", tier("hunter"))
	if tier("rite") > 0: s["skill_pct"] = value("rite", tier("rite"))
	if tier("stealth") > 0: s["pressure_pct"] = -value("stealth", tier("stealth"))
	if tier("inhibit") > 0:
		s["contam_pct"] = -value("inhibit", tier("inhibit"))
		s["res"] = INHIBIT_RES[value_index(tier("inhibit"))]
	for key in fickle_keys:
		s[key] = float(s.get(key, 0.0)) + float(PrefixCatalog.FICKLE[key]) * fickle_mult()
	return s

func fickle_count() -> int:
	var t := tier("fickle")
	if t <= 0: return 0
	return (2 if t >= 5 else 1) + (1 if t >= 6 else 0)

func fickle_mult() -> float:
	return value("fickle", tier("fickle")) * (2.0 if tier("fickle") >= 8 else 1.0)

## A new pick of 诡意 stats (each floor, and every 60 s from (4)).
func reroll_fickle() -> void:
	var keys: Array = PrefixCatalog.FICKLE.keys()
	keys.shuffle()
	fickle_keys = keys.slice(0, fickle_count())
	_fickle_clock = 0.0
	if tier("fickle") >= 8: _start("fickle_crit", 3.0)

# --- Hooks ----------------------------------------------------------------------

## Conditional 攻击力 +% (Player.power_bonus).
func atk_pct() -> float:
	var pct := 0.0
	if tier("riot") > 0:
		pct += value("riot", tier("riot")) * mini(8 if tier("riot") >= 6 else 5, player.nearby_enemy_count(6.0))
	if tier("familial") > 0 and player.hp_ratio() > threshold(): pct += value("familial", tier("familial"))
	if tier("guerrilla") > 0 and on("dodged"): pct += value("guerrilla", tier("guerrilla"))
	if tier("inhibit") >= 8: pct += 0.004 * player.contamination
	return pct

func aspd_bonus() -> float:
	var a := 0.0
	if tier("riot") >= 4 and on("rage"): a += 4.0 * rage
	if on("bounty"): a += 20.0
	if on("echo"): a += 20.0
	return a

func crit_bonus() -> float:
	return 0.12 if tier("familial") >= 6 and player.full_hp() else 0.0

func pierce() -> float:
	return 0.30 if tier("familial") >= 8 and player.hp_ratio() > threshold() else 0.0

func threshold() -> float:
	return 0.7 if tier("familial") >= 4 else 0.9

func idle_seconds() -> float:
	return 1.0 if tier("forest") >= 8 else 3.0

func idle() -> bool:
	return tier("forest") > 0 and player.combat_timer >= idle_seconds()

## Enemies beyond 12 m lose her (林隐), and nobody sees her for 2 s after 无声.
func concealed_from(distance: float) -> bool:
	if on("vanish"): return true
	return tier("forest") >= 6 and idle() and distance > 12.0

func threat_mult() -> float:
	return 0.6 if tier("forest") >= 6 and idle() else 1.0

func regen_per_second() -> float:
	return player.max_hp * value("forest", tier("forest")) if idle() else 0.0

## A forced crit for this basic hit or strike, spent here.
func take_forced_crit(target: Enemy) -> bool:
	if on("fickle_crit"): return true
	if tier("guerrilla") >= 4 and on("ambush"):
		timers.erase("ambush")
		return true
	if tier("forest") >= 8 and idle() and not _idle_strike_used:
		_idle_strike_used = true
		_start("idle_strike", 0.2)
		return true
	if tier("stealth") >= 6 and _unnoticed(target): return true
	return false

func _unnoticed(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and not enemy._dead and enemy.state != Enemy.State.CHASING

## Damage multiplier against `enemy` (Player.target_multiplier).
func damage_mult(enemy: Enemy) -> float:
	var m := 1.0
	if tier("stealth") > 0 and _unnoticed(enemy): m *= 1.0 + value("stealth", tier("stealth"))
	if tier("hunter") >= 4 and enemy == mark: m *= 1.08
	if on("idle_strike"): m *= 3.0
	return m

## Incoming damage after mitigation (Player.take_damage).
func incoming(amount: float) -> float:
	if tier("riot") >= 6 and player.nearby_enemy_count(6.0) >= 4: amount *= 0.85
	if tier("forest") >= 4 and idle(): amount *= 0.8
	if tier("rampart") >= 4 and amount > player.max_hp * 0.15: amount *= 0.7
	return amount

## 城垣: a block ready every 15 s.
func take_block() -> bool:
	if tier("rampart") < 6 or not _rampart_ready: return false
	_rampart_ready = false
	cooldowns["rampart"] = 15.0
	if tier("rampart") >= 8: _burst(player.global_position, 3.0, player.defense_value() * 2.5, "phys", false, 1.0)
	return true

## After she loses `amount` of life (家族's threshold).
func on_hurt(before_ratio: float) -> void:
	if tier("familial") < 4: return
	var line := threshold()
	if before_ratio >= line and player.hp_ratio() < line and _ready_cd("family"):
		cooldowns["family"] = 20.0
		player.shield = maxf(player.shield, player.max_hp * 0.10)
		if tier("familial") >= 8:
			_burst(player.global_position, 4.0, player.attack_power() * 3.0, "phys", true)

func on_dash(start: Vector3, end: Vector3, passed: Array) -> void:
	if tier("guerrilla") > 0: _start("dodged", 2.0)
	if tier("guerrilla") >= 4: _start("ambush", 4.0)
	if tier("guerrilla") >= 6 and not passed.is_empty(): player.stamina = minf(100.0, player.stamina + player.dash_cost() * 0.4)
	if tier("guerrilla") >= 8:
		for enemy in passed:
			if not is_instance_valid(enemy) or enemy._dead: continue
			player._deal(enemy, player.attack_power() * 1.5, "phys", false, 0.0, false)
			if is_instance_valid(enemy) and not enemy._dead: enemy.apply_status("slow", 2.0, 0.4)
	if tier("shadow") >= 6:
		_decoys.append({"pos": start, "time": 1.5})
		for enemy in _enemies_near(start, 8.0): enemy.decoy(start, 1.5)

## 连影: the second dodge within 4 s is free.
func free_dash() -> bool:
	if tier("shadow") < 4: return false
	if on("second_dash"):
		timers.erase("second_dash")
		return true
	_start("second_dash", 4.0)
	return false

func dash_cd_mult() -> float:
	return 0.8 if tier("guerrilla") >= 6 else 1.0

## Lifesteal spilling over full life becomes a shield (潮涌).
func on_lifesteal(amount: float, missing: float) -> void:
	if tier("blood") < 4 or amount <= missing: return
	player.shield = minf(player.max_hp * 0.10, maxf(player.shield, 0.0) + amount - missing)

func lifesteal_mult() -> float:
	return 2.0 if tier("blood") >= 6 and player.hp_ratio() < 0.3 else 1.0

## Extra hit riding a landed basic hit.
func on_basic_hit(target: Enemy) -> void:
	if not is_instance_valid(target) or target._dead: return
	if tier("hunter") >= 4 and target.elite: mark = target
	if tier("blood") >= 8 and player.shield >= player.max_hp * 0.10 - 0.5:
		player._deal(target, player.shield * 0.10, "arts", false, 0.0, false)
	if tier("riot") >= 8 and rage >= 5 and _ready_cd("riot_wave"):
		cooldowns["riot_wave"] = 0.5
		_burst(target.global_position, 3.0, player.attack_power() * 0.6, "phys")
	if tier("hunter") >= 8 and is_instance_valid(target) and not target._dead and target == mark and target.health < target.max_health * 0.15:
		if target.boss or target is Boss:
			if _ready_cd("execute"):
				cooldowns["execute"] = 10.0
				player._deal(target, player.attack_power() * 5.0, "phys", true, 0.0, false)
		else: target.take_hit(target.health + 1.0, "true")

func on_kill(enemy: Enemy) -> void:
	if tier("riot") >= 4:
		rage = mini(5, rage + 1) if on("rage") else 1
		_start("rage", 5.0)
	if tier("familial") >= 6: player.heal(player.max_hp * 0.03)
	if enemy.elite or enemy.boss:
		if tier("blood") >= 6: player.heal(player.max_hp * 0.15)
		if tier("hunter") >= 6:
			player.reset_skill_cooldown()
			_start("bounty", 5.0)
	if tier("stealth") >= 8 and enemy.state != Enemy.State.CHASING: _start("vanish", 2.0)

## A skill went off. Returns true when it should not cost its cooldown (连咏)
## and asks for a free recast every third (大术式) through `recast`.
func on_skill(recast: Callable) -> bool:
	if tier("rite") >= 4: _start("echo", 3.0)
	casts += 1
	if tier("rite") >= 8 and casts % 3 == 0: recast.call_deferred()
	return tier("rite") >= 6 and randf() < 0.25

## Contamination's life-cap cut (净化) and drain (反噬).
func contamination_cut_mult() -> float:
	return 0.5 if tier("inhibit") >= 4 else 1.0

func contamination_drains() -> bool:
	return tier("inhibit") < 8

func on_floor() -> void:
	_rampart_ready = true
	if tier("fickle") > 0: reroll_fickle()
	if tier("inhibit") >= 6 and is_instance_valid(player.game): player.game.cleanse_contamination(10.0)

func tick(delta: float) -> void:
	for name in timers.keys():
		timers[name] = float(timers[name]) - delta
		if float(timers[name]) <= 0.0:
			timers.erase(name)
			if name == "rage": rage = 0
	for name in cooldowns.keys():
		cooldowns[name] = float(cooldowns[name]) - delta
		if float(cooldowns[name]) <= 0.0:
			cooldowns.erase(name)
			if name == "rampart": _rampart_ready = true
	if player.combat_timer < idle_seconds(): _idle_strike_used = false
	if tier("fickle") >= 4:
		_fickle_clock += delta
		if _fickle_clock >= 60.0:
			reroll_fickle()
			player.heal(player.max_hp * 0.05)
			player._recompute_stats()
	for i in range(_decoys.size() - 1, -1, -1):
		_decoys[i].time = float(_decoys[i].time) - delta
		if float(_decoys[i].time) <= 0.0:
			if tier("shadow") >= 8: _burst(_decoys[i].pos, 3.0, player.attack_power() * 2.0, "phys")
			_decoys.remove_at(i)

# --- Helpers --------------------------------------------------------------------

func _enemies_near(at: Vector3, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	if not is_instance_valid(player.game): return out
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != player.game or enemy._dead: continue
		if Vector2(enemy.global_position.x - at.x, enemy.global_position.z - at.z).length() <= radius: out.append(enemy)
	return out

func _burst(at: Vector3, radius: float, damage: float, kind: String, push: bool = false, stun: float = 0.0) -> void:
	if not is_instance_valid(player.game): return
	CombatVfx.spawn(player.game, Vector3(at.x, player.game.ground_y(at) + 0.09, at.z), Vector3.FORWARD, "burst", 0, true)
	for enemy in _enemies_near(at, radius):
		player._deal(enemy, damage, kind, false, 0.0, false)
		if not is_instance_valid(enemy) or enemy._dead: continue
		if push:
			var away := enemy.global_position - at
			away.y = 0
			enemy.push(away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD, 1.5)
		if stun > 0.0: enemy.stun(stun)
