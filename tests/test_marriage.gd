extends TestCase
## 结婚生子 (第 4 块, 用户 2026-10-10 同意的规矩: 都按推荐, 近亲结婚照 867 年的史实)

var w: World
var _n := 0


func before_each() -> void:
	w = World.load_867()


func person(id: String) -> Person:
	return w.people[id]


## 造一个人放进世界 (born: 哪年生)
func make(female: bool, born: int, father: Person = null, mother: Person = null, culture := "anglo_saxon") -> Person:
	_n += 1
	var p := Person.new()
	p.id = "test_%d" % _n
	p.name = "测试%d" % _n
	p.female = female
	p.culture = culture
	p.rank = "noble"
	p.birth_day = GameDate.to_day(born, 1, 1)
	p.father = father.id if father else ""
	p.mother = mother.id if mother else ""
	p.house = father.house if father else ""
	p.dna = Portrait.random_dna(w.rng, culture)
	p.traits = Traits.random_personality(w.rng)
	w._register(p)
	return p


## 一条往下传 n 代的线: 返回第 n 代的那个人 (从 top 往下, 每代一个男人, 最后一个按 female 定)
func line(top: Person, n: int, female: bool, culture := "anglo_saxon") -> Person:
	var p := top
	for i in n:
		var wife := make(true, 800 + i * 20, null, null, culture)
		p = make(female if i == n - 1 else false, 820 + i * 20, p, wife, culture)
	return p


func test_new_people_from_history() -> void:
	var ea := person("ealhswith")
	check(ea.alive and ea.spouse == "", "埃尔斯维斯开局没结婚 (868 年才嫁给阿尔弗雷德)")
	eq(w.relation(person("land"), person("flann_sinna")), "儿子", "弗兰·辛纳是兰的儿子")
	eq(w.relation(person("land"), person("mael_sechnaill")), "前夫", "兰的第一个丈夫")
	eq(person("flann_sinna").house, w.ruler("mide").house, "弗兰是米斯王族")
	eq(w.historical_match(person("alfred"), ea).left(2), "阿瑟", "史料里两人是夫妻")
	eq(w.historical_match(person("alfred"), person("mael_muire")), "")


func test_alliances_at_start() -> void:
	# 开局已经有的婚事 = 同盟
	check(w.allies("wessex").has("mercia"), "埃塞尔斯维斯嫁给麦西亚国王: 威塞克斯和麦西亚是同盟")
	check(w.allies("mercia").has("wessex"))
	check(w.allies("gwynedd").has("seisyllwg"), "罗德里娶了古贡的妹妹")
	check(w.allies("ailech").has("osraige"), "艾德娶了凯尔伯尔的妹妹")
	check(w.allies("dublin").has("isles"), "阿姆莱夫娶了凯蒂尔的女儿")
	check(w.allies("alba").has("strathclyde"), "鲁恩娶了基纳德的女儿")
	check(not w.allies("wessex").has("dublin"))


func test_church_forbids_seven_degrees() -> void:
	var top := make(false, 700)
	var a := line(top, 2, false)        # 孙子
	var b := line(top, 2, true)         # 孙女 (堂表兄妹)
	has_text(Marriage.kin_problem(w, a, b), "堂表兄弟姐妹")
	has_text(Marriage.kin_problem(w, a, b), "教会")
	var far_a := line(top, 7, false)
	var far_b := line(top, 7, true)     # 往上七代才有同一个祖先
	check(Marriage.kin_problem(w, far_a, far_b) != "", "七代以内都不行")
	var top2 := make(false, 600)
	var far_c := line(top2, 8, false)
	var far_d := line(top2, 8, true)    # 隔八代
	eq(Marriage.kin_problem(w, far_c, far_d), "", "八代就可以了")
	var sis := make(true, 830, person("aethelwulf"), person("osburh"))
	has_text(Marriage.kin_problem(w, person("alfred"), sis), "兄弟姐妹")


