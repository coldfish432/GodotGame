extends SceneTree
## 显卡 (用户 2026-10-24: 能改为在设置里选显卡吗): the cards Windows lists, real
## ones only, most memory first (D3D12's order); 自动 never restarts; the row
## is on the 画面 settings page.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
func run() -> void:
	var names := GpuChoice.adapters()
	print("ADAPTERS ", names)
	check("only real cards (no virtual displays)", names.all(func(n): return not "Virtual" in str(n) and not "Idd" in str(n)))
	if OS.get_name() == "Windows": check("at least one card listed on Windows", not names.is_empty())
	check("short names drop the vendor words", GpuChoice.short_name("NVIDIA GeForce RTX 4060 Laptop GPU") == "RTX 4060" and GpuChoice.short_name("AMD Radeon(TM) 610M") == "Radeon(TM) 610M")
	SystemScreens.settings.gpu = ""
	check("自动 never restarts", not GpuChoice.apply_at_start(self))
	var row := SystemScreens.gpu_toggle(func(): pass)
	var buttons := row.find_children("*", "Button", true, false)
	check("the row: 自动 and one button per card", buttons.size() == names.size() + 1 and (buttons[0] as Button).text == "自动")
	row.free()
	check("project renders with D3D12 on Windows", str(ProjectSettings.get_setting("rendering/rendering_device/driver.windows", "")) == "d3d12")
	print("GPU FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
