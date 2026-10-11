class_name Portrait
extends RefCounted
## 像素头像: 用「长相基因」(dna) + 年龄、性别、文化、身份, 一层层拼出一张 120×140 的像素画
## (放大 2 倍正好填满头像框 240×280)。零件全是代码画的, 不用别人的素材。
## 同一个人 (同一套基因) 每次画出来都一样; 年纪大了头发变灰、长皱纹。

const W := 120
const H := 140
const CX := 60.0  # 脸的中线

# ---- 调色板 (9 世纪不列颠、北欧一带常见的样子) ----
const SKINS := ["f3d9c4", "edcfb6", "e6c3a5", "dcb592", "d1a682", "c49572"]
const HAIRS := {
	"black": "2a2522", "dark_brown": "4a3426", "brown": "6b4a30", "auburn": "7e3f22",
	"red": "a8512a", "blond": "c9a35e", "flaxen": "dcc98f", "fair_grey": "c8c0a8",
}
const EYES := {"blue": "4f7fb0", "grey": "7d8a92", "green": "5b8a5a", "hazel": "8a6a3a", "brown": "5a3a24"}
const CLOTH := ["7a2a24", "2f4f7a", "3d6a3a", "6a4a2a", "5a3a6a", "8a6a2a", "2e5e5a", "6e6e66"]
const LINEN := "e8e0cc"
const GOLD := "d9b44a"
const GEMS := ["b03030", "3050b0", "30a060"]
const OUTLINE := Color(0.07, 0.055, 0.045)

# 各文化发色的大概比例 (只是让人群看起来像那个地方, 每个人还是随机)
const HAIR_ODDS := {
	"anglo_saxon": {"dark_brown": 3, "brown": 4, "blond": 3, "flaxen": 1, "auburn": 1, "black": 1},
	"norse": {"blond": 4, "flaxen": 3, "brown": 3, "red": 2, "dark_brown": 1},
	"norse_gael": {"brown": 3, "blond": 2, "red": 2, "dark_brown": 2, "black": 1},
	"gaelic": {"dark_brown": 3, "brown": 3, "red": 2, "auburn": 2, "black": 2, "blond": 1},
	"welsh": {"dark_brown": 4, "black": 3, "brown": 3, "auburn": 1},
}
const EYE_ODDS := {"blue": 4, "grey": 3, "green": 2, "hazel": 2, "brown": 2}


## 画头像时照哪种样子画 (还没有自己样子的文化先借邻居的)
static func style(culture: String) -> String:
	return {"cornish": "welsh", "cumbric": "welsh"}.get(culture, culture)


## 随机一套长相基因 (生孩子时以后会从父母那里各拿一半)
static func random_dna(rng: RandomNumberGenerator, culture: String) -> Dictionary:
	culture = style(culture)
	return {
		"skin": rng.randi_range(0, 3) if culture != "gaelic" else rng.randi_range(0, 2),
		"hair": _pick(rng, HAIR_ODDS.get(culture, HAIR_ODDS.anglo_saxon)),
		"eyes": _pick(rng, EYE_ODDS),
		"face_w": rng.randf(),          # 脸宽窄
		"jaw": rng.randi_range(0, 2),   # 下巴: 0 圆 1 方 2 尖
		"nose": rng.randi_range(0, 2),  # 鼻子: 0 直 1 鹰钩 2 翘; 3 扁宽 (只给有记载的人)
		"eye_gap": rng.randi_range(0, 2),
		"brows": rng.randi_range(0, 1), # 眉毛: 0 细 1 浓
		"brow_arch": rng.randi_range(0, 2),
		"mouth": rng.randi_range(0, 2),
		"greying": rng.randf_range(0.5, 1.2), # 头发变灰早晚
		"style": rng.randi_range(0, 3),  # 发型、胡子挑哪一种 (看文化)
		"cloth": rng.randi_range(0, CLOTH.size() - 1),
		"seed": rng.randi_range(1, 1 << 30), # 头发丝、胡子茬这些小花纹
	}


