extends TestCase
## 决议 (第 8 块, 用户 2026-10-11 定的): 建立 / 篡夺公国王国帝国、丹麦法区、群岛王国、坎布里亚王国、让位、排解压力。

var w: World


func before_each() -> void:
	w = World.load_867(7, {"wars": "off"})
	w.today = w.start_day


func king(rid: String) -> Person:
	return w.ruler(rid)


## 把一些领地给某个国家 (国王直辖)
func give(ids: Array, rid: String) -> void:
	for id in ids:
		w.transfer_county(w.by_id[id], rid, king(rid), w.today, [])


func test_create_kingdom_of_scotland() -> void:
	var k := king("alba")
	var ctl := w.title_control("kingdom", "scotland", "alba")
	check(ctl[0] * 2 > ctl[1], "阿尔巴开局就占了苏格兰一半以上 (%d/%d)" % ctl)
	k.gold = 0.0
	check(w.create_problem(k, "kingdom", "scotland").contains("钱"), "钱不够: " + w.create_problem(k, "kingdom", "scotland"))
	k.gold = 400.0
	eq(w.create_problem(k, "kingdom", "scotland"), "")
	var before_limit: int = w.income(k).limit
	var p0 := k.prestige
	var ev := []
	var r := w.create_title(k, "kingdom", "scotland", w.today, ev)
	check(r.ok, r.text)
	eq(w.title_holder("kingdom", "scotland"), "alba")
	eq(k.gold, 400.0 - World.TITLE_COST.kingdom)
	eq(k.prestige, p0 + World.TITLE_PRESTIGE.kingdom)
	eq(w.realms.alba.title, "苏格兰国王")
	eq(w.rank_bonus(k), 1, "大国王直辖上限 +1")
	eq(w.income(k).limit, before_limit + 1)
	eq(ev[0].type, "title")
	check(w.realm_duchies("alba").has("strathclyde"), "王国下面的公国都算阿尔巴的法理 (能宣战)")
	check(w.create_problem(k, "kingdom", "scotland").contains("已经"), "不能再建一次")


func test_usurp_duchy() -> void:
	var m := king("mercia")
	m.gold = 300.0
	eq(w.title_holder("duchy", "essex"), "wessex", "埃塞克斯公国开局在威塞克斯手里")
	eq(w.create_problem(m, "duchy", "essex"), "", "麦西亚占了埃塞克斯三块里的两块, 能篡夺")
	var ev := []
	check(w.create_title(m, "duchy", "essex", w.today, ev).ok)
	eq(w.title_holder("duchy", "essex"), "mercia")
	check(not w.realms.wessex.titles.has("essex"), "威塞克斯丢了这个头衔")
	eq(ev[0].usurped, "wessex")
	check(king("wessex").opinion_of(m).total < m.opinion_of(king("wessex")).total, "被篡夺的人记恨")


func test_need_two_lower_titles() -> void:
	var k := king("connacht")
	k.gold = 999.0
	give(["cashel", "thomond", "desmond", "kerry", "deise", "fidgenti", "ailech", "tir_eogain", "tir_chonaill", "airgialla",
			"downpatrick", "dal_araidi", "uisneach", "brega", "naas", "ferns", "ui_failge", "osraige"], "connacht")
	check(w.create_problem(k, "kingdom", "ireland").contains("两个公国头衔"), w.create_problem(k, "kingdom", "ireland"))
	eq(w.title_holder("duchy", "munster"), "", "芒斯特国没了, 公国头衔没人拿")
	check(w.create_title(k, "duchy", "munster", w.today, []).ok, "建立芒斯特公国 (康诺特公国本来就有)")
	eq(w.create_problem(k, "kingdom", "ireland"), "")
	check(w.create_title(k, "kingdom", "ireland", w.today, []).ok)
	eq(w.realms.connacht.title, "爱尔兰至尊王", "爱尔兰的大国王叫至尊王")


func test_decision_list() -> void:
	var k := king("alba")
	k.gold = 0.0
	var rows := Decisions.list_for(w, k)
	var row := {}
	for r in rows:
		if r.id == "kingdom:scotland":
			row = r
	check(not row.is_empty(), "决议里列出建立苏格兰王国")
	check(not row.ok and row.why.contains("钱"), "钱不够也列出来, 写清楚差什么")
	check(row.name.begins_with("建立"))
	for r in rows:
		check(String(r.id) != "duchy:gowrie", "自己已经有的头衔不列")
	k.gold = 400.0
	rows = Decisions.list_for(w, k)
	for r in rows:
		if r.id == "kingdom:scotland":
			check(r.ok)
			var res: Dictionary = r.do.call([])
			check(res.ok, res.text)
	eq(w.title_holder("kingdom", "scotland"), "alba")


func test_ai_creates_titles() -> void:
	king("alba").gold = 1000.0
	for i in 60:
		Decisions.ai_monthly(w, w.today + i * 30, [])
	eq(w.title_holder("kingdom", "scotland"), "alba", "电脑有钱就会建立能建立的王国")


