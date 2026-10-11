extends TestCase
## 打仗 (第 6 块, 用户 2026-10-11 说「都按推荐」): 玩法照三代, 数字按小地图缩, 开局维京大军和诺森布里亚就在打。

var w: World
var wf: Warfare


func before_each() -> void:
	w = World.load_867(7, {"wars": "off"})  # 大部分测试不要开局的仗, 自己摆
	wf = w.warfare
	w.council.off = true  # 议会 (第 9 块) 的加成在 test_council 里测, 这里量打仗本身的数字
	w.council.refresh_opinions()
	for c in w.counties:
		c.garrison = wf.max_garrison(c)


func king(rid: String) -> Person:
	return w.ruler(rid)


func opt(att: Person, def: Person, cb: String, target := "") -> Dictionary:
	for o in wf.cb_options(att, def):
		if o.cb == cb and (target == "" or o.target == target):
			return o
	return {}


## 两支军队摆在同一块地上打起来, 一天天走到打完 (最多 120 天)
func fight(a: Dictionary, b: Dictionary, loc: String) -> Array:
	var events := []
	for x in [a, b]:
		x.loc = loc
		x.gather = 0
		x.path = []
	var day := w.today
	for i in 120:
		day += 1
		w.today = day
		wf.daily(day, events)
		if wf.battles.is_empty() and events.any(func(e: Dictionary) -> bool: return e.type == "battle"):
			break
	return events


func test_start_state() -> void:
	var w2 := World.load_867(7)
	var war: Dictionary = w2.warfare.wars[0]
	eq(w2.warfare.wars.size(), 1, "开局只有一场仗")
	eq(war.attacker, w2.realms.northumbria.ruler_id, "诺森布里亚的埃拉")
	eq(war.defender, w2.realms.great_army.ruler_id, "打维京大军的伊瓦尔")
	eq(war.cb, "de_jure")
	eq(war.targets, ["york"], "要回约克")
	eq(int(w2.realms.great_army.special), 2000, "维京大军 2000 个不用养的兵")
	eq(w2.ruler("wessex").prestige, War.START_PRESTIGE_KING, "国王开局 100 威望")
	eq(w2.people["aethelwulf_berkshire"].prestige, War.START_PRESTIGE_VASSAL, "封臣开局 25 威望")
	var os: Person = w2.people["osberht"]
	eq(os.claims, ["realm:northumbria"], "奥斯伯特对诺森布里亚有宣称")
	eq(os.liege_realm, "northumbria", "住在诺森布里亚")
	check(w2.warfare.commander_candidates(w2.ruler("northumbria")).has(os), "奥斯伯特能替诺森布里亚带兵")
	eq(w2.warfare.fort(w2.by_id.york), 3, "约克: 1 + 罗马城墙 + 都城")
	eq(int(w2.by_id.york.garrison), int(w2.warfare.max_garrison(w2.by_id.york)), "守军满的")
	check(w2.warfare.max_garrison(w2.by_id.york) >= 300.0, "约克的城墙 3 级 (元帅整顿军队还会多一些)")
	eq(wf.wars.size(), 0, "开局设置关了「历史上的仗」就没有")


func test_cb_options() -> void:
	var o := opt(king("wessex"), king("mercia"), "de_jure")
	check(not o.is_empty(), "威塞克斯手里有埃塞克斯公国头衔, 能要回伦敦、赫特福德")
	if not o.is_empty():
		eq(o.targets, ["london", "hertford"])
		eq(o.cost, War.COST_DE_JURE * 2)
	check(not opt(king("isles"), king("man"), "conquest").is_empty(), "维京人坐船能去抢马恩岛")
	check(opt(king("gwynedd"), king("man"), "holy").is_empty(), "基督徒不跨海打圣战")
	check(not opt(king("northumbria"), king("great_army"), "holy", "york").is_empty(), "基督徒能对挨着的维京人打圣战")
	check(opt(king("wessex"), king("mercia"), "holy").is_empty(), "都是基督徒没有圣战")
	check(opt(king("wessex"), king("mercia"), "conquest").is_empty(), "基督徒不能直接征服")
	var v: Person = w.people["aethelwulf_berkshire"]
	check(not opt(v, king("wessex"), "independence").is_empty(), "封臣能对国王宣布独立")
	check(wf.cb_options(v, king("mercia")).is_empty(), "封臣不能对别国宣战")


