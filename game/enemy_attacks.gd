class_name EnemyAttacks
extends RefCounted
## Distances are world units. With no ground warning, the windup itself is the
## warning, so ordinary windups run about 0.25 s longer than the old telegraphs.
## interval is the wait after the strike begins before the next windup may start
## (the pre-rework meaning), so one full cycle lasts windup + interval.
## Every ordinary attack is physical. Only the retained elite profile telegraphs,
## and its strike is arts damage: 策划案 §5 shows red ground for elites and arts.
## "damage" is the attack's multiplier on the enemy's ATK (all 1.0 for now);
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
	"elite": {"name": "精英重击", "attack": "重击", "row": -1, "windup": 1.0, "interval": 2.1, "damage": 1.0, "shape": "circle", "reach": 2.4, "radius": 1.65, "recovery": 0.3},
}

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
}
const HP_PER_DEPTH := 0.12
const ATK_PER_DEPTH := 0.02
const SNOW_HP_BONUS := 0.45
const PRESSURE_DIVISOR := 160.0

static func default_type(region: String, elite: bool, ranged: bool) -> String:
	if elite and region != "mine": return "elite"
	match region:
		"city": return "crossbow_leader" if ranged else "brawler"
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
