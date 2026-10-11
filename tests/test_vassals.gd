extends TestCase
## 封臣 (第 5 块, 用户 2026-10-10 选的「折中」: 玩法照三代, 叫法和几处规矩照史实)

var w: World


func before_each() -> void:
	w = World.load_867()


func person(id: String) -> Person:
	return w.people[id]


func county(id: String) -> Dictionary:
	return w.by_id[id]


func lord(id: String) -> Person:
	return w.people[county(id).lord]


func test_historical_vassals_at_start() -> void:
	eq(lord("berkshire").id, "aethelwulf_berkshire", "伯克郡郡长埃塞尔伍尔夫")
	eq(w.title_of(lord("berkshire")), "伯克郡郡长")
	eq(lord("wiltshire").id, "wulfhere_wiltshire", "威尔特郡郡长伍尔夫希尔")
	eq(lord("lincoln").id, "aethelred_mucel", "盖尼人的郡长埃塞尔雷德·穆赫尔")
	eq(w.relation(person("ealhswith"), person("aethelred_mucel")), "父亲", "埃尔斯维斯的父亲")
	eq(lord("brega").id, "flann_mac_conaing", "布雷加国王 (米斯只有两块地也给了他: 史料里有)")
	eq(w.title_of(lord("brega")), "布雷加小国王")
	eq(w.relation(person("gormlaith_brega"), person("flann_mac_conaing")), "父亲")
	eq(lord("airgialla").id, "congalach_airgialla")
	eq(lord("ferns").id, "donnacan_ferns")
	eq(lord("ui_failge").id, "mael_sinchill")
	eq(w.liege_of(lord("brega")), w.ruler("mide"))


func test_kings_keep_capital_and_limit() -> void:
	for rid in w.realm_order:
		var k := w.ruler(rid)
		var cap: Dictionary = county(w.realms[rid].capital)
		eq(cap.lord, k.id, "%s 的都城归国王" % rid)
		var inc := w.income(k)
		check(inc.domain <= inc.limit or w.counties_of(rid).size() <= 2, "%s 开局直辖不超过上限" % rid)
		if w.counties_of(rid).size() <= 2 and rid != "mide":
			eq(w.vassals_of(k).size(), 0, "%s 一两块地的小国家没有封臣" % rid)
	check(w.vassals_of(w.ruler("wessex")).size() >= 9, "威塞克斯有不少郡长")
	check(w.vassals_of(w.ruler("alba")).size() >= 10)


func test_vassal_names_by_region() -> void:
	eq(Feudal.kind(w, "wessex"), "郡长")
	eq(Feudal.kind(w, "munster"), "小国王")
	eq(Feudal.kind(w, "isles"), "雅尔")
	eq(Feudal.kind(w, "alba"), "领主", "阿尔巴: 867 年怎么叫查不到")
	eq(Feudal.kind(w, "gwynedd"), "领主")
	eq(Feudal.kind(w, "strathclyde"), "领主")
	for v in w.vassals_of(w.ruler("munster")):
		check(w.title_of(v).ends_with("小国王"))


func test_domain_limit() -> void:
	# 照三代现在的算法 (用户 2026-10-10 选的): 基础 1 + 头衔 2 + 教育 (差 -1、一般 0、好 +1、出色 +2)
	var k := w.ruler("wessex")
	k.education = {}
	eq(Feudal.domain_limit(k, w.start_day), 3, "没教育: 3 块")
	k.base_skills.stewardship = 30
	eq(Feudal.domain_limit(k, w.start_day), 3, "管理本事不算 (三代现在不看)")
	for lv in [[1, 2], [2, 3], [3, 4], [4, 5]]:
		k.education = {"skill": "stewardship", "level": lv[0]}
		eq(Feudal.domain_limit(k, w.start_day), lv[1], "教育第 %d 档" % lv[0])


