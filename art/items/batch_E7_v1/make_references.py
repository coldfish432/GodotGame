from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
REFS = ROOT.parent / "refs_E7"
FIELD = ROOT.parent.parent / "field" / "refs_N"
OUT = ROOT / "sources"
OUT.mkdir(parents=True, exist_ok=True)
GROUPS = {
    "a": [("mine_x01 / spade", REFS / "proto_entrenching_tool.jpg"),
          ("mine_x02 / wrench", REFS / "proto_pipe_wrench.jpg"),
          ("mine_x03 / chain fist", REFS / "proto_brass_knuckles.jpg"),
          ("mine_x04 / hook blade", REFS / "proto_billhook.jpg")],
    "b": [("mine_x05 / socket bayonet", REFS / "proto_bayonet.jpg"),
          ("mine_x06 / wired grip", REFS / "proto_trench_knife.jpg"),
          ("mine_x07 / door ram", None),
          ("mine_x08 / leaf spear", None)],
    "c": [("mi_thug_0 / machete", ROOT.parent / "batch_E1_v5" / "modified_machete.png"),
          ("mi_picket_8 / picket", FIELD / "prts_picket.png"),
          ("set_nameless_0 / machete", REFS / "proto_machete.jpg"),
          ("set_warrant_0 / hook", REFS / "proto_billhook.jpg")],
}
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 18)
for group, entries in GROUPS.items():
    sheet = Image.new("RGB", (4 * 256, 256), "#ddd9d1")
    draw = ImageDraw.Draw(sheet)
    for index, (label, path) in enumerate(entries):
        x = index * 256
        if path is not None:
            image = Image.open(path).convert("RGBA")
            image.thumbnail((236, 210), Image.Resampling.LANCZOS)
            sheet.paste(image, (x + (256 - image.width) // 2, 6 + (210 - image.height) // 2), image)
        draw.text((x + 5, 226), label, font=font, fill="#111111")
    sheet.save(OUT / f"reference_{group}.png")
