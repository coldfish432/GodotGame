class_name BossCatalog
extends RefCounted

## Region bosses and wardens (Boss与守卫者策划案_v1_0.md, 用户 2026-10-19).
## Floors 20, 40, 60… hold the region's boss, the same one every time, with
## more moves the deeper it is; floors 10, 30, 50… a warden, an upgraded elite.
## All numbers here are initial tuning, like FieldCatalog. The rules are in
## entities/boss.gd.

const BOSS_EVERY := 20
const BOSSES := {"mine": "patriot", "city": "rat_king", "snow": "eikthyrnir", "siracusa": "zaro"}
const WARDENS := {"mine": "crownslayer", "city": "skullshatterer", "snow": "hollow_snowpriest", "siracusa": "father_agnir"}

# --- The fight (§3.2–§3.5) -------------------------------------------------------

## The ground it holds round the route markers; a boss never leaves it. On a
## boss floor it is the arena room itself (Boss战场地策划案 §3.1).
const ARENA_RADIUS := 13.0
## Out of a boss's arena this long, she has left: it goes home, whole again.
const LEASH_SECONDS := 8.0
## No ordinary hit takes more than HIT_CAP of her life; a big move (two seconds
## of warning and a safe place) no more than BIG_CAP.
const HIT_CAP := 0.30
const BIG_CAP := 0.60
## A phase change: it roars this long, untouchable, and shoves her out of ROAR_RADIUS.
const ROAR_TIME := 1.5
const ROAR_RADIUS := 3.0
const ROAR_PUSH := 2.5
## 爱国者 kneels, 扎罗 lies down: this long, untouchable, before it gets up.
const DOWN_TIME := 2.0
## The soft enrage: past ENRAGE_AFTER s, every ENRAGE_EVERY s, ENRAGE_STEP
## more attack speed, up to ENRAGE_CAP.
const ENRAGE_AFTER := 180.0
const ENRAGE_EVERY := 30.0
const ENRAGE_STEP := 0.10
const ENRAGE_CAP := 0.50
## Called-in help (tier 4 on): at these shares of its life, never more than SUMMON_CAP alive.
const SUMMON_AT := [0.66, 0.33]
const SUMMON_CAP := 4
## A warden's last stand below this share: attack speed +LAST_STAND_ASPD.
const LAST_STAND_AT := 0.30
const LAST_STAND_ASPD := 0.20
## Big moves' safe circles, and the ground a summon comes in from.
const SAFE_RADIUS := 2.2
const EDGE_GAP := 2.0

# --- Tiers (§3.1, §3.3) ---------------------------------------------------------------

static func is_boss_floor(floor_number: int) -> bool:
	return floor_number > 0 and floor_number % BOSS_EVERY == 0

## 20 → 1, 40 → 2 …
static func boss_tier(floor_number: int) -> int:
	return maxi(1, floor_number / BOSS_EVERY)

## 10 → 1, 30 → 2, 50 → 3 …
static func warden_tier(floor_number: int) -> int:
	return maxi(1, (floor_number + 10) / BOSS_EVERY)

## [hp per tier, atk per tier, windup factor per tier, windup floor]
const TIER_CURVE := {"boss": [0.20, 0.05, 0.96, 0.80], "warden": [0.15, 0.04, 0.97, 0.85]}

static func hp_mult(rank: String, tier: int) -> float:
	return 1.0 + float(TIER_CURVE[rank][0]) * (tier - 1)

static func atk_mult(rank: String, tier: int) -> float:
	return 1.0 + float(TIER_CURVE[rank][1]) * (tier - 1)

static func windup_mult(rank: String, tier: int) -> float:
	return maxf(float(TIER_CURVE[rank][3]), pow(float(TIER_CURVE[rank][2]), tier - 1))

## Life shares where the next phase starts (§3.4): 50% at the first tier,
## 60% from the second, and a third phase at 25% from the third.
static func phase_marks(tier: int) -> Array:
	var out := [0.5 if tier <= 1 else 0.6]
	if tier >= 3: out.append(0.25)
	return out

