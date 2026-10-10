class_name Hud
extends CanvasLayer
## 界面: 照三代的截图摆 (画面 1920×1080, 位置常量都是从三代 1920×1080 的截图上量的)。
## 只学摆法, 图标是自己用代码画的欧洲中世纪小图 (icons.gd), 不用原版的图和名字。还没做的按钮点了提示「以后才有」。

signal play_requested(realm_id: String)
signal mode_requested(mode: int)
signal close_requested

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
const BANNER := Rect2(560, 64, 800, 96)

# 右边一列: [图标, 颜色, 名字, 第几块做]
const MENU := [
	["crown", "8fcf7a", "领地", 5], ["swords", "e07060", "军队", 6], ["throne", "6fc4b0", "宫廷", 10],
	["council", "86a9e0", "议会", 9], ["intrigue", "d58fd0", "阴谋", 7], ["torch", "e0803a", "派系", 11],
	["quill", "e6dcc4", "生活方式", 12], ["chalice", "d9b44a", "宗教", 13], ["book", "9fb6c9", "文化", 14], ["tree", "6fa04a", "王朝", 16],
]
# 右上角: [图标, 颜色, 名字, 说明]
const RESOURCES := [
	["coins", "e8c860", "金钱", "收税、打仗、盖房子都要钱。第 5 块「封臣」做好了才有。"],
	["crown", "e0b850", "威望", "别人有多看得起你。第 3 块「家族和继承」做好了才有。"],
	["cross", "ece6d6", "虔诚", "你对信仰有多虔诚。第 13 块「宗教」做好了才有。"],
	["tree", "6fa04a", "名望", "整个王朝的名声。第 16 块「王朝传承」做好了才有。"],
	["helmet", "b8c0c8", "兵力", "能召集多少兵。第 6 块「打仗」做好了才有。"],
	["tower", "a8a090", "亲自管的领地", "自己亲手管几块领地 / 最多能管几块。第 5 块「封臣」做好了才有。"],
]

var world: World
var clock: Clock
var map: MapView
var player := ""       # 玩家的国家, 没选之前是空的
var county := 0        # 左边窗口在看的领地, 0 = 没开
var hover_index := 0   # 鼠标指着的地图上的领地
var show_help := false

var _root := Root.new()
var _spots: Array = []
var _hover_spot: Control
var _county_spots: Array = []
var _toast := ""
var _toast_time := 0.0


func _init(p_world: World, p_clock: Clock, p_map: MapView) -> void:
	world = p_world
	clock = p_clock
	map = p_map


func _ready() -> void:
	_root.hud = self
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_make_spots()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_root.queue_redraw()


func redraw() -> void:
	_root.queue_redraw()


func toast(text: String) -> void:
	_toast = text
	_toast_time = 3.0
	_root.queue_redraw()


func later(name: String, block: int) -> void:
	toast("「%s」以后才有 (看板上的第 %d 块)" % [name, block])


func show_county(index: int) -> void:
	county = index
	show_help = false
	for s in _county_spots:
		s.visible = true
	_root.queue_redraw()


func close_county() -> void:
	county = 0
	for s in _county_spots:
		s.visible = false
	_root.queue_redraw()


func set_map_hover(index: int) -> void:
	hover_index = index
	_root.queue_redraw()