func test_declare_costs_prestige() -> void:
	var att := king("isles")
	var def := king("man")
	var o := opt(att, def, "conquest", "man")
	var before := att.prestige
	var events := []
	var r := wf.declare(att, o, w.today, events)
	check(r.ok, r.text)
	eq(att.prestige, before - o.cost, "花了威望")
	check(wf.hostile(att.id, def.id), "在打了")
	check(events.any(func(e: Dictionary) -> bool: return e.type == "war"), "有宣战的消息")
	check(def.memories.any(func(m: Dictionary) -> bool: return m.text == "向我宣战"), "被打的记着")
	check(not opt(att, def, "conquest", "man").ok, "已经在打就不能再宣战")
	att.prestige = 0
	check(not opt(king("isles"), king("orkney"), "conquest").ok if not opt(king("isles"), king("orkney"), "conquest").is_empty() else true, "威望不够不能宣战")


func test_allies_join_defensive_war() -> void:
	check(w.allies("mercia").has("wessex"), "麦西亚和威塞克斯是同盟 (伯格雷德娶了埃塞尔雷德的姐姐)")
	var att := king("great_army")
	var def := king("mercia")
	king("wessex").remember(def.id, "测试", 50, w.today + 3650)
	var events := []
	wf.declare(att, {"cb": "conquest", "target": "nottingham", "targets": ["nottingham"], "claimant": "", "cost": 0.0, "label": "抢诺丁汉",
			"defender": def.id, "ok": true, "why": "", "truce": false}, w.today, events, true)
	var war: Dictionary = wf.wars[0]
	check(war.defenders.has(king("wessex").id), "盟友来帮忙守 (好感够)")
	# 玩家是盟友: 不自动加入, 弹窗问
	var w2 := World.load_867(7, {"wars": "off"})
	w2.player = w2.ruler("wessex").id
	var ev2 := []
	w2.warfare.declare(w2.ruler("great_army"), {"cb": "conquest", "target": "nottingham", "targets": ["nottingham"], "claimant": "", "cost": 0.0,
			"label": "抢诺丁汉", "defender": w2.ruler("mercia").id, "ok": true, "why": "", "truce": false}, w2.today, ev2, true)
	check(ev2.any(func(e: Dictionary) -> bool: return e.type == "ally_call" and e.ally == w2.player), "玩家是盟友: 问玩家")
	check(not w2.warfare.wars[0].defenders.has(w2.player), "还没加入")


func test_raise_and_upkeep() -> void:
	var k := king("wessex")
	var lv := wf.levy_of(k)
	eq(lv.levy, float(w.income(k).levy), "能征的兵 = 直辖的 + 封臣交的")
	var r := wf.raise(k, w.today)
	check(r.ok, r.text)
	var a := wf.army_of(k.id)
	eq(a.loc, w.realms.wessex.capital, "在都城集合")
	check(int(a.gather) > 0, "要集合几天")
	eq(wf.upkeep(a), lv.levy / 1000.0 * War.UPKEEP_PER_1000, "每千人每月 3 金币")
	check(not wf.raise(k, w.today).ok, "征了就不能再征")
	check(wf.can_raise(w.people["aethelwulf_berkshire"]) != "", "封臣的兵交给国王, 自己征不了")
	var g: Dictionary = wf.army_of(king("great_army").id)
	check(g.is_empty(), "维京大军还没征")
	wf.raise(king("great_army"), w.today)
	eq(wf.army_of(king("great_army").id).special, 2000.0, "维京大军的 2000 人跟着军队")
	eq(int(w.realms.great_army.special), 0)
	var d := wf.disband(a)
	check(d.ok, d.text)
	check(wf.army_of(k.id).is_empty(), "解散了")


func test_move_and_ships() -> void:
	var k := king("gwynedd")
	w.player = k.id  # 电脑没在打仗会把军队解散; 玩家的不会
	wf.raise(k, w.today)
	var a := wf.army_of(k.id)
	a.gather = 0
	a.loc = "aberffraw"
	var path := wf.route("aberffraw", "dublin")
	check(not path.is_empty(), "安格尔西岛到都柏林走得到")
	check(path.any(func(e: Array) -> bool: return e[2]), "要坐船")
	var r := wf.order_move(a, "dublin")
	check(r.ok, r.text)
	has_text(r.text, "坐 ")
	var gold := k.gold
	var events := []
	var day := w.today
	for i in 40:
		day += 1
		wf.daily(day, events)
	eq(a.loc, "dublin", "到了都柏林")
	check(k.gold < gold, "坐船花了钱")
	var land := wf.route("hampshire", "london")
	check(not land.is_empty() and land.all(func(e: Array) -> bool: return not e[2]), "汉普郡到伦敦走路就行")


