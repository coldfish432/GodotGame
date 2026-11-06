class_name RouteMap
extends RefCounted

## 肉鸽路线图 (肉鸽路线图策划案 v0.2, 用户 2026-10-24): each block of ten floors
## is one branching map, rolled whole when the block is entered (a contract's
## start or a camp) and shown a column at a time. Column c of block b is floor
## b × 10 + c + 1. A map is a plain Dictionary so RunSave writes it as it is:
##   block       the block (0 for floors 1–10)
##   cols        per column, its nodes {kind, exit, mark, event, faction}
##   edges       per column, per node, the rows of the next column it leads to
##   exit_col    the column with the random extraction (floors 4–6)

## The node kinds (§4.1). danger: the hidden difficulty's modifier; reward:
## the drop bonus; enemies: added to the floor's 9 ordinary enemies; mult:
## times the floor's count; elites: more elites; deep: the 深部 modifiers
## (contamination, cold, guarded boxes); compact: the boss-sized map; combat:
## a fight floor (the fuzzy column's "未知作战"); calm: the threat meter rests;
## stat: the floor's enemies' life and attack (用户 2026-10-24: 掉落加成改为
## +5%/+15%，敌人更多，数值更高×1.25/×1.6).
const KINDS := {
	"entry": {"name": "外勤入口", "en": "ENTRY", "color": Color("dfe4e6"), "danger": -3.0, "reward": 0.0, "enemies": 0, "combat": true},
	"patrol": {"name": "巡检支路", "en": "PATROL ROUTE", "color": Color("dfe4e6"), "danger": -3.0, "reward": 0.0, "enemies": 0, "combat": true},
	"supply": {"name": "物资作业", "en": "SUPPLY FACE", "color": Color("f5c000"), "danger": 0.0, "reward": 0.05, "enemies": 3, "stat": 1.25, "combat": true},
	"deep": {"name": "深部污染", "en": "DEEP ZONE", "color": Color("ff4d4d"), "danger": 5.0, "reward": 0.15, "enemies": 6, "stat": 1.6, "deep": true, "combat": true},
	"event": {"name": "不期而遇", "en": "ENCOUNTER", "color": Color("9aa0a6"), "danger": 4.0, "reward": 0.0, "enemies": 3, "mult": 1.3, "elites": 1, "compact": true},
	"trader": {"name": "诡异行商", "en": "WANDERING TRADER", "color": Color("e6c25a"), "danger": -3.0, "reward": 0.0, "enemies": 0, "mult": 0.5, "compact": true, "no_device": true},
	"rest": {"name": "临时休整", "en": "SAFE HOUSE", "color": Color("5fd0d8"), "danger": 0.0, "reward": 0.0, "enemies": 0, "mult": 0.0, "compact": true, "calm": true, "no_device": true},
	"relic": {"name": "得偿所愿", "en": "WISH FULFILLED", "color": Color("c48cff"), "danger": 2.0, "reward": 0.0, "enemies": 3, "pois": 2},
	"elite": {"name": "险路恶敌", "en": "DIRE FOE", "color": Color("b8242c"), "danger": 3.0, "reward": 0.25, "enemies": 3, "combat": true},
	"vault": {"name": "暗墙密室", "en": "HIDDEN VAULT", "color": Color("b8902c"), "danger": 0.0, "reward": 0.05, "enemies": 3, "stat": 1.25, "combat": true},
	"fate": {"name": "命运所指", "en": "FATE'S CALL", "color": Color("e0782a"), "danger": 0.0, "reward": 0.05, "enemies": 3, "stat": 1.25, "combat": true},
	"post": {"name": "势力据点", "en": "FACTION POST", "color": Color("8fc31f"), "danger": 0.0, "reward": 0.05, "enemies": 3, "stat": 1.25, "combat": true},
	"outpost": {"name": "前哨据点", "en": "OUTPOST", "color": Color("dfe4e6"), "danger": 0.0, "reward": 0.05, "enemies": 3, "combat": true},
	# The camp between blocks (用户 2026-10-31: 营地层也要有地图): a small calm map
	# with 可露希尔, the fixed extraction and the way on. Never rolled on a block.
	"camp": {"name": "营地", "en": "CAMP", "color": Color("63eca7"), "danger": 0.0, "reward": 0.0, "enemies": 0, "mult": 0.0, "compact": true, "calm": true, "no_device": true},
	"boss": {"name": "首领战场", "en": "BOSS ARENA", "color": Color("ff4d4d"), "danger": 0.0, "reward": 0.05, "enemies": 3, "combat": true},
}
const COMBAT_KINDS := ["patrol", "supply", "deep"]
const COMBAT_WEIGHTS := [30.0, 45.0, 25.0]
## Per kind: the floors in a block it may stand on (1–10) and how many a block holds.
const PLACES := {"event": Vector2i(2, 9), "trader": Vector2i(3, 9), "rest": Vector2i(5, 9), "relic": Vector2i(4, 9),
	"elite": Vector2i(4, 9), "vault": Vector2i(3, 9), "fate": Vector2i(3, 9), "post": Vector2i(2, 9)}
