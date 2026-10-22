class_name OperatorProgress
extends RefCounted

## One operator's growth (精英化与加点策划案_v0_2.md): level and experience,
## elite stage, the four attributes and unspent points, skill-tree ranks, the
## active transmuter per group and the module level. Pure data and rules, kept
## by BaseState and saved with it; Player reads it for stats.

signal changed

var operator_id := Operators.LAPPLAND
var level := 1
var exp := 0
var elite := 0
var attributes := {}
var attribute_points := 0
var skill_points := 0
## node id -> rank
var ranks := {}
## transmuter group -> node id ("" for none)
var transmuters := {}
var module_level := 0

static func create(id: String) -> OperatorProgress:
	var p := OperatorProgress.new()
	p.operator_id = id
	p.attributes = Progression.start_attributes(id)
	for node_id in SkillTrees.tree(id):
		if str(SkillTrees.tree(id)[node_id].type) == "signature": p.ranks[node_id] = 1
	return p

func level_cap() -> int:
	return Progression.LEVEL_CAPS[elite]

func at_cap() -> bool:
	return level >= level_cap()

func exp_needed() -> int:
	return Progression.exp_to_next(elite, level)

func attribute(key: String) -> int:
	return int(attributes.get(key, 0))

func rank(node_id: String) -> int:
	return int(ranks.get(node_id, 0))

## Adds experience, levelling up as far as it reaches; what is past the cap is
## lost (§4.2). Returns the levels gained.
func add_exp(amount: int) -> int:
	if amount <= 0 or at_cap(): return 0
	var gained := 0
	exp += amount
	while not at_cap() and exp >= exp_needed():
		exp -= exp_needed()
		level += 1
		# 复利数值改造清单 J: a skill point every level, an attribute point every second.
		if level % Progression.ATTRIBUTE_EVERY == 0: attribute_points += 1
		skill_points += 1
		gained += 1
	if at_cap(): exp = 0
	changed.emit()
	return gained

## How much of `amount` experience she can still take this stage.
func exp_room() -> int:
	if at_cap(): return 0
	var room := exp_needed() - exp
	for l in range(level + 1, level_cap()): room += Progression.exp_to_next(elite, l)
	return room

# --- Attributes ---------------------------------------------------------------

func add_attribute(key: String) -> bool:
	if attribute_points <= 0 or not key in Progression.ATTRIBUTES: return false
	attributes[key] = attribute(key) + 1
	attribute_points -= 1
	changed.emit()
	return true

func attribute_sheet() -> Dictionary:
	return Progression.attribute_sheet(attributes, Progression.start_attributes(operator_id))

# --- Promotion ----------------------------------------------------------------

## "" when promotion is possible apart from paying; the reason otherwise.
func promotion_block() -> String:
	if elite >= 2: return "已精英 2"
	if not at_cap(): return "需要等级 %d" % level_cap()
	return ""

func promotion_cost() -> Dictionary:
	return Progression.PROMOTION[mini(elite + 1, 2)] if elite < 2 else {}

func promote() -> void:
	elite += 1
	level = 1
	exp = 0
	attribute_points += Progression.PROMOTION_ATTRIBUTE_POINTS
	skill_points += Progression.PROMOTION_SKILL_POINTS
	changed.emit()

# --- Skill tree ---------------------------------------------------------------

## "" when the next rank of `node_id` may be bought (points and materials
## aside from the materials check, which the caller makes); the reason otherwise.
func rank_block(node_id: String) -> String:
	var data := SkillTrees.node(operator_id, node_id)
	if data.is_empty(): return "无"
	var r := rank(node_id)
	if r >= SkillTrees.max_rank(data): return "已满"
	if data.has("parent") and rank(str(data.parent)) <= 0: return "需要" + str(SkillTrees.node(operator_id, data.parent).name)
	var need := SkillTrees.rank_elite(data, r)
	if elite < need: return "需要" + Progression.ELITE_NAMES[need]
	if skill_points < SkillTrees.rank_cost(data, r): return "技能点不足"
	return ""

func add_rank(node_id: String) -> bool:
	if not rank_block(node_id).is_empty(): return false
	var data := SkillTrees.node(operator_id, node_id)
	skill_points -= SkillTrees.rank_cost(data, rank(node_id))
	ranks[node_id] = rank(node_id) + 1
	if str(data.type) == "transmuter" and str(transmuters.get(data.group, "")).is_empty():
		transmuters[data.group] = node_id
	changed.emit()
	return true

