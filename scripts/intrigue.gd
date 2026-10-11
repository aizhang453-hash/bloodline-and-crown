class_name Intrigue
extends RefCounted
## 阴谋的过程 (第 7 块): 暗杀和拉拢 (每人每种同时只能搞一个)、内应、走漏和被发现、秘密 (揭发、勒索)、把柄、电脑搞阴谋、史料里的阴谋。
## 规矩和数字在 Schemes。阴谋是字典 (存档方便); 秘密和把柄记在人身上 (Person.secrets / hooks)。

var w: World
var schemes := {}          # 编号 -> {id, kind, owner, target, start, agents, progress, advantages, breaches, revealed}
var history_done: Array = []
var next_id := 1


func _init(p_world: World) -> void:
	w = p_world


# ---- 查 ----

func scheme_of(owner_id: String, kind: String) -> Dictionary:
	for s in schemes.values():
		if s.owner == owner_id and s.kind == kind:
			return s
	return {}


func schemes_of(owner_id: String) -> Array:
	return schemes.values().filter(func(s: Dictionary) -> bool: return s.owner == owner_id)


## 针对他的阴谋里, 他已经知道的 (走漏时被发现了)
func known_against(target_id: String) -> Array:
	return schemes.values().filter(func(s: Dictionary) -> bool: return s.target == target_id and s.revealed and s.kind == "murder")


func _skill(p: Person, sk: String) -> int:
	return p.skill(sk, w.today)


# ---- 暗杀的几个数 ----

## 多久攒一次机会 (暗杀看密谋, 拉拢看外交)
func phase_days(s: Dictionary) -> float:
	var p: Person = w.people[s.owner]
	if s.kind == "sway":
		return maxf(Schemes.SWAY_MIN, Schemes.SWAY_DAYS - Schemes.SWAY_PER_SKILL * _skill(p, "diplomacy"))
	# 第 9 块: 你的密探头子「支持阴谋」快一些; 对方的密探头子「破坏阴谋」慢一些
	var days := maxf(Schemes.PHASE_MIN, Schemes.PHASE_DAYS - Schemes.PHASE_PER_SKILL * _skill(p, "intrigue") - Councils.SUPPORT_DAYS * w.council.task_skill(p, "support"))
	var guard := _disrupt(s)
	if guard > 0:
		days += Councils.DISRUPT_DAYS + Councils.DISRUPT_PER * guard
	return days


## 保护目标的密探头子在「破坏阴谋」的本事 (0 = 没有)
func _disrupt(s: Dictionary) -> int:
	return w.council.task_skill(w.council.protector(w.people[s.target]), "disrupt")


## 内应跟目标多亲: [说明, 加多少]
func closeness(agent: Person, target: Person) -> Array:
	if agent.id == target.spouse or target.secondary.has(agent.id) or agent.secondary.has(target.id):
		return Schemes.CLOSE["husband" if target.female else "spouse"]
	if w.relation(target, agent) in ["父亲", "母亲", "儿子", "女儿", "哥哥", "弟弟", "姐姐", "妹妹"]:
		return Schemes.CLOSE.close
	if agent.house == target.house and agent.house != "":
		return Schemes.CLOSE.extended
	if w.liege_of(agent) == target:
		return Schemes.CLOSE.vassal
	return ["", 0.0]


## 一个内应能加多少成功率上限: 本事 (密谋、武力) 最多 25 + 跟目标多亲
func agent_value(agent: Person, target: Person) -> float:
	var a := _skill(agent, "intrigue")
	var b := _skill(agent, "prowess")
	var skill := minf(Schemes.AGENT_SKILL_MAX, 0.75 * maxi(a, b) + 0.25 * mini(a, b))
	return skill + float(closeness(agent, target)[1])


