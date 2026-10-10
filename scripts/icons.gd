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
			if not _pictogram(ci, name, t, col):
				push_error("没有这个图标: " + name)


# ---- 特点和本事的小图标 (第 2 块): 带底色的小方牌 + 里面一个小图画 ----

const INK := Color("eadfc4")  # 小图画的颜色 (羊皮纸色)
const BADGE := {
	"personality": [Color("4a3b28"), Color("b8955a")],
	"good": [Color("27432a"), Color("8fbf6a")],
	"bad": [Color("4a2424"), Color("c06a5a")],
	"education": [Color("24344a"), Color("7fa0c8")],
	"skill": [Color("2a2c33"), Color("8a7a5a")],
}
const SKILL_ICONS := {
	"diplomacy": "decree", "martial": "swords", "stewardship": "coins",
	"intrigue": "p_dagger", "learning": "book", "prowess": "p_round_shield",
}


## 画一个特点的图标。what: 性格或天生特点的 id, 或者教育 {skill, level}
static func trait_icon(ci: CanvasItem, what: Variant, c: Vector2, size: float) -> void:
	if what is Dictionary:
		_badge(ci, "education", c, size)
		draw(ci, SKILL_ICONS[what.skill], c + Vector2(0, -size * 0.06), size * 0.62, INK)
		_pips(ci, c, size, int(what.level), Color("a8c8f0"))
		return
	var info := Traits.get_trait(what)
	if info.get("kind", "") == "personality":
		_badge(ci, "personality", c, size)
		draw(ci, "p_" + String(what), c, size * 0.72, INK)
		return
	var good: bool = info.get("good", false)
	_badge(ci, "good" if good else "bad", c, size)
	var id := String(what)
	var level := 0
	for g in ["intellect", "beauty", "physique"]:
		if id.begins_with(g + "_"):
			level = int(id.right(1))
			id = id.left(id.length() - 2)  # intellect_good_2 -> intellect_good
	draw(ci, "p_" + id, c + Vector2(0, -size * (0.06 if level else 0.0)), size * (0.62 if level else 0.72), INK)
	if level:
		_pips(ci, c, size, level, Color("d9e8a0") if good else Color("f0a090"))


## 本事的图标 (六种本事一排时用)
static func skill_icon(ci: CanvasItem, skill: String, c: Vector2, size: float) -> void:
	_badge(ci, "skill", c, size)
	draw(ci, SKILL_ICONS[skill], c, size * 0.7, INK)


## 小方牌: 切掉四个角的方块
static func _badge(ci: CanvasItem, kind: String, c: Vector2, size: float) -> void:
	var h := size / 2.0
	var k := size * 0.16
	var pts := PackedVector2Array([
		c + Vector2(-h + k, -h), c + Vector2(h - k, -h), c + Vector2(h, -h + k), c + Vector2(h, h - k),
		c + Vector2(h - k, h), c + Vector2(-h + k, h), c + Vector2(-h, h - k), c + Vector2(-h, -h + k)])
	ci.draw_colored_polygon(pts, BADGE[kind][0])
	pts.append(pts[0])
	ci.draw_polyline(pts, BADGE[kind][1], maxf(1.0, size * 0.05), true)


## 底下一排小圆点表示第几档
static func _pips(ci: CanvasItem, c: Vector2, size: float, n: int, col: Color) -> void:
	var gap := size * 0.17
	for i in n:
		var x := c.x + (i - (n - 1) / 2.0) * gap
		ci.draw_circle(Vector2(x, c.y + size * 0.36), size * 0.055, col)


