extends TestCase
## 家族和继承 (第 3 块, 用户 2026-10-10 同意的规矩和家人名单)

var w: World


func before_each() -> void:
	w = World.load_867()


func person(id: String) -> Person:
	return w.people[id]


func die(id: String) -> Array:
	var events := []
	w.kill(person(id), w.start_day + 10, events)
	return events


func test_recorded_family() -> void:
	var ae := w.ruler("wessex")
	eq(w.relation(ae, person("alfred")), "弟弟")
	eq(w.relation(ae, person("aethelswith")), "姐姐")
	eq(w.relation(ae, person("aethelwulf")), "父亲")
	eq(w.relation(ae, person("wulfthryth")), "妻子")
	eq(w.relation(ae, person("aethelhelm")), "儿子")
	eq(person("aethelswith").spouse, "ruler_mercia", "埃塞尔斯维斯嫁给伯格雷德")
	eq(w.ruler("mercia").spouse, "aethelswith", "配偶两边都记上")
	eq(w.relation(w.ruler("isles"), person("aud")), "女儿")
	eq(person("aud").spouse, "ruler_dublin", "凯蒂尔的女儿奥德嫁给阿姆莱夫")
	eq(w.relation(w.ruler("dublin"), person("thorstein")), "儿子")
	eq(w.relation(person("angharad"), w.ruler("seisyllwg")), "哥哥", "安加拉德是古贡的妹妹 (按估计的生年)")
	eq(w.relation(w.ruler("gwynedd"), person("cadell")), "儿子")
	eq(w.children_of(w.ruler("gwynedd")).size(), 7, "罗德里七个儿子")
	eq(w.relation(person("land"), w.ruler("osraige")), "哥哥", "兰是凯尔伯尔的妹妹")
	eq(person("land").spouse, "ruler_ailech")
	check(person("alba_daughter").name != "", "没留下名字的女儿有了随机的名字")
	eq(person("eochaid").mother, "alba_daughter")
	check(not person("aethelwulf").alive and not person("ragnar").alive, "去世的长辈留着连家谱")
	eq(w.house_name(ae.house), "塞尔迪克家族")
	eq(person("halfdan").house, w.ruler("great_army").house)


func test_children_look_like_parents() -> void:
	var same := 0
	var total := 0
	for c in w.children_of(w.ruler("gwynedd")):
		for gene in ["hair", "eyes", "nose", "jaw"]:
			total += 1
			if c.dna[gene] == w.ruler("gwynedd").dna[gene] or c.dna[gene] == person("angharad").dna[gene]:
				same += 1
	eq(same, total, "孩子的长相每样都是从爸爸或妈妈那里来的")


func test_heirs_at_start() -> void:
	eq(w.heir("wessex", w.start_day).id, "alfred", "长者继承: 威塞克斯是弟弟阿尔弗雷德, 不是小儿子")
	eq(w.heir("gwynedd", w.start_day).id, "anarawd", "平分: 格温内斯是长子安纳拉乌德")
	eq(w.heir("great_army", w.start_day).id, "halfdan", "平分: 伊瓦尔没儿子, 是哥哥哈夫丹")
	eq(w.heir("alba", w.start_day).id, "aed_alba", "推举: 阿尔巴是成年的弟弟艾德, 不是 5 岁的儿子")
	eq(w.heir("dublin", w.start_day).id, "carlus", "平分: 都柏林是大儿子卡卢斯")
	check(w.heir("east_anglia", w.start_day) == null, "埃德蒙家族里没人")
	for id in ["ailech", "osraige"]:
		var h := w.heir(id, w.start_day)
		check(h != null and h.adult(w.start_day) and not h.female, id + " 推举出成年男人")


func test_seniority_succession() -> void:
	var events := die("ruler_wessex")
	eq(w.ruler("wessex").id, "alfred")
	eq(person("alfred").realm, "wessex")
	eq(person("alfred").rank, "king")
	eq(person("ruler_wessex").realm, "", "死了的人不再统治")
	var ev: Dictionary = events.filter(func(e: Dictionary) -> bool: return e.type == "succession")[0]
	eq(ev.law, "seniority")
	eq(ev.heir, "alfred")


