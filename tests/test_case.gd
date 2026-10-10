class_name TestCase
extends RefCounted
## 测试的底子: 每个测试文件 extends 它, 里面以 test_ 开头的函数就是一条测试。
## 用 check / eq / has_text 检查, 不对就记下来 (测试接着跑完, 最后一起报)。

var failures: Array = []
var current_test := ""


func check(ok: bool, what := "") -> void:
	if not ok:
		failures.append("%s: 不对 %s" % [current_test, what])


func eq(actual: Variant, expected: Variant, what := "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		failures.append("%s: 应该是 %s, 实际是 %s (类型不一样) %s" % [current_test, expected, actual, what])
	elif actual != expected:
		failures.append("%s: 应该是 %s, 实际是 %s %s" % [current_test, expected, actual, what])


func has_text(text: String, part: String, what := "") -> void:
	if not text.contains(part):
		failures.append("%s: 「%s」里应该有「%s」 %s" % [current_test, text, part, what])


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