## 成功率最高能到多少: 你的密谋 (最多 30) + 内应, 最多 95 → {total, parts}
func potential(s: Dictionary) -> Dictionary:
	var p: Person = w.people[s.owner]
	var t: Person = w.people[s.target]
	var parts := [["你的密谋 %d" % _skill(p, "intrigue"), minf(Schemes.OWN_POTENTIAL_MAX, _skill(p, "intrigue") * Schemes.OWN_POTENTIAL_PER)]]
	for id in s.agents:
		if w.people.has(id):
			var ag: Person = w.people[id]
			var cl: Array = closeness(ag, t)
			parts.append(["内应%s%s" % [ag.name, (" (%s)" % cl[0]) if cl[0] != "" else ""], agent_value(ag, t)])
	var total := 0.0
	for x in parts:
		total += x[1]
	return {"total": minf(Schemes.MAX_SUCCESS, total), "parts": parts}


## 现在动手的成功率 → {total, parts}: 上限 × 攒了几成机会, 攒得多再加; 减他的密谋、身份、打仗、走漏
func success(s: Dictionary) -> Dictionary:
	var p: Person = w.people[s.owner]
	var t: Person = w.people[s.target]
	var pot: float = potential(s).total
	var adv: int = s.advantages
	var parts := [["成功率上限 %d%%, 机会攒了 %d/%d" % [int(pot), mini(adv, Schemes.READY), Schemes.READY], pot * minf(1.0, adv / float(Schemes.READY))]]
	for b in Schemes.BONUS:
		if adv >= int(b[0]):
			parts.append(["机会攒到 %d 次" % int(b[0]), b[1]])
			break
	var ti := _skill(t, "intrigue")
	if ti > 0:
		parts.append(["%s的密谋 %d" % [t.name, ti], -minf(20.0, ti * Schemes.TARGET_INTRIGUE)])
	if _rank(t) > _rank(p):
		parts.append(["%s身份比你高" % t.name, Schemes.VS_HIGHER])
	if w.warfare.hostile(p.id, t.id):
		parts.append(["正在跟他打仗, 他防得严", Schemes.AT_WAR])
	if int(s.breaches) > 0:
		parts.append(["走漏了 %d 次" % int(s.breaches), Schemes.BREACH_SUCCESS * int(s.breaches)])
	var sup := w.council.task_skill(p, "support")
	if sup > 0:
		parts.append(["你的密探头子在支持阴谋", Councils.SUPPORT_SUCCESS + Councils.SUPPORT_PER * sup])
	var total := 0.0
	for x in parts:
		total += x[1]
	return {"total": clampf(total, 0.0, Schemes.MAX_SUCCESS), "parts": parts}


## 身份: 国王 2、有领地 1、别人 0
func _rank(p: Person) -> int:
	if p.realm != "":
		return 2
	return 1 if w.is_landed(p) else 0


## 保密: 40 + 你的密谋 ×2 - 他的密谋; 狡诈、多疑的内应 +5, 诚实的 -5
func secrecy(s: Dictionary) -> float:
	var p: Person = w.people[s.owner]
	var t: Person = w.people[s.target]
	var v := Schemes.SECRECY_BASE + 2.0 * _skill(p, "intrigue") - _skill(t, "intrigue")
	for id in s.agents:
		if w.people.has(id):
			var ag: Person = w.people[id]
			if ag.has_trait("deceitful") or ag.has_trait("paranoid"):
				v += 5.0
			if ag.has_trait("honest"):
				v -= 5.0
	v -= Councils.DISRUPT_SECRECY * _disrupt(s)
	return clampf(v, Schemes.SECRECY_MIN, Schemes.SECRECY_MAX)


## 拉拢成不成的机会
func sway_chance(s: Dictionary) -> float:
	var p: Person = w.people[s.owner]
	var t: Person = w.people[s.target]
	var v := Schemes.SWAY_BASE + 2.0 * _skill(p, "diplomacy")
	if _rank(t) > _rank(p):
		v += Schemes.VS_HIGHER
	return clampf(v, 10.0, 95.0)


