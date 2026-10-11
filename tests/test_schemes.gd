extends TestCase
## 阴谋 (第 7 块, 用户 2026-10-11 定的): 暗杀、拉拢、内应、秘密 (揭发、勒索)、把柄; 照三代, 数字我们定。

var w: World
var ig: Intrigue


func before_each() -> void:
	w = World.load_867(7, {"wars": "off"})
	ig = w.intrigue


func king(rid: String) -> Person:
	return w.ruler(rid)


## 一天天走 (只走阴谋)
func days(n: int, events: Array = []) -> void:
	for i in n:
		w.today += 1
		ig.daily(w.today, events)


func test_start_murder() -> void:
	var p := king("wessex")
	var t := king("mercia")
	p.traits = ["compassionate", "honest"]
	p.stress = 0.0
	var r := ig.start(p, t, "murder", w.today, [])
	check(r.ok, r.text)
	eq(p.stress, 120.0, "仁慈、诚实的人搞暗杀涨压力 (80 + 40)")
	check(ig.start_problem(p, king("alba"), "murder") != "", "暗杀同时只能搞一个")
	check(ig.start_problem(p, p, "sway") != "", "不能对自己")
	var kid: Person = w.children_of(king("gwynedd"))[0]
	check(ig.start_problem(king("gwynedd"), kid, "murder") != "", "不能对自己的孩子")
	king("gwynedd").traits.append("sadistic")
	eq(ig.start_problem(king("gwynedd"), kid, "murder"), "", "残忍的人可以")


func test_potential_and_success() -> void:
	var p := king("wessex")
	var t := king("mercia")
	p.base_skills.intrigue = 40
	ig.start(p, t, "murder", w.today, [])
	var s := ig.scheme_of(p.id, "murder")
	eq(ig.potential(s).total, Schemes.OWN_POTENTIAL_MAX, "自己最多给 30%")
	eq(ig.success(s).total, 0.0, "还没攒机会")
	s.advantages = 5
	check(ig.success(s).total > 0.0 and ig.success(s).total <= 30.0, "攒够 5 次: 成功率到上限 (再减他的密谋)")
	var before: float = ig.success(s).total
	s.advantages = 10
	check(ig.success(s).total > before, "多攒了加成功率")
	var spouse: Person = w.people[t.spouse]
	s.agents.append(spouse.id)
	check(ig.potential(s).total >= Schemes.OWN_POTENTIAL_MAX + 30.0, "他的妻子当内应 +30 (还有本事)")
	w.warfare.declare(p, {"cb": "de_jure", "target": "duchy:essex", "targets": ["london"], "claimant": "", "cost": 0.0, "label": "x",
			"defender": t.id, "ok": true, "why": "", "truce": false}, w.today, [], true)
	check(ig.success(s).parts.any(func(x: Array) -> bool: return x[1] == Schemes.AT_WAR), "跟他打仗 -50")


func test_advantages_accumulate() -> void:
	var p := king("wessex")
	p.base_skills.intrigue = 20
	ig.start(p, king("mercia"), "murder", w.today, [])
	var s := ig.scheme_of(p.id, "murder")
	w.player = p.id  # 玩家的阴谋不会自己动手
	var ev := []
	days(int(ig.phase_days(s)) * 5 + 1, ev)
	eq(int(s.advantages), 5, "攒了 5 次机会")
	check(ev.any(func(e: Dictionary) -> bool: return e.type == "scheme_ready"), "提醒玩家可以动手")


func test_execute_success_kills_and_secret() -> void:
	var p := king("wessex")
	var t := king("mercia")
	ig.start(p, t, "murder", w.today, [])
	var s := ig.scheme_of(p.id, "murder")
	s.advantages = 20
	p.base_skills.intrigue = 60
	s.agents = [t.spouse]
	# 找一个能得手、又被发现的种子
	for seed in range(1, 400):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed
		if probe.randf() * 100.0 < ig.success(s).total and probe.randf() < (100.0 - ig.secrecy(s)) / 100.0:
			w.rng.seed = seed
			break
	var ev := []
	var r := ig.execute(s, w.today, ev)
	check(r.ok, r.text)
	check(not t.alive, "得手了")
	check(ev.any(func(e: Dictionary) -> bool: return e.type == "death" and e.cause == "被人暗杀了"), "死因: 被人暗杀了")
	eq(p.secrets.size(), 1, "多了一个秘密")
	eq(p.secrets[0].type, "murder")
	check(p.secrets[0].known.size() > 1, "被发现了: 他家里人知道")
	check(Feudal.has_crime(p, w.today), "算有罪")
	check(ig.schemes.is_empty(), "阴谋结束了")


