extends TestCase
## 日期和时间


func test_date_round_trip() -> void:
	var start := GameDate.to_day(867, 1, 1)
	eq(GameDate.from_day(start), [867, 1, 1])
	eq(GameDate.text(start), "867 年 1 月 1 日")
	eq(GameDate.from_day(start + 31), [867, 2, 1], "一月 31 天")
	eq(GameDate.from_day(start + 31 + 28), [867, 3, 1], "二月 28 天, 不算闰年")
	eq(GameDate.from_day(start + 364), [867, 12, 31])
	eq(GameDate.from_day(start + 365), [868, 1, 1], "868 年也不算闰年 (跟三代一样)")
	for n in range(start, start + 800, 7):
		var d: Array = GameDate.from_day(n)
		eq(GameDate.to_day(d[0], d[1], d[2]), n)


func test_clock_paused_at_start() -> void:
	var c := Clock.new(GameDate.to_day(867, 1, 1))
	check(c.paused, "开局是暂停的")
	eq(c.advance(10.0), 0, "暂停时不走")
	eq(c.text(), "867 年 1 月 1 日")


func test_clock_speeds() -> void:
	var c := Clock.new(0)
	c.toggle_pause()
	eq(c.advance(1.0), 1, "一档每秒 1 天")
	c.set_speed(5)
	eq(c.advance(1.0), 30, "五档每秒 30 天")
	c.set_speed(3)
	var total := 0
	for i in 10:
		total += c.advance(0.1)
	eq(total, 5, "零头攒起来不丢")
	c.faster()
	c.faster()
	c.faster()
	eq(c.speed, 5, "最快五档")
	for i in 9:
		c.slower()
	eq(c.speed, 1, "最慢一档")