## 特点的小图画 (名字都以 p_ 开头)
static func _pictogram(ci: CanvasItem, name: String, t: Transform2D, col: Color) -> bool:
	match name:
		"p_brave":  # 竖起来的剑
			_poly(ci, t, [Vector2(-0.05, -0.36), Vector2(0, -0.48), Vector2(0.05, -0.36), Vector2(0.05, 0.12), Vector2(-0.05, 0.12)], STEEL)
			_line(ci, t, Vector2(-0.22, 0.13), Vector2(0.22, 0.13), col, 0.07)
			_line(ci, t, Vector2(0, 0.14), Vector2(0, 0.36), WOOD, 0.07)
			_circle(ci, t, Vector2(0, 0.41), 0.06, col)
		"p_craven":  # 白旗
			draw(ci, "banner", t.origin, t.get_scale().x, Color("f4f0e6"))
		"p_calm":  # 水面上的夕阳
			_half_ellipse(ci, t, Vector2(0, 0.06), Vector2(0.26, 0.26), Color("e8b860"))
			for k in 3:
				_line(ci, t, Vector2(-0.38 + k * 0.08, 0.16 + k * 0.12), Vector2(0.38 - k * 0.08, 0.16 + k * 0.12), Color("8fb8d8"), 0.05)
		"p_wrathful":  # 火
			_poly(ci, t, [Vector2(0, -0.46), Vector2(0.14, -0.22), Vector2(0.24, -0.3), Vector2(0.24, 0.08), Vector2(0.12, 0.32), Vector2(-0.12, 0.32), Vector2(-0.24, 0.08), Vector2(-0.2, -0.16), Vector2(-0.08, -0.08)], Color("e06a30"))
			_poly(ci, t, [Vector2(0, -0.12), Vector2(0.1, 0.08), Vector2(0.06, 0.24), Vector2(-0.06, 0.24), Vector2(-0.1, 0.08)], FLAME_CORE, false)
		"p_chaste":  # 百合花
			_line(ci, t, Vector2(0, 0.05), Vector2(0, 0.46), Color("6aa060"), 0.05)
			_poly(ci, t, [Vector2(0, -0.44), Vector2(0.09, -0.16), Vector2(0, 0.06), Vector2(-0.09, -0.16)], col)
			_poly(ci, t, [Vector2(-0.36, -0.28), Vector2(-0.06, -0.06), Vector2(-0.08, 0.08), Vector2(-0.26, -0.02)], col)
			_poly(ci, t, [Vector2(0.36, -0.28), Vector2(0.06, -0.06), Vector2(0.08, 0.08), Vector2(0.26, -0.02)], col)
		"p_lustful", "p_compassionate":  # 红心 (仁慈的心上有个白十字)
			var pts := []
			for k in 24:
				var a := TAU * k / 24.0
				pts.append(Vector2(16 * pow(sin(a), 3), -(13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a))) * 0.025 + Vector2(0, -0.02))
			_poly(ci, t, pts, Color("c83a3a") if name == "p_lustful" else Color("e07a8a"))
			if name == "p_compassionate":
				_line(ci, t, Vector2(0, -0.14), Vector2(0, 0.12), Color("fff4ec"), 0.06)
				_line(ci, t, Vector2(-0.11, -0.03), Vector2(0.11, -0.03), Color("fff4ec"), 0.06)
		"p_content":  # 小屋
			_poly(ci, t, [Vector2(-0.28, -0.04), Vector2(0.28, -0.04), Vector2(0.28, 0.4), Vector2(-0.28, 0.4)], col)
			_poly(ci, t, [Vector2(-0.4, 0.0), Vector2(0, -0.38), Vector2(0.4, 0.0)], Color("a0522d"))
			_poly(ci, t, [Vector2(-0.07, 0.16), Vector2(0.07, 0.16), Vector2(0.07, 0.4), Vector2(-0.07, 0.4)], WOOD, false)
		"p_ambitious":  # 王冠上一个往上的箭头
			_crown(ci, Transform2D(0.0, t.get_scale() * 0.62, 0.0, t * Vector2(0, 0.2)), GOLD, 0)
			_line(ci, t, Vector2(0, -0.02), Vector2(0, -0.42), col, 0.07)
			_poly(ci, t, [Vector2(-0.13, -0.3), Vector2(0, -0.48), Vector2(0.13, -0.3)], col)
		"p_diligent":  # 锤子
			_line(ci, t, Vector2(-0.28, 0.38), Vector2(0.12, -0.08), WOOD, 0.09)
			_poly(ci, t, [Vector2(-0.02, -0.3), Vector2(0.14, -0.44), Vector2(0.38, -0.18), Vector2(0.22, -0.04)], STEEL)
		"p_lazy":  # 月亮和星星 (睡觉)
			var moon := []
			for k in 13:
				var a := deg_to_rad(70 + k * 18.0)
				moon.append(Vector2(cos(a), sin(a)) * 0.34 + Vector2(0.04, 0))
			for k in 13:
				var a := deg_to_rad(286 - k * 18.0)
				moon.append(Vector2(cos(a), sin(a)) * 0.27 + Vector2(0.16, -0.03))
			_poly(ci, t, moon, Color("e8d890"))
			_circle(ci, t, Vector2(0.28, -0.3), 0.04, col)
			_circle(ci, t, Vector2(0.36, 0.06), 0.03, col)
		"p_forgiving":  # 鸽子
			_ellipse(ci, t, Vector2(0, 0.06), Vector2(0.3, 0.16), Color("f4f0e6"))
			_poly(ci, t, [Vector2(-0.12, 0.0), Vector2(0.1, -0.42), Vector2(0.16, -0.02)], Color("f4f0e6"))
			_circle(ci, t, Vector2(0.3, -0.06), 0.1, Color("f4f0e6"))
			_poly(ci, t, [Vector2(0.38, -0.08), Vector2(0.48, -0.04), Vector2(0.38, -0.01)], GOLD, false)
			_poly(ci, t, [Vector2(-0.3, 0.06), Vector2(-0.48, -0.06), Vector2(-0.46, 0.16)], Color("f4f0e6"))
		"p_vengeful", "p_dagger":  # 匕首 (记仇的带一滴血)
			_poly(ci, t, [Vector2(-0.05, -0.1), Vector2(0.05, -0.1), Vector2(0.04, 0.34), Vector2(0, 0.46), Vector2(-0.04, 0.34)], STEEL)
			_line(ci, t, Vector2(-0.2, -0.12), Vector2(0.2, -0.12), GOLD, 0.07)
			_line(ci, t, Vector2(0, -0.14), Vector2(0, -0.36), WOOD, 0.08)
			_circle(ci, t, Vector2(0, -0.41), 0.06, GOLD)
			if name == "p_vengeful":
				_poly(ci, t, [Vector2(0.22, 0.14), Vector2(0.28, 0.28), Vector2(0.22, 0.34), Vector2(0.16, 0.28)], WAX)
		"p_generous":  # 打开的钱袋, 钱往外掉
			_scroll_sack(ci, t, Vector2(-0.08, 0.06), col)
			for v in [Vector2(0.26, -0.2), Vector2(0.34, 0.06), Vector2(0.24, 0.3)]:
				_ellipse(ci, t, v, Vector2(0.08, 0.05), GOLD)
		"p_greedy":  # 扎紧的钱袋和一堆钱
			_scroll_sack(ci, t, Vector2(-0.1, 0.04), col)
			for k in 3:
				_ellipse(ci, t, Vector2(0.26, 0.36 - k * 0.08), Vector2(0.14, 0.05), GOLD)
		"p_gregarious":  # 两个杯子碰在一起
			for sign in [-1.0, 1.0]:
				var o := Vector2(sign * 0.17, 0)
				_poly(ci, t, [o + Vector2(-0.14, -0.3), o + Vector2(0.14, -0.3), o + Vector2(0.1, 0.0), o + Vector2(-0.1, 0.0)], GOLD)
				_line(ci, t, o + Vector2(0, 0.0), o + Vector2(0, 0.3), GOLD, 0.06)
				_line(ci, t, o + Vector2(-0.1, 0.32), o + Vector2(0.1, 0.32), GOLD, 0.06)
		"p_shy":  # 戴兜帽、低着头的人
			_poly(ci, t, [Vector2(-0.34, 0.46), Vector2(-0.26, -0.1), Vector2(0, -0.42), Vector2(0.26, -0.1), Vector2(0.34, 0.46)], Color("7a6a58"))
			_ellipse(ci, t, Vector2(0, -0.04), Vector2(0.13, 0.17), Color("2a221c"))
		"p_honest":  # 太阳
			for k in 8:
				var a := TAU * k / 8.0
				_line(ci, t, Vector2(cos(a), sin(a)) * 0.26, Vector2(cos(a), sin(a)) * 0.44, Color("f0c850"), 0.06)
			_circle(ci, t, Vector2.ZERO, 0.2, Color("f0c850"))
		"p_deceitful":  # 面具
			_poly(ci, t, [Vector2(-0.38, -0.26), Vector2(0.38, -0.26), Vector2(0.34, 0.06), Vector2(0.12, 0.34), Vector2(-0.12, 0.34), Vector2(-0.34, 0.06)], Color("f4f0e6"))
			_ellipse(ci, t, Vector2(-0.15, -0.06), Vector2(0.1, 0.06), Color("2a221c"))
			_ellipse(ci, t, Vector2(0.15, -0.06), Vector2(0.1, 0.06), Color("2a221c"))
			_line(ci, t, Vector2(-0.38, -0.2), Vector2(-0.48, -0.36), WAX, 0.04)
		"p_humble":  # 麦穗
			_line(ci, t, Vector2(0, -0.3), Vector2(0, 0.46), Color("c8a040"), 0.05)
			for k in 4:
				var y := -0.36 + k * 0.14
				_ellipse(ci, t, Vector2(-0.08, y), Vector2(0.07, 0.1), Color("e0b850"))
				_ellipse(ci, t, Vector2(0.08, y + 0.07), Vector2(0.07, 0.1), Color("e0b850"))
		"p_arrogant":  # 孔雀羽毛
			draw(ci, "quill", t.origin, t.get_scale().x, Color("3a8a6a"))
			_circle(ci, t, Vector2(0.16, -0.2), 0.11, Color("2a5aa0"))
			_circle(ci, t, Vector2(0.16, -0.2), 0.05, Color("e8c040"))
		"p_just":  # 天平
			_line(ci, t, Vector2(0, -0.4), Vector2(0, 0.36), GOLD, 0.06)
			_line(ci, t, Vector2(-0.32, -0.3), Vector2(0.32, -0.3), GOLD, 0.06)
			_line(ci, t, Vector2(-0.18, 0.4), Vector2(0.18, 0.4), GOLD, 0.07)
			for x in [-0.32, 0.32]:
				_line(ci, t, Vector2(x, -0.3), Vector2(x - 0.12, 0.04), col, 0.03)
				_line(ci, t, Vector2(x, -0.3), Vector2(x + 0.12, 0.04), col, 0.03)
				_half_ellipse(ci, t, Vector2(x, 0.04), Vector2(0.14, -0.1), GOLD)
		"p_arbitrary":  # 两个骰子
			for d in [[Vector2(-0.16, 0.06), 2], [Vector2(0.18, -0.12), 5]]:
				var o: Vector2 = d[0]
				_poly(ci, t, [o + Vector2(-0.16, -0.16), o + Vector2(0.16, -0.16), o + Vector2(0.16, 0.16), o + Vector2(-0.16, 0.16)], Color("f4f0e6"))
				var spots: Array = [Vector2(-0.08, -0.08), Vector2(0.08, 0.08)] if d[1] == 2 else [Vector2(-0.08, -0.08), Vector2(0.08, -0.08), Vector2(0, 0), Vector2(-0.08, 0.08), Vector2(0.08, 0.08)]
				for sp in spots:
					_circle(ci, t, o + sp, 0.025, Color("2a221c"))
		"p_patient", "p_impatient":  # 沙漏 (急躁的漏得飞快, 裂了)
			_line(ci, t, Vector2(-0.24, -0.4), Vector2(0.24, -0.4), WOOD, 0.07)
			_line(ci, t, Vector2(-0.24, 0.4), Vector2(0.24, 0.4), WOOD, 0.07)
			_poly(ci, t, [Vector2(-0.18, -0.36), Vector2(0.18, -0.36), Vector2(0.03, 0.0), Vector2(0.18, 0.36), Vector2(-0.18, 0.36), Vector2(-0.03, 0.0)], Color(0.85, 0.88, 0.9, 0.5))
			_poly(ci, t, [Vector2(-0.12, 0.36), Vector2(0.12, 0.36), Vector2(0.0, 0.2)], Color("e0c070"), false)
			_poly(ci, t, [Vector2(-0.1, -0.22), Vector2(0.1, -0.22), Vector2(0.0, -0.06)], Color("e0c070"), false)
			if name == "p_impatient":
				_line(ci, t, Vector2(0.06, -0.3), Vector2(0.16, -0.1), WAX, 0.04)
				_line(ci, t, Vector2(0.16, -0.1), Vector2(0.08, 0.04), WAX, 0.04)
		"p_temperate":  # 一杯清水
			_poly(ci, t, [Vector2(-0.22, -0.3), Vector2(0.22, -0.3), Vector2(0.16, 0.4), Vector2(-0.16, 0.4)], Color(0.85, 0.88, 0.9, 0.6))
			_poly(ci, t, [Vector2(-0.19, -0.12), Vector2(0.19, -0.12), Vector2(0.155, 0.38), Vector2(-0.155, 0.38)], Color("6aa0d0"), false)
		"p_gluttonous":  # 鸡腿
			_ellipse(ci, t, Vector2(-0.1, -0.1), Vector2(0.26, 0.2), Color("b06a3a"))
			_line(ci, t, Vector2(0.08, 0.06), Vector2(0.3, 0.3), Color("f4f0e6"), 0.08)
			_circle(ci, t, Vector2(0.32, 0.26), 0.06, Color("f4f0e6"))
			_circle(ci, t, Vector2(0.26, 0.34), 0.06, Color("f4f0e6"))
		"p_trusting":  # 扣在一起的两个环
			var s := t.get_scale().x
			ci.draw_arc(t * Vector2(-0.12, 0), 0.22 * s, 0, TAU, 32, GOLD, maxf(1.5, s * 0.07), true)
			ci.draw_arc(t * Vector2(0.12, 0), 0.22 * s, 0, TAU, 32, col, maxf(1.5, s * 0.07), true)
		"p_paranoid":  # 眼睛
			var eye := []
			for k in 20:
				var a := TAU * k / 20.0
				eye.append(Vector2(cos(a) * 0.42, sin(a) * 0.22 * (1.0 if sin(a) > 0 else 1.0)))
			_poly(ci, t, eye, Color("f4f0e6"))
			_circle(ci, t, Vector2.ZERO, 0.15, Color("5a8a5a"))
			_circle(ci, t, Vector2.ZERO, 0.07, Color("1a1612"))
		"p_zealous":  # 发光的十字架
			for k in 8:
				var a := TAU * k / 8.0 + 0.39
				_line(ci, t, Vector2(cos(a), sin(a)) * 0.3, Vector2(cos(a), sin(a)) * 0.44, Color("f0d070"), 0.04)
			draw(ci, "cross", t.origin, t.get_scale().x * 0.8, Color("f4f0e6"))
		"p_cynical":  # 断了的十字架
			var tt := Transform2D(0.25, t.get_scale() * 0.8, 0.0, t * Vector2(0.04, -0.06))
			_poly(ci, tt, [Vector2(-0.08, -0.45), Vector2(0.08, -0.45), Vector2(0.08, -0.2), Vector2(0.28, -0.2), Vector2(0.28, -0.05), Vector2(-0.28, -0.05), Vector2(-0.28, -0.2), Vector2(-0.08, -0.2)], col)
			_poly(ci, t, [Vector2(-0.07, 0.08), Vector2(0.07, 0.08), Vector2(0.07, 0.44), Vector2(-0.07, 0.44)], col)
		"p_callous":  # 一块冷冰冰的石头
			_poly(ci, t, [Vector2(-0.36, 0.3), Vector2(-0.3, -0.06), Vector2(-0.08, -0.3), Vector2(0.22, -0.26), Vector2(0.38, 0.04), Vector2(0.32, 0.32)], Color("8a9098"))
			_line(ci, t, Vector2(-0.08, -0.3), Vector2(0.0, 0.0), Color("6a7078"), 0.03)
		"p_sadistic":  # 流星锤
			_line(ci, t, Vector2(-0.36, 0.42), Vector2(-0.12, 0.14), WOOD, 0.09)
			for k in 3:
				_circle(ci, t, Vector2(-0.06 + k * 0.08, 0.06 - k * 0.1), 0.03, STEEL)
			for k in 8:
				var a := TAU * k / 8.0
				_line(ci, t, Vector2(0.22, -0.26), Vector2(0.22, -0.26) + Vector2(cos(a), sin(a)) * 0.2, STEEL, 0.04)
			_circle(ci, t, Vector2(0.22, -0.26), 0.13, Color("6a7078"))
		"p_stubborn":  # 牛角
			_circle(ci, t, Vector2(0, 0.12), 0.18, Color("7a5a3a"))
			for sign in [-1.0, 1.0]:
				_poly(ci, t, [Vector2(sign * 0.12, 0.0), Vector2(sign * 0.4, -0.08), Vector2(sign * 0.42, -0.4), Vector2(sign * 0.3, -0.12), Vector2(sign * 0.1, -0.1)], Color("f0e6d0"))
		"p_fickle":  # 风向标
			_line(ci, t, Vector2(0, -0.2), Vector2(0, 0.44), STEEL, 0.05)
			_poly(ci, t, [Vector2(-0.38, -0.24), Vector2(0.24, -0.24), Vector2(0.24, -0.32), Vector2(0.42, -0.2), Vector2(0.24, -0.08), Vector2(0.24, -0.16), Vector2(-0.38, -0.16)], col)
			_circle(ci, t, Vector2(0, -0.2), 0.05, GOLD)
		"p_eccentric":  # 螺旋
			var spiral := PackedVector2Array()
			for k in 60:
				var a := k * 0.32
				spiral.append(t * (Vector2(cos(a), sin(a)) * (0.03 + k * 0.0065)))
			ci.draw_polyline(spiral, Color("c8a0e0"), maxf(1.5, t.get_scale().x * 0.06), true)
		"p_intellect_good":  # 猫头鹰
			_ellipse(ci, t, Vector2(0, 0.06), Vector2(0.3, 0.36), Color("a07a4a"))
			_poly(ci, t, [Vector2(-0.3, -0.18), Vector2(-0.28, -0.44), Vector2(-0.1, -0.24)], Color("a07a4a"))
			_poly(ci, t, [Vector2(0.3, -0.18), Vector2(0.28, -0.44), Vector2(0.1, -0.24)], Color("a07a4a"))
			for x in [-0.13, 0.13]:
				_circle(ci, t, Vector2(x, -0.06), 0.11, Color("f4f0e6"))
				_circle(ci, t, Vector2(x, -0.06), 0.05, Color("1a1612"))
			_poly(ci, t, [Vector2(-0.05, 0.06), Vector2(0.05, 0.06), Vector2(0, 0.16)], GOLD, false)
		"p_intellect_bad":  # 一团雾 (脑子糊涂)
			for v in [Vector2(-0.2, 0.06), Vector2(0.2, 0.06), Vector2(0.0, -0.08), Vector2(-0.06, 0.16), Vector2(0.12, 0.16)]:
				_circle(ci, t, v, 0.2, Color("a8adb4"))
			for v in [Vector2(-0.2, 0.06), Vector2(0.2, 0.06), Vector2(0.0, -0.08), Vector2(-0.06, 0.16), Vector2(0.12, 0.16)]:
				ci.draw_circle(t * v, 0.17 * t.get_scale().x, Color("a8adb4"))
		"p_beauty_good":  # 玫瑰
			_line(ci, t, Vector2(0, 0.08), Vector2(0, 0.46), Color("5a9a50"), 0.05)
			_ellipse(ci, t, Vector2(0.12, 0.28), Vector2(0.1, 0.05), Color("5a9a50"))
			_circle(ci, t, Vector2(0, -0.12), 0.24, Color("c83a4a"))
			var sp := PackedVector2Array()
			for k in 30:
				var a := k * 0.4
				sp.append(t * (Vector2(0, -0.12) + Vector2(cos(a), sin(a)) * (0.02 + k * 0.006)))
			ci.draw_polyline(sp, Color("8a2030"), maxf(1.0, t.get_scale().x * 0.03), true)
		"p_beauty_bad":  # 裂了的镜子
			_line(ci, t, Vector2(0, 0.16), Vector2(0, 0.46), WOOD, 0.08)
			_ellipse(ci, t, Vector2(0, -0.12), Vector2(0.26, 0.3), GOLD)
			_ellipse(ci, t, Vector2(0, -0.12), Vector2(0.2, 0.24), Color("b8c8d4"))
			_line(ci, t, Vector2(-0.12, -0.3), Vector2(0.02, -0.1), Color("3a3a40"), 0.03)
			_line(ci, t, Vector2(0.02, -0.1), Vector2(-0.06, 0.06), Color("3a3a40"), 0.03)
			_line(ci, t, Vector2(0.02, -0.1), Vector2(0.14, -0.04), Color("3a3a40"), 0.03)
		"p_physique_good":  # 鼓起来的胳膊
			_line(ci, t, Vector2(-0.4, 0.22), Vector2(0.06, 0.22), Color("e0b090"), 0.18)
			_line(ci, t, Vector2(0.06, 0.22), Vector2(0.16, -0.24), Color("e0b090"), 0.16)
			_circle(ci, t, Vector2(-0.12, 0.1), 0.15, Color("e0b090"))
			_circle(ci, t, Vector2(0.17, -0.3), 0.12, Color("e0b090"))
		"p_physique_bad":  # 拐杖
			_line(ci, t, Vector2(0, -0.32), Vector2(0, 0.46), Color("c89a68"), 0.08)
			_line(ci, t, Vector2(-0.2, -0.36), Vector2(0.2, -0.36), Color("c89a68"), 0.1)
			_line(ci, t, Vector2(-0.14, 0.04), Vector2(0.0, 0.04), Color("c89a68"), 0.07)
		"p_giant", "p_dwarf":  # 一高一矮两个人 (主角是亮的那个)
			var big := name == "p_giant"
			_figure(ci, t, Vector2(-0.16, 0.44), 0.86, col if big else Color(col, 0.35))
			_figure(ci, t, Vector2(0.22, 0.44), 0.46, col if not big else Color(col, 0.35))
		"p_clubfooted":  # 歪了的靴子
			_poly(ci, t, [Vector2(-0.12, -0.42), Vector2(0.12, -0.42), Vector2(0.12, 0.08), Vector2(0.0, 0.3), Vector2(-0.36, 0.38), Vector2(-0.4, 0.22), Vector2(-0.14, 0.12)], Color("7a5232"))
		"p_hunchbacked":  # 弯着腰的人
			_circle(ci, t, Vector2(0.22, -0.08), 0.11, col)
			_poly(ci, t, [Vector2(0.14, 0.02), Vector2(-0.08, -0.22), Vector2(-0.3, -0.06), Vector2(-0.22, 0.44), Vector2(0.06, 0.44)], col)
		"p_stuttering":  # 断成几截的话 (卷轴条)
			for k in 3:
				var x := -0.36 + k * 0.26
				_poly(ci, t, [Vector2(x, -0.08 + k * 0.04), Vector2(x + 0.18, -0.08 + k * 0.04), Vector2(x + 0.18, 0.08 + k * 0.04), Vector2(x, 0.08 + k * 0.04)], PARCHMENT)
		"p_round_shield":  # 圆盾 (武力)
			_circle(ci, t, Vector2.ZERO, 0.42, Color("8a5a3a"))
			for k in 6:
				var a := TAU * k / 6.0
				_line(ci, t, Vector2.ZERO, Vector2(cos(a), sin(a)) * 0.4, Color("6a4228"), 0.03)
			_circle(ci, t, Vector2.ZERO, 0.13, STEEL)
		_:
			return false
	return true


## 小人 (站着的人), foot 是脚底中间, h 是高
static func _figure(ci: CanvasItem, t: Transform2D, foot: Vector2, h: float, col: Color) -> void:
	var w := h * 0.3
	_circle(ci, t, foot + Vector2(0, -h * 0.86), h * 0.13, col)
	_poly(ci, t, [foot + Vector2(-w / 2, -h * 0.7), foot + Vector2(w / 2, -h * 0.7), foot + Vector2(w * 0.4, 0), foot + Vector2(-w * 0.4, 0)], col, false)


## 钱袋
static func _scroll_sack(ci: CanvasItem, t: Transform2D, o: Vector2, col: Color) -> void:
	_poly(ci, t, [o + Vector2(-0.1, -0.24), o + Vector2(0.1, -0.24), o + Vector2(0.26, 0.1), o + Vector2(0.2, 0.34), o + Vector2(-0.2, 0.34), o + Vector2(-0.26, 0.1)], Color("b08a5a"))
	_line(ci, t, o + Vector2(-0.12, -0.2), o + Vector2(0.12, -0.2), WAX, 0.05)


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