# ---- 开始 ----

## 能不能对他搞这种阴谋 (空 = 能)
func start_problem(p: Person, t: Person, kind: String) -> String:
	if p == t:
		return "不能对自己"
	if not t.alive:
		return "人已经去世了"
	if not p.alive or p.prisoner_of != "":
		return "关在大牢里, 搞不了阴谋"
	if not p.adult(w.today):
		return "还不满 16 岁"
	if not scheme_of(p.id, kind).is_empty():
		return "已经在%s%s了 (一种阴谋同时只能搞一个)" % [Schemes.scheme_name(kind), w.people[scheme_of(p.id, kind).target].name]
	if kind == "murder" and (t.father == p.id or t.mother == p.id) and not p.has_trait("sadistic"):
		return "不能对自己的孩子下手"
	if kind == "sway" and p.scheme_blocked.has("sway:" + t.id):
		return "拉拢过他没成, 不能再拉拢他了"
	return ""


func start(p: Person, t: Person, kind: String, day: int, events: Array) -> Dictionary:
	var why := start_problem(p, t, kind)
	if why != "":
		return {"ok": false, "text": why}
	var s := {"id": next_id, "kind": kind, "owner": p.id, "target": t.id, "start": day, "agents": [], "progress": 0.0,
			"advantages": 0, "breaches": 0, "revealed": false}
	next_id += 1
	schemes[s.id] = s
	var stress := 0.0
	if kind == "murder":
		for tr in Schemes.STRESS:
			if p.has_trait(tr):
				stress += Schemes.STRESS[tr]
		p.add_stress(stress)
	events.append({"type": "scheme_start", "scheme": s.id, "owner": p.id, "target": t.id, "kind": kind, "day": day})
	var text := "开始%s%s: 大约每 %d 天攒一次机会" % [Schemes.scheme_name(kind), t.name, int(phase_days(s))] if kind == "murder" else \
			"开始拉拢%s: 大约 %d 天后见分晓 (成的机会 %d%%)" % [t.name, int(phase_days(s)), int(sway_chance(s))]
	if stress > 0.0:
		text += "; 你良心不安, 压力 +%d" % int(stress)
	return {"ok": true, "text": text, "scheme": s.id}


func cancel(s: Dictionary) -> Dictionary:
	schemes.erase(s.id)
	return {"ok": true, "text": "不搞了"}


# ---- 内应 ----

## 能拉来当内应的人: 他的妻子 / 丈夫、近亲、封臣、住在他那里的人 (成年、没关着、不是你自己)
func agent_candidates(s: Dictionary) -> Array:
	var t: Person = w.people[s.target]
	var p: Person = w.people[s.owner]
	var out := []
	var add := func(q: Person) -> void:
		if q != null and q.alive and q != p and q != t and q.adult(w.today) and q.prisoner_of == "" and not out.has(q) and not s.agents.has(q.id):
			out.append(q)
	for id in [t.spouse, t.father, t.mother] + t.secondary:
		add.call(w.people.get(id))
	for q in w.children_of(t) + w.siblings_of(t):
		add.call(q)
	for q in w.vassals_of(t):
		add.call(q)
	var realm := t.realm
	if realm != "":
		for q in w.house_members(t.house):
			if not w.is_landed(q):
				add.call(q)
		for q in w.living.values():
			if q.liege_realm == realm and not w.is_landed(q):
				add.call(q)
	out.sort_custom(func(a: Person, b: Person) -> bool: return agent_value(a, t) > agent_value(b, t))
	return out.slice(0, 24)