func set_player(realm_id: String) -> void:
	player = realm_id
	_root.queue_redraw()


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
		_spot(Rect2(x, 0, w - 4, 44), "%s\n%s" % [r[2], r[3]], Callable())
	# 右边一列
	_spot(RIGHT_MENU, "", Callable())
	for i in MENU.size():
		var m: Array = MENU[i]
		_spot(Rect2(1878, RIGHT_MENU_Y[i] - 20, 42, 40), m[2], later.bind(m[2], m[3]))
	# 左下角
	_spot(PORTRAIT, "", Callable())
	var squares := [["生活重点", 12], ["信仰", 13], ["文化", 14]]
	for i in 3:
		_spot(Rect2(0, LEFT_SQUARES_Y[i] - 20, 45, 40), "你的" + squares[i][0], later.bind(squares[i][0], squares[i][1]))
	_spot(Rect2(5, 983, 54, 92), "你的主要头衔 (点一下看你的国家)", _focus_player)
	var bottom := [["家族", 3], ["压力", 2], ["召集军队", 6], ["决议", 8]]
	for i in 4:
		var c: Vector2 = BOTTOM_ROW[i][0]
		var r: float = BOTTOM_ROW[i][1]
		_spot(Rect2(c - Vector2(r, r), Vector2(r, r) * 2), bottom[i][0], later.bind(bottom[i][0], bottom[i][1]))
	# 右下角: 日期和速度
	_spot(DATE_BAR, "", Callable())
	_spot(Rect2(1330, 1042, 34, 36), "菜单 (存档、设置、退出)", _menu)
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
	var later_modes := [["地形", 15], ["文化", 14], ["宗教", 13], ["更多地图模式", 15]]
	for i in 4:
		_spot(Rect2(MODE_SMALL[i + 3] - Vector2(13, 13), Vector2(26, 26)), "地图模式: " + later_modes[i][0], later.bind("地图模式: " + later_modes[i][0], later_modes[i][1]))
	# 左边的领地窗口 (开着的时候才有)
	_spot(SIDE_PANEL, "", Callable(), _county_spots)
	_spot(Rect2(SIDE_PANEL.end.x - 52, 14, 38, 38), "关上 (Esc)", close_requested.emit, _county_spots)
	_spot(Rect2(40, 960, 480, 56), "", _play_this, _county_spots)
	_spot(Rect2(40, 890, 480, 50), "", _focus_holder, _county_spots)
	for s in _county_spots:
		s.visible = false


func _focus_player() -> void:
	if player == "":
		toast("先选一个国王")
		return
	_focus_realm(player)


func _focus_holder() -> void:
	if county:
		_focus_realm(world.county_at(county).holder)


func _focus_realm(realm_id: String) -> void:
	var cs := world.counties_of(realm_id)
	var box := Rect2(cs[0].rect)
	for c in cs:
		box = box.merge(Rect2(c.rect))
	var z := clampf(minf(1300.0 / box.size.x, 900.0 / box.size.y), MapView.ZOOM_MIN, 1.6)
	map.focus(box.get_center(), z)


func _play_this() -> void:
	if county and player == "":
		play_requested.emit(world.county_at(county).holder)


func _menu() -> void:
	toast("存档、设置以后才有。现在要退出就直接关窗口")


func _toggle_help() -> void:
	show_help = not show_help
	_root.queue_redraw()