func test_ai_does_not_usurp_ally() -> void:
	check(w.allies("mercia").has("wessex"), "开局麦西亚和威塞克斯是同盟")
	king("mercia").gold = 1000.0
	for i in 60:
		Decisions.ai_monthly(w, w.today + i * 30, [])
	eq(w.title_holder("duchy", "essex"), "wessex", "电脑不篡夺盟友的头衔")


func test_isles_kingdom() -> void:
	var k := king("isles")
	check(w.special_problem(k, "k_isles").contains("整个群岛"), "开局马恩岛不归群岛, 做不了")
	give(["man"], "isles")
	k.gold = 0.0
	check(w.special_problem(k, "k_isles").contains("钱"))
	k.gold = 200.0
	eq(w.special_problem(k, "k_isles"), "")
	var r := w.special_decision(k, "k_isles", w.today, [])
	check(r.ok, r.text)
	eq(w.title_holder("kingdom", "k_isles"), "isles")
	eq(w.duchies.isles.kingdom, "k_isles", "群岛公国改归群岛王国")
	eq(w.realms.isles.title, "群岛国王")
	# 存档读档以后还在
	var w2 := World.from_save(JSON.parse_string(JSON.stringify(w.to_save())))
	eq(w2.duchies.isles.kingdom, "k_isles", "存档记着法理改了")
	eq(w2.title_holder("kingdom", "k_isles"), "isles")
	check(w.special_problem(king("alba"), "k_isles") != "", "不是维京人不能做")


func test_cumbria_kingdom() -> void:
	var k := king("strathclyde")
	give(["wigtown", "kirkcudbright", "carlisle"], "strathclyde")
	k.gold = 200.0
	eq(w.special_problem(k, "k_cumbria"), "")
	var sp0 := int(w.realms.strathclyde.get("special", 0))
	check(w.special_decision(k, "k_cumbria", w.today, []).ok)
	eq(w.title_holder("kingdom", "k_cumbria"), "strathclyde")
	eq(w.duchies.galloway.kingdom, "k_cumbria")
	eq(int(w.realms.strathclyde.special), sp0 + 1000, "多 1000 个不用养的兵")


func test_danelaw() -> void:
	var k := king("great_army")
	give(["beverley", "ripon", "elmet", "lincoln"], "great_army")
	k.prestige = 50.0
	check(w.special_problem(k, "danelaw").contains("威望"))
	k.prestige = 200.0
	eq(w.special_problem(k, "danelaw"), "")
	var partner := w.danelaw_partner(k)
	check(partner != null and not w._norse(partner), "跟英格兰地最多的基督徒国王谈")
	partner.remember(k.id, "测试: 很喜欢他", 100, w.today + 3650)
	var ev := []
	var r := w.special_decision(k, "danelaw", w.today, ev)
	check(r.ok, r.text)
	eq(w.title_holder("kingdom", "danelaw"), "great_army")
	eq(w.duchies.deira.kingdom, "danelaw", "占着的公国划进丹麦法区")
	eq(w.duchies.wessex.kingdom, "england", "别的还是英格兰的")
	eq(w.title_holder("kingdom", "england"), partner.realm, "对方当英格兰国王")
	check(w.warfare.truces.has(w.warfare._truce_key("great_army", partner.realm)), "停战")
	check(w.special_problem(k, "danelaw") != "", "不能再做")


func test_danelaw_asks_player() -> void:
	var k := king("great_army")
	give(["beverley", "ripon", "elmet"], "great_army")
	k.prestige = 200.0
	var partner := w.danelaw_partner(k)
	w.player = partner.id
	var ev := []
	check(w.special_decision(k, "danelaw", w.today, ev).ok)
	eq(ev[0].type, "danelaw_ask", "对方是玩家: 问玩家")
	eq(w.title_holder("kingdom", "danelaw"), "", "玩家答应以前还没有")


func test_abdicate() -> void:
	var k := king("wessex")
	var heir := w.heir("wessex", w.today)
	var p0 := k.prestige
	var ev := []
	w.abdicate(k, w.today, ev)
	check(k.alive, "让位的人还活着")
	eq(k.realm, "")
	eq(w.ruler("wessex"), heir, "继承人当了国王")
	eq(k.prestige, p0 - 100.0)
	var found := false
	for e in ev:
		if e.type == "succession" and e.get("abdicated", false):
			found = true
	check(found, "继承的消息里写着是让位")


func test_coping_decision() -> void:
	var p := king("mercia")
	p.traits.append("journaller")
	p.stress = 150.0
	var rows := Decisions.list_for(w, p)
	var row := {}
	for r in rows:
		if r.id == "coping:journaller":
			row = r
	check(not row.is_empty() and row.ok, "有写日记的毛病, 决议里能写日记")
	var r := Decisions.coping(w, p, "journaller", w.today)
	check(r.ok, r.text)
	check(p.stress < 150.0, "压力降了")
	check(not Decisions.coping(w, p, "journaller", w.today + 300).ok, "三年一次")
	check(Decisions.coping(w, p, "journaller", w.today + 3 * 365 + 1).ok, "三年后又能做")