func test_breaches_fail() -> void:
	var p := king("wessex")
	var t := king("mercia")
	p.base_skills.intrigue = 0
	t.base_skills.intrigue = 60
	ig.start(p, t, "murder", w.today, [])
	var s := ig.scheme_of(p.id, "murder")
	eq(ig.secrecy(s), Schemes.SECRECY_MIN, "保密很差")
	var ev := []
	var d := w.today
	for m in 240:
		d += 30
		w.today = d
		ig.monthly(d, ev)
		if not ig.schemes.has(s.id):
			break
	check(not ig.schemes.has(s.id), "走漏 5 次就失败")
	check(ev.any(func(e: Dictionary) -> bool: return e.type == "scheme_failed"))
	check(p.secrets.any(func(x: Dictionary) -> bool: return x.type == "attempted_murder"), "谋杀未遂的秘密")


func test_grace_no_breach() -> void:
	var p := king("wessex")
	p.base_skills.intrigue = 0
	king("mercia").base_skills.intrigue = 60
	ig.start(p, king("mercia"), "murder", w.today, [])
	var s := ig.scheme_of(p.id, "murder")
	for m in 5:
		ig.monthly(w.today + 30 * (m + 1), [])
	eq(int(s.breaches), 0, "开头 6 个月不会走漏")


func test_sway() -> void:
	var p := king("wessex")
	var t := king("mercia")
	p.base_skills.diplomacy = 60
	var before: int = t.opinion_of(p).total
	ig.start(p, t, "sway", w.today, [])
	var ev := []
	days(int(Schemes.SWAY_MIN) + 1, ev)
	var sw := ev.filter(func(e: Dictionary) -> bool: return e.type == "sway")
	eq(sw.size(), 1, "拉拢有结果了")
	if sw.size() == 1 and sw[0].ok:
		eq(t.opinion_of(p).total, mini(100, before + Schemes.SWAY_GAIN), "好感 +25")
	# 没成的不能再拉拢
	var w2 := World.load_867(7, {"wars": "off"})
	var p2 := w2.ruler("wessex")
	var t2 := w2.ruler("mercia")
	p2.base_skills.diplomacy = 0
	p2.scheme_blocked.append("sway:" + t2.id)
	check(w2.intrigue.start_problem(p2, t2, "sway") != "", "拉拢过没成, 不能再拉拢")


func test_agents() -> void:
	var p := king("wessex")
	var t := king("mercia")
	ig.start(p, t, "murder", w.today, [])
	var s := ig.scheme_of(p.id, "murder")
	var cands := ig.agent_candidates(s)
	check(not cands.is_empty(), "有能拉的人")
	var v: Person = w.vassals_of(t)[0]
	v.traits = ["compassionate", "honest"]
	check(ig.agent_accept(s, v).total < 0, "仁慈诚实的不肯")
	p.gold = 0.0
	check(not ig.invite(s, v, w.today).ok, "没钱收买, 拉不来")
	ig.give_hook(p, v)
	check(ig.invite(s, v, w.today).ok, "攥着他的把柄, 逼他入伙")
	check(s.agents.has(v.id))
	check(not ig.hook_ready(p, v, w.today), "强把柄五年内不能再用")