func test_generate_families() -> void:
	# 照三代的「生成家人」(默认开): 有领地、没记载家人的人开局有妻子和能继承的儿子
	var edmund := w.ruler("east_anglia")
	check(edmund.married(), "埃德蒙开局有妻子")
	var kids := w.children_of(edmund)
	check(not kids.is_empty() and not kids[0].female, "第一个孩子是儿子")
	eq(w.heir("east_anglia", w.start_day), kids[0], "儿子是继承人")
	var wife := edmund.living_spouse()
	check(kids.size() >= (1 + (1 if wife.age(w.start_day) > 25 else 0) + (1 if wife.age(w.start_day) > 33 else 0)), "母亲 25 岁以上第二个孩子, 33 岁以上第三个")
	for c in kids:
		check(c.age(w.start_day) <= wife.age(w.start_day) - 17, "孩子不比母亲小太多")
	var berk := person("aethelwulf_berkshire")
	check(berk.married(), "伯克郡郡长也有了家人")
	# 有记载家人的不生成
	eq(person("aethelred_mucel").spouse, "eadburh", "埃塞尔雷德·穆赫尔的妻子是史料里的埃德伯")
	eq(w.children_of(w.ruler("gwynedd")).size(), 7, "罗德里还是史料里的七个儿子")
	eq(w.ruler("alba").spouse, "", "康斯坦丁有记载的儿子, 不给他生成妻子 (三代也只管完全没家人的)")
	check(not person("alfred").married(), "没领地的人不生成")


func test_income_and_contract() -> void:
	var k := w.ruler("wessex")
	var v := person("aethelwulf_berkshire")
	var iv := w.income(v)
	eq(iv.own_gold, 1.0, "一块领地每月 1 金币")
	eq(iv.own_levy, 200)
	eq(iv.paid_gold, 0.2, "照常: 交 20% 的税")
	eq(iv.paid_levy, 50, "交 25% 的兵")
	var ik := w.income(k)
	eq(ik.own_gold, float(ik.active), "直辖的每块 1 金币")
	check(ik.from_gold > 1.5, "封臣交上来不少")
	var gold_before := k.gold
	w.advance(31, w.start_day + 31)
	check(absf(k.gold - gold_before - w.income(k).gold) < 0.6, "过了一个月收了钱")
	var r := w.set_contract(k, v, 2, w.start_day)
	check(r.ok)
	eq(w.income(v).paid_gold, 0.3, "多交: 30%")
	eq(k.tyranny, Feudal.TYRANNY, "让封臣多交算暴政")
	check(v.opinion_of(k).parts.any(func(x: Array) -> bool: return x[0] == "让我多交"))
	check(v.opinion_of(k).parts.any(func(x: Array) -> bool: return String(x[0]).begins_with("暴政")), "封臣不喜欢暴政")
	w.set_contract(k, v, 0, w.start_day)
	eq(w.income(v).paid_gold, 0.1, "少交: 10%")


func test_over_limit_counties_give_nothing() -> void:
	var k := w.ruler("wessex")
	for c in w.counties_of("wessex"):
		c.lord = k.id
	w._feudal_dirty = true
	var inc := w.income(k)
	eq(inc.domain, 14)
	eq(inc.own_gold, float(inc.limit), "超过上限的不出钱")


func test_grant_county() -> void:
	var k := w.ruler("wessex")
	var alfred := person("alfred")
	var dom := w.lands_of(k)
	var c: Dictionary = dom[dom.size() - 1]
	has_text(w.grant_county(k, county(w.realms.wessex.capital), alfred, w.start_day, []).text, "都城")
	var r := w.grant_county(k, c, alfred, w.start_day, [])
	check(r.ok, r.text)
	eq(c.lord, "alfred")
	eq(w.liege_of(alfred), k)
	check(w.vassals_of(k).has(alfred))
	check(alfred.opinion_of(k).parts.any(func(x: Array) -> bool: return x[0] == "封给我领地"), "很感激")
	eq(Marriage.status(w, alfred), 2)
	check(not w.grant_county(k, c, alfred, w.start_day, []).ok, "已经不是你直辖的了")