func test_battle_bigger_wins() -> void:
	var att := king("great_army")
	var def := king("northumbria")
	var ev := []
	wf.declare(def, opt(def, att, "holy", "york"), w.today, ev)
	wf.raise(att, w.today)
	wf.raise(def, w.today)
	var a := wf.army_of(att.id)
	var b := wf.army_of(def.id)
	var pa := att.prestige
	var events := fight(a, b, "beverley")
	var battle := events.filter(func(e: Dictionary) -> bool: return e.type == "battle")
	check(not battle.is_empty(), "打了一仗")
	if battle.is_empty():
		return
	eq(battle[0].winner, att.id, "2200 人打赢 %d 人" % int(wf.levy_of(def).levy))
	check(battle[0].lost_l > battle[0].lost_w, "输的死得多")
	check(att.prestige >= pa + War.BATTLE_PRESTIGE, "打赢涨威望")
	var war := wf.war_between(att.id, def.id)
	check(wf.score(war).total < 0.0, "进攻方 (诺森布里亚) 打输了, 战争分数是负的")
	check(wf.score(war).total >= -War.BATTLE_CAP, "打仗最多算 50 分")


func test_early_rout_wipes_army() -> void:
	var att := king("great_army")
	var def := king("isles")
	wf.declare(att, {"cb": "conquest", "target": "skye", "targets": ["skye"], "claimant": "", "cost": 0.0, "label": "x",
			"defender": def.id, "ok": true, "why": "", "truce": false}, w.today, [], true)
	wf.raise(att, w.today)
	wf.raise(def, w.today)
	var a := wf.army_of(att.id)
	var b := wf.army_of(def.id)
	a.special = 5000.0
	b.levy = 300.0
	b.special = 0.0
	b.commander = ""  # 没人带兵 (第 9 块起宫廷里多了请来的大臣, 可能有会带兵的)
	var events := fight(a, b, "skye")
	check(events.any(func(e: Dictionary) -> bool: return e.type == "battle" and e.wiped), "头 12 天就垮了: 全军覆没")
	check(wf.army_of(def.id).is_empty(), "军队没了")
	eq(def.levy_ratio, 0.0, "兵要从头慢慢补")


func test_siege_occupies_and_stops_income() -> void:
	var att := king("mercia")
	var def := king("east_anglia")
	wf.declare(att, {"cb": "punitive", "target": "cambridge", "targets": ["cambridge"], "claimant": "", "cost": 0.0, "label": "x",
			"defender": def.id, "ok": true, "why": "", "truce": false}, w.today, [], true)
	wf.raise(att, w.today)
	var a := wf.army_of(att.id)
	a.loc = "cambridge"
	a.gather = 0
	var c: Dictionary = w.by_id.cambridge
	var holder: Person = w.people[c.lord]
	var before: float = w.income(holder).gold
	var events := []
	var day := w.today
	var days := 0
	while c.occupier == "" and days < 400:
		day += 1
		days += 1
		wf.daily(day, events)
	var war0 := wf.war_between(att.id, def.id)
	check(c.occupier != "" and wf.side(war0, c.occupier) == 1, "进攻方围下来了 (盟友威塞克斯也来了)")
	check(days > 60, "要围几个月 (%d 天)" % days)
	check(w.income(holder).gold < before or before == 0.0, "被占的地不出钱")
	check(c.garrison < wf.max_garrison(c), "守军剩四分之一")
	var war := wf.war_between(att.id, def.id)
	check(wf.score(war).total > 0.0, "占了地, 进攻方涨分")
	check(events.any(func(e: Dictionary) -> bool: return e.type == "siege" and e.county == "cambridge"))


func test_capture_scores() -> void:
	var att := king("mercia")
	var def := king("east_anglia")
	wf.declare(att, {"cb": "punitive", "target": "cambridge", "targets": ["cambridge"], "claimant": "", "cost": 0.0, "label": "x",
			"defender": def.id, "ok": true, "why": "", "truce": false}, w.today, [], true)
	var war: Dictionary = wf.wars[0]
	def.prisoner_of = att.id
	eq(wf.score(war).total, 100.0, "抓到对方国王: +100")


func test_enforce_conquest_and_truce() -> void:
	var att := king("isles")
	var def := king("man")
	var o := opt(att, def, "conquest", "man")
	wf.declare(att, o, w.today, [])
	var war: Dictionary = wf.wars[0]
	var events := []
	wf.end_war(war, "attacker", w.today, events)
	eq(w.by_id.man.holder, "isles", "马恩岛归了群岛")
	eq(w.by_id.man.lord, att.id, "直辖")
	check(not w.realms.has("man"), "马恩岛国一块地都没了, 没了")
	check(events.any(func(e: Dictionary) -> bool: return e.type == "realm_gone"), "灭国的消息")
	eq(def.realm, "", "原来的国王没有国家了")
	check(wf.truce_until("isles", "man") > w.today, "停战 5 年")
	check(wf.wars.is_empty())