static func _pick(rng: RandomNumberGenerator, odds: Dictionary) -> String:
	var total := 0
	for k in odds:
		total += odds[k]
	var roll := rng.randi_range(1, total)
	for k in odds:
		roll -= odds[k]
		if roll <= 0:
			return k
	return odds.keys()[0]


## 画一张头像。who: {female, age, culture, rank ("king" / "noble" / ""), dna}
static func make(who: Dictionary) -> Image:
	var p := Painter.new()
	p.paint(who)
	return p.img


## 0 到 1 的固定随机数 (同一个位置、同一个人每次都一样)
static func hash01(x: int, y: int, seed: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 69069) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## 一种颜色的四个深浅: 亮、本色、暗、很暗
static func tones(c: Color) -> Array:
	return [c.lightened(0.14), c, c.darkened(0.16), c.darkened(0.32)]


## 一张画的过程 (每画一张建一个)
class Painter:
	var img := Image.create(Portrait.W, Portrait.H, false, Image.FORMAT_RGBA8)
	var dna: Dictionary
	var seed: int
	var female: bool
	var age: int
	var culture: String
	var rank: String
	var beardless := false   # 小时候被阉 (不长胡子)
	var blind := false       # 被刺瞎 (眼睛画成灰白)
	var skin: Array
	var hair: Array
	var top: float      # 头顶
	var chin: float     # 下巴
	var rx: float       # 脸的半宽
	var eye_y: int
	var mouth_y: int
	var mouth_w: int
	var eye_dx: int

	func paint(who: Dictionary) -> void:
		dna = who.dna
		seed = int(dna.get("seed", 1))
		female = who.get("female", false)
		age = who.get("age", 30)
		culture = Portrait.style(who.get("culture", "anglo_saxon"))
		rank = who.get("rank", "")
		beardless = who.get("beardless", false)
		blind = who.get("blind", false)
		skin = Portrait.tones(Color(Portrait.SKINS[int(dna.skin)]))
		hair = Portrait.tones(_hair_color())
		var young := clampf((18.0 - age) / 12.0, 0.0, 1.0)  # 小孩头大脸圆
		rx = 21.5 + float(dna.face_w) * 4.0 - (2.0 if female else 0.0) + young * 1.5
		top = 22.0 + young * 5.0
		chin = 95.0 - young * 5.0 - (2.0 if female else 0.0)
		eye_y = int(top + (chin - top) * 0.47)
		mouth_y = int(top + (chin - top) * 0.8)
		mouth_w = 5 + int(dna.mouth)
		eye_dx = 10 + int(dna.eye_gap)
		img.fill(Color(0, 0, 0, 0))
		_hair_back()
		_body()
		_neck()
		_hair_volume()
		_ears()
		_head()
		_hair_front()
		_eyes()
		_brows()
		_nose()
		_mouth()
		_age_lines()
		if not female and age >= 18 and not beardless:
			_beard()
		if female and culture == "norse":
			_braids()
		_headwear()
		_outline()

	# ---- 小工具 ----
	func px(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < Portrait.W and y < Portrait.H:
			img.set_pixel(x, y, c)

	func opaque(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < Portrait.W and y < Portrait.H and img.get_pixel(x, y).a > 0.5

	func noise(x: int, y: int) -> float:
		return Portrait.hash01(x, y, seed)

	## 这一行脸有多宽 (半宽), 不在脸上返回 -1
	func half_width(y: float) -> float:
		var t := (y + 0.5 - top) / (chin - top)
		if t < 0.0 or t > 1.0:
			return -1.0
		if t < 0.5:
			var u := (0.5 - t) / 0.5
			return rx * sqrt(maxf(0.0, 1.0 - u * u))
		var u := (t - 0.5) / 0.5
		var power: float = [2.0, 3.2, 1.4][int(dna.jaw)]
		return rx * (1.0 - pow(u, power) * 0.62)

	func in_face(x: int, y: int) -> bool:
		var hw := half_width(y)
		return hw > 0 and absf(x + 0.5 - CX) <= hw

	func _hair_color() -> Color:
		var base := Color(Portrait.HAIRS[dna.hair])
		var grey := clampf((age - 38.0) / 32.0 * float(dna.greying), 0.0, 0.9)
		# 先褪色再变白 (不然红头发变灰会发粉)
		var faded := Color.from_hsv(base.h, base.s * (1.0 - grey), base.v)
		return faded.lerp(Color("d8d6d0"), grey * 0.85)

	## 头发上一点的颜色: 一缕一缕竖着的深浅, 右边背光
	func hair_at(x: int, y: int) -> Color:
		var v := noise(x, y / 4)
		var k := 1
		if v > 0.8:
			k = 0
		elif v < 0.22:
			k = 2
		if x + 0.5 > CX + rx * 0.45:
			k = mini(k + 1, 3)
		return hair[k]

	## 胡子上一点的颜色: 竖着一缕一缕, 越往下越暗, 右边背光
	func beard_at(x: int, y: int) -> Color:
		var v := noise(x / 2, y / 5)
		var k := 1 if v > 0.3 else 2
		if x + 0.5 > CX + 4.0:
			k = 2 if v > 0.5 else 3
		if y > chin + 6:
			k = mini(k + 1, 3)
		return hair[k]

	func long_hair() -> bool:
		if female:
			return culture in ["norse", "gaelic", "norse_gael"]
		return culture in ["norse", "gaelic", "norse_gael"] and int(dna.style) != 0

	func cloth_tones(i: int) -> Array:
		var c := Color(Portrait.CLOTH[i % Portrait.CLOTH.size()])
		return Portrait.tones(c.lightened(0.06) if rank == "king" else c)

	# ---- 一层层画 ----
	func _hair_back() -> void:
		if not long_hair():
			return
		var bottom := 128 if female else 112
		for y in range(int(top) + 10, bottom):
			var hw := rx + 6.0 - maxf(0.0, (y - chin) * 0.12)
			for x in range(int(CX - hw), int(CX + hw) + 1):
				px(x, y, hair_at(x, y).darkened(0.1))

	func _body() -> void:
		var t := cloth_tones(int(dna.cloth))
		for y in range(104, Portrait.H):
			var hw := 20.0 + 38.0 * pow((y - 103) / 37.0, 0.55)
			for x in range(int(CX - hw), int(CX + hw) + 1):
				var nx := (x + 0.5 - CX) / hw
				var k := 1 if nx < 0.35 else (2 if nx < 0.75 else 3)
				if nx < -0.7:
					k = 0
				if noise(x / 3, 7) > 0.86 and y > 112:
					k = mini(k + 1, 3)  # 衣服的褶子
				px(x, y, t[k])
		# 领口 (圆领), 国王和贵族领口有绣花边
		for x in range(int(CX) - 12, int(CX) + 13):
			var dx := x + 0.5 - CX
			var y := 104 + int(dx * dx / 26.0)
			px(x, y, t[3])
			if rank != "":
				var band := Color(Portrait.GOLD) if rank == "king" else Color(Portrait.CLOTH[(int(dna.cloth) + 5) % Portrait.CLOTH.size()]).lightened(0.2)
				px(x, y + 1, band)
				px(x, y + 2, band.darkened(0.25) if (x % 3) == 0 else band)
				px(x, y + 3, band.darkened(0.3))
		# 斗篷搭在一边肩膀上
		if rank != "":
			var ct := cloth_tones(int(dna.cloth) + 3)
			for y in range(106, Portrait.H):
				var x0 := int(CX + 10 + (y - 106) * 0.4)
				var x1 := int(CX + 24 + (y - 106) * 1.05)
				for x in range(x0, x1 + 1):
					var k := 1 if x < x0 + 6 else 2
					if noise(x / 4, 11) > 0.8:
						k = 3
					px(x, y, ct[k])
				px(x0, y, ct[3])
			_brooch(int(CX) + 14, 112)

	## 胸针: 盎格鲁-撒克逊是圆的金胸针镶石榴石, 盖尔人、威尔士人、诺斯人是带针的开口圆环
	func _brooch(bx: int, by: int) -> void:
		var gold := Portrait.tones(Color(Portrait.GOLD))
		if culture == "anglo_saxon":
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if dx * dx + dy * dy <= 10:
						px(bx + dx, by + dy, gold[0] if dx + dy < -1 else (gold[2] if dx + dy > 2 else gold[1]))
			for d in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				px(bx + d.x, by + d.y, Color("a02828"))
			px(bx - 1, by - 1, Color("e06060"))
		else:
			for a in range(0, 360, 15):
				if a > 60 and a < 120:
					continue  # 圆环下面有个开口
				var r := deg_to_rad(a)
				px(bx + int(round(cos(r) * 4.0)), by + int(round(sin(r) * 4.0)), gold[1] if a > 180 else gold[2])
			for k in range(-6, 7):
				px(bx + int(k * 0.5), by - k, gold[0] if k < 0 else gold[2])

	func _neck() -> void:
		var hw := 8.0 if female else 10.0
		for y in range(int(chin) - 8, 108):
			for x in range(int(CX - hw), int(CX + hw)):
				var k := 1
				if x + 0.5 > CX + hw * 0.3:
					k = 2
				if y < chin + 5:
					k = 3  # 下巴底下的阴影
				px(x, y, skin[k])

	func _bald() -> bool:
		return not female and culture == "anglo_saxon" and int(dna.style) == 3 and age >= 40

	func _hair_volume() -> void:
		# 头发是盖在头上的一个圆顶, 比脑袋大一圈, 往下接到两鬓
		if _bald():
			return
		var extra := 4.0
		var cy := top + 13.0
		for y in range(int(top) - 6, eye_y):
			for x in range(0, Portrait.W):
				var dx := (x + 0.5 - CX) / (rx + extra)
				var dy := (y + 0.5 - cy) / 17.0
				var in_dome := dx * dx + dy * dy <= 1.0
				var below := y + 0.5 >= cy and absf(x + 0.5 - CX) <= half_width(y) + extra
				if in_dome or below:
					px(x, y, hair_at(x, y))

	func _ears() -> void:
		for y in range(eye_y - 2, eye_y + 10):
			var hw := half_width(y)
			for k in range(0, 4):
				px(int(CX - hw) - k, y, skin[1] if k < 3 else skin[2])
				px(int(CX + hw) + k - 1, y, skin[2] if k < 3 else skin[3])
			px(int(CX - hw) - 1, y, skin[2] if y > eye_y and y < eye_y + 7 else skin[1])

	func _head() -> void:
		for y in range(int(top), int(chin) + 1):
			var hw := half_width(y)
			if hw <= 0:
				continue
			var t := (y + 0.5 - top) / (chin - top)
			for x in range(int(floor(CX - hw)), int(ceil(CX + hw))):
				var nx := (x + 0.5 - CX) / hw
				if absf(nx) > 1.0:
					continue
				# 光从左上来: 右边暗, 下巴底下暗, 左脸颊亮
				var s := nx * 0.85
				if t > 0.74:
					s += (t - 0.74) * 1.6
				if Vector2(nx + 0.45, (t - 0.64) * 2.2).length() < 0.24:
					s -= 0.5
				var k := 1
				if s < -0.5:
					k = 0
				elif s > 0.62:
					k = 3
				elif s > 0.3:
					k = 2
				px(x, y, skin[k])
		# 眼窝: 眉毛下面暗一点
		for side in [-1, 1]:
			var ex: int = int(CX) + side * eye_dx
			for dx in range(-4, 5):
				px(ex + dx, eye_y - 2, skin[2] if side > 0 else skin[1].darkened(0.06))

	func _hair_front() -> void:
		# 发际线: 平刘海 / 偏分 / 中分 / 往后退 (年纪大) / 秃 (只剩两边一圈)
		var line := top + (chin - top) * 0.2
		if not female and age >= 45:
			line += 3.0
		var long := long_hair()
		for y in range(int(top), eye_y + (6 if long else 2)):
			for x in range(0, Portrait.W):
				if not in_face(x, y):
					continue
				var hw := half_width(y)
				var off := absf(x + 0.5 - CX)
				if _bald():
					if off > hw - 3.5 and y > eye_y - 16 and y < eye_y + 2:
						px(x, y, hair_at(x, y))
					continue
				var edge := line + (noise(x, 3) - 0.5) * 3.0
				match int(dna.style):
					1:
						edge += (x - CX) * 0.22
					2:
						edge += 2.0 - off * 0.22
				var side_width := 4.0 if long else 2.5
				var sides := off > hw - side_width and y < eye_y - (0 if long else 3)
				if long and off > hw - 2.5 and y >= eye_y - 3 and y < eye_y + 6:
					sides = true
				if y < edge or sides:
					px(x, y, hair_at(x, y))

	func _eyes() -> void:
		var iris := Color(Portrait.EYES[dna.eyes]) if not blind else Color("b9b4ab")
		var lid: Color = skin[1].darkened(0.55)
		var white := Color("ece6dc")
		for side in [-1, 1]:
			var ex: int = int(CX) + side * eye_dx
			var y := eye_y
			for dx in range(-3, 4):
				px(ex + dx, y - 1, lid)  # 上眼皮
			px(ex + 3 * side, y, lid)
			for dx in range(-2, 3):
				px(ex + dx, y, white if side < 0 or dx < 1 else white.darkened(0.12))
				px(ex + dx, y + 1, white.darkened(0.08))
			for dx in range(-1, 2):
				px(ex + dx, y, iris)
				px(ex + dx, y + 1, iris.darkened(0.2))
			px(ex, y, iris.darkened(0.65))     # 瞳孔
			px(ex - 1, y, iris.lightened(0.45))  # 亮点
			for dx in range(-2, 3):
				px(ex + dx, y + 2, skin[2])  # 下眼皮
			if female:
				px(ex + 4 * side, y - 2, lid)  # 睫毛
				px(ex + 4 * side, y - 1, lid)

	func _brows() -> void:
		var c: Color = hair[3] if age < 55 else hair[2]
		var arch: float = [1.0, 2.0, 0.0][int(dna.brow_arch)]
		var thick := 1 if female else (3 if int(dna.brows) == 1 else 2)
		for side in [-1, 1]:
			var ex: int = int(CX) + side * eye_dx
			for k in range(-5, 6):
				var u := k / 5.0
				var y := eye_y - 5 - int(round(arch * (1.0 - u * u)))
				if k * side < -3:
					y += 1  # 靠鼻子那头低一点
				for t in thick:
					if not (female and absf(u) > 0.8 and t > 0):
						px(ex + k, y + t, c)

	func _nose() -> void:
		var x := int(CX)
		var top_y := eye_y + 1
		var tip := eye_y + 12
		var shade: Color = skin[2]
		match int(dna.nose):
			0:  # 直
				for y in range(top_y + 1, tip):
					px(x + 2, y, shade)
			1:  # 鹰钩: 鼻梁中间凸出来, 鼻尖往下勾
				for y in range(top_y + 1, tip + 1):
					var bump := 1 if y > top_y + 3 and y < top_y + 8 else 0
					px(x + 2 + bump, y, shade)
					if bump:
						px(x + 1, y, skin[0])
				tip += 1
			2:  # 翘: 短, 鼻尖亮
				tip -= 2
				for y in range(top_y + 3, tip):
					px(x + 2, y, shade)
				px(x - 1, tip - 1, skin[0])
				px(x, tip - 1, skin[0])
			3:  # 扁宽 (扁鼻子凯蒂尔): 鼻梁塌, 鼻头又宽又平, 两个大鼻孔
				for y in range(top_y + 4, tip):
					px(x + 2, y, shade)
					px(x + 3, y, shade)
				for k in range(-5, 6):
					px(x + k, tip - 1, skin[0] if absf(k) < 3 else shade)
					px(x + k, tip, skin[3] if absf(k) >= 3 else shade)
				for k in range(-2, 3):
					px(x + k, tip + 1, skin[2])
				return
		# 鼻尖、鼻翼、鼻孔
		px(x, tip - 1, skin[0])
		px(x - 3, tip, skin[2])
		px(x + 3, tip, skin[3])
		px(x - 2, tip + 1, skin[3])
		px(x + 2, tip + 1, skin[3])
		for k in range(-1, 2):
			px(x + k, tip + 1, skin[2])

	func _mouth() -> void:
		var x := int(CX)
		var y := mouth_y
		var w := mouth_w
		var line: Color = skin[1].darkened(0.45)
		var lip: Color = Color("b8645a") if female else skin[1].darkened(0.12)
		for k in range(-w + 1, w):
			px(x + k, y - 1, skin[2])  # 上嘴唇
			px(x + k, y, line)         # 嘴缝
		px(x - w, y + 1, line)         # 嘴角往下一点
		px(x + w, y + 1, line)
		for k in range(-w + 2, w - 1):
			px(x + k, y + 1, lip.lightened(0.12) if absf(k) < 2 else lip)  # 下嘴唇
		for k in range(-w + 3, w - 2):
			px(x + k, y + 2, lip.darkened(0.1))
			px(x + k, y + 3, skin[2])  # 下嘴唇底下的阴影

	func _age_lines() -> void:
		var line: Color = skin[2]
		var forehead := int(top + (chin - top) * 0.27)
		if age >= 40:
			for k in range(-7, 8):
				px(int(CX) + k, forehead, line)
		if age >= 50:
			for k in range(-5, 6):
				px(int(CX) + k, forehead + 3, line)
			for side in [-1, 1]:
				var ex: int = int(CX) + side * eye_dx
				px(ex + side * 5, eye_y, line)
				px(ex + side * 5, eye_y + 2, line)
				px(ex + side * 6, eye_y + 1, line)
				for k in range(0, 7):
					px(int(CX) + side * (5 + k / 2), eye_y + 13 + k, line)  # 鼻子到嘴角的纹
		if age >= 62:
			for side in [-1, 1]:
				var ex: int = int(CX) + side * eye_dx
				for dx in range(-2, 3):
					px(ex + dx, eye_y + 4, line)  # 眼袋
				for k in range(0, 4):
					px(int(CX) + side * (mouth_w + 3), mouth_y + 3 + k, line)  # 下巴两边松了

	func _beard() -> void:
		var x0 := int(CX)
		var kind := "moustache"
		match culture:
			"anglo_saxon":
				kind = ["moustache", "short", "moustache", "short"][int(dna.style)]
			"norse", "norse_gael":
				kind = ["full", "forked", "full", "short"][int(dna.style)]
			_:
				kind = ["moustache", "full", "short", "moustache"][int(dna.style)]
		if age < 21:
			return  # 二十岁以下先不留胡子
		# 八字胡: 盖住上嘴唇; 盎格鲁-撒克逊人的两头垂下来
		var mw := mouth_w + 2
		for y in range(mouth_y - 4, mouth_y):
			var w := mw - (2 if y == mouth_y - 4 else 0)
			for k in range(-w, w + 1):
				px(x0 + k, y, beard_at(x0 + k, y) if k < 2 else hair[2])
		if kind == "moustache" and culture == "anglo_saxon":
			for y in range(mouth_y, mouth_y + 6):
				px(x0 - mw, y, hair[1])
				px(x0 - mw + 1, y, hair[2])
				px(x0 + mw, y, hair[2])
				px(x0 + mw - 1, y, hair[2])
		if kind == "moustache":
			return
		var length: int = {"short": 3, "full": 13, "forked": 15}[kind]
		for y in range(mouth_y + 1, int(chin) + length + 1):
			var hw := half_width(minf(y, chin - 0.5))
			if y > chin:
				hw = maxf(2.0, hw - (y - chin) * (1.1 if kind == "full" else 0.7))
			for x in range(int(CX - hw), int(CX + hw) + 1):
				var off := absf(x + 0.5 - CX)
				if kind == "forked" and y > chin + 5 and off < 2.0 + (y - chin - 5) * 0.3:
					continue  # 分成两叉
				if y <= mouth_y + 3 and off < mouth_w - 1:
					continue  # 下嘴唇露出来
				px(x, y, beard_at(x, y))
		# 两边腮帮子上的胡子连到鬓角
		for y in range(eye_y + 7, mouth_y + 1):
			var hw := half_width(y)
			var w := 3 if kind == "short" else 5
			for k in range(0, w):
				px(int(CX - hw) + k, y, beard_at(int(CX - hw) + k, y))
				px(int(CX + hw) - 1 - k, y, hair[2])

	## 诺斯女人: 两条辫子垂到胸前
	func _braids() -> void:
		for side in [-1, 1]:
			var bx := int(CX + side * (rx - 1.0))
			for y in range(eye_y + 6, 132):
				var wave := 1 if (y / 3) % 2 == 0 else -1
				for k in range(-3, 4):
					var c: Color = hair[1] if (k * wave + y) % 4 < 2 else hair[2]
					px(bx + k, y, c)
				px(bx - 3, y, hair[3])
				px(bx + 3, y, hair[3])
			for k in range(-2, 3):
				px(bx + k, 133, Color(Portrait.CLOTH[int(dna.cloth)]))  # 辫子尾巴扎的布条

	func _headwear() -> void:
		var line := int(top + (chin - top) * 0.15)
		if female and culture in ["anglo_saxon", "welsh"] and age >= 14:
			# 头巾: 把头发包起来, 从头顶垂到肩膀, 有几道褶子
			var base := Color(Portrait.LINEN) if int(dna.cloth) % 2 == 0 else Color(Portrait.CLOTH[int(dna.cloth)]).lightened(0.35)
			var v := Portrait.tones(base)
			for y in range(int(top) - 5, 116):
				var hw := rx + 5.0
				if y < top + 4:
					var u := (top + 4 - y) / 9.0
					hw = (rx + 5.0) * sqrt(maxf(0.0, 1.0 - u * u))
				elif y > chin - 4:
					hw += (y - chin + 4) * 0.85  # 往下披到肩膀上, 越往下越宽
				for x in range(int(CX - hw), int(CX + hw) + 1):
					var off := absf(x + 0.5 - CX)
					var face := in_face(x, y) and y >= line + 3 and off < half_width(y) - 1.5
					var throat := y > chin - 2 and off < 8.0 and y < 104
					if face or throat:
						continue
					var nx := (x + 0.5 - CX) / hw
					var k := 1 if nx < 0.4 else 2
					if nx < -0.75:
						k = 0
					if noise(x / 5, 3) > 0.78 and y > eye_y:
						k = mini(k + 1, 3)  # 褶子
					px(x, y, v[k])
		if rank == "king":
			# 头箍: 照当时钱币上国王戴的样子, 一圈带宝石的金箍 (不是后来那种高王冠)
			var gold := Portrait.tones(Color(Portrait.GOLD))
			var hw := half_width(line) + 4.0
			for y in range(line - 1, line + 3):
				for x in range(int(CX - hw), int(CX + hw) + 1):
					var nx := (x + 0.5 - CX) / hw
					var k := 0 if y == line - 1 else (1 if nx < 0.4 else 2)
					if y == line + 2:
						k = 3
					px(x, y, gold[k])
			for i in 3:
				var gx := int(CX) + (i - 1) * 13
				var gem := Color(Portrait.GEMS[(int(dna.cloth) + i) % 3])
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
					px(gx + d.x, line + d.y, gem)
				px(gx, line, gem.lightened(0.5))

	## 最后描一圈深色的边 (像素画的轮廓)
	func _outline() -> void:
		var marks: Array = []
		for y in Portrait.H:
			for x in Portrait.W:
				if opaque(x, y):
					continue
				if opaque(x - 1, y) or opaque(x + 1, y) or opaque(x, y - 1) or opaque(x, y + 1):
					marks.append(Vector2i(x, y))
		for m in marks:
			px(m.x, m.y, Portrait.OUTLINE)
