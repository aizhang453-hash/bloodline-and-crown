class_name Decisions
extends RefCounted
## 决议 (第 8 块, 照三代): 建立公国 / 王国 / 帝国 (别人拿着就是篡夺)、当地的特别决议 (丹麦法区、群岛王国、坎布里亚王国)、
## 排解压力的决议 (染上的毛病带的, 三年一次)。界面列出能做的, 差一点的也列 (写清楚还差什么); 电脑每个月看一次。

const COPING_YEARS := 3


## 给界面的一行行: [{id, name, icon, desc, ok, why, harsh, do: Callable(events) -> {ok, text}}]
static func list_for(w: World, p: Person) -> Array:
	var rows := []
	var day := w.today
	if p.realm != "" and w.realms.has(p.realm):
		var rid := p.realm
		for kind in ["empire", "kingdom", "duchy"]:
			for id in _title_ids(w, kind):
				var ctl := w.title_control(kind, id, rid)
				if ctl[1] == 0 or w.title_holder(kind, id) == rid:
					continue
				# 控制了三成以上才列出来 (帝国五成以上), 免得一长串够不着的
				if float(ctl[0]) < ctl[1] * (0.5 if kind == "empire" else 0.3):
					continue
				var why := w.create_problem(p, kind, id)
				var holder := w.title_holder(kind, id)
				var verb := "篡夺" if holder != "" else "建立"
				var k: String = kind
				var tid: String = id
				rows.append({"id": "%s:%s" % [kind, id], "name": "%s%s" % [verb, w.title_name(kind, id)], "icon": {"empire": "imperial_crown", "kingdom": "crown", "duchy": "coronet"}[kind],
						"desc": "控制了 %d/%d 块地 (要%s以上) · 花 %d 金币 · 威望 +%d%s" % [ctl[0], ctl[1], "八成" if kind == "empire" else "一半", World.TITLE_COST[kind], int(World.TITLE_PRESTIGE[kind]),
							(" · 现在在%s手里" % w.realm_name(holder)) if holder != "" else ""],
						"tip": _title_tip(w, kind, id, holder),
						"ok": why == "", "why": why, "harsh": true, "do": func(ev: Array) -> Dictionary: return w.create_title(p, k, tid, day, ev)})
		for sid in World.SPECIALS:
			if not _special_relevant(w, p, sid):
				continue
			var why := w.special_problem(p, sid)
			var s: String = sid
			rows.append({"id": sid, "name": World.SPECIALS[sid][0], "icon": "crown", "desc": World.SPECIALS[sid][1],
					"tip": World.SPECIALS[sid][1] + _special_cost(sid),
					"ok": why == "", "why": why, "harsh": true, "do": func(ev: Array) -> Dictionary: return w.special_decision(p, s, day, ev)})
	for t in p.coping():
		var info := Traits.get_trait(t)
		var dec: Dictionary = info.decision
		var ready := int(p.decision_used.get(t, -100000)) + COPING_YEARS * GameDate.YEAR_DAYS <= day
		var tr: String = t
		rows.append({"id": "coping:" + t, "name": dec.name, "icon": "candle", "desc": "%s · 压力 -%d%s · 三年一次" % [dec.desc, int(dec.stress), _coping_side(dec)],
				"ok": ready, "why": "三年内做过了", "harsh": false, "do": func(_ev: Array) -> Dictionary: return coping(w, p, tr, day)})
	return rows


static func _title_ids(w: World, kind: String) -> Array:
	match kind:
		"duchy":
			return w.duchies.keys()
		"kingdom":
			return w.kingdoms.keys()
	return ["britannia"]


static func _title_tip(w: World, kind: String, id: String, holder: String) -> String:
	var lines := [w.title_name(kind, id)]
	match kind:
		"duchy":
			lines.append("建立了以后: 对这个公国里别人的地有「法理」宣战理由")
		"kingdom":
			lines.append("建立了以后: 你成了%s, 直辖上限 +1, 每月威望多 0.5;" % w.kingdom_ruler_title(id))
			lines.append("对这个王国里别人的地都有「法理」宣战理由")
		_:
			lines.append("建立了以后: 你成了不列颠皇帝, 直辖上限 +2, 每月威望多 1; 对整个不列颠群岛都有「法理」宣战理由")
	if holder != "":
		lines.append("现在在%s手里: 你控制的地更多, 可以篡夺过来 (他会恨你)" % w.realm_name(holder))
	return "\n".join(lines)