func test_norse_may_marry_cousins() -> void:
	var top := make(false, 760, null, null, "norse")
	var a := line(top, 2, false, "norse")
	var b := line(top, 2, true, "norse")
	eq(Marriage.kin_problem(w, a, b), "", "北欧多神教: 可以娶堂表兄妹")
	var uncle: Person = w.people[a.father]
	has_text(Marriage.kin_problem(w, uncle, b), "叔伯", "叔叔和侄女不行")
	var sister := make(true, 840, w.people[a.father], w.people[a.mother], "norse")
	has_text(Marriage.kin_problem(w, a, sister), "兄弟姐妹")
	# 一边是基督徒就照严的
	var c := line(top, 2, true, "anglo_saxon")
	check(Marriage.kin_problem(w, a, c) != "", "一个基督徒一个维京人: 照教会的规矩")


func test_church_forbids_in_laws() -> void:
	var dad := make(false, 800)
	var mum := make(true, 805)
	var son := make(false, 830, dad, mum)
	var stepmum := make(true, 815)
	var events := []
	dad.spouse = stepmum.id  # 父亲后来娶的妻子 (继母)
	stepmum.spouse = dad.id
	dad.alive = false
	has_text(Marriage.kin_problem(w, son, stepmum), "姻亲", "继母不能娶 (埃塞尔博尔德娶继母朱迪丝被阿瑟骂)")
	var brother := make(false, 832, dad, mum)
	var widow := make(true, 835)
	w.marry(brother, widow, w.start_day, events)
	brother.alive = false
	has_text(Marriage.kin_problem(w, son, widow), "姻亲", "嫂子 / 弟媳不能娶")
	# 维京人没有姻亲的规矩 (只看血亲)
	var n_dad := make(false, 800, null, null, "norse")
	var n_son := make(false, 830, n_dad, make(true, 805, null, null, "norse"), "norse")
	var n_step := make(true, 815, null, null, "norse")
	w.marry(n_dad, n_step, w.start_day, events)
	n_dad.alive = false
	eq(Marriage.kin_problem(w, n_son, n_step), "", "北欧多神教不管姻亲")


func test_kinship() -> void:
	var dad := make(false, 800)
	var mum := make(true, 805)
	var a := make(false, 830, dad, mum)
	var b := make(true, 832, dad, mum)
	eq(Marriage.kinship(w, a, b), 0.5, "亲兄妹")
	var half := make(true, 834, dad, make(true, 810))
	eq(Marriage.kinship(w, a, half), 0.25, "同父异母")
	var a_kid := make(false, 855, a, make(true, 835))
	var b_kid := make(true, 856, make(false, 830), b)
	eq(Marriage.kinship(w, a_kid, b_kid), 0.125, "堂表兄妹")
	eq(Marriage.kinship(w, a, b_kid), 0.25, "舅舅和外甥女")
	eq(Marriage.kinship(w, a, dad), 0.5, "父子")


func test_marry_makes_alliance_and_opinion() -> void:
	var alfred := person("alfred")
	var mm := person("mael_muire")
	eq(Marriage.problem(w, alfred, mm, w.start_day), "")
	var events := []
	w.marry(alfred, mm, w.start_day, events)
	eq(alfred.spouse, mm.id)
	eq(mm.spouse, alfred.id)
	check(alfred.married() and mm.married())
	eq(w.relation(alfred, mm), "妻子")
	check(w.allies("wessex").has("alba"), "国王的弟弟娶了国王的妹妹: 两国结盟")
	eq(events[0].alliance.size(), 2, "消息里写了结盟")
	check(alfred.opinion_of(mm).parts.any(func(x: Array) -> bool: return x[0] == "夫妻"), "夫妻互相有好感")
	has_text(Marriage.problem(w, alfred, person("ealhswith"), w.start_day), "已经结婚")


func test_marrying_up_gives_prestige() -> void:
	var edmund := w.ruler("east_anglia")
	var alba := w.ruler("alba")
	var before := alba.prestige
	w.marry(edmund, person("mael_muire"), w.start_day, [])
	eq(alba.prestige - before, 25.0, "妹妹嫁给国王 (高一档): 阿尔巴国王涨 25 威望")


