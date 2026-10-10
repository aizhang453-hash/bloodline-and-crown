class_name ProvinceMap
extends RefCounted
## 领地图: data/generated/provinces.png, 每个像素记着是哪块领地 (红 × 256 + 绿 = 编号, 0 是海)。
## 鼠标点在地图上, 就看那个像素是几号。

const FILE := "res://data/generated/provinces.png"

var texture: Texture2D
var image: Image


func _init() -> void:
	texture = load(FILE)
	image = texture.get_image()
	if image.is_compressed():
		image.decompress()


func size() -> Vector2i:
	return image.get_size()


## 地图上的一点 (领地图的像素坐标) 是几号领地, 地图外面和海都是 0
func index_at(p: Vector2) -> int:
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return 0
	var c := image.get_pixel(x, y)
	return int(round(c.r * 255.0)) * 256 + int(round(c.g * 255.0))