func test_viceroy() -> void:
	var k := w.ruler("wessex")
	var alfred := person("alfred")
	var kent_vassals := w.vassals_of(k).filter(func(v: Person) -> bool: return w.lands_of(v)[0].duchy == "kent")
	var r := w.grant_viceroy(k, "kent", alfred, w.start_day, [])
	check(r.ok, r.text)
	eq(w.title_of(alfred), "肯特副王")
	eq(w.vassal_kind(alfred), "副王")
	check(not w.realms.wessex.titles.has("kent"), "肯特头衔给了副王")
	for v in kent_vassals:
		eq(w.liege_of(v), alfred, "肯特的郡长归副王管")
	check(not w.grant_viceroy(k, "wessex", person("aethelhelm"), w.start_day, []).ok, "主要的头衔不能封")
	# 副王当了国王: 头衔还给国家
	var events := []
	w.kill(k, w.start_day + 5, events)
	eq(w.ruler("wessex"), alfred, "长者继承: 阿尔弗雷德继位")
	check(w.realms.wessex.titles.has("kent"), "肯特头衔回到国家")
	eq(w.viceroy_duchy(alfred), "")


func test_ealdorman_revoke_is_not_tyranny() -> void:
	var k := w.ruler("wessex")
	var v := person("aethelwulf_berkshire")
	v.memories.clear()
	var r := w.revoke(k, v, w.start_day, [])
	if v.opinion_of(k).total < 0 and not r.ok:
		return  # 好感太低不肯交 (另一条测试管)
	check(r.ok, r.text)
	eq(k.tyranny, 0.0, "撤换郡长不算暴政")
	eq(county("berkshire").lord, k.id, "伯克郡归国王直辖")
	has_text(r.text, "不算暴政")


func test_irish_revoke_is_double_tyranny() -> void:
	var k := w.ruler("mide")
	var v := person("flann_mac_conaing")
	v.memories = [{"who": k.id, "text": "测试", "value": 100, "until": w.start_day + 99999}]
	var r := w.revoke(k, v, w.start_day, [])
	check(r.ok, r.text)
	eq(k.tyranny, 2 * Feudal.TYRANNY, "爱尔兰小国王: 暴政翻倍")


func test_refusal_gives_reason_to_arrest() -> void:
	var k := w.ruler("alba")
	var v: Person = w.vassals_of(k)[0]
	v.memories = [{"who": k.id, "text": "测试", "value": -100, "until": w.start_day + 99999}]
	var events := []
	var r := w.revoke(k, v, w.start_day, events)
	check(not r.ok, "好感低的不肯交")
	has_text(r.text, "抗命")
	check(Feudal.has_crime(v, w.start_day), "抗命算犯罪")
	eq(k.tyranny, 0.0)
	# 有罪的人关起来不算暴政; 关着的人不能不肯
	w.rng.seed = 1
	k.base_skills.intrigue = 30
	var a := w.arrest(k, v, w.start_day, events)
	check(a.ok, a.text)
	eq(k.tyranny, 0.0, "有罪, 不算暴政")
	eq(v.prisoner_of, k.id)
	var r2 := w.revoke(k, v, w.start_day, events)
	check(r2.ok, "关着的人不能不肯: " + r2.text)
	eq(k.tyranny, 0.0, "有罪的人收回也不算暴政")
	check(w.lands_of(v).is_empty())


func test_arrest_without_reason_is_tyranny() -> void:
	var k := w.ruler("wessex")
	k.base_skills.intrigue = 40
	var target := person("wulfhere_wiltshire")
	target.base_skills.intrigue = 0
	var r := w.arrest(k, target, w.start_day, [])
	check(r.ok, r.text)
	eq(k.tyranny, Feudal.TYRANNY, "没理由关人算暴政")
	check(target.opinion_of(k).total < 0, "被关的人恨你")
	has_text(Marriage.problem(w, target, person("ealhswith"), w.start_day), "大牢", "关着的人不能结婚")
	has_text(w.arrest_problem(k, w.ruler("mercia")), "别国的国王", "别国的国王抓不了")
	has_text(w.arrest_problem(k, person("land")), "不在你的国家", "别国的人抓不了")