func test_spouse_helps_ruler() -> void:
	var king := w.ruler("wessex")
	var queen := person("wulfthryth")
	queen.base_skills.diplomacy = 20
	var parts := king.skill_parts("diplomacy", w.start_day)
	var help: Array = parts.filter(func(x: Array) -> bool: return String(x[0]).contains("帮忙"))
	eq(help.size(), 1, "妻子帮忙")
	eq(help[0][1], queen.skill("diplomacy", w.start_day, false) / Person.SPOUSE_SHARE, "妻子外交的五分之一")
	var total := 0
	for x in parts:
		total += int(x[1])
	eq(king.skill("diplomacy", w.start_day), maxi(0, total), "总数跟每一项加起来一样")
	check(king.skill_parts("prowess", w.start_day).all(func(x: Array) -> bool: return not String(x[0]).contains("帮忙")), "武力不帮")


func test_history_marriage_happens_in_868() -> void:
	var alfred := person("alfred")
	var ea := person("ealhswith")
	var day867 := GameDate.to_day(867, 6, 1)
	for i in 50:
		w._history_marriages(day867, [])
	eq(alfred.spouse, "", "867 年还没到")
	var day868 := GameDate.to_day(868, 3, 1)
	var events := []
	for i in 100:
		w._history_marriages(day868, events)
	eq(alfred.spouse, ea.id, "868 年照史料结婚")
	var ev: Array = events.filter(func(e: Dictionary) -> bool: return e.husband == "alfred")
	has_text(ev[0].history, "868")


func test_history_skips_player_family() -> void:
	w.player = w.realms.wessex.ruler_id
	for i in 100:
		w._history_marriages(GameDate.to_day(869, 1, 1), [])
	eq(person("alfred").spouse, "", "玩家家里的人由玩家说亲")
	eq(w._reserved_for(person("ealhswith"), w.start_day), "alfred", "埃尔斯维斯还在等阿尔弗雷德, 电脑不把她嫁给别人")


func test_history_children_names() -> void:
	var alfred := person("alfred")
	var ea := person("ealhswith")
	w.marry(alfred, ea, w.start_day, [])
	var day := GameDate.to_day(870, 1, 1)
	var sons := []
	var daughters := []
	for i in 40:
		var c: Person = w._new_child(alfred, ea, day + i)
		(daughters if c.female else sons).append(c)
	eq(daughters[0].id, "aethelflaed", "头一个女儿是埃塞尔弗莱德")
	eq(daughters[0].name, "埃塞尔弗莱德")
	eq(daughters[1].name, "埃塞尔吉夫")
	eq(daughters[2].name, "埃尔夫思里斯")
	eq(sons[0].id, "edward_elder", "头一个儿子是爱德华")
	eq(sons[1].name, "埃塞尔沃德")
	check(not sons[2].note.begins_with("史料里"), "史料里的孩子用完了就随机起名")
	has_text(sons[0].note, "史料里")
	eq(sons[0].house, alfred.house, "孩子算父亲的家族")
	# 只写了父亲的: 卡德尔不管娶谁, 头一个儿子是休厄尔
	var cadell := person("cadell")
	var wife := make(true, 850, null, null, "welsh")
	var first_son: Person = null
	for i in 20:
		var c: Person = w._new_child(cadell, wife, day + i)
		if not c.female:
			first_son = c
			break
	eq(first_son.id, "hywel_dda", "卡德尔的头一个儿子是「好人」休厄尔")
	# 换了妻子: 阿尔弗雷德和埃尔斯维斯的名字不给别的妻子的孩子
	var other := make(true, 850)
	var c2: Person = w._new_child(person("ruler_wessex"), other, day)
	check(not c2.note.begins_with("史料里"))


func test_pregnancy_and_birth() -> void:
	var alfred := person("alfred")
	var ea := person("ealhswith")
	w.marry(alfred, ea, w.start_day, [])
	var day := w.start_day + 400
	ea.pregnant = {"father": alfred.id, "due": day}
	var events := []
	w._give_birth(ea, day, events)
	check(ea.pregnant.is_empty(), "生完了")
	var ev: Dictionary = events.filter(func(e: Dictionary) -> bool: return e.type == "birth")[0]
	check(ev.children.size() >= 1)
	var baby: Person = person(ev.children[0])
	eq(baby.father, alfred.id)
	eq(baby.mother, ea.id)
	eq(baby.birth_day, day)
	eq(baby.age(day), 0)
	check(w.children_of(alfred).has(baby) and w.children_of(ea).has(baby), "家谱上有了")
	for gene in ["hair", "eyes", "nose"]:
		check(baby.dna[gene] == alfred.dna[gene] or baby.dna[gene] == ea.dna[gene], "长相从爸妈来: " + gene)
	eq(baby.culture, "anglo_saxon")
	eq(baby.rank, "noble")


