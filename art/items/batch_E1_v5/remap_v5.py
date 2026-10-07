"""E1 v5: remap miner_vest off the originium orange ramp (E1_revision_v5.md).

Everything else is copied unchanged from batch_E1_v4; sources stay in
../batch_E1_v4/sources. Rebuilds the 8x preview, contact sheets, silhouette
check and manifest using the v4 processing script's sheet functions.
"""
import importlib.util
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
V4 = ROOT.parent / "batch_E1_v4"
REMAP = {"#ffb35a": "#d99560", "#ee8a24": "#b06a3a", "#b06a3a": "#7d4529"}

def rgb(h): return tuple(bytes.fromhex(h[1:]))

def remap(path: Path) -> None:
    table = {rgb(k): rgb(v) for k, v in REMAP.items()}
    im = Image.open(path).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] and c[:3] in table: px[x, y] = table[c[:3]] + (255,)
    im.save(path)

def main() -> None:
    remap(ROOT / "miner_vest.png")  # idempotent: re-copy from v4 first when rerunning
    vest = Image.open(ROOT / "miner_vest.png")
    vest.resize((vest.width * 8, vest.height * 8), Image.Resampling.NEAREST).save(ROOT / "miner_vest_8x.png")
    spec = importlib.util.spec_from_file_location("v4", V4 / "process_sources.py")
    v4 = importlib.util.module_from_spec(spec); spec.loader.exec_module(v4)
    v4.ROOT = ROOT
    manifest = json.loads((V4 / "manifest.json").read_text(encoding="utf-8"))
    rows = [(it["id"], it["name"], it["kind"]) for it in manifest["items"]]
    v4.make_contact(rows)
    from PIL import ImageDraw, ImageFont
    sheet = Image.open(ROOT / "contact_sheet.png")
    draw = ImageDraw.Draw(sheet)
    draw.rectangle((0, 0, sheet.width, 24), fill="#20242b")
    draw.text((5, 6), "E1 v5 (final) / actual 40px slots / common  fine  rare", fill="#eef3f5", font=ImageFont.load_default())
    sheet.save(ROOT / "contact_sheet.png")
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")
    v4.make_silhouette(rows)
    manifest.update(version=5, source_brief="../E1_revision_v5.md", status="accepted")
    for it in manifest["items"]:
        it["source"] = "../batch_E1_v4/" + it["source"]
        if it["id"] == "miner_vest":
            it["revision"] = "v4 colour-remapped to rust ramp (v5)"
            it["isolated_pixel_percent"] = v4.isolated_pixel_percent(Image.open(ROOT / "miner_vest.png").convert("RGBA"))
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
