extends TestCase
## 存档 (照三代: 随时能存、能读, 每年自动存一次)。存档写到临时文件夹, 不碰真的存档。

var w: World


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("bloodline_test_save_%d" % OS.get_process_id())
	w = World.load_867(42)


func after_each() -> void:
	if DirAccess.dir_exists_absolute(SaveGame.dir):
		for file in DirAccess.get_files_at(SaveGame.dir):
			DirAccess.remove_absolute(SaveGame.dir.path_join(file))


func _run(world: World, months: int, from: int) -> int:
	var day := from
	for m in months:
		day += 30
		world.advance(30, day)
	return day


func test_round_trip_keeps_everything() -> void:
	w.player = w.realms.wessex.ruler_id
	var day := _run(w, 30, w.start_day)
	var clock := Clock.new(day)
	var path := SaveGame.write("测试", w, clock, {})
	check(FileAccess.file_exists(path), "存档文件在")
	var d := SaveGame.read(path)
	var w2 := World.from_save(d.world)
	eq(w2.people.size(), w.people.size(), "人数一样")
	eq(w2.living.size(), w.living.size())
	eq(w2.player, w.player)
	eq(w2.realm_order, w.realm_order)
	for id in ["alfred", "ealhswith", "aethelwulf_berkshire", w.realms.wessex.ruler_id]:
		var a: Person = w.people[id]
		var b: Person = w2.people[id]
		eq(b.name, a.name)
		eq(b.alive, a.alive)
		eq(b.spouse, a.spouse)
		eq(b.traits, a.traits)
		eq(b.birth_day, a.birth_day)
		eq(b.gold, a.gold)
		eq(b.married(), a.married(), "配偶接上了")
	for i in w.counties.size():
		eq(w2.counties[i].lord, w.counties[i].lord)
		eq(w2.counties[i].holder, w.counties[i].holder)
	for rid in w.realm_order:
		eq(w2.ruler(rid).id, w.ruler(rid).id)
		eq(w2.realms[rid].color, w.realms[rid].color)
		eq(w2.income(w2.ruler(rid)).gold, w.income(w.ruler(rid)).gold, rid + " 收入一样")
	eq(w2.children_of(w2.people["ruler_gwynedd"]).size(), w.children_of(w.people["ruler_gwynedd"]).size())


func test_loaded_world_continues_the_same() -> void:
	# 存了再读, 接着走, 跟没存过一样 (随机数也接着原来的)
	var day := _run(w, 12, w.start_day)
	var path := SaveGame.write("测试", w, Clock.new(day), {})
	var w2 := World.from_save(SaveGame.read(path).world)
	_run(w, 24, day)
	_run(w2, 24, day)
	eq(w2.living.size(), w.living.size(), "两年后活着的人数一样")
	var a: Array = w.living.keys()
	var b: Array = w2.living.keys()
	a.sort()
	b.sort()
	eq(b, a, "两年后活着的是同一批人")
	for rid in w.realm_order:
		eq(w2.ruler(rid).id, w.ruler(rid).id, rid + " 的国王一样")


func test_list_and_autosave_name() -> void:
	SaveGame.write("第一个", w, Clock.new(w.start_day), {})
	SaveGame.write("自动存档", w, Clock.new(w.start_day + 40), {}, SaveGame.AUTO)
	var list := SaveGame.list()
	eq(list.size(), 2)
	check(list.any(func(x: Dictionary) -> bool: return x.auto and x.label == "自动存档"))
	check(list.any(func(x: Dictionary) -> bool: return x.label == "第一个" and not x.auto))
	SaveGame.write("自动存档", w, Clock.new(w.start_day + 80), {}, SaveGame.AUTO)
	eq(SaveGame.list().size(), 2, "自动存档每次盖掉上一次")


func _war_digest(world: World) -> String:
	var parts := []
	for a in world.warfare.armies.values():
		parts.append("%s@%s:%d" % [a.owner, a.loc, int(world.warfare.soldiers(a))])
	for war in world.warfare.wars:
		parts.append("war %s>%s %d" % [war.attacker, war.defender, int(world.warfare.score(war).total)])
	for c in world.counties:
		if c.occupier != "":
			parts.append("occ %s %s" % [c.id, c.occupier])
	return " | ".join(parts)


func test_mid_war_save_continues_the_same() -> void:
	# 打仗打到一半 (开局维京大军和诺森布里亚就在打) 存档, 读回来接着走, 军队、战争、占领都跟没存过一样
	var day := w.start_day
	for i in 50:
		day += 1
		w.advance(1, day)
	check(not w.warfare.armies.is_empty(), "存档时有军队在外面")
	var path := SaveGame.write("打仗中", w, Clock.new(day), {})
	var w2 := World.from_save(SaveGame.read(path).world)
	eq(_war_digest(w2), _war_digest(w), "读回来一样")
	for i in 400:
		day += 1
		w.advance(1, day)
		w2.advance(1, day)
	eq(_war_digest(w2), _war_digest(w), "接着走 400 天还一样")