func test_fertility_by_age() -> void:
	var woman := make(true, 840)
	eq(woman.fertility(GameDate.to_day(855, 6, 1)), 0.0, "不满 16 岁不能生")
	eq(woman.fertility(GameDate.to_day(865, 6, 1)), 1.0, "20 多岁最容易")
	check(woman.fertility(GameDate.to_day(877, 6, 1)) < 0.7, "37 岁难一些")
	eq(woman.fertility(GameDate.to_day(886, 6, 1)), 0.0, "45 岁以后不能生")
	var man := make(false, 800)
	eq(man.fertility(GameDate.to_day(855, 6, 1)), 0.75, "男人 50 多岁难一些")


func test_conception_and_birth_over_time() -> void:
	# 一对 18 岁结婚的夫妻, 不让他们死, 到 45 岁平均生 5 个左右 (算上死人以后平均 4–5 个, 见 test_family 的长跑)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var total := 0
	for k in 300:
		var wife := make(true, 850)
		var husband := make(false, 846)
		w.marry(husband, wife, w.start_day, [])
		var day := GameDate.to_day(868, 1, 1)
		var births := 0
		while wife.fertility(day) > 0.0 or wife.age(day) < 20:
			if not wife.pregnant.is_empty() and day >= int(wife.pregnant.due):
				wife.pregnant = {}
				wife.last_birth = day
				births += 1
			if wife.pregnant.is_empty():
				w._try_conceive(wife, day)
			day += 30
		total += births
	var avg := total / 300.0
	check(avg >= 4.0 and avg <= 7.5, "不死的话 18 到 45 岁平均生 %.1f 个" % avg)


func test_child_mortality() -> void:
	# 大约五个孩子里有一个长不到 16 岁 (用户定的, 比史实的三分之一轻)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var died := 0
	for i in 4000:
		var p := Person.new()
		p.birth_day = 0
		for year in 16:
			if rng.randf() < p.yearly_death_chance(year * 365 + 10):
				died += 1
				break
	var share := died / 4000.0
	check(share > 0.15 and share < 0.26, "长不到 16 岁的 %.1f%%" % (share * 100))


func test_childbirth_risk() -> void:
	var p := make(true, 845)
	var c := p.childbirth_death_chance(GameDate.to_day(868, 1, 1))
	check(c > 0.015 and c < 0.03, "健康的母亲生一次大约 2%% 会死 (%.3f)" % c)
	p.traits.append("physique_bad_3")
	check(p.childbirth_death_chance(GameDate.to_day(868, 1, 1)) > c, "身体差的更危险")


func test_congenital_inheritance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var dad := make(false, 820)
	var mum := make(true, 825)
	dad.traits = ["intellect_good_1"]
	mum.traits = ["intellect_good_1", "stuttering"]
	var smart := 0
	var stutter := 0
	for i in 4000:
		var t := Traits.inherit_congenital(rng, dad, mum)
		if t.has("intellect_good_1"):
			smart += 1
		if t.has("stuttering"):
			stutter += 1
	check(smart / 4000.0 > 0.45 and smart / 4000.0 < 0.58, "爸妈都聪明: 孩子一半聪明 (%d)" % smart)
	check(stutter / 4000.0 < 0.04, "口吃不遗传 (只有平常 2%% 的机会)")
	mum.traits = []
	smart = 0
	for i in 4000:
		if Traits.inherit_congenital(rng, dad, mum).has("intellect_good_1"):
			smart += 1
	check(smart / 4000.0 > 0.2 and smart / 4000.0 < 0.32, "一个聪明: 孩子大约四分之一 (%d)" % smart)


