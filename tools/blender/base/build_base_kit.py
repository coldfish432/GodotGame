"""Rhodes Island base, modelled (基地建模改造案_v1 §二, 用户 2026-10-18: 基地也改为
建模). B-M1: the bridge hall's shell pieces and props, art/kit/base_<name>.glb.

Sizes follow the hall's old pixel props (15 px a unit across), so the layout in
art/rhodes_runtime/room_hall.json still fits. Materials are procedural until
Sol's swatches (R1–R8) arrive; a part named "glow" is drawn self-lit.

Blender Z up, metres; origin at the bottom centre; the side facing the room
(and the camera) is Blender +Y (Godot -Z, north of the camera). Through the
MCP add-on:

    import build_base_kit as k; k.build("base_desk")
"""
import math
import os
import re
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "kit"))
import bpy  # noqa: E402
import mathutils  # noqa: E402
import kit_common as kit  # noqa: E402
import poi_detail as d  # noqa: E402
import build_city_kit as city  # noqa: E402
from build_encounter import decal  # noqa: E402
from build_siracusa_kit import new_scene  # noqa: E402

# Palette: 罗德岛基地美术策划案 v1.0 §3.1.
HULL = "4a5258"      # ship steel
PANEL = "7d868d"     # cold grey
WHITE = "dfe4e6"     # medical white
BLUE = "3a6f9e"      # Rhodes blue
SAFETY = "d8a520"    # safety yellow
ORANGE = "d0662a"    # warning orange
SCREEN = "6fd8e4"    # screen cyan
RUBBER = "34383c"
TEAL = "3fa8a0"      # medical accent


# Sol's hand-painted swatches (基地材质美术需求_v1 R2, R4–R9), 42.67 px a metre,
# in art/kit/textures/painted/. Each is used once it is there; until then the
# procedural materials below stand in. R2, R7 and R8 are neutral grey and
# coloured per part; R4, R5 and R6 are drawn in colour.
PAINTED = os.path.join(os.path.dirname(__file__), "..", "..", "..", "art", "kit", "textures", "painted")
## [file, metres a tile, tinted?] by swatch.
SWATCHES = {
    "steel": ("base_steel.png", 6.0, True),
    "hazard": ("base_hazard.png", 3.0, False),
    "grating": ("base_grating.png", 3.0, False),
    "screen": ("base_screen.png", 6.0, False),
    "fabric": ("base_fabric.png", 3.0, True),
    "container": ("base_container.png", 3.0, True),
}
## Which materials take which swatch, by material name (steel() takes R2).
HAZARD = re.compile(r"_hz_m$|^base_barrier_stripe_m$")
FABRIC = re.compile(r"(seat|chair|_mat|_bl|_pad|curtain)_m$")
CONTAINER = re.compile(r"^base_(ct_(grey|blue|orange)|c[kml][so](_lid)?|crate|cv_box|cc_box)_m$")
GRATING = {"base_hl_m", "base_cl2_deck_m", "base_fj_m", "base_lc_grate_m"}
SCREENS = {"base_console_glow_m", "base_desk_glow_m", "base_hang_glow_m", "base_counter_glow_m", "base_bs_scr_m",
           "base_iw_screen_m", "base_fa_scr_m", "base_sc_glow_m", "base_ab_glow_m", "base_mr_glow_m", "base_mi_glow_m",
           "base_mm_glow_m", "base_me_glow_m", "base_cc_glow_m", "base_bw_mon_m", "base_bw_screen_m",
           "base_bs2_scr_m", "base_ns_glow_m", "base_os_scr_m", "base_cr2_glow_m", "base_mk_glow_m",
           "base_cd_scr_m", "base_mw_scr_m", "base_ec_scr_m", "base_pd_glow_m", "base_it_glow_m", "base_fb_glow_m", "base_htd_glow_m",
           "base_td_scr_m", "base_tp_scr_m", "base_lc_scr_m", "base_lsc_scr_m", "base_lfh_scr_m", "base_lrh_scr_m"}
## A neutral swatch times its colour comes out darker: lifted back by this.
TINT_GAIN = 1.7


def _swatch_ready(kind):
    return os.path.exists(os.path.join(PAINTED, SWATCHES[kind][0]))


def swatch_material(name, kind, hex_rgb=None):
    """A material on Sol's swatch `kind`, box-projected in metres from the
    part's own space, coloured by `hex_rgb` when the swatch is neutral."""
    file, metres, tinted = SWATCHES[kind]
    mat, nodes, links = city._new(name)
    colour = city._swatch(nodes, links, file, metres)
    if tinted and hex_rgb:
        colour = city._tinted(nodes, links, colour, hex_rgb, TINT_GAIN)
    links.new(colour, kit.principled(nodes).inputs["Base Color"])
    return mat


def _routed(name, hex_rgb):
    """The swatch material for `name` if its swatch is in, else None."""
    for kind, test in (("hazard", lambda n: HAZARD.search(n)), ("fabric", lambda n: FABRIC.search(n)),
                       ("container", lambda n: CONTAINER.match(n)), ("grating", lambda n: n in GRATING)):
        if test(name) and _swatch_ready(kind):
            return swatch_material(name, kind, hex_rgb)
    return None


def _darker(hex_rgb, k=0.82):
    return "".join(f"{int(int(hex_rgb[i:i + 2], 16) * k):02x}" for i in (0, 2, 4))


def steel(name, seed, base=PANEL):
    """Painted ship steel: clean, faintly mottled, lighter worn edges and a
    little grime in the corners (a ship kept in order, not a ruin). On Sol's
    R2 once it is in (or R5/R8 for the parts that take those)."""
    routed = _routed(name, base)
    if routed is not None:
        return routed
    if _swatch_ready("steel"):
        mat = swatch_material(name, "steel", base)
        return d.worn(mat, edge="f0f2f2", edge_strength=0.15, grime="15181a", grime_strength=0.08)
    mat = kit.flat_material(name, base, 2.0 + seed * 0.1, _darker(base, 0.9))
    return d.worn(mat, edge=_darker(base, 1.0 / 0.72) if base not in (WHITE, SAFETY) else "f0f2f2",
                  edge_strength=0.3, grime="15181a", grime_strength=0.12)


def paint(name, hex_rgb, darker=None):
    routed = _routed(name, hex_rgb)
    if routed is not None:
        return routed
    return kit.flat_material(name, hex_rgb, 7.0 if darker else 0.0, darker)


def glow(name, hex_rgb=SCREEN):
    if name in SCREENS and _swatch_ready("screen"):
        return swatch_material(name, "screen")
    return kit.flat_material(name, hex_rgb, 9.0, "3fa8b8")


def glow_warm(name, hex_rgb, darker):
    """A lit part whose mottling stays in its own hue (glow() mixes in screen
    cyan, which turns originium orange to peach)."""
    return kit.flat_material(name, hex_rgb, 9.0, darker)


def join(name, objs):
    return kit.join(objs, name)


# --- Shell -------------------------------------------------------------------------

def base_wall_panel(width=4.0, height=3.6):
    """One bay of inner hull wall: a recessed panel between two ribs, a Rhodes
    blue line at waist height, a cable tray along the top."""
    hull = [d.bbox("w_back", (width, 0.5, height), (0, -0.25, height / 2))]
    for x in (-width / 2 + 0.12, width / 2 - 0.12):
        hull.append(d.bbox(f"w_rib{x}", (0.24, 0.16, height), (x, 0.06, height / 2)))
    hull.append(d.bbox("w_tray", (width, 0.28, 0.16), (0, 0.12, height - 0.3)))
    hull.append(d.bbox("w_skirt", (width, 0.12, 0.22), (0, 0.04, 0.11)))
    panel = [d.bbox("w_panel_lo", (width - 0.6, 0.06, 1.3), (0, 0.02, 0.95)),
             d.bbox("w_panel_hi", (width - 0.6, 0.06, 1.5), (0, 0.02, 2.5))]
    rv = d.rivets("w_rv", [(x, 0.06, z) for x in (-1.6, -0.8, 0.8, 1.6) for z in (0.4, 3.2)], radius=0.03, sign=1.0)
    line = [d.bbox("w_line", (width - 0.5, 0.07, 0.08), (0, 0.06, 1.68))]
    # A vent grille low in the lower panel, a light strip under the tray.
    vent = [d.bbox(f"w_vent{i}", (0.9, 0.08, 0.04), (0.9, 0.07, 0.55 + i * 0.1)) for i in range(4)]
    lamp = [d.bbox("w_lamp", (width - 0.8, 0.06, 0.06), (0, 0.24, height - 0.42))]
    pipes = [d.cyl(f"w_pipe{k}", r, width, (0, 0.2 + k * 0.05, height + 0.2 + k * 0.32), (0, math.radians(90), 0), 12)
             for k, r in enumerate((0.16, 0.11, 0.13))]
    flanges = [d.cyl(f"w_fl{k}", 0.2, 0.08, (x, 0.2, height + 0.2), (0, math.radians(90), 0), 12) for k, x in enumerate((-1.6, 1.6))]
    return [(join("w_hull", hull + rv + vent), steel("base_wall_hull_m", 3, HULL), "hull"),
            (join("w_panels", panel), steel("base_wall_panel_m", 5, PANEL), "panel"),
            (join("w_lines", line), paint("base_wall_line_m", BLUE), "line"),
            (join("w_lamp_j", lamp), glow("base_wall_lamp_m", "cfe6f0"), "lamp_glow"),
            (join("w_pipes", pipes[:1] + flanges), steel("base_wall_pipe_m", 2, PANEL), "pipe"),
            (join("w_pipes_b", pipes[1:2]), paint("base_wall_pipe_b_m", BLUE, "2c5880"), "pipe_b"),
            (join("w_pipes_o", pipes[2:]), paint("base_wall_pipe_o_m", ORANGE, "a24e1e"), "pipe_o")]


def base_wall_door(width=4.0, height=3.6, opening=3.0):
    """A bay with a 3 m airlock doorway (§6-19): a heavy frame in hazard stripes,
    hydraulic rams either side, the leaves slid open, a warning lamp over it."""
    side = (width - opening) / 2
    hull = [d.bbox("d_l", (side, 0.5, height), (-width / 2 + side / 2, -0.25, height / 2)),
            d.bbox("d_r", (side, 0.5, height), (width / 2 - side / 2, -0.25, height / 2)),
            d.bbox("d_head", (opening, 0.5, height - 2.7), (0, -0.25, 2.7 + (height - 2.7) / 2)),
            d.bbox("d_tray", (width, 0.28, 0.16), (0, 0.12, height - 0.3))]
    leaves = [d.bbox(f"d_leaf{s}", (0.3, 0.4, 2.6), (s * (opening / 2 + 0.05), -0.45, 1.3)) for s in (-1, 1)]
    frame = [d.bbox("d_fl", (0.3, 0.8, 2.9), (-opening / 2 - 0.15, -0.1, 1.45)),
             d.bbox("d_fr", (0.3, 0.8, 2.9), (opening / 2 + 0.15, -0.1, 1.45)),
             d.bbox("d_ft", (opening + 0.6, 0.8, 0.3), (0, -0.1, 2.95))]
    stripes = [d.bbox(f"d_hz{k}", (0.32, 0.06, 0.24), (s * (opening / 2 + 0.15), 0.31, 0.3 + k * 0.55), (0, math.radians(30 * s), 0))
               for s in (-1, 1) for k in range(5)]
    rams = [d.cyl(f"d_ram{s}", 0.09, 2.2, (s * (opening / 2 + 0.55), 0.2, 1.5)) for s in (-1, 1)]
    lamp = [d.cyl("d_lamp", 0.18, 0.2, (0, 0.3, 3.3), (math.radians(90), 0, 0), 12)]
    return [(join("d_hull", hull + leaves), steel("base_door_hull_m", 7, HULL), "hull"),
            (join("d_frame", frame + rams), steel("base_door_frame_m", 2, PANEL), "frame"),
            (join("d_hz", stripes), paint("base_door_hz_m", SAFETY), "stripe"),
            (join("d_lamp_j", lamp), glow("base_door_lamp_m", "f0a040"), "glow")]


def base_lift_gate():
    """外勤出发升降梯: a 6.4 m gate set in the north wall, safety-yellow frame,
    two closed leaves, the logo above, a cyan status lamp."""
    hull = [d.bbox("lg_back", (7.2, 0.5, 4.4), (0, -0.25, 2.2))]
    frame = [d.bbox("lg_fl", (0.4, 0.5, 3.6), (-3.2, 0.1, 1.8)), d.bbox("lg_fr", (0.4, 0.5, 3.6), (3.2, 0.1, 1.8)),
             d.bbox("lg_ft", (6.8, 0.5, 0.45), (0, 0.1, 3.6))]
    leaves = [d.bbox("lg_ll", (2.95, 0.12, 3.35), (-1.5, 0.05, 1.68)), d.bbox("lg_lr", (2.95, 0.12, 3.35), (1.5, 0.05, 1.68))]
    for i, z in enumerate((0.8, 1.6, 2.4)):
        leaves.append(d.bbox(f"lg_rib{i}", (5.8, 0.16, 0.08), (0, 0.08, z)))
    logo = kit.box("lg_logo", (0.9, 0.04, 0.9), (0, 0.38, 3.95))
    lamp = [d.bbox("lg_lamp", (0.5, 0.1, 0.16), (0, 0.38, 3.45))]
    return [(join("lg_hull", hull), steel("base_lift_hull_m", 4, HULL), "hull"),
            (join("lg_frame", frame), steel("base_lift_frame_m", 6, SAFETY), "frame"),
            (join("lg_leaves", leaves), steel("base_lift_leaf_m", 8, PANEL), "leaf"),
            (logo, logo_decal("base_lift_logo_m", HULL), "logo"),
            (join("lg_lamp_j", lamp), glow("base_lift_glow_m"), "glow")]


def base_railing(length=2.0):
    """A 2 m run of the lift well's guard rail: two posts, a yellow top rail, a
    mid rail and a kick plate with hazard stripes."""
    posts = [d.cyl("r_p0", 0.05, 1.05, (-length / 2 + 0.05, 0, 0.53)), d.cyl("r_p1", 0.05, 1.05, (length / 2 - 0.05, 0, 0.53)),
             d.bbox("r_mid", (length, 0.05, 0.05), (0, 0, 0.6))]
    top = [d.bbox("r_top", (length, 0.09, 0.07), (0, 0, 1.08))]
    kick = [d.bbox("r_kick", (length, 0.05, 0.18), (0, 0, 0.09))]
    return [(join("r_posts", posts), steel("base_rail_post_m", 3, PANEL), "post"),
            (join("r_topj", top), paint("base_rail_top_m", SAFETY, "a87e18"), "top"),
            (join("r_kickj", kick), paint("base_rail_kick_m", RUBBER), "kick")]


# --- Props -------------------------------------------------------------------------

def _monitor(prefix, x, y, z, w=0.9, h=0.6, lit=True, yaw=0.0):
    case = d.bbox(f"{prefix}_case", (w, 0.08, h), (x, y, z), (0, 0, yaw))
    stand = d.bbox(f"{prefix}_stand", (0.08, 0.08, 0.3), (x, y - 0.05, z - h / 2 - 0.12))
    screen = d.bbox(f"{prefix}_scr", (w - 0.1, 0.02, h - 0.1), (x, y + 0.045, z), (0, 0, yaw))
    return [case, stand], screen


def base_dispatch_console():
    """调度台: a curved command desk with three big screens, orange trim."""
    body = [d.bbox("dc_base", (5.6, 1.3, 0.9), (0, 0, 0.45)), d.bbox("dc_top", (6.2, 1.5, 0.1), (0, 0.05, 0.95)),
            d.bbox("dc_wl", (0.5, 1.4, 1.0), (-3.0, 0, 0.5)), d.bbox("dc_wr", (0.5, 1.4, 1.0), (3.0, 0, 0.5))]
    trim = [d.bbox("dc_trim", (6.2, 0.06, 0.08), (0, 0.8, 0.92)), d.bbox("dc_kick", (5.6, 0.06, 0.12), (0, 0.66, 0.08))]
    cases, screens = [], []
    for i, (x, yaw) in enumerate(((-1.9, 0.35), (0, 0.0), (1.9, -0.35))):
        c, s = _monitor(f"dc_m{i}", x, -0.3, 1.75, 1.6 if i == 1 else 1.3, 0.95, yaw=yaw)
        cases += c
        screens.append(s)
    return [(join("dc_body", body + cases), steel("base_console_body_m", 3, HULL), "body"),
            (join("dc_trimj", trim), paint("base_console_trim_m", ORANGE, "a24e1e"), "trim"),
            (join("dc_scr", screens), glow("base_console_glow_m"), "glow")]


def _desk(lit):
    top = [d.bbox("dk_top", (3.0, 1.2, 0.08), (0, 0, 0.82)), d.bbox("dk_side_l", (0.1, 1.1, 0.8), (-1.4, 0, 0.4)),
           d.bbox("dk_side_r", (0.1, 1.1, 0.8), (1.4, 0, 0.4)), d.bbox("dk_back", (2.8, 0.06, 0.5), (0, -0.55, 0.55))]
    chair = [d.bbox("dk_seat", (0.6, 0.6, 0.1), (0.2, 0.95, 0.5)), d.bbox("dk_backrest", (0.6, 0.08, 0.6), (0.2, 1.25, 0.85)),
             d.cyl("dk_post", 0.04, 0.45, (0.2, 0.95, 0.23))]
    cases, screen = _monitor("dk_m", -0.3, -0.25, 1.25, 1.1, 0.7)
    plate = kit.box("dk_logo", (0.42, 0.02, 0.42), (-1.0, 0.6, 0.55))
    parts = [(join("dk_body", top + cases), steel("base_desk_body_m", 4, PANEL), "body"),
             (join("dk_chair", chair), paint("base_desk_chair_m", RUBBER), "chair"),
             (plate, logo_decal("base_desk_logo_m", PANEL), "logo")]
    parts.append((screen, glow("base_desk_glow_m") if lit else paint("base_desk_off_m", "1c2a30", "121a1e"), "glow" if lit else "screen"))
    return parts


def base_desk():
    """值班台 with its screen on."""
    return _desk(True)


def base_desk_off():
    """An empty duty desk, its screen dark."""
    return _desk(False)


def base_hanging_screens(count=4):
    """Information screens hanging from a ceiling bar (always overhead)."""
    span = count * 1.3
    bar = [d.bbox("hs_bar", (span + 0.6, 0.12, 0.12), (0, 0, 1.2))]
    cases, screens = [], []
    for i in range(count):
        x = -span / 2 + 0.65 + i * 1.3
        bar.append(d.cyl(f"hs_wire{i}", 0.015, 0.5, (x, 0, 0.95)))
        cases.append(d.bbox(f"hs_case{i}", (1.0, 0.1, 0.7), (x, 0, 0.35)))
        screens.append(d.bbox(f"hs_scr{i}", (0.88, 0.02, 0.58), (x, 0.06, 0.35)))
    return [(join("hs_body", bar + cases), steel("base_hang_body_m", 5, HULL), "body"),
            (join("hs_scr", screens), glow("base_hang_glow_m"), "glow")]


def base_hanging_screens_pair():
    return base_hanging_screens(2)


def base_plant():
    """A potted plant on the duty floor: grey pot, dark leaves."""
    pot = [d.cyl("pl_pot", 0.32, 0.5, (0, 0, 0.25)), d.cyl("pl_rim", 0.36, 0.08, (0, 0, 0.52))]
    leaves = []
    for i in range(7):
        a = i / 7 * math.tau
        leaves.append(kit.rock(f"pl_leaf{i}", 0.26, (0.25 * math.cos(a), 0.25 * math.sin(a), 0.85 + 0.12 * (i % 3)), (1.3, 0.6, 0.35), 1))
    leaves.append(kit.rock("pl_crown", 0.3, (0, 0, 1.15), (1.0, 1.0, 0.8), 1))
    return [(join("pl_potj", pot), paint("base_plant_pot_m", WHITE, "9aa2a4"), "pot"),
            (join("pl_leaves", leaves), paint("base_plant_leaf_m", "3f6a3a", "253f22"), "leaf")]


def base_logistics_counter():
    """后勤柜台: a long service counter under a yellow gantry, a terminal on it."""
    body = [d.bbox("lc_base", (4.4, 1.0, 1.0), (0, 0, 0.5)), d.bbox("lc_top", (4.7, 1.2, 0.08), (0, 0, 1.04))]
    gantry = [d.bbox("lc_pl", (0.16, 0.16, 2.6), (-2.25, -0.4, 1.3)), d.bbox("lc_pr", (0.16, 0.16, 2.6), (2.25, -0.4, 1.3)),
              d.bbox("lc_beam", (4.66, 0.2, 0.22), (0, -0.4, 2.55))]
    cases, screen = _monitor("lc_m", 1.2, -0.2, 1.45, 0.8, 0.5)
    return [(join("lc_body", body + cases), steel("base_counter_body_m", 6, WHITE), "body"),
            (join("lc_gantry", gantry), steel("base_counter_gantry_m", 2, SAFETY), "gantry"),
            (screen, glow("base_counter_glow_m"), "glow")]


def base_crate():
    """A Rhodes engineering crate, a plain label patch (no text)."""
    body = [d.bbox("cr_body", (1.4, 1.2, 1.0), (0, 0, 0.5))]
    for i, x in enumerate((-0.55, 0.55)):
        body.append(d.bbox(f"cr_band{i}", (0.1, 1.24, 1.04), (x, 0, 0.5)))
    label = [d.bbox("cr_label", (0.6, 0.02, 0.3), (0, 0.61, 0.6))]
    return [(join("cr_bodyj", body), steel("base_crate_m", 5, PANEL), "body"),
            (join("cr_labelj", label), paint("base_crate_label_m", SAFETY), "label")]


def base_crate_stack():
    """Supply cases stacked by the wall, white with orange clasps."""
    boxes = [d.bbox("cs_a", (1.2, 1.0, 0.8), (-0.5, 0, 0.4)), d.bbox("cs_b", (1.0, 0.9, 0.7), (0.65, 0.05, 0.35)),
             d.bbox("cs_c", (1.0, 0.9, 0.6), (-0.4, 0, 1.1)), d.bbox("cs_d", (0.6, 0.6, 0.5), (0.6, 0.1, 0.95))]
    clasps = [d.bbox(f"cs_k{i}", (0.12, 0.04, 0.1), (x, y, z)) for i, (x, y, z) in enumerate(((-0.5, 0.52, 0.6), (0.65, 0.52, 0.5), (-0.4, 0.47, 1.25)))]
    return [(join("cs_boxes", boxes), steel("base_stack_m", 7, WHITE), "box"),
            (join("cs_clasps", clasps), paint("base_stack_clasp_m", ORANGE), "clasp")]


def base_case():
    """A long metal equipment case on the floor."""
    body = [d.bbox("mc_body", (2.4, 0.7, 0.55), (0, 0, 0.28)), d.bbox("mc_lid", (2.44, 0.74, 0.08), (0, 0, 0.58))]
    trim = [d.bbox(f"mc_t{i}", (0.1, 0.76, 0.62), (x, 0, 0.31)) for i, x in enumerate((-1.0, 0, 1.0))]
    return [(join("mc_bodyj", body), steel("base_case_m", 2, WHITE), "body"),
            (join("mc_trimj", trim), steel("base_case_trim_m", 4, HULL), "trim")]


def base_bench():
    """A three-seat waiting bench."""
    seats = [d.bbox(f"bn_s{i}", (0.95, 0.7, 0.12), (x, 0, 0.48)) for i, x in enumerate((-1.0, 0, 1.0))]
    seats += [d.bbox(f"bn_b{i}", (0.95, 0.1, 0.5), (x, -0.35, 0.8)) for i, x in enumerate((-1.0, 0, 1.0))]
    frame = [d.bbox("bn_rail", (3.2, 0.12, 0.12), (0, -0.1, 0.38)), d.bbox("bn_l0", (0.12, 0.6, 0.4), (-1.5, 0, 0.2)),
             d.bbox("bn_l1", (0.12, 0.6, 0.4), (1.5, 0, 0.2))]
    return [(join("bn_seats", seats), paint("base_bench_seat_m", "7a9ab4", "5a7a92"), "seat"),
            (join("bn_frame", frame), steel("base_bench_frame_m", 3, HULL), "frame")]


def base_dispenser():
    """A water dispenser: white body, blue bottle on top."""
    body = [d.bbox("wd_body", (0.55, 0.5, 1.1), (0, 0, 0.55)), d.bbox("wd_tap", (0.2, 0.08, 0.1), (0, 0.27, 0.8))]
    bottle = [d.cyl("wd_bottle", 0.18, 0.45, (0, 0, 1.33))]
    return [(join("wd_bodyj", body), paint("base_disp_body_m", WHITE, "a8b0b2"), "body"),
            (join("wd_bottlej", bottle), paint("base_disp_bottle_m", "5a9ad0", "3a6f9e"), "bottle")]


def base_wall_sign():
    """A room sign on the wall by a side door: dark plate, a coloured bar and
    the logo; no lettering (交互只提示 E)."""
    plate = [d.bbox("ws_plate", (3.6, 0.1, 0.9), (0, 0, 0.45))]
    bar = [d.bbox("ws_bar", (3.4, 0.05, 0.1), (0, 0.06, 0.82))]
    logo = kit.box("ws_logo", (0.6, 0.03, 0.6), (-1.3, 0.07, 0.4))
    lamp = [d.bbox("ws_glow", (1.6, 0.03, 0.14), (0.5, 0.07, 0.4))]
    return [(join("ws_platej", plate), steel("base_sign_plate_m", 2, HULL), "plate"),
            (join("ws_barj", bar), paint("base_sign_bar_m", BLUE), "bar"),
            (logo, logo_decal("base_sign_logo_m", HULL), "logo"),
            (join("ws_lamp", lamp), glow("base_sign_glow_m"), "glow")]


def base_directory_board():
    """The hall's standing directory: a long dark board on two legs, four rows,
    each a yellow tab and a lit bar (no lettering)."""
    board = [d.bbox("db_board", (12.0, 0.25, 3.0), (0, 0, 2.6)), d.bbox("db_leg0", (0.25, 0.25, 1.2), (-4.5, 0, 0.6)),
             d.bbox("db_leg1", (0.25, 0.25, 1.2), (4.5, 0, 0.6))]
    tabs, bars = [], []
    for i in range(4):
        z = 3.75 - i * 0.72
        tabs.append(d.bbox(f"db_tab{i}", (0.55, 0.06, 0.5), (-5.0, 0.14, z)))
        bars.append(d.bbox(f"db_bar{i}", (8.0, 0.04, 0.12), (-0.3, 0.14, z)))
    top = [d.bbox("db_top", (12.0, 0.28, 0.12), (0, 0, 4.12))]
    return [(join("db_boardj", board), steel("base_board_m", 4, HULL), "board"),
            (join("db_tabs", tabs + top), paint("base_board_tab_m", SAFETY), "tab"),
            (join("db_bars", bars), glow("base_board_glow_m"), "glow")]


def base_south_barrier():
    """The hall's south side: a low hazard-striped barrier with the Rhodes
    banner on a frame behind it (the old pixel set piece, modelled)."""
    barrier = [d.bbox("sb_low", (8.4, 0.5, 0.9), (0, 0, 0.45))]
    stripes = [d.bbox(f"sb_st{i}", (0.35, 0.04, 0.7), (-3.9 + i * 0.6, 0.27, 0.45), (0, 0.6, 0)) for i in range(14)]
    frame = [d.bbox("sb_fl", (0.12, 0.12, 2.6), (-1.4, -0.2, 1.3)), d.bbox("sb_fr", (0.12, 0.12, 2.6), (1.4, -0.2, 1.3)),
             d.bbox("sb_ft", (2.92, 0.12, 0.12), (0, -0.2, 2.6))]
    banner = kit.box("sb_banner", (2.6, 0.03, 2.2), (0, -0.12, 1.45))
    return [(join("sb_barrier", barrier + frame), steel("base_barrier_m", 3, HULL), "barrier"),
            (join("sb_stripes", stripes), paint("base_barrier_stripe_m", SAFETY), "stripe"),
            (banner, logo_decal("base_barrier_banner_m", BLUE), "banner")]


def base_column(height=5.0):
    """A structural rib standing out of a side wall: a square column with a
    Rhodes-blue light strip, a cap and a foot."""
    col = [d.bbox("cl_body", (1.0, 1.0, height), (0, 0.3, height / 2)), d.bbox("cl_foot", (1.3, 1.3, 0.35), (0, 0.3, 0.18)),
           d.bbox("cl_cap", (1.3, 1.3, 0.3), (0, 0.3, height - 0.15))]
    band = [d.bbox("cl_band", (1.04, 1.04, 0.14), (0, 0.3, 1.2))]
    strip = [d.bbox("cl_strip", (0.12, 0.05, height - 1.4), (0, 0.82, height / 2 + 0.3))]
    return [(join("cl_bodyj", col), steel("base_column_m", 5, PANEL), "body"),
            (join("cl_bandj", band), paint("base_column_band_m", SAFETY), "band"),
            (join("cl_stripj", strip), glow("base_column_strip_m", "4f8fd0"), "strip_glow")]


def base_floor_stripe(length=4.0):
    """A 4 m run of the deck's guide line: safety yellow, set flush."""
    stripe = [d.bbox("fs_body", (length, 0.22, 0.02), (0, 0, 0.01))]
    return [(join("fs_j", stripe), paint("base_stripe_m", SAFETY, "b88a14"), "stripe")]


# --- The command bridge (用户 2026-10-18: 主控台模型尺寸变大，突出宏伟) ------------

## The command ring (用户 2026-10-18: 主控可以更大，围成弧形): segments on a
## circle round the Doctor's spot, from RING_FROM to RING_TO degrees (0 = due
## north, the side away from the camera), open to the south.
RING_RADIUS = 7.5
RING_STEP = 30
RING_FROM, RING_TO = -120, 120


def _on_ring(radius, degrees):
    """A point on the ring, and the yaw that turns a segment's front (+Y) to
    face the ring's centre."""
    a = math.radians(degrees)
    return radius * math.sin(a), -radius * math.cos(a), a


def _place(objs, x, y, yaw):
    m = mathutils.Matrix.Translation((x, y, 0)) @ mathutils.Matrix.Rotation(yaw, 4, "Z")
    for o in objs:
        o.matrix_world = m @ o.matrix_world


def base_command_console(radius=RING_RADIUS):
    """调度台 as the bridge's command ring: nine consoles round the Doctor's
    spot, two screens each, facing in; pylons at the open ends; a raised round
    deck edged in light; the hologram of Terra hanging high over the centre,
    above the Doctor's head."""
    body, trim, screens, deck = [], [], [], []
    for i, deg in enumerate(range(RING_FROM, RING_TO + 1, RING_STEP)):
        x, y, yaw = _on_ring(radius, deg)
        seg = [d.bbox(f"cc_base{i}", (3.5, 1.4, 0.9), (0, 0, 0.45)),
               d.bbox(f"cc_slope{i}", (3.6, 0.95, 0.12), (0, 0.18, 1.0), (math.radians(-18), 0, 0)),
               d.bbox(f"cc_hood{i}", (3.6, 0.3, 1.25), (0, -0.6, 1.55)),
               d.bbox(f"cc_fin{i}", (0.16, 1.5, 1.9), (1.78, -0.1, 0.95))]
        tr = [d.bbox(f"cc_lip{i}", (3.6, 0.06, 0.07), (0, 0.66, 0.9)), d.bbox(f"cc_kick{i}", (3.4, 0.05, 0.1), (0, 0.72, 0.07)),
              d.bbox(f"cc_hcap{i}", (3.64, 0.36, 0.08), (0, -0.6, 2.2))]
        sc = [d.bbox(f"cc_s{i}a", (1.55, 0.03, 0.85), (-0.85, -0.43, 1.6), (math.radians(-10), 0, 0)),
              d.bbox(f"cc_s{i}b", (1.55, 0.03, 0.85), (0.85, -0.43, 1.6), (math.radians(-10), 0, 0)),
              d.bbox(f"cc_k{i}", (2.9, 0.02, 0.32), (0, 0.22, 1.04), (math.radians(-18), 0, 0))]
        _place(seg + tr + sc, x, y, yaw)
        body += seg
        trim += tr
        screens += sc
    for side in (-1, 1):
        x, y, yaw = _on_ring(radius, side * (RING_TO + 18))
        parts = [d.bbox(f"cc_pylon{side}", (1.0, 1.0, 3.4), (0, 0, 1.7)), d.bbox(f"cc_pcap{side}", (1.2, 1.2, 0.14), (0, 0, 3.45))]
        strip = [d.bbox(f"cc_pstrip{side}", (0.14, 0.06, 2.8), (0, 0.52, 1.75))]
        _place(parts + strip, x, y, yaw)
        body += parts
        screens += strip
    # Raised round deck under the ring, its rim lit in Rhodes blue.
    deck.append(d.cyl("cc_dais", radius + 1.6, 0.14, (0, 0, 0.07), vertices=72))
    deck.append(d.cyl("cc_dais_in", 2.2, 0.16, (0, 0, 0.08), vertices=48))
    bpy.ops.mesh.primitive_torus_add(major_radius=radius + 1.6, minor_radius=0.06, location=(0, 0, 0.15), major_segments=72)
    edge = [bpy.context.object]
    bpy.ops.mesh.primitive_torus_add(major_radius=2.2, minor_radius=0.05, location=(0, 0, 0.17), major_segments=48)
    edge.append(bpy.context.object)
    # The hologram of Terra hangs over the ring's centre, high enough that the
    # Doctor standing under it stays in view; an emitter ring on the deck.
    trim.append(d.cyl("cc_pring", 1.4, 0.06, (0, 0, 0.2), vertices=32))
    holo = [kit.rock("cc_globe", 1.3, (0, 0, 6.0), (1.0, 1.0, 1.0), 2)]
    for k, h in enumerate((4.9, 7.1)):
        bpy.ops.mesh.primitive_torus_add(major_radius=1.8 - 0.25 * k, minor_radius=0.04, location=(0, 0, h), major_segments=48)
        holo.append(bpy.context.object)
    return [(join("cc_body", body), steel("base_cc_body_m", 4, HULL), "body"),
            (join("cc_trim", trim), paint("base_cc_trim_m", ORANGE, "a24e1e"), "trim"),
            (join("cc_dais_j", deck), steel("base_cc_dais_m", 6, "3b4248"), "dais"),
            (join("cc_edge_j", edge), glow("base_cc_edge_m", "4f8fd0"), "edge_glow"),
            (join("cc_screens", screens), glow("base_cc_glow_m"), "glow"),
            (join("cc_holo", holo), glow("base_cc_holo_m", "8fe8f4"), "holo_glow")]


