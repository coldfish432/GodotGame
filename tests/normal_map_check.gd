extends SceneTree
## A5 normal-map check (CHANGE-BRIEF.md F8). curl_ratio and its helpers are the
## assignment's code, copied unchanged; tests/test_materials.gd preloads this file.
## Run on its own, it calibrates on the Poly Haven _nor_gl/_nor_dx pair of
## rusty_metal_sheet (agent-written runner):
##   ./scripts/run-test.sh normal_map_check.gd 60

# ~0: slope field of a real surface in this convention.
# ~1: no surface behind it.
# ~2: real surface, other green convention.
static func curl_ratio(source: Image, directx := false, stride := 4) -> float:
    var img := source.duplicate() as Image
    if img.is_compressed():
        img.decompress()
    var s: float = -1.0 if directx else 1.0
    var curl_sq := 0.0
    var terms_sq := 0.0
    for v in range(1, img.get_height() - 1, stride):
        for u in range(1, img.get_width() - 1, stride):
            var t1 := (_dh_du(img, u, v + 1) - _dh_du(img, u, v - 1)) * 0.5
            var t2 := (_dh_dv(img, u + 1, v, s) - _dh_dv(img, u - 1, v, s)) * 0.5
            curl_sq += (t1 - t2) * (t1 - t2)
            terms_sq += t1 * t1 + t2 * t2
    return curl_sq / maxf(terms_sq, 1e-12)


static func _normal(img: Image, u: int, v: int) -> Vector3:
    var c := img.get_pixel(u, v)
    return Vector3(c.r, c.g, c.b) * 2.0 - Vector3.ONE


static func _dh_du(img: Image, u: int, v: int) -> float:
    var n := _normal(img, u, v)
    return -n.x / maxf(n.z, 0.05)


static func _dh_dv(img: Image, u: int, v: int, s: float) -> float:
    var n := _normal(img, u, v)
    return s * n.y / maxf(n.z, 0.05)


# --- calibration runner (agent-written) ---

const DIR := "res://textures/cargo_panel/"

func _initialize() -> void:
    var rows := []
    for name in ["rusty_metal_sheet_nor_gl_1k", "rusty_metal_sheet_nor_dx_1k"]:
        var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + name + ".png"))
        rows.append(["source " + name, img])
    for name in ["rusty_metal_sheet_nor_gl_1k", "rusty_metal_sheet_nor_dx_1k", "rusty_metal_sheet_nor_dx_1k_inverty"]:
        rows.append(["imported " + name, (load(DIR + name + ".png") as Texture2D).get_image()])
    for row in rows:
        var gl := curl_ratio(row[1], false)
        var dx := curl_ratio(row[1], true)
        print("CURL_RATIO %-48s directx=false %.4f  directx=true %.4f" % [row[0], gl, dx])
    quit(0)
