extends TestCase
## 议会 (第 9 块, 用户 2026-10-11 说「照你的推荐做」): 五个大臣、派活、有实力的封臣、编造宣称、打探秘密……

var w: World
var c: Councils


func before_each() -> void:
	w = World.load_867(7, {"wars": "off"})
	w.today = w.start_day
	c = w.council


func king(rid: String) -> Person:
	return w.ruler(rid)


func test_start_councils_filled() -> void:
	for rid in w.realm_order:
		var k := king(rid)
		for seat in Councils.SEATS:
			var q := c.member(k, seat)
			check(q != null, "%s开局%s有人" % [rid, seat])
			if q == null:
				continue
			eq(c.problem(k, seat, q), "", "%s的%s%s能当" % [rid, seat, q.name])
	eq(c.seat_name(king("wessex"), "chaplain"), "宫廷牧师")
	eq(c.seat_name(king("great_army"), "chaplain"), "祭司", "信北欧旧神的叫祭司")


func test_who_can_serve() -> void:
	var k := king("wessex")
	var wife: Person = k.living_spouse()
	check(wife != null)
	check(c.problem(k, "steward", wife).contains("女人"), "女人只当心腹")
	check(c.problem(k, "steward", k) != "", "不能是自己")
	var foreign: Person = w.vassals_of(king("mercia"))[0]
	check(c.problem(k, "steward", foreign) != "", "别国的封臣不行")
	var v: Person = w.vassals_of(k)[0]
	v.prisoner_of = k.id
	check(c.problem(k, "steward", v).contains("大牢"))
	v.prisoner_of = ""
	var norse := c.make_local(king("great_army"), "chaplain", w.rng)
	check(c.problem(k, "chaplain", norse) != "", "宗教大臣要同一个信仰 (也要住在你的宫廷)")


func test_appoint_fire_and_powerful() -> void:
	var k := king("wessex")
	var pv := c.powerful_vassals(k)
	check(pv.size() >= 2, "威塞克斯有实力的封臣 %d 个" % pv.size())
	var seat := c.seat_of(k, pv[0])
	check(seat != "", "电脑开局让有实力的封臣进了议会")
	var r := c.fire(k, seat, w.today)
	check(r.ok, r.text)
	eq(c.member(k, seat), null)
	var parts: Array = pv[0].opinion_of(k).parts.map(func(x: Array) -> String: return x[0])
	check(parts.has("把我撤出了议会"), "撤掉的人记恨")
	check(parts.has("我有实力, 却没让我进议会"), "有实力的封臣没进议会 -40")
	r = c.appoint(k, seat, pv[0], w.today)
	check(r.ok, r.text)
	parts = pv[0].opinion_of(k).parts.map(func(x: Array) -> String: return x[0])
	check(not parts.has("我有实力, 却没让我进议会"), "进了议会就好了")


func test_domestic_and_taxes() -> void:
	var k := king("wessex")
	var v: Person = w.vassals_of(k)[0]
	c.set_task(k, "chancellor", "domestic")
	var sk := c.task_skill(k, "domestic")
	check(sk > 0)
	var found := false
	for x in v.opinion_of(k).parts:
		if x[0] == "首相在办内政":
			found = true
			eq(int(x[1]), int(Councils.DOMESTIC_OPINION * sk))
	check(found, "首相办内政: 封臣好感涨")
	var g1: float = w.income(k).own_gold
	c.councils["r:wessex"].steward.who = ""
	var g0: float = w.income(k).own_gold
	check(g1 > g0, "管家收税: 直辖领地的钱多 (%.2f > %.2f)" % [g1, g0])


func test_fabricate_claim_gives_war_reason() -> void:
	var k := king("mercia")
	var r := c.set_task(k, "chaplain", "fabricate", "dyfed")
	check(not r.ok, "德费德不挨着麦西亚")
	var opts := c.target_options(k, "fabricate")
	check(not opts.is_empty())
	var target: String = opts[0]
	r = c.set_task(k, "chaplain", "fabricate", target)
	check(r.ok, r.text)
	w.player = k.id  # 玩家的牧师不会因为手里有宣称就停下
	for i in 60:
		w.today += 30
		c.monthly(w.today, [])
		if k.claims.has("county:" + target):
			break
	check(k.claims.has("county:" + target), "编好了宣称")
	var holder := w.ruler(w.by_id[target].holder)
	var cbs: Array = w.warfare.cb_options(k, holder).filter(func(o: Dictionary) -> bool: return o.cb == "claim" and o.targets.has(target))
	check(not cbs.is_empty(), "能拿宣称宣战")


func test_ai_waits_with_spare_claim() -> void:
	var k := king("mercia")
	var target: String = c.target_options(k, "fabricate")[0]
	k.claims.append("county:" + target)
	check(c.ai_has_spare_claim(k))
	var s: Dictionary = c.councils["r:mercia"].chaplain
	s.progress = 50.0
	c.monthly(w.today + 30, [])
	eq(float(s.progress), 50.0, "电脑手里还有没用上的宣称, 先不编新的")