static func _special_relevant(w: World, p: Person, id: String) -> bool:
	match id:
		"danelaw":
			return w._norse(p) and w.title_control("kingdom", "england", p.realm)[0] > 0
		"k_isles":
			return w._norse(p) and w.title_control("duchy", "isles", p.realm)[0] > 0
		"k_cumbria":
			return p.culture == "cumbric"
	return false


static func _special_cost(id: String) -> String:
	if id == "danelaw":
		return "\n花 %d 威望; 对方答应才成 (他比你强得多又不喜欢你就不答应); 五年内只能谈一次" % int(World.DANELAW_PRESTIGE)
	return "\n花 %d 金币, 威望 +200" % World.SPECIAL_COST.get(id, 0)


static func _coping_side(dec: Dictionary) -> String:
	var parts := []
	if dec.has("gold"):
		parts.append("金钱 %d" % int(dec.gold))
	if dec.has("prestige"):
		parts.append("威望 %d" % int(dec.prestige))
	if dec.has("health"):
		parts.append("%d%% 伤身体" % int(float(dec.health_chance) * 100))
	return (" · " + "、".join(parts)) if not parts.is_empty() else ""


## 排解压力的决议: 压力降下来, 有的花钱、丢面子、伤身体
static func coping(w: World, p: Person, t: String, day: int) -> Dictionary:
	var dec: Dictionary = Traits.get_trait(t).decision
	if int(p.decision_used.get(t, -100000)) + COPING_YEARS * GameDate.YEAR_DAYS > day:
		return {"ok": false, "text": "三年内做过了"}
	p.decision_used[t] = day
	p.add_stress(-float(dec.stress))
	var notes := ["压力 -%d" % int(dec.stress)]
	if dec.has("gold"):
		p.gold += float(dec.gold)
		notes.append("金钱 %d" % int(dec.gold))
	if dec.has("prestige"):
		p.prestige += float(dec.prestige)
		notes.append("威望 %d" % int(dec.prestige))
	if dec.has("health") and w.rng.randf() < float(dec.health_chance):
		p.conditions.append({"text": "%s伤了身体" % dec.name, "health": float(dec.health), "until": day + GameDate.YEAR_DAYS})
		notes.append("伤了身体 (一年)")
	return {"ok": true, "text": "%s: %s" % [dec.name, "、".join(notes)]}


## 电脑每个月: 能建立的头衔有钱就建 (平均半年想一次), 特别决议一年想一次; 压力大的人用解压的决议
static func ai_monthly(w: World, day: int, events: Array) -> void:
	for rid in w.realm_order.duplicate():
		if not w.realms.has(rid):
			continue
		var k := w.ruler(rid)
		if k.id == w.player:
			continue
		if w.rng.randf() < 1.0 / 6.0:
			for kind in ["empire", "kingdom", "duchy"]:
				var done := false
				for id in _title_ids(w, kind):
					var holder := w.title_holder(kind, id)
					if holder != "" and w.allies(k.realm).has(holder):
						continue  # 电脑不篡夺盟友的头衔
					if w.create_problem(k, kind, id) == "" and k.gold >= World.TITLE_COST[kind] + 30:
						w.create_title(k, kind, id, day, events)
						done = true
						break
				if done:
					break
		if w.rng.randf() < 1.0 / 12.0:
			for sid in World.SPECIALS:
				if w.special_problem(k, sid) == "":
					w.special_decision(k, sid, day, events)
					break
	for p in w.living.values():
		if p.id == w.player or p.stress < 100.0 or p.coping().is_empty():
			continue
		for t in p.coping():
			if int(p.decision_used.get(t, -100000)) + COPING_YEARS * GameDate.YEAR_DAYS <= day:
				coping(w, p, t, day)
				break
