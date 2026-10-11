extends TestCase
## 随机事件和压力崩溃 (第 8 块, 用户 2026-10-11 看了单子说可以): 31 个事件、照史料来的事件带历史背景、崩溃三档。

var w: World
var st: StoryEvents


func before_each() -> void:
	w = World.load_867(11, {"wars": "off"})
	w.today = w.start_day
	st = w.story


func king(rid: String) -> Person:
	return w.ruler(rid)


func def_of(id: String) -> Dictionary:
	for d in StoryEvents.defs():
		if d.id == id:
			return d
	return {}


func test_defs() -> void:
	var defs := StoryEvents.defs()
	eq(defs.size(), 31, "第一批 31 个事件")
	var ids := {}
	for d in defs:
		check(not ids.has(d.id), "事件 id 不重复: " + d.id)
		ids[d.id] = true
		check(not d.options.is_empty(), d.id + " 有选项")
		check(d.title != "", d.id + " 有标题")
		eq(d.has("history"), d.cat == "史料", d.id + ": 只有照史料来的事件带历史背景")
		for o in d.options:
			for t in o.get("stress", {}):
				check(not Traits.get_trait(t).is_empty(), "%s 的压力写的性格 %s 存在" % [d.id, t])


## 每个事件都凑一个能出的情形, 每个选项都选一遍: 不出错、字里没有没填的 %、不写「随机」「史料」这些
func test_every_event_every_option() -> void:
	var me := king("wessex")
	w.player = me.id
	var seen := 0
	for d in StoryEvents.defs():
		for i in d.options.size():
			var w2 := World.load_867(11, {"wars": "off"})
			var c := _setup(w2, d.id)
			if c.is_empty():
				continue
			if not d.when.call(c):
				continue
			var s := w2.story.build(d, c)
			if i >= s.options.size():
				continue
			seen += 1
			for k in s.options.size():
				var words: String = s.text + w2.story.label_of(s, k) + w2.story.tip_of(s, k)
				check(not words.contains("%"), "%s 第 %d 个选项的字没填好: %s" % [d.id, k, words.left(80)])
				for bad in ["随机", "史料", "三代", "查不到"]:
					check(not words.contains(bad), "%s 的字里有「%s」" % [d.id, bad])
			var said := w2.story.choose(s, i)
			check(said != "" and not said.contains("%"), "%s 选 %d: %s" % [d.id, i, said])
	check(seen >= 60, "选项都试过了 (%d 个)" % seen)


## 给一个事件凑出能出的情形 (玩家是谁、日子、有什么人); 凑不出来返回空的
func _setup(w2: World, id: String) -> Dictionary:
	var rid := "wessex"
	match id:
		"cuthbert":
			rid = "northumbria"
		"blot":
			rid = "great_army"
	var me := w2.ruler(rid)
	w2.player = me.id
	var day := w2.start_day
	match id:
		"eclipse_878":
			day = GameDate.to_day(878, 11, 1)
		"comet_891":
			day = GameDate.to_day(891, 5, 1)
		"cuthbert":
			day = GameDate.to_day(876, 3, 1)
		"kids_fight", "tutor_praise", "child_fever":
			var wife := w2.make_noble("anglo_saxon", true, 25, day)
			w2._register(wife)
			if me.living_spouse() == null:
				w2.marry(me, wife, day, [])
			for k in 2:
				var kid := w2._new_child(me, me.living_spouse(), day - (9 - k) * 365)
				kid.traits = ["rowdy"]
				kid.focus = "learning"
				kid.guardian = me.id
		"heir_lowborn":
			var kid := w2._new_child(me, me.living_spouse() if me.living_spouse() != null else w2.make_noble("anglo_saxon", true, 40, day), day - 20 * 365)
			kid.female = false
			kid.traits = ["brave", "just", "calm"]
		"brothers_quarrel":
			var dad := w2.make_noble("anglo_saxon", false, 70, day)
			w2._register(dad)
			me.father = dad.id
			for k in 2:
				var b := w2._new_child(dad, w2.make_noble("anglo_saxon", true, 60, day), day - (30 - k) * 365)
				b.female = false
			w2.kids_of[dad.id].append(me.id)
		"parent_convent":
			var mum := w2.make_noble("anglo_saxon", true, 60, day)
			w2._register(mum)
			me.mother = mum.id
		"general_reward":
			w2.story.last_win = {"commander": "alfred", "day": day}
		"agent_wavers":
			var t := w2.ruler("mercia")
			me.traits = ["callous", "sadistic", "deceitful"]
			var r := w2.intrigue.start(me, t, "murder", day, [])
			if not r.ok:
				return {}
			var sc := w2.intrigue.scheme_of(me.id, "murder")
			sc.agents.append("alfred")
		"captive_plea":
			var q: Person = w2.vassals_of(w2.ruler("mercia"))[0]
			var f := w2.make_noble(q.culture, true, 40, day)
			w2._register(f)
			w2.marry(q, f, day, [])
			q.prisoner_of = me.id
		"baptism":
			w2.story.last_norse_win = {"enemy": w2.ruler("great_army").id, "day": day}
		"learn_latin":
			me.base_skills.learning = 2
	w2.today = day
	return {"w": w2, "me": me, "day": day, "events": []}