func test_integrate_title() -> void:
	var k := king("alba")
	k.gold = 400.0
	check(w.create_title(k, "kingdom", "scotland", w.today, []).ok)
	check(c.task_problem(k, "integrate") != "", "公国头衔都在苏格兰里, 没东西整合")
	w.realms.alba.titles.append("bernicia")
	eq(c.task_problem(k, "integrate"), "")
	check(c.set_task(k, "chancellor", "integrate").ok)
	eq(c.councils["r:alba"].chancellor.target, "bernicia")
	w.player = k.id
	for i in 120:
		w.today += 30
		c.monthly(w.today, [])
		if w.duchies.bernicia.kingdom == "scotland":
			break
	eq(w.duchies.bernicia.kingdom, "scotland", "伯尼西亚整合进了苏格兰王国")


func test_find_secrets() -> void:
	var k := king("wessex")
	w.player = k.id
	var v: Person = w.vassals_of(k)[0]
	v.secrets.append({"type": "murder", "target": "alfred", "day": w.today, "known": [v.id], "exposed": false})
	c.set_task(k, "spymaster", "secrets")
	for i in 600:
		c._work(k, c.councils["r:wessex"], w.today, [])
		if v.secrets[0].known.has(k.id):
			break
	check(v.secrets[0].known.has(k.id), "密探头子查出了秘密")


func test_disrupt_and_support() -> void:
	var a := king("mercia")
	var t := king("wessex")
	a.traits = ["sadistic", "deceitful", "ambitious"]
	var r := w.intrigue.start(a, t, "murder", w.today, [])
	check(r.ok, r.text)
	var sc: Dictionary = w.intrigue.schemes[int(r.scheme)]
	c.set_task(t, "spymaster", "support")
	var d0 := w.intrigue.phase_days(sc)
	var s0 := w.intrigue.secrecy(sc)
	c.set_task(t, "spymaster", "disrupt")
	check(w.intrigue.phase_days(sc) > d0, "对方的密探头子破坏阴谋: 慢了")
	check(w.intrigue.secrecy(sc) < s0, "也容易被发现")
	c.set_task(a, "spymaster", "support")
	var labels: Array = w.intrigue.success(sc).parts.map(func(x: Array) -> String: return x[0])
	check(labels.has("你的密探头子在支持阴谋"), "支持阴谋加成功率")


func test_marshal() -> void:
	var k := king("wessex")
	var cap: Dictionary = w.by_id[w.realms.wessex.capital]
	c.set_task(k, "marshal", "train")
	var g0 := w.warfare.max_garrison(cap)
	c.set_task(k, "marshal", "organize")
	check(w.warfare.max_garrison(cap) > g0, "整顿军队: 守军多")
	var a := {"owner": k.id, "levy": 1000.0}
	var u1 := w.warfare.upkeep(a)
	c.councils["r:wessex"].marshal.who = ""
	check(w.warfare.upkeep(a) > u1, "整顿军队: 养兵便宜")


func test_local_cleric() -> void:
	var k := king("wessex")
	var q := c.make_local(k, "chaplain", w.rng)
	check(q.clergy, "基督徒的宫廷牧师请来的是修士")
	check(not w.people.has(q.id), "选上以前不在世界里")
	var r := c.appoint(k, "chaplain", q, w.today)
	check(r.ok, r.text)
	check(w.people.has(q.id) and q.court == "r:wessex", "选上了住进宫廷")
	var girl := w.make_noble("anglo_saxon", true, 25, w.today)
	w._register(girl)
	check(Marriage.problem(w, q, girl, w.today).contains("修士"), "修士不结婚")


func test_councillor_leaves() -> void:
	var k := king("wessex")
	w.player = k.id
	var q := c.member(k, "marshal")
	w.kill(q, w.today, [])
	var ev := []
	c.monthly(w.today + 30, ev)
	eq(c.member(k, "marshal"), null, "玩家的大臣死了位子空着 (玩家自己挑)")
	check(not ev.filter(func(e: Dictionary) -> bool: return e.type == "council_left").is_empty(), "告诉玩家")
	var m := king("mercia")
	var q2 := c.member(m, "marshal")
	w.kill(q2, w.today, [])
	c.monthly(w.today + 60, [])
	check(c.member(m, "marshal") != null and c.member(m, "marshal") != q2, "电脑马上补人")


func test_save() -> void:
	var k := king("wessex")
	c.set_task(k, "chancellor", "foreign")
	c.councils["r:wessex"].chaplain.progress = 42.0
	var w2 := World.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	eq(w2.council.councils["r:wessex"].chancellor.task, "foreign")
	eq(float(w2.council.councils["r:wessex"].chaplain.progress), 42.0)
	eq(w2.council.member(w2.ruler("wessex"), "marshal").id, c.member(k, "marshal").id)
