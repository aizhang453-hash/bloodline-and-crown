class_name Icons
extends RefCounted
## 欧洲中世纪风格的小图标和纹章, 全用代码画 (不用原版的图, 也不用汉字当图标)。
## draw(画在哪, 图标名, 中心, 大小, 颜色): 大小是图标所在方块的边长。

const OUTLINE := Color(0.05, 0.04, 0.03, 0.85)
const STEEL := Color("d8dde2")
const GOLD := Color("d9b44a")
const SILVER := Color("ece6d6")
const SABLE := Color("2b2622")
const WOOD := Color("7a5332")
const PARCHMENT := Color("e6d6ae")
const WAX := Color("b23a2e")
const FLAME := Color("f0a030")
const FLAME_CORE := Color("fff0a0")

## 所有图标的名字 (测试用)
const NAMES := ["coins", "crown", "coronet", "imperial_crown", "cross", "tree", "helmet", "tower", "swords",
		"throne", "council", "intrigue", "torch", "quill", "chalice", "book", "candle", "banner", "bust",
		"decree", "house", "mountain", "plus"]


static func draw(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color) -> void:
	var t := Transform2D(0.0, Vector2(s, s), 0.0, c)
	match name:
		"coins":
			for k in 3:
				_ellipse(ci, t, Vector2(0, 0.26 - k * 0.17), Vector2(0.34, 0.13), col)
			_ellipse(ci, t, Vector2(0, -0.25), Vector2(0.34, 0.13), col.lightened(0.25))
		"crown":
			_crown(ci, t, col, 0)
		"coronet":
			_crown(ci, t, col, 1)
		"imperial_crown":
			_crown(ci, t, col, 2)
		"cross":
			_poly(ci, t, [Vector2(-0.08, -0.45), Vector2(0.08, -0.45), Vector2(0.08, -0.2), Vector2(0.28, -0.2),
					Vector2(0.28, -0.05), Vector2(0.08, -0.05), Vector2(0.08, 0.45), Vector2(-0.08, 0.45),
					Vector2(-0.08, -0.05), Vector2(-0.28, -0.05), Vector2(-0.28, -0.2), Vector2(-0.08, -0.2)], col)
		"tree":
			_poly(ci, t, [Vector2(-0.07, 0.05), Vector2(0.07, 0.05), Vector2(0.1, 0.45), Vector2(-0.1, 0.45)], WOOD)
			_circle(ci, t, Vector2(-0.19, 0.0), 0.19, col.darkened(0.15))
			_circle(ci, t, Vector2(0.19, 0.0), 0.19, col.darkened(0.15))
			_circle(ci, t, Vector2(0, -0.17), 0.26, col)
		"helmet":
			var dome := [Vector2(-0.3, 0.32)]
			for k in 17:
				var a := PI + PI * k / 16.0
				dome.append(Vector2(cos(a) * 0.3, -0.02 + sin(a) * 0.36))
			dome.append(Vector2(0.3, 0.32))
			_poly(ci, t, dome, col)
			_line(ci, t, Vector2(-0.24, 0.1), Vector2(-0.06, 0.1), OUTLINE, 0.06)
			_line(ci, t, Vector2(0.06, 0.1), Vector2(0.24, 0.1), OUTLINE, 0.06)
			_line(ci, t, Vector2(0, -0.05), Vector2(0, 0.36), col.darkened(0.35), 0.08)
		"tower":
			_poly(ci, t, [Vector2(-0.28, -0.22), Vector2(0.28, -0.22), Vector2(0.28, 0.45), Vector2(-0.28, 0.45)], col)
			for x in [-0.28, -0.07, 0.14]:
				_poly(ci, t, [Vector2(x, -0.4), Vector2(x + 0.14, -0.4), Vector2(x + 0.14, -0.21), Vector2(x, -0.21)], col)
			_arch(ci, t, Vector2(0, 0.45), 0.1, 0.22, OUTLINE)
			_line(ci, t, Vector2(0, -0.1), Vector2(0, 0.05), OUTLINE, 0.05)
		"swords":
			for sign in [-1.0, 1.0]:
				var tip := Vector2(0.36 * sign, -0.38)
				var hilt := Vector2(-0.22 * sign, 0.24)
				_line(ci, t, hilt, tip, STEEL, 0.08)
				var dir := (tip - hilt).normalized()
				var side := Vector2(-dir.y, dir.x)
				_line(ci, t, hilt - side * 0.13, hilt + side * 0.13, col, 0.07)
				_line(ci, t, hilt, hilt - dir * 0.16, WOOD, 0.07)
				_circle(ci, t, hilt - dir * 0.2, 0.05, col)
		"throne":
			_poly(ci, t, [Vector2(-0.22, 0.08), Vector2(-0.22, -0.32), Vector2(0, -0.46), Vector2(0.22, -0.32), Vector2(0.22, 0.08)], col)
			_poly(ci, t, [Vector2(-0.13, 0.02), Vector2(-0.13, -0.26), Vector2(0, -0.34), Vector2(0.13, -0.26), Vector2(0.13, 0.02)], WAX)
			_poly(ci, t, [Vector2(-0.32, 0.04), Vector2(0.32, 0.04), Vector2(0.32, 0.18), Vector2(-0.32, 0.18)], col.darkened(0.15))
			_line(ci, t, Vector2(-0.27, 0.18), Vector2(-0.27, 0.45), col.darkened(0.15), 0.08)
			_line(ci, t, Vector2(0.27, 0.18), Vector2(0.27, 0.45), col.darkened(0.15), 0.08)
		"council":
			for x in [-0.25, 0.25]:
				_half_ellipse(ci, t, Vector2(x, 0.42), Vector2(0.17, 0.26), col.darkened(0.25))
				_circle(ci, t, Vector2(x, -0.08), 0.11, col.darkened(0.25))
			_half_ellipse(ci, t, Vector2(0, 0.46), Vector2(0.22, 0.3), col)
			_circle(ci, t, Vector2(0, -0.14), 0.14, col)
		"intrigue":
			_scroll(ci, t, Rect2(-0.34, -0.3, 0.46, 0.62), PARCHMENT)
			_line(ci, t, Vector2(-0.2, 0.32), Vector2(0.3, -0.36), STEEL, 0.07)
			_line(ci, t, Vector2(-0.1, 0.12), Vector2(0.02, 0.24), col, 0.07)
			_line(ci, t, Vector2(-0.2, 0.32), Vector2(-0.3, 0.44), col.darkened(0.3), 0.07)
		"torch":
			_poly(ci, t, [Vector2(-0.07, -0.02), Vector2(0.07, -0.02), Vector2(0.05, 0.46), Vector2(-0.05, 0.46)], WOOD)
			_poly(ci, t, [Vector2(0, -0.48), Vector2(0.19, -0.22), Vector2(0.16, -0.03), Vector2(0, 0.04), Vector2(-0.16, -0.03), Vector2(-0.19, -0.22)], col)
			_poly(ci, t, [Vector2(0, -0.3), Vector2(0.08, -0.15), Vector2(0, -0.04), Vector2(-0.08, -0.15)], FLAME_CORE, false)
		"quill":
			var pts := []
			var other := []
			var a := Vector2(0.34, -0.44)
			var b := Vector2(-0.18, 0.28)
			var n := (b - a).normalized()
			var side := Vector2(-n.y, n.x)
			for k in 11:
				var f := k / 10.0
				var w := sin(PI * f) * (0.15 if f < 0.6 else 0.11)
				pts.append(a.lerp(b, f) + side * w)
				other.push_front(a.lerp(b, f) - side * w * 0.7)
			_poly(ci, t, pts + other, col)
			_line(ci, t, a + n * 0.05, Vector2(-0.32, 0.46), col.darkened(0.4), 0.04)
		"chalice":
			_poly(ci, t, [Vector2(-0.28, -0.4), Vector2(0.28, -0.4), Vector2(0.22, -0.16), Vector2(0.07, -0.03), Vector2(-0.07, -0.03), Vector2(-0.22, -0.16)], col)
			_poly(ci, t, [Vector2(-0.05, -0.04), Vector2(0.05, -0.04), Vector2(0.05, 0.28), Vector2(-0.05, 0.28)], col.darkened(0.15))
			_poly(ci, t, [Vector2(-0.12, 0.27), Vector2(0.12, 0.27), Vector2(0.25, 0.43), Vector2(-0.25, 0.43)], col)
		"book":
			_poly(ci, t, [Vector2(-0.44, -0.26), Vector2(-0.02, -0.18), Vector2(-0.02, 0.36), Vector2(-0.44, 0.28)], PARCHMENT)
			_poly(ci, t, [Vector2(0.44, -0.26), Vector2(0.02, -0.18), Vector2(0.02, 0.36), Vector2(0.44, 0.28)], PARCHMENT)
			for k in 3:
				var y := -0.08 + k * 0.12
				_line(ci, t, Vector2(-0.36, y), Vector2(-0.1, y + 0.04), col.darkened(0.2), 0.03)
				_line(ci, t, Vector2(0.1, y + 0.04), Vector2(0.36, y), col.darkened(0.2), 0.03)
			_line(ci, t, Vector2(0, -0.2), Vector2(0, 0.38), col, 0.06)
		"candle":
			_ellipse(ci, t, Vector2(0, 0.4), Vector2(0.28, 0.08), col.darkened(0.3))
			_poly(ci, t, [Vector2(-0.12, -0.1), Vector2(0.12, -0.1), Vector2(0.12, 0.38), Vector2(-0.12, 0.38)], SILVER)
			_poly(ci, t, [Vector2(0, -0.46), Vector2(0.1, -0.26), Vector2(0, -0.14), Vector2(-0.1, -0.26)], col)
		"banner":
			_line(ci, t, Vector2(-0.3, -0.46), Vector2(-0.3, 0.46), WOOD, 0.07)
			_poly(ci, t, [Vector2(-0.27, -0.4), Vector2(0.38, -0.4), Vector2(0.24, -0.15), Vector2(0.38, 0.1), Vector2(-0.27, 0.1)], col)
			_circle(ci, t, Vector2(-0.3, -0.46), 0.05, GOLD)
		"bust":
			_half_ellipse(ci, t, Vector2(0, 0.46), Vector2(0.34, 0.3), col)
			_circle(ci, t, Vector2(0, -0.14), 0.2, col)
		"decree":
			_scroll(ci, t, Rect2(-0.3, -0.34, 0.6, 0.66), PARCHMENT)
			for k in 3:
				_line(ci, t, Vector2(-0.18, -0.16 + k * 0.12), Vector2(0.18, -0.16 + k * 0.12), Color(0.35, 0.28, 0.2), 0.03)
			_circle(ci, t, Vector2(0.12, 0.22), 0.1, WAX)
		"house":
			var r := Rect2(c - Vector2(s, s) * 0.36, Vector2(s, s) * 0.72)
			arms(ci, r, 2, col, GOLD)
		"mountain":
			_poly(ci, t, [Vector2(-0.46, 0.36), Vector2(-0.12, -0.3), Vector2(0.08, 0.02), Vector2(0.22, -0.16), Vector2(0.46, 0.36)], col)
			_poly(ci, t, [Vector2(-0.12, -0.3), Vector2(0.0, -0.07), Vector2(-0.07, -0.1), Vector2(-0.12, -0.04), Vector2(-0.2, -0.14)], SILVER, false)
		"plus":
			_line(ci, t, Vector2(-0.3, 0), Vector2(0.3, 0), col, 0.1)
			_line(ci, t, Vector2(0, -0.3), Vector2(0, 0.3), col, 0.1)
		_:
			push_error("没有这个图标: " + name)


