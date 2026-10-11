class_name Hud
extends CanvasLayer
## 界面: 照三代的截图摆 (画面 1920×1080, 位置常量都是从三代 1920×1080 的截图上量的)。
## 只学摆法, 图标是自己用代码画的欧洲中世纪小图 (icons.gd), 不用原版的图和名字。还没做的按钮点了提示「以后才有」。

signal play_requested(realm_id: String)
signal mode_requested(mode: int)
signal close_requested
signal events_happened(events: Array)  # 界面上做的事 (说亲……) 引出的事, 交给 main 处理
signal save_requested(label: String, file: String)   # 菜单里点了存档 (file 空 = 新存一个)
signal load_requested(path: String)
signal quit_requested
signal rules_changed(rules: Dictionary)   # 开局前改了开局设置 (main 用新设置重新开一局)
signal new_game_requested                 # 铁人模式家族没了: 重新开一局

# ---- 位置 (从三代截图量的) ----
const TOP_BAR := Rect2(1222, 0, 698, 46)             # 右上角: 钱、威望、虔诚、名望、兵力、领地上限
const TOP_SLOTS := [1236, 1350, 1463, 1576, 1689, 1808]
const RIGHT_MENU := Rect2(1877, 125, 43, 487)        # 右边一列按钮
const RIGHT_MENU_Y := [153, 197, 241, 303, 347, 392, 453, 497, 542, 587]
const PORTRAIT := Rect2(52, 800, 240, 280)           # 左下角头像 (先空着, 只摆框)
const LEFT_SQUARES_Y := [850, 902, 953]              # 头像左边三个小方块
const TITLE_SHIELD := Rect2(5, 1013, 54, 62)         # 左下角: 主要头衔的盾牌 (上面有王冠)
const BOTTOM_ROW := [[Vector2(90, 1049), 22.0], [Vector2(145, 1049), 22.0], [Vector2(270, 1049), 25.0], [Vector2(330, 1049), 25.0]]
const STRESS_BAR := Rect2(162, 1039, 62, 20)
const DATE_BAR := Rect2(1322, 1040, 598, 40)         # 右下角: 日期和速度
const SPEED_BOXES_X := 1752.0
const MAP_MODES := Rect2(1745, 880, 175, 155)        # 右下角: 地图模式
const MODE_BIG := Vector2(1773, 969)
const MODE_SMALL := [Vector2(1817, 965), Vector2(1854, 965), Vector2(1887, 965),
		Vector2(1806, 1000), Vector2(1837, 1000), Vector2(1867, 1000), Vector2(1897, 1000)]
const SIDE_PANEL := Rect2(0, 0, 560, 1080)           # 点了领地以后左边的窗口 (跟三代的人物、领地窗口一样宽)
const NAME_PLATE := Rect2(52, 766, 240, 32)          # 头像框上面写名字的小牌子
const PANEL_FACE := Rect2(36, 168, 120, 140)         # 领地窗口里主人的头像 (原大)
# 人物窗口 (点头像打开, 跟领地窗口一样在左边)
const CHAR_FACE := Rect2(24, 24, 240, 280)
const CHAR_HEALTH := Rect2(24, 326, 512, 34)
const CHAR_STRESS := Rect2(24, 366, 512, 34)
const CHAR_TRAITS_Y := 500.0
const CHAR_SKILLS_Y := 680.0
const CHAR_NAME := Rect2(276, 30, 240, 156)          # 名字这一块 (鼠标指着看名字、头衔、家族)
const CHAR_OPINION := Rect2(24, 766, 512, 40)
const CHAR_HEIR := Rect2(24, 808, 512, 36)
const FAMILY_Y := 884.0                              # 家人小头像那一排
const FAMILY_FACE := Vector2(56, 65)
const FAMILY_MAX := 8
const CHAR_BUTTON := Rect2(40, 994, 480, 52)
const BADGE := 60.0
const POPUP := Rect2(560, 240, 800, 470)              # 国王去世的窗口 (画面正中)
const POPUP_BUTTON := Rect2(780, 630, 360, 54)
const NOTES := Rect2(1420, 58, 450, 34)               # 右边的消息, 一条一条往下排
const CHAR_ALLIES := Rect2(276, 278, 260, 30)         # 国王的同盟 (人物窗口名字下面)
# 说亲、教育的窗口 (第 4 块, 开在人物窗口右边)
const WINDOW := Rect2(580, 60, 820, 960)              # 右边到 1400 为止, 不挡右上角的消息
const WIN_ROW_Y := 244.0
const WIN_ROW_H := 78.0
const WIN_ROWS := 9
const MATCH_TABS := ["最肯答应的", "身份最高的", "本事最好的"]
const NAME_BUTTON := Vector2(230, 46)                 # 起名窗口里一个名字的按钮
const MENU_BOX := Rect2(610, 120, 700, 820)           # 菜单 (存档、读档)
const MENU_ROWS := 8                                  # 存档名单一页几个
const RULES_BUTTON := Rect2(860, 172, 200, 42)        # 开局时横幅下面的「开局设置」
const BIRTH := Rect2(560, 180, 800, 600)              # 孩子出生、起名的窗口 (比国王去世的高, 下面有写名字的框)
const NAME_EDIT := Rect2(600, 676, 500, 50)           # 自己写名字的框
const NAME_OK := Rect2(1120, 676, 200, 50)            # 「就叫这个」
const NAME_MAX := 12                                  # 名字最多几个字
const BANNER := Rect2(560, 64, 800, 96)
const ALERT_Y := 34.0            # 提醒那一排 (照三代的「重要事项」, 放在屏幕上方正中)
const ALERT_R := 25.0
const ALERT_GAP := 62.0

# 右边一列: [图标, 颜色, 名字, 第几块做]
const MENU := [
	["crown", "8fcf7a", "领地", 5], ["swords", "e07060", "军队", 6], ["throne", "6fc4b0", "宫廷", 10],
	["council", "86a9e0", "议会", 9], ["intrigue", "d58fd0", "阴谋", 7], ["torch", "e0803a", "派系", 11],
	["quill", "e6dcc4", "生活方式", 12], ["chalice", "d9b44a", "宗教", 13], ["book", "9fb6c9", "文化", 14], ["tree", "6fa04a", "王朝", 16],
]
# 右上角: [图标, 颜色, 名字, 说明]
const RESOURCES := [
	["coins", "e8c860", "金钱", "收税得来的钱。现在能送礼、付赎金; 以后打仗、盖房子都要钱。"],
	["crown", "e0b850", "威望", "别人有多看得起你。第 3 块「家族和继承」做好了才有。"],
	["cross", "ece6d6", "虔诚", "你对信仰有多虔诚。第 13 块「宗教」做好了才有。"],
	["tree", "6fa04a", "名望", "整个王朝的名声。第 16 块「王朝传承」做好了才有。"],
	["helmet", "b8c0c8", "兵力", "能召集多少兵 (直辖领地的兵 + 封臣交的兵)。第 6 块「打仗」才用得上。"],
	["tower", "a8a090", "亲自管的领地", "自己亲手管几块领地 / 最多能管几块 (基础 1 + 头衔 2 + 教育: 差 -1、好 +1、出色 +2)。超过的不出钱、不出兵。"],
]

var world: World
var clock: Clock
var map: MapView
var player := ""       # 玩家所在的国家 (国王是自己的国家, 封臣是他效忠的国家), 没选之前是空的
var player_id := ""    # 玩家这个人 (第 5 块起可以玩封臣, 不一定是国王)
var county := 0        # 左边窗口在看的领地, 0 = 没开
var person_id := ""    # 左边人物窗口在看的人, 空 = 没开
var hover_index := 0   # 鼠标指着的地图上的领地
var show_help := false

var _root := Root.new()
var _spots: Array = []
var _hover_spot: Control
var _county_spots: Array = []
var _toast := ""
var _toast_time := 0.0
var _faces := {}                     # 画好的头像: "人的 id 几岁" -> 图
var _back := Control.new()           # 最底下一层: 头像框的底色和左下角的头像 (按钮要画在头像上面)
var _player_face := TextureRect.new()
var _county_face := TextureRect.new()
var _person_face := TextureRect.new()
var _person_spots: Array = []
var _family: Array = []          # 人物窗口里家人那一排是谁 (人的 id)
var _family_faces: Array = []    # 家人的小头像 (TextureRect)
var popup := {}                  # 正中间的窗口 ({kind: "succession" / "game_over", event}), 空 = 没有
var _popup_spots: Array = []
var _popup_faces: Array = []
var _notes: Array = []           # 右边的消息: [[文字, 还剩几秒], ...]
var _stress_spot: Spot
var _res_spots: Array = []       # 右上角六样资源的方块 (说明跟着数字变)
var alerts: Array = []           # 现在的提醒: [{kind, icon, color, count, tip, click}]
var _alert_spots: Array = []
var _alert_key := ""
var _rules_spot: Spot
var window := {}                 # 右边的窗口: {kind: "match" 说亲 / "teacher" 教育, person, tab, page, rows}; 空 = 没开
var _window_spots: Array = []
var _window_faces: Array = []
var _popup_queue: Array = []     # 等着跳出来的窗口 (一次只开一个)
var name_edit: LineEdit          # 起名窗口里自己写名字的框 (开着起名窗口时才有)


func _init(p_world: World, p_clock: Clock, p_map: MapView) -> void:
	world = p_world
	clock = p_clock
	map = p_map


func _ready() -> void:
	_root.hud = self
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(func() -> void: _back.draw_colored_polygon(_root.arch(), Color(0.06, 0.065, 0.075, 0.9)))
	add_child(_back)
	add_child(_root)
	_make_spots()
	for face in [_player_face, _county_face, _person_face]:
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 像素画放大不要糊
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.visible = false
	_back.add_child(_player_face)
	_root.add_child(_county_face)  # 领地窗口、人物窗口里的头像在窗口上面
	_root.add_child(_person_face)
	_person_face.position = CHAR_FACE.position
	_person_face.size = CHAR_FACE.size
	_player_face.position = PORTRAIT.position
	_player_face.size = PORTRAIT.size
	_county_face.position = PANEL_FACE.position
	_county_face.size = PANEL_FACE.size


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_root.queue_redraw()
	if not _notes.is_empty():
		for n in _notes:
			n[1] -= delta
		_notes = _notes.filter(func(n: Array) -> bool: return n[1] > 0.0)
		_root.queue_redraw()


## 右边加一条消息 (别国的国王死了这类事), 12 秒后消失
func notify(text: String) -> void:
	_notes.push_front([text, 12.0])
	if _notes.size() > 6:
		_notes.resize(6)
	_root.queue_redraw()


## 正中间跳一个窗口 (你的国王死了、你的孩子出生)。窗口开着时点不到别的地方; 已经开着一个就排队
func show_popup(data: Dictionary) -> void:
	if not popup.is_empty():
		_popup_queue.append(data)
		return
	popup = data
	_spot(Rect2(0, 0, 1920, 1080), "", Callable(), _popup_spots)
	if data.kind == "menu":
		_make_menu(data)
		redraw()
		return
	if data.kind == "rules":
		_make_rules()
		redraw()
		return
	var e: Dictionary = data.event
	if data.kind == "birth":
		_make_birth_popup(data)
		redraw()
		return
	_spot(POPUP_BUTTON, "", close_popup, _popup_spots)
	for i in 2:
		var who: Person = world.people[e.dead if i == 0 else e.get("heir", e.get("to", e.dead))]
		var tex := TextureRect.new()
		tex.texture = face(who)
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.position = POPUP.position + (Vector2(40, 120) if i == 0 else Vector2(POPUP.size.x - 160, 120))
		tex.size = Vector2(Portrait.W, Portrait.H)
		if i == 0:
			tex.modulate = Color(0.6, 0.6, 0.6)
		_root.add_child(tex)
		_popup_faces.append(tex)
	redraw()


func close_popup() -> void:
	if popup.is_empty():
		return
	var game_over: bool = popup.kind in ["game_over", "vassal_over"]
	if popup.kind == "menu":
		clock.paused = popup.was_paused
	if game_over and world.rules.ironman == "on":
		popup = {}
		new_game_requested.emit()  # 铁人模式: 家族没了只能重新开一局
		return
	popup = {}
	name_edit = null
	for s in _popup_spots + _popup_faces:
		if _hover_spot == s:
			_hover_spot = null
		s.queue_free()
	_popup_spots.clear()
	_popup_faces.clear()
	if game_over:
		# 家族绝嗣 (或者没地了): 游戏结束, 可以换一个人接着玩
		player = ""
		player_id = ""
		world.player = ""
		_popup_queue.clear()
		close_person()
		toast("在地图上点一块领地, 换一个人接着玩")
	if not _popup_queue.is_empty():
		show_popup(_popup_queue.pop_front())
	redraw()


## 你的孩子出生了: 孩子的头像, 几个名字按钮 (点一个就用这个名字; 回车用第一个)
func _make_birth_popup(data: Dictionary) -> void:
	var baby: Person = world.people[data.child]
	var tex := TextureRect.new()
	tex.texture = face(baby)
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.position = BIRTH.position + Vector2(40, 110)
	tex.size = Vector2(Portrait.W, Portrait.H)
	_root.add_child(tex)
	_popup_faces.append(tex)
	for i in data.names.size():
		_spot(_name_rect(i), "就叫%s" % data.names[i], _pick_name.bind(data.names[i]), _popup_spots)
	# 自己写名字: 打字 (中文用输入法) 再按回车, 或者点「就叫这个」; 什么都不写按回车就用第一个
	var edit := LineEdit.new()
	edit.position = NAME_EDIT.position
	edit.size = NAME_EDIT.size
	edit.max_length = NAME_MAX
	edit.placeholder_text = "或者自己写一个名字, 写好按回车"
	edit.add_theme_font_override("font", Look.font("sans"))
	edit.add_theme_font_size_override("font_size", 22)
	edit.add_theme_color_override("font_color", Look.TEXT)
	edit.add_theme_color_override("font_placeholder_color", Look.TEXT_DIM)
	edit.add_theme_color_override("caret_color", Look.GOLD)
	for state in ["normal", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.1, 0.105, 0.12)
		box.border_color = Look.GOLD if state == "focus" else Look.GOLD_DIM
		box.set_border_width_all(2)
		box.set_content_margin_all(10)
		edit.add_theme_stylebox_override(state, box)
	edit.text_submitted.connect(_pick_typed)
	_root.add_child(edit)
	_popup_faces.append(edit)
	name_edit = edit
	_spot(NAME_OK, "用框里写的名字", func() -> void: _pick_typed(edit.text), _popup_spots)
	edit.grab_focus.call_deferred()


func _name_rect(i: int) -> Rect2:
	return Rect2(BIRTH.position + Vector2(40 + (i % 3) * (NAME_BUTTON.x + 15), 330 + (i / 3) * (NAME_BUTTON.y + 12)), NAME_BUTTON)


## 用玩家自己写的名字 (前后的空格去掉; 什么都没写就用第一个)
func _pick_typed(text: String) -> void:
	var n := text.strip_edges()
	if popup.is_empty() or popup.kind != "birth":
		return
	_pick_name(n if n != "" else popup.names[0])


## 孩子起名可以挑的: 现在的名字 (史料里的或者随机的) 在第一个, 再是长辈的名字 (中世纪常用) 和几个当时当地的名字
func birth_names(baby: Person) -> Array:
	var list := [baby.name]
	var elders := [baby.father, world.people[baby.father].father if world.people.has(baby.father) else ""] if not baby.female \
			else [baby.mother, world.people[baby.mother].mother if world.people.has(baby.mother) else ""]
	for id in elders:
		if id != "" and world.people.has(id) and not list.has(world.people[id].name):
			list.append(world.people[id].name)
	var tries := 0
	while list.size() < 6 and tries < 30:
		tries += 1
		var n := world.random_name(world.rng, baby.culture, baby.female)
		if not list.has(n):
			list.append(n)
	return list


func _pick_name(n: String) -> void:
	var baby: Person = world.people[popup.child]
	baby.name = n
	close_popup()


func redraw() -> void:
	_sync_faces()
	_update_alerts()
	_root.queue_redraw()