func test_expose_and_blackmail() -> void:
	var p := king("wessex")
	var o: Person = w.people["aethelwulf_berkshire"]
	var victim := king("mercia")
	o.secrets.append({"type": "murder", "target": victim.id, "day": w.today, "known": [p.id], "exposed": false})
	eq(ig.secrets_known_by(p).size(), 1, "你知道他的秘密")
	var pres: float = o.prestige
	var ev := []
	ig.expose(p, o, o.secrets[0], w.today, ev)
	eq(o.prestige, pres - Schemes.EXPOSE_PRESTIGE.murder, "丢威望")
	check(Feudal.has_crime(o, w.today), "算有罪")
	eq(Feudal.revoke_tyranny(w, o, w.today), 0.0, "收他的地不算暴政")
	eq(ig.secrets_known_by(p).size(), 0, "揭发了就不是秘密了")
	# 勒索: 肯就给强把柄
	var q: Person = w.people["wulfhere_wiltshire"]
	q.secrets.append({"type": "attempted_murder", "target": victim.id, "day": w.today, "known": [p.id], "exposed": false})
	w.rng.seed = 1
	for seed in range(1, 200):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed
		if probe.randf() < Schemes.BLACKMAIL_ACCEPT:
			w.rng.seed = seed
			break
	ig.blackmail(p, q, q.secrets[0], w.today, [])
	check(ig.held_by(q, p), "勒索成了: 你攥着他的强把柄")
	check(w.arrest_problem(q, p) != "", "他不能关你")
	# 把柄靠的秘密揭发了, 把柄就没了
	ig.expose(p, q, q.secrets[0], w.today, [])
	check(not ig.held_by(q, p), "秘密揭发了, 把柄没了")


func test_hooks_in_marriage_arrest_war() -> void:
	var p := king("wessex")
	w.player = p.id
	var t := king("mercia")
	ig.give_hook(p, t)
	var o := w.warfare.cb_options(t, p)
	check(o.all(func(x: Dictionary) -> bool: return not x.ok), "攥着他的强把柄: 他不能对你宣战")
	var v: Person = w.people["wulfhere_wiltshire"]
	ig.give_hook(p, v)
	v.base_skills.intrigue = 100
	var r := w.arrest(p, v, w.today, [])
	check(r.ok, "强把柄: 一定抓到")
	check(not ig.hook_ready(p, v, w.today), "用掉了 (五年后才能再用)")


func test_on_death_and_save() -> void:
	var p := king("wessex")
	var t := king("mercia")
	ig.start(p, t, "murder", w.today, [])
	w.kill(t, w.today, [])
	check(ig.schemes.is_empty(), "目标死了, 阴谋没了")
	ig.start(p, king("alba"), "murder", w.today, [])
	ig.give_hook(p, king("alba"))
	var d := w.to_save()
	var w2 := World.from_save(JSON.parse_string(JSON.stringify(d, "", false, true)))
	eq(w2.intrigue.schemes.size(), 1, "存档带着阴谋")
	check(w2.intrigue.held_by(w2.ruler("alba"), w2.ruler("wessex")), "存档带着把柄")


func test_history_scheme_872() -> void:
	var w2 := World.load_867(7)
	var f := w2.intrigue
	var ev := []
	f.monthly(GameDate.to_day(872, 1, 1), ev)
	if w2.realms.has("alba") and w2.realms.has("strathclyde"):
		var s := f.scheme_of(w2.ruler("alba").id, "murder")
		check(not s.is_empty() and s.target == w2.ruler("strathclyde").id, "872 年康斯坦丁开始暗杀阿特加尔")
	var w3 := World.load_867(7, {"wars": "off"})
	w3.intrigue.monthly(GameDate.to_day(872, 1, 1), [])
	check(w3.intrigue.schemes.is_empty(), "「历史上的仗和阴谋」关了就没有")


func test_long_run_schemes() -> void:
	var w2 := World.load_867(21)
	var day := w2.start_day
	var count := {}
	for m in 40 * 12:
		day += 30
		for e in w2.advance(30, day):
			if e.type in ["murder", "sway", "scheme_failed", "exposed", "blackmail", "scheme_revealed"]:
				count[e.type] = count.get(e.type, 0) + 1
		for s in w2.intrigue.schemes.values():
			check(w2.people[s.owner].alive and w2.people[s.target].alive, "阴谋的两个人都活着")
	print("    四十年的阴谋: ", count)
	check(count.get("murder", 0) >= 1, "四十年里有人搞过暗杀")
	check(count.get("murder", 0) <= 60, "暗杀不能太多 (%d)" % count.get("murder", 0))