func test_truce_breaking_costs_more() -> void:
	var att := king("wessex")
	var def := king("mercia")
	wf.truces[wf._truce_key("wessex", "mercia")] = w.today + 1000
	var o := opt(att, def, "de_jure")
	check(o.truce, "还在停战")
	eq(o.cost, War.COST_DE_JURE * 2 + War.TRUCE_BREAK, "多花 100 威望")


func test_loser_pays_and_white_peace() -> void:
	var att := king("wessex")
	var def := king("mercia")
	wf.declare(att, opt(att, def, "de_jure"), w.today, [])
	var war: Dictionary = wf.wars[0]
	var ga := att.gold
	var gd := def.gold
	wf.end_war(war, "defender", w.today, [])
	check(att.gold < ga and def.gold > gd, "进攻方输了赔钱")
	eq(w.by_id.london.holder, "mercia", "地不变")
	# 平局: 电脑没占上风才肯
	var w2 := World.load_867(7, {"wars": "off"})
	var f := w2.warfare
	f.declare(w2.ruler("wessex"), {"cb": "de_jure", "target": "duchy:essex", "targets": ["london", "hertford"], "claimant": "", "cost": 0.0,
			"label": "x", "defender": w2.ruler("mercia").id, "ok": true, "why": "", "truce": false}, w2.today, [], true)
	var war2: Dictionary = f.wars[0]
	check(not f.takes_white(war2, -1), "刚打不到三个月不肯平局")
	war2.months = 6
	check(f.takes_white(war2, -1), "没占上风, 肯平局")
	war2.battle = -40.0
	check(not f.takes_white(war2, -1), "防守方占着上风, 不肯")


func test_buy_peace() -> void:
	var att := king("great_army")
	var def := king("mercia")
	wf.declare(att, {"cb": "conquest", "target": "nottingham", "targets": ["nottingham"], "claimant": "", "cost": 0.0, "label": "x",
			"defender": def.id, "ok": true, "why": "", "truce": false}, w.today, [], true)
	var war: Dictionary = wf.wars[0]
	war.battle = 30.0
	check(wf.takes_money(war), "维京人好说话, 收钱走人")
	var price := wf.price_of(war)
	def.gold = price + 10.0
	var ga := att.gold
	wf.end_war(war, "bought", w.today, [], price)
	eq(def.gold, 10.0, "防守方付了钱")
	eq(att.gold, ga + price, "维京人收了钱")
	eq(w.by_id.nottingham.holder, "mercia", "地没丢")


func test_independence() -> void:
	var v: Person = w.people["aethelwulf_berkshire"]
	var k := king("wessex")
	check(not opt(v, k, "independence").ok, "封臣 25 威望, 宣布独立要 50, 不够")
	v.prestige = 100.0
	wf.declare(v, opt(v, k, "independence"), w.today, [])
	var war: Dictionary = wf.wars[0]
	check(wf.is_rebel(v.id))
	eq(wf.party(w.by_id.berkshire), v.id, "造反的封臣管自己的地")
	var events := []
	wf.end_war(war, "attacker", w.today, events)
	check(v.realm != "", "自立为王")
	eq(w.by_id.berkshire.holder, v.realm, "伯克郡是他的国家")
	check(w.liege_of(v) == null, "不再效忠谁")
	# 输了被关起来
	var w2 := World.load_867(7, {"wars": "off"})
	var v2: Person = w2.people["wulfhere_wiltshire"]
	v2.prestige = 100.0
	var o: Dictionary = {}
	for x in w2.warfare.cb_options(v2, w2.ruler("wessex")):
		if x.cb == "independence":
			o = x
	w2.warfare.declare(v2, o, w2.today, [])
	w2.warfare.end_war(w2.warfare.wars[0], "defender", w2.today, [])
	eq(v2.prisoner_of, w2.ruler("wessex").id, "造反输了被关进大牢")


func test_claim_on_throne() -> void:
	var os: Person = w.people["osberht"]
	var k := king("alba")
	os.liege_realm = "alba"  # 住到阿尔巴去, 阿尔巴国王替他要诺森布里亚的王位
	var o := opt(k, king("northumbria"), "claim")
	check(not o.is_empty(), "阿尔巴能替奥斯伯特打")
	if o.is_empty():
		return
	eq(o.cost, War.COST_CLAIM_REALM * War.CLAIM_OTHER, "替别人要: 威望 ×5")
	check(not o.ok, "威望不够")
	k.prestige = 1000
	wf.declare(k, opt(k, king("northumbria"), "claim"), w.today, [])
	var old := king("northumbria")
	wf.end_war(wf.wars[0], "attacker", w.today, [])
	eq(king("northumbria"), os, "奥斯伯特当上了诺森布里亚国王")
	eq(old.realm, "", "埃拉下台了")
	check(not os.claims.has("realm:northumbria"), "宣称用掉了")