# ---- 提醒 (照三代的「重要事项」: 屏幕上方一排小图标, 点一下就去处理) ----

## 现在该提醒玩家的事
func alerts_now() -> Array:
	var m := me()
	var out := []
	if m == null or not m.alive:
		return out
	var day := clock.day
	var family: Array = world.house_members(m.house).duplicate() if m.house != "" else []
	if not family.has(m):
		family.append(m)
	var mine := family.filter(func(p: Person) -> bool: return p.alive and world.is_player_court(p))
	# 孩子没有老师 (三代原版有这个提醒)
	var kids := mine.filter(func(p: Person) -> bool: return p.age(day) >= 6 and not p.adult(day) and p.guardian == "")
	if not kids.is_empty():
		out.append({"kind": "teacher", "icon": "book", "color": Look.GOLD, "count": kids.size(),
				"tip": "孩子没有老师: %s\n6 岁起要请老师, 不然只能自己学, 教育会差。\n(点一下: 给%s请老师)" % [_names(kids), kids[0].name],
				"click": func() -> void:
					show_person(kids[0].id)
					_open_teacher()})
	# 家里有成年人没结婚
	var single := mine.filter(func(p: Person) -> bool:
		return p.adult(day) and not p.married() and p.betrothed == "" and p.prisoner_of == "" and p.age(day) <= (40 if p.female else 60))
	if not single.is_empty():
		out.append({"kind": "marry", "icon": "rings", "color": Look.GOLD, "count": single.size(),
				"tip": "家里有成年人没结婚: %s\n只有你能给他们说亲。\n(点一下: 给%s说亲)" % [_names(single), single[0].name],
				"click": func() -> void:
					show_person(single[0].id)
					_open_match()})
	# 直辖领地超过上限
	var inc := world.income(m)
	if inc.domain > inc.limit:
		out.append({"kind": "domain", "icon": "tower", "color": Look.RED, "count": inc.domain - inc.limit,
				"tip": "直辖领地 %d 块, 超过上限 %d 块: 多出来的 %d 块不出钱、不出兵。\n(点一下: 打开你的国家, 把领地封出去)" % [inc.domain, inc.limit, inc.domain - inc.limit],
				"click": _open_realm_window})
	# 有人关在你的大牢里
	var held := world.living.values().filter(func(p: Person) -> bool: return p.alive and p.prisoner_of == m.id)
	if not held.is_empty():
		out.append({"kind": "prison", "icon": "helmet", "color": Look.TEXT, "count": held.size(),
				"tip": "关在你大牢里的人: %s\n可以放了、要赎金、处死……\n(点一下: 看%s)" % [_names(held), held[0].name],
				"click": func() -> void:
					show_person(held[0].id)
					_open_actions()})
	return out


func _names(list: Array) -> String:
	var shown := list.slice(0, 6).map(func(p: Person) -> String: return p.name)
	return "、".join(shown) + (" 等 %d 人" % list.size() if list.size() > 6 else "")


func _alert_rect(i: int, n: int) -> Rect2:
	var c := Vector2(960.0 + (i - (n - 1) / 2.0) * ALERT_GAP, ALERT_Y)
	return Rect2(c - Vector2(ALERT_R, ALERT_R), Vector2(ALERT_R, ALERT_R) * 2)


func _update_alerts() -> void:
	alerts = alerts_now()
	var key := ",".join(alerts.map(func(a: Dictionary) -> String: return "%s%d" % [a.kind, a.count]))
	if key != _alert_key:
		_alert_key = key
		for s in _alert_spots:
			if _hover_spot == s:
				_hover_spot = null
			s.queue_free()
		_alert_spots.clear()
		for i in alerts.size():
			_spot(_alert_rect(i, alerts.size()), "", _alert_click.bind(alerts[i].kind), _alert_spots)
	for i in mini(alerts.size(), _alert_spots.size()):
		_alert_spots[i].tooltip_text = alerts[i].tip


func _alert_click(kind: String) -> void:
	for a in alerts:
		if a.kind == kind:
			a.click.call()
			return


## 某个人现在的头像 (同一个人同一个岁数只画一次)
func face(p: Person) -> Texture2D:
	var key := "%s %d" % [p.id, p.age(clock.day)]
	if not _faces.has(key):
		_faces[key] = ImageTexture.create_from_image(Portrait.make(p.looks(clock.day)))
	return _faces[key]


## 头像跟着玩家、开着的窗口换 (左边窗口开着时盖住左下角的头像, 跟三代一样)
func _sync_faces() -> void:
	sync_player()
	if _rules_spot:
		_rules_spot.visible = player_id == ""
	_player_face.visible = player_id != "" and county == 0 and person_id == ""
	if _player_face.visible:
		_player_face.texture = face(me())
	_county_face.visible = county != 0
	if _county_face.visible:
		_county_face.texture = face(world.people[world.county_at(county).lord])
	_update_resource_tips()
	if player_id != "" and _stress_spot:
		var me := me()
		_stress_spot.tooltip_text = "你的压力: %d (第 %d 档)\n100 点一档, 最多三档。做违背性格的事会涨, 每年自己降一些。\n(点一下看你的人物窗口)" % [int(me.stress), me.stress_level()]
	_person_face.visible = person_id != ""
	if _person_face.visible:
		_person_face.texture = face(world.people[person_id])


## 右上角资源的说明: 每一项是怎么来的
func _update_resource_tips() -> void:
	if _res_spots.size() < RESOURCES.size():
		return
	var m := me()
	for i in RESOURCES.size():
		var r: Array = RESOURCES[i]
		var tip := "%s\n%s" % [r[2], r[3]]
		if m != null:
			var inc := world.income(m)
			match i:
				0:
					tip += "\n——\n现在 %d 金币, 每月 %+.1f:\n  直辖领地 %d 块 (上限 %d) +%.1f\n  封臣交上来 +%.1f" % [int(m.gold), inc.gold, inc.active, inc.limit, inc.own_gold, inc.from_gold]
					if inc.paid_gold > 0.0:
						tip += "\n  交给上面 (合同「%s」) -%.1f" % [Feudal.CONTRACTS[m.contract], inc.paid_gold]
				1:
					tip += "\n——\n每月 +%s (%s)" % ["1.0" if m.realm != "" else "0.5", "国王" if m.realm != "" else "有领地的封臣"]
				4:
					tip += "\n——\n直辖领地 %d 人, 封臣交上来 %d 人%s" % [inc.own_levy, inc.from_levy, ("\n交给上面 %d 人" % inc.paid_levy) if inc.paid_levy > 0 else ""]
				5:
					tip += "\n——\n现在 %d 块, 最多 %d 块%s" % [inc.domain, inc.limit, "\n超过了! 多出来的 %d 块不出钱不出兵, 封出去吧 (右边一列的「领地」按钮)" % (inc.domain - inc.limit) if inc.domain > inc.limit else ""]
		_res_spots[i].tooltip_text = tip


func toast(text: String) -> void:
	_toast = text
	_toast_time = 3.0
	_root.queue_redraw()


func later(name: String, block: int) -> void:
	toast("「%s」以后才有 (看板上的第 %d 块)" % [name, block])


func show_county(index: int) -> void:
	_drop_person()
	close_window()
	county = index
	map.set_focus_person(world.county_at(index).lord)
	show_help = false
	for s in _county_spots:
		s.visible = true
	redraw()


func close_county() -> void:
	county = 0
	if person_id == "":
		map.set_focus_person("")
	for s in _county_spots:
		s.visible = false
	redraw()


## 打开人物窗口 (领地窗口会关上, 跟三代一样左边只有一个窗口)
func show_person(id: String) -> void:
	county = 0
	for s in _county_spots:
		s.visible = false
	_drop_person()
	close_window()  # 说亲、教育的窗口是跟着人的, 换人就关上
	person_id = id
	map.set_focus_person(id if world.is_landed(world.people[id]) else "")
	show_help = false
	_make_person_spots()
	redraw()


func close_person() -> void:
	_drop_person()
	close_window()
	if county == 0:
		map.set_focus_person("")
	redraw()


## 人物窗口开着时, 时间走了 (有人出生、结婚、去世) 就重做一遍能点的地方。
## 说亲、教育的窗口开着就先不动 (不然名单一直在变), 关上以后再点开就是新的
func refresh_person() -> void:
	if person_id != "" and world.people.has(person_id) and window.is_empty():
		show_person(person_id)


func _drop_person() -> void:
	person_id = ""
	for f in _family_faces:
		f.queue_free()
	_family_faces.clear()
	_family.clear()
	for s in _person_spots:
		s.queue_free()
		if _hover_spot == s:
			_hover_spot = null
	_person_spots.clear()


func set_map_hover(index: int) -> void:
	hover_index = index
	_root.queue_redraw()


## 选一个人来玩 (国王或者封臣)
func set_player(id: String) -> void:
	player_id = id
	world.player = id
	sync_player()
	redraw()


## 玩家这个人, 还没选是 null
func me() -> Person:
	return world.people.get(player_id) if player_id != "" else null


## 玩家所在的国家跟着变 (封臣的国王换了、国家合并……)
func sync_player() -> void:
	player = world.realm_of_person(me()) if player_id != "" and world.people.has(player_id) else ""
	world.player = player_id


# ---- 能点的地方 (看不见的方块, 管鼠标指着的说明和点击) ----

func _spot(rect: Rect2, tip: String, click: Callable, group := _spots) -> Spot:
	var s := Spot.new()
	s.hud = self
	s.position = rect.position
	s.size = rect.size
	s.tooltip_text = tip
	s.on_click = click
	_root.add_child(s)
	group.append(s)
	return s


func _make_spots() -> void:
	# 右上角
	_spot(TOP_BAR, "", Callable())
	for i in RESOURCES.size():
		var r: Array = RESOURCES[i]
		var x: float = TOP_SLOTS[i]
		var w: float = (TOP_SLOTS[i + 1] if i + 1 < TOP_SLOTS.size() else TOP_BAR.end.x) - x
		_res_spots.append(_spot(Rect2(x, 0, w - 4, 44), "%s\n%s" % [r[2], r[3]], Callable()))
	# 右边一列
	_spot(RIGHT_MENU, "", Callable())
	for i in MENU.size():
		var m: Array = MENU[i]
		if i == 0:
			_spot(Rect2(1878, RIGHT_MENU_Y[i] - 20, 42, 40), "领地: 你的直辖领地、封臣, 把领地封出去", _open_realm_window)
		else:
			_spot(Rect2(1878, RIGHT_MENU_Y[i] - 20, 42, 40), m[2], later.bind(m[2], m[3]))
	# 左下角
	_spot(PORTRAIT, "你玩的这个人 (点一下看人物窗口)", _open_player)
	_rules_spot = _spot(RULES_BUTTON, "开局设置: 生成家人、铁人模式、孩子夭折多少…… (开始以后不能改)", open_rules)
	var squares := [["生活重点", 12], ["信仰", 13], ["文化", 14]]
	for i in 3:
		_spot(Rect2(0, LEFT_SQUARES_Y[i] - 20, 45, 40), "你的" + squares[i][0], later.bind(squares[i][0], squares[i][1]))
	_spot(Rect2(5, 983, 54, 92), "你的主要头衔 (点一下在地图上看你的地)", _focus_player)
	var bottom := [["家族", 3], ["压力", 2], ["召集军队", 6], ["决议", 8]]
	for i in 4:
		var c: Vector2 = BOTTOM_ROW[i][0]
		var r: float = BOTTOM_ROW[i][1]
		if i == 1:
			_stress_spot = _spot(Rect2(c - Vector2(r, r), Vector2(r * 2 + 62, r * 2)), "压力", _open_player)
		else:
			_spot(Rect2(c - Vector2(r, r), Vector2(r, r) * 2), bottom[i][0], later.bind(bottom[i][0], bottom[i][1]))
	# 右下角: 日期和速度
	_spot(DATE_BAR, "", Callable())
	_spot(Rect2(1330, 1042, 34, 36), "菜单: 存档、读档、退出", _menu)
	_spot(Rect2(1368, 1042, 34, 36), "操作说明 (F1)", _toggle_help)
	_spot(Rect2(1410, 1040, 330, 40), "空格: 暂停 / 继续", _toggle_pause)
	for i in 5:
		_spot(Rect2(SPEED_BOXES_X + i * 33, 1044, 31, 32),
				"速度 %d: 每秒 %s 天\n(按 + - 或者数字键 1～5 换速度)" % [i + 1, str(Clock.DAYS_PER_SECOND[i + 1])],
				_set_speed.bind(i + 1))
	# 右下角: 地图模式
	_spot(MAP_MODES, "", Callable())
	_spot(Rect2(MODE_BIG - Vector2(22, 22), Vector2(44, 44)), "地图模式: 国家", mode_requested.emit.bind(MapView.Mode.REALM))
	var small := [["公国 (按法理, 就是名义上本来该归谁)", MapView.Mode.DUCHY], ["王国 (按法理)", MapView.Mode.KINGDOM], ["帝国 (按法理)", MapView.Mode.EMPIRE]]
	for i in 3:
		_spot(Rect2(MODE_SMALL[i] - Vector2(14, 14), Vector2(28, 28)), "地图模式: " + small[i][0], mode_requested.emit.bind(small[i][1]))
	var later_modes := [["地形", 15], ["文化", 14], ["宗教", 13]]
	for i in 3:
		_spot(Rect2(MODE_SMALL[i + 3] - Vector2(13, 13), Vector2(26, 26)), "地图模式: " + later_modes[i][0], later.bind("地图模式: " + later_modes[i][0], later_modes[i][1]))
	_spot(Rect2(MODE_SMALL[6] - Vector2(13, 13), Vector2(26, 26)), "地图模式: 家族 (每块地按主人的家族上色, 一眼看出哪家管哪里)", mode_requested.emit.bind(MapView.Mode.HOUSE))
	# 左边的领地窗口 (开着的时候才有)
	_spot(SIDE_PANEL, "", Callable(), _county_spots)
	_spot(PANEL_FACE, "点一下看这个人", _open_holder, _county_spots)
	_spot(Rect2(SIDE_PANEL.end.x - 52, 14, 38, 38), "关上 (Esc)", close_requested.emit, _county_spots)
	_spot(Rect2(40, 960, 480, 56), "", _play_this, _county_spots)
	_spot(Rect2(40, 890, 480, 50), "", _focus_holder, _county_spots)
	for s in _county_spots:
		s.visible = false


func _focus_player() -> void:
	if player_id == "":
		toast("先选一个人来玩")
		return
	var mine := world.lands_of(me())
	if me().realm != "" or mine.is_empty():
		_focus_realm(player)
	else:
		_focus_counties(mine)


func _open_player() -> void:
	if player_id != "":
		show_person(player_id)


func _open_holder() -> void:
	if county:
		show_person(world.county_at(county).lord)


