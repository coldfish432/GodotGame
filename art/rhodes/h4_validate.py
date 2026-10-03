"""Independent H4 export audit. Run with either H4 batch directory argument."""
from __future__ import annotations

import hashlib
import json
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

from pixel_kit import COLORS, canvas, draw_text, rgba


def audit(root: Path) -> str:
    manifest=json.loads((root/"manifest.json").read_text(encoding="utf-8"))
    palette={tuple(bytes.fromhex(value[1:])) for value in COLORS.values()}
    assert len(COLORS)==31
    assets=manifest["assets"]
    names=[item["id"] for item in assets]
    assert len(names)==len(set(names)),"duplicate asset ID"
    states=defaultdict(list)
    generated=0
    emits=0
    for item in assets:
        path=root/item["file"]
        im=Image.open(path).convert("RGBA")
        pixels=np.asarray(im)
        assert list(im.size)==item["size_px"],path
        assert set(np.unique(pixels[:,:,3]).tolist()) <= {0,255},path
        assert {tuple(row) for row in np.unique(pixels[pixels[:,:,3]>0,:3],axis=0)} <= palette,path
        assert im.getchannel("A").getbbox(),path
        up=Image.open(root/(path.stem+"_8x.png")).convert("RGBA")
        assert up==im.resize(up.size,Image.Resampling.NEAREST) and up.size==(im.width*8,im.height*8),path
        if item["emit"]:
            mask=Image.open(root/item["emit"]).convert("RGBA")
            assert mask.size==im.size and mask.getchannel("A").getbbox(),path
            assert set(np.unique(np.asarray(mask)[:,:,3]).tolist()) <= {0,255},path
            emits+=1
        if item["source"]:
            source=root/item["source"]["file"]
            assert source.exists(),source
            assert hashlib.sha256(source.read_bytes()).hexdigest()==item["source"]["sha256"],source
            assert item["source"]["uniform_integer_reduction"]>=2,source
            generated+=1
        states[item["state_group"]].append(item)
    for name,items in states.items():
        if len(items)>1:
            assert len({tuple(item["size_px"]) for item in items})==1,name
            assert len({tuple(item["anchor_px"]) for item in items})==1,name
    for dep in manifest["external_dependencies"]:
        path=Path(dep["file"])
        assert path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()==dep["sha256"],path
    preview=root/manifest["preview"]["file"]
    one=Image.open(preview).convert("RGBA")
    four=Image.open(root/manifest["preview"]["review_4x"]).convert("RGBA")
    assert four.size==(one.width*4,one.height*4)
    assert four==one.resize(four.size,Image.Resampling.NEAREST)
    assert one.width>=300 and one.height>=200
    if root.name=="batch_H4_warehouse_v2":
        rack=np.asarray(Image.open(root/"warehouse_rack_trinket_80x64.png").convert("RGBA"))
        expected=canvas(80,64)
        draw_text(expected,"B1-03-C",19,1,5,"G2")
        ink=np.asarray(expected)[:,:,:3]==np.asarray(rgba("G2")[:3])
        text_pixels=np.all(ink,axis=2)
        assert np.array_equal(np.all(rack[:,:,:3]==np.asarray(rgba("G2")[:3]),axis=2)[0:9,9:71],
                              text_pixels[0:9,9:71]),"trinket rack header drift"
        for size in ("small","medium","large"):
            sealed=np.asarray(Image.open(root/f"warehouse_loot_crate_{size}_sealed.png").convert("RGBA"))
            opened=np.asarray(Image.open(root/f"warehouse_loot_crate_{size}_open.png").convert("RGBA"))
            assert np.count_nonzero(np.any(sealed!=opened,axis=2))>100,size
    if root.name=="batch_H4_medical_v2":
        for state in ("green","red"):
            gate=np.asarray(Image.open(root/f"medical_contamination_gate_ns_{state}_20x90.png").convert("RGBA"))
            assert gate.shape[:2]==(90,20) and not gate[26:64,:,3].any(),state
        beam=np.asarray(Image.open(root/"medical_contamination_scan_beam_ns_20x90.png").convert("RGBA"))
        assert beam[26:64,:,3].any() and not beam[:26,:,3].any() and not beam[64:,:,3].any()
        for state in ("continuous","door_gap"):
            ns=Image.open(root/f"medical_glass_partition_ns_{state}_8x90.png").convert("RGBA")
            ew=Image.open(root/f"medical_glass_partition_ew_{state}_90x8.png").convert("RGBA")
            assert ew==ns.transpose(Image.Transpose.ROTATE_270),state
        assert all((root/f"medical_room_plate_W_{n:02d}_32x12.png").exists() for n in range(1,12))
    if root.name=="batch_H4b_overhead_v1":
        assert all(item["layer"]=="overhead" for item in assets)
        for stem in ("overhead_ibeam_straight_ew_60x14","overhead_cable_tray_orange_60x14",
                     "overhead_medical_curtain_track_60x12"):
            strip=np.asarray(Image.open(root/(stem+".png")).convert("RGBA"))
            assert np.array_equal(strip[:,0,:],strip[:,-1,:]),stem
        cross=np.asarray(Image.open(root/"overhead_ibeam_cross_junction_36x36.png").convert("RGBA"))
        beam_ew=np.asarray(Image.open(root/"overhead_ibeam_straight_ew_60x14.png").convert("RGBA"))
        beam_ns=np.asarray(Image.open(root/"overhead_ibeam_straight_ns_14x60.png").convert("RGBA"))
        assert np.array_equal(cross[11:25,0,:],beam_ew[:,0,:])
        assert np.array_equal(cross[11:25,-1,:],beam_ew[:,-1,:])
        assert np.array_equal(cross[0,11:25,:],beam_ns[0,:,:])
        assert np.array_equal(cross[-1,11:25,:],beam_ns[-1,:,:])
        for stem in ("overhead_hoist_trolley","overhead_hoist_hook"):
            asset=next(item for item in assets if item["id"]==stem)
            x,y=asset["cable_socket_px"]
            assert 0<=x<asset["size_px"][0] and 0<=y<asset["size_px"][1],stem
    summary=f"PASS {root.name}: {len(assets)} unique assets; {generated} generated-source entries; {emits} nonempty emit masks; state bounds/anchors, source/dependency hashes, binary alpha, 31-color palette, exact 8x and 4x checked."
    report=root/"validation.txt"
    prior=report.read_text(encoding="utf-8")
    if summary not in prior:
        report.write_text(prior+summary+"\n",encoding="utf-8")
    return summary


if __name__=="__main__":
    for arg in sys.argv[1:]:
        print(audit(Path(arg)))
