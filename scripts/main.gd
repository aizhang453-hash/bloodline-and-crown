extends Node2D
## 游戏入口: 地图 + 界面 + 时间。
## 开局先选一个国王 (在地图上点领地, 再点「玩这个人」), 然后按空格让时间走起来。

var world: World
var clock: Clock
var map: MapView
var hud: Hud


var _year := 0     # 现在是哪一年 (换年时自动存档)
var allow_quit := true  # 测试里关掉 (乱玩点到「退出游戏」不能把测试关了)


func _ready() -> void:
	new_game({}, randi())


## 开一局新游戏 (开局设置改了也是重新开: 同一个种子, 名字这些不变)
func new_game(rules: Dictionary, seed: int) -> void:
	var w := World.load_867(seed, rules)
	_build(w, Clock.new(w.start_day))


## 搭起地图和界面 (开新游戏、读档都用)
func _build(w: World, c: Clock) -> void:
	for old in [map, hud]:
		if old != null:
			remove_child(old)
			old.queue_free()
	world = w
	clock = c
	var ym: Array = GameDate.from_day(clock.day)
	_year = int(ym[0]) * 2 + (1 if int(ym[1]) >= 7 else 0)
	map = MapView.new(world, ProvinceMap.new())
	add_child(map)
	hud = Hud.new(world, clock, map)
	add_child(hud)
	map.county_clicked.connect(_on_county_clicked)
	map.county_hovered.connect(hud.set_map_hover)
	hud.play_requested.connect(play_as)
	hud.mode_requested.connect(_on_mode)
	hud.close_requested.connect(close_panel)
	hud.events_happened.connect(handle_events)
	hud.save_requested.connect(save_game)
	hud.load_requested.connect(load_game)
	hud.quit_requested.connect(_quit)
	hud.rules_changed.connect(func(r: Dictionary) -> void:
		new_game(r, world.name_seed)
		hud.open_rules())
	hud.new_game_requested.connect(func() -> void: new_game({}, randi()))


func _process(delta: float) -> void:
	var days := clock.advance(delta)
	if days > 0:
		world.player = hud.player_id
		handle_events(world.advance(days, clock.day))
		var ym: Array = GameDate.from_day(clock.day)
		var half: int = int(ym[0]) * 2 + (1 if int(ym[1]) >= 7 else 0)
		if half != _year:
			var new_year: bool = int(ym[0]) != _year / 2
			_year = half
			if hud.player_id != "":
				# 照三代: 平时每年自动存一次; 铁人模式每半年存一次 (只有这一个档)
				if world.rules.ironman == "on":
					save_game("铁人模式", _ironman_file())
				elif new_year:
					save_game("自动存档", SaveGame.AUTO)
		hud.redraw()


## 时间走的时候出的事: 你的国王死了、你的孩子出生跳窗口 (游戏暂停), 别的写进右边的消息
func handle_events(events: Array) -> void:
	var map_changed := false
	for e in events:
		match e.type:
			"vassal_succession":
				if hud.player_id != "" and e.dead == hud.player_id:
					clock.paused = true
					hud.set_player(e.heir)
					hud.show_popup({"kind": "vassal_succession", "event": e})
				elif _in_my_realm(e.realm):
					hud.notify("%s去世了, %s继承了领地 (%s)" % [world.people[e.dead].name, world.people[e.heir].name, world.title_of(world.people[e.heir])])
				map_changed = true
			"escheat":
				if hud.player_id != "" and e.dead == hud.player_id:
					clock.paused = true
					if e.to != "":
						hud.show_popup({"kind": "vassal_over", "event": e})
				elif _in_my_realm(e.realm):
					hud.notify("%s家绝后了, 他的领地归了%s" % [world.people[e.dead].name, world.people[e.to].name if e.to != "" else "上面"])
				map_changed = true
			"grant":
				if _in_my_realm(world.realm_of_person(world.people[e.liege])) and e.liege != hud.player_id:
					hud.notify("%s封%s当了%s" % [world.people[e.liege].name, world.people[e.target].name, world.title_of(world.people[e.target])])
				map_changed = true
			"revoke", "arrest":
				map_changed = true
			"escape":
				var who: Person = world.people[e.person]
				if e.jailer == hud.player_id or e.person == hud.player_id or _mine(who):
					hud.notify("%s从%s的大牢里逃出来了" % [who.name, world.people[e.jailer].name])
			"birth":
				_on_birth(e)
			"marriage":
				_on_marriage(e)
			"grew_up":
				var p: Person = world.people[e.person]
				if _mine(p):
					hud.notify("你家的%s满 16 岁了: %s" % [p.name, Traits.education_name(p.education)])
			"guardian":
				var kid: Person = world.people[e.child]
				if _mine(kid):
					var who: String = ("换成了" + world.people[e.new].name) if e.new != "" else "要给他请一个新老师 (上面的提醒)"
					hud.notify("%s的老师%s去世了, %s" % [kid.name, world.people[e.old].name, who])
			"succession", "extinct":
				map_changed = map_changed or not e.splits.is_empty() or e.merged_into != "" or e.type == "extinct"
				if hud.player_id != "" and e.dead == hud.player_id:
					clock.paused = true
					if e.type == "extinct":
						hud.show_popup({"kind": "game_over", "event": e})
					else:
						hud.set_player(e.heir)
						hud.show_popup({"kind": "succession", "event": e})
				else:
					var dead: Person = world.people[e.dead]
					var heir: Person = world.people[e.heir]
					var text := "%s国王%s去世了, %s继位" % [e.realm_name, dead.name, heir.name]
					if e.type == "extinct":
						text = "%s国王%s去世, 家族绝后, 贵族推举%s当了国王" % [e.realm_name, dead.name, heir.name]
					for sp in e.splits:
						text += "; %s分到了%s" % [world.people[sp[1]].name, world.realm_name(sp[0])]
					hud.notify(text)
			"death":
				var p: Person = world.people[e.person]
				if not e.was_ruler and e.person != hud.player_id and _mine(p):
					hud.notify("你的家人%s%s, 享年 %d 岁" % [p.name, e.get("cause", "") if e.get("cause", "") != "" else "去世了", p.age(e.day)])
	if map_changed:
		map.refresh_colors()
	if not events.is_empty():
		hud.refresh_person()