## 他肯不肯当内应 (大于 0 就肯) → {total, parts}
func agent_accept(s: Dictionary, q: Person) -> Dictionary:
	var p: Person = w.people[s.owner]
	var t: Person = w.people[s.target]
	var parts := [["没什么好处", -10]]
	var op: int = q.opinion_of(p).total
	if op != 0:
		parts.append(["他对你的好感 %+d" % op, op / 2])
	var ot: int = q.opinion_of(t).total
	if ot != 0:
		parts.append(["他对%s的好感 %+d" % [t.name, ot], -ot / 2])
	if closeness(q, t)[1] >= 10.0 and ot > -30:
		parts.append(["%s是他的%s" % [t.name, "家人"], -50])
	for tr in [["compassionate", "仁慈", -40], ["honest", "诚实", -20], ["craven", "怯懦: 太危险", -30], ["just", "公正", -10],
			["deceitful", "狡诈", 10], ["sadistic", "残忍", 10], ["callous", "冷酷", 10]]:
		if q.has_trait(tr[0]):
			parts.append([tr[1], tr[2]])
	if q.has_trait("vengeful") and ot < 0:
		parts.append(["记仇, %s得罪过他" % t.name, 40])
	var total := 0
	for x in parts:
		total += int(x[1])
	return {"total": total, "parts": parts}


## 拉他入伙: 他自己肯就免费; 不肯但送钱肯就收买; 你攥着他的强把柄就逼他
func invite(s: Dictionary, q: Person, day: int) -> Dictionary:
	var p: Person = w.people[s.owner]
	if s.agents.size() >= Schemes.MAX_AGENTS:
		return {"ok": false, "text": "内应最多 %d 个" % Schemes.MAX_AGENTS}
	var acc: int = agent_accept(s, q).total
	var how := ""
	if acc > 0:
		how = "他答应了"
	elif acc + Schemes.BRIBE_ACCEPT > 0 and p.gold >= Schemes.BRIBE:
		p.gold -= Schemes.BRIBE
		how = "花 %d 金币收买了他" % Schemes.BRIBE
	elif hook_ready(p, q, day):
		use_hook(p, q, day)
		how = "用把柄逼他入伙"
	else:
		return {"ok": false, "text": "%s不肯 (肯不肯 %+d)" % [q.name, acc]}
	s.agents.append(q.id)
	return {"ok": true, "text": "%s成了内应: %s" % [q.name, how]}


## 这个人现在拉不拉得来 (给界面看): {ok, how, acc}
func invite_preview(s: Dictionary, q: Person, day: int) -> Dictionary:
	var p: Person = w.people[s.owner]
	var acc: int = agent_accept(s, q).total
	if acc > 0:
		return {"ok": true, "how": "肯", "acc": acc}
	if acc + Schemes.BRIBE_ACCEPT > 0 and p.gold >= Schemes.BRIBE:
		return {"ok": true, "how": "要 %d 金币" % Schemes.BRIBE, "acc": acc}
	if hook_ready(p, q, day):
		return {"ok": true, "how": "用把柄", "acc": acc}
	return {"ok": false, "how": "不肯", "acc": acc}


# ---- 每天 ----

func daily(day: int, events: Array) -> void:
	if schemes.is_empty():
		return
	for id in schemes.keys():
		if not schemes.has(id):
			continue
		var s: Dictionary = schemes[id]
		var p: Person = w.people[s.owner]
		var t: Person = w.people[s.target]
		if not p.alive or not t.alive or p.prisoner_of != "":
			schemes.erase(id)
			continue
		s.progress += 1.0
		if s.progress < phase_days(s):
			continue
		s.progress = 0.0
		if s.kind == "sway":
			_finish_sway(s, day, events)
			continue
		s.advantages = mini(Schemes.MAX_ADVANTAGES, int(s.advantages) + 1)
		if int(s.advantages) == Schemes.READY and s.owner == w.player:
			events.append({"type": "scheme_ready", "scheme": s.id, "owner": s.owner, "target": s.target, "day": day})
		if s.owner != w.player and int(s.advantages) >= Schemes.READY:
			# 电脑: 成功率够一半就动手; 攒满了还不到四分之一就算了, 够了就硬着头皮上
			var ch: float = success(s).total
			if ch >= 50.0:
				execute(s, day, events)
			elif int(s.advantages) >= Schemes.MAX_ADVANTAGES:
				if ch >= 25.0:
					execute(s, day, events)
				else:
					schemes.erase(s.id)


