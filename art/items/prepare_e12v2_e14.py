"""Prepare item-specific prompts for E12 review corrections and E14."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
BASE='''Use case: stylized-concept. Asset type: painted native pixel-art inventory icon for the established extraction ARPG. ONE isolated item only, real transparent background. No shadows, text, numbers, watermark, or glow halos. Top-left light. Crisp uniform pixel blocks, a 1-logical-pixel near-black #0b0c0d outline ALWAYS fully around the object, 4-5 tone ramps per material, at most 24 colours. Paint clear bold clusters, not dithering or noisy microtexture. At least 20 percent of object pixels should be bright highlights above 60 percent luminance. No loose disconnected parts: shafts and heads physically join, strings attach at both ends, all small decorations attach. Leave 2 logical pixels transparent canvas margin. Source should read immediately when reduced to native size. Native blocks enlarged 8x, one colour per logical block, NOT smooth painting with tiny details.'''
PAL={
 'mine':'Steel #2a2d33 #4a5058 #7d868e #b4bec4 #eef3f5; leather #2e2018 #5a3d2a #86603f #b48a5e; rust #4a2a1d #7d4529 #b06a3a #d99560; canvas #5a4d3a #857555 #b3a27c #d6c8a2; small warning yellow #d8a520; grey-green old army paint. Originium is BLACK, only INSIDE fissures have orange #b85a12 #ee8a24 #ffb35a #ffe0a8 glow. No orange crystal surfaces.',
 'lungmen':'Steel #2a2d33 #4a5058 #7d868e #b4bec4 #eef3f5; leather browns; navy #141f30 #24395a #3d6088 #6f9cc6 #b5d2ea; small vermilion #6e1616 #a82a22 #d9483a #f07a62 and brass #6e5220 #a8822e #dcb85a; reflective band #c8d860. Bright edges on navy. Clean issued gear or traditional Yan craft as described.',
 'sami':'Steel #2a2d33 #4a5058 #7d868e #b4bec4 #eef3f5; wood #3f2a1a #6b4a2e #9a7048; bone #8e8470 #b9ae95 #e6dfcc #fbf8ee; fur #6e5a45 #a68c6c #d8cbb5; ice #3d6a8a #5d8fb0 #9cc8e0 #e4f4fb; tiny woven bands red #b03a2e yellow #d9a43a blue #3f6fa8. No originium.',
 'siracusa':'Steel #2a2d33 #4a5058 #7d868e #b4bec4 #eef3f5; charcoal lacquer #1a1b1e #2e3036 #4a4d55 #767a84; walnut #3a2618 #5e3f26 #8a6440; brass #5e4418 #9a7428 #d0a848 #f0d888; ivory #8e8470 #c8bea6 #ece4d0; tiny wine-red #5e1620 #9a2a3a accents. 1940s Italian civilian family quarter, dressed and maintained. No originium.',
 'rhodes':'STRICT Rhodes palette: #0b0c0d #15181a #1f2427 #2c3236 #3d4448 #566064 #737d82 #98a2a6 #c3cacc #a9b2b3 #d4dadb #eef2f2 #385878 #5888a8 #78b8e8 #6e2f14 #b8531f #e0782a #0f3a40 #2a8a92 #5fd0d8 #b8f4f6 #6b5a1e #b89a2a #f4d73c. Neutral ship steel, cold grey and medical white body. Blue/orange/cyan/yellow combined under 10 percent of opaque pixels and any one family under 6 percent. Thin blue inset strips only 1 logical pixel wide. Small cyan focus is surrounded by a broad neutral metal housing. Leave ONE 9x9 logical-pixel blank neutral patch where the logo belongs, for exact native logo placement later. No letters or invented logos.'
}

def write(batch,entries):
    root=ROOT/batch;(root/'sources').mkdir(parents=True,exist_ok=True)
    (root/'generation_specs.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf-8')
    (root/'generation_prompts.md').write_text('# '+batch+'\n\nBuilt-in imagegen, one call per asset.\n\n'+'\n\n'.join('## '+e['id']+'\n\n'+e['prompt'] for e in entries),encoding='utf-8')
    print(batch,len(entries))

bell='A LARGE antique DARK BRONZE HAND BELL, centered front view native 32x32. Immediately identifiable bell silhouette: small CLOSED suspension loop at the top, a rounded dome body that slopes out into a wide flared bell mouth 26 logical pixels across, with a dark hollow opening below and one visible suspended clapper hanging down. Mouth at y24, clapper reaches y29, top loop at y2. The bronze body must occupy most of the canvas, deep brown-bronze shadow with warm metallic raised edges, distinctly darker and larger than a small silver sleigh bell. Frost is ONLY 3 bold white patches on TOP of the dome, NOT on its sides, NOT all over the rim. A narrow violet inner glow inside the mouth only, no external aura. No lump of rock, no ice crystal, no diagonal object. 1px #0b0c0d outline, joined loop/body/mouth/clapper. Palette bronze #34251c #554030 #806348 #b48a5e #d6b98b, frost #c7d3dc #eef3f5, violet #3d215c #6a3a94 #ae78db.'
cord='A leather KNOTTED CORD RECORD, centered front view native32x32, laid out as ONE loose flowing S-shaped cord, one continuous connected strand at least TWO logical pixels THICK before the 1px dark outline. Six to eight distinct warm-light-brown KNOTS, each a bold 3x3 or 4x3 pixel lump, spaced apart along the S so every knot can be counted at 1x. ONE prominent white BONE TOGGLE at upper right end, six logical pixels long by three high, physically attached to cord. The S spans x4 to27 and y4 to27. Dark leather cord with lighter knots, ivory toggle with grey shadow. Few bold strands, no fringes, no hairs, no twigs, no dried plant, no tangled bundle, no bead necklace. All knots joined to the cord. Full nearblack1px outline. Palette leather #2e2018 #5a3d2a #86603f #b48a5e #d6b98b; bone #8e8470 #b9ae95 #e6dfcc #fbf8ee. No glow.'
entries=[]
for item,name,subject,emit in [('mi_fallen_snowpriest_29','反馈赠之铃',bell,True),('mi_ice_hunter_20','结绳猎记',cord,False)]:
    entries.append(dict(id=item,name=name,region='sami',form='trinket',native_size=[32,32],has_emit=emit,kind='exclusive',prompt=BASE+'\n'+subject))
write('batch_E12_v2',entries)

brief=(ROOT/'E14_ranged_staves_brief_v1.md').read_text(encoding='utf-8')
entries=[];region='mine'
for line in brief.splitlines():
    if line.startswith('### '):
        region=next((v for k,v in [('Chernobog','mine'),('Lungmen','lungmen'),('Sami','sami'),('Siracusa','siracusa'),('Rhodes','rhodes')] if k in line),region)
    if not line.startswith('| '):continue
    f=[s.strip() for s in line.strip('|').split('|')]
    if len(f)!=4 or f[2].split(' · ')[0] not in ['crossbow','gun','bow','staff']:continue
    item,name,form,detail=f[0],f[1],f[2].split(' · ')[0],f[3]
    framing='Native canvas72x32, enlarged8x. Overall silhouette fills width68 pixels and height24-28 pixels. Stock or foot on LEFT, head or muzzle on RIGHT. Whole long object TILTED UP toward the right by 8-10 degrees, so left foot lower and right head higher. Shaft or barrel is 4 logical pixels THICK before adding full1px outline; no hairline shaft. Enlarge the head enough for its function to read. High contrast connected construction.'
    if form=='crossbow':framing+=' Crossbow MUST show the BOW ARMS/PROD spanning VERTICALLY across the RIGHT front end, 22-26 pixels tall, with a pale attached bowstring, while stock extends toward LEFT. Orthographic side/top view to show the arms. It must not look like a rifle without bow arms.'
    if form=='gun':framing+=' Old single-shot or double barrel civilian gun, obvious stock and barrel, NO crossbow arms. No magazines, no optics, no rails, no modern automatic gun.'
    if form=='bow':framing='Native72x32 canvas, horizontal bow spanning x2 to69. Bow limbs curve UP into a strong arch, string is a continuous pale line along the BOTTOM attached to both limb tips. Broad readable limbs3-4px thick before1px outline, carved grip near center. Limbs and bowstring form one joined silhouette. Do NOT draw the bow vertical or diagonally across a square. No arrow necessary.'
    if form=='staff':framing+=' Head is a FOCUS or ceremonial ornament, NEVER a blade, point, spearhead, axe or cutting edge. Bulbous/round/ring/box head. Use bright material rim on dark shafts.'
    if item=='folding_sleeve_crossbow':framing+=' Exception: compact object occupies 46x24 native pixels centered; keep empty space, do not stretch.'
    if item=='imperial_heavy_crossbow':framing+=' This is the largest crossbow: fill all68x28px with long stock and broad heavy bow arms.'
    entries.append(dict(id=item,name=name,region=region,form=form,native_size=[72,32],kind='base',has_emit=item in ['scrap_casting_staff','reunion_caster_staff','lawyer_casting_cane','rhodes_crossbow','rhodes_staff'],prompt=BASE+'\n'+PAL[region]+'\n'+framing+'\nItem: '+name+'. Mandatory structure: '+detail))
assert len(entries)==22
write('batch_E14_v1',entries)
