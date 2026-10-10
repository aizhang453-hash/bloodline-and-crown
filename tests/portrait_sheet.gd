extends SceneTree
## 头像样品: 拍两张图 (会开一下窗口, 拍完自己关)
##   头像样品_全部.png      60 个头像, 原大 (第一行是开局的国王, 下面四行是各文化随机的男女老少)
##   头像样品_游戏里大小.png  挑 21 个, 放大 2 倍 (游戏里头像框就是这么大)
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/portrait_sheet.gd -- 存图的文件夹

const CULTURES := [["anglo_saxon", "撒克逊"], ["norse", "诺斯"], ["gaelic", "盖尔"], ["welsh", "威尔士"]]
const AGES := [17, 26, 34, 46, 58, 71]
# 第二张图挑哪几个 (下标)
const PICK := [0, 1, 2, 3, 4, 7, 8, 14, 19, 27, 32, 40, 45, 52, 59, 16, 13, 33, 50, 56, 22]

var out := ""
var sheet: Sheet


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	sheet = Sheet.new()
	sheet.people = _people()
	var layer := CanvasLayer.new()
	layer.add_child(sheet)
	root.add_child(layer)
	_shoot.call_deferred()


func _shoot() -> void:
	for page in [1, 2]:
		sheet.page = page
		sheet.queue_redraw()
		for i in 6:
			await process_frame
		var name := "头像样品_全部.png" if page == 1 else "头像样品_游戏里大小.png"
		root.get_texture().get_image().save_png(out.path_join(name))
		print("拍了 ", name)
	quit()


func _people() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 867
	var list := []
	# 第一行: 开局的国王 (有外号讲到长相的照着画, 别的随机)
	var kings := [
		["扁鼻子凯蒂尔", "norse", 52, {"nose": 3}],
		["艾德·芬德利亚斯", "gaelic", 40, {"hair": "fair_grey"}],
		["阿姆莱夫", "norse_gael", 44, {"hair": "flaxen"}],
		["埃塞尔雷德一世", "anglo_saxon", 20, {}],
		["伯格雷德", "anglo_saxon", 40, {}],
		["埃德蒙", "anglo_saxon", 26, {}],
		["无骨者伊瓦尔", "norse", 35, {}],
		["罗德里大王", "welsh", 47, {}],
		["康斯坦丁一世", "gaelic", 31, {}],
		["凯尔伯尔", "gaelic", 55, {}],
		["阿特加尔", "welsh", 45, {}],
		["埃利塞德", "welsh", 30, {}],
	]
	for k in kings:
		var dna := Portrait.random_dna(rng, k[1])
		dna.merge(k[3], true)
		list.append({"label": k[0], "culture": k[1], "age": k[2], "rank": "king", "dna": dna, "female": false})
	for c in CULTURES:
		for female in [false, true]:
			for age in AGES:
				list.append({"label": "%s%s %d岁" % [c[1], "女" if female else "男", age], "culture": c[0],
						"age": age, "rank": "noble" if age > 30 and rng.randf() < 0.5 else "", "female": female,
						"dna": Portrait.random_dna(rng, c[0])})
	return list


class Sheet:
	extends Control

	var people: Array
	var textures: Array = []
	var page := 1

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for p in people:
			textures.append(ImageTexture.create_from_image(Portrait.make(p)))

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0.07, 0.075, 0.09))
		var scale := 1 if page == 1 else 2
		var w := Portrait.W * scale
		var h := Portrait.H * scale
		var cols := 12 if page == 1 else 7
		var gap := Vector2(36, 34) if page == 1 else Vector2(28, 40)
		var picks: Array = range(people.size()) if page == 1 else PICK
		for n in picks.size():
			var i: int = picks[n]
			var pos := Vector2(40 + (n % cols) * (w + gap.x), 14 + (n / cols) * (h + gap.y))
			draw_rect(Rect2(pos, Vector2(w, h)), Color(0.16, 0.15, 0.14) if i < 12 else Color(0.12, 0.125, 0.14))
			draw_texture_rect(textures[i], Rect2(pos, Vector2(w, h)), false)
			Look.text_center(self, Rect2(pos.x - 16, pos.y + h + 3, w + 32, 22), people[i].label, 15 if page == 1 else 18,
					Look.GOLD if i < 12 else Look.TEXT_DIM, "sans")
