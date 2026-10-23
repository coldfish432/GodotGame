class_name Toast
extends RefCounted

## A Windows notification (交易终端与盯盘小窗策划案_v1_0.md §4), through
## PowerShell and the system's own toast API: nothing to install. Fire and
## forget; elsewhere than Windows it does nothing.

## PowerShell's registered app id, so the toast is allowed without an installer.
const APP_ID := "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe"

static func show(title: String, text: String) -> void:
	if OS.get_name() != "Windows": return
	var script := """
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
$x = New-Object Windows.Data.Xml.Dom.XmlDocument
$x.LoadXml('<toast><visual><binding template="ToastGeneric"><text>%s</text><text>%s</text></binding></visual></toast>')
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('%s').Show([Windows.UI.Notifications.ToastNotification]::new($x))
""" % [_xml(I18n.t(title)), _xml(I18n.t(text)), APP_ID]
	powershell(script)

## Runs `script` in a hidden PowerShell, not waiting. -EncodedCommand takes
## UTF-16LE in base64: no quoting trouble with Chinese text or paths.
static func powershell(script: String) -> void:
	if OS.get_name() != "Windows": return
	var utf16 := PackedByteArray()
	for c in script:
		var code := c.unicode_at(0)
		utf16.append(code & 0xFF)
		utf16.append((code >> 8) & 0xFF)
	OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-EncodedCommand", Marshalls.raw_to_base64(utf16)])

## The two desktop shortcuts (交易终端策划案 §1): 罗德岛交易终端 and 罗德岛盯盘.
static func desktop_shortcuts() -> void:
	var exe := OS.get_executable_path().replace("'", "''")
	var lines := ["$s = New-Object -ComObject WScript.Shell", "$d = [Environment]::GetFolderPath('Desktop')"]
	for entry in [["罗德岛交易终端", "exchange"], ["罗德岛盯盘", "ticker"]]:
		var args := " ".join(Array(GameManager.app_args(str(entry[1]))).map(func(a): return ('"%s"' % a) if " " in a else a)).replace("'", "''")
		lines.append("$l = $s.CreateShortcut((Join-Path $d '%s.lnk')); $l.TargetPath = '%s'; $l.Arguments = '%s'; $l.WorkingDirectory = '%s'; $l.Save()" % [entry[0], exe, args, exe.get_base_dir()])
	powershell("\n".join(lines))

## Safe inside the XML and inside PowerShell's single-quoted string.
static func _xml(text: String) -> String:
	return text.xml_escape().replace("'", "''")
