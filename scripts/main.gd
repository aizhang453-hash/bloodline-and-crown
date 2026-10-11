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
	map.army_clicked.connect(_on_army_clicked)
	map.county_right_clicked.connect(_on_county_right_clicked)
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
		if not world.warfare.armies.is_empty() or not world.warfare.sieges.is_empty():
			map.overlay.queue_redraw()  # 军队在走
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
					var king_word := "女王" if dead.female else "国王"
					var text := ("%s%s%s让位, %s继位" if e.get("abdicated", false) else "%s%s%s去世了, %s继位") % [e.realm_name, king_word, dead.name, heir.name]
					if e.type == "extinct":
						text = "%s%s%s去世, 家族绝后, 贵族推举%s当了国王" % [e.realm_name, king_word, dead.name, heir.name]
					for sp in e.splits:
						text += "; %s分到了%s" % [world.people[sp[1]].name, world.realm_name(sp[0])]
					hud.notify(text)
			"death":
				var p: Person = world.people[e.person]
				if not e.was_ruler and e.person != hud.player_id and _mine(p):
					hud.notify("你的家人%s%s, 享年 %d 岁" % [p.name, e.get("cause", "") if e.get("cause", "") != "" else "去世了", p.age(e.day)])
			"war", "war_end", "battle", "siege", "ally_call", "peace_offer", "realm_gone", "independent", "crowned", "army_lost", "reinforce":
				map_changed = _on_war_event(e) or map_changed
			"scheme_ready", "scheme_revealed", "scheme_failed", "murder", "sway", "exposed", "blackmail", "blackmail_ask":
				_on_scheme_event(e)
			"story", "mental_break", "title", "danelaw_ask":
				map_changed = _on_story_event(e) or map_changed
			"council_left":
				hud.notify("%s不再是你的%s了 (%s), 位子空着" % [world.people[e.person].name, e.seat, e.why])
			"council_done":
				hud.notify(e.text)
				map_changed = map_changed or e.get("map", false)
	if map_changed:
		map.refresh_colors()
	if not events.is_empty():
		hud.refresh_person()


