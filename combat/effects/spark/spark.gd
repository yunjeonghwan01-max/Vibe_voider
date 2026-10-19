class_name SparkEffect
extends Node2D

## 타격/패링 스파크. _draw로 중심에서 뻗는 날카로운 직선들(별 모양 파열)을 그린다.
## 패링은 ring=true로 확장하는 원 테두리까지 그려 "쨍!" 하는 번개 같은 느낌을 준다.

var _rays: Array[Dictionary] = []
var _t: float = 0.0
var _lifetime: float = 0.22
var _color: Color = Color(1.0, 0.95, 0.7, 1.0)
var _length: float = 44.0
var _ring: bool = false
var _ring_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _ring_radius: float = 70.0


## count: 선 개수. spread_deg: 퍼짐 각(360이면 전방위). direction_deg: 중심 방향.
func burst(color: Color, count: int, spread_deg: float, direction_deg: float,
		length: float, lifetime: float = 0.22) -> void:
	_color = color
	_length = length
	_lifetime = lifetime
	var half := deg_to_rad(spread_deg) * 0.5
	var center := deg_to_rad(direction_deg)
	for i in count:
		var a := center + randf_range(-half, half)
		_rays.append({
			"angle": a,
			"len": length * randf_range(0.6, 1.0),
			"width": randf_range(2.0, 4.5),
			"inner": randf_range(2.0, 10.0),
		})


## 패링용 — 확장하는 링을 추가한다.
func with_ring(ring_color: Color, radius: float) -> void:
	_ring = true
	_ring_color = ring_color
	_ring_radius = radius


func _process(delta: float) -> void:
	_t += delta / maxf(_lifetime, 0.0001)
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _t
	# ease-out: 빠르게 뻗고 느리게 멈춘다.
	var reach := 1.0 - pow(1.0 - _t, 2.5)

	for ray in _rays:
		var dir: Vector2 = Vector2(cos(ray.angle), sin(ray.angle))
		var start: Vector2 = dir * float(ray.inner)
		var end: Vector2 = dir * (float(ray.inner) + float(ray.len) * reach)
		var c := _color
		c.a = _color.a * fade
		draw_line(start, end, c, float(ray.width) * fade, true)

	if _ring:
		var r := _ring_radius * reach
		var rc := _ring_color
		rc.a = _ring_color.a * fade * fade
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, rc, 3.5 * fade, true)
