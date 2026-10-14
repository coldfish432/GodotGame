extends SceneTree

## 中文 / English (用户 2026-10-13: 做双语版，可在设置中切换; i18n/i18n.gd):
## Chinese is untouched, every extracted key has English and comes out with no
## Chinese left, fragments join into sentences, templates reorder, a lone
## character only translates as a word of its own, Controls follow the
## switch, and the switch back leaves no English behind.

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	I18n.set_language("zh")
	check("Chinese mode shows the source text", I18n.t("合同开始：") == "合同开始：" and tr("背包") == "背包")

	I18n.set_language("en")
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/en.json"))
	var keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/keys.json"))
	var missing := keys.keys().filter(func(k): return not table.has(k))
	check("every extracted key has English (run tools/i18n/extract.py and merge.py)", missing.is_empty(), missing.slice(0, 20))
	# An entry whose English is its own key ("中文" on the language toggle, a URL) is left as it is on purpose.
	var leftover := table.keys().filter(func(k): return str(table[k]) != k and I18n.has_cjk(I18n.translate(k)))
	check("no key comes out with Chinese left in it", leftover.is_empty(), leftover.slice(0, 20))
	check("whole keys translate", I18n.t("背包") == str(table["背包"]))
	check("a template reorders", I18n.t("从营地 10出发").begins_with("Start at "), I18n.t("从营地 10出发"))
	check("full-width punctuation becomes English", not I18n.has_cjk(I18n.t("合同开始：" + "切尔诺伯格 · 坍塌矿区" + "。")), I18n.t("合同开始：切尔诺伯格 · 坍塌矿区。"))
	check("numbers and codes pass through", I18n.t("LG-01 · 2400 / 2400") == "LG-01 · 2400 / 2400")
	var zone := str(table["区"]).strip_edges()
	check("a lone character is not taken out of a longer word", not I18n.translate("甲区乙").contains(zone), I18n.translate("甲区乙"))
	check("but is translated as a word of its own", I18n.translate("材料区").contains(zone) or I18n.translate("3 区").contains(zone), I18n.translate("3 区"))
	var label := Label.new()
	label.text = "背包"
	root.add_child(label)
	await process_frame
	check("a Label shows English", label.tr(label.text) == str(table["背包"]))

	I18n.set_language("zh")
	await process_frame
	check("back in Chinese, a Label shows Chinese again", label.tr(label.text) == "背包")
	check("and hand-drawn text too", I18n.t("背包") == "背包")

	print("\n%d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