# ---- 纹章 (盾牌上的图案): 底色 + 一种图案 ----

const DESIGNS := 9


## 盾牌的形状 (上面平, 下面尖)
static func shield_points(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y)])
	var left := PackedVector2Array()
	for k in range(0, 13):
		var f := k / 12.0
		var a := Vector2(r.end.x, r.position.y + r.size.y * 0.5)
		var b := Vector2(r.end.x, r.position.y + r.size.y * 0.85)
		var c := Vector2(r.get_center().x, r.end.y)
		pts.append(a.lerp(b, f).lerp(b.lerp(c, f), f))
	for k in range(1, 13):
		var f := k / 12.0
		var a := Vector2(r.get_center().x, r.end.y)
		var b := Vector2(r.position.x, r.position.y + r.size.y * 0.85)
		var c := Vector2(r.position.x, r.position.y + r.size.y * 0.5)
		left.append(a.lerp(b, f).lerp(b.lerp(c, f), f))
	pts.append_array(left)
	return pts


## 画一面纹章盾: design 是第几种图案 (十字、斜十字、人字纹、横带、竖带、斜带、四分、半分、镶边)
static func arms(ci: CanvasItem, r: Rect2, design: int, field: Color, metal: Color) -> void:
	var shape := shield_points(r)
	ci.draw_colored_polygon(shape, field)
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	var band := w * 0.22
	var cx := r.get_center().x
	var charge: Array = []
	match design % DESIGNS:
		0:  # 十字
			charge = [_rect_pts(cx - band / 2, y0, band, h), _rect_pts(x0, y0 + h * 0.38 - band / 2, w, band)]
		1:  # 斜十字
			charge = [_band(Vector2(x0, y0), Vector2(r.end.x, r.end.y), band), _band(Vector2(r.end.x, y0), Vector2(x0, r.end.y), band)]
		2:  # 人字纹
			var top := y0 + h * 0.3
			var low := y0 + h * 0.72
			charge = [PackedVector2Array([Vector2(x0, low), Vector2(cx, top), Vector2(r.end.x, low),
					Vector2(r.end.x, low + band), Vector2(cx, top + band), Vector2(x0, low + band)])]
		3:  # 横带
			charge = [_rect_pts(x0, y0 + h * 0.36, w, h * 0.24)]
		4:  # 竖带
			charge = [_rect_pts(cx - w * 0.16, y0, w * 0.32, h)]
		5:  # 斜带
			charge = [_band(Vector2(x0, y0), Vector2(r.end.x, y0 + w), band * 1.2)]
		6:  # 四分
			charge = [_rect_pts(cx, y0, w / 2, h * 0.45), _rect_pts(x0, y0 + h * 0.45, w / 2, h)]
		7:  # 半分 (右边一半)
			charge = [_rect_pts(cx, y0, w / 2, h)]
		8:  # 镶边
			var inner := Geometry2D.offset_polygon(shape, -w * 0.12)
			ci.draw_colored_polygon(shape, metal)
			if not inner.is_empty():
				ci.draw_colored_polygon(inner[0], field)
	for piece in charge:
		for clipped in Geometry2D.intersect_polygons(shape, piece):
			ci.draw_colored_polygon(clipped, metal)
	var outline := shape.duplicate()
	outline.append(shape[0])
	ci.draw_polyline(outline, Color("d9c08a"), maxf(1.5, w * 0.035), true)


