"""Record the selected image-generation prompts and painted-source hashes."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent

PROMPTS = {}
REFERENCES = {}

PROMPTS["armed"] = "Use case: stylized-concept. Asset type: source artwork for a Godot pixel-art enemy walking sprite board. Create ONE clean transparent sprite sheet for the character in reference image 1 (the approved pixelated armed enemy). Reference image 2 shows ONLY the eight-direction/four-phase layout and pose language; do not copy its thug character. EXACT COMPOSITION: a uniform 8-column by 4-row matrix of equal square cells, no borders, no labels, no grid lines, transparent empty space around each isolated character. Columns left to right: S/front, SW/front-left, W/true left profile, NW/back-left, N/true back, NE/back-right, E/true right profile, SE/front-right. Rows top to bottom: CONTACT A (left foot planted), PASS A (right foot passing), CONTACT B (right foot planted), PASS B (left foot passing). Maintain the same heading in all four cells of each column. Draw the SAME enemy 32 times, consistent silhouette and scale: elite chibi roughly 2.5 heads tall, white hood and gas mask, black heavy body armor, canister on back, huge blunt two-handed weapon with yellow-black warning bands, dark chunky outline, broad flat pixel-colour masses, muted palette plus warning yellow accent. Weapon stays in hands and never floats. Clear leg, arm and weapon motion; feet at consistent baseline. True back view in N; true profiles in W and E. Visually match reference image 1 exactly in identity and pixel scale after reduction. No other figures, text, numbers, emblems, scenery, lighting bloom, gradients, shadows, or artifacts. The complete grid must fit inside the image without cropped limbs or weapon."
REFERENCES["armed"] = ["../batch_N1_claude/native/armed.png", "../refs_N/style_board_walk_thug.png"]

PROMPTS["caster"] = "Use case: stylized-concept. Make one clean transparent 8-column x 4-row walking sprite board for the exact character in image 1. Image 1 is the APPROVED pixel sprite enlarged eightfold: a GREY HOODED SPELLCASTER in a LONG DARK ROBE, white full-face mask, ORANGE GLOW only on wrist cuffs, BARE HANDS, absolutely NO weapon, NO staff, NO red armband, NO white shirt, NO sword. Image 2 is a layout/pose reference ONLY and depicts an unrelated thug: do not copy its costume, face, weapon or red armbands. Columns S/front, SW, W true profile, NW, N true back, NE, E true profile, SE. Rows CONTACT A, PASS A, CONTACT B, PASS B. Keep direction per column, animate alternating planted feet and robe sway, same size and floor line. Eight equally spaced columns, four equally spaced rows; each cell isolated on genuine transparent alpha with no marks, labels or grid lines. Bold simplified pixel masses, thick dark outline, muted greys and one orange wrist accent. All 32 cells fully inside bounds."
REFERENCES["caster"] = ["reference_x8/caster.png", "../refs_N/style_board_walk_thug.png"]

mine = {
    "shield": "normal chibi, white hood and mask, tactical vest, huge rectangular yellow-black riot shield fixed on LEFT arm, short blade in RIGHT hand; shield consistently oriented toward travel heading, walking legs and shield bounce",
    "slug_volatile": "low four-legged originium slug with cracked dark shell plates, molten orange light in cracks, spider-like legs; crawl gait with alternating leg pairs and stable shell silhouette, no human parts",
    "picket": "normal chibi, padded plain grey hood, gas mask, long dark coat, thin blade in hand and tan rope coiled at belt; blade remains carried and rope stays belted, clear alternating walking legs",
}
for enemy_id, subject in mine.items():
    PROMPTS[enemy_id] = f"Use case: stylized-concept. Asset type: transparent source artwork for a Godot pixel-art enemy walking sprite board. Image 1 is the approved native pixel identity of THIS character. Image 2 shows only the eight-direction/four-phase board layout, not the identity. Draw the character from image 1 exactly: {subject}. EXACT 8-column by 4-row grid of equal square cells, clean transparent background, no labels or grid lines. Columns left to right S/front, SW/front-left, W/true left profile, NW/back-left, N/true back, NE/back-right, E/true right profile, SE/front-right. Rows top to bottom CONTACT A, PASS A, CONTACT B, PASS B. Same direction per column; distinct alternating feet or legs in each row; constant figure size and baseline; complete body inside every cell. Crisp chunky painted pixel-art masses, thick near-black outline, muted palette and only specified accent, approximately 2.5 heads tall for humanoids. No text, emblems, extra props, shadows, scenery, gradients, bloom or cropped body parts. All 32 cells must be clear and uniformly placed."
    REFERENCES[enemy_id] = [f"../batch_N1_claude/native/{enemy_id}.png", "../refs_N/style_board_walk_thug.png"]

city_a = {
    "greytail": "street enforcer with BLACK/GREY STRIPED BANDANA, dark sunglasses and face mask, dark padded vest, steel pipe carried firmly in one hand; cool steel-blue accent",
    "greytail_lord": "larger elite street enforcer with RED STRIPED BANDANA, red sleeve bands, sunglasses, dark heavy vest, longer steel pipe kept in hands; red accent",
    "thrower": "dark hood and WHITE MASK, ragged dark jacket, RED armband, a bottle with an orange burning rag in one hand and lighter in the other; keep both objects carried and flame visible",
}
for enemy_id, identity in city_a.items():
    PROMPTS[enemy_id] = f"Use case: stylized-concept. Asset type: transparent Godot pixel-art walk animation source board. Image 1 is the exact approved N1 sprite of THIS enemy enlarged 8x and MUST determine identity. Image 2 is ONLY a four-phase/eight-direction layout example of a different character. Draw same character as image 1, described: {identity}. Uniform 8 columns x 4 rows of equal cells, each isolated on transparent alpha, no labels, grid, ground or other figures. Column order S/front, SW, W true profile, NW, N true back, NE, E true profile, SE. Row order CONTACT A, PASS A, CONTACT B, PASS B. Maintain heading across each column and consistent figure size, floor line, weapon grip. Distinct alternating foot placements and arm swing in each walking phase; for back views face hidden. Chibi proportions 2.5 heads high, dark thick pixel outline, broad flat masses and muted palette. Keep every figure and carried object fully inside its cell; no readable text, logos, extra weapons, smooth gradients or bloom."
    REFERENCES[enemy_id] = [f"reference_x8/{enemy_id}.png", "../refs_N/style_board_walk_thug.png"]

city_b = {
    "bully": "oversized elite hooded brute with grey hair, a huge blank road-sign plate with red border carried as a battering shield; the sign stays in hands, no digit or text",
    "avenger": "elite dark hood and mask, a long blade in one hand and a short blade in the other connected by chain/ring, tiny yellow tag; both blades stay in hands while walking",
}
for enemy_id, identity in city_b.items():
    PROMPTS[enemy_id] = f"Use case: stylized-concept. Produce one transparent painted pixel-art walking sprite BOARD for Godot. Image 1 is the approved 8x native sprite identity of {enemy_id}. Image 2 demonstrates ONLY 8 directions x 4 walking phases for an unrelated thug; do not copy its outfit or weapon. Exact identity: {identity}. Organize 32 complete character poses in a clean uniform 8-column x 4-row layout, equal square cells, transparent empty space, NO labels or borders. Columns in order S front, SW, W true side, NW, N true back, NE, E true side, SE. Rows CONTACT A, PASS A, CONTACT B, PASS B. Consistent heading down columns, stable proportions and baseline, clearly alternating steps and weight shift, hands continue gripping equipment. Thick dark pixel outline, chunky flat muted masses, one accent. Back columns hide face. No extra figures, text, emblems, digit, ground shadow, scenery, smooth illustration texture, gradients, cropped limbs or equipment."
    REFERENCES[enemy_id] = [f"reference_x8/{enemy_id}.png", "../refs_N/style_board_walk_thug.png"]

PROMPTS["breacher"] = "Use case: stylized-concept. Image 1 is the approved N1 8x pixel identity for breacher. Create a new clean transparent 8-direction x 4-phase WALK SPRITE SHEET: uniform 8 columns x 4 rows of equally spaced square cells, no labels, borders or shadows. Draw the exact riot soldier from reference. A clearly visible BIG SLEDGEHAMMER in the RIGHT hand and a tall rectangular RIOT SHIELD on LEFT arm IN ALL 32 POSES, including all rear angles; the hammer head should protrude beyond the soldier silhouette, held low to the side when walking. Full dark visor helmet, heavy charcoal armor, white shield, one orange-red stripe. Never replace hammer with fist, stick or gun. No thug costume. Columns order S/front, SW, W TRUE PROFILE, NW, N TRUE BACK, NE, E TRUE PROFILE, SE. Rows CONTACT A, PASS A, CONTACT B, PASS B. Heading fixed within each column, same figure scale and floor line, clearly different alternating steps. Chibi pixel art matching reference: broad flat muted masses, very dark thick pixel outline, one accent only. All 32 figures complete within their cell, genuine transparent background, no text, logos, extra objects, gradient, glow haze or cropped equipment."
REFERENCES["breacher"] = ["reference_x8/breacher.png"]

sami_a = {
    "taint_husk": "blue-grey fur hood with rounded beast ears, dark furs, short knife carried low, single bright WHITE EYE STAR visible in all front/side views and hidden in rear views; walk stiff and unnatural",
    "distorted_caster": "tall antlered blue-grey hood and veil, single bright WHITE FACE LIGHT in front/side views, thin ritual blade carried in hand, dark robes; walk stiff, gliding gait, antlers consistent",
    "shattered_champion": "large elite with massive antlers, teal-green ragged cloak, white bone tusks/mask, dark robes, long weapon carried firmly; heavy purposeful walking stride",
}
for enemy_id, identity in sami_a.items():
    PROMPTS[enemy_id] = f"Use case: stylized-concept. One clean transparent 8-direction, 4-phase walking source sprite sheet for Godot. Image 1 is the approved N1 pixel identity at 8x enlargement; preserve exactly. Image 2 is only an eight-column four-row example, with unrelated character. Identity: {identity}. Draw 32 isolated poses in exact uniform 8 columns x 4 rows of equal cells. Columns S/front, SW, W true profile, NW, N true back, NE, E true profile, SE. Rows CONTACT A, PASS A, CONTACT B, PASS B. Same heading in each column, constant figure size and floor baseline, alternating legs/weight and cloak sway, weapon remains in hand. Make eye-light a large solid bright white mass on forward and side views so it survives 28-pixel reduction; no eye-light on back views. Chibi proportion about 2.5 heads tall, very thick near-black pixel outline, broad flat masses, muted cool greys with only the reference accent. Genuine transparent empty cells, no labels, grid lines, extra figures, scenery, glow haze, text, symbols, cropped limbs or weapons."
    REFERENCES[enemy_id] = [f"reference_x8/{enemy_id}.png", "../refs_N/style_board_walk_thug.png"]

sami_b = {
    "shell_vine": "a dark wooden tool box that is ALIVE, normally CLOSED, only a few dull green vine tips emerging from lid seam; no face, no person, no open mouth; the closed box creeps with subtle alternating root/vine placements in four phases",
    "fallen_snowpriest": "white-haired white-robed fur-clad priestess with a solid bright VIOLET FACE ORB and violet-orb staff kept in one hand; both orbs remain visible in front/side views, hidden face orb in true back views, robes move while walking",
}
for enemy_id, identity in sami_b.items():
    PROMPTS[enemy_id] = f"Use case: stylized-concept. Create ONE clean transparent painted pixel-art WALK BOARD for the exact character/creature in image 1, the approved N1 pixel sprite enlarged 8x. Image 2 provides only eight-direction/four-phase layout, not subject. Identity: {identity}. Uniform 8 columns x 4 rows, equal square cells, one fully contained figure in every cell, no labels, no grid lines, genuine transparent space. Columns S/front, SW, W true profile, NW, N true back, NE, E true profile, SE. Rows CONTACT A, PASS A, CONTACT B, PASS B. Maintain same direction in each column and same body size/baseline throughout; show distinct alternating movement each row. Preserve closed-box form if box; four-legged trot if beast; hand holding staff if priestess. Use thick near-black pixel outline and chunky muted flat masses, one specified accent. The priestess's violet face orb and staff orb should each be large enough to survive 30-pixel bake; back view hides face orb. No text, symbols, extra subjects, background, shadow, gradients, glow haze, cropped limbs or props."
    REFERENCES[enemy_id] = [f"reference_x8/{enemy_id}.png", "../refs_N/style_board_walk_thug.png"]

PROMPTS["rock_hornbeast"] = "Use case: stylized-concept. Create a clean transparent 8 by 4 walking sprite board for the EXACT four-legged rock hornbeast in reference image 1. Reference 2 is a previously painted quadruped attempt for fur, stone horns, short hooves, and yellow flowers ONLY; CORRECT ITS HEADINGS. This is a squat four-legged goat beast with a long horizontal body, not a humanoid. Precisely eight direction columns: column 1 S = symmetrical FACE ON looking directly at viewer, both curled horns and both eyes; column 2 SW = three quarter looking down-left; column 3 W = TRUE LEFT PROFILE head facing LEFT, horizontal body with front and hind hooves; column 4 NW = rear three quarter toward upper-left; column 5 N = symmetrical RUMP/back view, face hidden; column 6 NE = rear three quarter toward upper-right; column 7 E = TRUE RIGHT PROFILE head facing RIGHT; column 8 SE = three quarter looking down-right. Four rows: CONTACT A, PASS A, CONTACT B, PASS B, visibly alternate the four hooves and body weight. One figure per equal square cell, 8 columns x 4 rows, fully contained. Thick black pixel outline, chunky flat muted grey-white fur, plated dark stone curled horns and just a few yellow flowers. Genuine transparent background. No labels, borders, text, scenery, humans, extra animals, cropped hooves, duplicated direction or static identical rows."
REFERENCES["rock_hornbeast"] = ["reference_x8/rock_hornbeast.png", "reference_generation/rock_hornbeast_quadruped_attempt.png"]


def main() -> None:
    lines = ["# N2 board generation prompts", "", "Selected source paintings were made with the built-in image generation tool. The files in `source_paintings/` are the selected painted outputs. Clean 320 px-cell boards are assembled from those paintings. Sami lights are restored at native size using the approved N1 stamp method.", "", "# Walking boards", ""]
    for enemy_id in PROMPTS:
        source = HERE / "source_paintings" / f"{enemy_id}_walk_source.png"
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        lines += [f"## {enemy_id}_walk", "", f"Source: `source_paintings/{source.name}` (SHA-256 `{digest}`)", "", "References: " + ", ".join(f"`{ref}`" for ref in REFERENCES[enemy_id]), "", "```text", PROMPTS[enemy_id], "```", ""]
    actions = json.loads((HERE / "action_prompt_records.json").read_text(encoding="utf-8"))
    revisions = json.loads((HERE / "action_revision_prompts.json").read_text(encoding="utf-8"))
    charge_strips = json.loads((HERE / "action_charge_strip_prompt.json").read_text(encoding="utf-8"))
    lines += ["# Action boards", "", "Frame sequences follow `../../../新敌人攻击动画与预警设计案.md` §三. The clean boards are assembled by `build_action.py` from the selected paintings. The source row reuse for greytail_lord RECOVER is recorded in `action_build_report.json`.", ""]
    for enemy_id, record in actions.items():
        source = HERE / "source_paintings" / f"{enemy_id}_action_source.png"
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        refs = [f"reference_x8/{enemy_id}.png", f"{enemy_id}_walk.png", "../refs_N/style_board_action_thug.png"]
        lines += [f"## {enemy_id}_action", "", f"Source: `source_paintings/{source.name}` (SHA-256 `{digest}`)", "", "References: " + ", ".join(f"`{ref}`" for ref in refs), "", f"Rows: {record['rows']}", "", "Initial generation prompt:", "", "```text", record["prompt"], "```", ""]
        if enemy_id in revisions:
            previous = HERE / "source_paintings" / f"{enemy_id}_action_source_v1.png"
            previous_hash = hashlib.sha256(previous.read_bytes()).hexdigest()
            lines += [f"Revision input: `source_paintings/{previous.name}` (SHA-256 `{previous_hash}`)", "", "Selected revision prompt:", "", "```text", revisions[enemy_id], "```", ""]
        if enemy_id in charge_strips:
            strip = HERE / "source_paintings" / f"{enemy_id}_action_charge_source.png"
            strip_hash = hashlib.sha256(strip.read_bytes()).hexdigest()
            lines += [f"Selected CHARGE row: `source_paintings/{strip.name}` (SHA-256 `{strip_hash}`)", "", "Charge-row prompt:", "", "```text", charge_strips[enemy_id], "```", ""]
    (HERE / "generation_prompts.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