# --- Rewards (§10) ---------------------------------------------------------------------

## A boss's own gear (9 pieces each, 用户 2026-10-19): this chance at tier 1,
## EXCLUSIVE_STEP more each tier, never above EXCLUSIVE_MAX.
const EXCLUSIVE_BASE := 0.25
const EXCLUSIVE_STEP := 0.05
const EXCLUSIVE_MAX := 0.50
const WARDEN_EXCLUSIVE := 0.10
const WARDEN_SET := 0.03
const BOSS_CHESTS := 2
## Experience: [base, per tier] (Progression.KILL_EXP's kinds).
const EXP := {"boss": [300, 100], "warden": [150, 30]}

static func exclusive_chance(tier: int) -> float:
	return minf(EXCLUSIVE_MAX, EXCLUSIVE_BASE + EXCLUSIVE_STEP * (tier - 1))

static func kill_exp(rank: String, tier: int) -> int:
	return int(EXP[rank][0]) + int(EXP[rank][1]) * (tier - 1)

# --- Warden affixes (§8.2); bosses draw them too from tier 6 ----------------------

const AFFIXES := ["swift", "bulwark", "rally", "quake", "steadfast", "last_rite"]
const SWIFT_SPEED := 0.25
const SWIFT_INTERVAL := 0.15
const BULWARK := 0.15
const RALLY_COUNT := 2
const QUAKE_EVERY := 12.0
const QUAKE_RADIUS := 1.6
const QUAKE_WINDUP := 1.2
const LAST_RITE_RADIUS := 2.5
const LAST_RITE_FUSE := 1.5
const BOSS_AFFIX_FROM := 6
const AFFIX_MAX := 3

## How many a warden of `tier` carries, or a boss.
static func affix_count(rank: String, tier: int) -> int:
	if rank == "warden": return mini(AFFIX_MAX, tier - 1)
	return clampi(tier - BOSS_AFFIX_FROM + 1, 0, AFFIX_MAX)

