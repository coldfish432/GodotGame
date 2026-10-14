"""Hand-placed native pixel clusters for the compact PRTS squad portrait."""

from PIL import Image, ImageDraw

INK = "#0b0c0d"
DEEP = "#191c21"
SHADE = "#272b32"
BASE = "#393e47"
LIT = "#626971"
SILVER = "#929a9e"
WHITE = "#c9cfd2"
GLINT = "#e9ecec"
CYAN_DARK = "#2a8a92"
CYAN = "#5fd0d8"
ORANGE_DARK = "#bc5309"
ORANGE = "#ffae20"
ORANGE_LIT = "#ffd55b"
LILAC_DARK = "#695973"
LILAC = "#a996b4"
LILAC_LIT = "#dccae0"
SKIN_DARK = "#b6816e"
SKIN = "#f1c6ad"


def paint_native() -> Image.Image:
    im = Image.new("RGBA", (105, 150), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # Sniper: bow, legs, short jacket, then the large ear helmet.
    d.arc((27, 31, 46, 99), 80, 272, fill=INK, width=3)
    d.arc((29, 34, 44, 96), 80, 272, fill=LIT, width=1)
    d.line((35, 36, 35, 96), fill=SILVER)
    d.line((34, 54, 40, 63), fill=CYAN_DARK, width=2)
    d.polygon([(44, 114), (52, 114), (52, 137), (47, 140), (42, 137)], fill=INK)
    d.polygon([(56, 114), (64, 114), (67, 137), (63, 140), (57, 136)], fill=INK)
    d.rectangle((45, 118, 50, 136), fill=BASE)
    d.rectangle((58, 118, 63, 136), fill=BASE)
    d.rectangle((42, 136, 52, 140), fill=SHADE)
    d.rectangle((57, 136, 67, 140), fill=SHADE)
    d.polygon([(42, 75), (61, 73), (69, 86), (66, 121), (59, 126), (42, 122), (36, 91)], fill=INK)
    d.polygon([(42, 78), (60, 76), (66, 87), (64, 119), (58, 122), (43, 119), (39, 91)], fill=SHADE)
    d.polygon([(39, 83), (43, 79), (48, 83), (44, 105), (38, 103)], fill=BASE)
    d.polygon([(63, 78), (69, 85), (68, 104), (64, 105)], fill=BASE)
    d.line((43, 81, 47, 87, 45, 106), fill=CYAN_DARK, width=1)
    d.line((62, 79, 65, 87, 65, 104), fill=CYAN, width=1)
    d.line((48, 79, 52, 85, 52, 112), fill=CYAN_DARK, width=1)
    d.rectangle((47, 103, 60, 114), fill=DEEP)
    d.line((49, 106, 59, 106), fill=LIT)
    d.polygon([(37, 47), (42, 33), (44, 43), (48, 38), (61, 39), (65, 30), (69, 43), (70, 52), (65, 72), (58, 80), (44, 77), (37, 69)], fill=INK)
    d.polygon([(41, 48), (43, 37), (46, 45), (51, 43), (61, 43), (66, 35), (67, 51), (64, 69), (57, 76), (45, 72), (40, 66)], fill=BASE)
    d.polygon([(44, 39), (45, 36), (47, 43)], fill=SILVER)
    d.polygon([(64, 43), (66, 38), (66, 47)], fill=SILVER)
    d.polygon([(42, 48), (49, 44), (61, 44), (67, 48), (66, 53), (41, 53)], fill=SHADE)
    d.polygon([(47, 43), (58, 42), (62, 44), (53, 44)], fill=LIT)
    d.rectangle((41, 54, 66, 64), fill=INK)
    d.polygon([(43, 56), (64, 56), (65, 60), (61, 63), (44, 62)], fill=ORANGE_DARK)
    d.polygon([(45, 55), (61, 55), (64, 58), (59, 61), (45, 60)], fill=ORANGE)
    d.rectangle((47, 56, 53, 57), fill=ORANGE_LIT)
    d.polygon([(43, 65), (48, 63), (61, 64), (65, 68), (59, 75), (49, 75), (43, 71)], fill=DEEP)
    d.line((49, 70, 58, 70), fill=LIT)
    d.polygon([(45, 66), (50, 64), (52, 67), (49, 69)], fill=BASE)
    d.polygon([(59, 65), (63, 67), (60, 70), (56, 68)], fill=BASE)
    d.rectangle((49, 88, 58, 93), fill=BASE)
    d.rectangle((50, 89, 55, 91), fill=LIT)
    d.rectangle((45, 96, 48, 101), fill=BASE)
    d.rectangle((55, 96, 58, 101), fill=BASE)
    d.rectangle((46, 118, 50, 123), fill=LIT)
    d.rectangle((59, 118, 63, 123), fill=LIT)

    # Front-left melee: solid round helmet, broad visor, short armoured body.
    d.polygon([(17, 120), (25, 120), (26, 139), (21, 144), (15, 142)], fill=INK)
    d.polygon([(31, 119), (39, 119), (42, 140), (38, 144), (31, 141)], fill=INK)
    d.rectangle((19, 123, 24, 139), fill=BASE)
    d.rectangle((33, 123, 38, 139), fill=BASE)
    d.rectangle((13, 140, 25, 144), fill=SHADE)
    d.rectangle((30, 140, 43, 144), fill=SHADE)
    d.polygon([(10, 94), (20, 88), (37, 88), (47, 96), (44, 125), (37, 130), (15, 127), (7, 113)], fill=INK)
    d.polygon([(12, 97), (21, 91), (36, 91), (44, 98), (42, 122), (36, 126), (17, 124), (10, 111)], fill=SHADE)
    d.polygon([(10, 98), (15, 95), (20, 101), (17, 117), (8, 114)], fill=BASE)
    d.polygon([(39, 94), (46, 99), (47, 114), (42, 117), (39, 103)], fill=BASE)
    d.line((13, 96, 19, 100, 17, 117), fill=CYAN_DARK, width=1)
    d.line((38, 94, 43, 99, 43, 113), fill=CYAN, width=1)
    d.line((19, 101, 22, 96, 32, 96, 37, 101), fill=CYAN_DARK, width=1)
    d.line((21, 107, 21, 120), fill=CYAN, width=1)
    d.rectangle((23, 105, 36, 123), fill=DEEP)
    d.rectangle((25, 108, 34, 112), fill=BASE)
    d.rectangle((25, 115, 34, 119), fill=BASE)
    d.line((26, 122, 37, 122), fill=LIT)
    d.polygon([(8, 70), (14, 61), (26, 58), (37, 62), (45, 71), (44, 84), (37, 95), (18, 96), (9, 88)], fill=INK)
    d.polygon([(11, 71), (16, 64), (26, 61), (36, 64), (42, 72), (41, 83), (36, 92), (18, 92), (12, 86)], fill=BASE)
    d.polygon([(16, 65), (26, 62), (35, 64), (39, 68), (31, 67), (21, 68)], fill=LIT)
    d.polygon([(18, 65), (26, 63), (32, 64), (28, 65)], fill=SILVER)
    d.polygon([(23, 60), (30, 60), (34, 62), (27, 62)], fill=WHITE)
    d.polygon([(11, 75), (39, 73), (42, 81), (38, 86), (13, 86)], fill=DEEP)
    d.polygon([(13, 76), (38, 75), (39, 80), (35, 84), (15, 84)], fill=SILVER)
    d.polygon([(15, 77), (31, 76), (29, 80), (16, 82)], fill=WHITE)
    d.polygon([(15, 86), (37, 85), (35, 92), (19, 92)], fill=SHADE)
    d.line((19, 89, 32, 89), fill=LIT)
    d.polygon([(17, 87), (22, 86), (22, 90), (19, 91)], fill=BASE)
    d.polygon([(31, 86), (36, 86), (34, 91), (30, 90)], fill=BASE)
    d.polygon([(11, 98), (16, 96), (18, 101), (15, 105), (10, 103)], fill=LIT)
    d.polygon([(40, 97), (44, 100), (44, 104), (40, 105)], fill=LIT)
    d.rectangle((10, 111, 16, 115), fill=DEEP)
    d.rectangle((42, 110, 47, 115), fill=DEEP)
    d.rectangle((20, 125, 25, 129), fill=LIT)
    d.rectangle((34, 125, 39, 129), fill=LIT)
    d.line((7, 119, 24, 130), fill=INK, width=3)
    d.line((5, 120, 20, 130), fill=SILVER, width=1)
    d.line((5, 120, 12, 124), fill=GLINT, width=1)

    # Front-right logistics: two drooping ears and one lilac hair mass.
    d.polygon([(69, 119), (77, 119), (78, 139), (74, 144), (69, 141)], fill=INK)
    d.polygon([(84, 118), (92, 118), (94, 140), (89, 144), (83, 140)], fill=INK)
    d.rectangle((71, 122, 76, 139), fill=BASE)
    d.rectangle((86, 122, 91, 139), fill=BASE)
    d.rectangle((68, 140, 79, 144), fill=SHADE)
    d.rectangle((82, 140, 94, 144), fill=SHADE)
    d.polygon([(68, 93), (88, 92), (96, 99), (95, 124), (90, 132), (70, 132), (63, 123)], fill=INK)
    d.polygon([(69, 96), (88, 95), (93, 101), (92, 122), (88, 129), (71, 129), (66, 121)], fill=WHITE)
    d.polygon([(74, 99), (87, 98), (91, 119), (88, 126), (73, 124)], fill=DEEP)
    d.rectangle((75, 102, 85, 119), fill=SHADE)
    d.line((69, 101, 69, 118), fill=CYAN, width=1)
    d.line((89, 100, 91, 119), fill=CYAN_DARK, width=1)
    d.line((76, 100, 85, 100), fill=CYAN_DARK)
    d.polygon([(72, 126), (89, 125), (90, 133), (70, 133)], fill=CYAN_DARK)
    d.rectangle((73, 127, 87, 130), fill=CYAN)
    d.polygon([(60, 104), (68, 102), (72, 123), (69, 130), (60, 128)], fill=INK)
    d.polygon([(62, 107), (67, 105), (70, 122), (68, 127), (62, 126)], fill=BASE)
    d.line((64, 109, 65, 123), fill=CYAN_DARK, width=1)
    d.polygon([(62, 70), (67, 60), (74, 58), (88, 59), (96, 66), (100, 80), (98, 99), (92, 104), (69, 102), (60, 94)], fill=INK)
    d.polygon([(64, 70), (69, 63), (75, 61), (88, 62), (94, 67), (97, 81), (96, 97), (91, 101), (70, 99), (63, 92)], fill=LILAC)
    d.polygon([(63, 69), (58, 72), (58, 87), (63, 96), (68, 91), (67, 75)], fill=LILAC_DARK)
    d.polygon([(95, 68), (101, 72), (101, 90), (97, 98), (92, 92), (93, 76)], fill=LILAC_DARK)
    d.polygon([(68, 64), (77, 60), (87, 62), (93, 67), (88, 68), (75, 66)], fill=LILAC_LIT)
    d.polygon([(67, 76), (69, 69), (72, 68), (70, 84)], fill=LILAC_LIT)
    d.polygon([(89, 67), (93, 72), (94, 85), (91, 79)], fill=LILAC_LIT)
    d.polygon([(69, 71), (75, 67), (89, 68), (94, 75), (93, 84), (69, 84)], fill=DEEP)
    d.rectangle((72, 75, 91, 91), fill=SKIN)
    d.rectangle((72, 87, 91, 91), fill=WHITE)
    d.polygon([(68, 72), (75, 68), (91, 70), (94, 77), (91, 83), (78, 82), (71, 86), (67, 81)], fill=LILAC)
    d.polygon([(69, 72), (75, 69), (85, 70), (78, 75)], fill=LILAC_LIT)
    d.rectangle((78, 69, 87, 73), fill=SHADE)
    d.rectangle((81, 69, 83, 73), fill=CYAN)
    d.rectangle((79, 70, 85, 71), fill=CYAN)
    d.polygon([(73, 73), (79, 73), (76, 88), (70, 91)], fill=LILAC)
    d.polygon([(85, 74), (92, 76), (89, 88), (83, 87)], fill=LILAC)
    d.polygon([(75, 74), (78, 74), (76, 82), (74, 83)], fill=LILAC_LIT)
    d.polygon([(86, 77), (89, 78), (87, 85), (84, 84)], fill=LILAC_LIT)
    d.line((70, 83, 70, 95), fill=LILAC_DARK, width=2)
    d.line((93, 82, 93, 97), fill=LILAC_DARK, width=2)
    d.line((75, 101, 84, 114), fill=LIT, width=2)
    d.rectangle((77, 104, 86, 107), fill=BASE)
    d.rectangle((78, 105, 83, 106), fill=SILVER)
    d.rectangle((65, 116, 71, 121), fill=SKIN)
    d.rectangle((90, 113, 96, 118), fill=SKIN)
    d.rectangle((87, 117, 102, 135), fill=INK)
    d.rectangle((89, 119, 100, 133), fill=SILVER)
    d.polygon([(89, 119), (99, 119), (97, 121), (90, 121)], fill=GLINT)
    d.line((94, 120, 94, 132), fill=BASE, width=2)
    d.rectangle((95, 123, 97, 126), fill=CYAN)
    d.line((88, 131, 100, 131), fill=BASE)
    # Clear three isolated pixels left by overlapping silhouettes.
    d.point((13, 96), fill=BASE)
    d.point((9, 123), fill=GLINT)
    d.point((71, 127), fill=CYAN_DARK)
    return im
