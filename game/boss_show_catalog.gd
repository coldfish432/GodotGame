class_name BossShowCatalog
extends RefCounted

## The numbers of the bosses' set pieces (Boss演出策划案_v0_2, 用户 2026-11-04:
## 都先按你推荐来, 扎罗血雾改黑雾). BossShow runs them; every second is here.

## --- The three moments (§1.2) -----------------------------------------------------------
## A first meeting (this region's boss at this tier): her hands held this long at most.
const FIRST_INTRO := 2.4
const AGAIN_INTRO := 1.0
## The camera's way over to the boss, and back.
const PAN := 0.6
const PAN_BACK := 0.4
const BAND_IN := 1.2
const BAND_OUT := 2.0
## The killing blow: frozen (real seconds), then slow, then a white flash.
const KILL_FREEZE := 0.12
const SLOW_SCALE := 0.3
const SLOW_TIME := 0.6
## A phase change's freeze (real seconds).
const PHASE_FREEZE := 0.08
## How long a boss takes to go after the slow motion (game seconds), and a warden.
const FINALE := 1.5
const WARDEN_FINALE := 0.8
const WARDEN_FREEZE := 0.08
## Her fall: the boss's winning pose before the fall is settled.
const VICTORY := 1.2
## The scene's look eases to a stage over this long.
const SHADE_EASE := 1.0
## The screen flash (§6.1, ≤30%).
const FLASH_ALPHA := 0.3
const FLASH_TIME := 0.1

## --- Who they are on screen ---------------------------------------------------------------
## main/hot as BossVfx.PALETTES; mist: 扎罗's black mist (用户 2026-11-04).
const MIST := Color("141216")
const MIST_EDGE := Color("766a72")
## Each boss's light (§1.4): its colour and energy, and a flare on each blow.
const LIGHT := {
	"patriot": [Color("ff9a48"), 0.6], "rat_king": [Color("e8c878"), 0.45],
	"eikthyrnir": [Color("9ee8ff"), 0.55], "zaro": [Color("c0392b"), 0.4],
}

## The scene by phase (§2.3, §3.3, §4.3, §5.3; ≤25% darker, Q7): `dim` off the
## filter's brightness, the ambient and sun pulled `k` toward `tint`; `lamps`:
## the arena's lamps × `mult`, pulled `k` toward `tint`. Index 0 is the first phase.
const STAGES := {
	"patriot": [
		{"dim": 0.06, "tint": Color("5a6a8a"), "k": 0.2},
		{"dim": 0.08, "tint": Color("ff8a2a"), "k": 0.3, "lamps": {"mult": 1.2, "tint": Color("ff9a48"), "k": 0.5}},
		{"dim": 0.12, "tint": Color("ff8a2a"), "k": 0.5, "lamps": {"mult": 1.4, "tint": Color("ff8a2a"), "k": 0.8}},
	],
	# 用户 2026-11-05: 整个场景都太黑了，可以调亮，转阶段可以用轻微的风沙模拟变暗 —
	# brighter than the street; each phase only a little dimmer, the rest is sand in the air (haze).
	"rat_king": [
		# 用户 2026-11-05: 鼠王本身有点太亮了 — the brightening is light on the scene
		# (ambient × `ambient`), not the screen filter, which lifted the sprites too.
		{"dim": 0.0, "tint": Color("e8c890"), "k": 0.12, "ambient": 1.8},
		{"dim": 0.03, "tint": Color("d8b070"), "k": 0.22, "haze": 1.0, "ambient": 1.7},
		{"dim": 0.06, "tint": Color("c8a060"), "k": 0.3, "haze": 2.0, "ambient": 1.6},
	],
	"eikthyrnir": [
		{"dim": 0.04, "tint": Color("bfe8ff"), "k": 0.15},
		{"dim": 0.1, "tint": Color("8ac8e8"), "k": 0.3},
		{"dim": 0.16, "tint": Color("6aa8d8"), "k": 0.45},
	],
	"zaro": [
		{"dim": 0.14, "tint": Color("3a2a40"), "k": 0.3},
		{"dim": 0.18, "tint": Color("8a1c22"), "k": 0.35},
		{"dim": 0.24, "tint": Color("5a1018"), "k": 0.45},
	],
}
## 扎罗: the arena's string lights redden with 血债 (0 warm → DEBT_RED dark red).
const DEBT_RED := 90.0
const DEBT_LAMP := Color("8a1c22")
## 清算时刻 darkens the scene a further step.
const RECKONING_DIM := 0.06

## The rows it holds in a set piece (BossCatalog.POSES numbering): Sol's B3
## rows (art/field/batch_B3_v1, accepted 2026-11-04) below the B1 ones.
const SHOW_ROWS := {
	"patriot": {"kneel": 9, "rise": 10, "victory": 12, "dies": 15},
	"rat_king": {"poised": 8, "cane_across": 10, "kneel": 12, "dies": 12, "victory": 13},
	"eikthyrnir": {"break": 9, "roar": 8, "clutch": 12, "dies": 13, "victory": 14},
	"zaro": {"asleep": 9, "lift": 10, "struggle": 12, "dies": 6, "victory": 8},
	"crownslayer": {"intro": 7, "dies": 8},
	"skullshatterer": {"intro": 6, "dies": 7},
	"hollow_snowpriest": {"intro": 7, "dies": 8},
	"father_agnir": {"intro": 6, "dies": 7},
}

## How each one goes (§2.7, §3.7, §4.7, §5.7, §6): the husk's dissolve
## (0 none, 1 feet up, 2 edge in), the colour it fades to, its edge, whether it stays.
const FINALES := {
	"patriot": {"mode": 0, "fade_colour": Color("26272b"), "fade_to": 0.3, "edge": Color("ffb060"), "stays": true},
	"rat_king": {"mode": 1, "fade_colour": Color("c8a868"), "edge": Color("f6e4a8"), "stays": false},
	"eikthyrnir": {"mode": 2, "fade_colour": Color("cfeefa"), "edge": Color("ffffff"), "stays": false},
	"zaro": {"mode": 2, "fade_colour": Color("1a1618"), "edge": Color("3a3238"), "stays": false},
	"crownslayer": {"mode": 2, "fade_colour": Color("6a6a70"), "edge": Color("c8c8d0"), "stays": false},
	"skullshatterer": {"mode": 1, "fade_colour": Color("4a4a50"), "edge": Color("ffb060"), "stays": false},
	"hollow_snowpriest": {"mode": 1, "fade_colour": Color("2a3050"), "edge": Color("dceefa"), "stays": false},
	"father_agnir": {"mode": 1, "fade_colour": Color("8a8690"), "edge": Color("fffbe8"), "stays": false},
}
