extends SceneTree
## A5 (agent-written; CHANGE-BRIEF.md F8): an extra curl measure, not the
## assignment's curl_ratio (that one is tests/normal_map_check.gd). A tangent-space
## normal map baked from a height field is a gradient, so its slope field has
## no curl, but only under the green convention it was baked with. With the
## slopes sx = nx/nz, sy = ny/nz taken in image coordinates (x right, rows
## down; v = -row), the residual that must vanish is
##   OpenGL (+Y up):   d(sy)/dx + d(sx)/dy
##   DirectX (+Y down): d(sy)/dx - d(sx)/dy
## Each map is scored under both; a map's own convention gives the smaller
## residual. Godot's NORMAL_MAP expects OpenGL. Checked on the source PNGs and
## on what the imports load as (decompressed BC5, Z rebuilt as Godot does).

const DIR := "res://textures/cargo_panel/"
var failures := 0

func check(label: String, passed: bool, detail = "") -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if str(detail) == "" else "  [" + str(detail) + "]"))

## Mean |residual| under the GL and DX hypotheses, every second texel in both
## directions (central differences, edges skipped).
func residuals(img: Image) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	var sx := PackedFloat32Array(); sx.resize(w * h)
	var sy := PackedFloat32Array(); sy.resize(w * h)
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			var nx := c.r * 2.0 - 1.0
			var ny := c.g * 2.0 - 1.0
			var nz := sqrt(maxf(1.0 - nx * nx - ny * ny, 1e-4))
			sx[y * w + x] = nx / nz
			sy[y * w + x] = ny / nz
	var gl := 0.0
	var dx := 0.0
	var n := 0
	for y in range(1, h - 1, 2):
		for x in range(1, w - 1, 2):
			var dsy_dx := (sy[y * w + x + 1] - sy[y * w + x - 1]) * 0.5
			var dsx_dy := (sx[(y + 1) * w + x] - sx[(y - 1) * w + x]) * 0.5
			gl += absf(dsy_dx + dsx_dy)
			dx += absf(dsy_dx - dsx_dy)
			n += 1
	return Vector2(gl / n, dx / n)

func source(name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + name + ".png"))
	img.convert(Image.FORMAT_RGB8)
	return img

func imported(name: String) -> Image:
	var img := (load(DIR + name + ".png") as Texture2D).get_image()
	if img.is_compressed(): img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGB8)
	return img

func _initialize() -> void:
	var src_gl := source("rusty_metal_sheet_nor_gl_1k")
	var src_dx := source("rusty_metal_sheet_nor_dx_1k")
	# Poly Haven's two maps should be one map with green flipped.
	var off := 0.0
	var red := 0.0
	for y in range(0, 1024, 4):
		for x in range(0, 1024, 4):
			var a := src_gl.get_pixel(x, y)
			var b := src_dx.get_pixel(x, y)
			off += absf(roundf(a.g * 255.0) + roundf(b.g * 255.0) - 255.0)
			red += absf(roundf(a.r * 255.0) - roundf(b.r * 255.0))
	var samples := 256.0 * 256.0
	print("SOURCE mean |G_gl + G_dx - 255| = %.3f, mean |R_gl - R_dx| = %.3f" % [off / samples, red / samples])
	check("source: DX green is GL green flipped (mean |G_gl + G_dx - 255| <= 1 level)", off / samples <= 1.0, off / samples)
	check("source: red channels agree (mean |R_gl - R_dx| <= 1 level)", red / samples <= 1.0, red / samples)

	var rows := {
		"source nor_gl": src_gl, "source nor_dx": src_dx,
		"imported nor_gl": imported("rusty_metal_sheet_nor_gl_1k"),
		"imported nor_dx (invert_y off)": imported("rusty_metal_sheet_nor_dx_1k"),
		"imported nor_dx_inverty (invert_y on)": imported("rusty_metal_sheet_nor_dx_1k_inverty"),
	}
	var scores := {}
	for label in rows:
		var r := residuals(rows[label])
		scores[label] = r
		print("CURL %-40s GL-residual %.5f  DX-residual %.5f  ratio GL/DX %.3f" % [label, r.x, r.y, r.x / r.y])
	check("source GL map is curl-free under the GL convention (GL residual < DX residual)", scores["source nor_gl"].x < scores["source nor_gl"].y, scores["source nor_gl"])
	check("source DX map is curl-free under the DX convention", scores["source nor_dx"].y < scores["source nor_dx"].x, scores["source nor_dx"])
	check("imported GL map still reads as GL", scores["imported nor_gl"].x < scores["imported nor_gl"].y, scores["imported nor_gl"])
	check("imported DX map with invert_y off still reads as DX (wrong for NORMAL_MAP)", scores["imported nor_dx (invert_y off)"].y < scores["imported nor_dx (invert_y off)"].x)
	check("imported DX map with invert_y on reads as GL (fixed)", scores["imported nor_dx_inverty (invert_y on)"].x < scores["imported nor_dx_inverty (invert_y on)"].y, scores["imported nor_dx_inverty (invert_y on)"])

	# The fixed DX import against the GL import, texel by texel (R and G; B is rebuilt).
	var a := rows["imported nor_gl"] as Image
	var b := rows["imported nor_dx_inverty (invert_y on)"] as Image
	var diff := 0.0
	for y in range(0, 1024, 2):
		for x in range(0, 1024, 2):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			diff += absf(p.r - q.r) * 255.0 + absf(p.g - q.g) * 255.0
	diff /= 512.0 * 512.0 * 2.0
	print("FIXED vs GL mean |delta| per channel (R,G) = %.3f levels" % diff)
	check("imported, fixed DX matches imported GL within 2 levels per channel on average", diff <= 2.0, diff)

	# The materials the game uses bind the GL map.
	for path in ["res://materials/cargo_panel_mild.tres", "res://materials/cargo_panel_weathered.tres"]:
		var tex := (load(path) as ShaderMaterial).get_shader_parameter("normal_tex") as Texture2D
		check("%s binds _nor_gl" % path.get_file(), tex != null and tex.resource_path.ends_with("rusty_metal_sheet_nor_gl_1k.png"), tex.resource_path if tex else "null")
	print("NORMAL MAP CHECK: %d failures" % failures)
	quit(1 if failures > 0 else 0)