## 人物窗口里能指、能点的地方 (每个人的特点不一样, 打开时现做)
func _make_person_spots() -> void:
	var p: Person = world.people[person_id]
	var day := clock.day
	_spot(SIDE_PANEL, "", Callable(), _person_spots)
	_spot(Rect2(SIDE_PANEL.end.x - 52, 14, 38, 38), "关上 (Esc)", close_requested.emit, _person_spots)
	# 游戏里不写谁是史料里的、谁是随机生成的 (用户 2026-10-10 说的); 史料依据留在数据文件里
	var about := [p.name]
	if world.title_of(p) != "":
		about.append(world.title_of(p))
	about.append("%s · %s" % [p.culture_name(), world.house_name(p.house)])
	_spot(CHAR_NAME, "\n".join(about), Callable(), _person_spots)
	if not p.alive:
		_spot(CHAR_HEALTH, "%s已经去世了" % p.name, Callable(), _person_spots)
	else:
		_spot(CHAR_HEALTH, _parts_text("健康: %s (%.1f)\n一年里死的机会大约 %.1f%%" % [p.health_text(day), p.health(day), p.yearly_death_chance(day) * 100.0], p.health_parts(day), true), Callable(), _person_spots)
	if p.realm != "":
		var al := world.allies(p.realm).map(func(r: String) -> String: return world.realm_name(r))
		var tyr := ("\n——\n暴政 %d: 做了不正当的事 (没理由收回领地、关人、让封臣多交、处死), 封臣对他好感 %d, 每月降 %.2f" % [int(p.tyranny), -int(p.tyranny / 2.0), Feudal.TYRANNY_DECAY]) if p.tyranny >= 1.0 else ""
		_spot(CHAR_ALLIES, ("同盟: %s" % "、".join(al) if not al.is_empty() else "还没有同盟") +
				"\n两个国王的近亲 (本人、父母、子女、兄弟姐妹、祖孙) 结了婚, 两国就是同盟。\n第 6 块「打仗」做好以后, 盟友会来帮忙" + tyr, Callable(), _person_spots)
	elif p.alive and _status_line(p) != "":
		_spot(CHAR_ALLIES, _status_tip(p), (show_person.bind(world.liege_of(p).id) if world.liege_of(p) != null else Callable()), _person_spots)
	_spot(CHAR_STRESS, "压力 %d (第 %d 档)\n做违背自己性格的事会涨, 每年自己降 %d%s。\n100 点一档; 到了一档会崩溃出事 (崩溃的事件第 8 块才有)。" % [
			int(p.stress), p.stress_level(), int(Person.STRESS_DECAY * (2 if p.has_trait("calm") else 1)), " (冷静的人降两倍)" if p.has_trait("calm") else ""],
			Callable(), _person_spots)
	var badges := _person_badges(p)
	for i in badges.size():
		_spot(_badge_rect(i), _trait_tip(badges[i]), Callable(), _person_spots)
	for i in Traits.SKILLS.size():
		var sk: String = Traits.SKILLS[i]
		var info := Traits.skill_info(sk)
		_spot(_skill_rect(i), _parts_text("%s %d\n%s" % [info.name, p.skill(sk, day), info.desc], p.skill_parts(sk, day), false), Callable(), _person_spots)
	if player_id != "" and player_id != p.id:
		var o := p.opinion_of(me())
		_spot(CHAR_OPINION, _parts_text("他对你的好感: %+d" % o.total, o.parts, false), Callable(), _person_spots)
	if p.alive and not p.adult(day):
		_spot(CHAR_HEIR, _school_tip(p), _open_teacher if _can_teach(p) else (show_person.bind(p.guardian) if p.guardian != "" else Callable()), _person_spots)
	if p.alive and p.realm != "":
		var law := Succession.law_of(world.realms[p.realm].culture)
		var h := world.heir(p.realm, day)
		var tip := "%s: %s" % [Succession.NAMES[law], Succession.DESCS[law]]
		if h:
			tip = "继承人: %s\n%s\n(点一下看他)" % [h.name, tip]
			_spot(CHAR_HEIR, tip, show_person.bind(h.id), _person_spots)
		else:
			_spot(CHAR_HEIR, "家族里没有能继承的男人! 他死了家族就丢了这个国家\n" + tip, Callable(), _person_spots)
	_make_family(p)
	var buttons := _person_buttons(p)
	for i in buttons.size():
		_spot(_button_rect(i, buttons.size()), buttons[i][3], buttons[i][2], _person_spots)


## 人物窗口下面一排按钮: [字, 图标, 点了做什么, 说明]
func _person_buttons(p: Person) -> Array:
	var list := []
	if p.realm != "":
		list.append(["国家", "banner", _focus_person_realm, "在地图上看整个%s" % world.realm_name(p.realm)])
	elif not world.lands_of(p).is_empty():
		list.append(["领地", "tower", _focus_person_realm, "在地图上看%s管的地" % p.name])
	if _can_arrange(p):
		var more := p.married()
		list.append(["再娶一个" if more else "说亲", "rings", _open_match,
				("爱尔兰古法准许再娶 (正妻加最多两个次妻)" if more else "给%s找对象 (有一个不满 16 岁就先订婚, 都满 16 岁再成亲)" % p.name)])
	if _can_teach(p):
		list.append(["教育", "book", _open_teacher, "给%s选学什么、请老师" % p.name])
	if player_id == "" and p.alive and world.is_landed(p):
		list.append(["玩这个人", "crown", play_requested.emit.bind(p.id), "选%s来玩 (%s)" % [p.name, world.title_of(p)]])
	elif not _actions_for(p).is_empty():
		list.append(["互动", "decree", _open_actions, "对%s做事: 送礼、改合同、收回领地、关大牢……" % p.name])
	return list


## 人物窗口名字下面那一行 (不是国王的人): 关在大牢里、给谁当封臣、合同
func _status_line(p: Person) -> String:
	if p.prisoner_of != "" and world.people.has(p.prisoner_of):
		return "关在%s的%s" % [world.people[p.prisoner_of].name, "地牢里" if p.dungeon else "大牢里 (软禁)"]
	var l := world.liege_of(p)
	if l != null:
		return "效忠%s · 合同%s" % [l.name, Feudal.CONTRACTS[p.contract]]
	return ""


func _status_tip(p: Person) -> String:
	var lines := [_status_line(p)]
	if p.prisoner_of != "":
		lines.append("每个月有 %.1f%% 的机会逃跑%s" % [Feudal.escape_chance(p, clock.day) * 100.0, "; 地牢伤身体 (健康 %.1f)" % Person.DUNGEON_HEALTH if p.dungeon else ""])
	var l := world.liege_of(p)
	if l != null:
		var inc := world.income(p)
		lines.append(Feudal.kind_desc(world.vassal_kind(p)))
		lines.append("合同「%s」: 交税 %d%%、交兵 %d%% (每月交 %.1f 金币、%d 个兵)" % [Feudal.CONTRACTS[p.contract], int(Feudal.TAX_SHARE[p.contract] * 100), int(Feudal.LEVY_SHARE[p.contract] * 100), inc.paid_gold, inc.paid_levy])
		lines.append("(点一下看%s)" % l.name)
	var crimes := Feudal.crime_text(p, clock.day)
	if crimes != "":
		lines.append("犯过的罪: %s (有罪的人关起来、收回领地都不算暴政)" % crimes)
	return "\n".join(lines)


func _button_rect(i: int, n: int) -> Rect2:
	var w := (CHAR_BUTTON.size.x - (n - 1) * 12) / n
	return Rect2(CHAR_BUTTON.position.x + i * (w + 12), CHAR_BUTTON.position.y, w, CHAR_BUTTON.size.y)


## 能不能给这个人说亲: 归你管的人 (你自己, 你家族里没领地的人; 照三代), 活着、还能结婚、没订婚
func _can_arrange(p: Person) -> bool:
	return player != "" and p.alive and world.is_player_court(p) and Marriage.free_to_marry(world, p) and p.betrothed == ""


func _can_teach(p: Person) -> bool:
	return player != "" and p.alive and world.is_player_court(p) and p.age(clock.day) >= 6 and not p.adult(clock.day)


## 孩子上学的说明
func _school_tip(p: Person) -> String:
	var a := p.age(clock.day)
	var lines := []
	if a < 6:
		lines.append("%d 岁, 6 岁开始跟老师学" % a)
	else:
		lines.append("学%s, 学了 %d 年 (6 岁学到 15 岁), 攒了 %.1f 分" % [Traits.track_name(p.focus), p.edu_years, p.edu_points])
		if p.guardian != "":
			var g: Person = world.people[p.guardian]
			lines.append("老师: %s (%s %d), 带着 %d 个学生" % [g.name, Traits.skill_info(p.focus).name, g.skill(p.focus, clock.day), world.wards_of(g)])
		else:
			lines.append("没有老师, 自己学 (一年只攒 0.2 分)")
		lines.append("每学一年攒「老师这一样本事 ÷ 10」分, 学的合小时候的性格再多 0.2")
		lines.append("16 岁时: 4 分以下差, 8 分以下一般, 12 分以下好, 再高出色 (聪不聪明、运气也算)")
		lines.append("老师每年有 10% 的机会把自己的一个性格传给他")
	if p.childhood() != "":
		var info := Traits.get_trait(p.childhood())
		lines.append("小时候的性格「%s」: 学%s合适" % [info.name, "、".join(info.focus.map(func(s: String) -> String: return Traits.skill_info(s).name))])
	if _can_teach(p):
		lines.append("(点一下换老师、换学的东西)")
	return "\n".join(lines)


## 家人那一排: 父母、配偶、孩子、兄弟姐妹 (最多 8 个), 每个一张小头像, 点了看那个人
func _make_family(p: Person) -> void:
	var list := []
	for id in [p.father, p.mother, p.spouse] + p.secondary + [p.betrothed]:
		if id != "" and world.people.has(id):
			list.append(world.people[id])
	list.append_array(world.children_of(p))
	list.append_array(world.siblings_of(p))
	for i in mini(list.size(), FAMILY_MAX):
		var f: Person = list[i]
		_family.append(f.id)
		var r := _family_rect(i)
		var tex := TextureRect.new()
		tex.texture = face(f)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # 不然图不肯比原来小
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.position = r.position
		tex.size = r.size
		if not f.alive:
			tex.modulate = Color(0.55, 0.55, 0.55)
		_root.add_child(tex)
		_family_faces.append(tex)
		var state := ("%d 岁" % f.age(clock.day)) if f.alive else ("已故, 享年 %d 岁" % f.age(clock.day))
		_spot(r, "%s: %s (%s)\n(点一下看这个人)" % [world.relation(p, f), f.name, state], show_person.bind(f.id), _person_spots)
	if list.size() > FAMILY_MAX:
		var rest := list.slice(FAMILY_MAX).map(func(f: Person) -> String: return "%s: %s" % [world.relation(p, f), f.name])
		_spot(Rect2(_family_rect(FAMILY_MAX - 1).end.x + 4, FAMILY_Y, 40, FAMILY_FACE.y), "还有:\n" + "\n".join(rest), Callable(), _person_spots)


func _family_rect(i: int) -> Rect2:
	return Rect2(Vector2(30 + i * 62, FAMILY_Y), FAMILY_FACE)


func _focus_person_realm() -> void:
	var p: Person = world.people[person_id]
	if p.realm != "":
		_focus_realm(p.realm)
	elif not world.lands_of(p).is_empty():
		_focus_counties(world.lands_of(p))


## 一个人身上的特点牌子: 先性格, 再天生的, 最后教育
func _person_badges(p: Person) -> Array:
	var list: Array = p.personality() + p.congenital()
	if p.childhood() != "":
		list.push_front(p.childhood())
	if not p.education.is_empty():
		list.append(p.education)
	return list


func _badge_rect(i: int) -> Rect2:
	var c := Vector2(58 + (i % 7) * 74, CHAR_TRAITS_Y + (i / 7) * 74)
	return Rect2(c - Vector2(BADGE, BADGE) / 2, Vector2(BADGE, BADGE))


func _skill_rect(i: int) -> Rect2:
	var c := Vector2(66 + i * 85, CHAR_SKILLS_Y)
	return Rect2(c - Vector2(28, 28), Vector2(56, 84))


func _trait_tip(what: Variant) -> String:
	if what is Dictionary:
		var name := Traits.education_name(what)
		var desc := ""
		for t in Traits.data().education.tracks:
			if t.skill == what.skill:
				desc = t.desc
		return "%s\n%s\n%s +%d" % [name, desc, Traits.skill_info(what.skill).name, Traits.education_bonus(int(what.level))]
	var info := Traits.get_trait(what)
	var lines := [info.name, info.desc]
	var effects := []
	for sk in info.get("skills", {}):
		var v := int(info.skills[sk])
		effects.append("%s %+d" % ["六项本事" if sk == "all" else Traits.skill_info(sk).name, v])
	if info.has("health"):
		effects.append("健康 %+.2f" % float(info.health))
	if info.has("opinion"):
		effects.append("别人对他的好感 %+d" % int(info.opinion))
	if not effects.is_empty():
		lines.append("  ".join(effects))
	if info.get("kind", "") == "personality":
		var opp := []
		for o in info.get("opposite", []):
			opp.append("「%s」" % Traits.get_trait(o).name)
		lines.append("跟同样%s的人合得来%s" % ["「" + info.name + "」", ("; 跟" + "、".join(opp) + "的人合不来") if not opp.is_empty() else ""])
	elif info.get("kind", "") == "congenital":
		var inherit := int(info.get("inherit", 0))
		lines.append("天生的: 爸妈一个有, 孩子有 %d%% 的机会也有 (两个都有翻倍)" % inherit if inherit > 0 else "天生的 (不遗传)")
	elif info.get("kind", "") == "childhood":
		lines.append("小时候的性格 (3 岁到 16 岁): 学%s合适" % "、".join(info.focus.map(func(s: String) -> String: return Traits.skill_info(s).name)))
		lines.append("长大以后多半有「%s」里的一个" % "」「".join(info.grows_into.map(func(t: String) -> String: return Traits.get_trait(t).name)))
	return "\n".join(lines)


## 「标题 + 每一项加了多少」的说明
func _parts_text(title: String, parts: Array, decimal: bool) -> String:
	var lines := [title, "——"]
	for x in parts:
		lines.append(("%s  %+.1f" if decimal else "%s  %+d") % [x[0], x[1]])
	if parts.is_empty():
		lines.append("(没有加减)")
	return "\n".join(lines)


# ---- 说亲、教育的窗口 (第 4 块) ----

func _open_match() -> void:
	_open_window("match")


func _open_teacher() -> void:
	_open_window("teacher")


## 右边的窗口: match 说亲、teacher 教育、actions 互动 (跟着人物窗口里的人); realm 你的国家、grant 封地 (跟着玩家)
func _open_window(kind: String, tab := 0, extra := {}) -> void:
	close_window()
	var pid := person_id if kind in ["match", "teacher", "actions"] else player_id
	if pid == "" or not world.people.has(pid):
		return
	var p: Person = world.people[pid]
	window = {"kind": kind, "person": pid, "tab": tab, "page": 0, "armed": -1}
	window.merge(extra)
	if kind == "teacher" and p.focus == "":
		p.focus = Traits.pick_focus(world.rng, p.childhood())
	match kind:
		"match":
			window.rows = _match_rows(p, tab)
		"teacher":
			window.rows = _teacher_rows(p)
		"actions":
			window.rows = _actions_for(p)
		"realm":
			window.rows = _realm_rows(p)
		"grant":
			window.rows = _grant_rows(p, extra)
	_make_window_spots()
	redraw()


func close_window() -> void:
	window = {}
	_clear_window_spots()
	_root.queue_redraw()


func _clear_window_spots() -> void:
	for s in _window_spots + _window_faces:
		if _hover_spot == s:
			_hover_spot = null
		s.queue_free()
	_window_spots.clear()
	_window_faces.clear()


## 说亲名单: 能嫁娶的人 (不是近亲、没结婚……) 加三个本地贵族家的 (随机生成的, 选上了才放进世界)
func _match_rows(p: Person, tab: int) -> Array:
	var day := clock.day
	var rows := []
	for c in world.living.values():
		if not c.alive or c.female == p.female or absi(c.age(day) - p.age(day)) > 30:
			continue
		if Marriage.problem(world, p, c, day, true) != "":
			continue
		rows.append({"person": c, "acc": Marriage.acceptance(world, me(), p, c, day), "new": false})
	var a := p.age(day)
	for i in 3:
		var age := clampi(a + (-3 - i * 2 if not p.female else 2 + i * 3), 16, 40) if p.adult(day) else clampi(a + i - 1, 0, 15)
		var n := world.make_noble(p.culture, not p.female, age, day)
		n.homeland = p.homeland
		rows.append({"person": n, "acc": Marriage.acceptance(world, me(), p, n, day), "new": true})
	for r in rows:
		var c: Person = r.person
		r.history = world.historical_match(p, c) != ""
		r.status = Marriage.status(world, c)
		var sum := 0
		for sk in Traits.SKILLS:
			sum += c.skill(sk, day)
		r.skills = sum
	match tab:
		0:
			rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
				return x.history if x.history != y.history else x.acc.total > y.acc.total)
		1:
			rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
				return x.status > y.status if x.status != y.status else x.acc.total > y.acc.total)
		_:
			rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.skills > y.skills)
	return rows


