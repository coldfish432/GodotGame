class_name EnemyAttacks
extends RefCounted
## Distances are world units. With no ground warning, the windup itself is the
## warning, so ordinary windups run about 0.25 s longer than the old telegraphs.
## interval is the wait after the strike begins before the next windup may start
## (the pre-rework meaning), so one full cycle lasts windup + interval.
## Every ordinary attack is physical. Only the retained elite profile telegraphs,
## and its strike is arts damage: 策划案 §5 shows red ground for elites and arts.
## "damage" is the attack's multiplier on the enemy's ATK: 1.0 for the old seven,
## the new enemies' own weights from 新敌人攻击动画与预警设计案 §三 (0.7–1.5);
## the ATK itself and the defences are in STATS.
const ORDER := ["thug", "crossbow", "slug", "brawler", "crossbow_leader", "ice_warrior", "ice_hunter"]
const PROFILES := {
	"thug": {"name": "暴徒", "attack": "乱劈", "row": 0, "windup": 0.8, "interval": 1.35, "damage": 1.0, "shape": "sector", "reach": 2.4, "angle": 100.0, "recovery": 0.25},
	"crossbow": {"name": "弩手", "attack": "单发弩箭", "row": 1, "windup": 1.0, "interval": 1.8, "damage": 1.0, "shape": "projectile", "reach": 12.0, "projectile": "arrow", "shots": 1, "recovery": 0.3},
	"slug": {"name": "源石虫", "attack": "扑咬", "row": 2, "windup": 0.8, "interval": 1.15, "damage": 1.0, "shape": "lane", "reach": 2.2, "width": 1.2, "dash": 1.6, "recoil": 1.2, "recovery": 0.25},
	"brawler": {"name": "拳刃武士", "attack": "突刺", "row": 3, "windup": 0.8, "interval": 1.0, "damage": 1.0, "shape": "lane", "reach": 3.2, "width": 0.9, "dash": 1.2, "recoil": 0.8, "recovery": 0.25},
	"crossbow_leader": {"name": "弩手组长", "attack": "三连扇射", "row": 4, "windup": 1.1, "interval": 1.8, "damage": 1.0, "shape": "projectile", "reach": 12.0, "projectile": "arrow", "shots": 3, "recovery": 0.3},
	"ice_warrior": {"name": "冰原战士", "attack": "劈冰", "row": 5, "windup": 1.0, "interval": 1.5, "damage": 1.0, "shape": "ice", "reach": 3.0, "width": 1.4, "impact_radius": 0.8, "recovery": 0.35},
	"ice_hunter": {"name": "冰原猎人", "attack": "狙击", "row": 6, "windup": 1.5, "interval": 2.6, "damage": 1.0, "shape": "projectile", "reach": 15.0, "track": 0.9, "projectile": "bullet", "shots": 1, "recovery": 0.35},
	"elite": {"name": "精英重击", "attack": "重击", "row": -1, "windup": 1.0, "interval": 2.1, "damage": 1.0, "shape": "circle", "reach": 2.4, "radius": 1.65, "recovery": 0.3, "elite": true},
	# --- 装备扩充策划案 §2.1: the first sixteen new enemies. "art" borrows an
	# existing sheet (tinted) until their own art lands; elites use the elite art.
	# 切尔诺伯格
	"armed": {"name": "武装人员", "attack": "钝器重击", "row": -1, "windup": 1.0, "interval": 2.1, "damage": 1.4, "shape": "circle", "reach": 2.4, "radius": 1.65, "recovery": 0.3, "elite": true, "tint": Color("c0a080")},
	"caster": {"name": "术师", "attack": "源石晶刺", "art": "crossbow", "tint": Color("c49cff"), "windup": 0.8, "interval": 2.2, "damage": 1.0, "shape": "ground", "reach": 9.0, "radius": 1.2, "recovery": 0.3},
	"shield": {"name": "机动盾兵", "attack": "盾推", "art": "thug", "tint": Color("9fb3c8"), "windup": 0.9, "interval": 1.6, "damage": 0.8, "shape": "sector", "reach": 2.2, "angle": 90.0, "recovery": 0.6, "front_guard": 0.6, "knockback": 2.0},
	# 用户 2026-10-11: rears up and chops down with its front claws (抬起前爪向下劈).
	"slug_volatile": {"name": "高能源石虫", "attack": "前爪下劈", "art": "slug", "tint": Color("ff9a4a"), "windup": 0.8, "interval": 1.2, "damage": 0.7, "shape": "sector", "reach": 1.9, "angle": 90.0, "recovery": 0.3, "death_blast": 2.0},
	"picket": {"name": "感染者纠察官", "attack": "扇形挥击", "art": "thug", "tint": Color("d08a6a"), "windup": 0.8, "interval": 1.3, "damage": 1.0, "shape": "sector", "reach": 2.6, "angle": 110.0, "recovery": 0.3, "lasso": true},
	# 龙门
	"greytail": {"name": "灰尾", "attack": "突刺", "art": "brawler", "tint": Color("aab0b8"), "windup": 0.8, "interval": 1.0, "damage": 0.8, "shape": "lane", "reach": 3.2, "width": 0.9, "dash": 1.2, "recoil": 0.8, "recovery": 0.25, "barrier": 0.3},
	"greytail_lord": {"name": "灰尾香主", "attack": "重击", "row": -1, "windup": 1.0, "interval": 2.0, "damage": 1.3, "shape": "circle", "reach": 2.4, "radius": 1.6, "recovery": 0.3, "elite": true, "barrier": 0.3, "barrier_color": Color("c8b0f0"), "tint": Color("b8b0d8")},
	"thrower": {"name": "燃烧瓶投掷者", "attack": "燃烧瓶", "art": "crossbow", "tint": Color("ffb066"), "windup": 1.0, "interval": 2.4, "damage": 0.8, "shape": "lob", "reach": 9.0, "radius": 1.3, "fire_time": 3.0, "recovery": 0.3, "backstep": 3.0},
	"bully": {"name": "欺凌者", "attack": "冲撞", "row": -1, "windup": 1.2, "interval": 2.6, "damage": 1.5, "shape": "charge", "reach": 7.0, "width": 1.4, "recovery": 1.0, "elite": true, "unstoppable": true, "knockback": 2.5, "tint": Color("e0a070")},
	"avenger": {"name": "寻仇者", "attack": "突刺回砍", "row": -1, "windup": 1.0, "interval": 2.0, "damage": 0.8, "shape": "circle", "reach": 2.4, "radius": 1.6, "recovery": 0.3, "elite": true, "combo": 2, "phase": 0.5, "tint": Color("d07070"),
		# 新敌人攻击案 §三第 10 条: a straight thrust, then a back-cut round its own feet;
		# below half it adds a third (the thrust again).
		"segments": [{"shape": "lane", "reach": 3.0, "width": 0.9}, {"shape": "self", "radius": 1.6}]},
	"breacher": {"name": "粉碎攻坚手", "attack": "重锤砸地", "row": -1, "windup": 1.1, "interval": 2.2, "damage": 1.3, "shape": "circle", "reach": 2.2, "radius": 2.0, "recovery": 0.4, "elite": true, "front_guard": 0.3, "stun_every": 3, "stun": 0.8, "tint": Color("8090a8")},
	# 萨米
	"taint_husk": {"name": "染污躯壳", "attack": "横扫", "art": "ice_warrior", "tint": Color("8a7a9a"), "windup": 0.9, "interval": 1.4, "damage": 1.1, "shape": "sector", "reach": 2.4, "angle": 110.0, "recovery": 0.3, "enrage_run": 2.0},
	"distorted_caster": {"name": "歪曲施法者", "attack": "脚下施法", "art": "ice_hunter", "tint": Color("9a7be0"), "windup": 0.9, "interval": 2.2, "damage": 1.1, "shape": "ground", "reach": 8.0, "radius": 1.3, "recovery": 0.3, "glide": 5.0},
	"shattered_champion": {"name": "木裂战士", "attack": "突进两段斩", "row": -1, "windup": 0.9, "interval": 2.0, "damage": 1.0, "shape": "circle", "reach": 2.6, "radius": 1.7, "recovery": 0.3, "elite": true, "combo": 2, "annihilate": 0.3, "tint": Color("b0c8d0")},
	"shell_vine": {"name": "巨壳藤蔓", "attack": "张口", "art": "slug", "tint": Color("7aaa5a"), "scale": 1.3, "windup": 0.7, "interval": 1.2, "damage": 1.0, "shape": "lane", "reach": 2.4, "width": 1.4, "dash": 1.6, "recoil": 1.0, "recovery": 0.3},
	# 用户 2026-10-11: lowers its head and butts with its horns (低头用角顶): a short
	# lunge, not a charge across the room.
	"rock_hornbeast": {"name": "岩角兽", "attack": "角顶", "art": "slug", "tint": Color("a08060"), "scale": 1.5, "windup": 1.0, "interval": 2.0, "damage": 1.0, "shape": "lane", "reach": 2.4, "width": 1.4, "dash": 1.0, "recoil": 0.6, "recovery": 0.6, "front_guard": 0.5, "neutral": true, "knockback": 2.0},
	"fallen_snowpriest": {"name": "陷落雪祀", "attack": "冰弹", "art": "ice_hunter", "tint": Color("eef4ff"), "windup": 1.2, "interval": 2.4, "damage": 1.1, "shape": "projectile", "reach": 11.0, "projectile": "ice_orb", "shots": 1, "recovery": 0.35, "haste_bounce": true},
	# 威胁值 (用户 2026-10-14; PRTS 萨卡兹哨兵: 负责侦查和预警, 不攻击): it never
	# attacks; seeing her it puts up a red "!" (the meter fills faster), runs to
	# a reachable spot and holds there, then runs again (Enemy._tick_sentinel).
	"sentinel": {"name": "萨卡兹哨兵", "attack": "警报", "art": "crossbow", "tint": Color("e07a6a"), "windup": 1.0, "interval": 1.0, "damage": 0.0, "shape": "none", "reach": 0.0, "recovery": 0.0, "alarm": true},
	# 叙拉古 (叙拉古敌人设计案_v1 §三, Sol batch N4). "debt": what its fall adds
	# to the 血债 (§四.1, 用户 2026-10-16: 血债杀人涨).
	"family_soldier": {"name": "家族士兵", "attack": "匕首突刺", "windup": 0.7, "interval": 1.2, "damage": 0.8, "shape": "lane", "reach": 2.4, "width": 0.8, "dash": 0.8, "recoil": 0.6, "recovery": 0.25, "debt": 3.0},
	# 用户 2026-10-16: 穿透类攻击打到他就停下 (blocks_pierce); slow, hard, heavy.
	"family_intimidator": {"name": "家族恫吓者", "attack": "双拳砸", "windup": 1.1, "interval": 2.0, "damage": 1.2, "shape": "sector", "reach": 2.2, "angle": 100.0, "recovery": 0.6, "knockback": 1.5, "slow": 0.6, "blocks_pierce": true, "debt": 12.0},
	# 清算时刻: its bolts turn to arts (Enemy.shot_kind).
	"family_crossbow": {"name": "家族弩手", "attack": "枪弩连射", "windup": 1.0, "interval": 2.0, "damage": 0.6, "shape": "projectile", "reach": 11.0, "projectile": "arrow", "shots": 2, "recovery": 0.3, "reckoning_arts": true},
	# 煽动 (§三第 4 条): stops to raise the 血债 "incite" a second (INCITE_*).
	"family_caster": {"name": "家族术师", "attack": "双发术弹", "windup": 0.9, "interval": 2.4, "damage": 0.7, "shape": "projectile", "reach": 9.0, "projectile": "ice_orb", "shots": 2, "recovery": 0.3, "incite": 0.75},
	# Its own deaths and those round it within CAPO_DEBT_RADIUS add CAPO_DEBT each.
	"family_capo": {"name": "家族角头", "attack": "雪茄里的武器", "row": -1, "windup": 1.0, "interval": 2.2, "damage": 1.4, "shape": "ground", "reach": 9.0, "radius": 1.7, "recovery": 0.35, "elite": true,
		# 近身一掌: within "trigger" of her, a backhand round its own feet instead.
		"close": {"shape": "self", "radius": 1.6, "windup": 0.7, "damage": 1.0, "trigger": 1.8}},
	# Comes only with the reckoning's patrols, unseen until close (Enemy.stealth).
	"family_eraser": {"name": "家族灭迹人", "attack": "现身斩", "row": -1, "windup": 0.55, "interval": 2.0, "damage": 1.6, "shape": "lane", "reach": 3.2, "width": 0.9, "dash": 1.2, "recoil": 0.6, "recovery": 0.4, "elite": true, "stealth": true},
	# A roadblock in a lane's mouth (§三第 7 条): never leaves it; a short charge
	# out and back. Broken within CAR_DROP_REACH it lets out three soldiers.
	"family_car": {"name": "家族专用轿车", "attack": "一路顺风", "row": -1, "windup": 1.3, "interval": 3.5, "damage": 1.8, "shape": "charge", "reach": 4.5, "width": 1.8, "recovery": 1.2, "elite": true, "unstoppable": true, "knockback": 3.0, "roadblock": true, "machine": true},
}
## 叙拉古's 血债 (§四.1): around a fallen enemy, every 家族角头 within this adds CAPO_DEBT.
const CAPO_DEBT_RADIUS := 3.0
const CAPO_DEBT := 6.0
## 家族专用轿车 broken this close lets out CAR_SOLDIERS 家族士兵.
const CAR_DROP_REACH := 4.0
const CAR_SOLDIERS := 3
## It starts its charge when she is this far ahead of its nose (and no wider
## than CAR_SIGHT_WIDTH either side), and backs into its slot over CAR_REVERSE_TIME.
const CAR_SIGHT := 8.0
const CAR_SIGHT_WIDTH := 2.0
const CAR_REVERSE_TIME := 1.5
## 家族术师's 煽动: at most INCITE_TIME s, broken by INCITE_BREAK_HITS hits or a
## silence, then INCITE_COOLDOWN s before the next. A reckoning's own casters
## never incite (their 血债 would call the next reckoning).
const INCITE_TIME := 8.0
const INCITE_COOLDOWN := 10.0
const INCITE_BREAK_HITS := 2
## 家族灭迹人, unseen past Enemy.STEALTH_FAINT in the rain: a splash every
## ERASER_SPLASH_EVERY s where it steps. It closes in on her from behind and to
## one side, ERASER_FLANK_GAP from her.
const ERASER_SPLASH_EVERY := 0.4
const ERASER_FLANK_GAP := 2.5

