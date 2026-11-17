class_name FactionAICatalog
extends RefCounted

## 罗德岛运营与资产管理策划案 v0.12 §3.8.3 / §3.8.7 / §3.9.4: what each faction
## eats and sells (categories that have books), its starting cash (龙门币), its
## character, and the attitudes between factions. The categories follow
## FactionCatalog's prefs (what it buys) and its shelf (what it sells).

## Personality keys (§3.8.7), 0–1: risk aversion, patience, value tilt (1 − trend
## tilt), credulity, revenge, cash preference.
const TRAITS := ["risk", "patience", "value", "credulity", "revenge", "cash"]

## use: category -> 龙门币 of base price a day; make: category -> the same it
## sells a day (onto the books that buy it); cash: starting 龙门币 equivalent.
const FACTIONS := {
	"lungmen": {"use": {"armor": 9000, "medical": 8000, "crop": 6000}, "make": {"build": 5000, "electronic": 3000}, "cash": 4000000.0, "seasonal": true,
		"traits": {"risk": 0.75, "patience": 0.7, "value": 0.7, "credulity": 0.3, "revenge": 0.4, "cash": 0.6}},
	"rat": {"use": {"contraband": 6000, "weapon": 5000}, "make": {"contraband": 4000, "electronic": 4000}, "cash": 900000.0, "night": true,
		"traits": {"risk": 0.3, "patience": 0.35, "value": 0.4, "credulity": 0.75, "revenge": 0.85, "cash": 0.3}},
	"rhine": {"use": {"originium": 9000, "electronic": 6000}, "make": {"medical": 7000, "elite": 5000}, "cash": 3000000.0,
		"traits": {"risk": 0.55, "patience": 0.85, "value": 0.65, "credulity": 0.3, "revenge": 0.3, "cash": 0.35}},
	"karlan": {"use": {"crop": 3000, "fuel": 5000}, "make": {"cold": 5000, "elite": 3000}, "cash": 2500000.0, "maker": true,
		"traits": {"risk": 0.5, "patience": 0.5, "value": 0.5, "credulity": 0.4, "revenge": 0.3, "cash": 0.5}},
	"ursus": {"use": {"fuel": 7000, "cold": 3000}, "make": {"originium": 8000, "build": 6000}, "cash": 1200000.0, "volatile": true,
		"traits": {"risk": 0.4, "patience": 0.4, "value": 0.5, "credulity": 0.5, "revenge": 0.6, "cash": 0.7}},
	"reunion": {"use": {"weapon": 4000, "medical": 4000}, "make": {"contraband": 2000, "originium": 2000}, "cash": 200000.0, "no_credit": true,
		"traits": {"risk": 0.2, "patience": 0.2, "value": 0.35, "credulity": 0.7, "revenge": 0.95, "cash": 0.2}},
	"sami": {"use": {"fuel": 2000, "medical": 2000}, "make": {"crop": 1500, "cold": 1500}, "cash": 150000.0, "income": 1.5,
		"traits": {"risk": 0.6, "patience": 0.6, "value": 0.6, "credulity": 0.4, "revenge": 0.4, "cash": 0.95}},
	"kazimierz": {"use": {"weapon": 8000, "armor": 7000, "build": 6000}, "make": {"trinket": 6000}, "cash": 6000000.0, "investor": "kaz",
		"traits": {"risk": 0.45, "patience": 0.55, "value": 0.45, "credulity": 0.4, "revenge": 0.5, "cash": 0.25}},
	"penguin": {"use": {"fuel": 3000}, "make": {}, "cash": 800000.0, "carrier": true,
		"traits": {"risk": 0.6, "patience": 0.6, "value": 0.6, "credulity": 0.3, "revenge": 0.1, "cash": 0.6}},
}

## §3.9.4: A -> B starting attitude (−1000…1000); everything else 0.
const BASE_RELATIONS := {
	"lungmen": {"rat": -600, "reunion": -500},
	"rat": {"lungmen": -600},
	"reunion": {"ursus": -800, "lungmen": -700},
	"ursus": {"reunion": -800},
	"kazimierz": {"reunion": -300},
	"karlan": {"sami": 350},
	"sami": {"karlan": 350},
}

## §3.9.4 tiers.
const HOSTILE := -500
const COOL := -100
const FRIENDLY := 300

static func info(f: String) -> Dictionary:
	return FACTIONS.get(f, {})

static func base_relation(a: String, b: String) -> int:
	return int((BASE_RELATIONS.get(a, {}) as Dictionary).get(b, 0))

## "敌对" / "冷淡" / "中立" / "友好".
static func tier_name(v: float) -> String:
	if v <= HOSTILE: return "敌对"
	if v <= COOL: return "冷淡"
	if v > FRIENDLY: return "友好"
	return "中立"

## §3.9.3 张力: 1 hostile, 0.5 cool, else 0.
static func tension(v: float) -> float:
	if v <= HOSTILE: return 1.0
	if v <= COOL: return 0.5
	return 0.0