func _finish_sway(s: Dictionary, day: int, events: Array) -> void:
	schemes.erase(s.id)
	var p: Person = w.people[s.owner]
	var t: Person = w.people[s.target]
	var ok := w.rng.randf() * 100.0 < sway_chance(s)
	if ok:
		t.remember(p.id, "被拉拢了", Schemes.SWAY_GAIN, day + Schemes.SWAY_YEARS * GameDate.YEAR_DAYS, true)
	else:
		t.remember(p.id, "想拉拢我, 被我看穿了", Schemes.SWAY_FAIL, day + 5 * GameDate.YEAR_DAYS, true)
		p.scheme_blocked.append("sway:" + t.id)
	events.append({"type": "sway", "owner": p.id, "target": t.id, "ok": ok, "day": day})


## 动手: 掷成功率; 保密不够就被发现 (他和他家人知道是谁干的)
func execute(s: Dictionary, day: int, events: Array) -> Dictionary:
	if int(s.advantages) < Schemes.READY:
		return {"ok": false, "text": "机会还没攒够 (%d/%d)" % [int(s.advantages), Schemes.READY]}
	var p: Person = w.people[s.owner]
	var t: Person = w.people[s.target]
	var chance: float = success(s).total
	var found_chance := 1.0 if s.revealed else (100.0 - secrecy(s)) / 100.0
	schemes.erase(s.id)
	var ok := w.rng.randf() * 100.0 < chance
	var found := w.rng.randf() < found_chance
	var knowers := _knowers(t)
	if ok:
		_add_secret(p, "murder", t, day, knowers if found else [])
	elif found:
		_add_secret(p, "attempted_murder", t, day, knowers)
	if found:
		for k in knowers:
			if w.people.has(k) and w.people[k].alive and k != t.id:
				w.people[k].remember(p.id, "暗杀了我的家人" if ok else "想暗杀我的家人", -50 if ok else -30, day + 20 * GameDate.YEAR_DAYS)
		if not ok:
			t.remember(p.id, "想暗杀我", -50, day + 20 * GameDate.YEAR_DAYS)
		p.crimes["谋杀" if ok else "谋杀未遂"] = day + Feudal.CRIME_YEARS * GameDate.YEAR_DAYS
	events.append({"type": "murder", "owner": p.id, "target": t.id, "ok": ok, "found": found, "chance": int(chance), "day": day})
	if ok:
		w.kill(t, day, events, "被人暗杀了")
	return {"ok": true, "text": ("得手了: %s死了" % t.name if ok else "没得手, %s逃过一劫" % t.name) + ("; 可是被人发现是你干的!" if found else "; 没人知道是你")}


## 出了事会知道的人: 他自己、近亲、他的国王 (他是封臣的话)
func _knowers(t: Person) -> Array:
	var out := [t.id]
	for f in w._close_family(t):
		out.append(f.id)
	var l := w.liege_of(t)
	if l != null:
		out.append(l.id)
	return out


func _add_secret(p: Person, type: String, t: Person, day: int, knowers: Array) -> void:
	p.secrets.append({"type": type, "target": t.id, "day": day, "known": knowers.duplicate(), "exposed": false})


# ---- 每个月 ----

