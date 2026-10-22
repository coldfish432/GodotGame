from pathlib import Path
import re,json,shutil
root=Path(__file__).resolve().parent/'batch_BG1_v1'
root.mkdir(exist_ok=True);(root/'sources').mkdir(exist_ok=True);(root/'refs').mkdir(exist_ok=True)
brief=root.parent.parent/'field/B_bosses_brief_v1.md'
shutil.copy2(brief,root/'source_brief.md')
shutil.copy2(root.parent/'batch_E13_v1/art_preview.png',root/'refs/style_E13.png')
text=brief.read_text(encoding='utf-8').split('## Stage 3:')[1]
extra={
'bg_patriot_0':'Long polearm: left leather-wrapped wooden haft, right rusted axe blade plus spear point; small torn orange-red pennant hangs immediately behind head. Halberd silhouette, not a sword.',
'bg_patriot_1':'Plain straight steel short sword, left worn dark grip and simple crossguard, right broad pointed blade, modest chips. No large crystals, no ornate decoration.',
'bg_patriot_2':'Two-handed brutal block maul. Long left haft, enormous rectangular iron head on right, rusty edges and orange rivets. Not a hammer with an axe blade.',
'bg_patriot_3':'Empty front-view heavy cuirass, massive angular pauldrons, layered dark grey plates, orange piping and rivets. No wearer, no head, no hands or legs.',
'bg_patriot_4':'Empty front-view pale dirty-grey hood-down shoulder cloak, asymmetric ragged hem, three large stitched dark patches, simple orange-red clasp. No wearer.',
'bg_patriot_5':'Empty front-view heavy dark breastplate, angular black Originium crystal clusters growing specifically from gaps between steel plates; sharp grey highlights, small rusty orange straps.',
'bg_patriot_6':'Single shield-shaped iron lapel badge, chunky orange X over dark inset, worn silver rim. Generic Shieldguard sign, no real-world heraldry.',
'bg_patriot_7':'One broad open iron armband, obvious oval opening and a faceted black Originium crystal on top. Steel reflections, tiny lavender crystal facet only.',
'bg_patriot_8':'Old simple medal hanging below a short faded rust-red cloth ribbon; tarnished brass, two cloth tails, no text or national insignia.',
'bg_rat_king_0':'Polished dark wood walking cane, long slim shaft horizontally to right, elegant silver curved handle at left; no hidden sword, no rat head, no blade.',
'bg_rat_king_1':'Compact alley knife, chunky worn brown handle left, broad short single-edged steel blade right, small simple guard, no needle blade.',
'bg_rat_king_2':'Open folding iron fan, fan pivot at left, dark metal ribs spread toward right into a broad silver semicircle; large planar panels, one purple tassel at pivot.',
'bg_rat_king_3':'Empty front-view long ivory coat, enormous shaggy white fur collar, dark waistcoat and purple necktie visible in open front, long sleeves, no wearer.',
'bg_rat_king_4':'Empty front-view sleeveless charcoal-brown waistcoat, visible armholes, three big patched cloth panels and worn brass buttons. No sleeves, no coat.',
'bg_rat_king_5':'Empty front-view sand-beige hooded travel cloak, big hood opening, broad draped shoulders, wind-worn torn lower edge, dark leather clasp. No wearer or sand effects.',
'bg_rat_king_6':'Single small bronze handbell, visible flared bell mouth, sand-gold glass inset in body, short loop handle and clapper; no hourglass.',
'bg_rat_king_7':'Single upright glass hourglass with two glass bulbs and a narrow waist, sand-gold contents, brass top/bottom with two dark supports.',
'bg_rat_king_8':'Closed squat thick notebook in worn tan-brown leather, wraparound dark leather strap, cream page block and dog-eared corner. No writing.',
'bg_eikthyrnir_0':'Mjolnir-like heavy short rectangular hammer head at right, broad dark iron faces with pale cyan carved lines and bright steel edges; left wrapped dark wooden handle. Not an axe.',
'bg_eikthyrnir_1':'Big chipped iron axe head at right, cleft splitting weathered wood haft extending left, pale exposed splinters at head socket, small cyan cord.',
'bg_eikthyrnir_2':'Primitive slightly curved ivory bone knife, jagged spine, pointed tip right, sinew-wrapped left grip and small dark wood guard. No metal sword.',
'bg_eikthyrnir_3':'Empty front-view broad thick white fur shoulder cape, rounded fur collar, scalloped coarse tufts, dark green-grey inner lining visible centrally, cyan clasp. No horns and no sleeves.',
'bg_eikthyrnir_4':'Empty front-view dark leather torso tunic with shoulder flaps, waist belt and large pale cyan geometric frost lines; no white fur, no antlers, no wearer.',
'bg_eikthyrnir_5':'A matched pair of steel-and-hide shoulder guards linked by short chest strap, each has big branching deer antler tines. No torso, no helmet, no animal head.',
'bg_eikthyrnir_6':'Single small forked deer antler pendant hanging from dark cord loop, ivory tines, dark brass cap. Clear antler Y silhouette, no skull.',
'bg_eikthyrnir_7':'Single thick angular slate talisman on a short cord loop, bold pale-cyan frost zigzag inlaid into the face, grey beveled rim. No alphabetic rune or lettering.',
'bg_eikthyrnir_8':'Single anatomically stylized wooden heart, obvious heart shape made of dark cracked wood, pale split grain and small cyan inner fissure. No flames, no floating fragments.',
'bg_zaro_0':'One huge curved ivory fang fashioned into a blade: black leather left grip, dark metal guard, long thick tooth tapering to right. Curved organic fang shape, tiny dark red band.',
'bg_zaro_1':'One wearable claw gauntlet: blackened metal wrist cuff at left, three large curved ivory claws projecting together to right, grey fur around wrist, red strap. No detached animal paw.',
'bg_zaro_2':'Extremely slim straight stiletto dagger, needle steel blade points right, charcoal grip left and elegant tiny guard, dark red pommel; narrower than alley knife.',
'bg_zaro_3':'Empty front-view open shoulder mantle of dark grey wolf pelt, recognizable wolf head forming shoulder clasp/collar at top, long hanging pelt sides, silver ruff highlights. No whole live wolf.',
'bg_zaro_4':'Empty front-view sleeved heavy shaggy grey-brown fur coat, very broad cylindrical body, rough natural fur hem, pale fur edges. NO wolf head, no animal mask, no cape silhouette.',
'bg_zaro_5':'Empty front-view 1940s charcoal raincoat, broad lapels, double-breasted buttons, waist belt and long clean hem, muted slate shoulder highlights. No hood, no wearer.',
'bg_zaro_6':'Single dark crimson roughly faceted stone, nearly black edges, blood-red center and sharp pale red specular glint; irregular angular stone silhouette, no mount, no floating aura.',
'bg_zaro_7':'Single ivory bone whistle diagonal lower-left to upper-right, hollow mouth opening at one end and three large finger holes, short dark leather lanyard. Not a knife or horn.',
'bg_zaro_8':'Closed red-bound ledger book, deep oxblood leather cover, dark metal corner guards, cream page block and black spine, small clasp; no writing, no crest.'}
jobs=[]
for line in text.splitlines():
    if not line.startswith('| `bg_'):continue
    cols=[s.strip() for s in line.strip('|').split('|')]
    id=cols[0].strip('`');name=cols[1];kind=cols[2];notes=cols[3]
    size={'weapon':[72,32],'armour':[72,72],'trinket':[32,32]}[kind]
    layout='Wide landscape composition in a 9:4 aspect ratio, fills 92 percent width. Handle or hilt on LEFT, head or tip on RIGHT, rising by at most 12 degrees. Entire object inside canvas with transparent margin.' if kind=='weapon' else 'Square composition, centered, fills about 85 percent of canvas. Armour viewed straight from FRONT, empty garment displayed without mannequin or human.' if kind=='armour' else 'Square composition, one compact object centered, fills about 85 percent, clear bold silhouette.'
    prompt=f'''Use case: stylized-concept. Asset type: one game inventory equipment icon, {id}, {name}.
Subject: {notes}. {extra[id]}
Style: painted pixel-art item matching an established dark tactical-fantasy inventory set: crisp stair-step silhouette, chunky connected pixel clusters, limited 4-5 tone ramps per material, restrained weathering, sharp one-native-pixel near-black outline #0b0c0d, top-left lighting. Paint for final {size[0]}x{size[1]} pixels, enlarged cleanly: prioritize large readable material planes over microdetail. No smooth photoreal rendering.
Composition: {layout}
Boss-exclusive lavender #b49ae8 appears ONLY as one tiny band, bead, stitch or gem, under 4 percent of visible object; preserve specified steel/wood/fur/orange/cyan/red colors. Give dark material generous pale grey edge planes so at least 15 percent of opaque pixels have bright highlights. No monochrome purple tint.
Background: genuine transparent alpha, no ground, no cast shadow, no backdrop, no border/frame, no UI, no readable writing/numbers/logos, no person, no hand holding item, no floating effects. ONE item only, no variants or sheet.''' 
    jobs.append(dict(id=id,name=name,kind=kind,native_size=size,notes=notes,design=extra[id],prompt=prompt))
assert len(jobs)==36
(root/'generation_specs.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2),encoding='utf-8')
(root/'.gdignore').write_text('')
print(root)
