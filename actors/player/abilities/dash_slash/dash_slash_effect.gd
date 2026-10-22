class_name DashSlashEffect
extends Node2D

## 대시 참격 궤적 — 앞으로 길게 뻗는 가늘고 날카로운 칼빛. 외부 이미지 없이 _draw로 그린다.
## 날 끝이 거의 순간적으로 쭉 뻗고(끝에서 별빛이 번쩍), 꼬리가 바로 뒤따라와 칼빛을 지운다
## → 한 번에 베고 지나간 날렵한 느낌. 날은 앞쪽 2/3 지점이 가장 두껍고 끝은 바늘처럼 뾰족하다.
## 좌우는 setup(facing)의 scale.x로 정한다 (반전 노드에 종속되지 않게 값으로 받는다).

@export var glow_color: Color = Color(0.7, 0.4, 1.0, 0.4)
@export var color: Color = Color(0.86, 0.72, 1.0, 0.95)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var length: float = 200.0           # 참격 판정 끝(+적 몸통)과 맞춘 길이
@export var thickness: float = 11.0
@export var lifetime: float = 0.13

var _t: float = 0.0  # 0..1 진행도


func setup(facing: float) -> void:
	scale = Vector2(signf(facing) if facing != 0.0 else 1.0, 1.0)


func _process(delta: float) -> void:
	_t += delta / maxf(lifetime, 0.0001)
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var tip := length * (1.0 - pow(1.0 - minf(_t * 4.0, 1.0), 3.0))   # 거의 즉시 끝까지 뻗는다
	var tail := length * pow(_t, 1.6)                                    # 꼬리가 가속하며 따라와 지운다
	if tip - tail < 2.0:
		return
	var fade := 1.0 - _t
	var thin := sqrt(fade)                     # 사라지며 더 가늘어진다

	_draw_blade(tail, tip, thickness * 2.2 * thin, _with_alpha(glow_color, fade))
	_draw_blade(tail, tip, thickness * thin, _with_alpha(color, fade))
	# 날의 번뜩임: 앞쪽 절반을 지나는 가는 흰 선
	draw_line(Vector2(lerpf(tail, tip, 0.35), 0.0), Vector2(tip, 0.0), _with_alpha(core_color, fade), 2.0, true)

	# 위아래로 스치는 가는 속도선
	var sc := _with_alpha(color, 0.5 * fade)
	draw_line(Vector2(lerpf(tail, tip, 0.15), -thickness * 1.5), Vector2(lerpf(tail, tip, 0.6), -thickness * 1.5), sc, 1.0)
	draw_line(Vector2(lerpf(tail, tip, 0.4), thickness * 1.2), Vector2(lerpf(tail, tip, 0.9), thickness * 1.2), sc, 1.0)

	# 날 끝 별빛 (처음 순간에만)
	if _t < 0.4:
		var g := 1.0 - _t / 0.4
		var cc := _with_alpha(core_color, g)
		var tp := Vector2(tip, 0.0)
		draw_line(tp - Vector2(16.0 * g, 0.0), tp + Vector2(16.0 * g, 0.0), cc, 2.0, true)
		draw_line(tp - Vector2(0.0, 9.0 * g), tp + Vector2(0.0, 9.0 * g), cc, 2.0, true)


## tail→tip 칼날 모양을 구간별 사각형으로 직접 그린다 (아주 가늘어져도 삼각분할이 깨지지 않는다).
## 위쪽이 아래보다 조금 더 부풀어 휘두른 방향감이 생긴다. u = 2/3에서 가장 두껍고 양 끝은 0.
func _draw_blade(tail: float, tip: float, thick: float, col: Color) -> void:
	var steps := 12
	var cols := PackedColorArray([col, col, col, col])
	var prev := _blade_edge(tail, tip, thick, 0.0)
	for i in range(1, steps + 1):
		var cur := _blade_edge(tail, tip, thick, float(i) / steps)
		draw_primitive(PackedVector2Array([prev[0], cur[0], cur[1], prev[1]]), cols, PackedVector2Array())
		prev = cur


func _blade_edge(tail: float, tip: float, thick: float, u: float) -> PackedVector2Array:
	var x := lerpf(tail, tip, u)
	var h := thick * 0.5 * (u * u * (1.0 - u)) / 0.148
	return PackedVector2Array([Vector2(x, -h), Vector2(x, h * 0.45)])


func _with_alpha(c: Color, mul: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * mul)