func test_arrest_can_fail() -> void:
	var k := w.ruler("wessex")
	var target := person("wulfhere_wiltshire")
	k.base_skills.intrigue = 0
	target.base_skills.intrigue = 40
	eq(Feudal.arrest_chance(k, target, w.start_day), 0.1, "最少 10%")
	var fails := 0
	for i in 50:
		target.prisoner_of = ""
		if not w.arrest(k, target, w.start_day, []).ok:
			fails += 1
	check(fails > 30, "多半抓不到 (%d / 50)" % fails)
	check(target.opinion_of(k).parts.any(func(x: Array) -> bool: return x[0] == "想抓我"))


func test_prisoner_options() -> void:
	var k := w.ruler("wessex")
	var t := person("wulfhere_wiltshire")
	t.prisoner_of = k.id
	w.toggle_dungeon(t)
	check(t.dungeon)
	check(t.health_parts(w.start_day).any(func(x: Array) -> bool: return x[0] == "关在地牢里"), "地牢伤身体")
	w.release(k, t, w.start_day)
	eq(t.prisoner_of, "")
	check(t.opinion_of(k).parts.any(func(x: Array) -> bool: return x[0] == "放了我"))
	t.prisoner_of = k.id
	t.gold = 500
	var r := w.ransom(k, t, w.start_day)
	check(r.ok, r.text)
	eq(t.prisoner_of, "")
	t.prisoner_of = k.id
	var events := []
	var ex := w.execute(k, t, w.start_day, events)
	check(ex.ok)
	check(not t.alive)
	eq(k.tyranny, Feudal.TYRANNY_EXECUTE, "没罪处死算暴政")
	check(county("wiltshire").lord != t.id, "领地传下去了或者归了国王")


func test_vassal_succession() -> void:
	var v := person("aethelwulf_berkshire")
	var son := Person.new()
	son.id = "test_son"
	son.name = "测试儿子"
	son.father = v.id
	son.house = v.house
	son.culture = v.culture
	son.birth_day = w.start_day - 20 * GameDate.YEAR_DAYS
	son.traits = Traits.random_personality(w.rng)
	son.education = {"skill": "martial", "level": 2}
	for c in w.children_of(v):  # 开局生成的孩子先死, 只留测试的儿子
		w.kill(c, w.start_day + 2, [])
	w._register(son)
	var events := []
	w.kill(v, w.start_day + 3, events)
	eq(county("berkshire").lord, "test_son", "儿子继承伯克郡")
	eq(son.liege_realm, "wessex")
	check(events.any(func(e: Dictionary) -> bool: return e.type == "vassal_succession"))
	# 家里没人: 领地归国王
	var events2 := []
	w.kill(son, w.start_day + 4, events2)
	eq(county("berkshire").lord, w.ruler("wessex").id, "绝后了, 归国王")
	check(events2.any(func(e: Dictionary) -> bool: return e.type == "escheat"))


func test_king_death_moves_domain_and_vassals() -> void:
	var dead := w.ruler("wessex")
	var dom := w.lands_of(dead).map(func(c: Dictionary) -> String: return c.id)
	var vs := w.vassals_of(dead)
	w.kill(dead, w.start_day + 5, [])
	var heir := w.ruler("wessex")
	for id in dom:
		eq(county(id).lord, heir.id, "直辖领地归新国王")
	for v in vs:
		eq(w.liege_of(v), heir, "封臣效忠新国王")


func test_partition_moves_vassals() -> void:
	# 罗德里死了, 波伊斯分给二儿子: 波伊斯的领主跟着去
	var k := w.ruler("gwynedd")
	var powys_vassals := w.vassals_of(k).filter(func(v: Person) -> bool: return w.lands_of(v)[0].duchy == "powys")
	var events := []
	w.kill(k, w.start_day + 5, events)
	var powys: String = person("gwriad").realm
	for v in powys_vassals:
		eq(v.liege_realm, powys, "%s 跟着去了波伊斯" % v.name)
		eq(w.liege_of(v), person("gwriad"))
	for c in w.counties_of(powys):
		check(c.lord == "gwriad" or w.people[c.lord].liege_realm == powys, "%s 的主人在波伊斯" % c.name)


