class_name RelationsScreen
extends RefCounted

## Every faction's relation on one page (用户 2026-10-24: 统一的查看各势力好感度的页面),
## the sand table's second tab: rank, the way to the next rank and what each
## rank opens. Data, state and buttons only (用户: 界面不写说明文字).

const TOP := BaseScreens.TOP
const BOTTOM := BaseScreens.BOTTOM
const COLS := 3
const CARD := Vector2(408, 200)
const GAP := 8.0

## rank -> what it opens with `faction`, from the rules that check it.
static func unlocks(ex: Exchange, faction: String) -> Dictionary:
	var out := {}
	var add := func(r: int, text: String) -> void:
		if not out.has(r): out[r] = []
		(out[r] as Array).append(text)
	var info := FactionCatalog.info(faction)
	if not info.get("transport", false) and not ex.forward_materials(faction).is_empty():
		for lev in Exchange.LEVERAGES: add.call(int(lev), "远期 %d×" % int(lev))
	if faction in FactionCatalog.CFD_ISSUERS:
		for lev in Exchange.LEVERAGES: add.call(int(lev), "差价合约 %d×" % int(lev))
	for material in FactionSpecials.ITEMS:
		if FactionSpecials.faction_of(material) == faction: add.call(FactionSpecials.rank_needed(material), material)
	for id in BaseCatalog.FACILITIES:
		var gate: Dictionary = BaseCatalog.FACILITIES[id].get("gate", {})
		if str(gate.get("faction", "")) == faction: add.call(int(gate.rank), str(BaseCatalog.FACILITIES[id].name))
	if faction == "penguin": add.call(Provisions.MAIL_RANK, "寄送补给")
	if faction == GameManager.DIRECTED_FACTION:
		var top := Exchange.RANK_AT.size() - 1
		add.call(top, "定向重铸")
		for id in ResearchCatalog.all_ids():
			if "lungmen_r5" in ResearchCatalog.conditions(id): add.call(top, ResearchCatalog.name_of(id))
	return out

static func page(menu: FieldMenu, stage: Control) -> void:
	var ex := menu.game.exchange
	for i in range(FactionCatalog.ORDER.size()):
		var at := Vector2(16 + (i % COLS) * (CARD.x + GAP), TOP + 6 + (i / COLS) * (CARD.y + GAP))
		_card(ex, stage, FactionCatalog.ORDER[i], at)

static func _card(ex: Exchange, stage: Control, f: String, at: Vector2) -> void:
	var rel := ex.relation(f)
	var r := ex.rank(f)
	var top := Exchange.RANK_AT.size() - 1
	stage.add_child(AK.rect(AK.PLATE_2, at, CARD))
	stage.add_child(AK.rect(AK.HOLO if r >= top else AK.LINE, at, Vector2(4, CARD.y)))
	var title := AK.label(FactionCatalog.name_of(f), 16, AK.FG)
	title.clip_text = true
	AK.put(stage, title, at + Vector2(14, 8), Vector2(CARD.x - 84, 0))
	AK.refit(title)
	AK.put(stage, AK.label(str(FactionCatalog.info(f).get("region", "")), 11, AK.MUTE), at + Vector2(14, 32))
	var badge := AK.label("R%d" % r, 22, AK.SP if r >= top else AK.FG, AK.en())
	AK.put(stage, badge, at + Vector2(CARD.x - 56, 6))
	# The way from this rank's start to the next one's.
	var lo: int = Exchange.RANK_AT[r]
	var hi := Exchange.next_rank_at(rel)
	var ratio := 1.0 if r >= top else float(rel - lo) / float(maxi(1, hi - lo))
	var bar_at := at + Vector2(14, 54)
	var bar_w := CARD.x - 28
	stage.add_child(AK.rect(Color(0, 0, 0, 0.6), bar_at, Vector2(bar_w, 6)))
	stage.add_child(AK.rect(AK.HOLO, bar_at, Vector2(bar_w * clampf(ratio, 0.0, 1.0), 6)))
	var drift := ex.relation_drift(f)
	AK.put(stage, AK.label("%d / %d%s" % [rel, hi, ("   修正 −%d/日" % drift) if drift > 0 else ""], 12, AK.FG, AK.en()), at + Vector2(14, 64))
	if not FactionCatalog.info(f).get("transport", false):
		AK.put(stage, AK.label("远程费 %.1f%%  ·  额度 %s" % [ex.remote_fee(f) * 100.0, Economy.format(roundi(ex.quota_cap(f)))], 11, AK.MUTE), at + Vector2(14, 82))
	var opens := unlocks(ex, f)
	var y := 102.0
	for k in range(1, top + 1):
		if not opens.has(k): continue
		var color := AK.GREEN if k <= r else (AK.SP if k == r + 1 else AK.DIM)
		var line := AK.label("R%d  %s" % [k, "  ·  ".join(PackedStringArray(opens[k]))], 12, color)
		line.clip_text = true
		AK.put(stage, line, at + Vector2(14, y), Vector2(CARD.x - 28, 0))
		y += 18