func test_partition_splits_powys() -> void:
	var before := w.realm_order.size()
	var events := die("ruler_gwynedd")
	eq(w.ruler("gwynedd").id, "anarawd")
	eq(w.realm_order.size(), before + 1, "多出一个国家")
	var ev: Dictionary = events.filter(func(e: Dictionary) -> bool: return e.type == "succession")[0]
	eq(ev.splits.size(), 1)
	var powys: String = ev.splits[0][0]
	eq(ev.splits[0][1], "gwriad", "二儿子格里亚德分到波伊斯")
	eq(w.realms[powys].title, "波伊斯国王")
	eq(w.realms.gwynedd.title, "格温内斯国王")
	for c in ["mathrafal", "arwystli", "maelor"]:
		eq(w.by_id[c].holder, powys, c + " 归了波伊斯")
	eq(w.by_id.aberffraw.holder, "gwynedd")


func test_merge_when_heir_already_rules() -> void:
	die("ruler_gwynedd")
	var powys: String = person("gwriad").realm
	check(powys != "" and powys != "gwynedd", "格里亚德当了波伊斯国王")
	for id in ["cadell", "merfyn_ap_rhodri", "tudwal", "meurig_ap_rhodri", "gwyddelig"]:
		person(id).alive = false
	var events := []
	w.kill(person("anarawd"), w.start_day + 20, events)
	var ev: Dictionary = events.filter(func(e: Dictionary) -> bool: return e.type == "succession")[0]
	eq(ev.heir, "gwriad", "安纳拉乌德没儿子, 弟弟里只剩格里亚德")
	eq(ev.merged_into, powys, "格里亚德本来是波伊斯国王, 格温内斯也归了他")
	check(not w.realms.has("gwynedd"), "格温内斯这个国家并进波伊斯")
	eq(w.by_id.aberffraw.holder, powys)


func test_extinct_house_gets_new_ruler() -> void:
	var events := die("ruler_east_anglia")
	var ev: Dictionary = events.filter(func(e: Dictionary) -> bool: return e.type == "extinct")[0]
	var newp := w.ruler("east_anglia")
	eq(ev.heir, newp.id)
	check(newp.alive and newp.adult(w.start_day + 10))
	check(newp.house != "edmund" and w.houses.has(newp.house), "新国王是新家族")
	eq(newp.culture, "anglo_saxon", "新国王是当地人")
	check(w.realms.east_anglia.random, "说明是随机的")


func test_lifespans() -> void:
	# 活过 30 岁的人, 多半死在 60 多到 70 岁
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ages := []
	for i in 2000:
		var p := Person.new()
		p.birth_day = 0
		var day := 30 * 365
		while rng.randf() >= p.yearly_death_chance(day):
			day += 365
		ages.append(day / 365)
	ages.sort()
	var median: int = ages[1000]
	check(median >= 58 and median <= 75, "活过 30 岁的人中间那个死在 %d 岁" % median)
	check(ages[1900] <= 92, "95% 的人 92 岁以前死")


func test_monthly_prestige_and_coming_of_age() -> void:
	var kid := person("domnall_alba")
	kid.birth_day = w.start_day - 16 * 365 + 15  # 1 月 16 日满 16 岁
	check(kid.personality().is_empty(), "小孩还没有性格")
	w.rng.seed = 1
	var p := w.ruler("wessex")
	w.advance(40, w.start_day + 40)
	if kid.alive:
		eq(kid.personality().size(), 3, "满 16 岁有了 3 个性格")
		check(not kid.education.is_empty(), "教育也定了")
	if p.alive:
		eq(p.prestige, 1.0, "国王一个月涨 1 点威望")


func test_long_run_stays_consistent() -> void:
	# 让时间走 150 年 (每次一个月), 每次检查: 每个国家都有活着的国王, 领地都有主人, 没人同时当两个国家的国王
	var day := w.start_day
	var deaths := 0
	for m in 150 * 12:
		day += 30
		var events := w.advance(30, day)
		deaths += events.filter(func(e: Dictionary) -> bool: return e.type == "death").size()
		var rulers := {}
		for id in w.realm_order:
			var r := w.ruler(id)
			check(r.alive, "%s 的国王活着" % id)
			eq(r.realm, id)
			check(not rulers.has(r.id), "%s 同时当两个国家的国王" % r.name)
			rulers[r.id] = true
		for c in w.counties:
			check(w.realms.has(c.holder), "%s 的主人是在的国家" % c.name)
		if not failures.is_empty():
			failures.append("第 %d 个月出的错" % m)
			return
	check(deaths > 80, "150 年里死了不少人 (%d)" % deaths)