const CAPS := {"event": 3, "trader": 1, "rest": 1, "relic": 1, "elite": 2, "vault": 1, "fate": 1, "post": 1}
const MIN_EVENTS := 1
## Weights of a free spot by the floor's band (§4.2): 2–4, 5–7, 8–9. In the
## first band 诡异行商 only on 3–4, 得偿所愿 and 险路恶敌 only on 4.
const BAND_WEIGHTS := {
	"event": [14.0, 14.0, 10.0], "trader": [6.0, 8.0, 6.0], "rest": [0.0, 6.0, 10.0], "relic": [4.0, 6.0, 6.0],
	"elite": [4.0, 8.0, 10.0], "vault": [5.0, 5.0, 5.0], "fate": [5.0, 5.0, 5.0], "post": [6.0, 6.0, 4.0], "combat": [56.0, 42.0, 44.0],
}
## The ones that never stand next to each other along a line.
const SERVICES := ["trader", "rest", "relic"]
## Fight floors every way through the block holds at least.
const MIN_FIGHTS := 4
## Columns 2–9 hold 2, 3 or 4 nodes.
const WIDTH_WEIGHTS := [25.0, 50.0, 25.0]
## A node leads on along 1 line (60%) or 2.
const SECOND_LINE := 0.4
## 用户 2026-10-24: 撤离节点上一列连入降到 1/2.
const EXIT_SHARE := 0.5
## Columns seen clearly ahead, and one more fuzzy after them (§3.3).
const SIGHT := 1

static func info(kind: String) -> Dictionary:
	return KINDS.get(kind, KINDS.supply)

static func kind_name(kind: String) -> String:
	return str(info(kind).name)

static func is_fight(kind: String) -> bool:
	return bool(info(kind).get("combat", false))

static func block_of(floor_number: int) -> int:
	return (floor_number - 1) / FieldCatalog.CAMP_INTERVAL

static func floor_of(block: int, col: int) -> int:
	return block * FieldCatalog.CAMP_INTERVAL + col + 1

static func col_of(floor_number: int) -> int:
	return (floor_number - 1) % FieldCatalog.CAMP_INTERVAL

# --- Rolling a block ------------------------------------------------------------------------

## The map of `block`. `ctx`:
##   region, seed          the region and the run's seed
##   first_exit            the first extraction ever: floor 5, its only node
##   extract_all           课题 撤离保障: every node before it leads to it
##   trader_col            课题 商队联络: a 诡异行商 on floor 3
##   mult                  kind -> weight multiplier (科研)
##   fate_ok, post_ok      a sought operator / a faction post in the region
##   posts                 the factions a 势力据点 may belong to
##   ensure_post           a faction that gets a post on every block ("" none)
##   bounty, search, deliver  the contract's marks: floor / true / [floor, faction]
##   plain                 tests: fight floors only (besides the marks)
static func roll(block: int, ctx: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ctx.get("seed", 0)) + block * 104729
	var columns := FieldCatalog.CAMP_INTERVAL
	var first_exit: bool = block == 0 and bool(ctx.get("first_exit", false))
	var exit_col := 4 if first_exit else 3 + rng.randi() % 3
	var widths: Array[int] = []
	for c in range(columns):
		if c == 0: widths.append(1 if block == 0 else rng.randi_range(2, 3))
		elif c == columns - 1: widths.append(1)
		elif c == exit_col: widths.append(1 if first_exit else rng.randi_range(1, 2))
		else: widths.append(2 + _pick(WIDTH_WEIGHTS, rng))
	var exit_row := rng.randi() % widths[exit_col]
	var edges: Array = []
	for c in range(columns - 1):
		if c + 1 == exit_col: edges.append(_exit_lines(widths[c], widths[c + 1], exit_row, bool(ctx.get("extract_all", false)), rng))
		else: edges.append(_lines(widths[c], widths[c + 1], rng))
	edges.append([[]])
	var cols: Array = []
	for c in range(columns):
		var col: Array = []
		for r in range(widths[c]): col.append({"kind": "", "exit": false, "mark": "", "event": "", "faction": ""})
		cols.append(col)
	cols[exit_col][exit_row].exit = true
	var map := {"block": block, "cols": cols, "edges": edges, "exit_col": exit_col}
	_fill(map, ctx, rng)
	return map