## 能当老师的人, 学的那一样本事好的在前
func _teacher_rows(child: Person) -> Array:
	var rows := []
	for t in world.teacher_candidates(child, clock.day):
		rows.append({"person": t, "skill": t.skill(child.focus, clock.day), "wards": world.wards_of(t)})
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.skill > y.skill)
	return rows


func _win_row_rect(i: int) -> Rect2:
	return Rect2(WINDOW.position.x + 20, _row_top() + i * WIN_ROW_H, WINDOW.size.x - 40, WIN_ROW_H - 6)


## 名单从哪里开始: 说亲、教育上面有一排按钮, 别的窗口往上挪
func _row_top() -> float:
	return WIN_ROW_Y if window.get("kind", "") in ["match", "teacher"] else WINDOW.position.y + 136


func _win_tab_rect(i: int, n: int) -> Rect2:
	var w := (WINDOW.size.x - 40 - (n - 1) * 10) / n
	return Rect2(WINDOW.position.x + 20 + i * (w + 10), WINDOW.position.y + 100, w, 44)


func _win_pages() -> int:
	return maxi(1, ceili(window.rows.size() / float(WIN_ROWS)))


func _make_window_spots() -> void:
	_clear_window_spots()
	var p: Person = world.people[window.person]
	_spot(WINDOW, "", Callable(), _window_spots)
	_spot(Rect2(WINDOW.end.x - 52, WINDOW.position.y + 14, 38, 38), "关上", close_window, _window_spots)
	if window.kind == "match":
		for i in MATCH_TABS.size():
			_spot(_win_tab_rect(i, MATCH_TABS.size()), "按「%s」排" % MATCH_TABS[i], _set_window_tab.bind(i), _window_spots)
	elif window.kind == "teacher":
		var tracks: Array = Traits.data().education.tracks
		for i in tracks.size():
			var info := Traits.skill_info(tracks[i].skill)
			var fits := Traits.focus_fits(p.childhood(), tracks[i].skill)
			_spot(_win_tab_rect(i, tracks.size()), "学%s: %s%s" % [tracks[i].name, tracks[i].desc, "\n(合他小时候的性格, 学得好一些)" if fits else ""], _set_focus.bind(tracks[i].skill), _window_spots)
	var start: int = window.page * WIN_ROWS
	for i in range(start, mini(start + WIN_ROWS, window.rows.size())):
		var r: Dictionary = window.rows[i]
		var rect := _win_row_rect(i - start)
		_spot(rect, _row_tip(p, r), _choose_row.bind(i), _window_spots)
		if not r.has("person") or window.kind == "actions":
			continue
		var c: Person = r.person
		var tex := TextureRect.new()
		tex.texture = face(c)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.position = rect.position + Vector2(8, 4)
		tex.size = Vector2(56, 65)
		_root.add_child(tex)
		_window_faces.append(tex)
	if _win_pages() > 1:
		_spot(Rect2(WINDOW.position.x + 20, WINDOW.end.y - 62, 200, 46), "上一页", _turn_page.bind(-1), _window_spots)
		_spot(Rect2(WINDOW.end.x - 220, WINDOW.end.y - 62, 200, 46), "下一页", _turn_page.bind(1), _window_spots)


func _row_tip(p: Person, r: Dictionary) -> String:
	match window.kind:
		"match":
			return _match_tip(p, r)
		"teacher":
			return _teacher_tip(p, r)
		"actions":
			return "%s\n%s%s" % [r.name, r.get("tip", r.desc), ("\n(做不了: %s)" % r.why) if not r.ok else ("\n(要点两次: 第一次点了再点一次才算数)" if r.harsh else "")]
		"realm":
			return _realm_tip(r)
		"grant":
			return _grant_tip(r)
	return ""


# ---- 互动: 送礼、改合同、收回领地、关大牢、处置关着的人 (第 5 块) ----

func _open_actions() -> void:
	_open_window("actions")


## 你能对这个人做的事: [{name, icon, desc, ok, why, harsh, do: Callable(events) -> {ok, text}}]
func _actions_for(p: Person) -> Array:
	var m := me()
	var acts := []
	if m == null or p == m or not p.alive:
		return acts
	var day := clock.day
	if p.prisoner_of == m.id:
		acts.append({"name": "放了他", "icon": "plus", "desc": "放%s出来, 他对你好感 +20 (十年)" % p.name,
				"ok": true, "why": "", "harsh": false, "do": func(_ev: Array) -> Dictionary: return world.release(m, p, day)})
		var cost := Feudal.ransom(world, p)
		var payer := p if p.gold >= cost else world.head_of(p)
		acts.append({"name": "要赎金", "icon": "coins", "desc": "要 %d 金币才放人 (他自己出, 不够就%s出); 他好感 -10" % [cost, payer.name],
				"ok": payer != m and payer.gold >= cost, "why": "他家拿不出 %d 金币" % cost, "harsh": false,
				"do": func(_ev: Array) -> Dictionary: return world.ransom(m, p, day)})
		acts.append({"name": "改成软禁" if p.dungeon else "关进地牢", "icon": "tower",
				"desc": "改成软禁: 不伤身体" if p.dungeon else "地牢: 伤身体 (健康 %.1f)、更难逃跑, 他更恨你" % Person.DUNGEON_HEALTH,
				"ok": true, "why": "", "harsh": false, "do": func(_ev: Array) -> Dictionary: return world.toggle_dungeon(p)})
		var just := Feudal.has_crime(p, day)
		acts.append({"name": "处死", "icon": "swords", "desc": "处死%s; 他的家人好感 -50 (三十年); %s" % [p.name, "他有罪, 不算暴政" if just else "暴政 +%d" % int(Feudal.TYRANNY_EXECUTE)],
				"ok": true, "why": "", "harsh": true, "do": func(ev: Array) -> Dictionary: return world.execute(m, p, day, ev)})
	else:
		acts.append({"name": "送礼", "icon": "coins", "desc": "花 %d 金币, 他对你好感 +20 (五年)" % int(Feudal.GIFT),
				"ok": m.gold >= Feudal.GIFT, "why": "钱不够 (有 %d, 要 %d)" % [int(m.gold), int(Feudal.GIFT)], "harsh": false,
				"do": func(_ev: Array) -> Dictionary: return world.gift(m, p, day)})
	if world.liege_of(p) == m:
		if p.contract > 0:
			var lv: int = p.contract - 1
			acts.append({"name": "让他少交", "icon": "coins", "desc": "合同改成「%s」(交税 %d%%、交兵 %d%%): 你少收一些, 他好感 +15 (十年)" % [Feudal.CONTRACTS[lv], int(Feudal.TAX_SHARE[lv] * 100), int(Feudal.LEVY_SHARE[lv] * 100)],
					"ok": true, "why": "", "harsh": false, "do": func(_ev: Array) -> Dictionary: return world.set_contract(m, p, lv, day)})
		if p.contract < Feudal.CONTRACTS.size() - 1:
			var lv2: int = p.contract + 1
			acts.append({"name": "让他多交", "icon": "coins", "desc": "合同改成「%s」(交税 %d%%、交兵 %d%%): 你多收一些; 暴政 +%d, 他好感 -20 (十年)" % [Feudal.CONTRACTS[lv2], int(Feudal.TAX_SHARE[lv2] * 100), int(Feudal.LEVY_SHARE[lv2] * 100), int(Feudal.TYRANNY)],
					"ok": true, "why": "", "harsh": true, "do": func(_ev: Array) -> Dictionary: return world.set_contract(m, p, lv2, day)})
		var tyr := Feudal.revoke_tyranny(world, p, day)
		var o: int = p.opinion_of(m).total
		var will: bool = p.prisoner_of != "" or o >= 0
		var why_t := "撤换郡长不算暴政" if world.vassal_kind(p) == "郡长" and tyr == 0.0 else ("有正当理由, 不算暴政" if tyr == 0.0 else "暴政 +%d%s" % [int(tyr), " (爱尔兰小国王翻倍)" if world.vassal_kind(p) == "小国王" else ""])
		var will_t := "关着的人不能不肯" if p.prisoner_of != "" else ("他会交出来" if will else "他不肯交 (算抗命)")
		acts.append({"name": "收回领地", "icon": "tower", "desc": "收回 %d 块领地归你直辖 · %s · %s" % [world.lands_of(p).size(), why_t, will_t],
				"tip": "收回他的 %d 块领地归你直辖。\n%s。\n他好感 -%d (二十年), 他家里人 -15 (十年)。\n%s" % [
				world.lands_of(p).size(), why_t, 30 if world.vassal_kind(p) == "郡长" else 40,
				"关着的人不能不肯" if p.prisoner_of != "" else ("他对你好感 %+d: %s" % [o, "好感不小于 0, 会交出来" if will else "好感小于 0, 不肯交。不肯算抗命, 你就有理由把他关起来 (关了再收回不算暴政)"])],
				"ok": true, "why": "", "harsh": true, "do": func(ev: Array) -> Dictionary: return world.revoke(m, p, day, ev)})
	if p.prisoner_of == "" and world.arrest_problem(m, p) == "":
		var just2 := Feudal.has_crime(p, day)
		acts.append({"name": "关进大牢", "icon": "tower", "desc": "抓到的机会 %d%% (比你和他的密谋本事)。%s; 他的家人好感 -20" % [
				int(Feudal.arrest_chance(m, p, day) * 100), ("他有罪 (%s), 不算暴政" % Feudal.crime_text(p, day)) if just2 else "没有理由: 暴政 +%d" % int(Feudal.TYRANNY)],
				"ok": true, "why": "", "harsh": true, "do": func(ev: Array) -> Dictionary: return world.arrest(m, p, day, ev)})
	return acts


func _do_action(i: int) -> void:
	var act: Dictionary = window.rows[i]
	if not act.ok:
		toast("做不了: " + act.why)
		return
	if act.harsh and window.armed != i:
		window.armed = i
		toast("再点一次确定: " + act.name)
		_root.queue_redraw()
		return
	var events := []
	var r: Dictionary = act.do.call(events)
	toast(r.text)
	var pid: String = window.person
	if not events.is_empty():
		events_happened.emit(events)
	if person_id == pid:
		_make_person_spots_again()
		_open_window("actions")


# ---- 你的国家: 直辖领地、公国头衔、封臣 (第 5 块; 右边一列的「领地」按钮) ----

func _open_realm_window() -> void:
	if player_id == "":
		toast("先选一个人来玩")
		return
	_open_window("realm")


func _realm_rows(m: Person) -> Array:
	var rows := []
	var l := world.liege_of(m)
	if l != null:
		rows.append({"type": "liege", "person": l})
	var inc := world.income(m)
	var dom := world.lands_of(m)
	for i in dom.size():
		rows.append({"type": "county", "county": dom[i], "active": i < inc.limit,
				"capital": m.realm != "" and dom[i].id == world.realms[m.realm].capital})
	if m.realm != "":
		var titles: Array = world.realms[m.realm].titles
		for t in titles.slice(1):
			rows.append({"type": "duchy", "duchy": t})
	for v in world.vassals_of(m):
		rows.append({"type": "vassal", "person": v})
	return rows


func _realm_tip(r: Dictionary) -> String:
	match r.type:
		"liege":
			return "你效忠的%s (点一下看他)" % r.person.name
		"county":
			if r.capital:
				return "%s: 你的都城 (不能封出去)" % r.county.name
			return "%s: 你直辖的领地%s\n(点一下把它封给别人)" % [r.county.name, "" if r.active else "; 超过上限了, 不出钱不出兵"]
		"duchy":
			return "%s: 你手里多出来的公国头衔\n(点一下封给家里人当副王: 那里你直辖的领地都归他, 那里的封臣也归他管)" % world.duchies[r.duchy].name
		"vassal":
			var v: Person = r.person
			return "%s\n%s\n他对你的好感 %+d\n(点一下看他, 在他的人物窗口里「互动」)" % [world.title_of(v), _status_tip(v), v.opinion_of(me()).total]
	return ""


func _realm_click(r: Dictionary) -> void:
	match r.type:
		"liege", "vassal":
			show_person(r.person.id)
		"county":
			if r.capital:
				toast("都城不能封出去")
			else:
				_open_window("grant", 0, {"county": r.county.id})
		"duchy":
			_open_window("grant", 0, {"duchy": r.duchy})


# ---- 封地: 选一个人 (家里的人, 或者本地贵族) ----

func _grant_rows(m: Person, what: Dictionary) -> Array:
	var rows := []
	var day := clock.day
	for p in world.house_members(m.house):
		if p != m and world.grant_problem(m, p, day) == "" and world.realm_of_person(p) in ["", world.realm_of_person(m)]:
			rows.append({"person": p, "new": false})
	if what.has("county"):
		for i in 3:
			var n := world.make_noble(m.culture if m.realm == "" else world.realms[m.realm].culture, false, 22 + i * 9, day)
			n.homeland = m.homeland
			rows.append({"person": n, "new": true})
	return rows


func _grant_tip(r: Dictionary) -> String:
	var p: Person = r.person
	var lines := ["%s (%d 岁)" % [p.name, p.age(clock.day)]]
	lines.append("本地贵族家的儿子" if r.new else ((world.relation(me(), p) + " · ") if world.relation(me(), p) != "" else "") + world.house_name(p.house))
	if window.has("county"):
		lines.append("把%s封给他: 他好感 +40 (二十年), 他按合同给你交钱交兵" % world.by_id[window.county].name)
	else:
		lines.append("封他当%s副王: 他好感 +60 (二十年)" % world.duchies[window.duchy].name)
	return "\n".join(lines)


func _grant_click(r: Dictionary) -> void:
	var events := []
	var res: Dictionary
	if window.has("county"):
		res = world.grant_county(me(), world.by_id[window.county], r.person, clock.day, events)
	else:
		res = world.grant_viceroy(me(), window.duchy, r.person, clock.day, events)
	toast(res.text)
	if res.ok:
		events_happened.emit(events)
		_open_window("realm")


func _match_tip(p: Person, r: Dictionary) -> String:
	var c: Person = r.person
	var lines := ["%s (%d 岁, %s)" % [c.name, c.age(clock.day), c.culture_name()]]
	var kin := world.ruler_kin(c)
	lines.append(kin if kin != "" else (("本地贵族家的" + ("女儿" if c.female else "儿子")) if r.new else world.house_name(c.house)))
	if not (p.adult(clock.day) and c.adult(clock.day)):
		lines.append("有一个不满 16 岁: 先订婚, 都满 16 岁再成亲")
	lines.append(_parts_text("%s家%s: %+d (大于 0 就答应)" % [c.name, "答应" if r.acc.total > 0 else "不答应", r.acc.total], r.acc.parts, false))
	return "\n".join(lines)


func _teacher_tip(child: Person, r: Dictionary) -> String:
	var t: Person = r.person
	var rel := world.relation(child, t)
	return "%s (%d 岁)%s\n%s %d: 一年能让%s攒 %.1f 分\n带着 %d 个学生 (最多 %d 个)\n(点一下请他当老师)" % [
			t.name, t.age(clock.day), (" · " + rel) if rel != "" else "", Traits.skill_info(child.focus).name, r.skill,
			child.name, (r.skill + (2.0 if Traits.focus_fits(child.childhood(), child.focus) else 0.0)) / 10.0, r.wards, World.MAX_WARDS]


func _set_window_tab(i: int) -> void:
	_open_window("match", i)


func _set_focus(skill: String) -> void:
	var p: Person = world.people[window.person]
	p.focus = skill
	_open_window("teacher")
	toast("%s改学%s" % [p.name, Traits.track_name(skill)])
	_make_person_spots_again()


func _turn_page(step: int) -> void:
	window.page = clampi(window.page + step, 0, _win_pages() - 1)
	_make_window_spots()
	redraw()


func _choose_row(i: int) -> void:
	var p: Person = world.people[window.person]
	var row: Dictionary = window.rows[i]
	match window.kind:
		"actions":
			_do_action(i)
			return
		"realm":
			_realm_click(row)
			return
		"grant":
			_grant_click(row)
			return
	var c: Person = row.person
	if window.kind == "teacher":
		p.guardian = c.id
		toast("请%s当%s的老师" % [c.name, p.name])
		_open_window("teacher")
		_make_person_spots_again()
		return
	var events := []
	var r := world.propose(p, c, clock.day, events)
	toast(r.text)
	if r.ok:
		close_window()
		events_happened.emit(events)
		_make_person_spots_again()