func test_inbred_children() -> void:
	# 北欧多神教可以娶堂表兄妹; 亲缘越近, 孩子越可能近亲繁殖 (亲兄妹 15%)
	var dad := make(false, 800, null, null, "norse")
	var mum := make(true, 805, null, null, "norse")
	var a := make(false, 830, dad, mum, "norse")
	var b := make(true, 832, dad, mum, "norse")
	var inbred := 0
	for i in 2000:
		var c: Person = w._new_child(a, b, w.start_day)
		if c.has_trait("inbred"):
			inbred += 1
	check(inbred > 220 and inbred < 380, "亲兄妹的孩子大约 15%% 近亲繁殖 (%d / 2000)" % inbred)
	check(Traits.get_trait("inbred").kind == "congenital")


func test_childhood_teacher_and_education() -> void:
	var kid := make(false, 865, person("ruler_wessex"), person("wulfthryth"))
	kid.traits = []
	var day := GameDate.to_day(867, 2, 1)
	w._grow(kid, day, [])
	eq(kid.childhood(), "", "2 岁还没有小时候的性格")
	day = GameDate.to_day(868, 2, 1)
	w._grow(kid, day, [])
	check(kid.childhood() != "", "3 岁有了小时候的性格")
	eq(Traits.get_trait(kid.childhood()).kind, "childhood")
	check(kid.focus == "", "6 岁才开始学")
	day = GameDate.to_day(871, 2, 1)
	w._grow(kid, day, [])
	check(kid.focus != "", "6 岁选了学什么")
	check(kid.guardian != "", "也找了老师")
	var teacher: Person = person(kid.guardian)
	check(teacher.adult(day) and teacher != kid)
	for p in w.teacher_candidates(kid, day):
		check(p.skill(kid.focus, day) <= teacher.skill(kid.focus, day), "电脑挑本事最好的老师")
	eq(kid.edu_years, 1, "学了一年")
	for y in range(872, 881):
		w._grow(kid, GameDate.to_day(y, 2, 1), [])
	eq(kid.edu_years, 10, "6 岁学到 15 岁, 一共 10 年")
	var ch := kid.childhood()
	w._come_of_age(kid, GameDate.to_day(881, 2, 1), [])
	eq(kid.childhood(), "", "16 岁小时候的性格没了")
	eq(kid.personality().size(), 3, "有了 3 个性格")
	check(not ch.is_empty())
	eq(kid.education.skill, kid.focus, "教育就是学的那一样")
	eq(kid.guardian, "", "学完了")


func test_better_teacher_better_education() -> void:
	eq(Traits.education_level(0.0), 1, "没攒分数: 差")
	eq(Traits.education_level(9.0), 3)
	eq(Traits.education_level(20.0), 4, "老师本事 20 教 10 年: 出色")
	check(Traits.focus_fits("rowdy", "martial"), "淘气的孩子学军事合适")
	check(not Traits.focus_fits("rowdy", "learning"))


func test_grown_personality_follows_childhood() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var hits := 0
	for i in 1000:
		var traits := Traits.grown_personality(rng, "rowdy", [])
		eq(traits.size(), 3)
		if traits.has("brave") or traits.has("wrathful") or traits.has("impatient"):
			hits += 1
		for t in traits:
			for o in traits:
				check(not Traits.opposite(t, o), "没有相反的性格")
	check(hits > 600, "淘气的孩子多半长成勇敢、易怒或急躁 (%d / 1000)" % hits)


func test_betrothal_then_marriage_at_16() -> void:
	var boy := person("owain_g")         # 欧温, 7 岁
	var girl := person("eithne_o")       # 埃斯尼, 9 岁
	eq(Marriage.problem(w, boy, girl, w.start_day), "还没满 16 岁 (可以先订婚)")
	eq(Marriage.problem(w, boy, girl, w.start_day, true), "")
	var events := []
	w.betroth(boy, girl, w.start_day, events)
	eq(w.relation(boy, girl), "未婚妻")
	w._betrothals_due(w.start_day + 365, events)
	eq(boy.spouse, "", "还小")
	var day := boy.birth_day + 16 * 365 + 30
	w._betrothals_due(day, events)
	eq(boy.spouse, girl.id, "都满 16 岁就成亲")
	eq(boy.betrothed, "")