## 局内构筑与数值策划案 §6. Shaped after the PRTS lines for the same enemy kinds
## (暴徒 / 弩手 / 源石虫 …, 局内构筑调研_集成战略藏品.md §2.3), rescaled so that at
## depth 1 Lappland lands 2–3 hits on an ordinary enemy and about 10 on an
## elite, and an ordinary hit costs her 6–15% of her life. Depth adds 12% HP
## and 2% ATK per segment, the snow region another 45% HP; alert (警戒) adds
## up to 62.5% damage on top.
const STATS := {
	"thug": {"hp": 1400.0, "atk": 440.0, "def": 100.0, "res": 0.0, "kind": "phys"},
	"crossbow": {"hp": 1100.0, "atk": 440.0, "def": 60.0, "res": 0.0, "kind": "phys"},
	"slug": {"hp": 800.0, "atk": 344.0, "def": 0.0, "res": 0.0, "kind": "phys"},
	"brawler": {"hp": 1300.0, "atk": 392.0, "def": 220.0, "res": 0.0, "kind": "phys"},
	"crossbow_leader": {"hp": 1300.0, "atk": 368.0, "def": 150.0, "res": 0.0, "kind": "phys"},
	"ice_warrior": {"hp": 1600.0, "atk": 520.0, "def": 220.0, "res": 0.0, "kind": "phys"},
	"ice_hunter": {"hp": 1100.0, "atk": 560.0, "def": 60.0, "res": 20.0, "kind": "phys"},
	"elite": {"hp": 3600.0, "atk": 560.0, "def": 300.0, "res": 30.0, "kind": "arts"},
	"armed": {"hp": 3600.0, "atk": 560.0, "def": 320.0, "res": 20.0, "kind": "phys"},
	"caster": {"hp": 900.0, "atk": 420.0, "def": 50.0, "res": 30.0, "kind": "arts"},
	"shield": {"hp": 1800.0, "atk": 380.0, "def": 260.0, "res": 0.0, "kind": "phys"},
	"slug_volatile": {"hp": 700.0, "atk": 344.0, "def": 0.0, "res": 0.0, "kind": "phys"},
	"picket": {"hp": 1700.0, "atk": 460.0, "def": 150.0, "res": 10.0, "kind": "phys"},
	"greytail": {"hp": 1300.0, "atk": 400.0, "def": 180.0, "res": 0.0, "kind": "phys"},
	"greytail_lord": {"hp": 3400.0, "atk": 540.0, "def": 260.0, "res": 20.0, "kind": "arts"},
	"thrower": {"hp": 950.0, "atk": 380.0, "def": 60.0, "res": 0.0, "kind": "arts"},
	"bully": {"hp": 3800.0, "atk": 600.0, "def": 320.0, "res": 10.0, "kind": "phys"},
	"avenger": {"hp": 3400.0, "atk": 520.0, "def": 240.0, "res": 20.0, "kind": "phys"},
	"breacher": {"hp": 4000.0, "atk": 580.0, "def": 380.0, "res": 10.0, "kind": "phys"},
	"taint_husk": {"hp": 1500.0, "atk": 480.0, "def": 160.0, "res": 0.0, "kind": "phys"},
	"distorted_caster": {"hp": 1000.0, "atk": 500.0, "def": 60.0, "res": 40.0, "kind": "arts"},
	"shattered_champion": {"hp": 3800.0, "atk": 600.0, "def": 280.0, "res": 30.0, "kind": "phys"},
	"family_soldier": {"hp": 1300.0, "atk": 420.0, "def": 120.0, "res": 10.0, "kind": "phys"},
	"family_intimidator": {"hp": 2600.0, "atk": 480.0, "def": 420.0, "res": 10.0, "kind": "phys"},
	"family_crossbow": {"hp": 1100.0, "atk": 420.0, "def": 100.0, "res": 10.0, "kind": "phys"},
	"family_caster": {"hp": 1000.0, "atk": 440.0, "def": 120.0, "res": 40.0, "kind": "arts"},
	"family_capo": {"hp": 3600.0, "atk": 560.0, "def": 320.0, "res": 25.0, "kind": "arts"},
	"family_eraser": {"hp": 3800.0, "atk": 640.0, "def": 360.0, "res": 45.0, "kind": "phys"},
	"family_car": {"hp": 4200.0, "atk": 640.0, "def": 480.0, "res": 15.0, "kind": "phys"},
	"shell_vine": {"hp": 2200.0, "atk": 460.0, "def": 200.0, "res": 20.0, "kind": "phys"},
	"rock_hornbeast": {"hp": 2000.0, "atk": 420.0, "def": 250.0, "res": 0.0, "kind": "phys"},
	"fallen_snowpriest": {"hp": 1800.0, "atk": 520.0, "def": 120.0, "res": 40.0, "kind": "arts"},
	"sentinel": {"hp": 900.0, "atk": 0.0, "def": 60.0, "res": 20.0, "kind": "phys"},
}

