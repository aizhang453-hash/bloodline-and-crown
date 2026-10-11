extends TestCase
## 对犯人的处置 (用户 2026-10-11 要的, 照三代): 用刑、刺瞎、阉割、逼他出家、流放, 还有「恐惧」。

var w: World
var k: Person   # 威塞克斯国王 (关人的)
var v: Person   # 他的一个封臣 (关起来的)


func before_each() -> void:
	w = World.load_867(7, {"wars": "off"})
	w.today = w.start_day
	k = w.ruler("wessex")
	k.traits = ["brave", "ambitious", "patient"]  # 不涨压力的性格, 量起来干净
	v = w.vassals_of(k)[0]
	v.prisoner_of = k.id


func test_blind() -> void:
	var m0 := v.skill("martial", w.today)
	var d0 := k.dread
	var r := w.blind(k, v, w.today)
	check(r.ok, r.text)
	check(v.has_trait("blind"))
	eq(v.skill("martial", w.today), maxi(0, m0 - 6), "军事 -6")
	var labels: Array = v.opinion_of(k).parts.map(func(x: Array) -> String: return x[0])
	check(labels.has("刺瞎了我"), "他恨你")
	check(k.dread > d0, "恐惧涨了 (%d)" % int(k.dread))
	check(not w.blind(k, v, w.today).ok, "已经瞎了")
	check(w.people[v.id].looks(w.today).blind, "头像的眼睛画成灰白")


func test_cruelty_stress() -> void:
	k.traits = ["compassionate", "just", "calm"]
	k.stress = 0.0
	w.blind(k, v, w.today)
	eq(k.stress, 160.0, "仁慈 +100、公正 +40、冷静 +20 (照三代)")


func test_castrate() -> void:
	v.claims.append("county:hampshire")
	var r := w.castrate(k, v, w.today)
	check(r.ok, r.text)
	check(v.has_trait("eunuch"))
	eq(v.claims.size(), 0, "宣称没了")
	check(not v.can_inherit(), "不能继承")
	eq(v.fertility(w.today), 0.0, "不能生孩子")
	var girl := w.make_noble("anglo_saxon", true, 20, w.today)
	w._register(girl)
	v.prisoner_of = ""
	check(Marriage.problem(w, v, girl, w.today).contains("阉人"), "不能结婚")
	var boy := w.make_noble("anglo_saxon", false, 8, w.today)
	w._register(boy)
	boy.prisoner_of = k.id
	check(w.castrate(k, boy, w.today).ok)
	check(boy.has_trait("beardless_eunuch"), "不满 12 岁: 无须阉人")
	check(boy.looks(w.today).beardless, "不长胡子")
	var woman := w.make_noble("anglo_saxon", true, 30, w.today)
	w._register(woman)
	woman.prisoner_of = k.id
	check(w.punish_problem(k, woman, "castrate") != "", "只能对男人")


func test_eunuch_skipped_in_succession() -> void:
	var heir := w.heir("wessex", w.today)
	heir.prisoner_of = k.id
	w.castrate(k, heir, w.today)
	check(w.heir("wessex", w.today) != heir, "阉人不能当继承人")


func test_torture() -> void:
	check(w.punish_problem(k, v, "torture").contains("地牢"), "要先关进地牢")
	v.dungeon = true
	var t0 := k.tyranny
	check(w.torture(k, v, w.today, []).ok)
	check(v.has_trait("wounded"), "受伤")
	eq(k.tyranny, t0 + Feudal.TYRANNY_EXECUTE, "没罪的人用刑算暴政")
	check(w.punish_problem(k, v, "torture") != "", "刚用过刑")
	v.decision_used.tortured = -100000
	w.torture(k, v, w.today, [])
	check(v.has_trait("severely_injured") and not v.has_trait("wounded"), "重伤")
	v.decision_used.tortured = -100000
	w.torture(k, v, w.today, [])
	check(v.has_trait("brutally_mauled"), "遍体鳞伤")
	v.decision_used.tortured = -100000
	var r := w.torture(k, v, w.today, [])
	check(not v.alive, "最重了再用刑会死: " + r.text)


func test_torture_confession() -> void:
	v.dungeon = true
	v.secrets.append({"type": "murder", "target": "alfred", "day": w.today, "known": [v.id], "exposed": false})
	for i in 40:
		v.traits = v.traits.filter(func(t: String) -> bool: return not World.WOUNDS.has(t))
		v.decision_used.tortured = -100000
		w.torture(k, v, w.today, [])
		if v.secrets[0].known.has(k.id):
			break
	check(v.secrets[0].known.has(k.id), "用刑招出了秘密")