## 人物窗口还开着: 重做能点的地方 (说亲、换老师以后)
func _make_person_spots_again() -> void:
	if person_id == "":
		return
	var keep := window.duplicate()
	var pages: int = window.get("page", 0)
	for f in _family_faces:
		f.queue_free()
	_family_faces.clear()
	_family.clear()
	for s in _person_spots:
		if _hover_spot == s:
			_hover_spot = null
		s.queue_free()
	_person_spots.clear()
	_make_person_spots()
	if not keep.is_empty():
		window = keep
		window.page = pages
		_make_window_spots()  # 窗口的方块要在人物窗口上面
	redraw()


func _focus_holder() -> void:
	if county:
		_focus_realm(world.county_at(county).holder)


func _focus_realm(realm_id: String) -> void:
	_focus_counties(world.counties_of(realm_id))


func _focus_counties(cs: Array) -> void:
	var box := Rect2(cs[0].rect)
	for c in cs:
		box = box.merge(Rect2(c.rect))
	var z := clampf(minf(1300.0 / box.size.x, 900.0 / box.size.y), MapView.ZOOM_MIN, 1.6)
	map.focus(box.get_center(), z)


func _play_this() -> void:
	if county and player_id == "":
		play_requested.emit(world.county_at(county).lord)


# ---- 菜单: 存档、读档、退出 (照三代: 随时能存、能读; 打开菜单时游戏暂停) ----

func _menu() -> void:
	if not popup.is_empty():
		return
	var was := clock.paused
	clock.paused = true
	show_popup({"kind": "menu", "view": "main", "was_paused": was, "armed": -1})


## 菜单里换一页 (main 主菜单 / save 存档 / load 读档)
func _menu_view(view: String) -> void:
	var keep := popup.duplicate()
	keep.view = view
	keep.armed = -1
	for s in _popup_spots + _popup_faces:
		if _hover_spot == s:
			_hover_spot = null
		s.queue_free()
	_popup_spots.clear()
	_popup_faces.clear()
	name_edit = null
	popup = keep
	_spot(Rect2(0, 0, 1920, 1080), "", Callable(), _popup_spots)
	_make_menu(popup)
	redraw()


func _menu_button(i: int) -> Rect2:
	return Rect2(MENU_BOX.position.x + 150, MENU_BOX.position.y + 130 + i * 76, 400, 58)


func _menu_row(i: int) -> Rect2:
	return Rect2(MENU_BOX.position.x + 30, MENU_BOX.position.y + (220 if popup.view == "save" else 110) + i * 62, MENU_BOX.size.x - 60, 56)


func _menu_back() -> Rect2:
	return Rect2(MENU_BOX.position.x + 30, MENU_BOX.end.y - 76, 200, 52)


func _make_menu(data: Dictionary) -> void:
	match data.view:
		"main":
			var iron: bool = world.rules.ironman == "on"
			var items := [["继续游戏", close_popup],
					["存档", (func() -> void: toast("铁人模式不能自己存档 (每半年和退出时自动存)")) if iron else _menu_view.bind("save")],
					["读档", (func() -> void: toast("铁人模式不能读档")) if iron else _menu_view.bind("load")],
					["退出游戏", _menu_quit],
					["开局设置", func() -> void:
						close_popup()
						open_rules()]]
			for i in items.size():
				_spot(_menu_button(i), "", items[i][1], _popup_spots)
		"save":
			popup.saves = SaveGame.list().filter(func(x: Dictionary) -> bool: return not x.auto).slice(0, MENU_ROWS)
			var me := me()
			var edit := LineEdit.new()
			edit.position = MENU_BOX.position + Vector2(30, 110)
			edit.size = Vector2(450, 52)
			edit.max_length = 40
			edit.text = ("%s · %s" % [me.name, GameDate.text(clock.day)]) if me != null else GameDate.text(clock.day)
			edit.add_theme_font_override("font", Look.font("sans"))
			edit.add_theme_font_size_override("font_size", 20)
			edit.add_theme_color_override("font_color", Look.TEXT)
			for state in ["normal", "focus"]:
				var box := StyleBoxFlat.new()
				box.bg_color = Color(0.1, 0.105, 0.12)
				box.border_color = Look.GOLD if state == "focus" else Look.GOLD_DIM
				box.set_border_width_all(2)
				box.set_content_margin_all(10)
				edit.add_theme_stylebox_override(state, box)
			edit.text_submitted.connect(func(t: String) -> void: _save_new(t))
			_root.add_child(edit)
			_popup_faces.append(edit)
			name_edit = edit
			_spot(Rect2(MENU_BOX.position + Vector2(495, 110), Vector2(175, 52)), "用这个名字存一个新的档", func() -> void: _save_new(edit.text), _popup_spots)
			for i in popup.saves.size():
				_spot(_menu_row(i), "点两次: 盖掉这个旧存档", _menu_pick.bind(i), _popup_spots)
			_spot(_menu_back(), "", _menu_view.bind("main"), _popup_spots)
		"load":
			popup.saves = SaveGame.list().slice(0, MENU_ROWS + 2)
			for i in popup.saves.size():
				_spot(_menu_row(i), "点两次: 读这个存档 (现在没存的进度会没了)", _menu_pick.bind(i), _popup_spots)
			_spot(_menu_back(), "", _menu_view.bind("main"), _popup_spots)


## 退出要点两次 (没存的进度会没了)
func _menu_quit() -> void:
	if popup.armed != 99:
		popup.armed = 99
		toast("再点一次「退出游戏」就退出 (没存的进度会没了)")
		redraw()
		return
	quit_requested.emit()


# ---- 开局设置 (照三代的游戏规则: 开局前选, 开始以后只能看) ----

func open_rules() -> void:
	if not popup.is_empty():
		return
	show_popup({"kind": "rules", "view": "rules", "armed": -1})


func _make_rules() -> void:
	for i in Rules.LIST.size():
		var r: Array = Rules.LIST[i]
		for j in r[3].size():
			_spot(_rule_option(i, j), r[2], _pick_rule.bind(r[0], r[3][j][0]), _popup_spots)
	_spot(_menu_back(), "", close_popup, _popup_spots)


func _rule_option(i: int, j: int) -> Rect2:
	return Rect2(MENU_BOX.position.x + 30 + j * 215, MENU_BOX.position.y + 168 + i * 150, 205, 44)


func _pick_rule(id: String, value: String) -> void:
	if player_id != "":
		toast("游戏开始以后不能改开局设置")
		return
	if world.rules[id] == value:
		return
	var r: Dictionary = world.rules.duplicate()
	r[id] = value
	close_popup()
	rules_changed.emit(r)


func _save_new(label: String) -> void:
	var t := label.strip_edges()
	if t == "":
		t = GameDate.text(clock.day)
	close_popup()
	save_requested.emit(t, "")


## 存档名单里点了一个: 点两次才算 (盖掉旧档、读档都不能反悔)
func _menu_pick(i: int) -> void:
	if popup.armed != i:
		popup.armed = i
		toast("再点一次确定")
		redraw()
		return
	var s: Dictionary = popup.saves[i]
	if popup.view == "save":
		close_popup()
		save_requested.emit(s.label, s.path.get_file().get_basename())
	else:
		close_popup()
		load_requested.emit(s.path)


func _toggle_help() -> void:
	show_help = not show_help
	_root.queue_redraw()


func _toggle_pause() -> void:
	if not popup.is_empty():
		return
	if player_id == "":
		toast("先在地图上点一块领地, 选一个国王或者封臣来玩")
		return
	clock.toggle_pause()
	_root.queue_redraw()


func _set_speed(s: int) -> void:
	clock.set_speed(s)
	_root.queue_redraw()


func _make_theme() -> Theme:
	var t := Theme.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.065, 0.075, 0.97)
	box.border_color = Look.GOLD_DIM
	box.set_border_width_all(2)
	box.set_content_margin_all(10)
	t.set_stylebox("panel", "TooltipPanel", box)
	t.set_font("font", "TooltipLabel", Look.font("sans"))
	t.set_font_size("font_size", "TooltipLabel", 19)
	t.set_color("font_color", "TooltipLabel", Look.TEXT)
	return t


## 看不见的方块: 鼠标指着显示说明, 点一下做事
class Spot:
	extends Control

	var hud: Hud
	var on_click: Callable

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		if on_click.is_valid():
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)

	func _on_enter() -> void:
		hud._hover_spot = self
		hud.map.clear_hover()
		hud.redraw()

	func _on_exit() -> void:
		if hud._hover_spot == self:
			hud._hover_spot = null
		hud.redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and on_click.is_valid():
			on_click.call()
			accept_event()