## 你家族里的人
func _mine(p: Person) -> bool:
	return hud.player_id != "" and world.is_player_family(p)


## 是你 (所在) 的国家
func _in_my_realm(realm_id: String) -> bool:
	return hud.player != "" and realm_id == hud.player


## 生孩子: 你 (国王) 的孩子跳窗口起名, 家里别人的孩子写消息
func _on_birth(e: Dictionary) -> void:
	var me: Person = hud.me()
	for id in e.children:
		var baby: Person = world.people[id]
		if me != null and e.father == me.id:
			clock.paused = true
			hud.show_popup({"kind": "birth", "event": e, "child": id, "names": hud.birth_names(baby)})
		elif _mine(baby) or (me != null and e.mother == me.id):
			hud.notify("%s生了一个%s: %s" % [world.people[e.mother].name, "女儿" if baby.female else "儿子", baby.name])


## 结婚: 你家的人、国王、史料里的婚事写进消息
func _on_marriage(e: Dictionary) -> void:
	var h: Person = world.people[e.husband]
	var wf: Person = world.people[e.wife]
	var text := "%s娶了%s%s" % [h.name, wf.name, "当次妻 (爱尔兰古法)" if e.get("secondary", false) else ""]
	if e.alliance.size() == 2:
		text += "; %s和%s结成同盟" % [world.realm_name(e.alliance[0]), world.realm_name(e.alliance[1])]
	if _mine(h) or _mine(wf):
		hud.notify("你家的婚事: " + text)
	elif h.realm != "" or wf.realm != "" or e.history != "":
		hud.notify(text)


## 退出: 铁人模式退出前先存
func _quit() -> void:
	if world.rules.ironman == "on" and hud.player_id != "":
		save_game("铁人模式", _ironman_file())
	if allow_quit:
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and world != null and world.rules.ironman == "on" and hud.player_id != "":
		save_game("铁人模式", _ironman_file())


func _ironman_file() -> String:
	return "ironman_%d" % world.name_seed


## 存档: 世界、日期、速度, 还有玩家在看地图的哪里、哪种地图模式
func save_game(label: String, file := "") -> String:
	var extra := {"mode": map.mode, "cam_x": map.camera.position.x, "cam_y": map.camera.position.y, "zoom": map.zoom()}
	var path := SaveGame.write(label, world, clock, extra, file)
	if file != SaveGame.AUTO and not file.begins_with("ironman"):
		hud.toast("存好了: " + label)
	return path


## 读档: 换掉现在的世界 (读完是暂停的)
func load_game(path: String) -> void:
	var d := SaveGame.read(path)
	if d.is_empty() or not d.has("world"):
		hud.toast("这个存档读不了")
		return
	var w := World.from_save(d.world)
	var c := Clock.new(int(d.day))
	c.speed = int(d.get("speed", 1))
	c.paused = true
	_build(w, c)
	if w.player != "" and w.people.has(w.player):
		hud.set_player(w.player)
	var ex: Dictionary = d.get("extra", {})
	map.set_mode(int(ex.get("mode", 0)))
	map.focus(Vector2(float(ex.get("cam_x", 0)), float(ex.get("cam_y", 0))), float(ex.get("zoom", 0.5)))
	hud.toast("读了存档: %s (%s)" % [d.get("label", ""), GameDate.text(c.day)])


## 选一个人来玩: 给国家 id 就是那个国家的国王, 不然是人的 id (国王或者封臣)
func play_as(who: String) -> void:
	var id: String = world.realms[who].ruler_id if world.realms.has(who) else who
	if world.rules.generate_families == "ai":
		world.remove_generated_family(id)  # 开局设置「生成家人: 只给电脑」
	hud.set_player(id)
	hud.toast("你现在是%s %s。按空格让时间走起来" % [world.title_of(world.people[id]), world.people[id].name])


func close_panel() -> void:
	hud.close_window()
	hud.close_county()
	hud.close_person()
	map.set_selected(0)


func _on_county_clicked(index: int) -> void:
	if index == 0:
		close_panel()
		return
	map.set_selected(index)
	hud.show_county(index)


func _on_mode(mode: int) -> void:
	map.set_mode(mode)
	hud.redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if not hud.popup.is_empty():
		# 中间的窗口开着: 回车、空格、Esc 都是「继续」
		if k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			hud.close_popup()
			get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_SPACE:
			hud._toggle_pause()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			clock.faster()
		KEY_MINUS, KEY_KP_SUBTRACT:
			clock.slower()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			clock.set_speed(k.keycode - KEY_0)
		KEY_ESCAPE:
			if hud.show_help:
				hud._toggle_help()
			elif not hud.window.is_empty():
				hud.close_window()
			else:
				close_panel()
		KEY_F1:
			hud._toggle_help()
		KEY_HOME:
			map.show_all()
		_:
			return
	hud.redraw()
	get_viewport().set_input_as_handled()