func test_force_vows() -> void:
	var lands := w.lands_of(v).size()
	check(lands > 0)
	w.rng.seed = 1
	var r := {}
	for i in 30:
		v.decision_used.erase("asked_vows")
		r = w.force_vows(k, v, w.today, [])
		if r.ok:
			break
	check(r.ok, r.text)
	check(v.clergy, "当了修士")
	eq(v.prisoner_of, "", "放出来了")
	check(not w.is_landed(v), "领地传下去了")
	check(not v.can_inherit(), "修士不能继承")
	var norse_k := w.ruler("great_army")
	var q: Person = w.make_noble("norse", false, 30, w.today)
	w._register(q)
	q.prisoner_of = norse_k.id
	check(w.punish_problem(norse_k, q, "vows").contains("基督徒"), "信北欧旧神的没有修道院")


func test_vows_refusal_waits_a_year() -> void:
	v.traits = ["lustful", "cynical", "brave"]
	eq(w.vows_chance(v), 0.2, "好色、愤世的更不肯 (照三代 -30)")
	var refused := false
	for i in 30:
		v.clergy = false
		v.prisoner_of = k.id
		v.decision_used.erase("asked_vows")
		var r := w.force_vows(k, v, w.today, [])
		if not r.ok:
			refused = true
			break
	check(refused)
	check(w.punish_problem(k, v, "vows").contains("一年"), "不肯就过一年再逼")


func test_banish() -> void:
	v.gold = 40.0
	var g0 := k.gold
	var t0 := k.tyranny
	var r := {}
	for i in 30:
		v.decision_used.erase("asked_banish")
		r = w.banish(k, v, w.today, [])
		if r.ok:
			break
	check(r.ok, r.text)
	eq(v.prisoner_of, "")
	check(not w.is_landed(v), "地传下去了")
	eq(k.gold, g0 + 40.0, "钱没收")
	check(v.court.begins_with("r:") and v.court != "r:wessex", "住到别的国家去了: " + v.court)
	eq(k.tyranny, t0 + World.BANISH_TYRANNY, "没理由流放算暴政")
	check(w.intrigue.hook_on(k, v).size() > 0, "你攥着他一个把柄")
	check(w.council.problem(k, "steward", v) != "", "不再是你宫廷里的人")


func test_dread_and_fear() -> void:
	var p := v
	p.traits = ["patient", "calm"]
	k.dread = 0.0
	eq(p.fear_of(k), 0)
	k.dread = 25.0
	eq(p.fear_of(k), 1, "恐惧比胆量高 20: 怕你")
	k.dread = 50.0
	eq(p.fear_of(k), 2, "高 45: 吓坏了")
	p.traits = ["brave"]
	eq(p.fear_of(k), 0, "勇敢的永远不怕")
	p.traits = ["craven"]
	k.dread = 0.0
	eq(p.fear_of(k), 2, "怯懦的永远吓坏了")
	p.traits = ["patient"]
	p.prisoner_of = ""
	var c0 := Feudal.arrest_chance(k, p, w.today)
	k.dread = 30.0
	check(Feudal.arrest_chance(k, p, w.today) > c0, "怕你的人更容易抓到")
	k.dread = 60.0
	eq(w.intrigue._fear_factor(p, k), 0.0, "吓坏了的人不敢暗害你")


func test_dread_drifts() -> void:
	k.dread = 30.0
	k.traits = ["brave"]
	w.advance(60, w.today + 60)
	check(k.dread < 30.0 and k.dread >= 28.9, "每月往本来的恐惧走 0.5 (%.1f)" % k.dread)
	k.traits = ["sadistic"]
	eq(k.natural_dread(), 35.0, "残忍的人本来就让人怕")


func test_execute_gives_dread() -> void:
	var d0 := k.dread
	w.execute(k, v, w.today, [])
	eq(k.dread, d0 + 10.0, "处死有领地的人 +10 (照三代)")


func test_wounds_heal() -> void:
	v.prisoner_of = ""
	v.traits.append("severely_injured")
	var day := w.today
	for i in 200:
		day += 30
		w.advance(30, day)
		if not v.alive or v.physical().is_empty():
			break
	check(not v.alive or v.physical().is_empty(), "伤慢慢好了 (重伤 → 受伤 → 好)")


func test_save() -> void:
	k.dread = 42.0
	w.blind(k, v, w.today)
	var w2 := World.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	eq(w2.people[k.id].dread, k.dread)
	check(w2.people[v.id].has_trait("blind"))


func test_no_vows_for_captured_king() -> void:
	var m := w.ruler("mercia")
	m.prisoner_of = k.id
	check(w.punish_problem(k, m, "vows").contains("国王"), "抓到的国王不能逼他出家 (他是你姐夫也不行)")
	check(w.punish_problem(k, m, "banish") != "", "也不能流放")
	check(w.punish_problem(k, m, "blind") == "", "刺瞎可以")