func monthly(day: int, events: Array) -> void:
	for id in schemes.keys():
		if not schemes.has(id):
			continue
		var s: Dictionary = schemes[id]
		if s.kind != "murder" or day - int(s.start) < Schemes.GRACE_DAYS:
			continue
		# 走漏: 每月的机会是没保住的那部分的十分之一 (照三代)
		if w.rng.randf() * 1000.0 < 100.0 - secrecy(s):
			s.breaches = int(s.breaches) + 1
			if not s.revealed and w.rng.randf() < Schemes.REVEAL_ON_BREACH:
				s.revealed = true
				var t: Person = w.people[s.target]
				t.remember(s.owner, "在密谋害我", -40, day + 10 * GameDate.YEAR_DAYS, true)
				events.append({"type": "scheme_revealed", "scheme": s.id, "owner": s.owner, "target": s.target, "day": day})
			if int(s.breaches) >= Schemes.MAX_BREACHES:
				schemes.erase(id)
				var t2: Person = w.people[s.target]
				_add_secret(w.people[s.owner], "attempted_murder", t2, day, _knowers(t2))
				w.people[s.owner].crimes["谋杀未遂"] = day + Feudal.CRIME_YEARS * GameDate.YEAR_DAYS
				events.append({"type": "scheme_failed", "owner": s.owner, "target": s.target, "day": day})
	_history_schemes(day, events)
	_ai_schemes(day, events)
	_ai_secrets(day, events)


## 史料里的阴谋 (872 年康斯坦丁让人杀了斯特拉斯克莱德国王阿特加尔): 到了那年那月, 两个人都还在位, 电脑开始这个阴谋, 成不成看真的
func _history_schemes(day: int, events: Array) -> void:
	if w.rules.get("wars", "on") != "on":
		return
	var d := GameDate.from_day(day)
	for i in w.history_schemes.size():
		if history_done.has(i):
			continue
		var hs: Dictionary = w.history_schemes[i]
		if int(d[0]) < int(hs.year) or (int(d[0]) == int(hs.year) and int(d[1]) < int(hs.month)):
			continue
		history_done.append(i)
		if not w.realms.has(hs.schemer) or not w.realms.has(hs.target):
			continue
		var p := w.ruler(hs.schemer)
		var t := w.ruler(hs.target)
		if p.id == w.player or start_problem(p, t, hs.kind) != "":
			continue
		var r := start(p, t, hs.kind, day, events)
		if r.ok:
			_ai_agents(schemes[r.scheme], day)


## 电脑搞阴谋 (很少): 狠的人暗杀很恨的人 (好感 -60 以下), 野心大的人暗杀挡在他和王位之间的继承人; 会说话的封臣拉拢国王
func _ai_schemes(day: int, events: Array) -> void:
	for p in w.living.values():
		if p.id == w.player or not p.alive or p.prisoner_of != "" or not p.adult(day):
			continue
		if p.memories.is_empty() or not scheme_of(p.id, "murder").is_empty():
			continue
		if not (p.has_trait("vengeful") or p.has_trait("sadistic") or p.has_trait("callous") or p.has_trait("deceitful")):
			continue
		for m in p.memories:
			if int(m.value) > -30 or not w.people.has(m.who):
				continue
			var t: Person = w.people[m.who]
			if t.alive and w.rng.randf() < 1.0 / 120.0 * _fear_factor(p, t) and p.opinion_of(t).total <= -60 and start_problem(p, t, "murder") == "":
				var r := start(p, t, "murder", day, events)
				if r.ok:
					_ai_agents(schemes[r.scheme], day)
				break
	for rid in w.realm_order:
		if not w.realms.has(rid):
			continue
		var k := w.ruler(rid)
		var h := w.heir(rid, day)
		if h == null or h == k:
			continue
		for q in w.house_members(k.house):
			if q == h or q == k or q.id == w.player or not q.has_trait("ambitious") or q.female or not q.adult(day):
				continue
			if w.rng.randf() < 1.0 / 240.0 * _fear_factor(q, k) and start_problem(q, h, "murder") == "" and q.opinion_of(h).total < 10:
				var r := start(q, h, "murder", day, events)
				if r.ok:
					_ai_agents(schemes[r.scheme], day)
	for rid in w.realm_order:
		if not w.realms.has(rid):
			continue
		var k := w.ruler(rid)
		for v in w.vassals_of(k):
			if v.id != w.player and (v.has_trait("ambitious") or v.has_trait("gregarious")) and w.rng.randf() < 1.0 / 120.0 and start_problem(v, k, "sway") == "":
				start(v, k, "sway", day, events)


