extends SceneTree
## 查界面上的字有没有超出框: 打开各种窗口 (每块领地、每个国王、各种窗口、所有事件), 列出超出的字。
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/text_fit.gd
## (要开真窗口才会画; 超出的字会自动缩小一点, 这里列的是缩小了还放不下、或者没给宽度超出面板的)

var main: Node


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	SaveGame.dir = OS.get_temp_dir().path_join("bloodline_fit_saves")  # 不碰真的存档
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _frame() -> void:
	main.hud.redraw()
	await process_frame
	await process_frame


func _run() -> void:
	Look.check = true
	var w: World = main.world
	var hud: Hud = main.hud
	await _frame()
	hud.open_rules()
	await _frame()
	hud.close_popup()
	for c in w.counties:
		main._on_county_clicked(c.index)
		await _frame()
	main.close_panel()
	hud._toggle_help()
	await _frame()
	hud._toggle_help()
	var rids: Array = w.realm_order.duplicate()
	for rid in rids:
		if not w.realms.has(rid):
			continue
		main.play_as(rid)
		var k: Person = hud.me()
		k.gold = 300.0
		k.stress = 150.0
		hud.show_person(k.id)
		await _frame()
		for kind in ["realm", "army", "schemes", "decisions"]:
			hud._open_window(kind)
			await _frame()
		hud.close_window()
		for q in w.vassals_of(k).slice(0, 2) + w.children_of(k).slice(0, 2):
			hud.show_person(q.id)
			await _frame()
			hud._open_actions()
			await _frame()
			if q.alive and not q.married():
				hud._open_match()
				await _frame()
			hud.close_window()
		for other in rids.slice(0, 26):
			if other != rid and w.realms.has(other) and randf() < 0.15:
				hud.show_person(w.ruler(other).id)
				await _frame()
				hud._open_actions()
				await _frame()
				hud.close_window()
		# 事件: 能出的都弹一遍
		for d in StoryEvents.defs():
			var ctx := {"w": w, "me": k, "day": main.clock.day, "events": []}
			if d.has("window"):
				ctx.day = int(d.window[0])
			if not d.when.call(ctx):
				continue
			main.handle_events([{"type": "story", "story": w.story.build(d, ctx), "day": main.clock.day}])
			await _frame()
			hud.close_popup()
		for lv in [1, 2, 3]:
			hud.show_popup({"kind": "story", "story": w.story.mental_break(k, lv, main.clock.day)})
			await _frame()
			hud.popup.done = true
			hud.close_popup()
		while not hud.popup.is_empty():
			hud.close_popup()
		hud.close_person()
	# 再让时间走 30 年 (玩威塞克斯): 弹出来的窗口 (仗、阴谋、继位……) 都画一遍, 每半年打开一些窗口
	main.new_game({}, 5)
	w = main.world
	hud = main.hud
	main.play_as("wessex")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for m in 30 * 12:
		var day: int = main.clock.day + 30
		main.clock.day = day
		main.handle_events(w.advance(30, day))
		while not hud.popup.is_empty():
			await _frame()
			hud.close_popup()
		if hud.me() == null:
			var heir := w.ruler("wessex") if w.realms.has("wessex") else null
			if heir == null:
				break
			main.play_as(heir.id)
		if m % 6 == 0:
			var me: Person = hud.me()
			for kind in ["realm", "army", "schemes", "decisions"]:
				hud._open_window(kind)
				await _frame()
			for war in w.warfare.wars_of(me.id):
				hud._open_war(int(war.id))
				await _frame()
			for sc in w.intrigue.schemes_of(me.id):
				hud._open_scheme(int(sc.id))
				await _frame()
			hud.close_window()
			var alive: Array = w.living.values()
			for i in 8:
				var q: Person = alive[rng.randi_range(0, alive.size() - 1)]
				hud.show_person(q.id)
				await _frame()
				hud._open_actions()
				await _frame()
				hud.close_window()
			hud.close_person()
	var list: Array = Look.overflows.keys()
	list.sort_custom(func(a: String, b: String) -> bool: return Look.overflows[a] > Look.overflows[b])
	for s in list:
		print("超出 %d 像素: %s" % [int(Look.overflows[s]), s])
	print("一共 %d 处超出" % list.size())
	for file in DirAccess.get_files_at(SaveGame.dir):
		DirAccess.remove_absolute(SaveGame.dir.path_join(file))
	quit()
