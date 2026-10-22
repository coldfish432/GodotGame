"""Rhodes Island's second deck (势力特供策划案_v0_2 §三; 用户 2026-10-22: 应该和
第一层大致轮廓相似 … 整体轮廓相同，房间分隔不用一样，第二层不需要舰桥这个大片区域
… 实在没东西放的区域可以暂时封闭). Writes art/rhodes_runtime/room_<id>.json.

The deck keeps the first deck's outline — the west wing, the hall's block
with its two north rooms, the east wing — shifted DX east, but is divided
its own way: a corridor with the lift through the hall's block, 食堂 and its
kitchen north of it, 农业部 in the west wing, and the rest sealed for now.

Layout x east, z north (as BaseMap). A room is (x0, z0 north edge, width,
depth). Doors are 3 m gaps in a room's wall strips: (side, centre[, width]) — a
gap wider than 6 m is an opening, drawn with no wall at all; "south"
gaps are left in the strips only (BaseMap draws a room's south wall low and
without doorways; the room south of it draws the door). Sealed doors are
listed in BaseMap.SEALED_DOORS, which shuts them and draws the blast door.
"""
import json
import os

DX = 320.0
T = 0.6
DOOR = 3.0
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "..", "art", "rhodes_runtime")

ROOMS = {
    # The hall's block: a road north–south from the lift on the north wall
    # (用户 2026-10-22: 升降梯是在中间的上面，中间留出道路) down to the corridor
    # that runs east–west; 食堂 and its kitchen north-west, sealed rooms round them.
    "deck2": ((58.0, 0.0, 12.0, 21.0), [("south", 64.0, 12.0)]),
    "deck2_x": ((0.0, -21.0, 128.0, 10.0), [("west", -26.0), ("north", 28.0), ("north", 64.0, 12.0), ("north", 96.0), ("east", -26.0)]),
    "mess": ((0.0, 0.0, 57.0, 21.0), [("south", 28.0), ("north", 7.47)]),
    "galley": ((0.0, 10.0, 18.0, 10.0), [("south", 7.47)]),
    "sealed_ne": ((71.0, 0.0, 57.0, 21.0), []),
    "sealed_n": ((100.0, 13.0, 28.0, 13.0), []),
    "sealed_sw": ((0.0, -31.0, 63.5, 25.0), [("north", 32.0)]),
    "sealed_se": ((64.5, -31.0, 63.5, 25.0), [("north", 96.0)]),
    # 农业部 in the east wing, its two rooms opened into one (用户 2026-10-22:
    # 农业部放到右侧两个房间，墙壁打通，可以多放几组水培).
    "farm": ((129.0, 4.0, 45.0, 41.0), [("west", -26.0), ("south", 149.0, 40.0)]),
    "farm2": ((129.0, -37.0, 40.0, 19.0), [("north", 149.0, 40.0)]),
    # The west wing, sealed.
    "sealed_w": ((-65.0, -8.0, 64.0, 36.0), [("east", -26.0)]),
    "sealed_nw": ((-40.0, 6.0, 39.0, 13.0), []),
}
## Rooms that stand on the next room's north wall: no south strip of their own.
OPEN_SOUTH = ["galley", "sealed_n"]

INTERACTABLES = {
    "deck2": [{"id": "lift2", "kind": "lift", "label": "升降梯", "x": 64.0, "z": -3.4}],
    "farm": [{"id": "farm", "kind": "farm", "label": "农业部终端", "x": 136.0, "z": -21.0}],
    "mess": [{"id": "canteen", "kind": "canteen", "label": "食堂终端", "x": 29.0, "z": -4.9}],
}
SPAWNS = {"deck2": {"deck2": [64.0, -6.0]}}
NOTES = {
    "deck2": "Deck 2's road from the lift on the north wall south to the corridor.",
    "deck2_x": "Deck 2's corridor through the first deck's hall block: west sealed, east to 农业部, north to 食堂 and the road.",
    "farm": "农业部 (north): two of RimWorld's 11×11 sun-lamp rooms of hydroponics; open south into its other room.",
    "farm2": "农业部 (south): the third sun-lamp room.",
    "mess": "食堂: the serving counter and long tables; the kitchen north-west, a door south to the corridor.",
    "galley": "The kitchen, for show: ranges, the prep island, fridges.",
}


def strips(x0, z0, w, d, gaps, room_id):
    def run(lo, hi, centres):
        out, at = [], lo
        for c, width in sorted(centres):
            out.append((at, c - width / 2))
            at = c + width / 2
        out.append((at, hi))
        return [(a, b) for a, b in out if b - a > 0.01]
    by = {s: [(g[1], g[2] if len(g) > 2 else DOOR) for g in gaps if g[0] == s] for s in ("north", "south", "west", "east")}
    out = []
    for a, b in run(x0, x0 + w, by["north"]):
        out.append([a, z0, b, z0 + T])
    if room_id not in OPEN_SOUTH:
        for a, b in run(x0, x0 + w, by["south"]):
            out.append([a, z0 - d - T, b, z0 - d])
    for a, b in run(z0 - d, z0, by["west"]):
        out.append([x0 - T, a, x0, b])
    for a, b in run(z0 - d, z0, by["east"]):
        out.append([x0 + w, a, x0 + w + T, b])
    return out


def main():
    for room_id, ((x0, z0, w, d), gaps) in ROOMS.items():
        x0 += DX
        shifted = [(g[0], g[1] + DX if g[0] in ("north", "south") else g[1]) + tuple(g[2:]) for g in gaps]
        cols = [[round(v, 2) for v in c] for c in strips(x0, z0, w, d, shifted, room_id)]
        ground = {"tex": "", "w_px": round((w + 1.07) * 15, 1), "h_px": round(d * 12.7, 1), "x": round(x0 - 0.53, 2), "z": z0}
        data = {"id": room_id, "origin": [x0, z0], "size": [w, d], "ground": ground, "facade": dict(ground, h_px=46),
                "sprites": [], "colliders": cols,
                "interactables": [dict(e, x=e["x"] + DX) for e in INTERACTABLES.get(room_id, [])],
                "spawns": {k: [v[0] + DX, v[1]] for k, v in SPAWNS.get(room_id, {}).items()},
                "_note": NOTES.get(room_id, "Sealed for now (用户 2026-10-22: 实在没东西放的区域可以暂时封闭).") + " Written by tools/blender/base/make_deck2_rooms.py."}
        with open(os.path.join(OUT, f"room_{room_id}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
    print(len(ROOMS), "rooms")


if __name__ == "__main__":
    main()