## 怕不怕 (照三代「恐惧」): 吓坏了的人根本不敢动手, 怕的人少四分之三
func _fear_factor(p: Person, t: Person) -> float:
	match p.fear_of(t):
		2:
			return 0.0
		1:
			return 0.25
	return 1.0


## 电脑开始阴谋时拉两个肯来的内应
func _ai_agents(s: Dictionary, day: int) -> void:
	var n := 0
	for q in agent_candidates(s):
		if n >= 2:
			break
		if agent_accept(s, q).total > 0:
			s.agents.append(q.id)
			n += 1


## 电脑知道别人的秘密: 记仇或者很讨厌他的就揭发, 别的拿来勒索 (玩家被勒索时弹窗问你)
func _ai_secrets(day: int, events: Array) -> void:
	for owner in w.living.values():
		if owner.secrets.is_empty():
			continue
		for sec in owner.secrets:
			if sec.exposed:
				continue
			for kid in sec.known:
				if kid == owner.id or kid == w.player or not w.people.has(kid) or w.rng.randf() >= 1.0 / 24.0:
					continue
				var k: Person = w.people[kid]
				if not k.alive or not k.adult(day):
					continue
				if k.has_trait("vengeful") or k.opinion_of(owner).total < -30:
					expose(k, owner, sec, day, events)
				elif not hook_on(k, owner).get("strong", false):
					blackmail(k, owner, sec, day, events)
				break
			if sec.exposed:
				break


# ---- 秘密 ----

## viewer 知道的别人的秘密 (没揭发的): [[人, 秘密], ...]
func secrets_known_by(viewer: Person) -> Array:
	var out := []
	for p in w.living.values():
		for sec in p.secrets:
			if not sec.exposed and sec.known.has(viewer.id) and p != viewer:
				out.append([p, sec])
	return out


func secret_text(owner: Person, sec: Dictionary) -> String:
	var t: Person = w.people.get(sec.target)
	return "%s%s%s" % [owner.name, "杀了" if sec.type == "murder" else "想杀", t.name if t != null else "?"]


## 揭发: 他丢威望, 被害人的家人记恨他, 算有罪 (关他、收他的地都不算暴政)
func expose(viewer: Person, owner: Person, sec: Dictionary, day: int, events: Array) -> Dictionary:
	if sec.exposed:
		return {"ok": false, "text": "已经揭发过了"}
	sec.exposed = true
	owner.prestige -= Schemes.EXPOSE_PRESTIGE.get(sec.type, 25.0)
	owner.crimes["谋杀" if sec.type == "murder" else "谋杀未遂"] = day + Feudal.CRIME_YEARS * GameDate.YEAR_DAYS
	owner.remember(viewer.id, "揭发了我", -40, day + 20 * GameDate.YEAR_DAYS)
	var t: Person = w.people.get(sec.target)
	if t != null:
		for f in w._close_family(t) + [t]:
			if f.alive and f != owner:
				f.remember(owner.id, "杀了我的家人" if sec.type == "murder" else "想杀我的家人", -40, day + 20 * GameDate.YEAR_DAYS, true)
	_drop_hooks_of(owner, sec)
	events.append({"type": "exposed", "viewer": viewer.id, "owner": owner.id, "secret": sec.type, "target": sec.target, "day": day})
	return {"ok": true, "text": "揭发了: %s。他丢了 %d 威望, 算有罪 (关他、收他的地不算暴政)" % [secret_text(owner, sec), int(Schemes.EXPOSE_PRESTIGE.get(sec.type, 25.0))]}