## Region pools for the new enemies (装备扩充策划案 §2.1). Ordinary slots draw
## from `normal` / `ranged`; elite slots from `elite`.
const REGION_POOLS := {
	"mine": {"normal": ["thug", "thug", "shield", "picket", "slug_volatile"], "ranged": ["crossbow", "crossbow", "caster"], "elite": ["armed"]},
	"city": {"normal": ["brawler", "brawler", "greytail"], "ranged": ["crossbow_leader", "thrower"], "elite": ["bully", "avenger", "breacher", "greytail_lord"]},
	"snow": {"normal": ["ice_warrior", "ice_warrior", "taint_husk"], "ranged": ["ice_hunter", "distorted_caster"], "elite": ["shattered_champion"]},
	# 叙拉古敌人设计案 §一: the eraser comes only with the reckoning's patrols,
	# the car only as a roadblock (GameManager), so neither is in the pool.
	"siracusa": {"normal": ["family_soldier", "family_soldier", "family_intimidator"], "ranged": ["family_crossbow", "family_caster"], "elite": ["family_capo"]},
}

## Standing heights in texels of the new enemies' own boards (art/field/reduce_n1.py
## FIGURES); 暴徒 is 28. Their pick box and navigation radius scale with it
## (新敌人攻击案 §六第 11 条).
const FIGURE_HEIGHTS := {
	"armed": 32, "caster": 26, "shield": 29, "slug_volatile": 20, "picket": 29,
	"greytail": 28, "greytail_lord": 31, "thrower": 26, "bully": 33, "avenger": 30, "breacher": 32,
	"taint_husk": 29, "distorted_caster": 31, "shattered_champion": 34, "shell_vine": 22, "rock_hornbeast": 28, "fallen_snowpriest": 30,
	"sentinel": 28,
}
const BASE_FIGURE := 28.0