## 打仗的事 (第 6 块): 跟你有关的弹窗或者写消息, 别国国王之间的大事写消息。返回地图要不要重新上色
func _on_war_event(e: Dictionary) -> bool:
	var wf := world.warfare
	var me := hud.player_id
	match e.type:
		"war":
			var att: Person = world.people[e.attacker]
			var def: Person = world.people[e.defender]
			var text := "%s向%s宣战 (%s: %s)" % [hud._side_name(att.id), hud._side_name(def.id), War.cb_name(e.cb), e.label]
			if e.defender == me:
				clock.paused = true
				hud.show_popup({"kind": "info", "icon": "swords", "bad": true, "title": "%s向你宣战了" % att.name,
						"lines": ["%s %s向你宣战。" % [world.title_of(att), att.name], "理由: %s (%s)" % [War.cb_name(e.cb), e.label],
						"打开右边一列的「军队」征兵; 右上角的小图标是这场仗。"]})
			elif e.attacker != me and (att.realm != "" or def.realm != ""):
				hud.notify(text)
		"war_end":
			var war: Dictionary = e.war
			var names := {"attacker": "进攻方赢了", "defender": "防守方赢了", "white": "平局", "bought": "花钱求和", "invalid": "打不下去了"}
			var text := "%s 的仗打完了: %s" % [hud._war_title(war), names.get(e.result, e.result)]
			if e.result == "bought":
				text += " (%d 金币)" % int(e.price)
			if me != "" and (war.attackers.has(me) or war.defenders.has(me)):
				var mine_side := 1 if war.attackers.has(me) else -1
				var won: bool = (e.result == "attacker" and mine_side == 1) or (e.result == "defender" and mine_side == -1) or (e.result == "bought" and mine_side == 1)
				var lost: bool = (e.result == "attacker" and mine_side == -1) or (e.result == "defender" and mine_side == 1) or (e.result == "bought" and mine_side == -1)
				var lines := [text]
				if not e.gained.is_empty():
					lines.append("拿到: " + "、".join(e.gained.map(func(id: String) -> String: return world.by_id[id].name)))
				lines.append("停战 5 年。")
				clock.paused = true
				hud.show_popup({"kind": "info", "icon": "crown" if won else "banner", "bad": lost,
						"title": "打赢了" if won else ("打输了" if lost else "仗打完了"), "lines": lines})
			else:
				hud.notify(text)
			return true
		"battle":
			var involved: bool = e.winners.has(me) or e.losers.has(me)
			if involved or _in_war_with_me(e.winner) or _in_war_with_me(e.loser):
				var text := "在%s打了一仗: %s赢了 (死了 %d 人), %s输了 (死了 %d 人)%s" % [world.by_id[e.loc].name, hud._side_name(e.winner), e.lost_w, hud._side_name(e.loser), e.lost_l, ", 全军覆没" if e.wiped else ""]
				for id in e.captured:
					text += "; %s被抓了" % world.people[id].name
				hud.notify(text)
		"siege":
			var c: Dictionary = world.by_id[e.county]
			if e.by == me or e.from == me or _in_war_with_me(e.by):
				var text := ("%s收复了%s" if e.liberated else "%s围下了%s") % [hud._side_name(e.by), c.name]
				for id in e.captured:
					text += "; 抓到了%s" % world.people[id].name
				hud.notify(text)
			return true
		"ally_call":
			var war := wf.war_by_id(int(e.war))
			if war.is_empty() or me == "":
				return false
			var leader: Person = world.people[e.leader]
			var s: int = e.side
			clock.paused = true
			hud.show_popup({"kind": "ask", "icon": "rings", "title": "%s请你帮忙打仗" % leader.name,
					"lines": ["%s (%s)" % [hud._war_title(war), War.cb_name(war.cb)], "你们是盟友, 他%s。" % ("要去打人" if s == 1 else "挨打了"),
						"不去的话他对你好感 %d (%d 年)。" % [War.DECLINE_ATTACK if s == 1 else War.DECLINE_DEFEND, 5 if s == 1 else 10]],
					"yes": "去帮忙", "no": "不去",
					"on_yes": func() -> void:
						wf.join(war, world.people[me], s)
						hud.toast("你加入了这场仗"),
					"on_no": func() -> void: wf.decline(war, world.people[me], s, clock.day)})
		"peace_offer":
			var war := wf.war_by_id(int(e.war))
			if war.is_empty():
				return false
			var def: Person = world.people[war.defender]
			clock.paused = true
			hud.show_popup({"kind": "ask", "icon": "coins", "title": "%s出钱求和" % def.name,
					"lines": ["%s愿意给你 %d 金币, 换你收兵回去。" % [def.name, int(e.price)], "收了钱这场仗就算打完, 停战 5 年。"],
					"yes": "收钱", "no": "不收, 接着打",
					"on_yes": func() -> void:
						var ev := []
						if wf.wars.has(war):
							wf.end_war(war, "bought", clock.day, ev, int(e.price))
						handle_events(ev),
					"on_no": func() -> void: pass})
		"realm_gone", "independent", "crowned":
			var text := ""
			match e.type:
				"realm_gone":
					text = "%s灭亡了" % e.name
					if e.ruler == me:
						clock.paused = true
						hud.show_popup({"kind": "info", "icon": "banner", "bad": true, "over": true, "title": "你的国家灭亡了",
								"lines": ["%s的最后一块地也丢了。" % e.name, "游戏结束。" + ("你可以换一个人接着玩。" if world.rules.ironman != "on" else "")]})
				"independent":
					text = "%s独立了, 成了%s" % [world.people[e.person].name, world.realm_name(e.realm) if world.realms.has(e.realm) else "国王"]
				"crowned":
					text = "%s当上了%s的国王, %s下台了" % [world.people[e.person].name, world.realm_name(e.realm) if world.realms.has(e.realm) else "", world.people[e.old].name]
					if e.old == me:
						clock.paused = true
						hud.show_popup({"kind": "info", "icon": "banner", "bad": true, "over": true, "title": "你的王位被抢走了",
								"lines": [text + "。", "游戏结束。" + ("你可以换一个人接着玩。" if world.rules.ironman != "on" else "")]})
			if text != "":
				hud.notify(text)
			return true
		"reinforce":
			var where: String = world.by_id[e.where].name if world.by_id.has(e.where) else ""
			hud.notify("一支很大的夏季大军渡海来到%s, %s多了 %d 人" % [where if where != "" else "英格兰", world.realm_name(e.realm), e.men])
		"army_lost":
			if e.owner == me:
				hud.notify("你的军队在%s走散了 (在敌人地上掉了太多兵)" % world.by_id[e.loc].name)
	return false