## 所有的画都在这里画
class Root:
	extends Control

	var hud: Hud

	func hot(rect: Rect2) -> bool:
		return hud._hover_spot != null and hud._hover_spot.visible and Rect2(hud._hover_spot.position, hud._hover_spot.size).is_equal_approx(rect)

	func _draw() -> void:
		_top_bar()
		_right_menu()
		_bottom_left()
		_map_modes()
		_date_bar()
		if hud.player_id == "":
			_banner()
		_alert_row()
		if hud.person_id != "":
			_person_panel()
		if hud.county:
			_county_panel()
		if not hud.window.is_empty():
			_window()
		if hud.show_help:
			_help()
		_notifications()
		_map_tooltip()
		_toast()
		if not hud.popup.is_empty():
			_popup()

	# ---- 右上角 ----
	func _top_bar() -> void:
		var r := TOP_BAR
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
				Vector2(r.position.x + 22, r.end.y), Vector2(r.position.x, r.end.y - 22)])
		draw_colored_polygon(pts, Look.PANEL)
		draw_polyline(PackedVector2Array([Vector2(r.end.x, r.end.y), Vector2(r.position.x + 22, r.end.y),
				Vector2(r.position.x, r.end.y - 22), r.position]), Look.GOLD_DIM, 2.0, true)
		for i in RESOURCES.size():
			var res: Array = RESOURCES[i]
			var x: float = TOP_SLOTS[i]
			if i > 0:
				draw_line(Vector2(x - 6, 8), Vector2(x - 6, 38), Color(Look.GOLD_DIM, 0.5), 1.0)
			draw_circle(Vector2(x + 18, 22), 15, Color(0.12, 0.12, 0.13))
			Icons.draw(self, res[0], Vector2(x + 18, 22), 24, Color(res[1]))
			if hud.player_id == "" or not hud.world.people.has(hud.player_id) or i in [2, 3]:
				Look.text(self, Vector2(x + 40, 28), "—", 20, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
			else:
				var m := hud.me()
				var inc := hud.world.income(m)
				var value := "—"
				var gain := ""
				match i:
					0:
						value = str(int(m.gold))
						gain = "%+.1f" % inc.gold
					1:
						value = str(int(m.prestige))
						gain = "+1.0" if m.realm != "" else "+0.5"
					4:
						value = str(int(inc.levy))
					5:
						value = "%d/%d" % [inc.domain, inc.limit]
				Look.text(self, Vector2(x + 40, 24), value, 20, Look.RED if i == 5 and inc.domain > inc.limit else Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
				Look.text(self, Vector2(x + 40, 40), gain, 13, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")

	# ---- 屏幕上方正中: 提醒 ----
	func _alert_row() -> void:
		var n := hud.alerts.size()
		for i in n:
			var a: Dictionary = hud.alerts[i]
			var r := hud._alert_rect(i, n)
			var c := r.get_center()
			Look.round_button(self, c, ALERT_R, a.icon, a.color, a.kind == "domain", hot(r))
			draw_circle(c + Vector2(ALERT_R * 0.75, -ALERT_R * 0.7), 10, Color("b0352b"))
			Look.text_center(self, Rect2(c + Vector2(ALERT_R * 0.75 - 10, -ALERT_R * 0.7 - 10), Vector2(20, 20)), str(a.count), 13, Color.WHITE, "sans")

	# ---- 右边一列 ----
	func _right_menu() -> void:
		var r := RIGHT_MENU
		draw_rect(r, Look.PANEL)
		draw_line(r.position, Vector2(r.position.x, r.end.y), Look.GOLD_DIM, 2.0)
		draw_line(r.position, Vector2(r.end.x, r.position.y), Look.GOLD_DIM, 2.0)
		draw_line(Vector2(r.position.x, r.end.y), r.end, Look.GOLD_DIM, 2.0)
		for gap in [272.0, 422.0]:
			draw_line(Vector2(r.position.x + 8, gap), Vector2(r.end.x - 4, gap), Color(Look.GOLD_DIM, 0.6), 1.0)
		for i in MENU.size():
			var m: Array = MENU[i]
			var box := Rect2(1878, RIGHT_MENU_Y[i] - 20, 42, 40)
			if hot(box):
				draw_rect(box.grow(-2), Color(1, 1, 1, 0.08))
			Icons.draw(self, m[0], box.get_center(), 30, Color(m[1]))

	## 头像框的形状: 上面是圆拱的窗户
	func arch() -> PackedVector2Array:
		var r := PORTRAIT
		var pts := PackedVector2Array()
		var radius := r.size.x / 2.0
		var top := r.position.y + radius
		for k in range(0, 33):
			var a := PI + PI * k / 32.0
			pts.append(Vector2(r.get_center().x + cos(a) * radius, top + sin(a) * radius))
		pts.append(r.end)
		pts.append(Vector2(r.position.x, r.end.y))
		return pts

	# ---- 左下角 ----
	func _bottom_left() -> void:
		# 头像框 (底色和头像在下面一层 _back 里画, 这里只描边)
		var r := PORTRAIT
		var arch := arch()
		var outline := arch.duplicate()
		outline.append(arch[0])
		draw_polyline(outline, Look.GOLD_DIM, 2.0, true)
		if hud.player_id != "":
			var me := hud.me()
			Look.panel(self, NAME_PLATE, Look.PANEL)
			Look.text_center(self, NAME_PLATE, "%s · %d 岁" % [me.name, me.age(hud.clock.day)], 20, Look.TEXT)
		else:
			Look.text_center(self, Rect2(r.position.x, 890, r.size.x, 40), "还没选人", 22, Look.TEXT_DIM)
		# 头像左边三个小方块
		var squares := [["candle", Icons.FLAME], ["cross", Icons.SILVER], ["banner", Color("4a78b0")]]
		for i in 3:
			var box := Rect2(0, LEFT_SQUARES_Y[i] - 20, 45, 40)
			Look.panel(self, box, Look.PANEL, false)
			draw_rect(box, Look.GOLD if hot(box) else Look.GOLD_DIM, false, 1.5)
			Icons.draw(self, squares[i][0], box.get_center(), 30, squares[i][1])
		# 主要头衔: 王冠 + 纹章盾
		Icons.draw(self, "crown", Vector2(33, 997), 40, Icons.GOLD)
		_shield(TITLE_SHIELD, hud.player, hud.me())
		# 下面一排圆按钮: 家族、压力、召集军队、决议
		var labels := ["house", "bust", "swords", "decree"]
		for i in 4:
			var c: Vector2 = BOTTOM_ROW[i][0]
			var rad: float = BOTTOM_ROW[i][1]
			if i == 1:
				draw_rect(STRESS_BAR, Color(0.06, 0.065, 0.075, 0.95))
				if hud.player_id != "":
					var st := hud.me().stress / Person.MAX_STRESS
					draw_rect(Rect2(STRESS_BAR.position, Vector2(STRESS_BAR.size.x * st, STRESS_BAR.size.y)), Color("b0503a"))
				draw_rect(STRESS_BAR, Look.GOLD_DIM, false, 1.5)
			Look.round_button(self, c, rad, labels[i], [Color("8a3a32"), Look.TEXT_DIM, Color("e0e4e8"), Icons.PARCHMENT][i], false, hot(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2)))

	## 国家的纹章盾 (封臣用自己家族的纹章); 还没选人时是一面灰盾牌, 上面一个问号
	func _shield(r: Rect2, realm_id: String, who: Person = null) -> void:
		if who != null and who.realm == "" and hud.world.houses.has(who.house):
			var hs: Dictionary = hud.world.houses[who.house]
			Icons.arms(self, r, int(hs.design) % Icons.DESIGNS, hs.color, Icons.charge_color(hs.color, int(hs.design)))
			return
		if realm_id != "" and hud.world.realms.has(realm_id):
			Icons.realm_arms(self, r, hud.world.realms[realm_id])
			return
		var pts := Icons.shield_points(r)
		draw_colored_polygon(pts, Color(0.3, 0.3, 0.32))
		pts.append(pts[0])
		draw_polyline(pts, Color("d9c08a"), 2.0, true)
		Look.text_center(self, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.85)), "?", int(r.size.x * 0.5), Color(1, 0.97, 0.9), "sans")

	# ---- 右下角: 地图模式 ----
	func _map_modes() -> void:
		var r := MAP_MODES
		draw_rect(r, Color(0.06, 0.065, 0.075, 0.8))
		draw_line(r.position, Vector2(r.end.x, r.position.y), Look.GOLD_DIM, 1.5)
		draw_line(r.position, Vector2(r.position.x, r.end.y), Look.GOLD_DIM, 1.5)
		Look.text(self, Vector2(r.position.x + 14, r.position.y + 26), "地图模式", 18, Look.GREEN)
		Look.text(self, Vector2(r.position.x + 14, r.position.y + 50), "现在: " + MapView.MODE_NAMES[hud.map.mode], 17, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		var mode := hud.map.mode
		Look.round_button(self, MODE_BIG, 22, "banner", Color("c84a3a"), mode == MapView.Mode.REALM, hot(Rect2(MODE_BIG - Vector2(22, 22), Vector2(44, 44))))
		var labels := ["coronet", "crown", "imperial_crown", "mountain", "book", "cross", "house"]
		var modes := [MapView.Mode.DUCHY, MapView.Mode.KINGDOM, MapView.Mode.EMPIRE, -1, -1, -1, MapView.Mode.HOUSE]
		for i in labels.size():
			var c: Vector2 = MODE_SMALL[i]
			var rad := 14.0 if i < 3 else 13.0
			var lit: bool = mode == modes[i]
			var usable: bool = modes[i] != -1
			Look.round_button(self, c, rad, labels[i], Icons.GOLD if usable else Look.TEXT_DIM, lit, hot(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2)))

	# ---- 右下角: 日期和速度 ----
	func _date_bar() -> void:
		var r := DATE_BAR
		var pts := PackedVector2Array([Vector2(r.position.x + 18, r.position.y), Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y + 18)])
		draw_colored_polygon(pts, Look.PANEL)
		draw_polyline(PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y + 18), Vector2(r.position.x + 18, r.position.y), Vector2(r.end.x, r.position.y)]), Look.GOLD_DIM, 2.0, true)
		Look.text_center(self, Rect2(1330, 1042, 34, 36), "≡", 24, Look.TEXT, "sans")
		Look.text_center(self, Rect2(1368, 1042, 34, 36), "?", 22, Look.TEXT, "sans")
		var paused := hud.clock.paused
		Look.text_center(self, Rect2(1410, 1040, 300, 40), hud.clock.text(), 24, Look.TEXT_DIM if paused else Look.TEXT)
		Look.text_center(self, Rect2(1708, 1040, 40, 40), "‖" if paused else "▶", 20, Look.RED if paused else Look.GREEN, "sans")
		for i in 5:
			var box := Rect2(SPEED_BOXES_X + i * 33, 1048, 31, 26)
			var on: bool = i < hud.clock.speed
			var fill := Color(0.12, 0.13, 0.14)
			if on:
				fill = Color(0.55, 0.3, 0.25) if paused else Color(0.35, 0.6, 0.3)
			draw_rect(box, fill)
			draw_rect(box, Look.GOLD if hot(Rect2(SPEED_BOXES_X + i * 33, 1044, 31, 32)) else Color(0, 0, 0, 0.6), false, 1.5)
		if paused and hud.player_id != "":
			var tag := Rect2(1600, 1006, 180, 32)
			Look.panel(self, tag, Look.PANEL)
			Look.text_center(self, tag, "已暂停 (按空格继续)", 16, Look.RED, "sans")

	# ---- 还没选国王: 上面的提示 ----
	func _banner() -> void:
		Look.panel(self, BANNER)
		Look.text_center(self, Rect2(BANNER.position.x, BANNER.position.y + 8, BANNER.size.x, 40), "867 年 1 月 1 日 · 不列颠群岛", 30, Look.GOLD)
		Look.text_center(self, Rect2(BANNER.position.x, BANNER.position.y + 50, BANNER.size.x, 34), "在地图上点一块领地, 选它的主人来玩 (国王或者封臣)", 22, Look.TEXT, "sans")
		_wide_button(RULES_BUTTON, "开局设置", false)

	# ---- 左边的领地窗口 ----
	# ---- 左边的人物窗口 ----
	func _person_panel() -> void:
		var w := hud.world
		var p: Person = w.people[hud.person_id]
		var day := hud.clock.day
		var r := SIDE_PANEL
		Look.panel(self, r, Color(0.07, 0.075, 0.09, 1.0))
		var realm: Dictionary = w.realms.get(p.realm, {})
		var liege_realm: Dictionary = w.realms.get(p.liege_realm, {})
		var band: Color = realm.color if not realm.is_empty() else (Color(liege_realm.color, 0.6) if not liege_realm.is_empty() and w.is_landed(p) else Look.GOLD_DIM)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 312)), Color(band, 0.28))
		draw_line(Vector2(0, 312), Vector2(r.size.x, 312), Look.GOLD_DIM, 2.0)
		draw_rect(CHAR_FACE, Color(0.1, 0.1, 0.11))
		draw_rect(CHAR_FACE.grow(2), Look.GOLD_DIM, false, 2.0)
		Look.text_center(self, Rect2(r.end.x - 52, 14, 38, 38), "✕", 24, Look.TEXT if hot(Rect2(r.end.x - 52, 14, 38, 38)) else Look.TEXT_DIM, "sans")
		# 名字、头衔、岁数、文化
		Look.text(self, Vector2(284, 76), p.name, 34 if p.name.length() <= 6 else 26, Look.TEXT)
		var title := w.title_of(p) if p.alive else ""
		if title != "":
			Look.text(self, Vector2(286, 110), title, 18, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, 250, "sans")
		var born: int = GameDate.from_day(p.birth_day)[0]
		if p.alive:
			Look.text(self, Vector2(286, 144), "%d 岁 (%d 年生)" % [p.age(day), born], 18, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		else:
			Look.text(self, Vector2(286, 144), "已故 · 享年 %d 岁 (%d 年)" % [p.age(day), GameDate.from_day(p.death_day)[0]], 18, Look.RED, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		Look.text(self, Vector2(286, 174), "%s · %s" % [p.culture_name(), w.house_name(p.house)], 17, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 250, "sans")
		if not realm.is_empty():
			Icons.realm_arms(self, Rect2(286, 196, 56, 66), realm)
			Look.text(self, Vector2(354, 236), w.realm_name(p.realm), 20, Look.TEXT)
			var al := w.allies(p.realm)
			var al_text := "同盟: " + ("、".join(al.map(func(r: String) -> String: return w.realm_name(r))) if not al.is_empty() else "没有")
			if p.tyranny >= 1.0:
				al_text += " · 暴政 %d" % int(p.tyranny)
			Look.text(self, CHAR_ALLIES.position + Vector2(10, 22), al_text, 15, Look.GOLD if hot(CHAR_ALLIES) else Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, CHAR_ALLIES.size.x - 10, "sans")
		elif w.houses.has(p.house):
			var hs: Dictionary = w.houses[p.house]
			Icons.arms(self, Rect2(286, 196, 56, 66), int(hs.design) % Icons.DESIGNS, hs.color, Icons.charge_color(hs.color, int(hs.design)))
			Look.text(self, Vector2(354, 236), hs.name, 20, Look.TEXT)
		# 封臣效忠谁、合同; 关在大牢里
		if realm.is_empty() and p.alive:
			var line := hud._status_line(p)
			if line != "":
				var red := p.prisoner_of != ""
				Look.text(self, CHAR_ALLIES.position + Vector2(10, 22), line, 15, Look.RED if red else (Look.GOLD if hot(CHAR_ALLIES) else Look.TEXT_DIM), HORIZONTAL_ALIGNMENT_LEFT, CHAR_ALLIES.size.x - 10, "sans")
		# 健康、压力
		Look.text(self, CHAR_HEALTH.position + Vector2(8, 25), "健康", 20, Look.GOLD)
		var ht := p.health_text(day) if p.alive else "已故"
		var hcol := Look.GREEN if ht in ["好", "很好"] else (Look.RED if ht in ["差", "很差"] else Look.TEXT)
		Look.text(self, CHAR_HEALTH.position + Vector2(80, 25), ht, 20, hcol, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		if p.alive and not p.pregnant.is_empty():
			var due := GameDate.from_day(int(p.pregnant.due))
			Icons.draw(self, "cradle", CHAR_HEALTH.position + Vector2(196, 17), 28, Look.GOLD)
			Look.text(self, CHAR_HEALTH.position + Vector2(216, 25), "怀孕了, 大约 %d 年 %d 月生" % [due[0], due[1]], 17, Color("e0a0b0"), HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		Look.text(self, CHAR_STRESS.position + Vector2(8, 25), "压力", 20, Look.GOLD)
		var bar := Rect2(CHAR_STRESS.position + Vector2(80, 9), Vector2(300, 16))
		draw_rect(bar, Color(0.12, 0.12, 0.13))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * p.stress / Person.MAX_STRESS, bar.size.y)), Color("b0503a"))
		for k in [1, 2]:
			draw_line(bar.position + Vector2(bar.size.x * k / 3.0, 0), bar.position + Vector2(bar.size.x * k / 3.0, bar.size.y), Color(0, 0, 0, 0.6), 2.0)
		draw_rect(bar, Look.GOLD_DIM, false, 1.0)
		Look.text(self, bar.position + Vector2(bar.size.x + 14, 15), "%d (第 %d 档)" % [int(p.stress), p.stress_level()], 17, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		# 性格特点
		draw_line(Vector2(30, 420), Vector2(r.size.x - 30, 420), Color(Look.GOLD_DIM, 0.5), 1.0)
		Look.text(self, Vector2(32, 452), "性格特点", 20, Look.GOLD)
		var badges := hud._person_badges(p)
		for i in badges.size():
			var br := hud._badge_rect(i)
			Icons.trait_icon(self, badges[i], br.get_center(), BADGE)
			if hot(br):
				draw_rect(br.grow(3), Look.GOLD, false, 2.0)
		# 本事
		draw_line(Vector2(30, 600), Vector2(r.size.x - 30, 600), Color(Look.GOLD_DIM, 0.5), 1.0)
		Look.text(self, Vector2(32, 632), "本事", 20, Look.GOLD)
		for i in Traits.SKILLS.size():
			var sr := hud._skill_rect(i)
			var c := Vector2(sr.get_center().x, CHAR_SKILLS_Y)
			Icons.skill_icon(self, Traits.SKILLS[i], c, 52)
			Look.text_center(self, Rect2(sr.position.x - 10, CHAR_SKILLS_Y + 30, sr.size.x + 20, 30), str(p.skill(Traits.SKILLS[i], day)), 24, Look.TEXT)
			if hot(sr):
				draw_rect(sr.grow(3), Look.GOLD, false, 2.0)
		# 对你的好感
		draw_line(Vector2(30, 758), Vector2(r.size.x - 30, 758), Color(Look.GOLD_DIM, 0.5), 1.0)
		var oy := CHAR_OPINION.position.y + 29
		if hud.player_id == "":
			Look.text(self, Vector2(32, oy), "(选好人以后, 这里显示他对你的好感)", 16, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		elif hud.player_id == p.id:
			Look.text(self, Vector2(32, oy), "这就是你", 20, Look.GREEN)
		elif p.alive and hud.player_id != "":
			var o := p.opinion_of(hud.me())
			Look.text(self, Vector2(32, oy), "他对你的好感", 19, Look.GOLD)
			var ocol := Look.GREEN if o.total > 0 else (Look.RED if o.total < 0 else Look.TEXT)
			Look.text(self, Vector2(190, oy + 2), "%+d" % o.total, 26, ocol)
			Look.text(self, Vector2(270, oy), "(鼠标指着看为什么)", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		# 小孩: 学什么、老师是谁
		if p.alive and not p.adult(day):
			var sy := CHAR_HEIR.position.y + 25
			Look.text(self, Vector2(32, sy), "上学", 19, Look.GOLD)
			var school := "%d 岁, 6 岁开始跟老师学" % p.age(day)
			if p.age(day) >= 6:
				var g: String = ("老师 " + w.people[p.guardian].name) if p.guardian != "" else "没有老师"
				school = "学%s · %s" % [Traits.skill_info(p.focus).name, g]
			Look.text(self, Vector2(100, sy), school, 18, Look.GOLD if hot(CHAR_HEIR) else Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 420, "sans")
		# 继承人
		if p.alive and p.realm != "":
			var law := Succession.law_of(w.realms[p.realm].culture)
			var h := w.heir(p.realm, day)
			var hy := CHAR_HEIR.position.y + 25
			Look.text(self, Vector2(32, hy), "继承人", 19, Look.GOLD)
			if h:
				var rel := w.relation(p, h)
				Look.text(self, Vector2(110, hy), "%s (%s%d 岁)" % [h.name, (rel + ", ") if rel != "" else "", h.age(day)], 19, Look.TEXT if not hot(CHAR_HEIR) else Look.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 300, "sans")
			else:
				Look.text(self, Vector2(110, hy), "没有! 家族里没有能继承的男人", 18, Look.RED, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
			Look.text(self, Vector2(430, hy), Succession.NAMES[law], 16, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		# 家人
		draw_line(Vector2(30, 852), Vector2(r.size.x - 30, 852), Color(Look.GOLD_DIM, 0.5), 1.0)
		Look.text(self, Vector2(32, 876), "家人", 19, Look.GOLD)
		if hud._family.is_empty():
			Look.text(self, Vector2(90, 876), "(没有)", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		for i in hud._family.size():
			var fr := hud._family_rect(i)
			draw_rect(fr, Color(0.12, 0.12, 0.13))
			draw_rect(fr.grow(1), Look.GOLD if hot(fr) else Look.GOLD_DIM, false, 1.0)
			var f: Person = w.people[hud._family[i]]
			Look.text_center(self, Rect2(fr.position.x - 4, fr.end.y + 2, fr.size.x + 8, 18), w.relation(p, f), 13, Look.TEXT_DIM if f.alive else Color(Look.TEXT_DIM, 0.5), "sans")
		var total := 4 + p.secondary.size() + w.children_of(p).size() + w.siblings_of(p).size()
		if hud._family.size() == FAMILY_MAX and total > FAMILY_MAX:
			Look.text(self, Vector2(hud._family_rect(FAMILY_MAX - 1).end.x + 8, FAMILY_Y + 38), "…", 22, Look.TEXT_DIM)
		var buttons := hud._person_buttons(p)
		for i in buttons.size():
			_icon_button(hud._button_rect(i, buttons.size()), buttons[i][0], buttons[i][1], i > 0)

	func _icon_button(r: Rect2, label: String, icon: String, main: bool) -> void:
		var lit := hot(r)
		draw_rect(r, Color(0.2, 0.17, 0.11) if main else Color(0.11, 0.115, 0.13))
		draw_rect(r, Look.GOLD if lit or main else Look.GOLD_DIM, false, 2.0)
		var f := Look.font()
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var x0 := r.get_center().x - (tw + 34) / 2.0
		Icons.draw(self, icon, Vector2(x0 + 14, r.get_center().y), 30, Look.GOLD)
		Look.text(self, Vector2(x0 + 34, r.get_center().y + 8), label, 20, Look.TEXT)

	# ---- 右边的窗口: 说亲、教育、互动、你的国家、封地 ----
	func _window() -> void:
		var w := hud.world
		var win := hud.window
		var p: Person = w.people[win.person]
		var day := hud.clock.day
		var r := WINDOW
		Look.panel(self, r, Color(0.07, 0.075, 0.09, 1.0))
		Look.text_center(self, Rect2(r.end.x - 52, r.position.y + 14, 38, 38), "✕", 24, Look.TEXT if hot(Rect2(r.end.x - 52, r.position.y + 14, 38, 38)) else Look.TEXT_DIM, "sans")
		var kind: String = win.kind
		var title := ""
		var sub := ""
		var icon := "rings"
		match kind:
			"match":
				title = "给%s说亲" % p.name
				sub = "%s, %d 岁。能嫁娶的人 (不是近亲、还能结婚的), 点一行就去提亲; 鼠标指着看对方肯不肯" % ["女" if p.female else "男", p.age(day)]
				if p.married():
					sub = "爱尔兰古法准许再娶: 正妻%s之外还能娶 %d 个次妻" % [p.living_spouse().name, Marriage.max_wives(p) - w.wives_of(p).size()]
			"teacher":
				title = "%s的教育" % p.name
				sub = "%d 岁。上面选学什么, 下面点一个人请他当老师 (老师这一样本事越高, 教得越好)" % p.age(day)
				icon = "book"
			"actions":
				title = "对%s做事" % p.name
				var rel := w.relation(hud.me(), p)
				sub = "%s%s · 他对你的好感 %+d。点一行就做; 狠的事要点两次" % [w.title_of(p) if w.title_of(p) != "" else p.culture_name(), (" · 你的" + rel) if rel != "" else "", p.opinion_of(hud.me()).total]
				icon = "decree"
			"realm":
				var inc := w.income(p)
				title = ("我的国家: " + w.realm_name(p.realm)) if p.realm != "" else "我的领地: " + w.title_of(p)
				sub = "直辖领地 %d 块 (上限 %d) · 每月 %+.1f 金币 · 兵 %d 人 · 封臣 %d 个%s" % [inc.domain, inc.limit, inc.gold, inc.levy, w.vassals_of(p).size(), (" · 暴政 %d" % int(p.tyranny)) if p.tyranny >= 1.0 else ""]
				icon = "tower"
			"grant":
				if win.has("county"):
					title = "把%s封给谁" % w.by_id[win.county].name
					sub = "你家族里成年、没在别处有地的男人, 还有三个本地贵族。点一行就封"
				else:
					title = "封谁当%s副王" % w.duchies[win.duchy].name
					sub = "副王只封给自己家族的人。点一行就封"
				icon = "crown"
		Icons.draw(self, icon, r.position + Vector2(44, 46), 44, Look.GOLD)
		Look.text(self, r.position + Vector2(80, 56), title, 30, Look.GOLD, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 140)
		Look.text(self, r.position + Vector2(24, 84), sub, 16, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 48, "sans")
		# 上面一排: 说亲是排法, 教育是学什么
		if kind == "match":
			for i in MATCH_TABS.size():
				var tr := hud._win_tab_rect(i, MATCH_TABS.size())
				var on: bool = win.tab == i
				draw_rect(tr, Color(0.2, 0.17, 0.11) if on else Color(0.11, 0.115, 0.13))
				draw_rect(tr, Look.GOLD if on or hot(tr) else Look.GOLD_DIM, false, 2.0)
				Look.text_center(self, tr, MATCH_TABS[i], 19, Look.TEXT if on else Look.TEXT_DIM, "sans")
		elif kind == "teacher":
			var tracks: Array = Traits.data().education.tracks
			for i in tracks.size():
				var tr := hud._win_tab_rect(i, tracks.size())
				var on: bool = p.focus == tracks[i].skill
				draw_rect(tr, Color(0.14, 0.2, 0.28) if on else Color(0.11, 0.115, 0.13))
				draw_rect(tr, Look.GOLD if on or hot(tr) else Look.GOLD_DIM, false, 2.0)
				Icons.skill_icon(self, tracks[i].skill, tr.position + Vector2(24, 22), 32)
				var fits := Traits.focus_fits(p.childhood(), tracks[i].skill)
				Look.text(self, tr.position + Vector2(46, 29), tracks[i].name + (" ★" if fits else ""), 16, Look.TEXT if on else Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, tr.size.x - 50, "sans")
		# 表头
		var hy := hud._row_top() - 10
		var x0 := r.position.x + 20
		match kind:
			"match":
				Look.text(self, Vector2(x0 + 76, hy), "名字 · 是谁家的", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
				Look.text(self, Vector2(x0 + 382, hy), "本事: 外交 军事 管理 密谋 学识 武力", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
				Look.text(self, Vector2(x0 + 680, hy), "肯不肯", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
			"teacher":
				Look.text(self, Vector2(x0 + 76, hy), "名字 · 跟他什么关系", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
				Look.text(self, Vector2(x0 + 450, hy), Traits.skill_info(p.focus).name, 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
				Look.text(self, Vector2(x0 + 570, hy), "带着几个学生", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
			"grant":
				Look.text(self, Vector2(x0 + 76, hy), "名字 · 是谁", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
				Look.text(self, Vector2(x0 + 382, hy), "本事: 外交 军事 管理 密谋 学识 武力", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		if win.rows.is_empty():
			var none := {"match": "没有合适的人", "teacher": "没有能当老师的大人 (家里的大人都带满了 3 个学生)", "actions": "现在没有能对他做的事",
					"realm": "你没有领地", "grant": "没有合适的人"}
			Look.text_center(self, Rect2(r.position.x, hud._row_top() + 60, r.size.x, 40), none.get(kind, ""), 20, Look.TEXT_DIM, "sans")
		var start: int = win.page * WIN_ROWS
		for i in range(start, mini(start + WIN_ROWS, win.rows.size())):
			var row: Dictionary = win.rows[i]
			var rr := hud._win_row_rect(i - start)
			var chosen: bool = kind == "teacher" and p.guardian == row.person.id
			var armed: bool = kind == "actions" and win.armed == i
			var off: bool = kind == "actions" and not row.ok
			draw_rect(rr, Color(0.3, 0.1, 0.08) if armed else (Color(0.14, 0.2, 0.28) if chosen else (Color(0.13, 0.12, 0.1) if hot(rr) else Color(0.09, 0.095, 0.11))))
			draw_rect(rr, Look.RED if armed else (Look.GOLD if hot(rr) or chosen else Color(Look.GOLD_DIM, 0.4)), false, 1.5)
			match kind:
				"actions":
					Icons.draw(self, row.icon, rr.position + Vector2(38, 38), 40, Look.TEXT_DIM if off else Look.GOLD)
					Look.text(self, rr.position + Vector2(76, 30), row.name + ("  (再点一次确定)" if armed else ""), 20, Look.RED if armed else (Look.TEXT_DIM if off else Look.TEXT), HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 90, "sans")
					Look.text(self, rr.position + Vector2(76, 58), row.desc if row.ok else "做不了: " + row.why, 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 90, "sans")
				"realm":
					_realm_row(rr, row)
				_:
					var c: Person = row.person
					draw_rect(Rect2(rr.position + Vector2(8, 4), Vector2(56, 65)), Color(0.12, 0.12, 0.13), false, 1.0)
					Look.text(self, rr.position + Vector2(76, 30), "%s  %d 岁" % [c.name, c.age(day)], 20, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 300, "sans")
					if kind == "match" or kind == "grant":
						var kin := w.ruler_kin(c)
						var who: String = kin if kin != "" else ("本地贵族" if row.new else w.house_name(c.house))
						if kind == "grant" and not row.new:
							var rel := w.relation(hud.me(), c)
							who = (rel + " · " if rel != "" else "") + w.house_name(c.house)
						Look.text(self, rr.position + Vector2(76, 58), "%s · %s" % [c.culture_name(), who], 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, 296, "sans")
						for k in Traits.SKILLS.size():
							Look.text_center(self, Rect2(rr.position.x + 380 + k * 46, rr.position.y + 18, 44, 30), str(c.skill(Traits.SKILLS[k], day)), 19, Look.TEXT, "sans")
					if kind == "match":
						var tags := []
						if not (p.adult(day) and c.adult(day)):
							tags.append("先订婚")
						if not tags.is_empty():
							Look.text(self, rr.position + Vector2(384, 64), " · ".join(tags), 14, Look.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
						var ok: bool = row.acc.total > 0
						Look.text(self, rr.position + Vector2(676, 44), ("肯 %+d" if ok else "不肯 %+d") % row.acc.total, 21, Look.GREEN if ok else Look.RED, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
					elif kind == "teacher":
						var rel := w.relation(p, c)
						Look.text(self, rr.position + Vector2(76, 58), (rel + " · " if rel != "" else "") + c.culture_name(), 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, 340, "sans")
						Icons.skill_icon(self, p.focus, rr.position + Vector2(450, 37), 40)
						Look.text(self, rr.position + Vector2(480, 46), str(row.skill), 26, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
						Look.text(self, rr.position + Vector2(590, 46), "%d / %d" % [row.wards, World.MAX_WARDS], 19, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
						if chosen:
							Look.text(self, rr.position + Vector2(670, 46), "现在的老师", 16, Look.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		if hud._win_pages() > 1:
			for k in 2:
				var br := Rect2(r.position.x + 20, r.end.y - 62, 200, 46) if k == 0 else Rect2(r.end.x - 220, r.end.y - 62, 200, 46)
				_wide_button(br, "上一页" if k == 0 else "下一页", false)
			Look.text_center(self, Rect2(r.position.x, r.end.y - 62, r.size.x, 46), "第 %d / %d 页 (一共 %d 个)" % [win.page + 1, hud._win_pages(), win.rows.size()], 17, Look.TEXT_DIM, "sans")

	## 「我的国家」窗口里的一行
	func _realm_row(rr: Rect2, row: Dictionary) -> void:
		var w := hud.world
		var me := hud.me()
		match row.type:
			"liege":
				var l: Person = row.person
				Look.text(self, rr.position + Vector2(76, 30), "效忠: %s %s" % [w.title_of(l), l.name], 20, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 600, "sans")
				Look.text(self, rr.position + Vector2(76, 58), "合同「%s」: 交税 %d%%、交兵 %d%% · 他对你的好感 %+d" % [Feudal.CONTRACTS[me.contract], int(Feudal.TAX_SHARE[me.contract] * 100), int(Feudal.LEVY_SHARE[me.contract] * 100), l.opinion_of(me).total], 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, 640, "sans")
			"county":
				var c: Dictionary = row.county
				Icons.draw(self, "tower", rr.position + Vector2(38, 38), 40, Look.GOLD if row.active else Look.RED)
				Look.text(self, rr.position + Vector2(76, 30), c.name + ("  (都城)" if row.capital else ""), 20, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 400, "sans")
				var note := "直辖 · 每月 +%d 金币、%d 个兵" % [int(Feudal.GOLD_PER_COUNTY), Feudal.LEVY_PER_COUNTY] if row.active else "超过直辖上限: 不出钱不出兵, 封出去吧"
				Look.text(self, rr.position + Vector2(76, 58), note, 15, Look.TEXT_DIM if row.active else Look.RED, HORIZONTAL_ALIGNMENT_LEFT, 500, "sans")
				if not row.capital:
					Look.text(self, rr.position + Vector2(rr.size.x - 120, 46), "封出去 ›", 17, Look.GOLD if hot(rr) else Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
			"duchy":
				Icons.draw(self, "coronet", rr.position + Vector2(38, 38), 40, Look.GOLD)
				Look.text(self, rr.position + Vector2(76, 30), "%s公国 (头衔)" % w.duchies[row.duchy].name, 20, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 400, "sans")
				Look.text(self, rr.position + Vector2(76, 58), "可以封给家里人当副王", 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, 500, "sans")
				Look.text(self, rr.position + Vector2(rr.size.x - 120, 46), "封副王 ›", 17, Look.GOLD if hot(rr) else Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
			"vassal":
				var v: Person = row.person
				var inc := w.income(v)
				Look.text(self, rr.position + Vector2(76, 30), "%s %s" % [w.title_of(v), v.name], 20, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 420, "sans")
				Look.text(self, rr.position + Vector2(76, 58), "%d 块领地 · 合同%s · 每月交 %.1f 金币、%d 个兵" % [w.lands_of(v).size(), Feudal.CONTRACTS[v.contract], inc.paid_gold, inc.paid_levy], 15, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, 500, "sans")
				var o: int = v.opinion_of(me).total
				Look.text(self, rr.position + Vector2(rr.size.x - 130, 44), "好感 %+d" % o, 19, Look.GREEN if o > 0 else (Look.RED if o < 0 else Look.TEXT), HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
	func _county_panel() -> void:
		var w := hud.world
		var c := w.county_at(hud.county)
		var realm := w.realm_of(c)
		var r := SIDE_PANEL
		Look.panel(self, r, Color(0.07, 0.075, 0.09, 1.0))
		# 顶上: 名字和爵位链
		draw_rect(Rect2(r.position, Vector2(r.size.x, 150)), Color(realm.color, 0.35))
		draw_line(Vector2(0, 150), Vector2(r.size.x, 150), Look.GOLD_DIM, 2.0)
		_shield(Rect2(28, 26, 80, 96), c.holder)
		Look.text(self, Vector2(130, 68), c.name, 44, Look.TEXT)
		Look.text(self, Vector2(132, 102), "伯爵领 · 属于%s公国" % w.duchy_of(c).name, 18, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		Look.text(self, Vector2(132, 128), "%s王国 · %s帝国 (按法理)" % [w.kingdom_of(c).name, w.empire.name], 18, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		Look.text_center(self, Rect2(r.end.x - 52, 14, 38, 38), "✕", 24, Look.TEXT if hot(Rect2(r.end.x - 52, 14, 38, 38)) else Look.TEXT_DIM, "sans")
		# 主人
		var y := 200.0
		var lord: Person = w.people[c.lord]
		draw_rect(PANEL_FACE, Color(0.12, 0.12, 0.13))
		draw_rect(PANEL_FACE.grow(1), Look.GOLD_DIM, false, 1.5)
		Look.text(self, Vector2(176, y), "主人", 20, Look.GOLD)
		Look.text(self, Vector2(176, y + 36), w.title_of(lord), 18, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		Look.text(self, Vector2(176, y + 72), lord.name, 30, Look.TEXT)
		var born_text := "%d 岁 (%d 年生)" % [lord.age(hud.clock.day), GameDate.from_day(lord.birth_day)[0]]
		Look.text(self, Vector2(176, y + 104), born_text, 17, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		y = 240.0
		var mine := w.counties_of(c.holder)
		var area := 0
		for m in mine:
			area += m.area_km2
		Look.text(self, Vector2(40, y + 100), "这个国家有 %d 块领地, %d 平方公里" % [mine.size(), area], 17, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		var liege := w.liege_of(lord)
		if liege != null:
			Look.text(self, Vector2(40, y + 124), "他是%s %s的%s" % [w.title_of(liege), liege.name, w.vassal_kind(lord)], 17, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 480, "sans")

		# 这块领地
		y = 410.0
		draw_line(Vector2(30, y - 30), Vector2(r.size.x - 30, y - 30), Color(Look.GOLD_DIM, 0.5), 1.0)
		Look.text(self, Vector2(40, y), "这块领地", 20, Look.GOLD)
		Look.text(self, Vector2(40, y + 34), "面积: %d 平方公里%s" % [c.area_km2, " · 靠海" if c.coastal else " · 不靠海"], 19, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		var names := []
		for n in c.neighbors:
			names.append(w.by_id[n].name)
		var nb := "挨着: " + ("、".join(names) if not names.is_empty() else "没有 (是个岛)")
		draw_multiline_string(Look.font("sans"), Vector2(40, y + 68), nb, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 19, 4, Look.TEXT)
		# 同一个公国里的领地
		y = 600.0
		draw_line(Vector2(30, y - 30), Vector2(r.size.x - 30, y - 30), Color(Look.GOLD_DIM, 0.5), 1.0)
		var duchy := w.duchy_of(c)
		Look.text(self, Vector2(40, y), "%s公国 (按法理) 的领地" % duchy.name, 20, Look.GOLD)
		var row := 0
		for d in w.counties_in_duchy(duchy.id):
			var ly := y + 36 + row * 28
			if ly > 870:
				Look.text(self, Vector2(40, ly), "……", 18, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
				break
			draw_rect(Rect2(40, ly - 15, 14, 14), w.realm_of(d).color)
			Look.text(self, Vector2(64, ly), d.name, 18, Look.TEXT if d.index != c.index else Look.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
			Look.text(self, Vector2(220, ly), w.realm_name(d.holder), 18, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
			row += 1
		# 下面的按钮
		_wide_button(Rect2(40, 890, 480, 50), "看看整个%s" % w.realm_name(c.holder), false)
		if hud.player_id == "":
			_wide_button(Rect2(40, 960, 480, 56), "玩这个人: %s" % lord.name, true)
		elif hud.player_id == c.lord:
			Look.text_center(self, Rect2(40, 960, 480, 56), "这是你的领地", 20, Look.GREEN, "sans")
		elif hud.player == c.holder:
			Look.text_center(self, Rect2(40, 960, 480, 56), "这是你国家里的领地", 20, Look.TEXT_DIM, "sans")

	func _wide_button(r: Rect2, label: String, main: bool) -> void:
		var lit := hot(r)
		draw_rect(r, Color(0.2, 0.17, 0.11) if main else Color(0.11, 0.115, 0.13))
		draw_rect(r, Look.GOLD if lit or main else Look.GOLD_DIM, false, 2.0)
		Look.text_center(self, r, label, 24 if main else 20, Look.TEXT)

	# ---- 操作说明 ----
	func _help() -> void:
		var r := Rect2(560, 110, 800, 760)
		Look.panel(self, r)
		Look.text_center(self, Rect2(r.position.x, r.position.y + 14, r.size.x, 44), "操作说明", 30, Look.GOLD)
		var lines := [
			"鼠标左键点领地: 看这块领地 (左边弹出窗口)",
			"鼠标拖地图 (左键、右键、中键都行) 或者 W A S D / 方向键: 移动地图",
			"鼠标滚轮 (或者触控板两指捏): 放大缩小; 放大了能看到每块领地的名字",
			"空格: 暂停 / 继续      + -: 快一档 / 慢一档      1～5: 直接换速度",
			"右下角圆按钮: 换地图模式 (国家、公国、王国、帝国、家族)",
			"左下角盾牌: 看你的国家      Esc: 关窗口      F1: 这个说明",
			"",
			"点左下角的头像: 看你玩的这个人 (人物窗口)",
			"人物窗口下面的按钮: 说亲、教育 (请老师)、互动 (送礼、收回领地、关大牢)",
			"右边一列第一个「领地」: 你的直辖领地、封臣, 把领地封出去",
			"右下角「≡」: 存档、读档、退出; 开局前横幅下面的「开局设置」",
			"上方正中的小图标是提醒 (孩子没老师、有人该结婚了……), 点了直接去办",
			"做好了第 1–5 块: 地图和时间、人物、家族和继承、结婚生子、封臣;",
			"打仗、阴谋这些还没有, 点那些按钮会提示「以后才有」。",
		]
		for i in lines.size():
			Look.text(self, Vector2(r.position.x + 40, r.position.y + 100 + i * 46), lines[i], 20, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, "sans")

	# ---- 鼠标指着地图上的领地 ----
	func _map_tooltip() -> void:
		if hud.hover_index == 0 or hud._hover_spot != null:
			return
		var w := hud.world
		var c := w.county_at(hud.hover_index)
		var m := get_local_mouse_position()
		var lord: Person = w.people[c.lord]
		var lines := [c.name, "%s %s" % [w.title_of(lord), lord.name]]
		var liege := w.liege_of(lord)
		if liege != null:
			lines.append("(%s %s的封臣)" % [w.title_of(liege), liege.name])
		var r := Rect2(m + Vector2(22, 18), Vector2(340, 74 + (lines.size() - 2) * 24))
		if r.end.x > 1900:
			r.position.x = m.x - 22 - r.size.x
		if r.end.y > 1070:
			r.position.y = m.y - 18 - r.size.y
		Look.panel(self, r, Color(0.06, 0.065, 0.075, 0.95))
		Look.text(self, r.position + Vector2(14, 30), lines[0], 22, Look.TEXT)
		for k in range(1, lines.size()):
			Look.text(self, r.position + Vector2(14, 58 + (k - 1) * 24), lines[k], 16, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, "sans")

	# ---- 右边的消息 ----
	func _notifications() -> void:
		var y := NOTES.position.y
		var f := Look.font("sans")
		for n in hud._notes:
			var a := clampf(float(n[1]), 0.0, 1.0)
			var lines := 1 if f.get_string_size(n[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x < NOTES.size.x - 24 else 2
			var r := Rect2(NOTES.position.x, y, NOTES.size.x, NOTES.size.y + (lines - 1) * 20)
			draw_rect(r, Color(0.06, 0.065, 0.075, 0.9 * a))
			draw_rect(r, Color(Look.GOLD_DIM, a), false, 1.5)
			draw_multiline_string(f, r.position + Vector2(12, 23), n[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 15, 2, Color(Look.TEXT, a))
			y += r.size.y + 6

	# ---- 正中间的窗口: 你的国王去世了 ----
	func _popup() -> void:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.45))
		if hud.popup.kind == "birth":
			_birth_popup()
			return
		if hud.popup.kind == "menu":
			_menu_popup()
			return
		if hud.popup.kind == "rules":
			_rules_popup()
			return
		var w := hud.world
		var e: Dictionary = hud.popup.event
		var dead: Person = w.people[e.dead]
		var heir: Person = w.people[e.get("heir", e.get("to", e.dead))]
		var r := POPUP
		Look.panel(self, r, Color(0.07, 0.075, 0.09, 1.0))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 84)), Color(0.25, 0.12, 0.1, 0.6))
		var kind: String = hud.popup.kind
		var over: bool = kind in ["game_over", "vassal_over"]
		var head := "%s去世了" % dead.name
		if kind == "game_over":
			head = "你的家族绝嗣了"
		elif kind == "vassal_over":
			head = "你的家族没有领地了"
		Look.text_center(self, Rect2(r.position.x, r.position.y + 14, r.size.x, 56), head, 36, Look.GOLD)
		for i in 2:
			var fr := Rect2(r.position + (Vector2(40, 120) if i == 0 else Vector2(r.size.x - 160, 120)), Vector2(Portrait.W, Portrait.H))
			draw_rect(fr.grow(2), Look.GOLD_DIM, false, 2.0)
			Look.text_center(self, Rect2(fr.position.x - 30, fr.end.y + 6, fr.size.x + 60, 24), dead.name if i == 0 else heir.name, 18, Look.TEXT_DIM if i == 0 else Look.TEXT, "sans")
		var lines := []
		var law: String = Succession.NAMES.get(e.get("law", ""), "")
		if kind == "vassal_over":
			lines.append("%s去世了, 享年 %d 岁。" % [dead.name, dead.age(e.day)])
			lines.append("%s里没有能继承的男人了," % w.house_name(dead.house))
			lines.append("他的领地归了%s %s。" % [w.title_of(heir), heir.name])
			lines.append("游戏结束。你可以换一个人接着玩。" if w.rules.ironman != "on" else "游戏结束 (铁人模式)。")
		elif kind == "vassal_succession":
			var rel2 := w.relation(dead, heir)
			lines.append("享年 %d 岁。" % dead.age(e.day))
			lines.append("照%s, 由他的%s%s继承领地。" % [law, rel2 if rel2 != "" else "族人", heir.name])
			lines.append("你现在是%s %s (%d 岁)。" % [w.title_of(heir), heir.name, heir.age(e.day)])
		elif over:
			lines.append("%s去世了, 享年 %d 岁。" % [dead.name, dead.age(e.day)])
			lines.append("%s里没有能继承的男人了。" % w.house_name(dead.house))
			lines.append("%s的贵族推举了%s当新国王。" % [e.realm_name, heir.name])
			lines.append("游戏结束。你可以换一个人接着玩。" if w.rules.ironman != "on" else "游戏结束 (铁人模式)。")
		else:
			var rel := w.relation(dead, heir)
			lines.append("享年 %d 岁。" % dead.age(e.day))
			lines.append("照%s, 由他的%s%s继承%s。" % [law, rel if rel != "" else "族人", heir.name, e.realm_name])
			for sp in e.splits:
				var son: Person = w.people[sp[1]]
				lines.append("%s%s分到了%s, 成了那里的国王。" % [w.relation(dead, son), son.name, w.realm_name(sp[0])])
			if e.merged_into != "":
				lines.append("%s本来就是%s的国王, 两个国家归到了他一个人手里。" % [heir.name, w.realm_name(e.merged_into)])
			lines.append("你现在是%s (%d 岁)。" % [heir.name, heir.age(e.day)])
		for i in lines.size():
			Look.text_center(self, Rect2(r.position.x + 180, r.position.y + 130 + i * 40, r.size.x - 360, 34), lines[i], 19, Look.TEXT, "sans")
		var iron_over: bool = over and w.rules.ironman == "on"
		_wide_button(POPUP_BUTTON, "开一局新游戏" if iron_over else ("换一个人接着玩" if over else "继续"), true)

	# ---- 正中间的窗口: 开局设置 ----
	func _rules_popup() -> void:
		var r := MENU_BOX
		var w := hud.world
		var editable := hud.player_id == ""
		Look.panel(self, r, Color(0.07, 0.075, 0.09, 1.0))
		Look.text_center(self, Rect2(r.position.x, r.position.y + 20, r.size.x, 56), "开局设置", 34, Look.GOLD)
		Look.text_center(self, Rect2(r.position.x, r.position.y + 70, r.size.x, 30),
				"选好了再选人开始; 开始以后不能改" if editable else "游戏开始以后不能改, 只能看", 16, Look.TEXT_DIM, "sans")
		for i in Rules.LIST.size():
			var rule: Array = Rules.LIST[i]
			var y: float = r.position.y + 120 + i * 150
			Look.text(self, Vector2(r.position.x + 30, y + 22), rule[1], 22, Look.GOLD)
			Look.text(self, Vector2(r.position.x + 30, y + 44), rule[2], 14, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, "sans")
			for j in rule[3].size():
				var br := hud._rule_option(i, j)
				var on: bool = w.rules[rule[0]] == rule[3][j][0]
				draw_rect(br, Color(0.2, 0.17, 0.11) if on else Color(0.11, 0.115, 0.13))
				draw_rect(br, Look.GOLD if on or (hot(br) and editable) else Look.GOLD_DIM, false, 2.0)
				Look.text_center(self, br, rule[3][j][1], 17, Look.TEXT if on else Look.TEXT_DIM, "sans")
		_wide_button(hud._menu_back(), "开始选人" if editable else "返回", true)

	# ---- 正中间的窗口: 菜单 (存档、读档、退出) ----
	func _menu_popup() -> void:
		var r := MENU_BOX
		var pop := hud.popup
		Look.panel(self, r, Color(0.07, 0.075, 0.09, 1.0))
		var title: String = {"main": "菜单", "save": "存档", "load": "读档"}[pop.view]
		Look.text_center(self, Rect2(r.position.x, r.position.y + 20, r.size.x, 56), title, 34, Look.GOLD)
		match pop.view:
			"main":
				var names := ["继续游戏", "存档", "读档", "再点一次就退出" if pop.armed == 99 else "退出游戏", "开局设置"]
				for i in names.size():
					_wide_button(hud._menu_button(i), names[i], i == 0)
				var iron: bool = hud.world.rules.ironman == "on"
				Look.text_center(self, Rect2(r.position.x, hud._menu_button(5).position.y + 10, r.size.x, 30),
						"铁人模式: 每半年和退出时自动存档, 不能自己存、读" if iron else "每年 1 月 1 日自动存一次档 (读档里叫「自动存档」)", 16, Look.TEXT_DIM, "sans")
			"save", "load":
				if pop.view == "save":
					_wide_button(Rect2(r.position + Vector2(495, 110), Vector2(175, 52)), "存新的档", true)
					Look.text(self, r.position + Vector2(30, 205), "或者盖掉一个旧存档 (点两次):", 17, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
				var saves: Array = pop.get("saves", [])
				if saves.is_empty():
					Look.text_center(self, Rect2(r.position.x, hud._menu_row(0).position.y + 10, r.size.x, 40), "还没有存档", 20, Look.TEXT_DIM, "sans")
				for i in saves.size():
					var s: Dictionary = saves[i]
					var rr := hud._menu_row(i)
					var armed: bool = pop.armed == i
					draw_rect(rr, Color(0.3, 0.1, 0.08) if armed else (Color(0.13, 0.12, 0.1) if hot(rr) else Color(0.09, 0.095, 0.11)))
					draw_rect(rr, Look.RED if armed else (Look.GOLD if hot(rr) else Color(Look.GOLD_DIM, 0.4)), false, 1.5)
					Look.text(self, rr.position + Vector2(16, 24), s.label + ("  (再点一次确定)" if armed else ""), 19, Look.RED if armed else Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 32, "sans")
					Look.text(self, rr.position + Vector2(16, 47), "%s · 游戏里 %s · 存于 %s" % [s.who, GameDate.text(s.day), s.saved_at.replace("T", " ").left(16)], 14, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 32, "sans")
				_wide_button(hud._menu_back(), "返回", false)

	# ---- 正中间的窗口: 你的孩子出生了, 给孩子起名 ----
	func _birth_popup() -> void:
		var w := hud.world
		var e: Dictionary = hud.popup.event
		var baby: Person = w.people[hud.popup.child]
		var mother: Person = w.people[e.mother]
		var r := BIRTH
		Look.panel(self, r, Color(0.07, 0.075, 0.09, 1.0))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 84)), Color(0.14, 0.2, 0.18, 0.7))
		var what := "女儿" if baby.female else "儿子"
		var title := "%s生了一个%s" % [mother.name, what]
		if e.children.size() == 2:
			title = "%s生了一对双胞胎" % mother.name
		Icons.draw(self, "cradle", r.position + Vector2(60, 42), 50, Look.GOLD)
		Look.text_center(self, Rect2(r.position.x, r.position.y + 14, r.size.x, 56), title, 34, Look.GOLD)
		var fr := Rect2(r.position + Vector2(40, 110), Vector2(Portrait.W, Portrait.H))
		draw_rect(fr.grow(2), Look.GOLD_DIM, false, 2.0)
		var lines := []
		if e.father != "":
			lines.append("父亲: %s    母亲: %s" % [w.people[e.father].name, mother.name])
		lines.append("算%s的人, 是%s" % [w.house_name(baby.house), baby.culture_name()])
		if e.mother_died:
			lines.append("%s生产时去世了。" % mother.name)
		for i in lines.size():
			var col := Look.RED if lines[i].ends_with("去世了。") else Look.TEXT
			Look.text(self, r.position + Vector2(190, 140 + i * 36), lines[i], 19, col, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 220, "sans")
		Look.text(self, r.position + Vector2(40, 314), "给%s起个名字: 点一个, 或者在下面自己写" % ("她" if baby.female else "他"), 18, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		var names: Array = hud.popup.names
		for i in names.size():
			var nr := hud._name_rect(i)
			_wide_button(nr, names[i], i == 0)
		Look.text(self, r.position + Vector2(40, 480), "自己起名 (最多 %d 个字; 什么都不写直接按回车, 就用第一个):" % NAME_MAX, 16, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		_wide_button(NAME_OK, "就叫这个", false)

	func _toast() -> void:
		if hud._toast_time <= 0.0:
			return
		var a := clampf(hud._toast_time, 0.0, 1.0)
		var f := Look.font("sans")
		var width := f.get_string_size(hud._toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 60
		var r := Rect2(960 - width / 2.0, 930, width, 50)
		draw_rect(r, Color(0.06, 0.065, 0.075, 0.92 * a))
		draw_rect(r, Color(Look.GOLD_DIM, a), false, 2.0)
		Look.text_center(self, r, hud._toast, 22, Color(Look.TEXT, a), "sans")
