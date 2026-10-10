extends TestCase
## 867 年的世界数据和地图工具做出来的领地图对得上

var world: World


func before_each() -> void:
	world = World.load_867()


func test_counts() -> void:
	eq(world.counties.size(), 130)
	eq(world.duchies.size(), 33)
	eq(world.kingdoms.size(), 4)
	eq(world.realms.size(), 26)
	eq(GameDate.text(world.start_day), "867 年 1 月 1 日")


func test_titles_chain_up() -> void:
	for c in world.counties:
		check(world.duchies.has(c.duchy), c.name + " 的公国")
		check(world.kingdoms.has(world.duchy_of(c).kingdom), c.name + " 的王国")
		check(world.realms.has(c.holder), c.name + " 的主人")
	for du in world.duchies.values():
		check(not world.counties_in_duchy(du.id).is_empty(), du.name + " 下面没有领地")


func test_every_realm_has_land_and_a_ruler() -> void:
	for id in world.realm_order:
		check(not world.counties_of(id).is_empty(), id + " 没有领地")
		check(String(world.realms[id].ruler) != "", id + " 没有统治者")


func test_867_rulers() -> void:
	eq(world.ruler_text("wessex"), "威塞克斯国王 埃塞尔雷德一世")
	eq(world.realms.great_army.ruler, "无骨者伊瓦尔")
	eq(world.by_id.york.holder, "great_army", "维京大军占着约克")
	eq(world.by_id.london.holder, "mercia", "伦敦 867 年归麦西亚")
	eq(world.realms.isles.ruler, "扁鼻子凯蒂尔")
	eq(world.realms.brycheiniog.ruler, "埃利塞德", "布雷肯用史料里 880 年代的国王")
	eq(world.realm_name("ailech"), "艾莱赫")
	eq(world.realm_name("great_army"), "维京大军")


func test_random_rulers_only_where_history_is_silent() -> void:
	var random := world.realm_order.filter(func(id: String) -> bool: return world.realms[id].random)
	random.sort()
	eq(random, ["galloway", "man", "orkney"])
	var again := World.load_867()
	eq(again.realms.orkney.ruler, world.realms.orkney.ruler, "同一个种子起的名字一样")


func test_random_names_fit_the_place() -> void:
	# 随机的统治者用当地当时的名字: 奥克尼用诺斯名, 加洛韦和马恩岛用诺斯-盖尔名
	var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(World.NAMES_FILE))
	var culture := {"orkney": "norse", "galloway": "norse_gael", "man": "norse_gael"}
	for seed in range(1, 40):
		var w := World.load_867(seed)
		for id in culture:
			check(names.male[culture[id]].has(w.realms[id].ruler), "%s 的 %s 不是 %s 的名字" % [id, w.realms[id].ruler, culture[id]])
	for kind in ["male", "female"]:
		for c in names[kind]:
			var list: Array = names[kind][c]
			check(not list.is_empty(), "%s %s 没有名字" % [kind, c])
			for n in list:
				check(list.count(n) == 1, "%s 里 %s 重复了" % [c, n])


func test_province_image_matches_counties() -> void:
	var pm := ProvinceMap.new()
	eq(pm.size(), world.map_size, "领地图的大小")
	for c in world.counties:
		eq(pm.index_at(c.seat), c.index, c.name + " 的都城在它自己的领地里")
		check(Rect2(c.rect).has_point(c.seat), c.name + " 的都城在它的范围里")
	eq(pm.index_at(Vector2(5, 5)), 0, "角上是海")
	eq(pm.index_at(Vector2(-10, 50)), 0, "地图外面")


func test_neighbors_go_both_ways() -> void:
	for c in world.counties:
		for n in c.neighbors:
			check(world.by_id[n].neighbors.has(c.id), "%s 和 %s 互为邻居" % [c.name, world.by_id[n].name])
	check(world.by_id.hampshire.neighbors.has("wiltshire"), "汉普郡挨着威尔特郡")
	check(world.by_id.wight.neighbors.is_empty(), "怀特岛是岛, 没有陆地邻居")
	check(world.by_id.wight.coastal)


func test_rulers_are_people() -> void:
	for id in world.realm_order:
		var p := world.ruler(id)
		eq(p.realm, id)
		eq(p.name, world.realms[id].ruler)
		eq(p.culture, world.realms[id].culture)
		eq(p.rank, "king")
		check(p.age(world.start_day) >= 16 and p.age(world.start_day) <= 75, "%s %d 岁" % [p.name, p.age(world.start_day)])
	var ae := world.ruler("wessex")
	check(ae.age(world.start_day) in [19, 20], "埃塞尔雷德约 847 年生, 867 年 19 或 20 岁")
	check(not ae.birth_estimated, "埃塞尔雷德的生年有史料")
	check(world.ruler("mercia").birth_estimated, "伯格雷德的生年是估计的")
	eq(ae.age(world.start_day + 365 * 10), ae.age(world.start_day) + 10, "过十年大十岁")


func test_recorded_looks() -> void:
	eq(world.ruler("isles").dna.nose, 3, "扁鼻子凯蒂尔是扁宽鼻子")
	eq(world.ruler("ailech").dna.hair, "fair_grey", "艾德·芬德利亚斯是浅色发灰的头发")
	eq(world.ruler("dublin").dna.hair, "flaxen", "「白色的奥拉夫」是浅色头发")
	for seed in range(1, 20):
		eq(World.load_867(seed).ruler("isles").dna.nose, 3, "换了种子也还是扁鼻子")


func test_every_ruler_portrait() -> void:
	for id in world.realm_order:
		var p := world.ruler(id)
		for years in [0, 30]:
			var img := Portrait.make(p.looks(world.start_day + years * 365))
			eq(img.get_size(), Vector2i(Portrait.W, Portrait.H))
			check(img.get_pixel(60, 60).a > 0.5, "%s 的头像脸上有颜色" % p.name)
			check(img.get_pixel(1, 1).a < 0.5, "%s 的头像角上是空的" % p.name)
	var a := Portrait.make(world.ruler("wessex").looks(world.start_day))
	var b := Portrait.make(world.ruler("wessex").looks(world.start_day))
	eq(a.get_data(), b.get_data(), "同一个人画两次一模一样")


func test_historical_personalities() -> void:
	# 用户 2026-10-10 同意的名单: 史料里看得出来的性格一定有, 不够 3 个随机补
	var expect := {
		"wessex": ["zealous", "brave"], "mercia": ["zealous"], "east_anglia": ["zealous", "brave"],
		"northumbria": ["ambitious", "sadistic"], "great_army": ["deceitful", "sadistic"], "cornwall": ["zealous"],
		"alba": ["brave"], "isles": ["ambitious"], "gwynedd": ["brave"], "dyfed": ["greedy", "arbitrary"],
		"glywysing": ["zealous"], "ailech": ["brave"], "dublin": ["ambitious", "callous"], "osraige": ["deceitful", "ambitious"],
	}
	for seed in [1, 2, 3, 867]:
		var w := World.load_867(seed)
		for id in expect:
			var p := w.ruler(id)
			for t in expect[id]:
				check(p.has_trait(t), "%s 应该%s" % [p.name, Traits.get_trait(t).name])
			eq(p.personality().size(), 3, p.name)
			has_text(p.note, Traits.get_trait(expect[id][0]).name, p.name + " 的说明里写了史料依据")
	var w := World.load_867()
	eq(w.ruler("gwynedd").base_skills.martial, 10, "罗德里军事底子高")
	eq(w.ruler("osraige").base_skills.intrigue, 10, "凯尔伯尔密谋底子高")