func _toggle_pause() -> void:
	if player == "":
		toast("先在地图上点一块领地, 选一个国王来玩")
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
		if hud.player == "":
			_banner()
		if hud.county:
			_county_panel()
		if hud.show_help:
			_help()
		_map_tooltip()
		_toast()

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
			if hud.player == "":
				Look.text(self, Vector2(x + 40, 28), "—", 20, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
			else:
				Look.text(self, Vector2(x + 40, 24), "0", 20, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
				Look.text(self, Vector2(x + 40, 40), "+0.0", 13, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")

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

	# ---- 左下角 ----
	func _bottom_left() -> void:
		# 头像框: 上面是圆拱的窗户, 头像以后再画
		var r := PORTRAIT
		var arch := PackedVector2Array()
		var radius := r.size.x / 2.0
		var top := r.position.y + radius
		for k in range(0, 33):
			var a := PI + PI * k / 32.0
			arch.append(Vector2(r.get_center().x + cos(a) * radius, top + sin(a) * radius))
		arch.append(r.end)
		arch.append(Vector2(r.position.x, r.end.y))
		draw_colored_polygon(arch, Color(0.06, 0.065, 0.075, 0.9))
		var outline := arch.duplicate()
		outline.append(arch[0])
		draw_polyline(outline, Look.GOLD_DIM, 2.0, true)
		Look.text_center(self, Rect2(r.position.x, r.position.y + 40, r.size.x, 30), "(头像以后再画)", 15, Color(Look.TEXT_DIM, 0.55), "sans")
		if hud.player != "":
			var realm: Dictionary = hud.world.realms[hud.player]
			Look.text_center(self, Rect2(r.position.x, 878, r.size.x, 40), realm.ruler, 30, Look.TEXT)
			Look.text_center(self, Rect2(r.position.x, 918, r.size.x, 30), realm.title, 18, Look.TEXT_DIM)
		else:
			Look.text_center(self, Rect2(r.position.x, 890, r.size.x, 40), "还没选国王", 22, Look.TEXT_DIM)
		# 头像左边三个小方块
		var squares := [["candle", Icons.FLAME], ["cross", Icons.SILVER], ["banner", Color("4a78b0")]]
		for i in 3:
			var box := Rect2(0, LEFT_SQUARES_Y[i] - 20, 45, 40)
			Look.panel(self, box, Look.PANEL, false)
			draw_rect(box, Look.GOLD if hot(box) else Look.GOLD_DIM, false, 1.5)
			Icons.draw(self, squares[i][0], box.get_center(), 30, squares[i][1])
		# 主要头衔: 王冠 + 纹章盾
		Icons.draw(self, "crown", Vector2(33, 997), 40, Icons.GOLD)
		_shield(TITLE_SHIELD, hud.player)
		# 下面一排圆按钮: 家族、压力、召集军队、决议
		var labels := ["house", "bust", "swords", "decree"]
		for i in 4:
			var c: Vector2 = BOTTOM_ROW[i][0]
			var rad: float = BOTTOM_ROW[i][1]
			if i == 1:
				draw_rect(STRESS_BAR, Color(0.06, 0.065, 0.075, 0.95))
				draw_rect(STRESS_BAR, Look.GOLD_DIM, false, 1.5)
			Look.round_button(self, c, rad, labels[i], [Color("8a3a32"), Look.TEXT_DIM, Color("e0e4e8"), Icons.PARCHMENT][i], false, hot(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2)))

	## 国家的纹章盾; 还没选国王时是一面灰盾牌, 上面一个问号
	func _shield(r: Rect2, realm_id: String) -> void:
		if realm_id != "":
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
		var labels := ["coronet", "crown", "imperial_crown", "mountain", "book", "cross", "plus"]
		var modes := [MapView.Mode.DUCHY, MapView.Mode.KINGDOM, MapView.Mode.EMPIRE]
		for i in labels.size():
			var c: Vector2 = MODE_SMALL[i]
			var rad := 14.0 if i < 3 else 13.0
			var lit: bool = i < 3 and mode == modes[i]
			Look.round_button(self, c, rad, labels[i], Icons.GOLD if i < 3 else Look.TEXT_DIM, lit, hot(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2)))

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
		if paused and hud.player != "":
			var tag := Rect2(1600, 1006, 180, 32)
			Look.panel(self, tag, Look.PANEL)
			Look.text_center(self, tag, "已暂停 (按空格继续)", 16, Look.RED, "sans")

	# ---- 还没选国王: 上面的提示 ----
	func _banner() -> void:
		Look.panel(self, BANNER)
		Look.text_center(self, Rect2(BANNER.position.x, BANNER.position.y + 8, BANNER.size.x, 40), "867 年 1 月 1 日 · 不列颠群岛", 30, Look.GOLD)
		Look.text_center(self, Rect2(BANNER.position.x, BANNER.position.y + 50, BANNER.size.x, 34), "在地图上点一块领地, 选一个国王来玩", 22, Look.TEXT, "sans")

	# ---- 左边的领地窗口 ----
	func _county_panel() -> void:
		var w := hud.world
		var c := w.county_at(hud.county)
		var realm := w.realm_of(c)
		var r := SIDE_PANEL
		Look.panel(self, r, Color(0.07, 0.075, 0.09, 0.97))
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
		Look.text(self, Vector2(40, y), "主人", 20, Look.GOLD)
		Look.text(self, Vector2(40, y + 40), w.ruler_text(c.holder), 26, Look.TEXT)
		var mine := w.counties_of(c.holder)
		var area := 0
		for m in mine:
			area += m.area_km2
		Look.text(self, Vector2(40, y + 74), "这个国家有 %d 块领地, %d 平方公里" % [mine.size(), area], 18, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		if realm.random:
			Look.text(self, Vector2(40, y + 100), "(史料里查不到这时候是谁在管, 统治者是随机生成的)", 16, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		# 这块领地
		y = 360.0
		draw_line(Vector2(30, y - 30), Vector2(r.size.x - 30, y - 30), Color(Look.GOLD_DIM, 0.5), 1.0)
		Look.text(self, Vector2(40, y), "这块领地", 20, Look.GOLD)
		Look.text(self, Vector2(40, y + 34), "面积: %d 平方公里%s" % [c.area_km2, " · 靠海" if c.coastal else " · 不靠海"], 19, Look.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, "sans")
		var names := []
		for n in c.neighbors:
			names.append(w.by_id[n].name)
		var nb := "挨着: " + ("、".join(names) if not names.is_empty() else "没有 (是个岛)")
		draw_multiline_string(Look.font("sans"), Vector2(40, y + 68), nb, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 19, 4, Look.TEXT)
		# 同一个公国里的领地
		y = 560.0
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
		if hud.player == "":
			_wide_button(Rect2(40, 960, 480, 56), "玩这个人: %s" % realm.ruler, true)
		elif hud.player == c.holder:
			Look.text_center(self, Rect2(40, 960, 480, 56), "这是你的领地", 20, Look.GREEN, "sans")

	func _wide_button(r: Rect2, label: String, main: bool) -> void:
		var lit := hot(r)
		draw_rect(r, Color(0.2, 0.17, 0.11) if main else Color(0.11, 0.115, 0.13))
		draw_rect(r, Look.GOLD if lit or main else Look.GOLD_DIM, false, 2.0)
		Look.text_center(self, r, label, 24 if main else 20, Look.TEXT)

	# ---- 操作说明 ----
	func _help() -> void:
		var r := Rect2(560, 180, 800, 600)
		Look.panel(self, r)
		Look.text_center(self, Rect2(r.position.x, r.position.y + 14, r.size.x, 44), "操作说明", 30, Look.GOLD)
		var lines := [
			"鼠标左键点领地: 看这块领地 (左边弹出窗口)",
			"鼠标拖地图 (左键、右键、中键都行) 或者 W A S D / 方向键: 移动地图",
			"鼠标滚轮 (或者触控板两指捏): 放大缩小; 放大了能看到每块领地的名字",
			"空格: 暂停 / 继续      + -: 快一档 / 慢一档      1～5: 直接换速度",
			"右下角圆按钮: 换地图模式 (国家、公国、王国、帝国)",
			"左下角盾牌: 看你的国家      Esc: 关窗口      F1: 这个说明",
			"",
			"现在只做了第 1 块「地图和时间」: 人物、家族、结婚、封臣、打仗、阴谋",
			"这些还没有, 点那些按钮会提示「以后才有」。",
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
		var lines := [c.name, w.ruler_text(c.holder)]
		var r := Rect2(m + Vector2(22, 18), Vector2(320, 74))
		if r.end.x > 1900:
			r.position.x = m.x - 22 - r.size.x
		if r.end.y > 1070:
			r.position.y = m.y - 18 - r.size.y
		Look.panel(self, r, Color(0.06, 0.065, 0.075, 0.95))
		Look.text(self, r.position + Vector2(14, 30), lines[0], 22, Look.TEXT)
		Look.text(self, r.position + Vector2(14, 58), lines[1], 16, Look.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, "sans")

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