func test_ai_grants_excess() -> void:
	var k := w.ruler("wessex")
	for c in w.counties_of("wessex"):
		c.lord = k.id
	w._feudal_dirty = true
	var day := w.start_day
	for m in 36:
		day += 30
		w._ai_grants(day, [])
	check(w.income(k).domain <= w.income(k).limit + 1, "三年后电脑把多的领地封出去了 (%d / %d)" % [w.income(k).domain, w.income(k).limit])


func test_gift() -> void:
	var k := w.ruler("wessex")
	var t := person("aethelwulf_berkshire")
	has_text(w.gift(k, t, w.start_day).text, "钱不够")
	k.gold = 100
	var before: int = t.opinion_of(k).total
	check(w.gift(k, t, w.start_day).ok)
	eq(k.gold, 75.0)
	eq(t.opinion_of(k).total - before, 20, "好感 +20")
	w.gift(k, t, w.start_day)
	eq(t.opinion_of(k).total - before, 20, "再送一次不叠加 (刷新)")


func test_memories_expire_and_tyranny_decays() -> void:
	var k := w.ruler("wessex")
	var t := person("aethelwulf_berkshire")
	t.remember(k.id, "测试", 30, w.start_day + 40)
	k.tyranny = 20.0
	w.advance(60, w.start_day + 60)
	check(not t.memories.any(func(m: Dictionary) -> bool: return m.text == "测试"), "过期的忘了")
	check(k.tyranny < 20.0, "暴政每月降")


func test_long_run_feudal_consistency() -> void:
	w.rng.seed = 33
	var day := w.start_day
	for m in 60 * 12:
		day += 30
		w.advance(30, day)
		if m % 24 == 0:
			for c in w.counties:
				var l: Person = w.people[c.lord]
				check(l.alive, "%s 的主人活着" % c.name)
				check(w.realm_of_person(l) == c.holder, "%s 的主人属于这个国家 (%s)" % [c.name, l.name])
				# 第 6 块起国王打仗会被别国抓, 但不会关在自己国家的大牢里
				check(l.prisoner_of == "" or l.realm == "" or w.realm_of_person(w.people[l.prisoner_of]) != l.realm, "国王不在自己国家的大牢里")
			for p in w.living.values():
				check(not is_nan(p.gold), "钱是个数")  # 第 6 块起养兵、打输了赔钱会欠钱 (照三代)
				check(p.tyranny >= 0.0)
		if not failures.is_empty():
			failures.append("第 %d 个月" % m)
			return


func test_landed_relatives_marry_on_their_own() -> void:
	# 照三代 (用户 2026-10-10 选的): 你家里没领地的人只有你能说亲; 封了领地的家里人自己找对象
	var k := w.ruler("wessex")
	w.player = k.id
	var alfred := person("alfred")
	check(w.is_player_court(alfred), "阿尔弗雷德没领地: 归你管")
	check(w.is_player_court(k), "你自己的婚事你管")
	var dom := w.lands_of(k)
	w.grant_county(k, dom[dom.size() - 1], alfred, w.start_day, [])
	check(not w.is_player_court(alfred), "封了领地: 他自己做主")
	person("ealhswith").betrothed = "someone_else"  # 别让史料里的婚事插进来 (她订了别的婚, 阿尔弗雷德就不用等她)
	w.rng.seed = 4
	var day := w.start_day
	for m in 3 * 12:
		day += 30
		w._ai_marriages(day, [])
		if alfred.married():
			break
	check(alfred.married(), "封了地的阿尔弗雷德三年里自己结了婚")
	check(w.is_player_court(person("aethelhelm")), "你的小儿子还归你管")