## The transmuter switched on in `group` (bought ones switch freely).
func set_transmuter(group: String, node_id: String) -> bool:
	if node_id.is_empty():
		transmuters[group] = ""
		changed.emit()
		return true
	var data := SkillTrees.node(operator_id, node_id)
	if data.is_empty() or str(data.get("group", "")) != group or rank(node_id) <= 0: return false
	transmuters[group] = node_id
	changed.emit()
	return true

func transmuter(group: String) -> String:
	return str(transmuters.get(group, ""))

## Points a full reset gives back: every point spent, 专精 included. What
## 专精 cost in materials is not returned (§10).
func refundable_points() -> int:
	var total := 0
	for node_id in ranks:
		var data := SkillTrees.node(operator_id, node_id)
		if not data.is_empty(): total += SkillTrees.spent(data, rank(node_id))
	return total

## Back to a fresh tree: signatures at rank 1, nothing else, no transmuter.
func reset_skills() -> int:
	var refund := refundable_points()
	ranks.clear()
	for node_id in SkillTrees.tree(operator_id):
		if str(SkillTrees.tree(operator_id)[node_id].type) == "signature": ranks[node_id] = 1
	transmuters.clear()
	skill_points += refund
	changed.emit()
	return refund

# --- Module -------------------------------------------------------------------

func module_block() -> String:
	if elite < 2: return "需要精英 2"
	if module_level >= 3: return "已满"
	return ""

func upgrade_module() -> void:
	module_level = mini(3, module_level + 1)
	changed.emit()

# --- Save ---------------------------------------------------------------------

func to_data() -> Dictionary:
	return {"level": level, "exp": exp, "elite": elite, "attributes": attributes.duplicate(), "attribute_points": attribute_points,
		"skill_points": skill_points, "ranks": ranks.duplicate(), "transmuters": transmuters.duplicate(), "module": module_level, "scale": 2}

static func from_data(id: String, data: Dictionary) -> OperatorProgress:
	var p := create(id)
	p.elite = clampi(int(data.get("elite", 0)), 0, 2)
	p.level = clampi(int(data.get("level", 1)), 1, p.level_cap())
	p.exp = maxi(0, int(data.get("exp", 0)))
	var attrs: Dictionary = data.get("attributes", {})
	for key in Progression.ATTRIBUTES:
		p.attributes[key] = maxi(int(p.attributes[key]), int(attrs.get(key, p.attributes[key])))
	p.attribute_points = maxi(0, int(data.get("attribute_points", 0)))
	p.skill_points = maxi(0, int(data.get("skill_points", 0)))
	var old := int(data.get("scale", 1)) < 2
	var saved_ranks: Dictionary = data.get("ranks", {})
	for node_id in saved_ranks:
		var node_data := SkillTrees.node(id, str(node_id))
		if node_data.is_empty(): continue
		var r := int(saved_ranks[node_id])
		if old: r = SkillTrees.fine_rank(node_data, r)
		p.ranks[str(node_id)] = clampi(r, 0, SkillTrees.max_rank(node_data))
	var saved_tx: Dictionary = data.get("transmuters", {})
	for group in saved_tx: p.transmuters[str(group)] = str(saved_tx[group])
	p.module_level = clampi(int(data.get("module", 0)), 0, 3)
	if old: p._migrate_levels(int(data.get("level", 1)))
	return p

## A save from before 60 / 80 / 90 (复利数值改造清单 J): the level at the same
## share of its stage; points recounted under the new rules — the attributes
## she raised keep their share, the rest come back unspent.
func _migrate_levels(old_level: int) -> void:
	var old_cap := int(Progression.OLD_LEVEL_CAPS[elite])
	level = clampi(roundi(1.0 + float(old_level - 1) * float(level_cap() - 1) / float(old_cap - 1)), 1, level_cap())
	exp = 0
	var start := Progression.start_attributes(operator_id)
	var old_extra := 0
	for key in Progression.ATTRIBUTES: old_extra += maxi(0, attribute(key) - int(start[key]))
	var old_total := old_extra + attribute_points
	var new_total := Progression.level_attribute_points(elite, level) + elite * Progression.PROMOTION_ATTRIBUTE_POINTS
	var ratio := float(new_total) / float(maxi(1, old_total))
	var raised := 0
	for key in Progression.ATTRIBUTES:
		var extra := mini(roundi(maxi(0, attribute(key) - int(start[key])) * ratio), new_total - raised)
		attributes[key] = int(start[key]) + extra
		raised += extra
	attribute_points = maxi(0, new_total - raised)
	var spent := 0
	for node_id in ranks:
		var node_data := SkillTrees.node(operator_id, node_id)
		if not node_data.is_empty(): spent += SkillTrees.spent(node_data, rank(node_id))
	skill_points = maxi(0, Progression.level_skill_points(elite, level) + elite * Progression.PROMOTION_SKILL_POINTS - spent)