LOGO = os.path.join(os.path.dirname(__file__), "..", "..", "..", "art", "kit", "textures", "base_rhodes_logo.png")


def logo_decal(name, under_hex):
    """The Rhodes Island logo (Sol's L logo: the rook tower in the triangle) on a
    plate's front face, over `under_hex` where the image is clear."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coord = nodes.new("ShaderNodeTexCoord")
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Generated"], xyz.inputs["Vector"])
    uv = nodes.new("ShaderNodeCombineXYZ")
    links.new(xyz.outputs["X"], uv.inputs["X"])
    links.new(xyz.outputs["Z"], uv.inputs["Y"])
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.normpath(LOGO), check_existing=True)
    tex.interpolation = "Closest"
    tex.extension = "CLIP"
    links.new(uv.outputs["Vector"], tex.inputs["Vector"])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = kit.srgb(under_hex)
    links.new(tex.outputs["Alpha"], mix.inputs["Factor"])
    links.new(tex.outputs["Color"], mix.inputs["B"])
    links.new(mix.outputs["Result"], kit.principled(nodes).inputs["Base Color"])
    return mat


VIEW = os.path.join(os.path.dirname(__file__), "..", "..", "..", "art", "kit", "textures", "base_wasteland_view.png")
# Sol's painted view (基地材质美术需求_v1 R9) replaces the stand-in once it is in.
if os.path.exists(os.path.join(PAINTED, "base_wasteland_view.png")):
    VIEW = os.path.join(PAINTED, "base_wasteland_view.png")


def view_material(name, repeat=1.0):
    """The wasteland outside, laid across a window's front face (x and z of its
    bounds), `repeat` times along its width. Stand-in until Sol paints it."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coord = nodes.new("ShaderNodeTexCoord")
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Generated"], xyz.inputs["Vector"])
    scale = nodes.new("ShaderNodeMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = repeat
    links.new(xyz.outputs["X"], scale.inputs[0])
    uv = nodes.new("ShaderNodeCombineXYZ")
    links.new(scale.outputs["Value"], uv.inputs["X"])
    links.new(xyz.outputs["Z"], uv.inputs["Y"])
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.normpath(VIEW), check_existing=True)
    tex.interpolation = "Closest"
    links.new(uv.outputs["Vector"], tex.inputs["Vector"])
    links.new(tex.outputs["Color"], kit.principled(nodes).inputs["Base Color"])
    return mat


def base_bridge_wall(width=40.0, height=9.0, lift_half=3.6, lift_h=4.4):
    """The bridge's north wall (基地装饰调研_v1 §6-1, 4): 40 m and twice the
    hall's height. Over the lift, the main screen; either side, a long window
    on the wasteland the ship is crossing, slanted mullions, and a bank of
    monitors under it; two great columns hold the lift between them, and the
    logo crowns it. The lift gate stands in its opening."""
    side = width / 2 - lift_half
    hull = [d.bbox("bw_l", (side, 0.6, height), (-lift_half - side / 2, -0.3, height / 2)),
            d.bbox("bw_r", (side, 0.6, height), (lift_half + side / 2, -0.3, height / 2)),
            d.bbox("bw_top", (2 * lift_half, 0.6, height - lift_h), (0, -0.3, lift_h + (height - lift_h) / 2))]
    frame = [d.bbox("bw_sframe", (13.4, 0.35, 5.0), (0, 0.05, 6.4)), d.bbox("bw_cornice", (width + 0.4, 0.8, 0.35), (0, 0.1, height)),
             d.bbox("bw_sill", (width, 0.5, 0.25), (0, 0.15, 3.1))]
    cols, strips, views, monitors = [], [], [], []
    for sx in (-1, 1):
        # the great columns either side of the lift
        x = sx * 7.4
        cols += [d.bbox(f"bw_col{sx}", (1.8, 1.6, height + 1.2), (x, 0.5, (height + 1.2) / 2)),
                 d.bbox(f"bw_base{sx}", (2.4, 2.1, 0.6), (x, 0.5, 0.3)), d.bbox(f"bw_ring{sx}", (1.9, 1.7, 0.2), (x, 0.5, 4.2))]
        strips.append(d.bbox(f"bw_strip{sx}", (0.2, 0.05, height - 1.2), (x, 1.32, height / 2 + 0.4)))
        # the window: a frame, slanted mullions, the view behind
        wx = sx * 13.6
        views.append(d.bbox(f"bw_view{sx}", (10.6, 0.04, 4.6), (wx, 0.02, 6.1)))
        cols.append(d.bbox(f"bw_wframe{sx}", (11.2, 0.4, 0.3), (wx, 0.2, 8.5)))
        for k in range(5):
            cols.append(d.bbox(f"bw_mul{sx}{k}", (0.22, 0.3, 4.9), (wx - 4.6 + k * 2.3, 0.18, 6.1), (0, math.radians(14), 0)))
        # a bank of monitors under the window, on a ledge
        cols.append(d.bbox(f"bw_ledge{sx}", (10.4, 0.9, 0.9), (wx, 0.45, 0.45)))
        for r in range(2):
            for c in range(4):
                monitors.append(d.bbox(f"bw_mon{sx}{r}{c}", (2.2, 0.06, 0.95), (wx - 3.6 + c * 2.4, 0.42, 1.55 + r * 1.1)))
                cols.append(d.bbox(f"bw_mcase{sx}{r}{c}", (2.36, 0.2, 1.08), (wx - 3.6 + c * 2.4, 0.32, 1.55 + r * 1.1)))
    screen = [d.bbox("bw_screen", (12.8, 0.05, 4.4), (0, 0.24, 6.4))]
    data = [d.bbox(f"bw_row{k}", (5.4 - k * 0.6, 0.02, 0.12), (-3.0, 0.28, 7.8 - k * 0.55)) for k in range(5)]
    data.append(d.bbox("bw_map", (4.2, 0.02, 2.6), (3.4, 0.28, 6.6)))
    logo = kit.box("bw_logo", (2.2, 0.04, 2.2), (0, 0.6, height - 1.05))
    return [(join("bw_hull", hull), steel("base_bw_hull_m", 3, HULL), "hull"),
            (join("bw_frame", frame + cols), steel("base_bw_frame_m", 5, PANEL), "frame"),
            (join("bw_strips", strips), glow("base_bw_strip_m", "4f8fd0"), "strip_glow"),
            (join("bw_views", views), view_material("base_bw_view_m", 1.0), "view_glow"),
            (join("bw_mons", monitors), glow("base_bw_mon_m", "5fc8d8"), "mon_glow"),
            (join("bw_screen_j", screen), glow("base_bw_screen_m", "2f7fb8"), "screen_glow"),
            (join("bw_data", data), glow("base_bw_data_m", "9fe8f0"), "data_glow"),
            (logo, logo_decal("base_bw_logo_m", HULL), "logo")]


# --- Decoration (基地装饰调研_v1 §6) ------------------------------------------------

def base_sand_table():
    """陆行舰沙盘台 (§6-5; 用户 2026-10-18: 认不出来): a low dark table with a
    scale model of Rhodes Island on it, big enough to read from above — a long
    hull on two track units, decks stepping up towards the stern, the bridge
    block on top, the yellow mining drum at the bow — and cyan contour lines
    of the ground it is crossing glowing in the table top."""
    table = [d.bbox("st_base", (10.0, 5.0, 0.8), (0, 0, 0.4)), d.bbox("st_rim", (10.4, 5.4, 0.1), (0, 0, 0.85))]
    top = [d.bbox("st_top", (9.8, 4.8, 0.04), (0, 0, 0.9))]
    contours = []
    for k in range(6):
        w, h = 9.2 - k * 1.1, 4.2 - k * 0.55
        for (sx, sy, lx, ly) in ((0, h / 2, w, 0.05), (0, -h / 2, w, 0.05), (w / 2, 0, 0.05, h), (-w / 2, 0, 0.05, h)):
            contours.append(d.bbox(f"st_c{k}{sx}{sy}", (lx, ly, 0.02), (sx + 0.1 * k, sy, 0.93)))
    # The ship, bow to +X: hull, track units, decks, bridge, drum.
    hull = [d.bbox("st_hull", (6.8, 2.0, 0.55), (0, 0, 1.3)),
            d.bbox("st_bow", (1.2, 1.7, 0.45), (3.7, 0, 1.25), (0, math.radians(-18), 0)),
            d.bbox("st_d1", (5.6, 1.8, 0.45), (-0.5, 0, 1.78)),
            d.bbox("st_d2", (4.0, 1.5, 0.45), (-1.2, 0, 2.2)),
            d.bbox("st_d3", (2.4, 1.2, 0.45), (-1.9, 0, 2.62)),
            d.bbox("st_bridge", (1.3, 1.0, 0.5), (-2.4, 0, 3.05)),
            d.bbox("st_mast", (0.12, 0.12, 0.7), (-2.6, 0, 3.6))]
    tracks = []
    for side in (-1, 1):
        tracks.append(d.bbox(f"st_trk{side}", (6.2, 0.5, 0.45), (-0.2, side * 1.15, 1.02)))
        for k in range(7):
            tracks.append(d.cyl(f"st_wh{side}{k}", 0.2, 0.52, (-3.0 + k * 0.95, side * 1.15, 1.0), (math.radians(90), 0, 0), 12))
    drum = [d.cyl("st_drum", 0.55, 1.6, (4.35, 0, 1.45), (math.radians(90), 0, 0), 20),
            d.cyl("st_drum_a", 0.6, 0.12, (4.35, 0.8, 1.45), (math.radians(90), 0, 0), 20),
            d.cyl("st_drum_b", 0.6, 0.12, (4.35, -0.8, 1.45), (math.radians(90), 0, 0), 20)]
    windows = [d.bbox(f"st_win{k}", (0.9, 0.02, 0.1), (-2.4 + k * 1.1, 0.76, 1.85)) for k in range(4)]
    windows.append(d.bbox("st_bwin", (1.0, 0.02, 0.14), (-2.4, 0.51, 3.12)))
    # The model sits back from the bow end so the drum stays on the table.
    for o in hull + tracks + drum + windows:
        o.location.x -= 0.7
    return [(join("st_table", table + tracks[:0]), steel("base_st_table_m", 4, "3a4046"), "table"),
            (join("st_top_j", top), paint("base_st_top_m", "1d2a30"), "top"),
            (join("st_hull_j", hull), steel("base_st_ship_m", 6, WHITE), "ship"),
            (join("st_tracks", tracks), steel("base_st_track_m", 3, HULL), "track"),
            (join("st_drum_j", drum), paint("base_st_drum_m", SAFETY, "a87e18"), "drum"),
            (join("st_contours", contours + windows), glow("base_st_contour_m", "4fc8d8"), "contour_glow")]