static func is_elite_type(type: String) -> bool:
	return bool(PROFILES.get(type, {}).get("elite", false))

## The sprite sheet a type uses: its own, or the one it borrows.
static func art_type(type: String) -> String:
	return str(PROFILES.get(type, {}).get("art", type))
const HP_PER_DEPTH := 0.12
const ATK_PER_DEPTH := 0.02
const SNOW_HP_BONUS := 0.45
const PRESSURE_DIVISOR := 160.0

static func default_type(region: String, elite: bool, ranged: bool) -> String:
	if elite: return "armed" if region == "mine" else "elite"
	match region:
		"city": return "crossbow_leader" if ranged else "brawler"
		"siracusa": return "family_crossbow" if ranged else "family_soldier"
		"snow": return "ice_hunter" if ranged else "ice_warrior"
	return "crossbow" if ranged else "thug"

static func contains(profile: Dictionary, origin: Vector3, direction: Vector3, point: Vector3, reach: float = -1.0) -> bool:
	var offset := Vector2(point.x - origin.x, point.z - origin.z)
	var forward := Vector2(direction.x, direction.z).normalized()
	var length := float(profile.reach) if reach < 0 else reach
	var along := offset.dot(forward)
	var across := absf(offset.cross(forward))
	match str(profile.shape):
		"sector":
			return offset.length() <= length and (offset.length_squared() < 0.0001 or offset.normalized().dot(forward) >= cos(deg_to_rad(float(profile.angle) * 0.5)))
		"lane", "ice":
			var lane := along >= 0 and along <= length and across <= float(profile.width) * 0.5
			return lane or (profile.shape == "ice" and offset.distance_to(forward * length) <= float(profile.impact_radius))
	return false
