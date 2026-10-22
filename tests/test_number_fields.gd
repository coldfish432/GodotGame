extends SceneTree

## 用户 2026-10-21: the exchange's amounts can be typed, 赤金 and 龙门币 to two
## decimals; the commodity pickers step with ◀ ▶.

var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func run() -> void:
	check("amounts show with two decimals and thousands", ExchangeScreen.number_text(1234.5, 2) == "1,234.50", ExchangeScreen.number_text(1234.5, 2))
	check("counts show whole", ExchangeScreen.number_text(12.0, 0) == "12")
	check("typed numbers read with commas", is_equal_approx(ExchangeScreen.parse_number(" 1,000.25 "), 1000.25))
	check("text that is no number is refused", is_nan(ExchangeScreen.parse_number("abc")))
	var box := VBoxContainer.new()
	root.add_child(box)
	var got := [0.0]
	var field := ExchangeScreen._number(box, "龙门币", 1000.0, 2, 1000.0, 0.01, func(v): got[0] = v)
	field.text = "2500.456"
	field.text_submitted.emit(field.text)
	check("a typed amount is kept to two decimals", is_equal_approx(got[0], 2500.46), got[0])
	field.text = "-5"
	field.text_submitted.emit(field.text)
	check("and never under its floor", is_equal_approx(got[0], 0.01), got[0])
	var whole_box := VBoxContainer.new()
	root.add_child(whole_box)
	ExchangeScreen._number(whole_box, "龙门币", 1000.0, 2, 1000.0, 0.01, func(v): got[0] = v, "", func(): return 6543.219)
	var whole: Button = null
	for b in whole_box.get_child(0).get_children():
		if b is Button and b.text == "全部": whole = b
	check("全部 is there", whole != null)
	whole.pressed.emit()
	check("and sets all of it, cut to two decimals", is_equal_approx(got[0], 6543.21), got[0])
	var picks := VBoxContainer.new()
	root.add_child(picks)
	ExchangeScreen._picker(picks, "商品", "胶带", func(): pass, func(): pass)
	var texts: Array = []
	for b in picks.get_child(0).get_children():
		if b is Button: texts.append(b.text)
	check("the picker steps with ◀ ▶", texts == ["◀", "▶"], texts)
	print("NUMBER FIELDS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
