class_name GpuChoice
extends RefCounted

## 显卡 (用户 2026-10-24: 能改为在设置里选显卡吗). Windows renders with D3D12
## (project.godot), which by itself takes the high-performance card. A setting
## can name another card: Godot only takes a card at launch (--gpu-index), so
## the choice applies from the next start, when the game restarts itself once
## with that card's index if it came up on a different one. "" = 自动.
##
## The cards are the PCI display adapters Windows lists, by dedicated memory,
## most first: the order D3D12 numbers them in (high performance first).
## Virtual displays (remote desktop, emulators) are left out.

static var _adapters: Array = []
static var _listed := false

## The cards' names, D3D12's order (empty off Windows or when none are found).
static func adapters() -> Array:
	if _listed: return _adapters
	_listed = true
	if OS.get_name() != "Windows": return _adapters
	var out: Array = []
	var code := OS.execute("powershell", ["-NoProfile", "-Command",
		"Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name + '|' + $_.AdapterRAM + '|' + $_.PNPDeviceID }"], out)
	if code != 0 or out.is_empty(): return _adapters
	var found: Array = []
	for line in str(out[0]).split("\n"):
		var parts := line.strip_edges().split("|")
		if parts.size() < 3 or not parts[2].begins_with("PCI\\"): continue
		found.append([parts[0], int(parts[1]) if parts[1].is_valid_int() else 0])
	found.sort_custom(func(a, b): return a[1] > b[1])
	_adapters = found.map(func(f): return f[0])
	return _adapters

## The card she picked ("" = 自动).
static func chosen() -> String:
	return str(SystemScreens.settings.get("gpu", ""))

## The card the game is drawing with now.
static func current() -> String:
	return RenderingServer.get_video_adapter_name()

## A short name for a button: "RTX 4060", "Radeon(TM) 610M".
static func short_name(name: String) -> String:
	var shown := name
	for cut in ["NVIDIA ", "GeForce ", "AMD ", "Intel(R) ", " Laptop GPU", " Graphics"]: shown = shown.replace(cut, "")
	return shown.strip_edges()

## At launch (SystemScreens, the real game only): when a card is picked and
## the game came up on another, restart once on it. True when it is restarting.
static func apply_at_start(tree: SceneTree) -> bool:
	var want := chosen()
	if want.is_empty() or current() == want: return false
	var args := OS.get_cmdline_args()
	# Already restarted for it (the card would not take): run on what there is.
	if "--gpu-index" in args: return false
	var index := adapters().find(want)
	if index < 0: return false
	OS.set_restart_on_exit(true, args + PackedStringArray(["--gpu-index", str(index)]))
	tree.quit()
	return true