## 勒索: 他给你一个强把柄 (照三代: 犯罪的秘密换强把柄), 不给就揭发。玩家被勒索: 事件交给界面问
func blackmail(viewer: Person, owner: Person, sec: Dictionary, day: int, events: Array) -> Dictionary:
	if owner.id == w.player:
		events.append({"type": "blackmail_ask", "viewer": viewer.id, "owner": owner.id, "secret": sec.type, "target": sec.target, "secret_day": int(sec.day), "day": day})
		return {"ok": true, "text": "等他回话"}
	if w.rng.randf() < Schemes.BLACKMAIL_ACCEPT:
		give_hook(viewer, owner, sec)
		events.append({"type": "blackmail", "viewer": viewer.id, "owner": owner.id, "ok": true, "day": day})
		return {"ok": true, "text": "%s服软了: 你攥住了他的把柄 (强)" % owner.name}
	var r := expose(viewer, owner, sec, day, events)
	return {"ok": true, "text": "%s不肯, 你把事情抖了出来。%s" % [owner.name, r.text]}


## 找到这个人身上的那个秘密 (界面上点「给他把柄」时用)
func find_secret(owner: Person, type: String, target: String, day: int) -> Dictionary:
	for sec in owner.secrets:
		if sec.type == type and sec.target == target and int(sec.day) == day:
			return sec
	return {}


# ---- 把柄 ----

func give_hook(holder: Person, target: Person, sec: Dictionary = {}) -> void:
	holder.hooks[target.id] = {"strong": true, "used": -100000, "secret": [sec.get("type", ""), sec.get("target", ""), int(sec.get("day", 0))]}


func hook_on(holder: Person, target: Person) -> Dictionary:
	return holder.hooks.get(target.id, {})


## 把柄现在能不能用 (强的五年一次, 弱的一次)
func hook_ready(holder: Person, target: Person, day: int) -> bool:
	var h := hook_on(holder, target)
	if h.is_empty():
		return false
	return not h.strong or int(h.used) + Schemes.HOOK_COOLDOWN_YEARS * GameDate.YEAR_DAYS <= day


func use_hook(holder: Person, target: Person, day: int) -> bool:
	if not hook_ready(holder, target, day):
		return false
	var h := hook_on(holder, target)
	if h.strong:
		h.used = day
	else:
		holder.hooks.erase(target.id)
	return true


## 他攥着你的强把柄吗 (那你不能对他宣战、不能关他)
func held_by(target: Person, holder: Person) -> bool:
	return hook_on(holder, target).get("strong", false)


## 秘密揭发了, 靠它攥着的把柄就没了
func _drop_hooks_of(owner: Person, sec: Dictionary) -> void:
	var key := [sec.type, sec.target, int(sec.day)]
	for p in w.living.values():
		var h: Dictionary = p.hooks.get(owner.id, {})
		if not h.is_empty() and h.has("secret") and h.secret[0] == key[0] and h.secret[1] == key[1] and int(h.secret[2]) == key[2]:
			p.hooks.erase(owner.id)


# ---- 有人死了 ----

func on_death(p: Person) -> void:
	for id in schemes.keys():
		var s: Dictionary = schemes[id]
		if s.owner == p.id or s.target == p.id:
			schemes.erase(id)
		else:
			s.agents.erase(p.id)


# ---- 存档 ----

func to_save() -> Dictionary:
	return {"schemes": schemes.values(), "history_done": history_done, "next_id": next_id}


func from_save(d: Dictionary) -> void:
	schemes = {}
	for s in d.get("schemes", []):
		s.id = int(s.id)
		s.start = int(s.start)
		s.advantages = int(s.advantages)
		s.breaches = int(s.breaches)
		schemes[s.id] = s
	history_done = d.get("history_done", []).map(func(x: Variant) -> int: return int(x))
	next_id = int(d.get("next_id", 1))