## Fixed for the floor: the same floor of the same region always rolls the same.
static func roll_affixes(rank: String, tier: int, region: String, floor_number: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%d" % [rank, region, floor_number])
	var pool: Array = AFFIXES.duplicate()
	var out := []
	for i in range(affix_count(rank, tier)):
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out

# --- The eight (§4–§8) ---------------------------------------------------------------------
## art / tint / scale: the existing board it borrows until Sol's art lands.
## taken: damage it takes in each phase (1 = all). front_guard: the share its
## shield takes off hits from in front, by phase (爱国者 in 行军姿态, 用户 2026-10-19:
## 毁灭姿态 keeps the shield as PRTS draws it but no longer blocks). lives: 扎罗 has two.
const FIGURES := {
	"patriot": {"name": "爱国者", "rank": "boss", "region": "mine", "hp": 32000.0, "atk": 640.0, "def": 600.0, "res": 40.0, "kind": "phys",
		"art": "breacher", "tint": Color("d8d4d0"), "scale": 1.5, "speed": 1.2, "front_guard": [0.6, 0.0, 0.0], "down_phase": true,
		"aura": {"phase": 2, "radius": 3.0, "feature": "contamination", "rate": 1.0}},
	"rat_king": {"name": "“鼠王”", "rank": "boss", "region": "city", "hp": 26000.0, "atk": 560.0, "def": 380.0, "res": 30.0, "kind": "arts",
		"art": "greytail_lord", "tint": Color("e6e0d6"), "scale": 1.3, "speed": 1.0, "barrier": 0.20, "barrier_color": Color("e0c890"),
		"dealt": [1.0, 1.3, 1.3]},
	"eikthyrnir": {"name": "“木裂”埃克提尔尼尔", "rank": "boss", "region": "snow", "hp": 34000.0, "atk": 620.0, "def": 600.0, "res": 20.0, "kind": "phys",
		"art": "shattered_champion", "tint": Color("a8c4cc"), "scale": 1.5, "speed": 1.2,
		"aura": {"phase": 1, "radius": 2.5, "feature": "cold", "pulse": 3.0, "every": 5.0}},
	"zaro": {"name": "扎罗，“狼之主”", "rank": "boss", "region": "siracusa", "hp": 18000.0, "atk": 600.0, "def": 500.0, "res": 45.0, "kind": "phys",
		"art": "rock_hornbeast", "tint": Color("5c5c66"), "scale": 1.7, "speed": 1.6, "lives": 2, "taken": [0.7, 1.0, 1.0],
		"debt_rate": 0.5, "rooted_phase": 1},
	"crownslayer": {"name": "弑君者", "rank": "warden", "region": "mine", "hp": 15000.0, "atk": 560.0, "def": 220.0, "res": 40.0, "kind": "phys",
		"art": "avenger", "tint": Color("d8a090"), "scale": 1.1, "speed": 1.7},
	"skullshatterer": {"name": "碎骨", "rank": "warden", "region": "city", "hp": 17000.0, "atk": 600.0, "def": 300.0, "res": 20.0, "kind": "phys",
		"art": "thrower", "tint": Color("7a7c8c"), "scale": 1.2, "speed": 1.3},
	"hollow_snowpriest": {"name": "空洞雪祀", "rank": "warden", "region": "snow", "hp": 15000.0, "atk": 560.0, "def": 200.0, "res": 50.0, "kind": "arts",
		"art": "fallen_snowpriest", "tint": Color("9a8ae8"), "scale": 1.2, "speed": 1.2},
	"father_agnir": {"name": "阿格尼尔神父", "rank": "warden", "region": "siracusa", "hp": 15000.0, "atk": 600.0, "def": 320.0, "res": 35.0, "kind": "phys",
		"art": "family_crossbow", "tint": Color("b8b8c4"), "scale": 1.15, "speed": 1.3, "debt_rate": 0.5},
}

## Each move. tier: the first tier it appears at; phase: [first, last] phase it
## is used in; early: from this tier it is used from phase 1 on (跳过教学段);
## range: the distance to her it is chosen at; up: what changes from a tier on.
## damage is on its ATK; windup in seconds, before the tier's factor.
const MOVES := {
	"patriot": [
		{"id": "sweep", "shape": "sector", "reach": 3.0, "angle": 140.0, "windup": 1.0, "damage": 1.2, "cd": 0.0, "range": [0.0, 3.0],
			"up": {2: {"combo": [{"shape": "sector", "reach": 3.0, "angle": 140.0}, {"shape": "lane", "reach": 4.0, "width": 1.0}, {"shape": "self", "radius": 2.4}]}}},
		{"id": "thrust", "shape": "lane", "reach": 4.0, "width": 1.0, "windup": 0.9, "damage": 1.1, "cd": 4.0, "range": [1.5, 4.2]},
		{"id": "stomp", "shape": "self", "radius": 2.4, "windup": 1.2, "damage": 1.0, "cd": 10.0, "range": [0.0, 1.6]},
		{"id": "javelin", "shape": "javelin", "reach": 14.0, "width": 1.2, "windup": 2.0, "lock": 0.4, "damage": 1.8, "cd": 9.0, "range": [3.0, 14.0], "phase": [2, 3], "early": 2,
			"up": {5: {"zone": {"radius": 2.0, "time": 10.0, "tick": 0.15, "feature": "contamination", "rate": 2.0}}}},
		{"id": "eruption", "shape": "safe_zones", "count": 3, "windup": 2.5, "damage": 2.8, "cd": 30.0, "range": [0.0, 99.0], "phase": [3, 3], "tier": 3, "big": true},
		{"id": "guerrillas", "shape": "summon", "types": ["shield", "shield", "crossbow"], "windup": 1.0, "tier": 4, "boost": 0.20},
		# 用户 2026-10-20: more 源石祭坛 at random spots, and — her inside one's
		# reach — a chance he sets it off at once (the shrine's own red ground first).
		{"id": "raise_shrine", "shape": "raise_shrine", "count": 1, "windup": 1.4, "cd": 22.0, "range": [0.0, 99.0], "phase": [2, 3], "early": 3,
			"up": {4: {"count": 2}}},
		{"id": "shrine_call", "shape": "shrine_call", "chance": 0.35, "windup": 1.0, "cd": 7.0, "range": [0.0, 99.0]},
	],
	"rat_king": [
		{"id": "cane", "shape": "sector", "reach": 2.2, "angle": 110.0, "windup": 0.8, "damage": 0.9, "kind": "phys", "cd": 0.0, "range": [0.0, 2.2]},
		{"id": "sand_shot", "shape": "projectile", "reach": 11.0, "shots": 1, "projectile": "sand_orb", "speed": 7.0, "windup": 0.9, "damage": 0.8, "cd": 1.5, "range": [2.2, 11.0]},
		{"id": "sing", "shape": "cross", "arm": 7.0, "width": 2.6, "mark": 1.8, "windup": 1.8, "damage": 1.5, "kind": "phys", "cd": 14.0, "range": [0.0, 9.0],
			"up": {2: {"double": true}}},
		{"id": "prison", "shape": "ground", "radius": 3.5, "windup": 1.2, "damage": 0.0, "cd": 18.0, "range": [0.0, 10.0], "phase": [2, 3], "early": 2,
			"zone": {"radius": 3.5, "time": 8.0, "tick": 0.25, "hex": {"atk": -0.40}}, "up": {5: {"zone": {"radius": 3.5, "time": 20.0, "tick": 0.25, "hex": {"atk": -0.40}}}}},
		{"id": "stampede", "shape": "lanes", "count": 3, "width": 3.0, "mode": "parallel", "windup": 2.0, "damage": 2.5, "kind": "phys", "cd": 25.0, "range": [0.0, 99.0], "phase": [3, 3], "tier": 3, "big": true},
		{"id": "grey_tails", "shape": "summon", "types": ["greytail", "greytail", "greytail_lord"], "windup": 1.0, "tier": 4},
		{"id": "sandstorm", "shape": "sandstorm", "every": 30.0, "step": 2.0, "times": 3, "warn": 3.0, "tier": 5},
	],
	"eikthyrnir": [
		{"id": "hammer", "shape": "front_circle", "offset": 1.4, "radius": 1.8, "windup": 1.1, "damage": 1.3, "cold": 6.0, "cd": 0.0, "range": [0.0, 3.0]},
		{"id": "sweep", "shape": "sector", "reach": 3.0, "angle": 150.0, "windup": 0.9, "damage": 1.0, "cold": 4.0, "cd": 3.0, "range": [0.0, 3.0]},
		{"id": "hurl", "shape": "hurl", "radius": 2.0, "width": 1.2, "back": 0.6, "windup": 1.4, "damage": 1.2, "back_damage": 0.8, "cold": 6.0, "cd": 8.0, "range": [3.0, 11.0], "tier": 2, "early": 2},
		{"id": "entropy", "shape": "lanes", "count": 6, "width": 1.4, "mode": "radial", "windup": 2.2, "damage": 2.4, "cold": 15.0, "cd": 28.0, "range": [0.0, 99.0], "phase": [3, 3], "tier": 3, "big": true,
			"zone": {"time": 6.0, "feature": "cold", "rate": 8.0}},
		{"id": "treescar", "shape": "summon", "types": ["shattered_champion", "ice_warrior", "ice_warrior"], "windup": 1.0, "tier": 4},
	],
	"zaro": [
		{"id": "claw", "shape": "sector", "reach": 2.6, "angle": 120.0, "windup": 0.8, "damage": 1.1, "cd": 0.0, "range": [0.0, 2.6]},
		{"id": "call_family", "shape": "family", "every": 20.0, "count": 2, "cap": 6, "phase": [1, 1]},
		{"id": "dread", "shape": "curse", "radius": 1.2, "windup": 1.2, "cd": 25.0, "range": [0.0, 14.0], "phase": [1, 1], "break": 0.20, "ramp": 20.0, "drain": 0.03, "hex": {"aspd": -0.30},
			"up": {2: {"cd": 18.0}}},
		{"id": "pounce", "shape": "charge", "reach": 5.0, "width": 1.4, "windup": 0.8, "damage": 1.2, "cd": 2.5, "range": [1.5, 5.5], "phase": [2, 3],
			"up": {2: {"follow": {"shape": "self", "radius": 1.6, "damage": 1.0}}}},
		{"id": "bite", "shape": "sector", "reach": 2.2, "angle": 100.0, "windup": 0.7, "damage": 1.0, "cd": 0.0, "range": [0.0, 2.2], "phase": [2, 3]},
		{"id": "howl", "shape": "channel", "time": 3.0, "debt": 10.0, "breaks": 2, "windup": 0.4, "cd": 40.0, "range": [0.0, 99.0], "phase": [2, 3], "tier": 2},
		{"id": "pack", "shape": "lanes", "count": 4, "width": 1.6, "mode": "edge", "windup": 2.0, "damage": 2.5, "cd": 26.0, "range": [0.0, 99.0], "phase": [3, 3], "tier": 3, "big": true},
	],
	"crownslayer": [
		{"id": "twin", "shape": "sector", "reach": 2.4, "angle": 100.0, "windup": 0.8, "damage": 1.0, "cd": 0.0, "range": [0.0, 2.4]},
		{"id": "behind", "shape": "blink", "gap": 1.5, "radius": 1.6, "windup": 0.8, "damage": 1.2, "cd": 12.0, "range": [0.0, 9.0],
			"up": {2: {"repeat": 1}}},
		{"id": "knives", "shape": "projectile", "reach": 10.0, "shots": 3, "projectile": "arrow", "speed": 13.0, "windup": 0.9, "damage": 0.7, "cd": 4.0, "range": [2.4, 10.0]},
		{"id": "smoke", "shape": "smoke", "radius": 3.0, "time": 6.0, "taken": 0.6, "windup": 0.6, "cd": 18.0, "range": [0.0, 99.0], "tier": 2},
		{"id": "regicide", "shape": "dashes", "count": 3, "reach": 9.0, "width": 1.0, "mark": 1.5, "windup": 0.5, "damage": 1.0, "cd": 24.0, "range": [0.0, 99.0], "tier": 3, "big": true},
	],
	"skullshatterer": [
		{"id": "grenade", "shape": "ground", "radius": 2.0, "windup": 1.0, "damage": 0.9, "cd": 2.5, "range": [2.0, 10.0], "hex": {"def": -0.30, "time": 5.0}},
		{"id": "arm_blade", "shape": "sector", "reach": 2.2, "angle": 110.0, "windup": 0.8, "damage": 1.2, "cd": 0.0, "range": [0.0, 2.2]},
		{"id": "hop", "shape": "backstep", "distance": 3.0, "after": 3.0, "cd": 6.0},
		{"id": "barrage", "shape": "lob_line", "count": 3, "radius": 1.6, "gap": 0.3, "windup": 1.0, "damage": 0.8, "cd": 9.0, "range": [3.0, 11.0], "tier": 2},
		{"id": "demolition", "shape": "mines", "count": 3, "radius": 2.5, "windup": 3.0, "damage": 2.0, "cd": 22.0, "range": [0.0, 99.0], "tier": 3, "big": true},
	],
	"hollow_snowpriest": [
		{"id": "orb", "shape": "projectile", "reach": 11.0, "shots": 1, "projectile": "ice_orb", "speed": 8.0, "windup": 1.0, "damage": 0.9, "cold": 5.0, "cd": 2.0, "range": [0.0, 11.0],
			"bounce": 3, "bounce_gap": 0.6, "bounce_cut": 0.15, "up": {2: {"bounce": 4}}},
		{"id": "bless", "shape": "bless", "time": 8.0, "aspd": 0.5, "speed": 0.5, "windup": 0.8, "cd": 15.0, "range": [0.0, 99.0]},
		{"id": "spike", "shape": "ground", "radius": 1.3, "windup": 0.9, "damage": 1.0, "cd": 5.0, "range": [0.0, 10.0],
			"up": {2: {"triple": 1.6}}},
		{"id": "snatch", "shape": "summon", "types": ["shell_vine", "shell_vine"], "windup": 1.2, "tier": 3, "once": true},
	],
	"father_agnir": [
		{"id": "special_round", "shape": "projectile", "reach": 12.0, "shots": 1, "projectile": "bullet", "speed": 14.0, "windup": 1.0, "damage": 1.0, "cd": 2.0, "range": [0.0, 12.0],
			"shred": 0.08, "shred_max": 5},
		{"id": "burst", "shape": "projectile", "reach": 12.0, "shots": 2, "projectile": "bullet", "speed": 14.0, "windup": 0.9, "damage": 0.6, "cd": 3.5, "range": [0.0, 12.0]},
		{"id": "absolve", "shape": "channel", "time": 1.5, "heal": 0.20, "breaks": 2, "windup": 0.3, "cd": 16.0, "range": [0.0, 99.0], "tier": 2},
		{"id": "buckshot", "shape": "sector", "reach": 5.0, "angle": 50.0, "windup": 0.8, "damage": 1.1, "cd": 6.0, "range": [0.0, 5.0], "tier": 2},
		{"id": "last_rites", "shape": "sniper", "mark": 2.0, "lock": 0.4, "reach": 30.0, "damage": 2.5, "cd": 20.0, "range": [0.0, 99.0], "tier": 3, "big": true},
	],
}

## Self-buffs and the field by tier (§4–§7), read by entities/boss.gd.
## 爱国者 stands once more at REVIVE_SHARE from tier 5 (不倒); 埃克提尔尼尔's
## self-annihilation fires at these shares, by tier; tier 5 frost armour.
const REVIVE_TIER := 5
const REVIVE_SHARE := 0.30
const RAMPAGE_AT := {1: [0.70], 2: [0.70, 0.40], 3: [0.70, 0.40, 0.10]}
const RAMPAGE_TIME := 3.0
const RAMPAGE_TAKEN := 0.2
const RAMPAGE_DASHES := 3
const RAMPAGE_BURST := {"radius": 2.5, "cold": 8.0}
const FROST_ARMOUR := 0.15
const BLIZZARD := 2.0
const FIRE_HAMMER_COST := 30.0
## 冻结: a cold hit while she is at the top step of cold.
const FREEZE := 0.8
## 扎罗: 远古威慑 within AWE_RADIUS; 清算时刻 RECKONING_TIME s; tier 5 blood moon.
const AWE_RADIUS := 2.0
const AWE_ASPD := -0.30
const RECKONING_TIME := 15.0
const RECKONING_ASPD := 0.30
const BLOOD_MOON := 2.0
const BLOOD_MARK_EVERY := 30.0
const BLOOD_MARK := {"radius": 2.5, "time": 10.0, "taken": 0.5}
## 鼠王's sand barrier, raised again at half life from tier 2.
const SAND_REBARRIER_TIER := 2

## Their own boards (Sol B1, accepted 2026-10-19): rows past the shared five
## (IDLE START CHARGE STRIKE RECOVER), 0-based, by move id; "down" and "roar"
## for the phase change. Patriot's second stance walks on walk rows 5-8 and
## stands on walk row 5; Zaro's IDLE is lying, so up he stands on walk row 1.
const POSES := {
	"patriot": {"moves": {"thrust": 5, "stomp": 6, "javelin": 7, "eruption": 8, "raise_shrine": 8, "shrine_call": 6}, "down": 8, "walk2": 4},
	# 沙弹 throws from the raised hand, 唱沙 and 沙狱 plant the cane; the cane
	# swing keeps the shared rows (用户 2026-10-20: 远程和扇形区分动作).
	"rat_king": {"moves": {"sand_shot": 5, "sing": 6, "prison": 6, "stampede": 7, "grey_tails": 5}, "roar": 7},
	"eikthyrnir": {"moves": {"sweep": 5, "hurl": 6, "rampage": 7, "treescar": 8}, "roar": 8},
	"zaro": {"moves": {"dread": 5, "pounce": 7, "howl": 8, "pack": 8}, "down": 6, "roar": 8, "stand": 0},
	"crownslayer": {"moves": {"behind": 5, "knives": 6, "smoke": 6}},
	"skullshatterer": {"moves": {"grenade": 5, "barrage": 5, "demolition": 5}},
	"hollow_snowpriest": {"moves": {"bless": 5, "snatch": 6}},
	"father_agnir": {"moves": {"absolve": 5}},
}

# --- The arenas (Boss战场地策划案 §4, 用户 2026-10-19) ---------------------------------
## Each region's ground: its cover (offsets from the centre, in metres, +z
## toward the way out; size), the mouths summons come in by, and its device.
## Cover the big moves break stays broken, even after a reset (Q6).
const ARENAS := {
	"mine": {"colour": Color("e08a30"), "cover": [[Vector2(-7.0, 2.0), Vector2(2.2, 1.4)], [Vector2(6.5, -3.0), Vector2(2.2, 1.4)]],
		"mouths": [Vector2(-1.0, -1.0), Vector2(-1.0, 0.3), Vector2(1.0, 0.3)]},
	"city": {"colour": Color("6ad0c0"), "cover": [[Vector2(-6.0, -4.0), Vector2(1.6, 1.8)], [Vector2(6.0, -4.0), Vector2(1.6, 1.8)], [Vector2(0.0, -8.0), Vector2(1.6, 1.8)]],
		"mouths": [Vector2(-0.71, -0.71), Vector2(0.71, -0.71), Vector2(-0.71, 0.71), Vector2(0.71, 0.71)]},
	"snow": {"colour": Color("9fd8ff"), "cover": [[Vector2(-6.5, -2.5), Vector2(1.4, 1.6)], [Vector2(6.5, -2.5), Vector2(1.4, 1.6)]],
		"mouths": [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0)]},
	"siracusa": {"colour": Color("c0392b"), "cover": [[Vector2(-7.0, -3.0), Vector2(1.6, 1.8)], [Vector2(7.0, -3.0), Vector2(1.4, 0.9)]],
		"mouths": [Vector2(-0.71, -0.71), Vector2(0.71, -0.71), Vector2(-0.71, 0.71), Vector2(0.71, 0.71)]},
}
## 矿区: 源石祭坛 (7-18) — every SHRINE_EVERY s, SHRINE_WARN s of warning, then a
## pulse of SHRINE_RADIUS: her SHRINE_HIT of her life (true) and SHRINE_CONTAM
## contamination; 爱国者 and his help a stack of SHRINE_ATK attack for
## SHRINE_TIME s, at most SHRINE_STACKS.
const SHRINE_AT := Vector2(-5.0, -2.0)
const SHRINE_EVERY := 14.0
const SHRINE_WARN := 2.0
const SHRINE_RADIUS := 4.0
const SHRINE_HIT := 0.12
const SHRINE_CONTAM := 5.0
const SHRINE_ATK := 0.10
const SHRINE_TIME := 12.0
const SHRINE_STACKS := 3
## 爱国者 raises more (raise_shrine): at most SHRINE_RAISED_MAX at once, each
## SHRINE_APART from the others; a raised one first pulses SHRINE_FIRST s on.
## Gone when the fight resets.
const SHRINE_RAISED_MAX := 3
const SHRINE_APART := 5.0
const SHRINE_FIRST := 7.0
## 干扰地雷 (7-18): she arms them with E; an enemy within MINE_TRIGGER sets
## one off: her attack × MINE_DAMAGE within MINE_RADIUS, and those it hits take
## MINE_FRAGILE more damage for MINE_FRAGILE_TIME s.
const MINES := [Vector2(-4.0, -7.0), Vector2(5.0, 3.0), Vector2(-2.0, 7.0)]
const MINE_TRIGGER := 1.0
const MINE_RADIUS := 2.0
const MINE_DAMAGE := 3.0
const MINE_FRAGILE := 0.5
const MINE_FRAGILE_TIME := 15.0
## 龙门: 医疗符文 (CB-10) — RUNE_HEAL of her life a second on it; 沙狱 on a
## rune covers it for RUNE_BURIED s.
const RUNES := [Vector2(-5.0, 4.0), Vector2(5.0, 4.0), Vector2(0.0, -5.0)]
const RUNE_RADIUS := 1.5
const RUNE_HEAL := 0.02
const RUNE_BURIED := 20.0
## 萨米: two fires (one lit), and the 木裂 totem in the middle — broken by the
## first 自我泯灭, it leaves TOTEM_ICE s of fissured ground (cold TOTEM_COLD a second).
const FIRES := [Vector2(-9.0, 1.0), Vector2(9.0, 1.0)]
const FIRE_START := 120.0
const TOTEM_AT := Vector2(0.0, -1.5)
const TOTEM_SIZE := Vector2(1.2, 2.6)
const TOTEM_ICE := 6.0
const TOTEM_ICE_RADIUS := 2.5
const TOTEM_COLD := 8.0
## 叙拉古: the fountain behind 扎罗 (never breaks), CIVILIANS 叙拉古平民 (IS-10)
## round the edge; each blow of hers on one adds CIVILIAN_DEBT 血债 (Q7).
const FOUNTAIN_AT := Vector2(0.0, 7.0)
const FOUNTAIN_RADIUS := 1.8
const CIVILIANS := 6
const CIVILIAN_DEBT := 5.0
## They wander the piazza (用户 2026-10-20): to a spot at most CIVILIAN_WANDER
## from where they sheltered, at CIVILIAN_WALK, resting CIVILIAN_REST s between.
const CIVILIAN_WANDER := 5.0
const CIVILIAN_WALK := 1.1
const CIVILIAN_REST := Vector2(1.5, 4.0)
## A 平民 within reach when 扎罗 or one of the family starts a blow: this
## chance the blow goes at it instead. It cringes and runs, and adds 血债 as hers do.
const CIVILIAN_TARGET_CHANCE := 0.3

static func figure(id: String) -> Dictionary:
	return FIGURES.get(id, {})

static func display_name(id: String) -> String:
	return str(FIGURES.get(id, {}).get("name", id))

## The move as it is at `tier`, with every upgrade up to it merged in.
static func move_at(move: Dictionary, tier: int) -> Dictionary:
	var out := move.duplicate(true)
	var ups: Dictionary = move.get("up", {})
	var keys := ups.keys()
	keys.sort()
	for at in keys:
		if tier >= int(at): out.merge(ups[at], true)
	out.erase("up")
	return out

## Moves this figure has at `tier` in `phase` (summons and the field are not chosen, only fired).
static func moves_for(id: String, tier: int, phase: int) -> Array:
	var out := []
	for move in MOVES.get(id, []):
		var m := move_at(move, tier)
		if tier < int(m.get("tier", 1)): continue
		var span: Array = m.get("phase", [1, 3])
		var first := int(span[0])
		if m.has("early") and tier >= int(m.early): first = 1
		if phase < first or phase > int(span[1]): continue
		out.append(m)
	return out
