extends Node2D
## 游戏入口。现在还只是一个空架子: 第 1 块 (地图和时间) 还没开始做。

const SIZE := Vector2(1920, 1080)

var font := SystemFont.new()


func _ready() -> void:
	# 中文字体先用电脑自带的 (Mac 冬青黑体, Windows 微软雅黑)
	font.font_names = PackedStringArray(["Hiragino Sans GB", "PingFang SC", "Microsoft YaHei"])


func _draw() -> void:
	draw_string(font, Vector2(0, SIZE.y / 2 - 40), "血脉与王冠",
			HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 72, Color(0.93, 0.85, 0.62))
	draw_string(font, Vector2(0, SIZE.y / 2 + 40), "867 年 · 不列颠群岛  (还在做第 1 块: 地图和时间)",
			HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 28, Color(0.75, 0.75, 0.78))