func test_betrothal_ends_when_one_dies() -> void:
	var boy := person("owain_g")
	var girl := person("eithne_o")
	w.betroth(boy, girl, w.start_day, [])
	w.kill(girl, w.start_day + 10, [])
	eq(boy.betrothed, "", "未婚妻去世, 婚约没了")


func test_player_proposals() -> void:
	w.player = w.realms.wessex.ruler_id
	var alfred := person("alfred")
	var events := []
	var r := w.propose(alfred, person("aethelswith"), w.start_day, events)
	check(not r.ok)
	var acc := Marriage.acceptance(w, w.ruler("wessex"), alfred, person("mael_muire"), w.start_day)
	var r2 := w.propose(alfred, person("mael_muire"), w.start_day, events)
	eq(r2.ok, acc.total > 0, "答不答应看分数: " + str(acc))
	check(acc.parts.any(func(x: Array) -> bool: return String(x[0]).contains("结盟")), "对方想跟你结盟")
	# 订婚: 自己家的小孩
	var kid := person("aethelhelm")
	var noble := w.make_noble("anglo_saxon", true, 3, w.start_day)
	check(not w.people.has(noble.id), "说亲名单里的本地贵族还没放进世界")
	var r3 := w.propose(kid, noble, w.start_day, events)
	check(r3.ok, "跟本地贵族家的小姑娘订婚: " + r3.text)
	check(w.people.has(noble.id), "选上了才放进世界")
	eq(kid.betrothed, noble.id)
	has_text(r3.text, "订婚")


func test_ai_marries_royals_but_not_player_family() -> void:
	w.player = w.realms.gwynedd.ruler_id
	w.rng.seed = 9
	var day := w.start_day
	for m in 5 * 12:
		day += 30
		w.advance(30, day)
	for id in ["anarawd", "gwriad", "cadell"]:
		var p := person(id)
		if p.alive and w.is_player_court(p):  # 当了国王、封了领地的就自己做主了 (照三代)
			eq(p.spouse, "", "%s 是玩家家里没领地的人, 电脑不替他说亲" % p.name)
	var single := 0
	var total := 0
	for rid in w.realm_order:
		if rid == "gwynedd" or w.ruler(rid).house == w.ruler("gwynedd").house:
			continue
		for c in w.children_of(w.ruler(rid)):
			if c.alive and c.age(day) >= 18 and c.age(day) <= 40:
				total += 1
				if not c.married():
					single += 1
	check(total > 5, "有不少国王的成年孩子 (%d)" % total)
	check(single <= total / 3, "五年后国王的成年孩子多半结了婚 (%d / %d 没结)" % [single, total])


func test_marriages_respect_rules_over_time() -> void:
	w.rng.seed = 21
	var day := w.start_day
	var married := []
	for m in 30 * 12:
		day += 30
		for e in w.advance(30, day):
			if e.type == "marriage":
				married.append([e.husband, e.wife, day])
	check(married.size() > 30, "30 年里结了不少婚 (%d)" % married.size())
	for x in married:
		var h: Person = person(x[0])
		var wf: Person = person(x[1])
		check(not h.female and wf.female, "一男一女")
		check(h.age(x[2]) >= 16 and wf.age(x[2]) >= 16, "都满 16 岁")
		var pair := Marriage.nearest_common(w, h, wf)
		var strict := "christian" if Marriage.faith_of(h.culture) == "christian" or Marriage.faith_of(wf.culture) == "christian" else "norse"
		check(not Marriage.kin_forbidden(strict, pair), "%s 和 %s 不是不能结婚的近亲" % [h.name, wf.name])
	for p in w.living.values():
		if p.married():
			var s: Person = p.living_spouse()
			check(s.spouse == p.id or s.secondary.has(p.id), "%s 的配偶两边对得上" % p.name)
		check(p.secondary.size() <= Marriage.max_wives(p) - 1, "次妻不超过上限")
		check(p.pregnant.is_empty() or p.female, "只有女人怀孕")


func test_homelands() -> void:
	eq(w.ruler("ailech").homeland, "ireland")
	eq(person("flann_sinna").homeland, "ireland")
	eq(person("gormlaith_brega").homeland, "ireland", "没有国家的家族按文化")
	eq(person("mael_muire").homeland, "scotland", "梅尔穆雷是阿尔巴人")
	eq(w.ruler("alba").homeland, "scotland")
	eq(person("alfred").homeland, "england")
	eq(w.ruler("gwynedd").homeland, "wales")


