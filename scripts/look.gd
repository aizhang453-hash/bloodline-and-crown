class_name Look
extends RefCounted
## 界面的样子: 颜色、字体、面板的画法。学三代的感觉 (深色石板底、暗金色描边), 不用原版的图。

const GOLD := Color("c8a660")
const GOLD_DIM := Color("7d6a45")
const PANEL := Color(0.075, 0.08, 0.095, 0.94)
const PANEL_LIGHT := Color(0.13, 0.135, 0.15, 0.96)
const TEXT := Color("ecdfc2")
const TEXT_DIM := Color("a89c84")
const GREEN := Color("8fcf7a")
const RED := Color("e07060")

const SERIF := ["Songti SC", "STSong", "SimSun", "Noto Serif CJK SC", "Source Han Serif SC"]
# 注意: Mac 上要「PingFang SC」会拿到「PingFang HK」(香港字形, 缺「迟」这些简体字), 所以不用苹方
const SANS := ["Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC", "Source Han Sans SC", "STHeiti"]

static var _fonts := {}


## kind: "serif" 标题用的宋体, "sans" 小字用的黑体, "map" 地图上会放大缩小的字 (用 MSDF, 放大了也清楚)
static func font(kind := "serif") -> Font:
	if not _fonts.has(kind):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(SANS if kind == "sans" else SERIF)
		var backup := SystemFont.new()
		backup.font_names = PackedStringArray(SANS + SERIF)
		f.fallbacks = [backup]
		if kind == "map":
			f.multichannel_signed_distance_field = true
			f.msdf_size = 64
			f.msdf_pixel_range = 12
		_fonts[kind] = f
	return _fonts[kind]


# 查字有没有超出框 (测试用, tests/text_fit.gd 打开): 字 -> 超出了多少
static var check := false
static var overflows := {}
static var _boxes: Array = []   # 这一帧画过的面板 (没给宽度的字, 看它有没有超出所在的面板)
const MIN_SHRINK := 0.75        # 放不下的字最多缩到 75%


## 每一帧开头 (界面的 _draw 最前面) 调用
static func begin_frame() -> void:
	_boxes.clear()


## 一块面板: 深色底 + 暗金色描边
static func panel(ci: CanvasItem, r: Rect2, fill := PANEL, trim := true) -> void:
	ci.draw_rect(r, fill)
	if trim:
		ci.draw_rect(r, GOLD_DIM, false, 2.0)
		ci.draw_rect(r.grow(-4), Color(GOLD_DIM, 0.35), false, 1.0)
	if check:
		_boxes.append(r)


## 写一行字。给了宽度的, 放不下就把字缩小一点 (最多缩到 75%)
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color := TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, kind := "serif") -> void:
	var f := font(kind)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width > 0.0 and w > width:
		var smaller := maxi(int(size * MIN_SHRINK), int(size * width / w))
		w = w * smaller / size
		size = smaller
	ci.draw_string(f, pos, s, align, width, size, color)
	if check:
		if width > 0.0:
			_note(s, w - width)
		else:
			for i in range(_boxes.size() - 1, -1, -1):
				var b: Rect2 = _boxes[i]
				if b.has_point(pos + Vector2(1, -2)):
					_note(s, pos.x + w - (b.end.x - 6))
					break


## 在 r 里居中写一行字 (放不下就缩小一点)
static func text_center(ci: CanvasItem, r: Rect2, s: String, size: int, color := TEXT, kind := "serif") -> void:
	var f := font(kind)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if w > r.size.x - 8:
		var smaller := maxi(int(size * MIN_SHRINK), int(size * (r.size.x - 8) / w))
		w = w * smaller / size
		size = smaller
	var y := r.position.y + (r.size.y + f.get_ascent(size) - f.get_descent(size)) / 2.0
	ci.draw_string(f, Vector2(r.position.x, y), s, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, color)
	if check:
		_note(s, w - r.size.x)


static func _note(s: String, over: float) -> void:
	if over > 0.5:
		overflows[s] = maxf(over, float(overflows.get(s, 0.0)))


## 圆按钮: 深色圆 + 金圈, 中间一个小图标 (Icons 里的名字)
static func round_button(ci: CanvasItem, center: Vector2, radius: float, icon: String, color := TEXT,
		lit := false, hover := false) -> void:
	ci.draw_circle(center, radius, Color(0.16, 0.15, 0.13) if lit else Color(0.08, 0.085, 0.1))
	ci.draw_arc(center, radius - 1.0, 0, TAU, 48, GOLD if (lit or hover) else GOLD_DIM, 2.0, true)
	Icons.draw(ci, icon, center, radius * 1.35, color)