## Lines between a column of `n` and one of `m` nodes: a monotone walk from the
## top pair to the bottom pair (so none cross and every node has one), then a
## second line from some nodes where it crosses nothing.
static func _lines(n: int, m: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in range(n): out.append([])
	var cap := maxi(2, ceili(float(m) / n))
	var i := 0
	var j := 0
	out[0].append(0)
	while i < n - 1 or j < m - 1:
		var moves: Array[int] = []   # 0: both, 1: next upper node, 2: next lower node
		if i < n - 1 and j < m - 1: moves.append_array([0, 0])
		if i < n - 1: moves.append(1)
		if j < m - 1 and (out[i].size() < cap or i == n - 1): moves.append(2)
		var move: int = moves[rng.randi() % moves.size()]
		if move != 2: i += 1
		if move != 1: j += 1
		if not out[i].has(j): out[i].append(j)
	for k in range(n):
		if out[k].size() != 1 or rng.randf() >= SECOND_LINE: continue
		var to: int = out[k][0] + (1 if rng.randf() < 0.5 else -1)
		if to < 0 or to >= m or not _uncrossed(out, k, to): continue
		out[k].append(to)
		out[k].sort()
	return out

## Into the extraction's column: at least EXIT_SHARE of the column before leads
## to its node (all of it with 撤离保障), the rest to the other node.
static func _exit_lines(n: int, m: int, exit_row: int, all_in: bool, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in range(n): out.append([])
	if m == 1:
		for i in range(n): out[i].append(0)
		return out
	var into := n if all_in else maxi(1, ceili(n * EXIT_SHARE))
	# The `into` nodes on the exit's side (top if it is the upper node, else bottom)
	# lead to it; the rest to the other node.
	for i in range(n):
		var to_exit := i < into if exit_row == 0 else i >= n - into
		var other := 1 - exit_row
		if to_exit: out[i].append(exit_row)
		else: out[i].append(other)
	# The other node needs a line: the nearest one to it leads there as well.
	var other_row := 1 - exit_row
	if not out.any(func(row): return row.has(other_row)):
		var k := n - 1 if other_row == 1 else 0
		out[k].append(other_row)
	# Now and then the boundary node leads to both.
	for k in range(n):
		if out[k].size() == 1 and rng.randf() < SECOND_LINE and _uncrossed(out, k, 1 - int(out[k][0])):
			out[k].append(1 - int(out[k][0]))
		out[k].sort()
	return out

## Whether a line k -> to crosses none of `out`'s.
static func _uncrossed(out: Array, k: int, to: int) -> bool:
	for a in range(out.size()):
		for b in out[a]:
			if (a < k and int(b) > to) or (a > k and int(b) < to): return false
	return true

static func _pick(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights: total += float(w)
	if total <= 0.0: return 0
	var roll := rng.randf() * total
	for i in range(weights.size()):
		roll -= float(weights[i])
		if roll <= 0.0 and float(weights[i]) > 0.0: return i
	return weights.size() - 1

## Kinds onto the nodes: the ends and the marks first, then the free spots by
## weight, then the rules (§4.2) mended.
static func _fill(map: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var cols: Array = map.cols
	var block := int(map.block)
	var last := cols.size() - 1
	var final_floor := floor_of(block, last)
	cols[last][0].kind = "boss" if BossCatalog.is_boss_floor(final_floor) else "outpost"
	if block == 0: cols[0][0].kind = "entry"
	var counts := {}
	# The contract's marks and the research guarantees.
	var bounty := int(ctx.get("bounty", 0))
	if bounty > 0 and block_of(bounty) == block and col_of(bounty) < last:
		_place(map, col_of(bounty), "elite", "bounty", counts, rng)
	var deliver: Array = ctx.get("deliver", [])
	if not deliver.is_empty() and block_of(int(deliver[0])) == block and col_of(int(deliver[0])) < last:
		var node := _place(map, col_of(int(deliver[0])), "post", "deliver", counts, rng)
		if not node.is_empty(): node.faction = str(deliver[1])
	# 残党联络人 (势力声望解锁策划案 §三): one of 整合运动残党's posts on every block.
	if not str(ctx.get("ensure_post", "")).is_empty():
		for attempt in range(last * 2):
			var post := _place(map, rng.randi_range(1, last - 1), "post", "", counts, rng)
			if not post.is_empty():
				post.faction = str(ctx.ensure_post)
				break
	if bool(ctx.get("search", false)):
		var tries := [2, 3, 4, 5, 6, 7]
		tries.shuffle()
		for c in tries:
			if not _place(map, c, "vault", "search", counts, rng).is_empty(): break
	if bool(ctx.get("trader_col", false)): _place(map, 2, "trader", "", counts, rng)
	var mult: Dictionary = ctx.get("mult", {})
	var plain := bool(ctx.get("plain", false))
	for c in range(last):
		for r in range(cols[c].size()):
			var node: Dictionary = cols[c][r]
			if not str(node.kind).is_empty(): continue
			node.kind = _combat(c, rng) if plain or c == 0 else _free_kind(map, c, r, ctx, counts, mult, rng)
			counts[node.kind] = int(counts.get(node.kind, 0)) + 1
	if not plain: _mend(map, ctx, counts, rng)
	var events: Array = RouteEvents.pool(str(ctx.get("region", "")))
	for c in range(last):
		for node in cols[c]:
			if node.kind == "event" and not events.is_empty(): node.event = str(events.pop_at(rng.randi() % events.size()))
			if node.kind == "post" and str(node.faction).is_empty():
				var posts: Array = ctx.get("posts", [])
				if not posts.is_empty(): node.faction = str(posts[rng.randi() % posts.size()])

## A mark's node on column `c`: not the extraction's (unless that is all there is).
static func _place(map: Dictionary, c: int, kind: String, mark: String, counts: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var col: Array = map.cols[c]
	var free := range(col.size()).filter(func(r): return str(col[r].kind).is_empty() and not col[r].exit)
	if free.is_empty(): free = range(col.size()).filter(func(r): return str(col[r].kind).is_empty())
	if free.is_empty(): return {}
	var node: Dictionary = col[free[rng.randi() % free.size()]]
	node.kind = kind
	node.mark = mark
	counts[kind] = int(counts.get(kind, 0)) + 1
	return node

static func _combat(c: int, rng: RandomNumberGenerator) -> String:
	var weights := COMBAT_WEIGHTS.duplicate()
	if c <= 1: weights[2] = 0.0   # no 深部 on floor 2 (nor the first floor out of a camp)
	return COMBAT_KINDS[_pick(weights, rng)]

static func _free_kind(map: Dictionary, c: int, r: int, ctx: Dictionary, counts: Dictionary, mult: Dictionary, rng: RandomNumberGenerator) -> String:
	var place := c + 1
	var band := 0 if place <= 4 else (1 if place <= 7 else 2)
	var col: Array = map.cols[c]
	var exit: bool = col[r].exit
	var kinds: Array[String] = []
	var weights: Array[float] = []
	for kind in CAPS:
		var w := float(BAND_WEIGHTS[kind][band]) * float(mult.get(kind, 1.0))
		if w <= 0.0 or exit: continue
		var places: Vector2i = PLACES[kind]
		if place < places.x or place > places.y: continue
		if band == 0 and kind == "trader" and place < 3: continue
		if band == 0 and kind in ["relic", "elite"] and place != 4: continue
		if int(counts.get(kind, 0)) >= int(CAPS[kind]): continue
		if kind == "fate" and not bool(ctx.get("fate_ok", false)): continue
		if kind == "post" and not bool(ctx.get("post_ok", false)): continue
		if col.any(func(n): return n.kind == kind): continue
		if kind in SERVICES and _service_before(map, c, r): continue
		kinds.append(kind)
		weights.append(w)
	kinds.append("combat")
	weights.append(float(BAND_WEIGHTS.combat[band]))
	var pick := kinds[_pick(weights, rng)]
	return _combat(c, rng) if pick == "combat" else pick

## Whether a node of the column before that leads here is one of SERVICES.
static func _service_before(map: Dictionary, c: int, r: int) -> bool:
	if c == 0: return false
	var before: Array = map.cols[c - 1]
	for k in range(before.size()):
		if (map.edges[c - 1][k] as Array).has(r) and str(before[k].kind) in SERVICES: return true
	return false

## The rules the weights alone do not keep: at least MIN_EVENTS 不期而遇, a fight
## on floor 9, and MIN_FIGHTS fight floors every way through.
static func _mend(map: Dictionary, ctx: Dictionary, counts: Dictionary, rng: RandomNumberGenerator) -> void:
	var cols: Array = map.cols
	var last := cols.size() - 1
	if not cols[last - 1].any(func(n): return is_fight(n.kind)):
		var node: Dictionary = cols[last - 1][rng.randi() % cols[last - 1].size()]
		node.kind = _combat(last - 1, rng)
		node.mark = ""
	for attempt in range(12):
		var path := fewest_fights(map)
		if path.size() == 0 or _fights_on(map, path) >= MIN_FIGHTS: break
		var turnable: Array = []
		for step: Vector2i in path:
			var node: Dictionary = cols[step.x][step.y]
			if not is_fight(node.kind) and node.mark.is_empty(): turnable.append(node)
		if turnable.is_empty(): break
		turnable[rng.randi() % turnable.size()].kind = "supply"
	# At least one 不期而遇, on a spot that keeps every way's fights.
	counts["event"] = 0
	for col in cols:
		for node in col:
			if node.kind == "event": counts["event"] += 1
	if int(counts.event) < MIN_EVENTS:
		var spots: Array = []
		for c in range(1, last):
			for r in range(cols[c].size()):
				var node: Dictionary = cols[c][r]
				if node.kind in COMBAT_KINDS and not node.exit and node.mark.is_empty() and not cols[c].any(func(n): return n.kind == "event"): spots.append(node)
		while not spots.is_empty():
			var node: Dictionary = spots.pop_at(rng.randi() % spots.size())
			var was: String = node.kind
			node.kind = "event"
			if _fights_on(map, fewest_fights(map)) >= MIN_FIGHTS:
				counts["event"] = int(counts.get("event", 0)) + 1
				break
			node.kind = was

## The way through with the fewest fight floors, as (column, row) steps.
static func fewest_fights(map: Dictionary) -> Array[Vector2i]:
	var cols: Array = map.cols
	var best := {}   # Vector2i -> [count, previous]
	for r in range(cols[0].size()):
		best[Vector2i(0, r)] = [1 if is_fight(cols[0][r].kind) else 0, Vector2i(-1, -1)]
	for c in range(cols.size() - 1):
		for r in range(cols[c].size()):
			var here: Array = best.get(Vector2i(c, r), [])
			if here.is_empty(): continue
			for to in map.edges[c][r]:
				var at := Vector2i(c + 1, int(to))
				var count: int = int(here[0]) + (1 if is_fight(cols[c + 1][int(to)].kind) else 0)
				if not best.has(at) or int(best[at][0]) > count: best[at] = [count, Vector2i(c, r)]
	var out: Array[Vector2i] = []
	var at := Vector2i(cols.size() - 1, 0)
	while best.has(at):
		out.push_front(at)
		at = best[at][1]
	return out

static func _fights_on(map: Dictionary, path: Array[Vector2i]) -> int:
	return path.filter(func(step): return is_fight(map.cols[step.x][step.y].kind)).size()

# --- Reading a map ---------------------------------------------------------------------------

static func node_at(map: Dictionary, at: Vector2i) -> Dictionary:
	if map.is_empty() or at.x < 0 or at.x >= (map.cols as Array).size(): return {}
	var col: Array = map.cols[at.x]
	return col[at.y] if at.y >= 0 and at.y < col.size() else {}

## The rows of the next column that `at` leads to; from before the block (a
## camp, x = -1) every node of the first column.
static func next_rows(map: Dictionary, at: Vector2i) -> Array:
	if map.is_empty(): return []
	if at.x < 0: return range((map.cols[0] as Array).size())
	if at.x >= (map.cols as Array).size() - 1: return []
	return (map.edges[at.x][at.y] as Array).duplicate()

## How column `c` shows from column `here` with `clear` columns of sight:
## "seen" (walked or current), "clear", "fuzzy" or "dark".
static func sight(c: int, here: int, clear: int) -> String:
	if c <= here: return "seen"
	if c - here <= clear: return "clear"
	return "fuzzy" if c - here == clear + 1 else "dark"
