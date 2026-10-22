class_name WatcherBeam
extends Node2D

## 카유공 광선의 겉모습 (판정은 Watcher가 히트스캔으로 이미 끝냈다).
## 굵은 금빛 광선이 번쩍 뻗었다가 가늘어지며 사라진다. 발사점 섬광 + 명중점 폭발 원 + 광선을 따라 튀는 불꽃 조각.
## 노드 위치 = 발사점. setup()으로 끝점(전역)과 명중 여부를 받는다.

@export var outer_color: Color = Color(1.0, 0.62, 0.25, 0.55)
@export var mid_color: Color = Color(1.0, 0.88, 0.5, 0.95)
@export var core_color: Color = Color(1.0, 1.0, 0.96, 1.0)
@export var width: float = 34.0
@export var lifetime: float = 0.42

var _end: Vector2 = Vector2.ZERO     # 로컬 끝점
var _hit: bool = false
var _t: float = 0.0
var _bits: Array[Dictionary] = []


func setup(end_global: Vector2, hit: bool) -> void:
	_end = end_global - global_position
	_hit = hit
	var n := int(_end.length() / 40.0)
	for i in n:
		_bits.append({
			"u": randf(),
			"off": randf_range(-1.0, 1.0),
			"len": randf_range(10.0, 26.0),
		})


func _process(delta: float) -> void:
	_t += delta / maxf(lifetime, 0.0001)
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var dir := _end.normalized()
	var nrm := dir.orthogonal()
	# 처음 순간 가장 굵고(팝), 점점 가늘어진다. 살짝 떨린다.
	var k := (1.0 - _t) * (1.0 - _t) * (1.0 + 0.12 * sin(_t * 90.0))
	var pop := 1.0 + 0.6 * maxf(1.0 - _t * 8.0, 0.0)
	var w := width * k * pop
	draw_line(Vector2.ZERO, _end, _alpha(outer_color, 1.0 - _t), w * 2.0)
	draw_line(Vector2.ZERO, _end, _alpha(mid_color, 1.0 - _t), w)
	draw_line(Vector2.ZERO, _end, _alpha(core_color, 1.0 - _t * 0.8), maxf(w * 0.35, 1.5))
	# 광선을 따라 바깥으로 튀는 불꽃 조각
	for b in _bits:
		var p: Vector2 = _end * float(b.u) + nrm * float(b.off) * (w * 0.6 + _t * 70.0)
		draw_line(p, p + dir * float(b.len) * (1.0 - _t), _alpha(mid_color, 1.0 - _t), 2.0)
	# 발사점 섬광
	draw_circle(Vector2.ZERO, 26.0 * k * pop, _alpha(core_color, 1.0 - _t))
	# 명중점 폭발 원
	if _hit:
		var r := 30.0 + 120.0 * (1.0 - pow(1.0 - _t, 3.0))
		draw_arc(_end, r, 0.0, TAU, 40, _alpha(mid_color, 1.0 - _t), 6.0 * (1.0 - _t) + 1.0)
		draw_circle(_end, 34.0 * k * pop, _alpha(core_color, 1.0 - _t))


func _alpha(c: Color, mul: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(mul, 0.0, 1.0))
