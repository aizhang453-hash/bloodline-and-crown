class_name Clock
extends RefCounted
## 时间: 跟三代一样, 时间自己往前走, 可以暂停, 有五档速度。

## 每一档速度每秒走几天 (第 0 个不用)
const DAYS_PER_SECOND := [0.0, 1.0, 2.5, 5.0, 12.0, 30.0]
const MAX_SPEED := 5

var day: int
var paused := true
var speed := 1
var _carry := 0.0  # 不满一天的零头


func _init(start_day: int) -> void:
	day = start_day


## 过了 seconds 秒, 返回走了几天 (暂停时是 0)
func advance(seconds: float) -> int:
	if paused:
		return 0
	_carry += seconds * DAYS_PER_SECOND[speed]
	var days := int(_carry)
	_carry -= days
	day += days
	return days


func toggle_pause() -> void:
	paused = not paused


func set_speed(value: int) -> void:
	speed = clampi(value, 1, MAX_SPEED)


func faster() -> void:
	set_speed(speed + 1)


func slower() -> void:
	set_speed(speed - 1)


func text() -> String:
	return GameDate.text(day)
