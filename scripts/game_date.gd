class_name GameDate
extends RefCounted
## 日期: 游戏里的日期用「从公元 0 年 1 月 1 日算起的第几天」一个整数记。
## 跟三代一样不算闰年, 每年都是 365 天, 二月 28 天。

const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const YEAR_DAYS := 365


static func to_day(year: int, month: int, day: int) -> int:
	var n := year * YEAR_DAYS
	for m in range(month - 1):
		n += MONTH_DAYS[m]
	return n + day - 1


## 第几天 -> [年, 月, 日]
static func from_day(n: int) -> Array:
	var year := n / YEAR_DAYS
	var rest := n % YEAR_DAYS
	var month := 1
	while rest >= MONTH_DAYS[month - 1]:
		rest -= MONTH_DAYS[month - 1]
		month += 1
	return [year, month, rest + 1]


static func text(n: int) -> String:
	var d := from_day(n)
	return "%d 年 %d 月 %d 日" % d