func test_sons_get_claims() -> void:
	var r := king("gwynedd")  # 罗德里大王, 平分继承
	var sons := w.children_of(r).filter(func(p: Person) -> bool: return p.alive and not p.female)
	check(sons.size() >= 2, "罗德里有好几个儿子")
	w.kill(r, w.today, [])
	var heir := king("gwynedd")
	for s in sons:
		if s != heir:
			check(s.claims.has("realm:gwynedd"), "%s对格温内斯有宣称" % s.name)
	check(not heir.claims.has("realm:gwynedd"), "继承人自己没有")


func test_leader_dies_heir_takes_over() -> void:
	var att := king("wessex")
	var def := king("mercia")
	wf.declare(att, opt(att, def, "de_jure"), w.today, [])
	w.kill(att, w.today, [])
	var war: Dictionary = wf.wars[0]
	eq(war.attacker, king("wessex").id, "国王死了, 新国王接着打")
	check(war.attackers.has(king("wessex").id))


func test_long_run_with_wars() -> void:
	var w2 := World.load_867(13)
	var day := w2.start_day
	var count := {}
	for m in 40 * 12:
		day += 30
		for e in w2.advance(30, day):
			count[e.type] = count.get(e.type, 0) + 1
		if m % 12 == 0:
			for a in w2.warfare.armies.values():
				check(a.levy >= 0.0 and a.special >= 0.0, "军队人数不是负的")
				check(w2.people[a.owner].alive, "军队的主人活着")
			for war in w2.warfare.wars:
				check(w2.people[war.attacker].alive and w2.people[war.defender].alive, "打仗的两边带头的活着")
			for c in w2.counties:
				check(w2.realms.has(c.holder), "%s 属于一个还在的国家" % c.name)
				check(c.occupier == "" or w2.warfare.hostile(c.occupier, w2.warfare.party(c)), "被占的地是敌人占的")
	check(count.get("war", 0) >= 5, "四十年里打了几场仗 (%d)" % count.get("war", 0))
	check(count.get("battle", 0) >= 5, "打过仗 (%d)" % count.get("battle", 0))
	check(w2.realm_order.size() >= 15, "四十年后还剩不少国家 (%d)" % w2.realm_order.size())


func test_history_wars_on_schedule() -> void:
	var w2 := World.load_867(7)
	var day := w2.start_day
	var found := false
	while day < GameDate.to_day(868, 1, 1):
		day += 30
		for e in w2.advance(30, day):
			if e.type == "war" and e.attacker == w2.realms.great_army.get("ruler_id", "") and w2.people[e.defender].realm == "mercia":
				found = true
	if w2.realms.has("great_army") and w2.realms.has("mercia"):
		check(found, "867 年 10 月维京大军向麦西亚宣战 (史料: 诺丁汉)")


func test_summer_army_871() -> void:
	# 史料: 871 年梅雷顿之战以后一支很大的夏季大军来到雷丁。维京大军还在就多 1000 个不用养的兵
	var w2 := World.load_867(7)
	var f := w2.warfare
	var day := GameDate.to_day(871, 3, 1)
	w2.today = day
	var before := int(w2.realms.great_army.special) + (int(f.army_of(w2.ruler("great_army").id).special) if not f.army_of(w2.ruler("great_army").id).is_empty() else 0)
	var events := []
	f.monthly(GameDate.to_day(871, 4, 1), events)
	var after := int(w2.realms.great_army.special) + (int(f.army_of(w2.ruler("great_army").id).special) if not f.army_of(w2.ruler("great_army").id).is_empty() else 0)
	eq(after, before + 1000, "多了 1000 人")
	check(events.any(func(e: Dictionary) -> bool: return e.type == "reinforce"), "有消息")
	f.monthly(GameDate.to_day(871, 5, 1), [])
	eq(int(w2.realms.great_army.special) + (int(f.army_of(w2.ruler("great_army").id).special) if not f.army_of(w2.ruler("great_army").id).is_empty() else 0), after, "只来一次")
	var w3 := World.load_867(7, {"wars": "off"})
	eq(w3.history_reinforcements.size(), 0, "「历史上的仗」关了就没有")
