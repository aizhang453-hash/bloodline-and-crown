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
	eq(world.realm_name("ailech"), "艾莱赫")
	eq(world.realm_name("great_army"), "维京大军")


func test_random_rulers_only_where_history_is_silent() -> void:
	var random := world.realm_order.filter(func(id: String) -> bool: return world.realms[id].random)
	random.sort()
	eq(random, ["brycheiniog", "galloway", "man", "orkney"])
	var again := World.load_867()
	eq(again.realms.orkney.ruler, world.realms.orkney.ruler, "同一个种子起的名字一样")


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