func test_dated_event_fires_once() -> void:
	var me := king("wessex")
	w.player = me.id
	var day := GameDate.to_day(878, 11, 1)
	var ev := []
	st.monthly(day, ev)
	eq(ev.size(), 1, "878 年 11 月: 日食的事件")
	eq(ev[0].story.id, "eclipse_878")
	check(ev[0].story.history.contains("879"), "带历史背景")
	ev = []
	st.monthly(day + 1, ev)
	for e in ev:
		check(e.story.id != "eclipse_878", "只出一次")


func test_rate_about_once_a_year() -> void:
	var me := king("wessex")
	w.player = me.id
	var n := 0
	for m in 12 * 40:
		var ev := []
		st.monthly(w.start_day + 400 + m * 30, ev)
		for e in ev:
			n += 1
			st.choose(e.story, 0)
	check(n >= 20 and n <= 70, "40 年里出了 %d 件 (平均一年一件左右)" % n)


func test_break_ai() -> void:
	var p := king("mercia")
	p.traits = ["brave", "just", "calm"]
	p.stress = 140.0
	var ev := []
	st._check_breaks(w.today, ev)
	var found := {}
	for e in ev:
		if e.type == "mental_break" and e.person == p.id:
			found = e
	check(not found.is_empty(), "压力过了 100: 电脑的人崩溃了")
	eq(found.get("level", 0), 1)
	eq(p.coping().size(), 1, "染上一个排解压力的毛病")
	check(p.stress < 100.0, "压力降下来了 (%d)" % int(p.stress))
	ev = []
	p.stress = 150.0
	st._check_breaks(w.today + 30, ev)
	check(ev.filter(func(e: Dictionary) -> bool: return e.type == "mental_break").is_empty(), "一年内不会又崩溃")


func test_break_player_level1() -> void:
	var p := king("wessex")
	w.player = p.id
	p.stress = 120.0
	var ev := []
	st._check_breaks(w.today, ev)
	eq(ev.size(), 1)
	eq(ev[0].type, "story", "玩家崩溃: 弹窗让玩家选")
	var s: Dictionary = ev[0].story
	eq(s.id, "break_1")
	eq(s.options.size(), 3, "两个排解压力的毛病 + 咬牙撑下去")
	eq(s.options[2].kind, "endure")
	st.choose(s, 2)
	eq(p.stress, 140.0, "硬扛: 压力还涨 20")
	eq(p.coping().size(), 0)


func test_break_level3_abdicate() -> void:
	var p := king("wessex")
	w.player = p.id
	var heir := w.heir("wessex", w.today)
	p.stress = 330.0
	var ev := []
	st._check_breaks(w.today, ev)
	var s: Dictionary = ev[0].story
	eq(s.id, "break_3")
	var kinds: Array = s.options.map(func(o: Dictionary) -> String: return o.get("kind", ""))
	check(kinds.has("abdicate") and kinds.has("death") and kinds.has("endure"), "第 3 档: 能让位、寻死、硬扛 %s" % str(kinds))
	st.choose(s, kinds.find("abdicate"))
	check(p.alive and p.realm == "", "让位了, 人还活着")
	eq(w.ruler("wessex"), heir)
	var succ: Array = s.ctx.events.filter(func(e: Dictionary) -> bool: return e.type == "succession")
	check(not succ.is_empty() and succ[0].abdicated, "继承的消息写着让位")