def base_intel_wall(width=20.0):
    """情报墙 (§6-10): a row of server cabinets along the wall, lights blinking,
    a cable tray over them, and a wide map screen above."""
    racks, lamps = [], []
    n = int(width // 1.25)
    for k in range(n):
        x = -width / 2 + 0.62 + k * 1.25
        racks.append(d.bbox(f"iw_rack{k}", (1.15, 1.0, 2.4), (x, 0.5, 1.2)))
        for r in range(4):
            lamps.append(d.bbox(f"iw_led{k}{r}", (0.5 if r % 2 else 0.3, 0.03, 0.05), (x - 0.15, 1.01, 0.5 + r * 0.45)))
    racks.append(d.bbox("iw_tray", (width, 0.6, 0.25), (0, 0.4, 2.8)))
    screen = [d.bbox("iw_screen", (width * 0.6, 0.05, 2.4), (0, 0.15, 4.4))]
    racks.append(d.bbox("iw_sframe", (width * 0.6 + 0.4, 0.2, 2.8), (0, 0.08, 4.4)))
    return [(join("iw_racks", racks), steel("base_iw_rack_m", 3, HULL), "rack"),
            (join("iw_leds", lamps), glow("base_iw_led_m", "7fe0a0"), "led_glow"),
            (join("iw_screen_j", screen), glow("base_iw_screen_m", "3a8fb8"), "screen_glow")]


def base_first_aid():
    """急救点 (§6-11): a white medical cabinet, a folded stretcher on a rack and
    a vitals monitor on a stand. The mark is Rhodes' own, no red cross."""
    cab = [d.bbox("fa_cab", (1.2, 0.6, 1.8), (-0.9, 0, 0.9)), d.bbox("fa_rack", (1.6, 0.5, 0.12), (0.6, 0, 1.2)),
           d.bbox("fa_rack2", (1.6, 0.5, 0.12), (0.6, 0, 0.4)), d.bbox("fa_stretch", (1.5, 0.5, 0.1), (0.6, 0, 1.33))]
    legs = [d.bbox(f"fa_leg{k}", (0.06, 0.06, 1.3), (0.6 + sx * 0.75, sy * 0.2, 0.65)) for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    stand = [d.cyl("fa_pole", 0.04, 1.6, (1.9, 0.1, 0.8)), d.bbox("fa_mon", (0.6, 0.1, 0.45), (1.9, 0.1, 1.7))]
    mark = kit.box("fa_mark", (0.5, 0.02, 0.5), (-0.9, 0.31, 1.3))
    screen = [d.bbox("fa_scr", (0.5, 0.02, 0.36), (1.9, 0.16, 1.7))]
    return [(join("fa_white", cab), steel("base_fa_cab_m", 5, WHITE), "cabinet"),
            (join("fa_steel", legs + stand), steel("base_fa_steel_m", 3, PANEL), "steel"),
            (mark, logo_decal("base_fa_mark_m", WHITE), "mark"),
            (join("fa_scr_j", screen), glow("base_fa_scr_m", "7fe0a0"), "glow")]


def base_conveyor(length=7.0):
    """后勤传送口 (§6-12): a roller conveyor coming out of a shuttered hatch in
    the wall, two crates riding it."""
    hatch = [d.bbox("cv_hatch", (2.6, 0.5, 2.6), (0, -length / 2 - 0.2, 1.3)), d.bbox("cv_shutter", (2.0, 0.08, 1.5), (0, -length / 2 + 0.08, 1.85))]
    frame = [d.bbox("cv_frame", (1.6, length, 0.2), (0, 0, 0.8))] + [d.bbox(f"cv_leg{k}", (0.12, 0.12, 0.8), (sx * 0.7, -length / 2 + 0.6 + k // 2 * 2.0, 0.4)) for k, sx in enumerate((-1, 1) * 4)]
    rollers = [d.cyl(f"cv_r{k}", 0.08, 1.5, (0, -length / 2 + 0.3 + k * 0.4, 0.95), (0, math.radians(90), 0), 10) for k in range(int(length / 0.4))]
    boxes = [d.bbox("cv_box0", (1.0, 0.9, 0.7), (0, -0.8, 1.4)), d.bbox("cv_box1", (0.8, 0.8, 0.6), (0, 1.6, 1.35))]
    stripes = [d.bbox("cv_hz", (2.4, 0.06, 0.2), (0, -length / 2 + 0.06, 2.75))]
    return [(join("cv_hatch_j", hatch + frame), steel("base_cv_frame_m", 4, PANEL), "frame"),
            (join("cv_rollers", rollers), steel("base_cv_roll_m", 2, "9aa2a8"), "roller"),
            (join("cv_boxes", boxes), steel("base_cv_box_m", 6, BLUE), "box"),
            (join("cv_hz_j", stripes), paint("base_cv_hz_m", SAFETY), "stripe")]


def base_container_stack():
    """集装箱堆 (§6-13): standard containers three high against the north wall,
    grey, Rhodes blue and orange, strapped down for the ship's motion."""
    boxes = {"grey": [], "blue": [], "orange": []}
    spec = [((-3.1, 0, 1.3), "grey"), ((3.1, 0, 1.3), "blue"), ((-3.1, 0, 3.9), "orange"), ((3.1, 0, 3.9), "grey"), ((0, 0, 6.5), "blue")]
    ribs = []
    for k, (p, c) in enumerate(spec):
        boxes[c].append(d.bbox(f"ct_box{k}", (6.0, 2.4, 2.5), p))
        for r in range(7):
            ribs.append(d.bbox(f"ct_rib{k}{r}", (0.08, 2.46, 2.3), (p[0] - 2.7 + r * 0.9, 0, p[2])))
    straps = [d.bbox(f"ct_strap{k}", (0.12, 2.5, 7.8), (x, 0.02, 3.9)) for k, x in enumerate((-4.5, -1.6, 1.6, 4.5))]
    return [(join("ct_grey", boxes["grey"] + ribs), steel("base_ct_grey_m", 4, PANEL), "grey"),
            (join("ct_blue", boxes["blue"]), steel("base_ct_blue_m", 5, BLUE), "blue"),
            (join("ct_orange", boxes["orange"]), steel("base_ct_orange_m", 6, ORANGE), "orange"),
            (join("ct_straps", straps), paint("base_ct_strap_m", SAFETY, "a87e18"), "strap")]


def base_gantry_crane(span=26.0):
    """吊运行车 (§6-14): a bridge crane across the logistics bay on two rails, its
    trolley with a pallet of medical supplies hanging under it. Stands on two
    legs at the ends; the beam is high."""
    h = 6.5
    legs = [d.bbox(f"gc_leg{s}", (0.6, 0.6, h), (s * span / 2, 0, h / 2)) for s in (-1, 1)]
    beam = [d.bbox("gc_beam", (span + 0.6, 0.7, 0.8), (0, 0, h + 0.4)), d.bbox("gc_trolley", (1.6, 1.2, 0.6), (4.0, 0, h - 0.2))]
    cable = [d.cyl("gc_cable", 0.03, 2.4, (4.0, 0, h - 1.7))]
    load = [d.bbox("gc_pallet", (1.6, 1.2, 0.15), (4.0, 0, h - 2.95)), d.bbox("gc_load", (1.4, 1.0, 0.9), (4.0, 0, h - 2.4))]
    stripes = [d.bbox(f"gc_hz{k}", (1.4, 0.72, 0.2), (-span / 2 + 2 + k * 3.6, 0, h + 0.4)) for k in range(8)]
    return [(join("gc_steel", legs + beam + cable), steel("base_gc_m", 3, PANEL), "steel"),
            (join("gc_hz_j", stripes), paint("base_gc_hz_m", SAFETY), "stripe"),
            (join("gc_load_j", load), steel("base_gc_load_m", 5, WHITE), "load")]


def base_big_screen():
    """The hall's hanging screen (§6-24): two screens back to back on a frame
    hung from the ceiling, the logo turning on them (no lettering)."""
    frame = [d.bbox("bs_frame", (7.4, 0.5, 2.6), (0, 0, 1.3)), d.cyl("bs_hang0", 0.05, 2.0, (-2.8, 0, 3.6)), d.cyl("bs_hang1", 0.05, 2.0, (2.8, 0, 3.6))]
    screen = [d.bbox("bs_scr", (7.0, 0.04, 2.2), (0, 0.27, 1.3))]
    logo = kit.box("bs_logo", (1.6, 0.03, 1.6), (0, 0.3, 1.3))
    return [(join("bs_frame_j", frame), steel("base_bs_m", 3, HULL), "frame"),
            (join("bs_scr_j", screen), glow("base_bs_scr_m", "2f7fb8"), "screen_glow"),
            (logo, logo_decal("base_bs_logo_m", "2f7fb8"), "logo")]


def base_floor_joint(length=4.0):
    """甲板伸缩节 (§6-8): a 1 m metal expansion joint across the deck, toothed
    seam and rivets, yellow edges; the ship is built in sections."""
    plate = [d.bbox("fj_plate", (length, 1.0, 0.04), (0, 0, 0.02))]
    teeth = [d.bbox(f"fj_t{k}", (0.25, 0.3, 0.05), (-length / 2 + 0.25 + k * 0.5, 0.12 * (1 if k % 2 else -1), 0.03)) for k in range(int(length / 0.5))]
    edges = [d.bbox(f"fj_e{s}", (length, 0.1, 0.05), (0, s * 0.5, 0.03)) for s in (-1, 1)]
    return [(join("fj_plate_j", plate + teeth), steel("base_fj_m", 4, "6a737a"), "plate"),
            (join("fj_edges", edges), paint("base_fj_edge_m", SAFETY), "edge")]


# --- The holographic sand table (用户 2026-10-18: 经典的全息沙盘，蓝色数字罗德岛) --------

def base_holo_table(width=32.4, depth=20.6):
    """全息沙盘台: a long low table whose top is a dark emitter plate ringed by a
    lit rail; the map of Terra itself is projected over it in the game
    (world/base_hologram.gdshader), so only the hardware is modelled here:
    the body, the emitter plate, projector heads at the corners and a step
    round it."""
    body = [d.bbox("ht_base", (width, depth, 0.9), (0, 0, 0.45)), d.bbox("ht_step", (width + 1.2, depth + 1.2, 0.18), (0, 0, 0.09))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            body.append(d.bbox(f"ht_head{sx}{sy}", (0.7, 0.7, 0.55), (sx * (width / 2 - 0.2), sy * (depth / 2 - 0.2), 1.15)))
    plate = [d.bbox("ht_plate", (width - 0.8, depth - 0.8, 0.06), (0, 0, 0.93))]
    rail = [d.bbox(f"ht_rail{k}", sz, loc) for k, (sz, loc) in enumerate((
        ((width - 0.4, 0.12, 0.06), (0, depth / 2 - 0.25, 0.96)), ((width - 0.4, 0.12, 0.06), (0, -depth / 2 + 0.25, 0.96)),
        ((0.12, depth - 0.4, 0.06), (width / 2 - 0.25, 0, 0.96)), ((0.12, depth - 0.4, 0.06), (-width / 2 + 0.25, 0, 0.96))))]
    lenses = [d.cyl(f"ht_lens{sx}{sy}", 0.22, 0.06, (sx * (width / 2 - 0.2), sy * (depth / 2 - 0.2), 1.45), vertices=16)
              for sx in (-1, 1) for sy in (-1, 1)]
    trim = [d.bbox(f"ht_hz{k}", (1.2, 0.06, 0.16), (-width / 2 + 1.5 + k * 3.0, depth / 2 + 0.03, 0.5)) for k in range(int((width - 1.5) // 3.0))]
    return [(join("ht_body", body), steel("base_ht_body_m", 4, HULL), "body"),
            (join("ht_plate_j", plate), paint("base_ht_plate_m", "142028"), "plate"),
            (join("ht_trim", trim), paint("base_ht_trim_m", SAFETY), "trim"),
            (join("ht_rail_j", rail + lenses), glow("base_ht_rail_m", "4fb8e0"), "rail_glow")]


def base_holo_rhodes():
    """The little Rhodes Island the sand table shows where the ship is: hull on
    its tracks, the stepped decks, the bridge block, the mining drum at the
    bow (+X). About 1.6 m long; drawn as a blue hologram in the game, so its
    one material is plain white."""
    parts = [d.bbox("hr_hull", (1.3, 0.42, 0.12), (0, 0, 0.12)), d.bbox("hr_d1", (1.05, 0.38, 0.1), (-0.1, 0, 0.23)),
             d.bbox("hr_d2", (0.75, 0.3, 0.1), (-0.2, 0, 0.33)), d.bbox("hr_d3", (0.42, 0.24, 0.1), (-0.32, 0, 0.43)),
             d.bbox("hr_bridge", (0.22, 0.18, 0.1), (-0.4, 0, 0.53)), d.cyl("hr_mast", 0.015, 0.16, (-0.45, 0, 0.66), vertices=6)]
    for side in (-1, 1):
        parts.append(d.bbox(f"hr_trk{side}", (1.2, 0.1, 0.1), (-0.04, side * 0.24, 0.05)))
    parts.append(d.cyl("hr_drum", 0.11, 0.34, (0.78, 0, 0.13), (1.5708, 0, 0), 12))
    return [(join("hr_j", parts), paint("base_hr_m", "ffffff"), "body")]


# --- B-M2/B-M3: the other rooms (用户 2026-10-18: 完成其他房间) --------------------
# Same conventions as the hall: origin at the bottom centre, front (+Y) to the
# camera. Sizes follow each room's old pixel props (15 px a unit across).

PURPLE = "8a6ad0"    # trinkets
GREEN = "5aa86a"     # materials
RED = "c8483a"       # alert


# Store (可露希尔的商店) ---------------------------------------------------------------

def base_store_counter(width=5.6):
    """可露希尔的柜台: a long counter, orange top trim, a till with its screen,
    goods and a little desk lamp on top; she stands behind it (north)."""
    body = [d.bbox("sc_base", (width, 0.9, 1.0), (0, 0, 0.5)), d.bbox("sc_top", (width + 0.2, 1.05, 0.08), (0, 0, 1.04)),
            d.bbox("sc_kick", (width - 0.2, 0.1, 0.14), (0, 0.42, 0.07))]
    trim = [d.bbox("sc_trim", (width + 0.2, 0.06, 0.1), (0, 0.53, 0.98)), d.bbox("sc_band", (width, 0.04, 0.12), (0, 0.46, 0.6))]
    till = [d.bbox("sc_till", (0.7, 0.5, 0.25), (-1.6, 0, 1.2)), d.bbox("sc_tstand", (0.1, 0.1, 0.35), (-1.6, -0.15, 1.45))]
    screen = [d.bbox("sc_scr", (0.62, 0.05, 0.42), (-1.6, -0.12, 1.75), (math.radians(-12), 0, 0))]
    goods = [d.bbox("sc_g0", (0.5, 0.4, 0.35), (0.4, -0.1, 1.25)), d.bbox("sc_g1", (0.35, 0.3, 0.28), (0.95, 0.05, 1.22)),
             d.bbox("sc_g2", (0.4, 0.35, 0.5), (2.2, -0.1, 1.33))]
    bottles = [d.cyl(f"sc_b{k}", 0.07, 0.3, (1.5 + k * 0.17, 0.15, 1.23), vertices=10) for k in range(4)]
    lamp = [d.cyl("sc_lp", 0.03, 0.5, (-0.5, -0.3, 1.33)), d.cyl("sc_ls", 0.17, 0.14, (-0.5, -0.15, 1.6), (math.radians(60), 0, 0), 12)]
    plate = kit.box("sc_logo", (0.5, 0.02, 0.5), (-2.3, 0.46, 0.6))
    return [(join("sc_body", body + till + lamp), steel("base_sc_body_m", 4, PANEL), "body"),
            (join("sc_trim_j", trim), paint("base_sc_trim_m", ORANGE, "a24e1e"), "trim"),
            (join("sc_goods", goods), steel("base_sc_goods_m", 6, WHITE), "goods"),
            (join("sc_bottles", bottles), paint("base_sc_bottle_m", "5a9ad0", "3a6f9e"), "bottle"),
            (plate, logo_decal("base_sc_logo_m", PANEL), "logo"),
            (join("sc_scr_j", screen), glow("base_sc_glow_m"), "glow")]


def base_pendant_lamp():
    """A shop pendant lamp: an orange shade on a cable, its bulb lit (hung
    high; its origin is the shade's bottom)."""
    shade = [d.cyl("pd_shade", 0.42, 0.3, (0, 0, 0.15), vertices=16), d.cyl("pd_cap", 0.12, 0.15, (0, 0, 0.36), vertices=10),
             d.cyl("pd_cable", 0.015, 1.4, (0, 0, 1.1), vertices=6)]
    bulb = [d.cyl("pd_bulb", 0.3, 0.04, (0, 0, 0.01), vertices=16)]
    return [(join("pd_j", shade), paint("base_pd_m", ORANGE, "a24e1e"), "shade"),
            (join("pd_bulb_j", bulb), glow("base_pd_glow_m", "ffd890"), "glow")]


def _display_case(name, width, weapon):
    base = [d.bbox(f"{name}_base", (width, 0.85, 0.75), (0, 0, 0.38)), d.bbox(f"{name}_lip", (width + 0.1, 0.95, 0.06), (0, 0, 0.78))]
    posts = [d.bbox(f"{name}_p{k}", (0.06, 0.06, 0.6), (sx * (width / 2 - 0.03), sy * 0.42, 1.1))
             for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    posts += [d.bbox(f"{name}_t{s}", (width, 0.05, 0.05), (0, s * 0.42, 1.4)) for s in (-1, 1)]
    posts += [d.bbox(f"{name}_e{s}", (0.05, 0.85, 0.05), (s * (width / 2 - 0.03), 0, 1.4)) for s in (-1, 1)]
    pad = [d.bbox(f"{name}_pad", (width - 0.3, 0.6, 0.06), (0, 0, 0.84))]
    if weapon:
        item = [d.bbox(f"{name}_blade", (width * 0.62, 0.1, 0.05), (0.2, 0, 0.92)), d.bbox(f"{name}_hilt", (0.5, 0.14, 0.08), (-width * 0.27, 0, 0.93)),
                d.bbox(f"{name}_guard", (0.08, 0.36, 0.08), (-width * 0.16, 0, 0.93))]
    else:
        item = [d.bbox(f"{name}_vest", (0.9, 0.5, 0.18), (-0.5, 0, 0.96)), d.cyl(f"{name}_orb", 0.18, 0.14, (0.7, 0, 0.95), vertices=12)]
    strip = [d.bbox(f"{name}_led", (width - 0.2, 0.03, 0.04), (0, 0.44, 0.7))]
    return [(join(f"{name}_basej", base + posts), steel(f"base_{name}_m", 4, HULL), "base"),
            (join(f"{name}_padj", pad), paint(f"base_{name}_pad_m", "283a48"), "pad"),
            (join(f"{name}_item", item), steel(f"base_{name}_item_m", 6, WHITE), "item"),
            (join(f"{name}_ledj", strip), glow(f"base_{name}_glow_m", "8fd8f0"), "glow")]


def base_display_case():
    """A glass-topped display case (seen from above, the glass is only its
    frame): a vest and a charm on dark felt, lit along its front."""
    return _display_case("dcs", 3.2, False)


def base_display_case_weapon():
    """The same case with a sword laid in it."""
    return _display_case("dcw", 3.0, True)


def base_goods_shelf(width=4.4, height=2.6):
    """Shelves of goods against the store's back wall: three boards of boxes,
    tins and bottles in Rhodes colours."""
    frame = [d.bbox("gs_back", (width, 0.1, height), (0, -0.25, height / 2))]
    frame += [d.bbox(f"gs_side{s}", (0.08, 0.6, height), (s * (width / 2 - 0.04), 0, height / 2)) for s in (-1, 1)]
    frame += [d.bbox(f"gs_board{k}", (width, 0.6, 0.06), (0, 0, 0.3 + k * 0.75)) for k in range(4)]
    goods = {"w": [], "b": [], "o": []}
    keys = ["w", "b", "o", "w", "b", "w"]
    for k in range(3):
        x = -width / 2 + 0.3
        i = 0
        while x < width / 2 - 0.4:
            w = 0.3 + ((i * 7 + k * 3) % 4) * 0.08
            h = 0.3 + ((i * 5 + k) % 3) * 0.12
            goods[keys[(i + k) % len(keys)]].append(d.bbox(f"gs_i{k}_{i}", (w, 0.4, h), (x + w / 2, 0.02, 0.33 + k * 0.75 + h / 2)))
            x += w + 0.06
            i += 1
    return [(join("gs_frame", frame), steel("base_gs_m", 3, HULL), "frame"),
            (join("gs_white", goods["w"]), steel("base_gs_w_m", 5, WHITE), "white"),
            (join("gs_blue", goods["b"]), paint("base_gs_b_m", BLUE, "2c5880"), "blue"),
            (join("gs_orange", goods["o"]), paint("base_gs_o_m", ORANGE, "a24e1e"), "orange")]


def base_store_sign():
    """The shop's wall sign: the logo on a dark plate, an orange bar under it,
    a lit edge (no lettering)."""
    plate = [d.bbox("ss_plate", (3.2, 0.12, 1.4), (0, 0, 0.7))]
    bar = [d.bbox("ss_bar", (3.0, 0.05, 0.16), (0, 0.07, 0.16))]
    logo = kit.box("ss_logo", (1.0, 0.03, 1.0), (0, 0.08, 0.78))
    edge = [d.bbox("ss_glow", (3.2, 0.04, 0.05), (0, 0.07, 1.38))]
    return [(join("ss_platej", plate), steel("base_ss_m", 2, HULL), "plate"),
            (join("ss_barj", bar), paint("base_ss_bar_m", ORANGE), "bar"),
            (logo, logo_decal("base_ss_logo_m", HULL), "logo"),
            (join("ss_glow_j", edge), glow("base_ss_glow_m", "ffd890"), "glow")]


# Armory ----------------------------------------------------------------------------

def base_armory_bench(width=6.0):
    """整备台: a heavy workbench, yellow-edged, a vice and a weapon on it, a
    tool panel at its back and a screen on an arm."""
    body = [d.bbox("ab_top", (width, 1.2, 0.12), (0, 0, 0.92)), d.bbox("ab_lo", (width - 0.4, 1.0, 0.7), (0, 0, 0.38)),
            d.bbox("ab_back", (width, 0.12, 1.1), (0, -0.55, 1.5))]
    drawers = [d.bbox(f"ab_dr{k}", (1.2, 0.04, 0.2), (-2.0 + k * 1.35, 0.51, 0.55)) for k in range(4)]
    trim = [d.bbox("ab_edge", (width, 0.06, 0.1), (0, 0.62, 0.94))]
    vice = [d.bbox("ab_vice", (0.4, 0.5, 0.3), (2.0, 0.1, 1.13)), d.bbox("ab_jaw", (0.5, 0.12, 0.2), (2.0, 0.38, 1.18))]
    tools = [d.bbox(f"ab_tool{k}", (0.06, 0.04, 0.5 + 0.1 * (k % 3)), (-2.4 + k * 0.3, -0.47, 1.55)) for k in range(8)]
    rifle = [d.bbox("ab_rifle", (2.0, 0.22, 0.12), (-0.3, 0.1, 1.05)), d.bbox("ab_stock", (0.5, 0.18, 0.2), (-1.35, 0.1, 1.07)),
             d.bbox("ab_mag", (0.15, 0.1, 0.3), (-0.2, 0.1, 0.95))]
    arm = [d.cyl("ab_arm", 0.04, 0.9, (1.0, -0.45, 1.5)), d.bbox("ab_mon", (1.0, 0.08, 0.62), (1.0, -0.4, 2.1))]
    screen = [d.bbox("ab_scr", (0.9, 0.02, 0.52), (1.0, -0.35, 2.1))]
    return [(join("ab_body", body + drawers + vice + arm), steel("base_ab_m", 4, HULL), "body"),
            (join("ab_trim", trim), paint("base_ab_trim_m", SAFETY), "trim"),
            (join("ab_tools", tools + rifle), steel("base_ab_tools_m", 2, PANEL), "tools"),
            (join("ab_scr_j", screen), glow("base_ab_glow_m"), "glow")]


def base_armory_rail(length=29.0):
    """The armory's overhead hoist rail: an I-beam the room's length, hung on
    brackets, yellow end stops (hung high; origin at the beam's bottom)."""
    beam = [d.bbox("ar_web", (length, 0.08, 0.36), (0, 0, 0.22)), d.bbox("ar_top", (length, 0.3, 0.06), (0, 0, 0.42)),
            d.bbox("ar_bot", (length, 0.3, 0.06), (0, 0, 0.03))]
    hangers = [d.bbox(f"ar_h{k}", (0.12, 0.12, 1.4), (-length / 2 + 1 + k * 3.0, 0, 1.15)) for k in range(int(length // 3.0) + 1)]
    stops = [d.bbox(f"ar_s{s}", (0.2, 0.4, 0.5), (s * (length / 2 - 0.1), 0, 0.2)) for s in (-1, 1)]
    return [(join("ar_beam", beam + hangers), steel("base_ar_m", 3, PANEL), "beam"),
            (join("ar_stops", stops), paint("base_ar_stop_m", SAFETY), "stop")]


def base_rail_hoist():
    """A hoist on the overhead rail lowering a weapon case: the trolley at the
    rail (3.4 m), a chain, the hook and the case hanging at waist height."""
    trolley = [d.bbox("rh_trolley", (0.8, 0.5, 0.4), (0, 0, 3.15)), d.bbox("rh_motor", (0.4, 0.4, 0.4), (0, 0.35, 3.1))]
    chain = [d.cyl(f"rh_ch{k}", 0.025, 1.4, (k * 0.12 - 0.06, 0, 2.25), vertices=6) for k in range(2)]
    hook = [d.bbox("rh_block", (0.3, 0.2, 0.3), (0, 0, 1.45)), d.bbox("rh_spreader", (1.6, 0.1, 0.08), (0, 0, 1.25))]
    case = [d.bbox("rh_case", (1.8, 0.6, 0.45), (0, 0, 0.95)), d.bbox("rh_lid", (1.84, 0.64, 0.06), (0, 0, 1.2))]
    stripe = [d.bbox("rh_hz", (0.82, 0.52, 0.1), (0, 0, 3.4))]
    return [(join("rh_steel", trolley + chain + hook), steel("base_rh_m", 3, HULL), "steel"),
            (join("rh_case_j", case), steel("base_rh_case_m", 5, WHITE), "case"),
            (join("rh_hz_j", stripe), paint("base_rh_hz_m", SAFETY), "stripe")]


def base_bench_lamp():
    """A long work lamp over the bench, hung on two rods (origin at its bottom)."""
    lamp = [d.bbox("bl_body", (2.6, 0.4, 0.14), (0, 0, 0.1)), d.cyl("bl_r0", 0.02, 1.2, (-1.0, 0, 0.75), vertices=6),
            d.cyl("bl_r1", 0.02, 1.2, (1.0, 0, 0.75), vertices=6)]
    tube = [d.bbox("bl_tube", (2.4, 0.3, 0.03), (0, 0, 0.02))]
    return [(join("bl_j", lamp), steel("base_bl_m", 3, PANEL), "body"),
            (join("bl_glow", tube), glow("base_bl_glow_m", "eaf4ff"), "glow")]


def base_robot_arm():
    """An assembly robot arm on its plinth, white and orange, reaching over."""
    plinth = [d.bbox("ra_plinth", (1.4, 1.2, 0.4), (0, 0, 0.2)), d.cyl("ra_turret", 0.4, 0.5, (0, 0, 0.65), vertices=16)]
    links = [d.bbox("ra_l1", (0.32, 0.32, 1.4), (0.25, 0, 1.4), (0, math.radians(20), 0)),
             d.bbox("ra_l2", (1.3, 0.26, 0.26), (0.85, 0, 2.05), (0, math.radians(-25), 0)),
             d.bbox("ra_l3", (0.2, 0.2, 0.5), (1.45, 0, 1.55))]
    joints = [d.cyl(f"ra_j{k}", 0.22 - k * 0.04, 0.4, p, (math.radians(90), 0, 0), 14) for k, p in enumerate(((0, 0, 0.95), (0.5, 0, 2.0), (1.4, 0, 1.8)))]
    grip = [d.bbox("ra_g0", (0.06, 0.2, 0.25), (1.38, 0, 1.2)), d.bbox("ra_g1", (0.06, 0.2, 0.25), (1.52, 0, 1.2))]
    return [(join("ra_white", links + plinth[1:]), steel("base_ra_m", 5, WHITE), "white"),
            (join("ra_dark", plinth[:1] + grip), steel("base_ra_dark_m", 3, HULL), "dark"),
            (join("ra_orange", joints), paint("base_ra_o_m", ORANGE, "a24e1e"), "joint")]


def base_weapon_wall_rack(width=5.0):
    """A wall rack of weapons: a dark board with rifles, blades and a shield
    racked on pegs, a light along the top."""
    board = [d.bbox("wr_board", (width, 0.12, 2.0), (0, 0, 1.9)), d.bbox("wr_shelf", (width, 0.4, 0.08), (0, 0.15, 0.95))]
    pegs = [d.bbox(f"wr_peg{k}", (0.06, 0.2, 0.06), (-width / 2 + 0.5 + k * 0.6, 0.12, z)) for k in range(int(width / 0.6)) for z in (1.4, 2.4)]
    arms = []
    for k in range(int(width / 0.6) - 1):
        x = -width / 2 + 0.8 + k * 0.6
        if k % 3 == 2:
            arms.append(d.bbox(f"wr_blade{k}", (0.12, 0.06, 1.6), (x, 0.18, 1.85)))
        else:
            arms += [d.bbox(f"wr_gun{k}", (0.16, 0.1, 1.5), (x, 0.18, 1.85)), d.bbox(f"wr_gstock{k}", (0.22, 0.12, 0.3), (x, 0.18, 1.15))]
    shield = [d.bbox("wr_shield", (0.9, 0.1, 1.1), (width / 2 - 0.6, 0.2, 1.6))]
    light = [d.bbox("wr_light", (width - 0.2, 0.05, 0.06), (0, 0.08, 2.86))]
    return [(join("wr_board_j", board + pegs), steel("base_wr_m", 3, HULL), "board"),
            (join("wr_arms", arms), steel("base_wr_arm_m", 2, "5c646a"), "arms"),
            (join("wr_shield_j", shield), paint("base_wr_shield_m", BLUE, "2c5880"), "shield"),
            (join("wr_light_j", light), glow("base_wr_glow_m", "eaf4ff"), "glow")]


# Medical bay -----------------------------------------------------------------------

def base_med_reception(width=5.6):
    """医疗前台: a white curved desk, a blue band, two monitors and a nurse's
    chair behind it (north)."""
    body = [d.bbox("mr_body", (width, 1.0, 1.05), (0, 0, 0.53)), d.bbox("mr_top", (width + 0.2, 1.15, 0.08), (0, 0, 1.08))]
    for s in (-1, 1):
        body.append(d.bbox(f"mr_wing{s}", (0.9, 1.0, 1.05), (s * (width / 2 + 0.3), -0.4, 0.53), (0, 0, math.radians(30 * s))))
    band = [d.bbox("mr_band", (width, 0.04, 0.18), (0, 0.51, 0.7))]
    cases, scr = [], []
    for k, x in enumerate((-1.0, 0.8)):
        c, s = _monitor(f"mr_m{k}", x, -0.25, 1.55, 0.8, 0.5)
        cases += c
        scr.append(s)
    chair = [d.bbox("mr_seat", (0.6, 0.6, 0.1), (0, -1.0, 0.5)), d.bbox("mr_bk", (0.6, 0.08, 0.6), (0, -1.3, 0.85))]
    mark = kit.box("mr_logo", (0.55, 0.02, 0.55), (-2.2, 0.52, 0.65))
    return [(join("mr_body_j", body), steel("base_mr_m", 5, WHITE), "body"),
            (join("mr_band_j", band), paint("base_mr_band_m", BLUE), "band"),
            (join("mr_dark", cases + chair), steel("base_mr_dark_m", 3, PANEL), "dark"),
            (mark, logo_decal("base_mr_logo_m", WHITE), "logo"),
            (join("mr_scr", scr), glow("base_mr_glow_m", "7fe0c0"), "glow")]


def base_med_alert():
    """The front desk's alert: an amber beacon and an amber banner screen, set
    on the desk while a report or an injury waits (MedicalView)."""
    beacon = [d.cyl("ma_beacon", 0.16, 0.3, (2.2, -0.1, 1.27), vertices=12)]
    banner = [d.bbox("ma_banner", (1.8, 0.03, 0.22), (0, 0.55, 0.95))]
    return [(join("ma_j", beacon + banner), glow("base_ma_glow_m", "ffb040"), "glow")]


def base_med_sink():
    """A wash station: white cabinet, steel basin and tap, a dispenser."""
    body = [d.bbox("ms_cab", (1.8, 0.7, 0.85), (0, 0, 0.43)), d.bbox("ms_top", (1.9, 0.75, 0.06), (0, 0, 0.88)),
            d.bbox("ms_splash", (1.9, 0.08, 0.6), (0, -0.33, 1.2))]
    basin = [d.bbox("ms_basin", (0.7, 0.45, 0.06), (-0.3, 0.05, 0.9)), d.cyl("ms_tap", 0.03, 0.3, (-0.3, -0.2, 1.05), vertices=8),
             d.bbox("ms_disp", (0.18, 0.12, 0.3), (0.5, -0.25, 1.2))]
    return [(join("ms_body", body), steel("base_ms_m", 5, WHITE), "body"),
            (join("ms_steel", basin), steel("base_ms_steel_m", 2, "a8b0b4"), "steel")]


def base_scan_gate(width=2.6):
    """The contamination scan gate in the corridor wall's gap: two white posts
    with blue light bars, a lintel, green status lamps (scenery, always green)."""
    posts = [d.bbox(f"sg_p{s}", (0.35, 0.6, 2.6), (s * (width / 2 + 0.17), 0, 1.3)) for s in (-1, 1)]
    posts.append(d.bbox("sg_top", (width + 0.7, 0.6, 0.3), (0, 0, 2.75)))
    bars = [d.bbox(f"sg_b{s}{k}", (0.05, 0.4, 0.06), (s * (width / 2 + 0.0), 0, 0.5 + k * 0.45)) for s in (-1, 1) for k in range(5)]
    lamps = [d.cyl(f"sg_l{s}", 0.1, 0.1, (s * 0.8, 0.31, 2.75), (math.radians(90), 0, 0), 10) for s in (-1, 1)]
    return [(join("sg_body", posts), steel("base_sg_m", 5, WHITE), "body"),
            (join("sg_bars", bars), glow("base_sg_bar_m", "6fc8ff"), "bar_glow"),
            (join("sg_lamps", lamps), glow("base_sg_lamp_m", "70f090"), "lamp_glow")]


def _bed(name, used):
    """A hospital bed, head to the north (-Y): frame, rails, mattress, pillow
    and the blanket (turned back when empty, over a patient when used)."""
    frame = [d.bbox(f"{name}_frame", (1.2, 2.3, 0.3), (0, 0, 0.45)), d.bbox(f"{name}_head", (1.3, 0.1, 1.0), (0, -1.15, 0.6)),
             d.bbox(f"{name}_foot", (1.3, 0.1, 0.7), (0, 1.15, 0.45))]
    frame += [d.cyl(f"{name}_w{k}", 0.08, 0.06, (sx * 0.5, sy * 1.0, 0.08), (0, math.radians(90), 0), 10)
              for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    rails = [d.bbox(f"{name}_rail{s}", (0.05, 1.2, 0.25), (s * 0.62, -0.2, 0.85)) for s in (-1, 1)]
    mattress = [d.bbox(f"{name}_mat", (1.1, 2.1, 0.18), (0, 0, 0.69)), d.bbox(f"{name}_pil", (0.8, 0.4, 0.14), (0, -0.82, 0.85))]
    if used:
        blanket = [d.bbox(f"{name}_bl", (1.15, 1.4, 0.16), (0, 0.3, 0.82)), kit.rock(f"{name}_body", 0.32, (0, -0.1, 0.92), (1.0, 2.2, 0.45), 1)]
    else:
        blanket = [d.bbox(f"{name}_bl", (1.15, 0.9, 0.08), (0, 0.55, 0.8)), d.bbox(f"{name}_fold", (1.15, 0.3, 0.12), (0, 0.05, 0.82))]
    return [(join(f"{name}_frame_j", frame + rails), steel(f"base_{name}_m", 4, "b8c2c8"), "frame"),
            (join(f"{name}_mat_j", mattress), paint(f"base_{name}_mat_m", WHITE, "b0b8bc"), "mattress"),
            (join(f"{name}_bl_j", blanket), paint(f"base_{name}_bl_m", "6a9ac8", "4a78a8"), "blanket")]


def base_med_bed():
    """An empty ward bed, made up."""
    return _bed("mb", False)


def base_med_bed_used():
    """A ward bed with someone in it."""
    return _bed("mbu", True)


def base_iv_stand():
    """An IV drip stand: five-footed base, a pole, a bag hanging from the hook."""
    base = [d.cyl("iv_hub", 0.06, 0.1, (0, 0, 0.08), vertices=8)]
    base += [d.bbox(f"iv_f{k}", (0.32, 0.04, 0.03), (0.16 * math.cos(k * math.tau / 5), 0.16 * math.sin(k * math.tau / 5), 0.04), (0, 0, k * math.tau / 5)) for k in range(5)]
    base += [d.cyl("iv_pole", 0.02, 2.0, (0, 0, 1.05), vertices=8), d.bbox("iv_hook", (0.4, 0.03, 0.03), (0, 0, 2.02))]
    bag = [d.bbox("iv_bag", (0.16, 0.06, 0.26), (0.15, 0, 1.82))]
    return [(join("iv_j", base), steel("base_iv_m", 2, "b8c2c8"), "steel"),
            (join("iv_bag_j", bag), glow("base_iv_bag_m", "c8f0ff"), "bag_glow")]


def base_med_icu():
    """ICU bed: a bed beside a tall machine with screens and tubes."""
    parts = _bed("mi", True)
    tower = [d.bbox("mi_tower", (0.7, 0.6, 1.8), (1.2, -0.7, 0.9)), d.bbox("mi_arm", (0.6, 0.08, 0.08), (0.9, -0.7, 1.7))]
    scr = [d.bbox("mi_scr", (0.55, 0.03, 0.42), (1.2, -0.39, 1.45)), d.bbox("mi_scr2", (0.5, 0.03, 0.3), (1.2, -0.39, 0.95))]
    return parts + [(join("mi_tower_j", tower), steel("base_mi_tower_m", 4, PANEL), "tower"),
                    (join("mi_scr_j", scr), glow("base_mi_glow_m", "7fe0a0"), "glow")]


def base_med_monitor_arm():
    """Overhead in the treatment room: a ceiling boom with two vitals screens
    and a round surgical light (hung; origin at its lowest point)."""
    boom = [d.cyl("mm_mast", 0.06, 1.2, (0, 0, 1.4), vertices=8), d.bbox("mm_boom", (2.0, 0.12, 0.12), (0, 0, 0.8))]
    cases = [d.bbox(f"mm_case{s}", (0.8, 0.1, 0.5), (s * 0.55, 0.05, 0.4)) for s in (-1, 1)]
    lamp = [d.cyl("mm_lamp", 0.4, 0.1, (0.95, -0.4, 0.55), vertices=16)]
    scr = [d.bbox(f"mm_scr{s}", (0.7, 0.03, 0.4), (s * 0.55, 0.11, 0.4)) for s in (-1, 1)]
    lens = [d.cyl("mm_lens", 0.32, 0.03, (0.95, -0.4, 0.49), vertices=16)]
    return [(join("mm_body", boom + cases + lamp), steel("base_mm_m", 4, WHITE), "body"),
            (join("mm_scr_j", scr), glow("base_mm_glow_m", "7fe0c0"), "glow"),
            (join("mm_lens_j", lens), glow("base_mm_lens_m", "f4fbff"), "lens_glow")]


def base_med_exam():
    """A treatment couch with its console: padded table, a console with a
    screen on its head end."""
    table = [d.bbox("me_base", (0.6, 1.6, 0.6), (0, 0, 0.3)), d.bbox("me_pad", (1.0, 2.2, 0.16), (0, 0, 0.72))]
    console = [d.bbox("me_con", (1.6, 0.6, 1.0), (1.4, -0.7, 0.5)), d.bbox("me_mon", (0.9, 0.08, 0.6), (1.4, -0.85, 1.4))]
    scr = [d.bbox("me_scr", (0.8, 0.02, 0.5), (1.4, -0.8, 1.4))]
    return [(join("me_steel", table[:1] + console), steel("base_me_m", 5, WHITE), "body"),
            (join("me_pad_j", table[1:]), paint("base_me_pad_m", "5a8ab8", "3a6a98"), "pad"),
            (join("me_scr_j", scr), glow("base_me_glow_m", "7fe0c0"), "glow")]


def base_med_partition(length=4.0):
    """A ward partition: a white half wall 0.3 m thick with a blue line and a
    teal cap rail, glazing bars up to 2.2 m and a top rail (the glass itself
    left out, so the beds behind show). Thick enough to read from above
    (用户 2026-10-18: 医疗部太空了)."""
    wall = [d.bbox("mp_low", (length, 0.3, 1.05), (0, 0, 0.53))]
    cap = [d.bbox("mp_cap", (length, 0.36, 0.08), (0, 0, 1.09))]
    bars = [d.bbox(f"mp_bar{k}", (0.08, 0.1, 1.15), (-length / 2 + 0.04 + k * length / 4, 0, 1.68)) for k in range(5)]
    bars.append(d.bbox("mp_top", (length, 0.14, 0.1), (0, 0, 2.25)))
    line = [d.bbox("mp_line", (length, 0.32, 0.08), (0, 0, 0.75))]
    return [(join("mp_wall", wall + bars), steel("base_mp_m", 5, WHITE), "wall"),
            (join("mp_cap_j", cap), paint("base_mp_cap_m", TEAL), "cap"),
            (join("mp_line_j", line), paint("base_mp_line_m", BLUE), "line")]


def base_med_cabinet():
    """A tall white supply cabinet against a wall, glass-fronted shelves of
    boxes, a green light strip."""
    body = [d.bbox("mc2_body", (1.6, 0.6, 2.2), (0, 0, 1.1))]
    shelves = [d.bbox(f"mc2_box{k}", (0.32, 0.3, 0.25), (-0.55 + (k % 4) * 0.37, 0.18, 0.7 + (k // 4) * 0.55)) for k in range(12)]
    strip = [d.bbox("mc2_led", (1.5, 0.04, 0.05), (0, 0.31, 2.1))]
    return [(join("mc2_j", body), steel("base_mc2_m", 5, WHITE), "body"),
            (join("mc2_boxes", shelves), paint("base_mc2_box_m", "6a9ac8", "4a78a8"), "boxes"),
            (join("mc2_glow", strip), glow("base_mc2_glow_m", "70f0a0"), "glow")]


# Warehouse -------------------------------------------------------------------------

RACK_W, RACK_D, RACK_H = 4.2, 1.2, 2.7
## The cells on a rack's face (WarehouseView.cells, an 80x64 rack image):
## four across, three up; their centres in the rack's local metres.
RACK_CELLS = [(-1.5 + c * 1.0, 0.0, 0.55 + r * 0.8) for r in range(3) for c in range(4)]


def _rack(name, colour):
    """A storage rack: yellow uprights, three steel shelves (the cells sit on
    them), a coloured category plate on the top beam, no lettering."""
    ups = [d.bbox(f"{name}_u{k}", (0.1, 0.1, RACK_H), (sx * (RACK_W / 2 - 0.05), sy * (RACK_D / 2 - 0.05), RACK_H / 2))
           for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    shelves = [d.bbox(f"{name}_sh{k}", (RACK_W - 0.1, RACK_D - 0.1, 0.05), (0, 0, 0.18 + k * 0.8)) for k in range(4)]
    beams = [d.bbox(f"{name}_bm{k}", (RACK_W, 0.08, 0.1), (0, RACK_D / 2 - 0.04, 0.2 + k * 0.8)) for k in range(4)]
    braces = [d.bbox(f"{name}_br{s}", (0.04, 0.04, RACK_H * 1.05), (s * (RACK_W / 2 - 0.05), 0, RACK_H / 2), (math.radians(24), 0, 0)) for s in (-1, 1)]
    plate = [d.bbox(f"{name}_plate", (1.0, 0.05, 0.22), (-RACK_W / 2 + 0.7, RACK_D / 2 + 0.01, RACK_H - 0.2))]
    return [(join(f"{name}_up", ups + beams), paint(f"base_{name}_up_m", SAFETY, "a87e18"), "upright"),
            (join(f"{name}_steel", shelves + braces), steel(f"base_{name}_m", 3, PANEL), "steel"),
            (join(f"{name}_plate_j", plate), glow(f"base_{name}_plate_m", colour), "plate_glow")]


def base_rack_weapon():
    """The weapon zone's rack."""
    return _rack("rkw", "f08a40")


def base_rack_armor():
    """The armour zone's rack."""
    return _rack("rka", "5aa0f0")


def base_rack_trinket():
    """The trinket zone's rack."""
    return _rack("rkt", "b890f0")


def base_rack_material():
    """The material zone's rack."""
    return _rack("rkm", "70d080")


def base_cell_weapon():
    """One stored weapon: a long case, laid on a shelf (a rack cell)."""
    return [(join("cw", [d.bbox("cw_case", (0.85, 0.5, 0.2), (0, 0, 0.1)), d.bbox("cw_h", (0.2, 0.06, 0.04), (0, 0.26, 0.12))]),
             steel("base_cw_m", 4, "6a7076"), "case"),
            (join("cw_t", [d.bbox("cw_tag", (0.25, 0.02, 0.1), (-0.25, 0.26, 0.1))]), paint("base_cw_tag_m", ORANGE), "tag")]


def base_cell_armor():
    """One stored armour piece: a folded vest in a tote."""
    return [(join("ca", [d.bbox("ca_tote", (0.75, 0.6, 0.35), (0, 0, 0.18))]), steel("base_ca_m", 4, "3d5a78"), "tote"),
            (join("ca_v", [d.bbox("ca_vest", (0.6, 0.5, 0.12), (0, 0, 0.4))]), paint("base_ca_vest_m", "5a6a50", "3a4a34"), "vest")]


def base_cell_trinket():
    """One stored trinket: a small case with a glint."""
    return [(join("ct", [d.bbox("ct_box", (0.5, 0.45, 0.3), (0, 0, 0.15))]), steel("base_ct_m", 5, WHITE), "box"),
            (join("ct_g", [d.bbox("ct_gem", (0.18, 0.04, 0.12), (0, 0.24, 0.17))]), glow("base_ct_glow_m", "c8a0ff"), "gem_glow")]


def base_cell_material():
    """One stored material lot: a green bin heaped with parts."""
    return [(join("cm", [d.bbox("cm_bin", (0.8, 0.6, 0.32), (0, 0, 0.16))]), paint("base_cm_m", GREEN, "3a7a4a"), "bin"),
            (join("cm_p", [kit.rock("cm_heap", 0.3, (0, 0, 0.34), (1.2, 0.9, 0.4), 1)]), steel("base_cm_heap_m", 3, "8a9298"), "heap")]


def base_rack_hatch():
    """The floor hatch a rack rises out of: a hazard-striped frame round a dark
    pit (the leaves are base_rack_hatch_leaf, moved in the game)."""
    w, dpt = RACK_W + 0.5, RACK_D + 0.5
    frame = [d.bbox(f"rh2_e{k}", sz, loc) for k, (sz, loc) in enumerate((
        ((w + 0.3, 0.15, 0.03), (0, dpt / 2 + 0.07, 0.015)), ((w + 0.3, 0.15, 0.03), (0, -dpt / 2 - 0.07, 0.015)),
        ((0.15, dpt, 0.03), (w / 2 + 0.07, 0, 0.015)), ((0.15, dpt, 0.03), (-w / 2 - 0.07, 0, 0.015))))]
    stripes = [d.bbox(f"rh2_s{k}", (0.14, 0.16, 0.035), (-w / 2 + 0.2 + k * 0.4, dpt / 2 + 0.07, 0.017)) for k in range(int(w / 0.4))]
    pit = [d.bbox("rh2_pit", (w, dpt, 0.01), (0, 0, 0.004))]
    return [(join("rh2_frame", frame), steel("base_rh2_m", 3, "2a2e32"), "frame"),
            (join("rh2_hz", stripes), paint("base_rh2_hz_m", SAFETY), "stripe"),
            (join("rh2_pit_j", pit), paint("base_rh2_pit_m", "0a0c0e"), "pit")]


def base_rack_hatch_leaf():
    """One leaf of a rack hatch: a ribbed plate the hatch wide and half its
    depth, its origin at its inner edge so the game can swing it up about
    its outer edge (the front or back of the pit)."""
    w, dpt = RACK_W + 0.5, (RACK_D + 0.5) / 2
    plate = [d.bbox("hl_plate", (w, dpt, 0.03), (0, -dpt / 2, 0.022))]
    ribs = [d.bbox(f"hl_r{k}", (w - 0.2, 0.05, 0.012), (0, -0.15 - k * 0.22, 0.042)) for k in range(int(dpt / 0.22))]
    edge = [d.bbox("hl_hz", (w, 0.08, 0.035), (0, -0.04, 0.024))]
    return [(join("hl_j", plate + ribs), steel("base_hl_m", 4, "5a6268"), "plate"),
            (join("hl_edge", edge), paint("base_hl_hz_m", SAFETY), "edge")]


def base_recycler():
    """回收炉: a squat recycling furnace, its hopper mouth glowing orange."""
    body = [d.bbox("rc_body", (2.8, 2.0, 1.6), (0, 0, 0.8)), d.bbox("rc_hood", (2.4, 1.4, 0.5), (0, -0.2, 1.85)),
            d.cyl("rc_stack", 0.25, 1.4, (0.9, -0.6, 2.6), vertices=12)]
    mouth = [d.bbox("rc_mouth", (1.8, 0.05, 0.7), (0, 1.01, 0.95))]
    hz = [d.bbox(f"rc_hz{k}", (0.3, 0.04, 0.12), (-1.2 + k * 0.4, 1.02, 0.15), (0, math.radians(30), 0)) for k in range(7)]
    return [(join("rc_j", body), steel("base_rc_m", 4, HULL), "body"),
            (join("rc_hz_j", hz), paint("base_rc_hz_m", SAFETY), "stripe"),
            (join("rc_mouth_j", mouth), glow("base_rc_glow_m", "ff8a30"), "mouth_glow")]


def base_forklift():
    """An engineering forklift, yellow, forks to the north, an operator cage."""
    body = [d.bbox("fk_body", (1.4, 2.2, 0.8), (0, 0.3, 0.6)), d.bbox("fk_cw", (1.4, 0.5, 0.6), (0, 1.25, 0.9))]
    cage = [d.bbox(f"fk_c{k}", (0.08, 0.08, 1.4), (sx * 0.62, sy, 1.7)) for k, (sx, sy) in enumerate(((-1, -0.2), (1, -0.2), (-1, 0.9), (1, 0.9)))]
    cage.append(d.bbox("fk_roof", (1.4, 1.2, 0.06), (0, 0.35, 2.4)))
    mast = [d.bbox(f"fk_m{s}", (0.12, 0.12, 2.6), (s * 0.45, -0.85, 1.3)) for s in (-1, 1)]
    forks = [d.bbox(f"fk_f{s}", (0.12, 1.2, 0.06), (s * 0.3, -1.5, 0.12)) for s in (-1, 1)]
    wheels = [d.cyl(f"fk_w{k}", 0.28, 0.25, (sx * 0.7, sy, 0.28), (0, math.radians(90), 0), 14) for k, (sx, sy) in enumerate(((-1, -0.5), (1, -0.5), (-1, 1.1), (1, 1.1)))]
    return [(join("fk_y", body), paint("base_fk_m", SAFETY, "a87e18"), "body"),
            (join("fk_steel", cage + mast + forks), steel("base_fk_steel_m", 3, HULL), "steel"),
            (join("fk_wheels", wheels), paint("base_fk_wheel_m", RUBBER), "wheel")]


def base_stash_terminal():
    """仓管台: a standing desk with a big screen and a scanner, a lit ring on
    the floor in front of it."""
    body = [d.bbox("sh_desk", (2.6, 1.0, 1.0), (0, 0, 0.5)), d.bbox("sh_top", (2.8, 1.1, 0.08), (0, 0, 1.04))]
    cases, scr = _monitor("sh_m", 0, -0.35, 1.75, 2.0, 1.0)
    scanner = [d.bbox("sh_scan", (0.4, 0.3, 0.15), (0.9, 0.1, 1.16))]
    ring = [d.bbox(f"sh_ring{k}", sz, loc) for k, (sz, loc) in enumerate((((2.4, 0.08, 0.02), (0, 1.9, 0.01)), ((2.4, 0.08, 0.02), (0, 0.8, 0.01)),
                                                                            ((0.08, 1.1, 0.02), (-1.2, 1.35, 0.01)), ((0.08, 1.1, 0.02), (1.2, 1.35, 0.01))))]
    mark = kit.box("sh_logo", (0.5, 0.02, 0.5), (-0.9, 0.51, 0.55))
    return [(join("sh_body", body + cases + scanner), steel("base_sh_m", 4, PANEL), "body"),
            (mark, logo_decal("base_sh_logo_m", PANEL), "logo"),
            (join("sh_glow", [scr] + ring), glow("base_sh_glow_m"), "glow")]


def base_pallet():
    """A steel cargo pallet."""
    deck = [d.bbox(f"pa_s{k}", (2.4, 0.22, 0.05), (0, -0.55 + k * 0.275, 0.17)) for k in range(5)]
    feet = [d.bbox(f"pa_f{k}", (0.15, 1.3, 0.12), (x, 0, 0.06)) for k, x in enumerate((-1.1, 0, 1.1))]
    return [(join("pa_j", deck + feet), steel("base_pa_m", 3, "6a7076"), "body")]


def base_cargo_cart():
    """A hand cart with a crate on it."""
    cart = [d.bbox("cc_bed", (1.8, 1.0, 0.1), (0, 0, 0.3)), d.bbox("cc_handle", (0.06, 1.0, 0.9), (-0.95, 0, 0.75))]
    wheels = [d.cyl(f"cc_w{k}", 0.15, 0.1, (sx * 0.7, sy * 0.45, 0.15), (math.radians(90), 0, 0), 12) for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    load = [d.bbox("cc_box", (1.2, 0.8, 0.7), (0.15, 0, 0.7))]
    return [(join("cc_frame", cart), steel("base_cc_m", 3, HULL), "frame"),
            (join("cc_wheels", wheels), paint("base_cc_w_m", RUBBER), "wheel"),
            (join("cc_load", load), steel("base_cc_box_m", 5, BLUE), "box")]


def base_cargo_lift(width=6.2, depth=3.6):
    """The cargo lift at the south wall: a platform in a hazard-striped frame,
    two lamp posts, its deck a step below the floor."""
    frame = [d.bbox(f"cl2_e{k}", sz, loc) for k, (sz, loc) in enumerate((
        ((width + 0.4, 0.2, 0.08), (0, depth / 2 + 0.1, 0.04)), ((width + 0.4, 0.2, 0.08), (0, -depth / 2 - 0.1, 0.04)),
        ((0.2, depth, 0.08), (width / 2 + 0.1, 0, 0.04)), ((0.2, depth, 0.08), (-width / 2 - 0.1, 0, 0.04))))]
    deck = [d.bbox("cl2_deck", (width, depth, 0.02), (0, 0, 0.01))]
    deck += [d.bbox(f"cl2_rib{k}", (0.06, depth - 0.3, 0.02), (-width / 2 + 0.4 + k * 0.6, 0, 0.025)) for k in range(int(width / 0.6))]
    stripes = [d.bbox(f"cl2_s{k}", (0.2, 0.22, 0.09), (-width / 2 + 0.3 + k * 0.5, depth / 2 + 0.1, 0.045)) for k in range(int(width / 0.5))]
    posts = [d.bbox(f"cl2_p{s}", (0.25, 0.25, 1.6), (s * (width / 2 + 0.4), -depth / 2, 0.8)) for s in (-1, 1)]
    lamps = [d.bbox(f"cl2_l{s}", (0.2, 0.2, 0.15), (s * (width / 2 + 0.4), -depth / 2, 1.7)) for s in (-1, 1)]
    return [(join("cl2_frame", frame + posts), steel("base_cl2_m", 3, HULL), "frame"),
            (join("cl2_deck_j", deck), steel("base_cl2_deck_m", 5, "3a4046"), "deck"),
            (join("cl2_hz", stripes), paint("base_cl2_hz_m", SAFETY), "stripe"),
            (join("cl2_lamp", lamps), glow("base_cl2_glow_m", "f0a040"), "glow")]


def base_floor_frame(width=2.4, depth=2.4):
    """A floor frame: four yellow corners and dashes (receiving bays, staging);
    scaled to size in the game."""
    dashes = []
    for k in range(4):
        t = -0.5 + (k + 0.5) / 4
        for s in (-1, 1):
            dashes.append(d.bbox(f"ff_x{k}{s}", (width / 4 * 0.6, 0.08, 0.015), (t * width, s * depth / 2, 0.008)))
            dashes.append(d.bbox(f"ff_y{k}{s}", (0.08, depth / 4 * 0.6, 0.015), (s * width / 2, t * depth, 0.008)))
    return [(join("ff_j", dashes), paint("base_ff_m", SAFETY), "dash")]


def base_zone_frame(width=5.6, depth=3.2):
    """A storage zone's floor frame under one rack column: a dashed outline."""
    return [(base_floor_frame(width, depth)[0][0], paint("base_zf_m", "8a7a40"), "dash")]


def base_zone_frame_glow(width=5.6, depth=3.2):
    """The same frame lit, while she carries something that belongs there."""
    return [(base_floor_frame(width, depth)[0][0], glow("base_zg_m", "ffe070"), "dash_glow")]


def _crate(name, size, opened, colour):
    w, dpt, h = size
    body = [d.bbox(f"{name}_body", (w, dpt, h), (0, 0, h / 2))]
    bands = [d.bbox(f"{name}_band{s}", (0.08, dpt + 0.04, h + 0.04), (s * (w / 2 - 0.15), 0, h / 2)) for s in (-1, 1)]
    label = [d.bbox(f"{name}_label", (w * 0.35, 0.02, h * 0.25), (0, dpt / 2 + 0.01, h * 0.6))]
    parts = []
    if opened:
        lid = [d.bbox(f"{name}_lid", (w, 0.06, dpt), (0, -dpt / 2 - 0.05, h + dpt / 2 - 0.1), (math.radians(80), 0, 0))]
        inner = [d.bbox(f"{name}_in", (w - 0.12, dpt - 0.12, 0.02), (0, 0, h - 0.02))]
        stuff = [d.bbox(f"{name}_st", (w * 0.5, dpt * 0.5, 0.1), (0, 0, h + 0.02))]
        parts = [(join(f"{name}_lid_j", lid), steel(f"base_{name}_lid_m", 3, colour), "lid"),
                 (join(f"{name}_in_j", inner), paint(f"base_{name}_in_m", "1a1e22"), "inside"),
                 (join(f"{name}_st_j", stuff), steel(f"base_{name}_st_m", 5, WHITE), "stuff")]
    else:
        lid = [d.bbox(f"{name}_lid", (w + 0.06, dpt + 0.06, 0.08), (0, 0, h + 0.03))]
        parts = [(join(f"{name}_lid_j", lid), steel(f"base_{name}_lid_m", 3, colour), "lid")]
    return [(join(f"{name}_body_j", body + bands), steel(f"base_{name}_m", 5, colour), "body"),
            (join(f"{name}_label_j", label), paint(f"base_{name}_label_m", SAFETY), "label")] + parts


CRATE_SIZE = {"small": (0.9, 0.8, 0.6), "medium": (1.4, 1.1, 0.8), "large": (2.0, 1.4, 1.0)}


def base_crate_small_sealed():
    return _crate("cks", CRATE_SIZE["small"], False, PANEL)


def base_crate_small_open():
    return _crate("cko", CRATE_SIZE["small"], True, PANEL)


def base_crate_medium_sealed():
    return _crate("cms", CRATE_SIZE["medium"], False, "6a7a86")


def base_crate_medium_open():
    return _crate("cmo", CRATE_SIZE["medium"], True, "6a7a86")


def base_crate_large_sealed():
    return _crate("cls", CRATE_SIZE["large"], False, BLUE)


def base_crate_large_open():
    return _crate("clo", CRATE_SIZE["large"], True, BLUE)


def base_order_board(width=4.4, height=2.2):
    """订单板 on the north wall: a framed panel, its screen drawn by the game
    in the board's state (open, done, empty)."""
    frame = [d.bbox("ob_frame", (width, 0.15, height), (0, 0, 1.4 + height / 2)), d.bbox("ob_hood", (width + 0.2, 0.4, 0.12), (0, 0.15, 1.4 + height + 0.05))]
    tabs = [d.bbox(f"ob_tab{k}", (0.3, 0.05, 0.3), (-width / 2 + 0.35, 0.09, 1.75 + k * 0.6)) for k in range(3)]
    return [(join("ob_frame_j", frame), steel("base_ob_m", 3, HULL), "frame"),
            (join("ob_tabs", tabs), paint("base_ob_tab_m", SAFETY), "tab")]


def base_cargo_drone():
    """工程部的货运无人机: a quad frame, four rotors, a crate slung under it."""
    hub = [d.bbox("dr_hub", (0.6, 0.6, 0.2), (0, 0, 0.5))]
    arms = [d.bbox(f"dr_arm{k}", (1.1, 0.08, 0.06), (0, 0, 0.55), (0, 0, math.radians(45 + 90 * k))) for k in range(2)]
    rotors = [d.cyl(f"dr_rot{k}", 0.3, 0.03, (0.4 * sx, 0.4 * sy, 0.62), vertices=14) for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    load = [d.bbox("dr_box", (0.55, 0.45, 0.35), (0, 0, 0.18))]
    lamp = [d.bbox("dr_lamp", (0.2, 0.05, 0.05), (0, 0.31, 0.5))]
    return [(join("dr_frame", hub + arms + rotors), steel("base_dr_m", 3, HULL), "frame"),
            (join("dr_load", load), paint("base_dr_box_m", SAFETY, "a87e18"), "load"),
            (join("dr_lamp_j", lamp), glow("base_dr_glow_m", "70f0a0"), "glow")]


ROOM_BUILDERS = [base_store_counter, base_pendant_lamp, base_display_case, base_display_case_weapon, base_goods_shelf, base_store_sign,
                 base_armory_bench, base_armory_rail, base_rail_hoist, base_bench_lamp, base_robot_arm, base_weapon_wall_rack,
                 base_med_reception, base_med_alert, base_med_sink, base_scan_gate, base_med_bed, base_med_bed_used, base_iv_stand,
                 base_med_icu, base_med_monitor_arm, base_med_exam, base_med_partition, base_med_cabinet,
                 base_rack_weapon, base_rack_armor, base_rack_trinket, base_rack_material,
                 base_cell_weapon, base_cell_armor, base_cell_trinket, base_cell_material,
                 base_rack_hatch, base_rack_hatch_leaf, base_recycler, base_forklift, base_stash_terminal, base_pallet,
                 base_cargo_cart, base_cargo_lift, base_floor_frame, base_zone_frame, base_zone_frame_glow,
                 base_crate_small_sealed, base_crate_small_open, base_crate_medium_sealed, base_crate_medium_open,
                 base_crate_large_sealed, base_crate_large_open, base_order_board, base_cargo_drone]


# Medical bay, second pass (用户 2026-10-18: 医疗部表现力不足，太空了) -------------------



def base_wall_panel_med(width=4.0, height=3.6):
    """The medical bay's wall bay: the hull wall in medical white, a teal line
    at waist height and a soft lamp strip (same frame as base_wall_panel)."""
    hull = [d.bbox("wm_back", (width, 0.5, height), (0, -0.25, height / 2))]
    for x in (-width / 2 + 0.12, width / 2 - 0.12):
        hull.append(d.bbox(f"wm_rib{x}", (0.24, 0.16, height), (x, 0.06, height / 2)))
    hull.append(d.bbox("wm_tray", (width, 0.28, 0.16), (0, 0.12, height - 0.3)))
    hull.append(d.bbox("wm_skirt", (width, 0.12, 0.22), (0, 0.04, 0.11)))
    panel = [d.bbox("wm_panel_lo", (width - 0.6, 0.06, 1.3), (0, 0.02, 0.95)),
             d.bbox("wm_panel_hi", (width - 0.6, 0.06, 1.5), (0, 0.02, 2.5))]
    line = [d.bbox("wm_line", (width - 0.5, 0.07, 0.12), (0, 0.06, 1.68))]
    rail = [d.bbox("wm_rail", (width - 0.3, 0.1, 0.08), (0, 0.1, 1.0))]
    lamp = [d.bbox("wm_lamp", (width - 0.8, 0.06, 0.06), (0, 0.24, height - 0.42))]
    return [(join("wm_hull", hull), steel("base_wm_hull_m", 3, "b8c0c4"), "hull"),
            (join("wm_panels", panel + rail), steel("base_wm_panel_m", 5, WHITE), "panel"),
            (join("wm_lines", line), paint("base_wm_line_m", TEAL), "line"),
            (join("wm_lamp_j", lamp), glow("base_wm_lamp_m", "eaf6f8"), "lamp_glow")]


def base_med_bed_side():
    """Beside a ward bed: a white bedside cabinet with a cup and a tablet, a
    vitals monitor on a pole, and a visitor's chair in front (south)."""
    cab = [d.bbox("bs2_cab", (0.6, 0.55, 0.8), (0, 0, 0.4)), d.bbox("bs2_top", (0.66, 0.6, 0.04), (0, 0, 0.82))]
    cab += [d.bbox(f"bs2_dr{k}", (0.5, 0.03, 0.2), (0, 0.29, 0.25 + k * 0.28)) for k in range(2)]
    things = [d.cyl("bs2_cup", 0.05, 0.12, (-0.15, 0.05, 0.9), vertices=10), d.bbox("bs2_book", (0.24, 0.18, 0.04), (0.12, -0.05, 0.86))]
    pole = [d.cyl("bs2_pole", 0.03, 1.5, (0.45, -0.2, 0.75), vertices=8), d.cyl("bs2_base", 0.2, 0.05, (0.45, -0.2, 0.03), vertices=12),
            d.bbox("bs2_mon", (0.5, 0.1, 0.38), (0.45, -0.15, 1.55))]
    screen = [d.bbox("bs2_scr", (0.42, 0.02, 0.3), (0.45, -0.09, 1.55))]
    chair = [d.bbox("bs2_seat", (0.5, 0.5, 0.08), (0.0, 0.9, 0.46)), d.bbox("bs2_back", (0.5, 0.06, 0.5), (0.0, 1.15, 0.75))]
    legs = [d.bbox(f"bs2_leg{k}", (0.04, 0.04, 0.44), (sx * 0.2, 0.9 + sy * 0.2, 0.22)) for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    return [(join("bs2_white", cab), steel("base_bs2_m", 5, WHITE), "cabinet"),
            (join("bs2_steel", pole + legs), steel("base_bs2_pole_m", 3, "a8b0b4"), "steel"),
            (join("bs2_things", things), paint("base_bs2_things_m", TEAL, "2c7a74"), "things"),
            (join("bs2_chair_j", chair), paint("base_bs2_chair_m", "6a8aa0", "4a6a80"), "chair"),
            (join("bs2_scr_j", screen), glow("base_bs2_scr_m", "7fe0c0"), "glow")]


def base_med_curtain(length=2.6):
    """A ward's privacy curtain: a ceiling rail along the bed (+X), the curtain
    drawn a third of the way and gathered in folds at one end."""
    rail = [d.bbox("cu_rail", (length, 0.06, 0.06), (0, 0, 2.35)), d.cyl("cu_h0", 0.02, 0.6, (-length / 2, 0, 2.65), vertices=6),
            d.cyl("cu_h1", 0.02, 0.6, (length / 2, 0, 2.65), vertices=6)]
    folds = []
    for k in range(7):
        x = -length / 2 + 0.1 + k * 0.13
        folds.append(d.bbox(f"cu_f{k}", (0.12, 0.08 + 0.05 * (k % 2), 1.9), (x, 0.03 * (k % 2), 1.3)))
    hem = [d.bbox("cu_hem", (0.95, 0.12, 0.08), (-length / 2 + 0.48, 0, 0.32))]
    return [(join("cu_rail_j", rail), steel("base_cu_rail_m", 2, "b8c0c4"), "rail"),
            (join("cu_folds", folds), paint("base_cu_curtain_m", "8ec8c4", "6aa8a4"), "curtain"),
            (join("cu_hem_j", hem), paint("base_cu_hem_m", TEAL), "hem")]


def base_med_head_panel(width=2.4):
    """The service panel on the wall over a bed's head: gas outlets, sockets,
    a reading lamp and a call button (mounted; origin at its bottom)."""
    panel = [d.bbox("hp_body", (width, 0.12, 0.45), (0, 0.06, 0.22))]
    outlets = [d.cyl(f"hp_o{k}", 0.05, 0.04, (-0.8 + k * 0.25, 0.13, 0.25), (math.radians(90), 0, 0), 10) for k in range(4)]
    lamp = [d.bbox("hp_lamp", (0.7, 0.04, 0.06), (0.6, 0.13, 0.38))]
    call = [d.cyl("hp_call", 0.05, 0.03, (0.95, 0.13, 0.15), (math.radians(90), 0, 0), 10)]
    return [(join("hp_body_j", panel), steel("base_hp_m", 5, WHITE), "body"),
            (join("hp_outlets", outlets), paint("base_hp_o_m", TEAL), "outlets"),
            (join("hp_call_j", call), paint("base_hp_call_m", RED), "call"),
            (join("hp_lamp_j", lamp), glow("base_hp_glow_m", "f4fbff"), "lamp_glow")]


def base_nurse_station(length=3.6):
    """护士站: a long white counter with a teal band, three monitors, files and
    a chair behind (north); its length along +X."""
    body = [d.bbox("ns_body", (length, 0.8, 1.05), (0, 0, 0.53)), d.bbox("ns_top", (length + 0.2, 0.9, 0.06), (0, 0, 1.08)),
            d.bbox("ns_desk", (length - 0.2, 0.7, 0.05), (0, -0.55, 0.75))]
    band = [d.bbox("ns_band", (length, 0.04, 0.16), (0, 0.41, 0.7))]
    cases, scr = [], []
    for k, x in enumerate((-1.1, 0.0, 1.1)):
        c, s = _monitor(f"ns_m{k}", x, -0.55, 1.15, 0.7, 0.45)
        cases += c
        scr.append(s)
    files = [d.bbox(f"ns_file{k}", (0.08, 0.3, 0.32), (-length / 2 + 0.3 + k * 0.1, 0.1, 1.27)) for k in range(6)]
    chair = [d.bbox("ns_seat", (0.55, 0.55, 0.08), (0.5, -1.25, 0.5)), d.bbox("ns_back", (0.55, 0.06, 0.5), (0.5, -1.5, 0.8))]
    return [(join("ns_body_j", body), steel("base_ns_m", 5, WHITE), "body"),
            (join("ns_band_j", band), paint("base_ns_band_m", TEAL), "band"),
            (join("ns_dark", cases), steel("base_ns_dark_m", 3, PANEL), "dark"),
            (join("ns_files", files), paint("base_ns_files_m", "6a9ac8", "4a78a8"), "files"),
            (join("ns_chair_j", chair), paint("base_ns_chair_m", "6a8aa0", "4a6a80"), "chair"),
            (join("ns_scr", scr), glow("base_ns_glow_m", "7fe0c0"), "glow")]


def base_med_cart():
    """A medicine trolley: drawers in teal and white, a tray of bottles on top,
    a push handle and castors."""
    body = [d.bbox("mcart_body", (1.0, 0.6, 0.9), (0, 0, 0.55)), d.bbox("mcart_top", (1.05, 0.65, 0.05), (0, 0, 1.02))]
    drawers = [d.bbox(f"mcart_d{k}", (0.9, 0.03, 0.18), (0, 0.31, 0.25 + k * 0.22)) for k in range(4)]
    handle = [d.bbox("mcart_h", (0.06, 0.6, 0.06), (0.58, 0, 1.0)), d.bbox("mcart_h2", (0.06, 0.06, 0.3), (0.58, 0.27, 0.85))]
    wheels = [d.cyl(f"mcart_w{k}", 0.06, 0.04, (sx * 0.42, sy * 0.24, 0.06), (math.radians(90), 0, 0), 10) for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    bottles = [d.cyl(f"mcart_b{k}", 0.05, 0.16, (-0.35 + k * 0.12, -0.1, 1.13), vertices=8) for k in range(6)]
    return [(join("mcart_body_j", body + handle), steel("base_mcart_m", 5, WHITE), "body"),
            (join("mcart_dr", drawers), paint("base_mcart_dr_m", TEAL, "2c7a74"), "drawers"),
            (join("mcart_wheels", wheels), paint("base_mcart_w_m", RUBBER), "wheels"),
            (join("mcart_bottles", bottles), paint("base_mcart_b_m", "d8a050", "a87830"), "bottles")]


def base_wheelchair():
    """A folded-back wheelchair: two big wheels, a blue seat and back."""
    wheels = [d.cyl(f"wc_w{s}", 0.32, 0.05, (s * 0.3, 0, 0.32), (0, math.radians(90), 0), 18) for s in (-1, 1)]
    wheels += [d.cyl(f"wc_c{s}", 0.07, 0.04, (s * 0.22, 0.45, 0.07), (0, math.radians(90), 0), 10) for s in (-1, 1)]
    frame = [d.bbox("wc_fr0", (0.04, 0.6, 0.04), (-0.25, 0.15, 0.45)), d.bbox("wc_fr1", (0.04, 0.6, 0.04), (0.25, 0.15, 0.45)),
             d.bbox("wc_push", (0.6, 0.04, 0.04), (0, -0.2, 0.95)), d.bbox("wc_foot", (0.45, 0.2, 0.03), (0, 0.55, 0.12))]
    seat = [d.bbox("wc_seat", (0.48, 0.45, 0.06), (0, 0.15, 0.48)), d.bbox("wc_back", (0.48, 0.05, 0.45), (0, -0.15, 0.75))]
    return [(join("wc_wheels", wheels), paint("base_wc_w_m", RUBBER), "wheels"),
            (join("wc_frame", frame), steel("base_wc_m", 2, "a8b0b4"), "frame"),
            (join("wc_seat_j", seat), paint("base_wc_seat_m", BLUE, "2c5880"), "seat")]


def base_gurney():
    """A wheeled stretcher (担架车): a padded deck on a scissor frame, rails,
    a folded blanket (long axis +X)."""
    deck = [d.bbox("gu_deck", (2.0, 0.65, 0.12), (0, 0, 0.75)), d.bbox("gu_pillow", (0.35, 0.5, 0.1), (-0.8, 0, 0.86))]
    frame = [d.bbox("gu_x0", (1.8, 0.05, 0.05), (0, -0.25, 0.4), (0, math.radians(18), 0)), d.bbox("gu_x1", (1.8, 0.05, 0.05), (0, 0.25, 0.4), (0, math.radians(-18), 0)),
             d.bbox("gu_rail0", (1.4, 0.04, 0.2), (0.1, 0.34, 0.92)), d.bbox("gu_rail1", (1.4, 0.04, 0.2), (0.1, -0.34, 0.92))]
    wheels = [d.cyl(f"gu_w{k}", 0.07, 0.04, (sx * 0.85, sy * 0.25, 0.07), (math.radians(90), 0, 0), 10) for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    blanket = [d.bbox("gu_bl", (0.6, 0.6, 0.1), (0.6, 0, 0.86))]
    return [(join("gu_frame", frame), steel("base_gu_m", 2, "a8b0b4"), "frame"),
            (join("gu_deck_j", deck), paint("base_gu_pad_m", "4a6a80", "34505f"), "pad"),
            (join("gu_bl_j", blanket), paint("base_gu_bl_m", "6a9ac8", "4a78a8"), "blanket"),
            (join("gu_wheels", wheels), paint("base_gu_w_m", RUBBER), "wheels")]


def base_oxygen_rack():
    """Oxygen and gas cylinders chained in a rack against a wall."""
    rack = [d.bbox("ox_back", (1.6, 0.08, 1.4), (0, -0.3, 0.7)), d.bbox("ox_base", (1.6, 0.6, 0.08), (0, 0, 0.04)),
            d.bbox("ox_chain", (1.6, 0.04, 0.04), (0, 0.2, 1.05))]
    tanks = [d.cyl(f"ox_t{k}", 0.13, 1.35, (-0.6 + k * 0.3, 0, 0.75), vertices=14) for k in range(5)]
    caps = [d.cyl(f"ox_c{k}", 0.09, 0.15, (-0.6 + k * 0.3, 0, 1.5), vertices=10) for k in range(5)]
    return [(join("ox_rack", rack), steel("base_ox_m", 3, PANEL), "rack"),
            (join("ox_tanks", tanks), paint("base_ox_t_m", "dfe4e6", "a8b0b4"), "tanks"),
            (join("ox_caps", caps), paint("base_ox_c_m", "3aa068", "2a7a4a"), "caps")]


def base_originium_scanner():
    """源石病检测仪: a ring gantry over a sliding bed, as a CT scanner — the
    Rhodes look, white shell, the ring's bore lit cyan, an amber Originium
    readout on its face; a console beside it (bed along +X)."""
    ring = [d.cyl("os_ring", 1.05, 0.7, (-0.6, 0, 1.15), (0, math.radians(90), 0), 28), d.bbox("os_foot", (0.8, 1.6, 0.4), (-0.6, 0, 0.2))]
    inner = [d.cyl("os_bore", 0.55, 0.74, (-0.6, 0, 1.15), (0, math.radians(90), 0), 24)]
    bed = [d.bbox("os_bed_base", (1.6, 0.5, 0.6), (0.9, 0, 0.3)), d.bbox("os_bed", (2.6, 0.55, 0.1), (0.4, 0, 0.75))]
    pad = [d.bbox("os_pad", (1.8, 0.5, 0.06), (0.7, 0, 0.83))]
    readout = [d.bbox("os_read", (0.05, 0.6, 0.25), (-0.2, 0.0, 1.95))]
    console = [d.bbox("os_con", (0.9, 0.6, 1.0), (1.4, -1.2, 0.5)), d.bbox("os_mon", (0.8, 0.08, 0.5), (1.4, -1.35, 1.35))]
    scr = [d.bbox("os_scr", (0.7, 0.02, 0.4), (1.4, -1.3, 1.35))]
    return [(join("os_shell", ring + bed + console), steel("base_os_m", 6, WHITE), "shell"),
            (join("os_bore_j", inner), glow("base_os_bore_m", "8fe8f0"), "bore_glow"),
            (join("os_pad_j", pad), paint("base_os_pad_m", "4a6a80", "34505f"), "pad"),
            (join("os_read_j", readout), glow("base_os_read_m", "ffb040"), "read_glow"),
            (join("os_scr_j", scr), glow("base_os_scr_m", "7fe0c0"), "glow")]


def base_lab_bench(length=4.0):
    """源石病研究台: a lab bench against the wall — a microscope, a centrifuge,
    racks of sample tubes glowing amber (Originium samples), a shelf of
    reagent bottles above."""
    body = [d.bbox("lb_body", (length, 0.75, 0.9), (0, 0, 0.45)), d.bbox("lb_top", (length + 0.1, 0.8, 0.05), (0, 0, 0.92)),
            d.bbox("lb_shelf", (length, 0.3, 0.04), (0, -0.25, 1.65)), d.bbox("lb_back", (length, 0.05, 1.0), (0, -0.4, 1.45))]
    gear = [d.bbox("lb_mic_base", (0.3, 0.3, 0.06), (-1.3, 0, 0.98)), d.cyl("lb_mic_arm", 0.04, 0.4, (-1.3, -0.1, 1.2), vertices=8),
            d.cyl("lb_mic_tube", 0.05, 0.3, (-1.3, 0.0, 1.35), (math.radians(30), 0, 0), 8),
            d.cyl("lb_centri", 0.22, 0.25, (-0.4, 0, 1.08), vertices=16)]
    racks = [d.bbox(f"lb_rack{k}", (0.4, 0.15, 0.06), (0.5 + k * 0.6, 0.1, 0.98)) for k in range(3)]
    tubes = [d.cyl(f"lb_t{k}_{j}", 0.02, 0.14, (0.35 + k * 0.6 + j * 0.07, 0.1, 1.06), vertices=6) for k in range(3) for j in range(5)]
    bottles = [d.cyl(f"lb_b{k}", 0.05, 0.18, (-1.7 + k * 0.28, -0.25, 1.76), vertices=8) for k in range(12)]
    return [(join("lb_body_j", body + gear + racks), steel("base_lb_m", 5, WHITE), "body"),
            (join("lb_bottles", bottles), paint("base_lb_b_m", "6a9ac8", "4a78a8"), "bottles"),
            (join("lb_tubes", tubes), glow("base_lb_glow_m", "ffa040"), "tube_glow")]


def base_sample_fridge():
    """A tall sample refrigerator, glass-fronted, its shelves of vials lit."""
    body = [d.bbox("sf_body", (0.9, 0.75, 2.1), (0, 0, 1.05))]
    shelves = [d.bbox(f"sf_sh{k}", (0.75, 0.04, 0.06), (0, 0.38, 0.5 + k * 0.4)) for k in range(4)]
    glass = [d.bbox("sf_glass", (0.75, 0.02, 1.7), (0, 0.38, 1.1))]
    return [(join("sf_body_j", body + shelves), steel("base_sf_m", 5, WHITE), "body"),
            (join("sf_glass_j", glass), glow("base_sf_glow_m", "a8e8f0"), "glass_glow")]


def base_crash_cart():
    """急救推车: a red-trimmed crash cart, a defibrillator on top, oxygen bottle
    on its side."""
    body = [d.bbox("cr2_body", (0.9, 0.6, 1.0), (0, 0, 0.6)), d.bbox("cr2_top", (0.95, 0.65, 0.05), (0, 0, 1.12))]
    drawers = [d.bbox(f"cr2_d{k}", (0.8, 0.03, 0.18), (0, 0.31, 0.3 + k * 0.22)) for k in range(4)]
    defib = [d.bbox("cr2_def", (0.5, 0.4, 0.2), (0, -0.05, 1.25))]
    scr = [d.bbox("cr2_scr", (0.3, 0.02, 0.12), (0, 0.16, 1.27))]
    tank = [d.cyl("cr2_tank", 0.08, 0.7, (0.5, 0, 0.6), vertices=10)]
    wheels = [d.cyl(f"cr2_w{k}", 0.06, 0.04, (sx * 0.38, sy * 0.24, 0.06), (math.radians(90), 0, 0), 10) for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    return [(join("cr2_body_j", body + defib), steel("base_cr2_m", 5, WHITE), "body"),
            (join("cr2_dr", drawers), paint("base_cr2_dr_m", RED, "9a3428"), "drawers"),
            (join("cr2_tank_j", tank), paint("base_cr2_t_m", "3aa068", "2a7a4a"), "tank"),
            (join("cr2_wheels", wheels), paint("base_cr2_w_m", RUBBER), "wheels"),
            (join("cr2_scr_j", scr), glow("base_cr2_glow_m", "7fe0a0"), "glow")]


def base_med_kiosk():
    """挂号机: a free-standing check-in terminal, white with a teal frame, a
    tilted touch screen and a card slot."""
    body = [d.bbox("mk_body", (0.6, 0.45, 1.2), (0, 0, 0.6)), d.bbox("mk_head", (0.7, 0.35, 0.6), (0, -0.05, 1.45), (math.radians(-15), 0, 0))]
    frame = [d.bbox("mk_frame", (0.66, 0.04, 0.06), (0, 0.24, 1.2))]
    scr = [d.bbox("mk_scr", (0.55, 0.02, 0.45), (0, 0.11, 1.47), (math.radians(-15), 0, 0))]
    return [(join("mk_body_j", body), steel("base_mk_m", 5, WHITE), "body"),
            (join("mk_frame_j", frame), paint("base_mk_frame_m", TEAL), "frame"),
            (join("mk_scr_j", scr), glow("base_mk_glow_m", "7fe0c0"), "glow")]


def base_med_zone_ward():
    """A 1 m square of the wards' pale blue vinyl, laid over the deck and
    stretched to each ward row (the zones read from above)."""
    return [(join("mz_j", [d.bbox("mz_body", (1.0, 1.0, 0.008), (0, 0, 0.004), width=0.001)]), paint("base_mz_m", "a8c4d8"), "vinyl")]


def base_med_zone_treat():
    """The same in the treatment room's pale teal."""
    return [(join("mzt_j", [d.bbox("mzt_body", (1.0, 1.0, 0.008), (0, 0, 0.004), width=0.001)]), paint("base_mzt_m", "c4e6e0"), "vinyl")]


def base_med_floor_line(length=2.0):
    """A run of the medical bay's floor guide line, set flush; coloured in the
    game's wayfinding (green to the wards, blue to the pharmacy) by model."""
    return [(join("ml_j", [d.bbox("ml_body", (length, 0.2, 0.012), (0, 0, 0.006))]), paint("base_ml_m", "3aa068"), "line")]


def base_med_floor_line_blue(length=2.0):
    return [(join("mlb_j", [d.bbox("mlb_body", (length, 0.2, 0.012), (0, 0, 0.006))]), paint("base_mlb_m", "3a80c0"), "line")]


MED_BUILDERS = [base_wall_panel_med, base_med_bed_side, base_med_curtain, base_med_head_panel, base_nurse_station, base_med_cart,
                base_wheelchair, base_gurney, base_oxygen_rack, base_originium_scanner, base_lab_bench, base_sample_fridge,
                base_crash_cart, base_med_kiosk, base_med_floor_line, base_med_floor_line_blue, base_med_zone_ward, base_med_zone_treat]
ROOM_BUILDERS += MED_BUILDERS


# Hall re-layout (用户 2026-10-18: 重整主基地摆放逻辑) ------------------------------------
# The command dais replaces the ring; the exchange floor takes the north-west,
# the operators' lounge the south-west; the armory becomes 人事部; signs hang
# from the ceiling. Sizes are real; the game shows furniture at PROP_SCALE.

PURPLE_X = "8a6ad0"
WARM = "b08a5a"


def base_command_dais(radius=4.4):
    """调度台 (用户: 中间这个太丑了，重新设计): a low octagonal dais in two steps
    with a lit Rhodes-blue edge, a crescent command desk across its north side
    (screens tilted towards the Doctor at the centre, facing the lift), two
    crew seats, and in the middle a slim emitter column under a small Terra
    hologram — latitude rings round a glowing core. Unscaled (it is the
    hall's centrepiece and its colliders are laid in the game)."""
    oct_pts = 8
    steps = []
    for k, (r, h) in enumerate(((7.6, 0.16), (6.6, 0.32))):
        bpy.ops.mesh.primitive_cylinder_add(vertices=oct_pts, radius=r, depth=h, location=(0, 0, h / 2), rotation=(0, 0, math.pi / 8))
        o = bpy.context.object
        o.name = f"cd_step{k}"
        o.scale = (1.0, 0.72, 1.0)
        bpy.ops.object.transform_apply(scale=True)
        steps.append(o)
    edge = []
    for k in range(oct_pts):
        a0, a1 = (k + 0.5) / oct_pts * math.tau, (k + 1.5) / oct_pts * math.tau
        p0 = (6.65 * math.cos(a0), 6.65 * math.sin(a0) * 0.72)
        p1 = (6.65 * math.cos(a1), 6.65 * math.sin(a1) * 0.72)
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        length = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        edge.append(d.bbox(f"cd_edge{k}", (length, 0.12, 0.05), (mx, my, 0.335), (0, 0, math.atan2(p1[1] - p0[1], p1[0] - p0[0]))))
    # Crescent desk on the north (-Y) side, from -65° to 65° off north.
    desk, trim, screens, seats = [], [], [], []
    for k in range(7):
        a = math.radians(-60 + k * 20)
        x, y = radius * math.sin(a), -radius * math.cos(a)
        rot = (0, 0, a)
        desk.append(d.bbox(f"cd_desk{k}", (1.6, 0.9, 0.85), (x, y, 0.32 + 0.43), rot))
        trim.append(d.bbox(f"cd_trim{k}", (1.62, 0.06, 0.06), (x - 0.47 * math.sin(a), y + 0.47 * math.cos(a), 1.17), rot))
        sx, sy = (radius + 0.25) * math.sin(a), -(radius + 0.25) * math.cos(a)
        screens.append(d.bbox(f"cd_scr{k}", (1.3, 0.05, 0.7), (sx, sy, 1.65), (math.radians(-12), 0, a)))
        desk.append(d.bbox(f"cd_back{k}", (1.4, 0.08, 0.8), (sx - 0.05 * math.sin(a), sy + 0.05 * math.cos(a), 1.6), (math.radians(-12), 0, a)))
    for s in (-1, 1):
        a = math.radians(s * 30)
        x, y = (radius - 1.3) * math.sin(a), -(radius - 1.3) * math.cos(a)
        seats.append(d.bbox(f"cd_seat{s}", (0.6, 0.6, 0.1), (x, y, 0.82), (0, 0, a)))
        seats.append(d.bbox(f"cd_seatb{s}", (0.6, 0.08, 0.6), (x * 1.08, y * 1.08 - 0.0, 1.1), (0, 0, a)))
        seats.append(d.cyl(f"cd_post{s}", 0.05, 0.45, (x, y, 0.55), vertices=8))
    # The emitter and its hologram.
    emitter = [d.cyl("cd_em_base", 0.8, 0.12, (0, 0, 0.38), vertices=20), d.cyl("cd_em_col", 0.18, 0.9, (0, 0, 0.85), vertices=12)]
    holo = [d.cyl("cd_core", 0.32, 0.4, (0, 0, 1.75), vertices=16)]
    for k, (r, z) in enumerate(((0.62, 1.75), (0.55, 1.45), (0.55, 2.05), (0.4, 1.25), (0.4, 2.25))):
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.025, location=(0, 0, z), major_segments=28, minor_segments=6)
        t = bpy.context.object
        t.name = f"cd_lat{k}"
        holo.append(t)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.64, minor_radius=0.025, location=(0, 0, 1.75), rotation=(math.radians(90), 0, 0), major_segments=28, minor_segments=6)
    meridian = bpy.context.object
    meridian.name = "cd_mer"
    holo.append(meridian)
    ring = []
    bpy.ops.mesh.primitive_torus_add(major_radius=1.15, minor_radius=0.04, location=(0, 0, 0.35), major_segments=32, minor_segments=6)
    ring_obj = bpy.context.object
    ring_obj.name = "cd_floor_ring"
    ring.append(ring_obj)
    logo = kit.box("cd_logo", (1.6, 1.6, 0.02), (0, 2.6, 0.33))
    return [(join("cd_steps", steps), steel("base_cd_step_m", 4, "5c656b"), "steps"),
            (join("cd_desk_j", desk + emitter + seats), steel("base_cd_desk_m", 5, "dfe4e6"), "desk"),
            (join("cd_trim_j", trim), paint("base_cd_trim_m", BLUE, "2c5880"), "trim"),
            (logo, logo_decal("base_cd_logo_m", "5c656b"), "logo"),
            (join("cd_edge_j", edge + ring), glow("base_cd_edge_m", "4f9fe0"), "edge_glow"),
            (join("cd_scr_j", screens), glow("base_cd_scr_m"), "screen_glow"),
            (join("cd_holo", holo), glow("base_cd_holo_m", "8fe8f0"), "holo_glow")]


def base_market_wall(width=24.0):
    """交易所行情墙: big screens along the wall — price charts, a market map,
    a ticker strip running under them; a frame and two lit pillars."""
    frame = [d.bbox("mw_frame", (width, 0.4, 3.6), (0, 0.2, 2.9)), d.bbox("mw_base", (width, 0.6, 0.9), (0, 0.3, 0.45))]
    frame += [d.bbox(f"mw_p{s}", (0.6, 0.7, 4.8), (s * (width / 2 + 0.3), 0.35, 2.4)) for s in (-1, 1)]
    screens = [d.bbox(f"mw_s{k}", (width / 3 - 0.4, 0.05, 2.6), (-width / 3 + k * width / 3, 0.43, 3.0)) for k in range(3)]
    ticker = [d.bbox("mw_tick", (width - 0.4, 0.05, 0.3), (0, 0.43, 1.35))]
    lamps = [d.bbox(f"mw_l{s}", (0.08, 0.05, 4.2), (s * (width / 2 + 0.3), 0.72, 2.4)) for s in (-1, 1)]
    return [(join("mw_frame_j", frame), steel("base_mw_m", 3, HULL), "frame"),
            (join("mw_scr", screens), glow("base_mw_scr_m"), "screen_glow"),
            (join("mw_tick_j", ticker + lamps), glow("base_mw_tick_m", "c8a0ff"), "tick_glow")]


def base_exchange_counter():
    """交易所终端: a curved trading counter, three terminals on it, and a
    hologram of a rising chart over it (bars and a line)."""
    body, screens = [], []
    for k in range(5):
        a = math.radians(-50 + k * 25)
        x, y = 2.0 * math.sin(a), -2.0 * math.cos(a) + 1.6
        body.append(d.bbox(f"ec_seg{k}", (1.0, 0.8, 1.0), (x, y, 0.5), (0, 0, a)))
    for k, a in enumerate((-30, 0, 30)):
        r = math.radians(a)
        screens.append(d.bbox(f"ec_scr{k}", (0.8, 0.05, 0.5), (1.85 * math.sin(r), -1.85 * math.cos(r) + 1.6, 1.35), (math.radians(-15), 0, r)))
    # The quote ring over it is a hologram drawn by the game (MarketBoard);
    # the mast in the middle carries its emitter.
    pole = [d.cyl("ec_pole", 0.07, 1.4, (0, 1.0, 1.7), vertices=8), d.cyl("ec_emit", 0.25, 0.12, (0, 1.0, 2.45), vertices=16)]
    emit = [d.cyl("ec_emit_glow", 0.2, 0.03, (0, 1.0, 2.52), vertices=16)]
    trim = [d.bbox(f"ec_t{k}", (1.0, 0.06, 0.08), (2.0 * math.sin(math.radians(-50 + k * 25)), -2.0 * math.cos(math.radians(-50 + k * 25)) + 1.6 - 0.0, 1.02),
                   (0, 0, math.radians(-50 + k * 25))) for k in range(5)]
    return [(join("ec_body", body + pole), steel("base_ec_m", 5, PANEL), "body"),
            (join("ec_trim_j", trim), paint("base_ec_trim_m", PURPLE_X, "5a4a90"), "trim"),
            (join("ec_scr_j", screens), glow("base_ec_scr_m"), "screen_glow"),
            (join("ec_emit_j", emit), glow("base_ec_holo_m", "8fe8f0"), "holo_glow")]


def base_trader_desk(width=3.2):
    """交易员工位 (用户 2026-10-18: 建模也换，参考真实交易所): a trading-floor
    workstation — a dark desk with a raised rail carrying a 2 x 3 array of
    monitors angled towards the trader, two keyboards, a turret phone, a
    chair (south, at the front)."""
    body = [d.bbox("td_top", (width, 1.1, 0.06), (0, 0, 0.78)), d.bbox("td_ped0", (0.5, 0.9, 0.75), (-width / 2 + 0.3, -0.05, 0.38)),
            d.bbox("td_ped1", (0.5, 0.9, 0.75), (width / 2 - 0.3, -0.05, 0.38)), d.bbox("td_rail", (width - 0.2, 0.15, 0.08), (0, -0.4, 1.0)),
            d.bbox("td_mast", (0.12, 0.12, 1.4), (0, -0.45, 1.5))]
    cases, scr = [], []
    for row, z in enumerate((1.25, 1.85)):
        for k, x in enumerate((-0.98, 0.0, 0.98)):
            yaw = (-0.25, 0.0, 0.25)[k]
            cases.append(d.bbox(f"td_mon{row}{k}", (0.92, 0.07, 0.56), (x, -0.36 + abs(x) * 0.12, z), (math.radians(-6 if row == 0 else -14), 0, yaw)))
            scr.append(d.bbox(f"td_scr{row}{k}", (0.84, 0.02, 0.48), (x, -0.31 + abs(x) * 0.12, z), (math.radians(-6 if row == 0 else -14), 0, yaw)))
    kit_ = [d.bbox("td_kb0", (0.55, 0.18, 0.03), (-0.5, 0.25, 0.82)), d.bbox("td_kb1", (0.55, 0.18, 0.03), (0.4, 0.25, 0.82)),
            d.bbox("td_phone", (0.35, 0.28, 0.1), (1.2, 0.15, 0.86), (math.radians(-10), 0, 0))]
    chair = [d.bbox("td_seat", (0.6, 0.6, 0.1), (0, 0.95, 0.5)), d.bbox("td_back", (0.6, 0.08, 0.7), (0, 1.25, 0.9)), d.cyl("td_post", 0.04, 0.45, (0, 0.95, 0.24), vertices=8)]
    edge = [d.bbox("td_edge", (width, 0.04, 0.05), (0, 0.55, 0.78))]
    return [(join("td_body", body + cases), steel("base_td_m", 3, "3a4046"), "body"),
            (join("td_dark", kit_ + chair), paint("base_td_chair_m", RUBBER), "dark"),
            (join("td_edge_j", edge), glow("base_td_edge_m", "c8a0ff"), "edge_glow"),
            (join("td_scr_j", scr), glow("base_td_scr_m"), "screen_glow")]


def base_trading_post(radius=2.2):
    """交易柱 after the NYSE floor's trading posts: a horseshoe counter open to
    the south, a central column rising through a ring of eight overhead
    monitors facing outwards, specialists' screens along the counter. The
    quote ring hologram turns above it (MarketBoard)."""
    counter, trim, scr = [], [], []
    for k in range(9):
        a = math.radians(-120 + k * 30)
        x, y = radius * math.sin(a), -radius * math.cos(a)
        counter.append(d.bbox(f"tp_seg{k}", (1.25, 0.7, 1.05), (x, y, 0.53), (0, 0, a)))
        trim.append(d.bbox(f"tp_trim{k}", (1.25, 0.06, 0.08), ((radius + 0.36) * math.sin(a), -(radius + 0.36) * math.cos(a), 1.02), (0, 0, a)))
        scr.append(d.bbox(f"tp_cscr{k}", (0.7, 0.03, 0.4), ((radius - 0.15) * math.sin(a), -(radius - 0.15) * math.cos(a), 1.3), (math.radians(20), 0, a)))
    column = [d.cyl("tp_col", 0.35, 3.4, (0, 0, 1.7), vertices=16), d.cyl("tp_cap", 0.55, 0.2, (0, 0, 3.05), vertices=12)]
    mons = []
    for k in range(8):
        a = k * math.tau / 8
        x, y = 1.25 * math.sin(a), -1.25 * math.cos(a)
        mons.append(d.bbox(f"tp_mon{k}", (0.95, 0.08, 0.6), (x, y, 2.55), (math.radians(-10), 0, a)))
        scr.append(d.bbox(f"tp_mscr{k}", (0.87, 0.02, 0.52), (1.3 * math.sin(a), -1.3 * math.cos(a), 2.55), (math.radians(-10), 0, a)))
    emit = [d.cyl("tp_emit", 0.3, 0.05, (0, 0, 3.2), vertices=16)]
    return [(join("tp_body", counter + column + mons), steel("base_tp_m", 4, "3a4046"), "body"),
            (join("tp_trim_j", trim + emit), glow("base_tp_trim_m", "c8a0ff"), "trim_glow"),
            (join("tp_scr_j", scr), glow("base_tp_scr_m"), "screen_glow")]


def base_holo_screen_frame(width=24.0):
    """交易所全息巨幕的设备 (用户 2026-10-18: 改为全息超大屏): two slim emitter
    pylons at the screen's ends, lit strips up their faces and projector
    heads angled in, joined by a floor emitter rail with a glowing slot; the
    screen itself is a hologram drawn by the game (MarketBoard)."""
    pylons, heads, strips = [], [], []
    for s in (-1, 1):
        x = s * (width / 2 + 0.5)
        pylons += [d.bbox(f"hs2_py{s}", (0.7, 0.8, 6.2), (x, 0, 3.1)), d.bbox(f"hs2_foot{s}", (1.1, 1.2, 0.3), (x, 0, 0.15))]
        heads.append(d.bbox(f"hs2_head{s}", (0.8, 0.9, 0.6), (x - s * 0.3, 0.25, 6.3), (0, s * math.radians(20), 0)))
        strips.append(d.bbox(f"hs2_strip{s}", (0.08, 0.05, 5.4), (x - s * 0.2, 0.41, 3.2)))
        strips.append(d.bbox(f"hs2_lens{s}", (0.4, 0.05, 0.3), (x - s * 0.45, 0.72, 6.3)))
    rail = [d.bbox("hs2_rail", (width, 0.9, 0.25), (0, 0, 0.125)), d.bbox("hs2_lip", (width, 0.12, 0.3), (0, -0.4, 0.15))]
    slot = [d.bbox("hs2_slot", (width - 0.4, 0.2, 0.03), (0, 0.1, 0.26))]
    vents = [d.bbox(f"hs2_v{k}", (0.6, 0.05, 0.1), (-width / 2 + 1.0 + k * 2.0, 0.46, 0.13)) for k in range(12)]
    return [(join("hs2_body", pylons + heads + rail + vents), steel("base_hs2_m", 3, HULL), "body"),
            (join("hs2_glow", strips + slot), glow("base_hs2_glow_m", "8fe8f0"), "emit_glow")]


def base_sofa(length=2.4):
    """A lounge sofa: low, deep, two cushions and arms."""
    body = [d.bbox("sf2_base", (length, 0.9, 0.42), (0, 0, 0.21)), d.bbox("sf2_back", (length, 0.25, 0.5), (0, -0.33, 0.67))]
    body += [d.bbox(f"sf2_arm{s}", (0.22, 0.9, 0.62), (s * (length / 2 - 0.11), 0, 0.31)) for s in (-1, 1)]
    cushions = [d.bbox(f"sf2_c{k}", (length / 2 - 0.25, 0.62, 0.14), (-length / 4 + 0.0 + k * length / 2, 0.08, 0.49)) for k in range(2)]
    return [(join("sf2_body", body), paint("base_sf2_seat_m", "4a6a80", "34505f"), "body"),
            (join("sf2_cush", cushions), paint("base_sf2_chair_m", "6a8aa0", "4a6a80"), "cushion")]


def base_coffee_table():
    """A low coffee table: steel legs, a glass top seen as a lit frame,
    magazines and two mugs."""
    top = [d.bbox("ctb_top", (1.4, 0.8, 0.05), (0, 0, 0.42)), d.bbox("ctb_shelf", (1.3, 0.7, 0.03), (0, 0, 0.15))]
    legs = [d.bbox(f"ctb_l{k}", (0.05, 0.05, 0.42), (sx * 0.65, sy * 0.35, 0.21)) for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    things = [d.bbox("ctb_mag", (0.35, 0.25, 0.02), (-0.3, 0.1, 0.46)), d.cyl("ctb_mug0", 0.05, 0.1, (0.3, -0.1, 0.5), vertices=10),
              d.cyl("ctb_mug1", 0.05, 0.1, (0.45, 0.12, 0.5), vertices=10)]
    return [(join("ctb_j", top + legs), steel("base_ctb_m", 3, PANEL), "table"),
            (join("ctb_things", things), paint("base_ctb_things_m", ORANGE, "a24e1e"), "things")]


def base_vending_machine():
    """A drinks machine: a lit front of cans in rows, a dispenser slot."""
    body = [d.bbox("vm_body", (1.0, 0.8, 2.0), (0, 0, 1.0))]
    front = [d.bbox("vm_front", (0.7, 0.03, 1.3), (-0.08, 0.41, 1.25))]
    cans = [d.cyl(f"vm_can{r}_{c}", 0.05, 0.14, (-0.32 + c * 0.13, 0.43, 0.75 + r * 0.25), (math.radians(90), 0, 0), 8) for r in range(5) for c in range(5)]
    slot = [d.bbox("vm_slot", (0.5, 0.05, 0.18), (-0.08, 0.41, 0.3))]
    return [(join("vm_body_j", body + slot), steel("base_vm_m", 4, BLUE), "body"),
            (join("vm_front_j", front), glow("base_vm_glow_m", "dff4ff"), "front_glow"),
            (join("vm_cans", cans), paint("base_vm_cans_m", ORANGE, "a24e1e"), "cans")]


def base_bar_counter(length=4.0):
    """The lounge's bar: a counter with a warm top, stools in front (south),
    a back shelf of bottles and a coffee machine."""
    body = [d.bbox("bc_body", (length, 0.7, 1.05), (0, 0, 0.53)), d.bbox("bc_top", (length + 0.2, 0.85, 0.06), (0, 0.05, 1.08))]
    shelf = [d.bbox("bc_shelf", (length, 0.35, 1.8), (0, -1.1, 0.9)), d.bbox("bc_shelf2", (length, 0.38, 0.04), (0, -1.05, 1.5))]
    bottles = [d.cyl(f"bc_b{k}", 0.05, 0.25, (-length / 2 + 0.25 + k * 0.3, -1.0, 1.65), vertices=8) for k in range(int(length / 0.3))]
    stools = []
    for k in range(4):
        x = -length / 2 + 0.6 + k * (length - 1.2) / 3
        stools += [d.cyl(f"bc_st{k}", 0.2, 0.06, (x, 0.75, 0.75), vertices=12), d.cyl(f"bc_sp{k}", 0.04, 0.72, (x, 0.75, 0.36), vertices=8)]
    machine = [d.bbox("bc_cm", (0.45, 0.4, 0.45), (length / 2 - 0.4, -0.1, 1.33))]
    return [(join("bc_body_j", body), paint("base_bc_m", WARM, "8a6a40"), "body"),
            (join("bc_steel", shelf + stools + machine), steel("base_bc_steel_m", 3, HULL), "steel"),
            (join("bc_bottles", bottles), glow("base_bc_glow_m", "ffc070"), "bottle_glow")]


def base_bookshelf(width=2.4):
    """A bookshelf against a wall: four boards of books in Rhodes colours."""
    frame = [d.bbox("bk_back", (width, 0.08, 2.2), (0, -0.2, 1.1))]
    frame += [d.bbox(f"bk_side{s}", (0.06, 0.45, 2.2), (s * (width / 2 - 0.03), 0, 1.1)) for s in (-1, 1)]
    frame += [d.bbox(f"bk_b{k}", (width, 0.45, 0.04), (0, 0, 0.1 + k * 0.52)) for k in range(5)]
    books = {"b": [], "w": [], "o": []}
    keys = ["b", "w", "o", "w", "b"]
    for k in range(4):
        x = -width / 2 + 0.1
        i = 0
        while x < width / 2 - 0.15:
            w = 0.06 + ((i * 3 + k) % 3) * 0.02
            books[keys[(i + k) % 5]].append(d.bbox(f"bk_{k}_{i}", (w, 0.3, 0.32 + ((i + k) % 2) * 0.06), (x + w / 2, 0.02, 0.29 + k * 0.52)))
            x += w + 0.01
            i += 1
    return [(join("bk_frame", frame), paint("base_bk_m", WARM, "8a6a40"), "frame"),
            (join("bk_blue", books["b"]), paint("base_bk_b_m", BLUE, "2c5880"), "blue"),
            (join("bk_white", books["w"]), paint("base_bk_w_m", WHITE, "a8b0b4"), "white"),
            (join("bk_orange", books["o"]), paint("base_bk_o_m", ORANGE, "a24e1e"), "orange")]


def base_lounge_rug():
    """A 1 m square of the lounge's warm floor, stretched over its corner."""
    return [(join("lr_j", [d.bbox("lr_body", (1.0, 1.0, 0.008), (0, 0, 0.004), width=0.001)]), paint("base_lr_m", "a08060"), "rug")]


def base_personnel_desk(width=5.0):
    """人事部前台: a long counter in Rhodes blue and white, three terminals, a
    tray of operator files, the logo on its front."""
    body = [d.bbox("pd_body", (width, 1.0, 1.05), (0, 0, 0.53)), d.bbox("pd_top", (width + 0.2, 1.15, 0.06), (0, 0, 1.08))]
    band = [d.bbox("pd_band", (width, 0.04, 0.22), (0, 0.51, 0.7))]
    cases, scr = [], []
    for k, x in enumerate((-1.6, 0.0, 1.6)):
        c, s = _monitor(f"pd_m{k}", x, -0.25, 1.55, 0.9, 0.55)
        cases += c
        scr.append(s)
    files = [d.bbox(f"pd_f{k}", (0.3, 0.22, 0.03), (0.9 + (k % 3) * 0.08, 0.2, 1.12 + k * 0.03)) for k in range(5)]
    logo = kit.box("pd_logo", (0.6, 0.02, 0.6), (-2.0, 0.52, 0.62))
    return [(join("pd_body_j", body), steel("base_pd_m", 5, WHITE), "body"),
            (join("pd_band_j", band), paint("base_pd_band_m", BLUE, "2c5880"), "band"),
            (join("pd_dark", cases), steel("base_pd_dark_m", 3, PANEL), "dark"),
            (join("pd_files", files), paint("base_pd_files_m", SAFETY, "a87e18"), "files"),
            (logo, logo_decal("base_pd_logo_m", WHITE), "logo"),
            (join("pd_scr", scr), glow("base_pd_glow_m"), "screen_glow")]


def base_roster_holo():
    """干员档案全息台: a round pedestal projecting a fan of operator file
    cards (blank, lit) in two rows over it."""
    base = [d.cyl("rh3_base", 1.1, 0.5, (0, 0, 0.25), vertices=24), d.cyl("rh3_top", 0.9, 0.06, (0, 0, 0.53), vertices=24)]
    cards = []
    for row, z in enumerate((1.3, 2.0)):
        for k in range(5):
            a = math.radians(-40 + k * 20)
            cards.append(d.bbox(f"rh3_c{row}{k}", (0.42, 0.03, 0.56), (1.0 * math.sin(a), -1.0 * math.cos(a) * 0.4, z), (0, 0, a)))
    ring = []
    bpy.ops.mesh.primitive_torus_add(major_radius=0.85, minor_radius=0.03, location=(0, 0, 0.58), major_segments=32, minor_segments=6)
    ring.append(bpy.context.object)
    return [(join("rh3_base_j", base), steel("base_rh3_m", 5, WHITE), "base"),
            (join("rh3_cards", cards + ring), glow("base_rh3_glow_m", "8fd0f8"), "card_glow")]


def base_file_cabinets(width=4.0):
    """A row of operator file cabinets against a wall, drawer pulls, a
    coloured tab on each."""
    body = [d.bbox("fc_body", (width, 0.6, 1.6), (0, 0, 0.8))]
    drawers = [d.bbox(f"fc_d{c}_{r}", (width / 5 - 0.08, 0.03, 0.34), (-width / 2 + width / 10 + c * width / 5, 0.31, 0.25 + r * 0.38)) for c in range(5) for r in range(4)]
    tabs = [d.bbox(f"fc_t{c}_{r}", (0.12, 0.03, 0.05), (-width / 2 + width / 10 + c * width / 5, 0.33, 0.36 + r * 0.38)) for c in range(5) for r in range(4)]
    return [(join("fc_body_j", body + drawers), steel("base_fc_m", 4, PANEL), "body"),
            (join("fc_tabs", tabs), paint("base_fc_tab_m", SAFETY, "a87e18"), "tabs")]


def base_interview_table():
    """A round meeting table with four chairs, a tablet on it."""
    table = [d.cyl("it_top", 0.8, 0.05, (0, 0, 0.75), vertices=24), d.cyl("it_post", 0.08, 0.72, (0, 0, 0.36), vertices=10),
             d.cyl("it_foot", 0.4, 0.04, (0, 0, 0.02), vertices=16)]
    chairs = []
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        x, y = 1.15 * math.cos(a), 1.15 * math.sin(a)
        chairs += [d.bbox(f"it_s{k}", (0.5, 0.5, 0.08), (x, y, 0.46), (0, 0, a)), d.bbox(f"it_b{k}", (0.5, 0.06, 0.5), (1.38 * math.cos(a), 1.38 * math.sin(a), 0.75), (0, 0, a + math.pi / 2))]
    tablet = [d.bbox("it_tab", (0.3, 0.2, 0.02), (0.1, 0, 0.79))]
    return [(join("it_table", table), steel("base_it_m", 5, WHITE), "table"),
            (join("it_chairs", chairs), paint("base_it_chair_m", "4a6a80", "34505f"), "chair"),
            (join("it_tab_j", tablet), glow("base_it_glow_m"), "glow")]


def base_weapon_rack_stand():
    """A free-standing weapon rack by the 整备台: an A-frame with rifles and
    blades racked on both faces."""
    frame = [d.bbox("ws2_base", (2.4, 0.8, 0.1), (0, 0, 0.05)), d.bbox("ws2_top", (2.4, 0.1, 0.1), (0, 0, 1.9))]
    frame += [d.bbox(f"ws2_leg{s}{t}", (0.08, 0.08, 1.95), (s * 1.15, t * 0.3, 0.97), (t * 0.16, 0, 0)) for s in (-1, 1) for t in (-1, 1)]
    arms = []
    for k in range(6):
        x = -0.95 + k * 0.38
        for t in (-1, 1):
            if k % 3 == 2:
                arms.append(d.bbox(f"ws2_bl{k}{t}", (0.1, 0.05, 1.5), (x, t * 0.18, 1.0), (t * 0.16, 0, 0)))
            else:
                arms.append(d.bbox(f"ws2_g{k}{t}", (0.14, 0.08, 1.4), (x, t * 0.18, 0.95), (t * 0.16, 0, 0)))
    return [(join("ws2_frame", frame), steel("base_ws2_m", 3, HULL), "frame"),
            (join("ws2_arms", arms), steel("base_ws2_arm_m", 2, "5c646a"), "arms")]


# Hanging signs: a plate hung from the ceiling on two rods, a coloured band
# and a pictogram — no lettering (场景里不挂文字). Origin at the plate's bottom.
SIGNS = {
    "warehouse": ("d8a520", "box"), "medical": ("8fc31f", "plus"), "store": ("d0662a", "bag"),
    "personnel": ("3a8fd0", "person"), "exchange": ("c48cff", "chart"), "lounge": ("3fa8a0", "cup"),
    "loadout": ("0098dc", "blades"), "logistics": ("e0b030", "arrow"), "workshop": ("e0782a", "gear"),
    "research": ("e0782a", "flask"),
}


def _pictogram(kind, prefix):
    """The sign's mark, built of boxes on the plate's face (+Y), centred at
    x 0.35, z 0.35, about 0.5 m."""
    cx, cz, y = 0.35, 0.36, 0.07
    b = lambda n, sx, sz, x, z, r=0.0: d.bbox(f"{prefix}_{n}", (sx, 0.03, sz), (cx + x, y, cz + z), (0, r, 0))
    if kind == "box":
        return [b("a", 0.44, 0.06, 0, 0.2), b("b", 0.44, 0.06, 0, -0.2), b("c", 0.06, 0.44, -0.2, 0), b("d", 0.06, 0.44, 0.2, 0), b("e", 0.44, 0.06, 0, 0)]
    if kind == "plus":
        return [b("a", 0.46, 0.14, 0, 0), b("b", 0.14, 0.46, 0, 0)]
    if kind == "bag":
        return [b("a", 0.4, 0.3, 0, -0.06), b("b", 0.05, 0.16, -0.1, 0.16), b("c", 0.05, 0.16, 0.1, 0.16), b("d", 0.25, 0.05, 0, 0.23)]
    if kind == "person":
        return [b("a", 0.18, 0.18, 0, 0.15), b("b", 0.36, 0.22, 0, -0.14)]
    if kind == "chart":
        return [b("a", 0.08, 0.14, -0.15, -0.15), b("b", 0.08, 0.26, 0, -0.09), b("c", 0.08, 0.4, 0.15, -0.02), b("d", 0.42, 0.05, 0, 0.12, -0.5)]
    if kind == "cup":
        return [b("a", 0.3, 0.3, -0.03, -0.08), b("b", 0.08, 0.14, 0.17, -0.06), b("c", 0.04, 0.12, -0.08, 0.17), b("d", 0.04, 0.12, 0.02, 0.17)]
    if kind == "gear":
        teeth = [b(f"t{k}", 0.1, 0.12, 0.2 * math.cos(k * math.pi / 4), 0.2 * math.sin(k * math.pi / 4), -k * math.pi / 4) for k in range(8)]
        return teeth + [b("hub", 0.3, 0.3, 0, 0), b("hole", 0.08, 0.08, 0, 0)][:1]
    if kind == "flask":
        return [b("neck", 0.1, 0.18, 0, 0.17), b("lip", 0.18, 0.04, 0, 0.27), b("body", 0.36, 0.2, 0, -0.08),
                b("sl", 0.08, 0.16, -0.12, 0.04, 0.5), b("sr", 0.08, 0.16, 0.12, 0.04, -0.5), b("base", 0.44, 0.05, 0, -0.2)]
    if kind == "blades":
        return [b("a", 0.06, 0.5, 0, 0, 0.6), b("b", 0.06, 0.5, 0, 0, -0.6), b("c", 0.24, 0.05, 0, -0.14)]
    return [b("a", 0.34, 0.06, -0.04, 0), b("b", 0.22, 0.06, 0.1, 0.06, -0.75), b("c", 0.22, 0.06, 0.1, -0.06, 0.75)]


def _hanging_sign(key):
    colour, kind = SIGNS[key]
    p = f"hsg_{key}"
    plate = [d.bbox(f"{p}_plate", (1.7, 0.12, 0.72), (0, 0, 0.36))]
    rods = [d.cyl(f"{p}_rod{s}", 0.025, 1.4, (s * 0.65, 0, 1.42), vertices=6) for s in (-1, 1)]
    band = [d.bbox(f"{p}_band", (0.9, 0.03, 0.72), (-0.4, 0.07, 0.36))]
    mark = _pictogram(kind, p)
    return [(join(f"{p}_plate_j", plate + rods), steel(f"base_{p}_m", 3, "2a2f33"), "plate"),
            (join(f"{p}_band_j", band), paint(f"base_{p}_band_m", colour), "band"),
            (join(f"{p}_mark", mark), glow(f"base_{p}_mark_m", "f4fbff"), "mark_glow")]


def base_hanging_directory():
    """The hall's directory, hung from the ceiling over the floor logo: a wide
    dark board, one coloured band and pictogram per station (no lettering)."""
    keys = list(SIGNS)
    board = [d.bbox("hd_board", (len(keys) * 0.9 + 0.4, 0.14, 1.1), (0, 0, 0.55))]
    rods = [d.cyl(f"hd_rod{s}", 0.03, 1.4, (s * 3.2, 0, 1.8), vertices=6) for s in (-1, 1)]
    parts = [(join("hd_board_j", board + rods), steel("base_hd_m", 3, "2a2f33"), "board")]
    for i, key in enumerate(keys):
        colour, kind = SIGNS[key]
        x = -len(keys) * 0.45 + 0.45 + i * 0.9
        band = [d.bbox(f"hd_band{i}", (0.8, 0.03, 0.18), (x, 0.08, 0.2))]
        mark = _pictogram(kind, f"hd_{key}")
        for o in mark:
            o.location.x += x - 0.35
            o.location.z += 0.25
            o.scale = (0.75, 1, 0.75)
        parts.append((join(f"hd_band_j{i}", band), paint(f"base_hd_band{i}_m", colour), f"band{i}"))
        parts.append((join(f"hd_mark_j{i}", mark), glow(f"base_hd_mark{i}_m", "f4fbff"), f"mark{i}_glow"))
    return parts


def base_hanging_sign_warehouse(): return _hanging_sign("warehouse")
def base_hanging_sign_medical(): return _hanging_sign("medical")
def base_hanging_sign_store(): return _hanging_sign("store")
def base_hanging_sign_personnel(): return _hanging_sign("personnel")
def base_hanging_sign_exchange(): return _hanging_sign("exchange")
def base_hanging_sign_lounge(): return _hanging_sign("lounge")
def base_hanging_sign_loadout(): return _hanging_sign("loadout")
def base_hanging_sign_logistics(): return _hanging_sign("logistics")
def base_hanging_sign_workshop(): return _hanging_sign("workshop")
def base_hanging_sign_research(): return _hanging_sign("research")


def _torus(name, major, minor, z, segments=48, rings=8, x=0.0, y=0.0, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=(x, y, z), rotation=rotation,
                                     major_segments=segments, minor_segments=rings)
    obj = bpy.context.object
    obj.name = name
    return obj


def _cone(name, r1, r2, depth, location, vertices=24, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=location, vertices=vertices, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return obj


def _bolts(prefix, points, radius=0.025, depth=0.02, axis="y"):
    """Little hex bolt heads at `points`, facing +Y (or up)."""
    rot = (math.radians(90), 0, 0) if axis == "y" else (0, 0, 0)
    return [d.cyl(f"{prefix}{k}", radius, depth, p, rot, 6) for k, p in enumerate(points)]


def _pipe(name, a, b, radius, vertices=12):
    """A straight pipe from `a` to `b`."""
    va, vb = mathutils.Vector(a), mathutils.Vector(b)
    mid, axis = (va + vb) / 2, vb - va
    obj = d.cyl(name, radius, axis.length, tuple(mid), (0, 0, 0), vertices)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = axis.to_track_quat("Z", "Y")
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


# --- 科研部 (龙门币平衡与科研部策划案_v1_1 §5.3; 用户 2026-10-20: 面数更多，搭配材质、纹理和渲染) --

def base_originium_chamber():
    """源石隔离舱: a stepped plinth ringed by a hazard band, a grated floor and
    an emitter under a cluster of originium held in three containment rings
    between six clamped posts; an open crown of beams and a central emitter,
    cable runs down the posts, a control lectern at the front, coolant pipes
    behind."""
    body, hz, grate, dark, glow_o, glow_c, scr = [], [], [], [], [], [], []
    body += [d.cyl("lc_base0", 1.62, 0.12, (0, 0, 0.06), vertices=64), d.cyl("lc_base1", 1.52, 0.22, (0, 0, 0.23), vertices=64),
             d.cyl("lc_base2", 1.42, 0.06, (0, 0, 0.37), vertices=64)]
    hz.append(d.cyl("lc_band", 1.535, 0.08, (0, 0, 0.2), vertices=64))
    body += _bolts("lc_bb", [(1.53 * math.cos(k * math.pi / 12), 1.53 * math.sin(k * math.pi / 12), 0.3) for k in range(24)], 0.03, 0.03, "z")
    grate.append(d.cyl("lc_grate", 1.32, 0.03, (0, 0, 0.41), vertices=64))
    body += [d.cyl("lc_emit_base", 0.55, 0.22, (0, 0, 0.52), vertices=32), d.cyl("lc_emit_neck", 0.38, 0.18, (0, 0, 0.7), vertices=32)]
    glow_c.append(_torus("lc_emit_ring", 0.47, 0.03, 0.62, 40, 6))
    for k in range(8):
        a = k * math.pi / 4
        body.append(d.bbox(f"lc_fin{k}", (0.05, 0.28, 0.2), (0.45 * math.cos(a), 0.45 * math.sin(a), 0.55), (0, 0, a + math.pi / 2)))
    for k in range(6):
        a = k * math.pi / 3 + math.pi / 6
        x, y = 1.4 * math.cos(a), 1.4 * math.sin(a)
        body.append(d.bbox(f"lc_post{k}", (0.13, 0.13, 2.7), (x, y, 1.75), (0, 0, a), 0.02))
        for j, z in enumerate((0.55, 1.7, 2.85)):
            body.append(d.bbox(f"lc_clamp{k}{j}", (0.22, 0.22, 0.12), (x, y, z), (0, 0, a), 0.02))
            glow_o.append(d.bbox(f"lc_node{k}{j}", (0.06, 0.02, 0.05), (x * 0.92, y * 0.92, z + 0.1), (0, 0, a + math.pi / 2)))
        dark.append(_pipe(f"lc_cable{k}", (x * 1.06, y * 1.06, 3.0), (x * 1.06, y * 1.06, 0.45), 0.03, 8))
    for j, z in enumerate((0.55, 1.7, 2.85)):
        glow_c.append(_torus(f"lc_ring{j}", 1.36, 0.035, z, 64, 6))
    body.append(_torus("lc_crown", 1.4, 0.13, 3.08, 64, 10))
    for k in range(4):
        a = k * math.pi / 4
        body.append(d.bbox(f"lc_beam{k}", (2.7, 0.1, 0.12), (0, 0, 3.12), (0, 0, a), 0.02))
    body += [d.cyl("lc_top_emit", 0.32, 0.22, (0, 0, 3.08), vertices=32), d.cyl("lc_top_lens", 0.22, 0.1, (0, 0, 2.94), vertices=32)]
    glow_c.append(d.cyl("lc_top_glow", 0.18, 0.04, (0, 0, 2.88), vertices=24))
    # The cluster: a dark core and lit shards, hexagonal like originium.
    crystals = [(0, 0, 1.55, 1.5, 0.0, 0.0), (0.38, 0.12, 1.3, 1.0, 0.45, 0.2), (-0.34, -0.16, 1.35, 1.1, -0.4, -0.25),
                (0.08, 0.42, 1.25, 0.8, 0.3, -0.5), (-0.14, -0.42, 1.28, 0.85, -0.25, 0.5), (0.3, -0.3, 1.45, 0.6, 0.6, 0.6),
                (-0.32, 0.3, 1.45, 0.65, -0.55, -0.6), (0.0, 0.0, 2.25, 0.5, 0.15, 0.3), (0.15, -0.1, 0.95, 0.5, 0.0, 0.9)]
    for k, (x, y, z, h, rx, ry) in enumerate(crystals):
        r = 0.12 + h * 0.07
        glow_o.append(d.cyl(f"lc_cr{k}", r, h, (x, y, z), (rx, ry, k * 0.4), 6))
        tip = (x + math.sin(ry) * h * 0.62, y - math.sin(rx) * h * 0.62, z + math.cos(rx) * math.cos(ry) * h * 0.62)
        glow_o.append(_cone(f"lc_tip{k}", r, 0.0, h * 0.35, tip, 6, (rx, ry, k * 0.4)))
    dark.append(d.cyl("lc_core", 0.2, 0.7, (0, 0, 1.45), vertices=6))
    # The lectern at the front (+Y faces the room).
    body += [d.bbox("lc_lect_post", (0.3, 0.3, 1.0), (0, 1.95, 0.5)), d.bbox("lc_lect_top", (0.8, 0.5, 0.08), (0, 1.92, 1.05), (math.radians(-25), 0, 0))]
    scr.append(d.bbox("lc_lect_scr", (0.66, 0.36, 0.02), (0, 1.94, 1.1), (math.radians(-25), 0, 0)))
    glow_o += [d.bbox(f"lc_btn{k}", (0.05, 0.05, 0.02), (-0.25 + k * 0.1, 1.78, 1.0)) for k in range(6)]
    # Coolant pipes behind, into the deck.
    for s in (-1, 1):
        dark += [_pipe(f"lc_cool{s}a", (s * 0.6, -1.45, 0.3), (s * 0.6, -2.0, 0.3), 0.09, 16),
                 _pipe(f"lc_cool{s}b", (s * 0.6, -2.0, 0.3), (s * 0.6, -2.0, 0.0), 0.09, 16)]
        body.append(_torus(f"lc_flange{s}", 0.11, 0.025, 0.3, 16, 6, s * 0.6, -1.5, (math.radians(90), 0, 0)))
    return [(join("lc_body_j", body), steel("base_lc_m", 5, HULL), "box"),
            (join("lc_hz_j", hz), steel("base_lc_hz_m", 2, SAFETY), "band"),
            (join("lc_grate_j", grate), steel("base_lc_grate_m", 3, HULL), "grate"),
            (join("lc_dark_j", dark), paint("base_lc_dark_m", "2a2f33", "1a1e22"), "pipes"),
            (join("lc_scr_j", scr), glow("base_lc_scr_m"), "screen_glow"),
            (join("lc_rings", glow_c), glow_warm("base_lc_ring_m", "8fd8f0", "3fa8b8"), "ring_glow"),
            (join("lc_crystal", glow_o), glow_warm("base_lc_crystal_m", "ff7a24", "c2461a"), "crystal_glow")]


def base_sample_cabinet():
    """源石样本柜: an open-fronted cabinet, three shelves of tube racks, each
    sealed tube lit by the sample inside; a lit cornice, a status screen on
    the side post, two drawers below, a hazard strip at the foot."""
    body, hz, tubes, caps, samples, scr, glows = [], [], [], [], [], [], []
    body += [d.bbox("lsc_back", (2.4, 0.1, 3.0), (0, -0.35, 1.5)), d.bbox("lsc_top", (2.5, 0.85, 0.14), (0, 0, 2.93)),
             d.bbox("lsc_foot", (2.4, 0.8, 0.12), (0, 0, 0.06))]
    body += [d.bbox(f"lsc_side{s}", (0.1, 0.82, 3.0), (s * 1.15, 0, 1.5)) for s in (-1, 1)]
    body += [d.bbox(f"lsc_drawer{k}", (1.08, 0.06, 0.36), (-0.56 + k * 1.12, 0.39, 0.38)) for k in range(2)]
    body += [d.bbox(f"lsc_pull{k}", (0.3, 0.05, 0.04), (-0.56 + k * 1.12, 0.44, 0.44)) for k in range(2)]
    body += [d.bbox(f"lsc_vent{k}", (0.03, 0.02, 0.5), (1.21, -0.2 + k * 0.08, 1.6)) for k in range(6)]
    hz.append(d.bbox("lsc_hz", (2.38, 0.03, 0.08), (0, 0.41, 0.12)))
    glows.append(d.bbox("lsc_cornice", (2.2, 0.03, 0.04), (0, 0.43, 2.86)))
    scr.append(d.bbox("lsc_scr", (0.03, 0.34, 0.24), (1.21, 0.15, 1.95)))
    for k in range(3):
        z = 0.7 + k * 0.72
        body.append(d.bbox(f"lsc_shelf{k}", (2.2, 0.66, 0.05), (0, 0.03, z)))
        body.append(d.bbox(f"lsc_rack{k}", (2.1, 0.22, 0.12), (0, 0.15, z + 0.09)))
        glows.append(d.bbox(f"lsc_lip{k}", (2.2, 0.03, 0.03), (0, 0.37, z + 0.02)))
        for j in range(10):
            x = -0.95 + j * 0.21
            for row, y in enumerate((0.08, 0.24)):
                tubes.append(d.cyl(f"lsc_t{k}{j}{row}", 0.055, 0.42, (x, y, z + 0.27), vertices=16))
                caps.append(d.cyl(f"lsc_c{k}{j}{row}", 0.062, 0.06, (x, y, z + 0.5), vertices=16))
                level = (j + row + k) % 3
                samples.append(d.cyl(f"lsc_s{k}{j}{row}", 0.04, 0.14 + 0.06 * level, (x, y, z + 0.13 + 0.03 * level), vertices=6))
    return [(join("lsc_body_j", body), steel("base_lsc_m", 5, WHITE), "box"),
            (join("lsc_hz_j", hz), steel("base_lsc_hz_m", 2, SAFETY), "band"),
            (join("lsc_tubes", tubes), glow("base_lsc_tube_m", "bfe8f0"), "tube_glow"),
            (join("lsc_caps", caps), paint("base_lsc_cap_m", BLUE, "2c5880"), "caps"),
            (join("lsc_samples", samples), glow_warm("base_lsc_sample_m", "ff7a24", "c2461a"), "sample_glow"),
            (join("lsc_scr_j", scr), glow("base_lsc_scr_m"), "screen_glow"),
            (join("lsc_glows", glows), glow("base_lsc_light_m", "f4fbff"), "light_glow")]


def base_fume_hood():
    """通风橱: a steel base with two doors, a dark epoxy worktop, a baffled back
    wall, a framed sash with its handle and lit sill, a side control post
    with lit buttons, glassware on the worktop and a flanged duct to the
    ceiling."""
    body, top, glass, liquid, scr, glows, hz = [], [], [], [], [], [], []
    body += [d.bbox("lfh_base", (2.4, 0.95, 0.88), (0, 0, 0.44)), d.bbox("lfh_kick", (2.3, 0.85, 0.1), (0, 0, 0.05))]
    body += [d.bbox(f"lfh_door{k}", (1.12, 0.04, 0.68), (-0.58 + k * 1.16, 0.48, 0.48)) for k in range(2)]
    body += [d.bbox(f"lfh_handle{k}", (0.04, 0.05, 0.3), (-0.1 + k * 0.2, 0.52, 0.55)) for k in range(2)]
    top.append(d.bbox("lfh_top", (2.46, 1.0, 0.05), (0, 0, 0.91)))
    body += [d.bbox("lfh_backwall", (2.3, 0.06, 1.4), (0, -0.45, 1.62)), d.bbox("lfh_hood", (2.46, 1.0, 0.5), (0, 0, 2.55))]
    body += [d.bbox(f"lfh_baffle{k}", (2.2, 0.04, 0.04), (0, -0.41, 1.15 + k * 0.22)) for k in range(5)]
    body += [d.bbox(f"lfh_side{s}", (0.1, 1.0, 1.4), (s * 1.18, 0, 1.62)) for s in (-1, 1)]
    body += [d.bbox("lfh_sash_top", (2.26, 0.06, 0.08), (0, 0.47, 2.0)), d.bbox("lfh_sash_bar", (1.2, 0.07, 0.05), (0, 0.52, 1.92))]
    body += [d.bbox(f"lfh_sash_side{s}", (0.06, 0.06, 0.95), (s * 1.1, 0.47, 1.52)) for s in (-1, 1)]
    hz.append(d.bbox("lfh_hz", (2.4, 0.03, 0.08), (0, 0.5, 2.38)))
    glows += [d.bbox("lfh_sill", (2.2, 0.03, 0.03), (0, 0.48, 0.96)), d.bbox("lfh_lamp", (2.0, 0.3, 0.02), (0, 0.0, 2.29))]
    body.append(d.bbox("lfh_ctrl", (0.2, 0.12, 0.6), (1.3, 0.38, 1.4)))
    glows += [d.bbox(f"lfh_btn{k}", (0.1, 0.02, 0.05), (1.3, 0.45, 1.25 + k * 0.1)) for k in range(4)]
    scr.append(d.bbox("lfh_scr", (0.14, 0.02, 0.12), (1.3, 0.45, 1.62)))
    body.append(d.cyl("lfh_duct", 0.26, 1.5, (0, -0.15, 3.55), vertices=32))
    body += [_torus(f"lfh_fl{k}", 0.27, 0.03, 2.9 + k * 0.5, 32, 6, 0, -0.15) for k in range(3)]
    # Glassware: flasks, beakers and a retort stand.
    for k, x in enumerate((-0.8, -0.45, 0.45)):
        glass += [_cone(f"lfh_flask{k}", 0.13, 0.04, 0.24, (x, 0.0, 1.05), 24), d.cyl(f"lfh_neck{k}", 0.035, 0.12, (x, 0.0, 1.23), vertices=16)]
        liquid.append(_cone(f"lfh_liq{k}", 0.12, 0.07, 0.1, (x, 0.0, 0.99), 24))
    for k, x in enumerate((-0.1, 0.1, 0.8)):
        glass.append(d.cyl(f"lfh_beaker{k}", 0.07, 0.16, (x, 0.18, 1.01), vertices=20))
        liquid.append(d.cyl(f"lfh_bliq{k}", 0.062, 0.07, (x, 0.18, 0.97), vertices=20))
    body += [d.bbox("lfh_stand_foot", (0.3, 0.2, 0.03), (0.9, -0.2, 0.95)), d.cyl("lfh_stand_rod", 0.015, 0.8, (0.98, -0.2, 1.35), vertices=8),
             d.bbox("lfh_clamp", (0.18, 0.04, 0.04), (0.9, -0.2, 1.45))]
    return [(join("lfh_body_j", body), steel("base_lfh_m", 5, WHITE), "box"),
            (join("lfh_top_j", top), paint("base_lfh_top_m", "2a2f33", "1a1e22"), "top"),
            (join("lfh_hz_j", hz), steel("base_lfh_hz_m", 2, SAFETY), "band"),
            (join("lfh_glass", glass), glow("base_lfh_glass_m", "cfeef4"), "glass_glow"),
            (join("lfh_liquid", liquid), glow("base_lfh_liquid_m", "8fe0c0"), "liquid_glow"),
            (join("lfh_scr_j", scr), glow("base_lfh_scr_m"), "screen_glow"),
            (join("lfh_glows", glows), glow("base_lfh_light_m", "f4fbff"), "light_glow")]


def base_research_holo():
    """全息科技树台: a stepped round console, eight workstation bays round its
    rim (an angled screen and a keyboard each), a lit floor ring, a central
    emitter column with a lens; the tree itself (one light per node) is drawn
    in Godot and lit by what is done."""
    body, dark, scr, glows, hz = [], [], [], [], []
    body += [d.cyl("lrh_step0", 2.55, 0.1, (0, 0, 0.05), vertices=64), d.cyl("lrh_step1", 2.4, 0.55, (0, 0, 0.375), vertices=64),
             d.cyl("lrh_lip", 2.48, 0.06, (0, 0, 0.68), vertices=64), d.cyl("lrh_top", 2.15, 0.08, (0, 0, 0.74), vertices=64)]
    hz.append(d.cyl("lrh_hz", 2.56, 0.04, (0, 0, 0.12), vertices=64))
    glows.append(_torus("lrh_ring", 2.02, 0.035, 0.8, 64, 6))
    body += _bolts("lrh_b", [(2.42 * math.cos(k * math.pi / 16), 2.42 * math.sin(k * math.pi / 16), 0.5) for k in range(32)], 0.025, 0.02, "z")
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        x, y = 2.3 * math.cos(a), 2.3 * math.sin(a)
        yaw = a + math.pi / 2
        body.append(d.bbox(f"lrh_bay{k}", (0.95, 0.42, 0.18), (x, y, 0.84), (0, 0, yaw)))
        scr.append(d.bbox(f"lrh_scr{k}", (0.8, 0.02, 0.36), (2.38 * math.cos(a), 2.38 * math.sin(a), 1.08), (math.radians(-20), 0, yaw - math.pi)))
        dark.append(d.bbox(f"lrh_kb{k}", (0.6, 0.2, 0.03), (2.12 * math.cos(a), 2.12 * math.sin(a), 0.94), (0, 0, yaw)))
        glows.append(d.bbox(f"lrh_led{k}", (0.6, 0.02, 0.02), (2.5 * math.cos(a), 2.5 * math.sin(a), 0.62), (0, 0, yaw)))
    body += [d.cyl("lrh_column", 0.42, 0.5, (0, 0, 1.03), vertices=32), d.cyl("lrh_collar", 0.5, 0.08, (0, 0, 1.3), vertices=32)]
    for k in range(6):
        a = k * math.pi / 3
        body.append(d.bbox(f"lrh_fin{k}", (0.05, 0.22, 0.4), (0.44 * math.cos(a), 0.44 * math.sin(a), 1.05), (0, 0, a + math.pi / 2)))
    glows += [d.cyl("lrh_lens", 0.3, 0.06, (0, 0, 1.37), vertices=32), _torus("lrh_lens_ring", 0.38, 0.025, 1.36, 32, 6)]
    for k in range(4):
        a = k * math.pi / 2
        dark.append(_pipe(f"lrh_conduit{k}", (0.5 * math.cos(a), 0.5 * math.sin(a), 0.8), (1.9 * math.cos(a), 1.9 * math.sin(a), 0.8), 0.04, 10))
    return [(join("lrh_body_j", body), steel("base_lrh_m", 5, HULL), "box"),
            (join("lrh_hz_j", hz), steel("base_lrh_hz_m", 2, SAFETY), "band"),
            (join("lrh_dark_j", dark), paint("base_lrh_dark_m", "2a2f33", "1a1e22"), "dark"),
            (join("lrh_scr_j", scr), glow("base_lrh_scr_m"), "screen_glow"),
            (join("lrh_glows", glows), glow_warm("base_lrh_glow_m", "ffa050", "d0662a"), "ring_glow")]


def base_fabricator():
    """加工站的加工机: a big industrial fabricator against the wall — a steel
    housing, a lit glass chamber with a part being made, a gantry head over
    it, an orange-trimmed control panel and a hopper (front +Y)."""
    body = [d.bbox("fb_body", (4.0, 2.2, 0.9), (0, -0.2, 0.45)), d.bbox("fb_back", (4.0, 0.6, 3.4), (0, -1.0, 1.7)),
            d.bbox("fb_roof", (4.0, 2.0, 0.3), (0, -0.3, 3.25)), d.bbox("fb_post0", (0.3, 0.3, 2.5), (-1.85, 0.7, 2.05)),
            d.bbox("fb_post1", (0.3, 0.3, 2.5), (1.85, 0.7, 2.05)), d.bbox("fb_hopper", (0.9, 0.9, 0.8), (1.4, -0.9, 3.75))]
    chamber = [d.bbox("fb_glass", (3.2, 1.4, 0.04), (0, -0.2, 0.92)), d.bbox("fb_glass_f", (3.2, 0.04, 2.1), (0, 0.5, 1.95))]
    head = [d.bbox("fb_rail", (3.4, 0.2, 0.2), (0, -0.2, 2.85)), d.bbox("fb_head", (0.5, 0.5, 0.6), (-0.4, -0.2, 2.5)),
            d.cyl("fb_nozzle", 0.08, 0.5, (-0.4, -0.2, 2.0), vertices=8)]
    part = [d.bbox("fb_part", (0.8, 0.6, 0.35), (-0.4, -0.2, 1.1))]
    panel = [d.bbox("fb_panel", (0.8, 0.5, 1.3), (2.45, 0.2, 0.65)), d.bbox("fb_trim", (4.0, 0.06, 0.1), (0, 0.92, 0.88))]
    scr = [d.bbox("fb_scr", (0.6, 0.02, 0.4), (2.45, 0.46, 1.0))]
    return [(join("fb_body_j", body + head), steel("base_fb_m", 4, HULL), "body"),
            (join("fb_panel_j", panel), paint("base_fb_trim_m", ORANGE, "a24e1e"), "trim"),
            (join("fb_part_j", part), paint("base_fb_part_m", "ffb060"), "part"),
            (join("fb_glass_j", chamber), glow("base_fb_glass_m", "6fb8d8"), "glass_glow"),
            (join("fb_scr_j", scr), glow("base_fb_glow_m"), "glow")]


HALL_BUILDERS = [base_command_dais, base_market_wall, base_exchange_counter, base_sofa, base_coffee_table, base_vending_machine,
                 base_bar_counter, base_bookshelf, base_lounge_rug, base_personnel_desk, base_roster_holo, base_file_cabinets,
                 base_interview_table, base_weapon_rack_stand, base_hanging_directory,
                 base_hanging_sign_warehouse, base_hanging_sign_medical, base_hanging_sign_store, base_hanging_sign_personnel,
                 base_hanging_sign_exchange, base_hanging_sign_lounge, base_hanging_sign_loadout, base_hanging_sign_logistics,
                 base_hanging_sign_workshop, base_fabricator, base_holo_screen_frame, base_trader_desk, base_trading_post]
ROOM_BUILDERS += HALL_BUILDERS
LAB_BUILDERS = [base_hanging_sign_research, base_originium_chamber, base_sample_cabinet, base_fume_hood, base_research_holo]
ROOM_BUILDERS += LAB_BUILDERS


# --- Detail pass (用户 2026-10-18: 补更精细的模型) -------------------------------------
# A second layer on the most-seen pieces, built after each piece's own parts
# (build() adds DETAILS[name]()): screws and seams, labels, lit indicators,
# cables, and the small things people leave on furniture. Same conventions:
# origin at the bottom centre, front +Y.

def _leds(prefix, points, colour="70f0a0", size=0.05):
    return (join(f"{prefix}_leds", [d.bbox(f"{prefix}_led{k}", (size, 0.03, size), p) for k, p in enumerate(points)]),
            glow(f"base_{prefix}_led_m", colour), f"{prefix}_led_glow")


def _cable(name, points, radius=0.025):
    """A cable as straight runs between points."""
    segs = []
    for k, (a, b) in enumerate(zip(points, points[1:])):
        mid = [(a[i] + b[i]) / 2 for i in range(3)]
        vec = mathutils.Vector(b) - mathutils.Vector(a)
        seg = d.cyl(f"{name}{k}", radius, vec.length, mid, vertices=6)
        seg.rotation_mode = "QUATERNION"
        seg.rotation_quaternion = mathutils.Vector((0, 0, 1)).rotation_difference(vec.normalized())
        segs.append(seg)
    return segs


def _det_wall_panel():
    seams = [d.bbox(f"wd_seam{k}", (3.3, 0.02, 0.025), (0, 0.06, z)) for k, z in enumerate((0.95, 2.5))]
    box = [d.bbox("wd_box", (0.42, 0.14, 0.5), (-1.25, 0.1, 2.15)), d.cyl("wd_conduit", 0.035, 1.5, (-1.25, 0.12, 1.15), vertices=8)]
    label = [d.bbox("wd_label", (0.36, 0.02, 0.18), (-0.45, 0.07, 0.42))]
    screws = d.rivets("wd_sc", [(x, 0.07, z) for x in (-1.75, 1.75) for z in (0.95, 1.85, 2.5)], radius=0.022, sign=1.0)
    return [(join("wd_hw", seams + box + screws), steel("base_wd_m", 2, "3a4046"), "hardware"),
            (join("wd_label_j", label), paint("base_wd_hz_m", SAFETY), "label"),
            _leds("wd", [(1.45, 0.08, 2.25), (1.55, 0.08, 2.25)], "70f0a0", 0.04)]


def _det_wall_panel_med():
    sanit = [d.bbox("wmd_disp", (0.22, 0.14, 0.32), (1.2, 0.12, 1.35)), d.bbox("wmd_drip", (0.16, 0.08, 0.04), (1.2, 0.16, 1.15))]
    label = [d.bbox("wmd_label", (0.5, 0.02, 0.26), (-1.1, 0.07, 2.2))]
    return [(join("wmd_hw", sanit), steel("base_wmd_m", 4, WHITE), "hardware"),
            (join("wmd_label_j", label), paint("base_wmd_label_m", TEAL), "label"),
            _leds("wmd", [(1.2, 0.2, 1.45)], "70f0a0", 0.03)]


def _det_desk():
    kb = [d.bbox("dd_kb", (0.6, 0.2, 0.03), (-0.3, 0.2, 0.88)), d.bbox("dd_mouse", (0.07, 0.11, 0.03), (0.15, 0.22, 0.88))]
    stuff = [d.bbox("dd_paper", (0.32, 0.24, 0.03), (0.75, 0.15, 0.88), (0, 0, 0.2)), d.bbox("dd_paper2", (0.3, 0.22, 0.02), (0.78, 0.1, 0.91), (0, 0, -0.15)),
             d.cyl("dd_mug", 0.05, 0.11, (1.15, -0.1, 0.92), vertices=10)]
    lamp = [d.cyl("dd_lp", 0.02, 0.4, (1.2, -0.35, 1.06), vertices=6), d.bbox("dd_lh", (0.3, 0.12, 0.06), (1.08, -0.3, 1.27))]
    cable = _cable("dd_cb", [(-0.3, -0.5, 0.9), (-0.3, -0.58, 0.5), (-0.3, -0.58, 0.02)], 0.015)
    return [(join("dd_dark", kb + lamp + cable), paint("base_dd_m", RUBBER), "dark"),
            (join("dd_stuff", stuff), paint("base_dd_stuff_m", WHITE, "b0b8bc"), "stuff")]


def _det_logistics_counter():
    boxes = [d.bbox("ldc_b0", (0.5, 0.4, 0.35), (-1.8, 0.05, 1.26)), d.bbox("ldc_b1", (0.4, 0.35, 0.3), (-1.3, 0.1, 1.23)),
             d.bbox("ldc_b2", (0.35, 0.3, 0.25), (-1.75, 0.05, 1.56))]
    clip = [d.bbox("ldc_clip", (0.25, 0.32, 0.02), (0.3, 0.25, 1.09)), d.bbox("ldc_scan", (0.1, 0.18, 0.12), (0.6, 0.2, 1.14))]
    stripes = [d.bbox(f"ldc_hz{s}", (0.17, 0.17, 0.5), (s * 2.25, -0.4, 0.25)) for s in (-1, 1)]
    lamp = [d.bbox("ldc_lamp", (1.6, 0.18, 0.06), (0, -0.4, 2.42))]
    return [(join("ldc_boxes", boxes), steel("base_ldc_box_m", 5, "b08a5a"), "boxes"),
            (join("ldc_clip_j", clip), paint("base_ldc_clip_m", RUBBER), "clip"),
            (join("ldc_hz_j", stripes), paint("base_ldc_hz_m", SAFETY), "stripe"),
            (join("ldc_lamp_j", lamp), glow("base_ldc_lamp_m", "f4fbff"), "lamp_glow")]


def _det_armory_bench():
    parts = [d.bbox("abd_tray", (0.8, 0.5, 0.08), (0.8, 0.2, 1.02)), d.bbox("abd_ammo0", (0.3, 0.2, 0.18), (2.6, 0.2, 1.07)),
             d.bbox("abd_ammo1", (0.3, 0.2, 0.18), (2.6, -0.05, 1.07))]
    helmet = [kit.rock("abd_helmet", 0.2, (-2.4, 0.15, 1.12), (1.0, 1.1, 0.8), 1)]
    screws = [d.cyl(f"abd_sc{k}", 0.02, 0.02, (0.6 + k * 0.08, 0.25, 1.07), vertices=6) for k in range(6)]
    board = [d.bbox("abd_peg", (3.0, 0.03, 0.9), (-1.2, -0.48, 1.55))]
    holes = [d.cyl(f"abd_h{k}_{r}", 0.012, 0.02, (-2.6 + k * 0.2, -0.46, 1.2 + r * 0.2), (math.radians(90), 0, 0), 6) for k in range(14) for r in range(4)]
    return [(join("abd_parts", parts + screws), steel("base_abd_m", 2, "5c646a"), "parts"),
            (join("abd_helmet_j", helmet), paint("base_abd_helmet_m", "4a5a48", "34402f"), "helmet"),
            (join("abd_board", board + holes), steel("base_abd_board_m", 3, PANEL), "board"),
            _leds("abd", [(2.9, 0.62, 0.8), (2.75, 0.62, 0.8)], "f0a040", 0.04)]


def _det_command_dais():
    grates = [d.bbox(f"cdd_gr{k}", (0.9, 0.5, 0.012), (x, y, 0.326)) for k, (x, y) in enumerate(((-2.4, 1.6), (2.4, 1.6), (-3.6, -0.6), (3.6, -0.6)))]
    kbs = []
    for k in range(7):
        a = math.radians(-60 + k * 20)
        r = 4.4 - 0.35
        kbs.append(d.bbox(f"cdd_kb{k}", (0.7, 0.22, 0.03), (r * math.sin(a), -r * math.cos(a), 1.2), (0, 0, a)))
    cables = []
    for s in (-1, 1):
        a = math.radians(s * 65)
        x, y = 4.9 * math.sin(a), -4.9 * math.cos(a)
        cables += _cable(f"cdd_cb{s}", [(x, y, 0.4), (x * 1.15, y * 1.15, 0.34), (x * 1.3, y * 1.3, 0.17)], 0.05)
    lamps = [d.bbox(f"cdd_st{k}", (0.5, 0.06, 0.04), (6.95 * math.cos((k + 0.5) / 8 * math.tau), 6.95 * math.sin((k + 0.5) / 8 * math.tau) * 0.72 + 0.0, 0.17),
                    (0, 0, (k + 0.5) / 8 * math.tau + math.pi / 2)) for k in range(8)]
    return [(join("cdd_grates", grates), steel("base_cdd_gr_m", 2, "3a4046"), "grate"),
            (join("cdd_dark", kbs + cables), paint("base_cdd_m", RUBBER), "dark"),
            (join("cdd_lamps", lamps), glow("base_cdd_lamp_m", "4f9fe0"), "step_glow")]


def _det_fabricator():
    pipes = _cable("fbd_p0", [(-2.1, -1.0, 3.3), (-2.1, -1.0, 0.5), (-2.1, 0.0, 0.3)], 0.08) + _cable("fbd_p1", [(2.1, -1.2, 3.0), (2.1, -1.2, 0.4)], 0.07)
    vents = [d.bbox(f"fbd_v{k}", (0.9, 0.04, 0.04), (-1.2, 0.86, 0.2 + k * 0.1)) for k in range(5)]
    stripes = [d.bbox(f"fbd_hz{k}", (0.3, 0.05, 0.12), (-1.8 + k * 0.45, 0.92, 0.06), (0, math.radians(30), 0)) for k in range(9)]
    return [(join("fbd_pipes", pipes + vents), steel("base_fbd_m", 2, PANEL), "pipes"),
            (join("fbd_hz_j", stripes), paint("base_fbd_hz_m", SAFETY), "stripe"),
            _leds("fbd", [(2.3, 0.47, 1.45), (2.45, 0.47, 1.45), (2.6, 0.47, 1.45)], "70f0a0", 0.05)]


def _det_bed(prefix):
    def details():
        clip = [d.bbox(f"{prefix}_clip", (0.3, 0.02, 0.4), (0.3, 1.21, 0.6))]
        ctrl = [d.bbox(f"{prefix}_ctrl", (0.12, 0.2, 0.06), (0.64, 0.2, 0.75))]
        wheels = [d.cyl(f"{prefix}_wh{k}", 0.06, 0.12, (sx * 0.5, sy * 1.0, 0.18), vertices=8) for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
        return [(join(f"{prefix}_det", ctrl + wheels), paint(f"base_{prefix}_det_m", RUBBER), "det"),
                (join(f"{prefix}_clip_j", clip), paint(f"base_{prefix}_clip_m", WHITE, "b0b8bc"), "clip")]
    return details


def _det_rack(prefix):
    def details():
        tags = [d.bbox(f"{prefix}_tag{k}_{r}", (0.22, 0.02, 0.08), (-1.5 + k * 1.0, 0.62, 0.25 + r * 0.8)) for k in range(4) for r in range(3)]
        kick = [d.bbox(f"{prefix}_kick{k}", (0.3, 0.05, 0.1), (-1.9 + k * 0.4, 0.63, 0.06), (0, math.radians(30), 0)) for k in range(10)]
        return [(join(f"{prefix}_tags", tags), paint(f"base_{prefix}_tag_m", WHITE, "b0b8bc"), "tags"),
                (join(f"{prefix}_kick_j", kick), paint(f"base_{prefix}_hz_m", SAFETY), "stripe")]
    return details


def _det_sofa():
    pillows = [kit.rock("sfd_p0", 0.2, (-0.85, -0.1, 0.72), (1.0, 0.45, 0.9), 1), kit.rock("sfd_p1", 0.2, (0.85, -0.1, 0.72), (1.0, 0.45, 0.9), 1)]
    stitch = [d.bbox("sfd_st", (2.0, 0.02, 0.02), (0, -0.2, 0.75))]
    return [(join("sfd_pil", pillows), paint("base_sfd_chair_m", ORANGE, "a24e1e"), "pillows"),
            (join("sfd_st_j", stitch), paint("base_sfd_m", "34505f"), "stitch")]


def _det_holo_table():
    kbs = [d.bbox(f"htd_kb{k}", (1.2, 0.35, 0.05), (-12.0 + k * 6.0, 10.6, 0.95), (math.radians(-15), 0, 0)) for k in range(5)]
    scr = [d.bbox(f"htd_scr{k}", (0.9, 0.04, 0.5), (-12.0 + k * 6.0, 10.4, 1.25), (math.radians(-25), 0, 0)) for k in range(5)]
    return [(join("htd_kb_j", kbs), paint("base_htd_m", RUBBER), "kb"),
            (join("htd_scr_j", scr), glow("base_htd_glow_m"), "screen_glow")]


def _det_personnel_desk():
    kbs = [d.bbox(f"pdd_kb{k}", (0.6, 0.2, 0.03), (x, 0.2, 1.12)) for k, x in enumerate((-1.6, 0.0, 1.6))]
    plate = [d.bbox("pdd_plate", (0.5, 0.06, 0.12), (-0.8, 0.45, 1.15))]
    plant = [d.cyl("pdd_pot", 0.12, 0.18, (2.3, 0.0, 1.2), vertices=10), kit.rock("pdd_leaf", 0.18, (2.3, 0.0, 1.42), (1.0, 1.0, 0.8), 1)]
    return [(join("pdd_dark", kbs), paint("base_pdd_m", RUBBER), "dark"),
            (join("pdd_plate_j", plate + plant[:1]), paint("base_pdd_plate_m", BLUE, "2c5880"), "plate"),
            (join("pdd_leaf_j", plant[1:]), paint("base_pdd_leaf_m", "3f6a3a", "253f22"), "leaf")]


def _det_bar_counter():
    cups = [d.cyl(f"bcd_c{k}", 0.05, 0.12, (-1.4 + k * 0.5, 0.15, 1.17), vertices=10) for k in range(5)]
    taps = [d.cyl(f"bcd_t{k}", 0.03, 0.3, (0.6 + k * 0.2, -0.2, 1.25), vertices=6) for k in range(3)]
    return [(join("bcd_cups", cups), paint("base_bcd_m", WHITE, "b0b8bc"), "cups"),
            (join("bcd_taps", taps), steel("base_bcd_tap_m", 2, "a8b0b4"), "taps")]



# --- 基建 (基建设施修订案_v1_1 §二, §三, §六) ------------------------------------------
# The construction kit every unbuilt part stands behind, and the parts the
# facility levels add. The kit pieces are shown at their modelled size
# (BaseMap.UNSCALED "build_"), the parts at PROP_SCALE like the other props.

def _hazard_plate(name, size, location, rotation=(0, 0, 0)):
    return d.bbox(name, size, location, rotation, 0.008)


def base_build_barrier(width=2.0):
    """施工围挡: a 2 m panel of yellow-and-black stripes in a steel frame on two
    ballast feet, the Rhodes logo stencilled in the middle, reflectors along
    the top rail and an amber flasher on one post."""
    frame, feet, hz, logo, refl, lamp = [], [], [], [], [], []
    for s in (-1, 1):
        x = s * (width / 2 - 0.06)
        frame.append(d.bbox(f"bb_post{s}", (0.07, 0.07, 1.08), (x, 0, 0.6), width=0.01))
        feet += [d.bbox(f"bb_foot{s}", (0.34, 0.6, 0.14), (x, 0, 0.07), width=0.03),
                 d.bbox(f"bb_foot_top{s}", (0.24, 0.42, 0.06), (x, 0, 0.17), width=0.02)]
        feet += _bolts(f"bb_fb{s}", [(x + dx, 0.0, 0.205) for dx in (-0.07, 0.07)], 0.02, 0.02, "z")
    frame += [d.bbox("bb_rail_top", (width, 0.06, 0.07), (0, 0, 1.13)), d.bbox("bb_rail_bot", (width, 0.05, 0.05), (0, 0, 0.27))]
    hz.append(_hazard_plate("bb_panel", (width - 0.16, 0.03, 0.78), (0, 0.0, 0.7)))
    logo.append(d.bbox("bb_logo", (0.5, 0.012, 0.44), (0, 0.022, 0.7), width=0.002))
    refl += [d.bbox(f"bb_refl{k}", (0.16, 0.012, 0.035), (-width / 2 + 0.35 + k * (width - 0.7) / 3, 0.036, 1.13)) for k in range(4)]
    lamp += [d.cyl("bb_flash", 0.06, 0.09, (-width / 2 + 0.06, 0, 1.24), vertices=16)]
    frame.append(d.cyl("bb_flash_base", 0.05, 0.04, (-width / 2 + 0.06, 0, 1.18), vertices=12))
    return [(join("bb_frame_j", frame), steel("base_bb_m", 3, HULL), "frame"),
            (join("bb_feet_j", feet), paint("base_bb_feet_m", ORANGE, "a24e1e"), "feet"),
            (join("bb_hz_j", hz), steel("base_bb_hz_m", 2, SAFETY), "panel"),
            (join("bb_logo_j", logo), logo_decal("base_bb_logo_m", SAFETY), "logo"),
            (join("bb_refl_j", refl), glow("base_bb_refl_m", "f2f6f8"), "refl_glow"),
            (join("bb_lamp_j", lamp), glow_warm("base_bb_lamp_m", "ffb03a", "c27414"), "lamp_glow")]


def base_build_cone():
    """A road cone on a square rubber foot, two reflective bands."""
    foot = [d.bbox("bc_foot", (0.4, 0.4, 0.05), (0, 0, 0.025), width=0.02)]
    cone = [_cone("bc_cone", 0.15, 0.03, 0.62, (0, 0, 0.36), 24)]
    bands = [_cone("bc_band0", 0.115, 0.1, 0.07, (0, 0, 0.36), 24), _cone("bc_band1", 0.08, 0.062, 0.06, (0, 0, 0.52), 24)]
    for k, b in enumerate(bands):
        b.scale = (1.06, 1.06, 1.0)
    return [(join("bc_foot_j", foot), paint("base_bcone_foot_m", RUBBER, "202326"), "foot"),
            (join("bc_cone_j", cone), paint("base_bcone_m", ORANGE, "b4521e"), "cone"),
            (join("bc_band_j", bands), glow("base_bcone_refl_m", "eef3f5"), "band_glow")]


def base_build_crate_tarp():
    """Supplies under a grey tarp on a pallet: the crate's shape through the
    cloth, the cloth hanging in folds round the foot, two yellow ratchet
    straps over it, corner guards, a facility pictogram patch (no text)."""
    pallet, tarp, straps, guards, patch = [], [], [], [], []
    pallet += [d.bbox(f"bct_slat{k}", (1.6, 0.16, 0.03), (0, -0.5 + k * 0.25, 0.13), width=0.006) for k in range(5)]
    pallet += [d.bbox(f"bct_block{i}{j}", (0.14, 0.14, 0.1), (x, y, 0.05), width=0.01) for i, x in enumerate((-0.7, 0, 0.7)) for j, y in enumerate((-0.5, 0, 0.5))]
    tarp.append(d.bbox("bct_body", (1.5, 1.1, 0.86), (0, 0, 0.58), width=0.08))
    tarp.append(d.bbox("bct_top", (1.38, 0.98, 0.1), (0.02, -0.01, 1.03), (0, 0, 0.03), 0.05))
    # Folds round the foot, uneven.
    for k in range(9):
        t = -0.66 + k * 0.165
        tarp.append(d.bbox(f"bct_fold_s{k}", (0.12, 0.05, 0.3 + 0.08 * ((k * 7) % 3)), (t, 0.565, 0.33), (0.06 * ((k % 2) * 2 - 1), 0, 0), 0.02))
        tarp.append(d.bbox(f"bct_fold_n{k}", (0.12, 0.05, 0.28 + 0.07 * ((k * 5) % 3)), (t, -0.565, 0.33), (0, 0, 0), 0.02))
    for k in range(6):
        t = -0.42 + k * 0.17
        tarp.append(d.bbox(f"bct_fold_w{k}", (0.05, 0.12, 0.3 + 0.06 * (k % 3)), (-0.765, t, 0.33), width=0.02))
        tarp.append(d.bbox(f"bct_fold_e{k}", (0.05, 0.12, 0.28 + 0.06 * ((k + 1) % 3)), (0.765, t, 0.33), width=0.02))
    for s in (-1, 1):
        x = s * 0.4
        straps += [d.bbox(f"bct_strap_t{s}", (0.07, 1.16, 0.012), (x, 0, 1.085)), d.bbox(f"bct_strap_f{s}", (0.07, 0.012, 0.95), (x, 0.58, 0.6)),
                   d.bbox(f"bct_strap_b{s}", (0.07, 0.012, 0.95), (x, -0.58, 0.6))]
        guards.append(d.bbox(f"bct_ratchet{s}", (0.12, 0.05, 0.08), (x, 0.6, 0.78), width=0.01))
    guards += [d.bbox(f"bct_guard{k}", (0.12, 0.12, 0.14), (sx * 0.72, sy * 0.52, 1.0), width=0.01)
               for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    patch.append(d.bbox("bct_patch", (0.36, 0.012, 0.3), (0.0, 0.57, 0.78), width=0.003))
    return [(join("bct_pallet_j", pallet), paint("base_bct_pallet_m", "7c6440", "54432a"), "pallet"),
            (join("bct_tarp_j", tarp), paint("base_bct_mat_m", "6f777c", "50575b"), "box"),
            (join("bct_straps_j", straps), paint("base_bct_strap_m", SAFETY, "a07a12"), "straps"),
            (join("bct_guard_j", guards), steel("base_bct_guard_m", 3, HULL), "guards"),
            (join("bct_patch_j", patch), logo_decal("base_bct_patch_m", SAFETY), "patch")]


def base_build_scaffold(width=3.0, depth=1.5, height=3.4):
    """Two-bay tube scaffolding: standards on screw-jack base plates, ledgers
    at each lift, cross braces on the back, two grated decks with toe boards,
    a ladder up the side, a hazard banner along the top rail."""
    tubes, plates, decks, toes, banner = [], [], [], [], []
    xs = (-width / 2, 0.0, width / 2)
    ys = (-depth / 2, depth / 2)
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            tubes.append(_pipe(f"bsc_std{i}{j}", (x, y, 0.12), (x, y, height), 0.024, 10))
            plates += [d.bbox(f"bsc_plate{i}{j}", (0.16, 0.16, 0.012), (x, y, 0.006)), d.cyl(f"bsc_jack{i}{j}", 0.03, 0.12, (x, y, 0.07), vertices=8)]
    for k, z in enumerate((0.25, 1.4, 2.6, height - 0.05)):
        for y in ys:
            tubes.append(_pipe(f"bsc_led{k}{y}", (-width / 2, y, z), (width / 2, y, z), 0.022, 8))
        for x in xs:
            tubes.append(_pipe(f"bsc_tr{k}{x}", (x, -depth / 2, z), (x, depth / 2, z), 0.022, 8))
    for i in range(2):
        tubes.append(_pipe(f"bsc_brace{i}", (xs[i], -depth / 2, 0.25), (xs[i + 1], -depth / 2, 2.6), 0.018, 8))
    for k, z in enumerate((1.42, 2.62)):
        for i in range(2):
            cx = (xs[i] + xs[i + 1]) / 2
            decks.append(d.bbox(f"bsc_deck{k}{i}", (width / 2 - 0.06, depth - 0.08, 0.04), (cx, 0, z + 0.04), width=0.006))
        toes += [d.bbox(f"bsc_toe{k}{s}", (width, 0.02, 0.15), (0, s * (depth / 2 - 0.01), z + 0.13)) for s in (-1, 1)]
    for k in range(10):
        tubes.append(_pipe(f"bsc_rung{k}", (width / 2 + 0.1, -0.2, 0.3 + k * 0.3), (width / 2 + 0.1, 0.2, 0.3 + k * 0.3), 0.014, 6))
    tubes += [_pipe(f"bsc_lad{s}", (width / 2 + 0.1, s * 0.2, 0.0), (width / 2 + 0.1, s * 0.2, 3.1), 0.018, 8) for s in (-1, 1)]
    banner.append(_hazard_plate("bsc_banner", (width - 0.1, 0.015, 0.32), (0, depth / 2 + 0.03, height - 0.3)))
    return [(join("bsc_tubes_j", tubes), steel("base_bsc_m", 4, PANEL), "frame"),
            (join("bsc_plates_j", plates), steel("base_bsc_plate_m", 2, HULL), "plates"),
            (join("bsc_decks_j", decks), steel("base_bsc_deck_m", 3, HULL), "deck"),
            (join("bsc_toes_j", toes), paint("base_bsc_toe_m", "8a6c3e", "5e4928"), "toes"),
            (join("bsc_banner_j", banner), steel("base_bsc_hz_m", 2, SAFETY), "banner")]


def base_build_lamp():
    """A tripod work lamp: three splayed legs, a telescoping mast, two flood
    heads on a crossbar facing the work, a cable coiled at its foot into a
    small power box."""
    legs, mast, heads, light, box = [], [], [], [], []
    for k in range(3):
        a = k * 2 * math.pi / 3
        legs.append(_pipe(f"bl_leg{k}", (0.0, 0.0, 0.9), (0.42 * math.cos(a), 0.42 * math.sin(a), 0.0), 0.02, 8))
        legs.append(d.cyl(f"bl_shoe{k}", 0.045, 0.03, (0.42 * math.cos(a), 0.42 * math.sin(a), 0.015), vertices=10))
    mast += [d.cyl("bl_mast0", 0.035, 1.0, (0, 0, 1.2), vertices=12), d.cyl("bl_mast1", 0.026, 0.8, (0, 0, 1.9), vertices=12),
             d.cyl("bl_collar", 0.05, 0.08, (0, 0, 1.7), vertices=12), d.bbox("bl_bar", (0.9, 0.05, 0.05), (0, 0, 2.28))]
    for s in (-1, 1):
        x = s * 0.32
        heads += [d.bbox(f"bl_head{s}", (0.34, 0.16, 0.26), (x, 0.06, 2.22), (math.radians(-20), 0, 0), 0.02)]
        heads += [d.bbox(f"bl_fin{s}{k}", (0.3, 0.02, 0.2), (x, -0.04 - k * 0.03, 2.22), (math.radians(-20), 0, 0)) for k in range(3)]
        light.append(d.bbox(f"bl_lens{s}", (0.28, 0.02, 0.2), (x, 0.145, 2.19), (math.radians(-20), 0, 0)))
    box += [d.bbox("bl_box", (0.36, 0.24, 0.26), (0.34, -0.42, 0.13), width=0.02)]
    box += [_torus(f"bl_coil{k}", 0.17 - k * 0.025, 0.014, 0.02 + k * 0.026, 24, 6, -0.25, -0.3) for k in range(3)]
    box.append(_pipe("bl_cable", (-0.05, -0.05, 0.9), (-0.15, -0.25, 0.05), 0.014, 6))
    return [(join("bl_legs_j", legs), steel("base_blp_m", 2, HULL), "legs"),
            (join("bl_mast_j", mast + heads), paint("base_blp_head_m", SAFETY, "a07a12"), "heads"),
            (join("bl_light_j", light), glow_warm("base_blp_light_m", "fff0c8", "e0b060"), "light_glow"),
            (join("bl_box_j", box), paint("base_blp_box_m", RUBBER, "202326"), "box")]


def base_build_post():
    """施工终端: a slim post on a bolted plate, a tilted amber screen with a
    keypad under it, a hazard band, a beacon on top, its cable into the deck."""
    body, hz, scr, lamp = [], [], [], []
    body += [d.bbox("bp_plate", (0.5, 0.5, 0.03), (0, 0, 0.015), width=0.01), d.bbox("bp_post", (0.18, 0.18, 1.2), (0, -0.04, 0.63), width=0.02),
             d.bbox("bp_head", (0.46, 0.3, 0.34), (0, 0.04, 1.2), (math.radians(-28), 0, 0), 0.025),
             d.bbox("bp_pad", (0.3, 0.14, 0.04), (0, 0.16, 0.96), (math.radians(-40), 0, 0), 0.01)]
    body += _bolts("bp_bolt", [(sx * 0.2, sy * 0.2, 0.035) for sx in (-1, 1) for sy in (-1, 1)], 0.02, 0.02, "z")
    body.append(_pipe("bp_cable", (0.0, -0.13, 0.4), (0.0, -0.28, 0.03), 0.02, 8))
    hz.append(d.bbox("bp_band", (0.19, 0.19, 0.12), (0, -0.04, 0.3)))
    scr.append(d.bbox("bp_scr", (0.38, 0.02, 0.24), (0, 0.19, 1.24), (math.radians(-28), 0, 0)))
    scr += [d.bbox(f"bp_key{k}", (0.05, 0.05, 0.015), (-0.1 + (k % 3) * 0.1, 0.18 + (k // 3) * 0.035, 0.985 + (k // 3) * 0.03), (math.radians(-40), 0, 0)) for k in range(6)]
    lamp += [d.cyl("bp_beacon", 0.06, 0.1, (0, 0.0, 1.47), vertices=16)]
    body.append(d.cyl("bp_beacon_base", 0.07, 0.03, (0, 0.0, 1.405), vertices=16))
    return [(join("bp_body_j", body), steel("base_bp_m", 3, HULL), "body"),
            (join("bp_hz_j", hz), steel("base_bp_hz_m", 2, SAFETY), "band"),
            (join("bp_scr_j", scr), glow_warm("base_bp_scr_m", "ffc24a", "c2861a"), "screen_glow"),
            (join("bp_lamp_j", lamp), glow_warm("base_bp_lamp_m", "ffb03a", "c27414"), "lamp_glow")]


def base_build_tape(length=1.0):
    """Hazard tape laid on the deck, 1 m long (stretched along x per site)."""
    tape = [d.bbox("bt_tape", (length, 0.14, 0.008), (0, 0, 0.004), width=0.001)]
    return [(join("bt_tape_j", tape), steel("base_bt_hz_m", 1, SAFETY), "tape")]


def base_cable_trunk(length=3.0):
    """A cable trunk run across the deck to a facility, lit along its lid when
    the link is live: a low ramped cover, grated lid, a cyan strip."""
    body = [d.bbox("ct_cover", (0.5, length, 0.08), (0, 0, 0.04), width=0.02)]
    body += [d.bbox(f"ct_ramp{s}", (0.12, length, 0.04), (s * 0.3, 0, 0.02), (0, s * math.radians(25), 0)) for s in (-1, 1)]
    grate = [d.bbox(f"ct_slot{k}", (0.32, 0.05, 0.01), (0, -length / 2 + 0.15 + k * 0.15, 0.085)) for k in range(int(length / 0.15) - 1)]
    strip = [d.bbox("ct_strip", (0.05, length - 0.1, 0.012), (0.19, 0, 0.088))]
    return [(join("ct_body_j", body), steel("base_ctk_m", 3, HULL), "body"),
            (join("ct_grate_j", grate), paint("base_ctk_slot_m", "1e2226"), "grate"),
            (join("ct_strip_j", strip), glow("base_ctk_glow_m", "6fd8e4"), "strip_glow")]


def base_relay_cabinet():
    """接入中继柜: a rack cabinet that links a facility to the hub — a vented
    door with a status screen and rows of port lights, a conduit up into the
    cable tray on top, a hazard plinth, the Rhodes logo on its side."""
    body, door, hz, leds, scr, conduit, logo = [], [], [], [], [], [], []
    body += [d.bbox("rc_body", (1.4, 0.8, 1.9), (0, 0, 1.03), width=0.02), d.bbox("rc_cap", (1.46, 0.86, 0.06), (0, 0, 2.0))]
    hz.append(d.bbox("rc_plinth", (1.44, 0.84, 0.1), (0, 0, 0.05)))
    door.append(d.bbox("rc_door", (1.26, 0.03, 1.72), (0, 0.41, 1.02), width=0.01))
    door += [d.bbox(f"rc_vent{k}", (0.5, 0.02, 0.025), (-0.3, 0.43, 0.4 + k * 0.06)) for k in range(8)]
    door += [d.bbox("rc_handle", (0.04, 0.04, 0.3), (0.55, 0.45, 1.0)), d.bbox("rc_hinge0", (0.04, 0.04, 0.14), (-0.62, 0.43, 1.6)),
             d.bbox("rc_hinge1", (0.04, 0.04, 0.14), (-0.62, 0.43, 0.45))]
    scr.append(d.bbox("rc_scr", (0.5, 0.02, 0.3), (0.25, 0.43, 1.55)))
    for r in range(6):
        for c in range(8):
            leds.append(d.bbox(f"rc_led{r}{c}", (0.035, 0.015, 0.02), (-0.08 + c * 0.075, 0.43, 0.95 + r * 0.07)))
    conduit += [_pipe("rc_conduit0", (-0.45, -0.25, 2.03), (-0.45, -0.25, 2.6), 0.05, 12), _pipe("rc_conduit1", (-0.2, -0.25, 2.03), (-0.2, -0.25, 2.6), 0.04, 12),
                d.bbox("rc_tray", (1.0, 0.3, 0.06), (-0.3, -0.25, 2.62))]
    logo.append(d.bbox("rc_logo", (0.32, 0.012, 0.32), (-0.35, 0.432, 1.55)))
    return [(join("rc_body_j", body + door), steel("base_rlc_m", 5, PANEL), "box"),
            (join("rc_hz_j", hz), steel("base_rlc_hz_m", 2, SAFETY), "plinth"),
            (join("rc_leds_j", leds), glow("base_rlc_led_m", "6fd8e4"), "led_glow"),
            (join("rc_scr_j", scr), glow("base_rlc_scr_m"), "screen_glow"),
            (join("rc_conduit_j", conduit), paint("base_rlc_conduit_m", "2a2f33", "1a1e22"), "conduit"),
            (join("rc_logo_j", logo), logo_decal("base_rlc_logo_m", PANEL), "logo")]


def base_build_console(width=6.4):
    """基建总控台: a three-seat arc desk in engineering yellow trim — angled
    screen banks, keyboards, a central projector with the ship's plan floating
    over it in cyan (six facility nodes round the hull), chairs, a hazard kick
    rail, cable bundles off the back towards the trunks."""
    body, trim, hz, scr, holo, nodes, dark, chairs = [], [], [], [], [], [], [], []
    for k in range(5):
        a = math.radians(-36 + k * 18)
        x, y = 4.6 * math.sin(a), 4.6 * (1 - math.cos(a)) - 1.0
        body.append(d.bbox(f"bk_desk{k}", (1.32, 0.95, 0.82), (x, y + 0.2, 0.41), (0, 0, -a), 0.03))
        body.append(d.bbox(f"bk_top{k}", (1.36, 1.05, 0.05), (x, y + 0.18, 0.85), (0, 0, -a), 0.01))
        trim.append(d.bbox(f"bk_trim{k}", (1.34, 0.04, 0.06), (x - 0.48 * math.sin(a), y + 0.7 - (1 - math.cos(a)) * 0.0, 0.78), (0, 0, -a)))
        hz.append(d.bbox(f"bk_kick{k}", (1.3, 0.03, 0.12), (x - 0.5 * math.sin(a), y + 0.69, 0.07), (0, 0, -a)))
        if k != 2:
            body.append(d.bbox(f"bk_bank{k}", (1.2, 0.12, 0.62), (x + 0.28 * math.sin(a), y - 0.1, 1.2), (math.radians(14), 0, -a), 0.02))
            scr.append(d.bbox(f"bk_scr{k}", (1.06, 0.02, 0.5), (x + 0.26 * math.sin(a), y - 0.03, 1.21), (math.radians(14), 0, -a)))
            scr.append(d.bbox(f"bk_kb{k}", (0.6, 0.22, 0.02), (x - 0.12 * math.sin(a), y + 0.45, 0.885), (0, 0, -a)))
    # The projector and the plan over it.
    body += [d.cyl("bk_proj", 0.5, 0.3, (0, -0.55, 1.0), vertices=32), d.cyl("bk_proj_ring", 0.58, 0.06, (0, -0.55, 1.18), vertices=32)]
    holo.append(_torus("bk_proj_glow", 0.42, 0.03, 1.22, 40, 6, 0.0, -0.55))
    hull = [(-1.3, 0.0), (-0.9, 0.42), (0.9, 0.42), (1.45, 0.12), (1.45, -0.12), (0.9, -0.42), (-0.9, -0.42)]
    for k in range(len(hull)):
        a, b = hull[k], hull[(k + 1) % len(hull)]
        holo.append(_pipe(f"bk_hull{k}", (a[0], -0.55 + a[1], 2.0), (b[0], -0.55 + b[1], 2.0), 0.018, 6))
    holo += [_pipe("bk_deck0", (-0.9, -0.55, 2.0), (1.2, -0.55, 2.0), 0.01, 6), _pipe("bk_deck1", (0.2, -0.97, 2.0), (0.2, -0.13, 2.0), 0.01, 6)]
    for k, (x, y) in enumerate(((-0.8, 0.2), (-0.8, -0.2), (0.0, 0.28), (0.0, -0.28), (0.8, 0.2), (0.8, -0.2))):
        nodes.append(d.bbox(f"bk_node{k}", (0.12, 0.12, 0.12), (x, -0.55 + y, 2.0)))
    # Thin light lines from the projector up to the plan (kit glow parts are
    # opaque, so no beam volume).
    holo += [_pipe(f"bk_ray{k}", (0.4 * math.cos(k * math.pi / 3), -0.55 + 0.4 * math.sin(k * math.pi / 3), 1.24),
                   (1.1 * math.cos(k * math.pi / 3), -0.55 + 0.35 * math.sin(k * math.pi / 3), 1.98), 0.008, 4) for k in range(6)]
    # Cable bundles off the back.
    for k in range(6):
        x = -1.5 + k * 0.6
        dark.append(_pipe(f"bk_cab{k}", (x, -0.4, 0.3), (x * 1.2, -1.6, 0.04), 0.045, 8))
    for k in (0, 1, 3, 4):
        a = math.radians(-36 + k * 18)
        x, y = 4.6 * math.sin(a), 4.6 * (1 - math.cos(a)) - 1.0
        cx, cy = x - 0.95 * math.sin(a), y + 1.25
        chairs += [d.cyl(f"bk_ch_base{k}", 0.28, 0.05, (cx, cy, 0.03), vertices=10), d.cyl(f"bk_ch_post{k}", 0.04, 0.4, (cx, cy, 0.25), vertices=8),
                   d.bbox(f"bk_ch_seat{k}", (0.5, 0.5, 0.1), (cx, cy, 0.5), (0, 0, -a), 0.04),
                   d.bbox(f"bk_ch_back{k}", (0.48, 0.08, 0.55), (cx + 0.22 * math.sin(a), cy + 0.24, 0.82), (math.radians(-8), 0, -a), 0.04)]
    return [(join("bk_body_j", body), steel("base_hubc_m", 6, HULL), "box"),
            (join("bk_trim_j", trim), paint("base_hubc_trim_m", SAFETY, "a07a12"), "trim"),
            (join("bk_hz_j", hz), steel("base_hubc_hz_m", 2, SAFETY), "kick"),
            (join("bk_scr_j", scr), glow("base_hubc_scr_m"), "screen_glow"),
            (join("bk_holo_j", holo), glow_warm("base_hubc_holo_m", "8fe6f6", "3fa8b8"), "holo_glow"),
            (join("bk_nodes_j", nodes), glow_warm("base_hubc_node_m", "ffd25a", "c29a1a"), "node_glow"),
            (join("bk_dark_j", dark), paint("base_hubc_cable_m", "2a2f33", "1a1e22"), "cables"),
            (join("bk_chairs_j", chairs), paint("base_hubc_chair_m", "3a4146", "262b2f"), "chairs")]


def base_drone_pad(size=4.6):
    """无人机停机坪: a raised square pad, grated edge, a lit landing ring and
    corner lights, hazard chevrons on the corners, a charging pylon with its
    arm folded over the pad, its cable into the deck."""
    body, grate, hz, ring, lamps, pylon = [], [], [], [], [], []
    body.append(d.bbox("dp_pad", (size, size, 0.1), (0, 0, 0.05), width=0.03))
    body.append(d.bbox("dp_inner", (size - 0.6, size - 0.6, 0.02), (0, 0, 0.11)))
    grate += [d.bbox(f"dp_edge{k}", (size - 0.1, 0.24, 0.015), (0, s * (size / 2 - 0.17), 0.105)) for k, s in enumerate((-1, 1))]
    grate += [d.bbox(f"dp_edge_s{k}", (0.24, size - 0.5, 0.015), (s * (size / 2 - 0.17), 0, 0.105)) for k, s in enumerate((-1, 1))]
    for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        hz.append(d.bbox(f"dp_chev{k}", (0.7, 0.7, 0.012), (sx * (size / 2 - 0.55), sy * (size / 2 - 0.55), 0.125), (0, 0, math.radians(45))))
        lamps.append(d.cyl(f"dp_lamp{k}", 0.07, 0.05, (sx * (size / 2 - 0.15), sy * (size / 2 - 0.15), 0.13), vertices=12))
    ring.append(_torus("dp_ring", 1.3, 0.04, 0.125, 64, 6))
    ring += [d.bbox(f"dp_tick{k}", (0.32, 0.06, 0.012), (1.55 * math.cos(k * math.pi / 4), 1.55 * math.sin(k * math.pi / 4), 0.125), (0, 0, k * math.pi / 4)) for k in range(8)]
    pylon += [d.bbox("dp_pylon", (0.3, 0.3, 1.6), (size / 2 - 0.3, -size / 2 + 0.3, 0.9), width=0.03),
              d.bbox("dp_arm", (1.2, 0.12, 0.1), (size / 2 - 0.9, -size / 2 + 0.3, 1.66), (0, math.radians(-12), 0), 0.02),
              d.cyl("dp_plug", 0.06, 0.2, (size / 2 - 1.5, -size / 2 + 0.3, 1.5), vertices=10)]
    pylon.append(_pipe("dp_cable", (size / 2 - 0.3, -size / 2 + 0.1, 0.4), (size / 2 - 0.3, -size / 2 - 0.2, 0.02), 0.03, 8))
    return [(join("dp_body_j", body + pylon), steel("base_dp_m", 4, HULL), "box"),
            (join("dp_grate_j", grate), steel("base_dp_grate_m", 3, PANEL), "grate"),
            (join("dp_hz_j", hz), steel("base_dp_hz_m", 2, SAFETY), "chevrons"),
            (join("dp_ring_j", ring), glow("base_dp_ring_m", "6fd8e4"), "ring_glow"),
            (join("dp_lamp_j", lamps), glow_warm("base_dp_lamp_m", "ffb03a", "c27414"), "lamp_glow")]


def base_order_screen(width=2.8):
    """订单调度屏: a wall screen on two brackets over the order board — three
    lit order bands and a refresh glyph, a frame with a yellow header."""
    frame, head, scr, bands = [], [], [], []
    frame += [d.bbox("os_frame", (width, 0.1, 1.5), (0, 0, 2.2), width=0.02)]
    frame += [d.bbox(f"os_br{s}", (0.1, 0.3, 0.1), (s * (width / 2 - 0.3), -0.15, 2.9)) for s in (-1, 1)]
    head.append(d.bbox("os_head", (width, 0.12, 0.16), (0, 0.01, 2.98)))
    scr.append(d.bbox("os_scr", (width - 0.16, 0.02, 1.3), (0, 0.06, 2.18)))
    bands += [d.bbox(f"os_band{k}", (width - 0.5, 0.012, 0.26), (-0.1, 0.075, 2.6 - k * 0.38)) for k in range(3)]
    bands.append(_torus("os_refresh", 0.11, 0.02, 0.0, 24, 6, width / 2 - 0.25, 0.08, (math.radians(90), 0, 0)))
    bands[-1].location.z = 2.6
    return [(join("os_frame_j", frame), steel("base_ors_m", 3, HULL), "frame"),
            (join("os_head_j", head), paint("base_ors_head_m", SAFETY, "a07a12"), "head"),
            (join("os_scr_j", scr), glow("base_ors2_scr_m", "2e7f8a"), "screen_glow"),
            (join("os_band_j", bands), glow("base_ors_band_m", "bff2f8"), "band_glow")]


def base_pack_rig():
    """背包改装架: a tactical pack hung on a test frame — the frame on a low
    tool bench, the pack's main bag, side pouches, straps and buckles, a
    folding lamp arm over it, tools and a roll of webbing on the bench."""
    frame, bench, bag, straps, metal, lamp = [], [], [], [], [], []
    bench += [d.bbox("pr_bench", (1.8, 0.8, 0.7), (0, 0, 0.35), width=0.03), d.bbox("pr_top", (1.86, 0.86, 0.05), (0, 0, 0.72))]
    frame += [d.bbox(f"pr_post{s}", (0.06, 0.06, 1.3), (s * 0.45, -0.25, 1.4)) for s in (-1, 1)]
    frame += [d.bbox("pr_cross", (1.0, 0.06, 0.06), (0, -0.25, 2.02)), d.bbox("pr_hook", (0.06, 0.2, 0.06), (0, -0.15, 1.96))]
    bag += [d.bbox("pr_bag", (0.62, 0.36, 0.82), (0, -0.05, 1.42), width=0.08), d.bbox("pr_lid", (0.6, 0.38, 0.14), (0, -0.04, 1.86), (math.radians(6), 0, 0), 0.05),
            d.bbox("pr_front", (0.44, 0.12, 0.36), (0, 0.17, 1.28), width=0.05)]
    bag += [d.bbox(f"pr_side{s}", (0.14, 0.26, 0.42), (s * 0.38, -0.04, 1.3), width=0.04) for s in (-1, 1)]
    straps += [d.bbox(f"pr_strap{s}", (0.06, 0.02, 0.8), (s * 0.16, 0.235, 1.42)) for s in (-1, 1)]
    straps += [d.bbox(f"pr_web{k}", (0.64, 0.02, 0.04), (0, 0.24, 1.15 + k * 0.42)) for k in range(2)]
    straps.append(d.cyl("pr_roll", 0.09, 0.22, (0.6, 0.15, 0.82), (0, math.radians(90), 0), 16))
    metal += [d.bbox(f"pr_buckle{s}", (0.08, 0.03, 0.05), (s * 0.16, 0.25, 1.2)) for s in (-1, 1)]
    metal += [d.bbox("pr_tool0", (0.3, 0.05, 0.02), (-0.5, 0.2, 0.755), (0, 0, 0.3)), d.bbox("pr_tool1", (0.22, 0.04, 0.03), (-0.2, 0.25, 0.755), (0, 0, -0.4)),
              d.cyl("pr_awl", 0.015, 0.2, (0.25, 0.25, 0.76), (0, math.radians(90), 0.6), 8)]
    lamp += [d.bbox("pr_arm0", (0.04, 0.04, 0.5), (0.8, -0.3, 0.98)), d.bbox("pr_arm1", (0.6, 0.04, 0.04), (0.55, -0.3, 1.24), (0, math.radians(-20), 0)),
             d.cyl("pr_shade", 0.1, 0.12, (0.28, -0.2, 1.3), (math.radians(30), 0, 0), 16)]
    glow_part = [d.cyl("pr_bulb", 0.07, 0.02, (0.28, -0.17, 1.24), (math.radians(30), 0, 0), 16)]
    return [(join("pr_bench_j", bench + frame + lamp), steel("base_pr_m", 4, HULL), "box"),
            (join("pr_bag_j", bag), paint("base_pr_bl_m", "4a5a4a", "34402f"), "bag"),
            (join("pr_strap_j", straps), paint("base_pr_strap_m", "2a2f33", "1a1e22"), "straps"),
            (join("pr_metal_j", metal), paint("base_pr_metal_m", SAFETY, "a07a12"), "metal"),
            (join("pr_glow_j", glow_part), glow_warm("base_pr_glow_m", "fff0c8", "e0b060"), "lamp_glow")]


def base_secure_safe():
    """安全袋保险柜: a heavy armoured safe on a hazard plinth — thick walls with
    bolted corners, a door with a spoked wheel and heavy hinges, a lit keypad
    and status strip, the Rhodes logo on the door."""
    body, door, hz, glows, logo = [], [], [], [], []
    body.append(d.bbox("ss_body", (1.5, 1.1, 1.35), (0, 0, 0.78), width=0.06))
    hz.append(d.bbox("ss_plinth", (1.56, 1.16, 0.1), (0, 0, 0.05)))
    body += [d.bbox(f"ss_corner{k}", (0.18, 0.18, 1.37), (sx * 0.68, sy * 0.48, 0.78), width=0.03)
             for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    body += _bolts("ss_bolt", [(sx * 0.68, 0.575, z) for sx in (-1, 1) for z in (0.3, 0.75, 1.2)], 0.03, 0.02)
    door += [d.bbox("ss_door", (1.1, 0.06, 1.12), (0, 0.57, 0.78), width=0.03)]
    door += [d.bbox(f"ss_hinge{k}", (0.1, 0.1, 0.2), (-0.6, 0.6, z)) for k, z in enumerate((0.4, 1.15))]
    door += [_torus("ss_wheel", 0.2, 0.025, 0.0, 32, 8, 0.12, 0.65, (math.radians(90), 0, 0)), d.cyl("ss_hub", 0.06, 0.08, (0.12, 0.64, 0.0), (math.radians(90), 0, 0), 16)]
    door += [d.bbox(f"ss_spoke{k}", (0.4, 0.03, 0.03), (0.12, 0.65, 0.0), (0, k * math.pi / 3, 0)) for k in range(3)]
    for part in door[-5:]:
        part.location.z = 0.72
    glows += [d.bbox("ss_keypad", (0.22, 0.02, 0.3), (0.42, 0.61, 0.95)), d.bbox("ss_strip", (0.9, 0.02, 0.03), (0, 0.61, 1.28))]
    logo.append(d.bbox("ss_logo", (0.3, 0.012, 0.3), (-0.3, 0.605, 1.05)))
    return [(join("ss_body_j", body + door), steel("base_sfe_m", 6, HULL), "box"),
            (join("ss_hz_j", hz), steel("base_sfe_hz_m", 2, SAFETY), "plinth"),
            (join("ss_glow_j", glows), glow("base_sfe_glow_m", "6fd8e4"), "keypad_glow"),
            (join("ss_logo_j", logo), logo_decal("base_sfe_logo_m", HULL), "logo")]


def base_closure_fridge(width=1.7):
    """可露希尔的特供冷柜: a double glass-fronted fridge, lit shelves of vials
    in their colours, a pink neon strip along the top in her store's colour,
    a frosted kick plate and the compressor grille."""
    body, glass, shelves, vials, neon, grille = [], [], [], [], [], []
    body += [d.bbox("cf_body", (width, 0.9, 2.0), (0, 0, 1.0), width=0.03), d.bbox("cf_mull", (0.06, 0.04, 1.6), (0, 0.46, 1.08))]
    glass += [d.bbox(f"cf_glass{s}", (width / 2 - 0.1, 0.02, 1.56), (s * width / 4, 0.46, 1.08)) for s in (-1, 1)]
    body += [d.bbox(f"cf_handle{s}", (0.03, 0.05, 0.5), (s * 0.08, 0.5, 1.1)) for s in (-1, 1)]
    colours = ["ff7a24", "6fd8e4", "ff5fa2", "8fc31f"]
    for r in range(4):
        z = 0.5 + r * 0.38
        shelves.append(d.bbox(f"cf_shelf{r}", (width - 0.1, 0.7, 0.02), (0, 0.05, z)))
        for c in range(8):
            vials.append(d.cyl(f"cf_vial{r}{c}", 0.04, 0.16, (-width / 2 + 0.16 + c * (width - 0.3) / 7, 0.2, z + 0.09), vertices=8))
    neon.append(d.bbox("cf_neon", (width - 0.1, 0.04, 0.06), (0, 0.45, 1.95)))
    grille += [d.bbox(f"cf_gr{k}", (width - 0.2, 0.02, 0.02), (0, 0.46, 0.08 + k * 0.05)) for k in range(4)]
    return [(join("cf_body_j", body), steel("base_cf_m", 4, WHITE), "box"),
            (join("cf_glass_j", glass + shelves), glow("base_cf_glass_m", "dff4ff"), "glass_glow"),
            (join("cf_vials_j", vials), glow_warm("base_cf_vial_m", "ffa860", "c2601a"), "vial_glow"),
            (join("cf_neon_j", neon), glow_warm("base_cf_neon_m", "ff7ab8", "d23e86"), "neon_glow"),
            (join("cf_grille_j", grille), paint("base_cf_grille_m", "2a2f33"), "grille")]


def base_display_case_lock():
    """The same glass case locked down for 应急强心针: a dark vault pad, the
    injector in a cradle, a lock bar across with a red lock light."""
    parts = _display_case("dcl", 3.0, False)
    bar = [d.bbox("dcl_bar", (3.0, 0.12, 0.08), (0, 0, 1.45)), d.bbox("dcl_lock", (0.22, 0.16, 0.2), (0, 0.06, 1.45), width=0.02),
           d.bbox("dcl_cradle", (0.7, 0.24, 0.08), (0, 0, 0.9)), d.cyl("dcl_injector", 0.05, 0.5, (0, 0, 0.98), (0, math.radians(90), 0), 12)]
    light = [d.bbox("dcl_light", (0.08, 0.02, 0.06), (0, 0.15, 1.48))]
    return parts + [(join("dcl_bar_j", bar), steel("base_dcl_bar_m", 3, SAFETY), "lock"),
                    (join("dcl_light_j", light), glow_warm("base_dcl_light_m", "ff4a4a", "b01e1e"), "lock_glow")]


WORKS_BUILDERS = [base_build_barrier, base_build_cone, base_build_crate_tarp, base_build_scaffold, base_build_lamp, base_build_post,
                  base_build_tape, base_cable_trunk, base_relay_cabinet, base_build_console, base_drone_pad, base_order_screen,
                  base_pack_rig, base_secure_safe, base_closure_fridge, base_display_case_lock]
ROOM_BUILDERS += WORKS_BUILDERS


# Second deck (势力特供策划案_v0_2 §三–§五, 用户 2026-10-22): 农业部 in RimWorld's
# 11×11 sun-lamp room — one sun lamp, 24 1×4 hydroponics basins (a tile 1.5 m, so a basin
# is 6 × 1.5 m) — and 食堂's galley, counter and tables. The basins and
# crops are shown at their real size (BaseMap.UNSCALED), so the swirl's grid
# holds; crops stand on the basin top (CROP_Y) and BaseMap squashes them
# while they grow.
LEAF = "4f8a3a"
SOIL = "3a2c22"
WATER = "2c5a66"
CROP_Y = 0.72


def base_hydro_basin():
    """水培槽: a long white tray on steel legs, the nutrient bed dark inside
    its lip, a feed pipe along one side with drip lines across, the pump box
    and its status lamp at one end."""
    body, frame, bed, pipe, lamp = [], [], [], [], []
    body += [d.bbox("hb_tray", (5.8, 1.3, 0.34), (0, 0, 0.53)), d.bbox("hb_lip", (5.9, 1.4, 0.05), (0, 0, 0.71))]
    bed.append(d.bbox("hb_bed", (5.6, 1.1, 0.04), (0, 0, 0.7)))
    for x in (-2.6, -0.9, 0.9, 2.6):
        for y in (-0.55, 0.55):
            frame.append(d.bbox(f"hb_leg{x}{y}", (0.1, 0.1, 0.38), (x, y, 0.19)))
    frame.append(d.bbox("hb_rail", (5.6, 0.08, 0.06), (0, -0.55, 0.12)))
    frame.append(d.bbox("hb_rail2", (5.6, 0.08, 0.06), (0, 0.55, 0.12)))
    pipe.append(d.cyl("hb_feed", 0.06, 5.7, (0, -0.68, 0.66), (0, math.radians(90), 0), 10))
    for k in range(9):
        pipe.append(d.bbox(f"hb_drip{k}", (0.03, 1.1, 0.02), (-2.5 + k * 0.625, 0, 0.75)))
    body.append(d.bbox("hb_pump", (0.36, 0.5, 0.36), (2.98, -0.3, 0.5)))
    lamp.append(d.bbox("hb_lamp", (0.08, 0.2, 0.06), (3.17, -0.3, 0.6)))
    return [(join("hb_body_j", body), steel("base_hb_m", 4, WHITE), "tray"),
            (join("hb_frame_j", frame), steel("base_hb_frame_m", 3, HULL), "frame"),
            (join("hb_bed_j", bed), paint("base_hb_bed_m", WATER, "1e3e48"), "bed"),
            (join("hb_pipe_j", pipe), paint("base_hb_pipe_m", BLUE, "2c5880"), "pipe"),
            (join("hb_lamp_j", lamp), glow("base_hb_lamp_m", "8ff0a0"), "lamp_glow")]


def base_sun_lamp():
    """太阳灯: RimWorld's sun lamp — a steel column on a ballast foot, four
    arms holding a wide hood, its ring of lamps lit all round the rim."""
    post = [d.cyl("sl_foot", 0.9, 0.3, (0, 0, 0.15), vertices=20), d.cyl("sl_col", 0.18, 3.0, (0, 0, 1.8), vertices=14)]
    hood = [d.cyl("sl_hood", 1.3, 0.22, (0, 0, 3.4), vertices=24), d.cyl("sl_cap", 0.6, 0.3, (0, 0, 3.6), vertices=20)]
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        post.append(d.bbox(f"sl_arm{k}", (1.2, 0.1, 0.1), (0.6 * math.cos(a), 0.6 * math.sin(a), 3.3), (0, 0, a)))
    ring = [d.cyl("sl_ring", 1.36, 0.08, (0, 0, 3.27), vertices=24)]
    bulbs = [d.cyl(f"sl_b{k}", 0.12, 0.1, (1.05 * math.cos(k * math.tau / 12), 1.05 * math.sin(k * math.tau / 12), 3.5), vertices=10) for k in range(12)]
    hz = [d.bbox("sl_hz", (0.4, 0.04, 0.2), (0, 0.19, 0.8))]
    return [(join("sl_post_j", post), steel("base_sl_m", 3, PANEL), "post"),
            (join("sl_hood_j", hood), steel("base_sl_hood_m", 5, HULL), "hood"),
            (join("sl_hz_j", hz), paint("base_sl_hz_m", SAFETY), "band"),
            (join("sl_light_j", ring + bulbs), glow_warm("base_sl_glow_m", "fff1b0", "f0c860"), "light_glow")]


def base_water_tank():
    """营养液罐: a tall tank with banded hoops, a level gauge lit down its front,
    a valve and pipe off the side."""
    tank = [d.cyl("wt_body", 1.1, 2.6, (0, 0, 1.4), vertices=24), d.cyl("wt_dome", 1.0, 0.2, (0, 0, 2.8), vertices=24)]
    hoops = [d.cyl(f"wt_hoop{k}", 1.14, 0.1, (0, 0, 0.5 + k * 0.8), vertices=24) for k in range(3)]
    foot = [d.bbox("wt_foot", (2.4, 2.0, 0.12), (0, 0, 0.06))]
    gauge = [d.bbox("wt_gauge", (0.12, 0.05, 1.6), (0, 1.11, 1.4))]
    pipe = [d.cyl("wt_pipe", 0.09, 1.0, (1.4, 0, 0.6), (0, math.radians(90), 0), 10), d.cyl("wt_valve", 0.16, 0.12, (1.2, 0, 0.6), (0, math.radians(90), 0), 12)]
    return [(join("wt_body_j", tank), steel("base_wt_m", 6, WHITE), "tank"),
            (join("wt_hoop_j", hoops + foot), steel("base_wt_hoop_m", 2, HULL), "hoop"),
            (join("wt_pipe_j", pipe), paint("base_wt_pipe_m", BLUE, "2c5880"), "pipe"),
            (join("wt_gauge_j", gauge), glow("base_wt_glow_m", "6ff0c0"), "gauge_glow")]


def base_seed_cabinet():
    """种子柜: a white cabinet of small drawers, each with a coloured tag, a
    lit humidity screen on top."""
    body = [d.bbox("sc_body", (2.4, 0.8, 2.2), (0, 0, 1.1))]
    drawers, tags = [], []
    for r in range(5):
        for c in range(6):
            x, z = -0.98 + c * 0.39, 0.35 + r * 0.38
            drawers.append(d.bbox(f"sc_d{r}{c}", (0.34, 0.04, 0.32), (x, 0.41, z)))
            tags.append(d.bbox(f"sc_t{r}{c}", (0.14, 0.02, 0.06), (x, 0.44, z + 0.08)))
    scr = [d.bbox("sc_scr", (0.8, 0.05, 0.3), (0, 0.38, 2.35))]
    return [(join("sc_body_j", body + drawers), steel("base_seed_m", 5, WHITE), "body"),
            (join("sc_tag_j", tags), paint("base_seed_tag_m", LEAF, "2f5a22"), "tags"),
            (join("sc_scr_j", scr), glow("base_seed_glow_m", "8ff0a0"), "screen_glow")]


def base_potting_bench():
    """育苗台: a steel bench with seedling trays and pots, a tool rail behind."""
    bench = [d.bbox("pb_top", (3.6, 1.0, 0.08), (0, 0, 0.92)), d.bbox("pb_shelf", (3.4, 0.9, 0.05), (0, 0, 0.3))]
    bench += [d.bbox(f"pb_leg{x}{y}", (0.08, 0.08, 0.9), (x, y, 0.45)) for x in (-1.7, 1.7) for y in (-0.42, 0.42)]
    trays = [d.bbox(f"pb_tray{k}", (0.9, 0.6, 0.1), (-1.2 + k * 1.2, 0.1, 1.01)) for k in range(3)]
    sprouts = [kit.rock(f"pb_sp{k}{j}", 0.07, (-1.5 + k * 1.2 + j * 0.15, 0.1 + (j % 2) * 0.15, 1.1), (1, 1, 1.4), 1) for k in range(3) for j in range(5)]
    rail = [d.bbox("pb_rail", (3.4, 0.06, 0.06), (0, -0.48, 1.6))]
    rail += [d.bbox(f"pb_tool{k}", (0.05, 0.04, 0.4), (-1.4 + k * 0.7, -0.46, 1.38)) for k in range(5)]
    return [(join("pb_bench_j", bench + rail), steel("base_pb_m", 3, PANEL), "bench"),
            (join("pb_tray_j", trays), paint("base_pb_tray_m", SOIL, "241a12"), "trays"),
            (join("pb_sprout_j", sprouts), paint("base_pb_sprout_m", "7fbf5a", "4f8a3a"), "sprouts")]


def base_compost_bin():
    """堆肥箱: a green bin with a hinged lid and a vent."""
    body = [d.bbox("cb_body", (1.6, 1.2, 0.9), (0, 0, 0.45)), d.bbox("cb_lid", (1.7, 1.3, 0.1), (0, 0, 0.95))]
    vent = [d.bbox(f"cb_v{k}", (0.6, 0.02, 0.04), (0, 0.61, 0.5 + k * 0.1)) for k in range(3)]
    return [(join("cb_body_j", body), steel("base_cb_m", 2, "4f7a3a"), "bin"),
            (join("cb_vent_j", vent), steel("base_cb_vent_m", 3, HULL), "vent")]


def _plants(prefix, colour, dark, count_x, count_y, radius, height, squash=(1.0, 1.0, 1.6)):
    out = []
    for i in range(count_x):
        for j in range(count_y):
            x = -2.55 + (i + 0.5) * 5.1 / count_x
            y = -0.4 + (j + 0.5) * 0.8 / count_y
            out.append(kit.rock(f"{prefix}{i}_{j}", radius, (x, y, height * 0.5), squash, 1))
    return out


def base_crop_wheat():
    """舰载麦: dense rows of golden stalks with heavy heads."""
    stalks = []
    for i in range(22):
        for j in range(3):
            x, y = -2.6 + i * 0.25, -0.38 + j * 0.38
            stalks.append(d.bbox(f"cw_s{i}{j}", (0.04, 0.04, 0.7), (x, y, 0.35)))
    heads = _plants("cw_h", "d8c060", "a08a30", 22, 3, 0.07, 1.48, (0.8, 0.8, 2.2))
    return [(join("cw_stalk_j", stalks), paint("base_cw_m", "9aa040", "6a7028"), "stalks"),
            (join("cw_head_j", heads), paint("base_cw_head_m", "d8c060", "a08a30"), "heads")]


def base_crop_tuber():
    """块茎薯: low broad-leaved bushes over the bed."""
    leaves = _plants("ct_l", LEAF, "2f5a22", 9, 2, 0.32, 0.7, (1.2, 1.0, 0.7))
    return [(join("ct_leaf_j", leaves), paint("base_ct_m", "5f8a3a", "3a5a22"), "leaves")]


def base_crop_bean():
    """温室豆: vines up a little trellis, pods hanging."""
    trellis = [d.bbox(f"cbn_t{k}", (0.04, 0.04, 1.1), (-2.6 + k * 0.65, 0, 0.55)) for k in range(9)]
    trellis.append(d.bbox("cbn_top", (5.3, 0.04, 0.04), (0, 0, 1.1)))
    vines = _plants("cbn_v", "6faf4a", "3f7a2a", 12, 2, 0.2, 1.4, (0.9, 0.9, 2.4))
    pods = _plants("cbn_p", "a8d070", "6f9a40", 16, 2, 0.06, 1.2, (0.6, 0.6, 2.0))
    return [(join("cbn_tr_j", trellis), paint("base_cbn_tr_m", "8a6a40", "5a4228"), "trellis"),
            (join("cbn_v_j", vines), paint("base_cbn_m", "6faf4a", "3f7a2a"), "vines"),
            (join("cbn_p_j", pods), paint("base_cbn_pod_m", "c8e090", "8aa858"), "pods")]


def _shine(prefix, leaf, dark, bulb, bulb_dark, ripe, tall):
    stems = _plants(prefix + "s", leaf, dark, 8, 2, 0.24, tall, (0.8, 0.8, 2.6))
    out = [(join(prefix + "stem_j", stems), paint(f"base_{prefix}m", leaf, dark), "leaves")]
    pods = []
    for i in range(8):
        for j in range(2):
            x = -2.55 + (i + 0.5) * 5.1 / 8
            y = -0.4 + (j + 0.5) * 0.4
            pods.append(d.cyl(f"{prefix}b{i}{j}", 0.13, 0.22, (x, y, tall * 1.1), vertices=10))
    if ripe:
        out.append((join(prefix + "bulb_j", pods), glow_warm(f"base_{prefix}glow_m", bulb, bulb_dark), "bulb_glow"))
    else:
        out.append((join(prefix + "bulb_j", pods), paint(f"base_{prefix}bud_m", _darker(bulb, 0.6), _darker(bulb_dark, 0.6)), "buds"))
    return out


def base_crop_shine():
    """闪耀作物 growing: pale blue-green stems with closed buds."""
    return _shine("cs", "5fa8a0", "3a6a66", "8ff0ff", "3fb8d0", False, 1.0)


def base_crop_shine_ripe():
    """闪耀作物 ripe: the buds open and glow (the RimWorld nod)."""
    return _shine("csr", "5fa8a0", "3a6a66", "8ff0ff", "3fb8d0", True, 1.0)


def base_crop_shine_var():
    """闪耀作物·变种 growing: taller violet stems."""
    return _shine("cv", "8a6aa8", "5a4270", "e0b0ff", "a060e0", False, 1.3)


def base_crop_shine_var_ripe():
    return _shine("cvr", "8a6aa8", "5a4270", "e0b0ff", "a060e0", True, 1.3)


def base_kitchen_range():
    """灶台: a stainless cooking line — four burners lit orange, pots and a
    wok on them, the extraction hood above on two posts, a splash back."""
    body = [d.bbox("kr_body", (6.0, 1.2, 0.9), (0, 0, 0.45)), d.bbox("kr_top", (6.1, 1.3, 0.06), (0, 0, 0.93)),
            d.bbox("kr_back", (6.0, 0.1, 1.2), (0, -0.6, 1.5))]
    body += [d.bbox(f"kr_door{k}", (1.3, 0.04, 0.6), (-2.2 + k * 1.47, 0.61, 0.45)) for k in range(4)]
    hood = [d.bbox("kr_hood", (6.2, 1.1, 0.5), (0, -0.1, 2.7)), d.bbox("kr_duct", (1.0, 0.8, 0.9), (0, -0.2, 3.3))]
    hood += [d.bbox(f"kr_post{s}", (0.1, 0.1, 1.8), (s * 3.0, -0.55, 1.8)) for s in (-1, 1)]
    burners = [d.cyl(f"kr_b{k}", 0.24, 0.03, (-2.2 + k * 1.47, 0.1, 0.97), vertices=16) for k in range(4)]
    pots = [d.cyl("kr_pot0", 0.3, 0.35, (-2.2, 0.1, 1.15), vertices=16), d.cyl("kr_pot1", 0.26, 0.28, (-0.73, 0.1, 1.12), vertices=16),
            d.cyl("kr_wok", 0.38, 0.1, (0.73, 0.1, 1.04), vertices=18), d.cyl("kr_pot2", 0.3, 0.4, (2.2, 0.1, 1.18), vertices=16)]
    lamp = [d.bbox("kr_lamp", (5.8, 0.05, 0.05), (0, 0.42, 2.44))]
    return [(join("kr_body_j", body + hood), steel("base_kr_m", 6, "c8ccd0"), "steel"),
            (join("kr_pot_j", pots), steel("base_kr_pot_m", 3, HULL), "pots"),
            (join("kr_burn_j", burners), glow_warm("base_kr_glow_m", "ff8a3a", "c04a1a"), "burner_glow"),
            (join("kr_lamp_j", lamp), glow_warm("base_kr_lamp_m", "fff1d0", "e8c890"), "lamp_glow")]


def base_serving_counter():
    """出餐口: a long counter with food wells under a sneeze guard, the dishes
    in their colours, warm heat lamps along the guard, trays stacked at one end."""
    body = [d.bbox("scn_body", (10.0, 1.1, 1.0), (0, 0, 0.5)), d.bbox("scn_top", (10.2, 1.2, 0.06), (0, 0, 1.03))]
    guard = [d.bbox("scn_glass", (9.6, 0.04, 0.5), (0, 0.1, 1.45)), d.bbox("scn_rail", (9.8, 0.08, 0.06), (0, 0.1, 1.72))]
    guard += [d.bbox(f"scn_post{k}", (0.05, 0.05, 0.7), (-4.8 + k * 1.6, 0.1, 1.38)) for k in range(7)]
    food, colours = [], []
    dishes = [("d8c060", "a08a30"), ("8a5a30", "5a3a1a"), ("7fbf5a", "4f8a3a"), ("8ff0ff", "3fb8d0"), ("d0662a", "a24e1e"), ("e0d0b0", "b0a080")]
    out = []
    for k, (c, dk) in enumerate(dishes):
        well = [d.bbox(f"scn_w{k}", (1.2, 0.7, 0.06), (-4.0 + k * 1.6, -0.05, 1.08))]
        out.append((join(f"scn_f{k}_j", well), paint(f"base_scn_f{k}_m", c, dk), f"food{k}"))
    trays = [d.bbox(f"scn_tr{k}", (0.6, 0.45, 0.03), (4.6, 0.2, 1.09 + k * 0.04)) for k in range(6)]
    lamps = [d.bbox("scn_lamp", (9.4, 0.06, 0.04), (0, 0.1, 1.68))]
    return [(join("scn_body_j", body + guard), steel("base_scn_m", 5, "c8ccd0"), "steel"),
            (join("scn_tray_j", trays), paint("base_scn_tray_m", ORANGE, "a24e1e"), "trays"),
            (join("scn_lamp_j", lamps), glow_warm("base_scn_glow_m", "ffd090", "e0a050"), "lamp_glow")] + out


def base_dish_rack():
    """碗碟架: a wire rack of plates and stacked bowls."""
    frame = [d.bbox("dr_side0", (0.06, 0.7, 1.8), (-1.25, 0, 0.9)), d.bbox("dr_side1", (0.06, 0.7, 1.8), (1.25, 0, 0.9))]
    frame += [d.bbox(f"dr_sh{k}", (2.5, 0.7, 0.04), (0, 0, 0.3 + k * 0.5)) for k in range(4)]
    plates = [d.cyl(f"dr_p{k}{j}", 0.16, 0.02, (-1.0 + j * 0.25, 0, 0.42 + k * 0.5), (math.radians(90), 0, 0), 14) for k in range(3) for j in range(9)]
    return [(join("dr_frame_j", frame), steel("base_dr_m", 3, PANEL), "frame"),
            (join("dr_plate_j", plates), paint("base_dr_plate_m", WHITE, "9aa2a4"), "plates")]


def base_mess_table():
    """食堂长桌: a long table, a bench either side, trays and cups set out."""
    table = [d.bbox("mt_top", (6.0, 1.0, 0.08), (0, 0, 0.8)), d.bbox("mt_beam", (5.6, 0.12, 0.1), (0, 0, 0.45))]
    table += [d.bbox(f"mt_leg{s}", (0.1, 0.8, 0.76), (s * 2.7, 0, 0.38)) for s in (-1, 1)]
    benches = [d.bbox(f"mt_bench{s}", (5.8, 0.4, 0.06), (0, s * 0.95, 0.48)) for s in (-1, 1)]
    benches += [d.bbox(f"mt_bl{s}{x}", (0.08, 0.36, 0.46), (x, s * 0.95, 0.23)) for s in (-1, 1) for x in (-2.6, 2.6)]
    trays = [d.bbox(f"mt_tr{k}{s}", (0.5, 0.36, 0.03), (-2.2 + k * 1.1, s * 0.26, 0.86)) for k in range(5) for s in (-1, 1) if (k + s) % 3 != 0]
    cups = [d.cyl(f"mt_c{k}", 0.05, 0.12, (-1.65 + k * 1.1, 0.0, 0.9), vertices=10) for k in range(4)]
    return [(join("mt_table_j", table), steel("base_mt_m", 3, "b8bcc0"), "table"),
            (join("mt_bench_j", benches), paint("base_mt_bench_m", BLUE, "2c5880"), "benches"),
            (join("mt_tray_j", trays + cups), paint("base_mt_tray_m", ORANGE, "a24e1e"), "trays")]


def base_sealed_door(width=4.0, height=3.6, opening=3.0):
    """封闭的舱门 (用户 2026-10-22: 实在没东西放的区域可以暂时封闭): the airlock
    bay with its blast shutter down — hazard stripes across the leaf, a bar
    bolted over it, a red lamp lit above."""
    side = (width - opening) / 2
    hull = [d.bbox("sd_l", (side, 0.5, height), (-width / 2 + side / 2, -0.25, height / 2)),
            d.bbox("sd_r", (side, 0.5, height), (width / 2 - side / 2, -0.25, height / 2)),
            d.bbox("sd_head", (opening, 0.5, height - 2.7), (0, -0.25, 2.7 + (height - 2.7) / 2)),
            d.bbox("sd_tray", (width, 0.28, 0.16), (0, 0.12, height - 0.3))]
    frame = [d.bbox("sd_fl", (0.3, 0.8, 2.9), (-opening / 2 - 0.15, -0.1, 1.45)),
             d.bbox("sd_fr", (0.3, 0.8, 2.9), (opening / 2 + 0.15, -0.1, 1.45)),
             d.bbox("sd_ft", (opening + 0.6, 0.8, 0.3), (0, -0.1, 2.95))]
    leaf = [d.bbox("sd_leaf", (opening, 0.2, 2.7), (0, -0.05, 1.35))]
    stripes = [d.bbox(f"sd_hz{k}", (0.34, 0.04, 3.2), (-1.2 + k * 0.6, 0.06, 1.35), (0, math.radians(35), 0)) for k in range(5)]
    bar = [d.bbox("sd_bar", (opening + 0.4, 0.16, 0.22), (0, 0.16, 1.3))]
    bar += [d.cyl(f"sd_bolt{s}", 0.08, 0.1, (s * (opening / 2 + 0.05), 0.26, 1.3), (math.radians(90), 0, 0), 10) for s in (-1, 1)]
    lamp = [d.cyl("sd_lamp", 0.18, 0.2, (0, 0.3, 3.3), (math.radians(90), 0, 0), 12)]
    return [(join("sd_hull_j", hull), steel("base_sd_hull_m", 7, HULL), "hull"),
            (join("sd_frame_j", frame + bar), steel("base_sd_frame_m", 2, PANEL), "frame"),
            (join("sd_leaf_j", leaf), steel("base_sd_leaf_m", 5, PANEL), "leaf"),
            (join("sd_hz_j", stripes), paint("base_sd_hz_m", SAFETY), "stripe"),
            (join("sd_lamp_j", lamp), glow_warm("base_sd_lamp_m", "ff4a3a", "b01e1e"), "lamp_glow")]


DECK2_BUILDERS = [base_hydro_basin, base_sun_lamp, base_sealed_door, base_water_tank, base_seed_cabinet,
                  base_potting_bench, base_compost_bin, base_crop_wheat, base_crop_tuber, base_crop_bean, base_crop_shine,
                  base_crop_shine_ripe, base_crop_shine_var, base_crop_shine_var_ripe, base_kitchen_range, base_serving_counter,
                  base_dish_rack, base_mess_table]
ROOM_BUILDERS += DECK2_BUILDERS


DETAILS = {
    "base_wall_panel": _det_wall_panel, "base_wall_panel_med": _det_wall_panel_med, "base_desk": _det_desk, "base_desk_off": _det_desk,
    "base_logistics_counter": _det_logistics_counter, "base_armory_bench": _det_armory_bench, "base_command_dais": _det_command_dais,
    "base_fabricator": _det_fabricator, "base_med_bed": _det_bed("mbd"), "base_med_bed_used": _det_bed("mbud"), "base_med_icu": _det_bed("mid"),
    "base_rack_weapon": _det_rack("rkwd"), "base_rack_armor": _det_rack("rkad"), "base_rack_trinket": _det_rack("rktd"), "base_rack_material": _det_rack("rkmd"),
    "base_sofa": _det_sofa, "base_holo_table": _det_holo_table, "base_personnel_desk": _det_personnel_desk, "base_bar_counter": _det_bar_counter,
}


BUILDERS = [base_holo_table, base_holo_rhodes, base_sand_table, base_intel_wall, base_first_aid, base_conveyor, base_container_stack, base_gantry_crane,
            base_big_screen, base_floor_joint, base_command_console, base_bridge_wall, base_column, base_floor_stripe, base_wall_panel, base_wall_door, base_lift_gate, base_railing, base_dispatch_console, base_desk, base_desk_off,
            base_hanging_screens, base_hanging_screens_pair, base_plant, base_logistics_counter, base_crate, base_crate_stack,
            base_case, base_bench, base_dispenser, base_wall_sign, base_directory_board, base_south_barrier]


def build(name, export=True):
    builder = next(b for b in BUILDERS + ROOM_BUILDERS if b.__name__ == name)
    new_scene(name)
    parts = builder()
    if name in DETAILS:
        parts = parts + DETAILS[name]()
    if not export:
        return parts
    return city.publish(name, parts)


def build_all():
    return [build(b.__name__) for b in BUILDERS + ROOM_BUILDERS]


def build_rooms(names=None):
    """B-M2/B-M3 pieces, or just `names` (without the base_ prefix)."""
    out = []
    for b in ROOM_BUILDERS:
        if names is None or b.__name__[5:] in names:
            out.append(build(b.__name__))
    return out
