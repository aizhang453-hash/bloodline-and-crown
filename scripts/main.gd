extends Node2D
## 游戏入口: 地图 + 界面 + 时间。
## 开局先选一个国王 (在地图上点领地, 再点「玩这个人」), 然后按空格让时间走起来。

var world: World
var clock: Clock
var map: MapView
var hud: Hud


func _ready() -> void:
	world = World.load_867(randi())
	clock = Clock.new(world.start_day)
	map = MapView.new(world, ProvinceMap.new())
	add_child(map)
	hud = Hud.new(world, clock, map)
	add_child(hud)
	map.county_clicked.connect(_on_county_clicked)
	map.county_hovered.connect(hud.set_map_hover)
	hud.play_requested.connect(play_as)
	hud.mode_requested.connect(_on_mode)
	hud.close_requested.connect(close_panel)


func _process(delta: float) -> void:
	var days := clock.advance(delta)
	if days > 0:
		handle_events(world.advance(days, clock.day))
		hud.redraw()


## 时间走的时候出的事: 你的国王死了跳窗口 (游戏暂停), 别的写进右边的消息
func handle_events(events: Array) -> void:
	var map_changed := false
	for e in events:
		match e.type:
			"succession", "extinct":
				map_changed = map_changed or not e.splits.is_empty() or e.merged_into != "" or e.type == "extinct"
				if hud.player != "" and e.realm == hud.player:
					if e.merged_into != "":
						hud.player = e.merged_into
					clock.paused = true
					if e.type == "extinct":
						hud.show_popup({"kind": "game_over", "event": e})
					else:
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
				if not e.was_ruler and hud.player != "" and world.realms.has(hud.player) and p.house == world.ruler(hud.player).house:
					hud.notify("你的家人%s去世了, 享年 %d 岁" % [p.name, p.age(e.day)])
	if map_changed:
		map.refresh_colors()


func play_as(realm_id: String) -> void:
	hud.set_player(realm_id)
	hud.toast("你现在是%s。按空格让时间走起来" % world.ruler_text(realm_id))


func close_panel() -> void:
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