func test_break_level3_death() -> void:
	var p := king("mercia")
	w.player = p.id
	p.stress = 330.0
	var ev := []
	st._check_breaks(w.today, ev)
	var s: Dictionary = ev[0].story
	var kinds: Array = s.options.map(func(o: Dictionary) -> String: return o.get("kind", ""))
	st.choose(s, kinds.find("death"))
	check(not p.alive, "寻死")


func test_add_trait_replaces_personality() -> void:
	var p := king("mercia")
	p.traits = ["calm", "just", "brave"]
	StoryEvents.add_trait(p, "wrathful")
	check(p.has_trait("wrathful") and not p.has_trait("calm"), "易怒顶掉相反的冷静")
	eq(p.personality().size(), 3)
	StoryEvents.add_trait(p, "eccentric")
	eq(p.personality().size(), 3, "性格还是三个")
	check(p.has_trait("eccentric"))


func test_option_stress() -> void:
	var p := king("wessex")
	w.player = p.id
	p.traits = ["greedy", "brave", "calm"]
	p.stress = 0.0
	var d := def_of("wandering_poet")
	var c := {"w": w, "me": p, "day": w.today, "events": []}
	var s := st.build(d, c)
	check(st.tip_of(s, 0).contains("贪婪"), "说明里写了违背性格涨压力")
	st.choose(s, 0)
	eq(p.stress, 10.0, "贪婪的人赏钱: 压力 +10")


func test_boons_and_conditions() -> void:
	var p := king("wessex")
	var g0: float = w.income(p).gold
	p.boons.append({"text": "集市", "gold": 1.5, "until": w.today + 60})
	eq(w.income(p).gold, g0 + 1.5, "集市每月多 1.5 金币")
	var h0 := p.health(w.today)
	p.conditions.append({"text": "咳嗽", "health": -0.5, "until": w.today + 60})
	eq(p.health(w.today), h0 - 0.5, "生病健康变差")
	w.advance(120, w.today + 120)
	eq(p.boons.size(), 0, "到期就没了")
	eq(p.conditions.size(), 0)


func test_grief() -> void:
	var k := king("gwynedd")
	k.stress = 0.0
	var kid: Person = w.children_of(k)[0]
	w.kill(kid, w.today, [])
	eq(k.stress, World.GRIEF_CHILD * (1.5 if k.has_trait("compassionate") else (0.5 if k.has_trait("callous") or k.has_trait("sadistic") else 1.0)), "孩子死了父亲压力涨")


func test_watch_wins() -> void:
	var me := king("wessex")
	w.player = me.id
	st.watch([{"type": "battle", "winners": [me.id], "winner_commanders": ["alfred"], "day": w.today}])
	eq(st.last_win.commander, "alfred", "记下打赢的将领")
	var army := king("great_army")
	st.watch([{"type": "war_end", "result": "defender", "war": {"attacker": army.id, "defender": me.id}, "day": w.today}])
	eq(st.last_norse_win.enemy, army.id, "记下打败的维京首领")


func test_save() -> void:
	var me := king("wessex")
	w.player = me.id
	st.fired["kids_fight"] = 12345
	st.last_win = {"commander": "alfred", "day": 1}
	me.boons.append({"text": "集市", "gold": 1.5, "until": w.today + 600})
	var w2 := World.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	eq(int(w2.story.fired.kids_fight), 12345)
	eq(w2.story.last_win.commander, "alfred")
	eq(w2.people[me.id].boons.size(), 1)


func test_option_needs_gold() -> void:
	var p := king("wessex")
	w.player = p.id
	p.gold = 5.0
	var s := st.build(def_of("wandering_poet"), {"w": w, "me": p, "day": w.today, "events": []})
	check(not st.can_choose(s, 0), "钱不够不能赏 10 金币")
	check(st.tip_of(s, 0).contains("钱不够"))
	eq(st.first_ok(s), 1, "能选的第一个是打发他走")
	var h := king("northumbria")
	h.gold = 0.0
	var s2 := st.build(def_of("bad_harvest"), {"w": w, "me": h, "day": w.today, "events": []})
	eq(st.cost_of(s2, 0), 5 * w.lands_of(h).size(), "开仓救济的钱看领地多少")