## 阴谋的事 (第 7 块): 有人暗害你被发现了、你被勒索弹窗; 你家的人被暗杀、阴谋成没成写消息
func _on_scheme_event(e: Dictionary) -> void:
	var me := hud.player_id
	var ig := world.intrigue
	var owner: Person = world.people.get(e.get("owner", ""))
	var target: Person = world.people.get(e.get("target", ""))
	match e.type:
		"scheme_ready":
			hud.notify("暗杀%s: 机会攒够了, 可以动手 (上方的提醒)" % target.name)
		"scheme_revealed":
			if e.target == me:
				clock.paused = true
				hud.show_popup({"kind": "info", "icon": "p_dagger", "bad": true, "title": "有人要暗杀你",
						"lines": ["你发现%s %s在密谋暗杀你。" % [world.title_of(owner), owner.name],
							"他在你的国家里的话, 可以照他的罪把他关起来 (不算暴政)。", "阴谋窗口 (右边一列「阴谋」) 里能看到。"]})
			elif e.owner == me:
				hud.notify("糟了: %s知道你在密谋害他" % target.name)
			elif _mine(target):
				hud.notify("%s发现%s在密谋害他" % [target.name, owner.name])
		"scheme_failed":
			if e.owner == me:
				hud.notify("暗杀%s的事走漏太多, 失败了; 大家都知道是你" % target.name)
			elif e.target == me or _mine(target):
				hud.notify("%s想暗杀%s, 事情败露了" % [owner.name, target.name])
		"murder":
			if e.owner == me:
				var t1 := ("%s死了" % target.name) if e.ok else ("没得手, %s逃过一劫" % target.name)
				hud.notify("暗杀: " + t1 + ("; 可是被人发现是你干的!" if e.found else "; 没人知道是你"))
			elif e.target == me or _mine(target):
				var who := ("是%s干的" % owner.name) if e.found else "不知道是谁干的"
				hud.notify(("%s被人暗杀了, %s" % [target.name, who]) if e.ok else ("有人想暗杀%s, 没得手 (%s)" % [target.name, who]))
			elif e.ok and target.realm != "":
				hud.notify("%s %s被人暗杀了" % [world.title_of(target), target.name])
		"sway":
			if e.owner == me:
				hud.notify(("拉拢成了: %s对你好感 +%d" % [target.name, Schemes.SWAY_GAIN]) if e.ok else ("拉拢%s没成, 他好感 %d, 以后不能再拉拢他" % [target.name, Schemes.SWAY_FAIL]))
		"exposed":
			var viewer: Person = world.people[e.viewer]
			if e.owner == me or e.viewer == me or _mine(owner):
				hud.notify("%s揭发了%s: %s" % [viewer.name, owner.name, Schemes.secret_name(e.secret)])
		"blackmail":
			if e.owner == me or e.viewer == me:
				hud.notify("%s拿秘密要挟%s, 拿到了把柄" % [world.people[e.viewer].name, owner.name])
		"blackmail_ask":
			var viewer: Person = world.people[e.viewer]
			var sec := ig.find_secret(owner, e.secret, e.target, int(e.secret_day))
			if sec.is_empty() or sec.exposed:
				return
			clock.paused = true
			hud.show_popup({"kind": "ask", "icon": "decree", "bad": true, "title": "%s在要挟你" % viewer.name,
					"lines": ["%s知道你%s。" % [viewer.name, "杀了" + target.name if e.secret == "murder" else "想杀" + target.name],
						"他要你给他一个把柄 (他能逼你答应婚事、交出领地; 你不能对他宣战、不能关他),", "不给他就把事情抖出来 (你丢威望, 算有罪)。"],
					"yes": "给他把柄", "no": "不给",
					"on_yes": func() -> void:
						ig.give_hook(viewer, owner, sec)
						hud.toast("%s攥住了你的把柄" % viewer.name),
					"on_no": func() -> void:
						var ev := []
						hud.toast(ig.expose(viewer, owner, sec, clock.day, ev).text)
						handle_events(ev)})


