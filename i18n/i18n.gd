class_name I18n
extends RefCounted

## 中文 / English (用户 2026-10-13: 做双语版，可在设置中切换).
##
## The game keeps all its text, data and keys in Chinese; English is applied
## when text is shown. Controls (Label, Button, tooltips …) translate their own
## text through Godot's TranslationServer, where DownfallTranslation answers
## with translate() below; text drawn by hand (HUD draw_string) calls t().
##
## translate(): a whole-string hit in i18n/en.json, else the string is read
## left to right and every key found there is replaced, longest first, so a
## formatted message ("合同开始：" + region name + "。") is covered by its
## fragments and the names filled into it. Full-width punctuation left over
## becomes English punctuation. Keys come from tools/i18n/extract.py.
##
## A key with %s / %d in it is a whole-sentence template, for messages whose
## English word order differs ("从%s出发" → "Start at %s"): a shown string
## that matches it whole is rebuilt in English with its filled-in parts,
## each translated in turn. %1$s-style indices in the English reorder them.

const TABLE_PATH := "res://i18n/en.json"
const LANGUAGES := ["zh", "en"]
const PUNCT := {
	"：": ": ", "，": ", ", "。": ". ", "、": ", ", "；": "; ", "（": " (", "）": ") ",
	"！": "! ", "？": "? ", "《": "“", "》": "”", "【": "[", "】": "]", "～": "~", "　": " ",
}
const CACHE_LIMIT := 8000

static var language := "zh"
static var _table := {}
static var _by_first := {}
static var _templates: Array = []  # [RegEx, English]
static var _cache := {}
static var _translation: Translation
static var _registered := false
## Chinese text shown in English mode with no key for it (for the coverage test).
static var missing := {}

## Switches the shown language now; every Control re-reads its text.
static func set_language(lang: String) -> void:
	language = lang if lang in LANGUAGES else "zh"
	_cache.clear()
	if language == "en":
		_load()
		if _translation == null:
			_translation = DownfallTranslation.new()
			_translation.locale = "en"
		if not _registered:
			TranslationServer.add_translation(_translation)
			_registered = true
		TranslationServer.set_locale("en")
	else:
		# Off the server entirely: its fallback locale is English, so a
		# registered English table would answer for Chinese too.
		if _registered:
			TranslationServer.remove_translation(_translation)
			_registered = false
		TranslationServer.set_locale("zh")
	_refit_all()

## After a switch: fixed boxes size their text again (AK.fit).
static func _refit_all() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return
	for node in tree.get_nodes_in_group("ak_fit"): AK.refit(node)

static func is_english() -> bool:
	return language == "en"

## `text` as shown in the current language (for text drawn by hand).
static func t(text: String) -> String:
	return translate(text) if language == "en" else text

static func _load() -> void:
	if not _table.is_empty(): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH)) if FileAccess.file_exists(TABLE_PATH) else null
	if not parsed is Dictionary:
		push_warning("I18n: no table at " + TABLE_PATH)
		return
	_table = parsed
	for key: String in _table:
		if key.is_empty(): continue
		if key.contains("%s") or key.contains("%d"):
			_templates.append([_template_regex(key), str(_table[key])])
			continue
		var first := key[0]
		if not _by_first.has(first): _by_first[first] = []
		_by_first[first].append(key)
	for first in _by_first:
		_by_first[first].sort_custom(func(a: String, b: String): return a.length() > b.length())

static func _template_regex(key: String) -> RegEx:
	var pattern := "^"
	var i := 0
	while i < key.length():
		if key.substr(i, 2) == "%s":
			pattern += "(.+?)"
			i += 2
		elif key.substr(i, 2) == "%d":
			pattern += "([-+]?\\d+)"
			i += 2
		else:
			var c := key[i]
			pattern += ("\\" + c) if "^$.|?*+()[]{}\\".contains(c) else c
			i += 1
	var regex := RegEx.new()
	regex.compile(pattern + "$")
	return regex

static func _fill(english: String, parts: Array) -> String:
	var out := english
	for n in range(parts.size()):
		out = out.replace("%%%d$s" % (n + 1), parts[n]).replace("%%%d$d" % (n + 1), parts[n])
	for part in parts:
		var at := out.find("%s")
		var at_d := out.find("%d")
		if at < 0 or (at_d >= 0 and at_d < at): at = at_d
		if at < 0: break
		out = out.substr(0, at) + part + out.substr(at + 2)
	return out

static func has_cjk(text: String) -> bool:
	for i in range(text.length()):
		var c := text.unicode_at(i)
		if (c >= 0x4e00 and c <= 0x9fff) or (c >= 0x3000 and c <= 0x303f) or (c >= 0xff00 and c <= 0xffef): return true
	return false

static func translate(text: String) -> String:
	if text.is_empty() or not has_cjk(text): return text
	if _cache.has(text): return _cache[text]
	var result: String
	var templated := false
	if _table.has(text):
		result = _table[text]
	else:
		for template in _templates:
			var found: RegExMatch = (template[0] as RegEx).search(text)
			if found == null: continue
			var parts: Array = []
			for g in range(1, found.get_group_count() + 1): parts.append(translate(found.get_string(g)))
			result = _fill(template[1], parts)
			templated = true
			break
	if not templated and not _table.has(text):
		var out := ""
		var i := 0
		while i < text.length():
			var c := text[i]
			var hit := ""
			for key: String in _by_first.get(c, []):
				if text.substr(i, key.length()) != key: continue
				# One character alone (区, 缓, 层 …) only as a word of its own:
				# inside 下城区 or 缓释凝胶 it is part of a longer name.
				if key.length() == 1 and (_ideograph(text, i - 1) or _ideograph(text, i + 1)): continue
				hit = key
				break
			if not hit.is_empty():
				out = _join(out, str(_table[hit]))
				i += hit.length()
				continue
			if PUNCT.has(c): out += PUNCT[c]
			else:
				if has_cjk(c): missing[text] = true
				out += c
			i += 1
		result = _tidy(out)
	if _cache.size() > CACHE_LIMIT: _cache.clear()
	_cache[text] = result
	return result

static func _ideograph(text: String, i: int) -> bool:
	if i < 0 or i >= text.length(): return false
	var c := text.unicode_at(i)
	return c >= 0x4e00 and c <= 0x9fff

## Two English pieces run together get a space between them.
static func _join(out: String, piece: String) -> String:
	if out.is_empty() or piece.is_empty(): return out + piece
	var last := out[out.length() - 1]
	var first := piece[0]
	if _wordy(last) and (_wordy(first) or first == "("): return out + " " + piece
	return out + piece

static func _wordy(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == ")" or c == "%"

static func _tidy(text: String) -> String:
	while text.contains("  "): text = text.replace("  ", " ")
	for p in [" .", " ,", " :", " ;", " )", " !", " ?"]:
		text = text.replace(p, p.substr(1))
	text = text.replace("( ", "(")
	return text.strip_edges(false, true)