## 这个国家用哪种图案、什么金属色 (按国家的编号固定下来)
static func realm_arms(ci: CanvasItem, r: Rect2, realm: Dictionary) -> void:
	var i: int = realm.index
	arms(ci, r, i % DESIGNS, realm.color, charge_color(realm.color, i))


## 图案的颜色: 金或银轮着用; 底色太浅 (跟金银分不清) 就用深色
static func charge_color(field: Color, i: int) -> Color:
	if field.get_luminance() > 0.5:
		return SABLE
	return GOLD if (i / DESIGNS) % 2 == 0 else SILVER


# ---- 画图用的小工具 (坐标是 -0.5 到 0.5 的方块里) ----

static func _poly(ci: CanvasItem, t: Transform2D, pts: Array, col: Color, outline := true) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(t * v)
	ci.draw_colored_polygon(p, col)
	if outline:
		p.append(p[0])
		ci.draw_polyline(p, OUTLINE, maxf(1.0, t.get_scale().x * 0.035), true)


static func _line(ci: CanvasItem, t: Transform2D, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	ci.draw_line(t * a, t * b, col, maxf(1.0, t.get_scale().x * width), true)


static func _circle(ci: CanvasItem, t: Transform2D, c: Vector2, r: float, col: Color) -> void:
	var s := t.get_scale().x
	ci.draw_circle(t * c, r * s, col)
	ci.draw_arc(t * c, r * s, 0, TAU, 24, OUTLINE, maxf(1.0, s * 0.035), true)


static func _ellipse(ci: CanvasItem, t: Transform2D, c: Vector2, radius: Vector2, col: Color) -> void:
	var pts := []
	for k in 20:
		var a := TAU * k / 20.0
		pts.append(c + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	_poly(ci, t, pts, col)


## 上半个椭圆 (人的肩膀)
static func _half_ellipse(ci: CanvasItem, t: Transform2D, c: Vector2, radius: Vector2, col: Color) -> void:
	var pts := []
	for k in 17:
		var a := PI + PI * k / 16.0
		pts.append(c + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	_poly(ci, t, pts, col)


## 拱门 (门洞)
static func _arch(ci: CanvasItem, t: Transform2D, bottom: Vector2, half_w: float, h: float, col: Color) -> void:
	var pts := [bottom + Vector2(-half_w, 0)]
	for k in 9:
		var a := PI + PI * k / 8.0
		pts.append(bottom + Vector2(cos(a) * half_w, -h + half_w + sin(a) * half_w))
	pts.append(bottom + Vector2(half_w, 0))
	_poly(ci, t, pts, col, false)


## 卷轴: 一张羊皮纸, 上下卷起来
static func _scroll(ci: CanvasItem, t: Transform2D, r: Rect2, col: Color) -> void:
	_poly(ci, t, [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)], col)
	_ellipse(ci, t, Vector2(r.get_center().x, r.position.y), Vector2(r.size.x * 0.56, 0.06), col.darkened(0.15))
	_ellipse(ci, t, Vector2(r.get_center().x, r.end.y), Vector2(r.size.x * 0.56, 0.06), col.darkened(0.15))


static func _rect_pts(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


## 从 a 到 b 的一条带子
static func _band(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var n := (b - a).normalized()
	var side := Vector2(-n.y, n.x) * width / 2.0
	a -= n * width
	b += n * width
	return PackedVector2Array([a + side, b + side, b - side, a - side])


static func _crown(ci: CanvasItem, t: Transform2D, col: Color, kind: int) -> void:
	var band_top := 0.12
	if kind == 1:  # 公爵的小冠: 矮, 三片叶子
		_poly(ci, t, [Vector2(-0.4, 0.3), Vector2(-0.4, 0.05), Vector2(0.4, 0.05), Vector2(0.4, 0.3)], col)
		for x in [-0.26, 0.0, 0.26]:
			_poly(ci, t, [Vector2(x - 0.1, 0.06), Vector2(x, -0.16), Vector2(x + 0.1, 0.06)], col)
		band_top = 0.05
	else:
		_poly(ci, t, [Vector2(-0.42, 0.32), Vector2(-0.42, -0.2), Vector2(-0.22, 0.02), Vector2(0, -0.3),
				Vector2(0.22, 0.02), Vector2(0.42, -0.2), Vector2(0.42, 0.32)], col)
		for p in [Vector2(-0.42, -0.24), Vector2(0, -0.34), Vector2(0.42, -0.24)]:
			_circle(ci, t, p, 0.06, col.lightened(0.3))
		if kind == 2:  # 皇冠: 上面一道拱, 顶上一个十字
			var arc := []
			for k in 9:
				var a := PI + PI * k / 8.0
				arc.append(Vector2(cos(a) * 0.3, -0.1 + sin(a) * 0.28))
			for k in 8:
				_line(ci, t, arc[k], arc[k + 1], col.darkened(0.2), 0.06)
			_line(ci, t, Vector2(0, -0.38), Vector2(0, -0.5), col, 0.06)
			_line(ci, t, Vector2(-0.06, -0.45), Vector2(0.06, -0.45), col, 0.06)
	_line(ci, t, Vector2(-0.38, band_top + 0.1), Vector2(0.38, band_top + 0.1), WAX, 0.06)