func test_irish_law_allows_more_wives() -> void:
	# 爱尔兰古法: 艾德有正妻兰, 还能娶梅尔穆雷当次妻; 他们的儿子就是史料里的尼尔
	var aed := w.ruler("ailech")
	var land := person("land")
	var mm := person("mael_muire")
	eq(Marriage.max_wives(aed), 3)
	eq(Marriage.problem(w, aed, mm, w.start_day), "", "爱尔兰国王可以再娶")
	var acc := Marriage.acceptance(w, w.ruler("alba"), mm, aed, w.start_day)
	check(acc.parts.any(func(x: Array) -> bool: return String(x[0]).contains("次妻")), "做次妻对方不太愿意")
	var events := []
	w.marry(aed, mm, w.start_day, events)
	eq(aed.spouse, land.id, "兰还是正妻")
	eq(aed.secondary, [mm.id])
	eq(mm.spouse, aed.id)
	check(events[0].secondary, "消息里写了是次妻")
	eq(w.relation(aed, mm), "次妻")
	eq(w.relation(mm, aed), "丈夫")
	eq(w.wives_of(aed).size(), 2)
	check(w.allies("ailech").has("alba") and w.allies("ailech").has("osraige"), "两门婚事, 两个同盟")
	check(aed.opinion_of(mm).parts.any(func(x: Array) -> bool: return x[0] == "夫妻"))
	var son: Person = null
	for i in 20:
		var c: Person = w._new_child(aed, mm, w.start_day + 300 + i)
		if not c.female:
			son = c
			break
	eq(son.id, "niall_glundub", "艾德和梅尔穆雷的头一个儿子是「黑膝」尼尔")


func test_irish_wife_limit_and_promotion() -> void:
	var flann := person("flann_sinna")
	var events := []
	w.marry(flann, person("gormlaith_brega"), w.start_day, events)
	var e2 := w.make_noble("gaelic", true, 20, w.start_day)
	var e3 := w.make_noble("gaelic", true, 20, w.start_day)
	var e4 := w.make_noble("gaelic", true, 20, w.start_day)
	for x in [e2, e3, e4]:
		w._register(x)
	w.marry(flann, e2, w.start_day, events)
	w.marry(flann, e3, w.start_day, events)
	has_text(Marriage.problem(w, flann, e4, w.start_day), "最多 3 个", "正妻加两个次妻, 不能再多")
	w.kill(person("gormlaith_brega"), w.start_day + 5, events)
	eq(flann.spouse, e2.id, "正妻去世, 最早的次妻当正妻")
	eq(flann.secondary, [e3.id])
	check(flann.former_spouses.has("gormlaith_brega"))
	eq(Marriage.problem(w, flann, e4, w.start_day + 6), "", "又能再娶一个")
	w.kill(e3, w.start_day + 7, events)
	eq(flann.secondary, [], "次妻去世")
	check(flann.former_spouses.has(e3.id))


func test_only_ireland_has_more_wives() -> void:
	# 阿尔巴也是盖尔人, 但查不到史料, 不算; 都柏林的维京人也不算
	var aed_alba := person("aed_alba")
	var wife := w.make_noble("gaelic", true, 20, w.start_day)
	w._register(wife)
	w.marry(aed_alba, wife, w.start_day, [])
	eq(Marriage.max_wives(aed_alba), 1)
	has_text(Marriage.problem(w, aed_alba, person("thorunn"), w.start_day), "已经结婚了")
	eq(Marriage.max_wives(w.ruler("dublin")), 1, "都柏林的诺斯-盖尔人")
	eq(Marriage.max_wives(w.ruler("wessex")), 1)
	eq(Marriage.max_wives(person("land")), 1, "女人只能有一个丈夫")


func test_history_irish_second_marriage() -> void:
	var aed := w.ruler("ailech")
	for i in 100:
		w._history_marriages(GameDate.to_day(868, 3, 1), [])
	check(aed.secondary.has("mael_muire"), "868 年起照史料, 艾德娶梅尔穆雷当次妻")
	eq(aed.spouse, "land")