## 这个人在跟你打仗吗 (或者是你)
func _in_war_with_me(pid: String) -> bool:
	return pid != "" and hud.player_id != "" and (pid == hud.player_id or world.warfare.hostile(pid, hud.player_id))


## 你家族里的人
func _mine(p: Person) -> bool:
	return hud.player_id != "" and world.is_player_family(p)


## 随机事件、压力崩溃、头衔、特别决议 (第 8 块)。返回地图要不要重新上色
func _on_story_event(e: Dictionary) -> bool:
	var me := hud.player_id
	match e.type:
		"story":
			clock.paused = true
			hud.show_popup({"kind": "story", "story": e.story})
		"mental_break":
			var p: Person = world.people[e.person]
			if _mine(p) or (hud.me() != null and world.liege_of(p) == hud.me()):
				hud.notify("%s压力太大, 崩溃了: %s" % [p.name, e.text])
		"title":
			var p: Person = world.people[e.person]
			var name := world.title_name(e.kind, e.id)
			var mine_realm := hud.player
			if e.usurped != "" and e.usurped == mine_realm and e.person != me:
				clock.paused = true
				hud.show_popup({"kind": "info", "icon": "crown", "bad": true, "title": "%s被篡夺了" % name,
						"lines": ["%s %s控制了%s大半的地," % [world.title_of(p), p.name, name], "把这个头衔从你手里夺走了。",
							"你可以把地打回来, 再篡夺回来 (左下角「决议」)。"]})
			elif e.person != me:
				hud.notify("%s%s了%s" % [p.name, "篡夺" if e.usurped != "" else "建立", name])
			return true
		"danelaw_ask":
			var p: Person = world.people[e.person]
			var partner: Person = world.people[e.partner]
			clock.paused = true
			hud.show_popup({"kind": "ask", "icon": "crown", "title": "%s要跟你划界" % p.name,
					"lines": ["%s派人来谈: 他在英格兰占着的那些公国划给他的「丹麦法区」," % p.name,
						"你当英格兰国王, 两边停战 25 年, 互相好感 +50。", "不答应的话, 他对你好感 -20 (十年), 仗接着打。"],
					"yes": "答应划界", "no": "不答应",
					"on_yes": func() -> void:
						var ev := []
						if p.alive and partner.alive and p.realm != "" and partner.realm != "" and world.title_holder("kingdom", "danelaw") == "":
							hud.toast(world.danelaw_apply(p, partner, clock.day, ev).text)
						handle_events(ev),
					"on_no": func() -> void: p.remember(partner.id, "不肯跟我划界", -20, clock.day + 10 * GameDate.YEAR_DAYS)})
	return false


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


## 点了地图上的军队: 自己的就选中 (再右键点地让它走), 别人的看他是谁
func _on_army_clicked(id: int) -> void:
	var a: Dictionary = world.warfare.armies.get(id, {})
	if a.is_empty():
		return
	if a.owner == hud.player_id:
		map.selected_army = id
		map.overlay.queue_redraw()
		hud.toast("选中了你的军队 (%d 人): 右键点一块地, 军队就走过去" % int(world.warfare.soldiers(a)))
	else:
		hud.show_person(a.owner)


## 右键点了一块地: 选中了自己的军队就让它走过去
func _on_county_right_clicked(index: int) -> void:
	var a: Dictionary = world.warfare.armies.get(map.selected_army, {})
	if a.is_empty() or a.owner != hud.player_id:
		map.selected_army = -1
		return
	if index == 0:
		hud.toast("那里是海 (要坐船就右键点对岸靠海的地)")
		return
	var r := world.warfare.order_move(a, world.county_at(index).id)
	hud.toast(r.text)
	map.overlay.queue_redraw()


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
		if hud.popup.kind == "story":
			# 随机事件: 一定要选一个办法, 数字键 1～4 选 (回车、Esc 不管用, 免得点错)
			var n: int = k.keycode - KEY_1
			if n >= 0 and n < hud.popup.story.options.size():
				hud._pick_story(n)
				get_viewport().set_input_as_handled()
			return
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
			elif map.selected_army >= 0:
				map.selected_army = -1
				map.overlay.queue_redraw()
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
