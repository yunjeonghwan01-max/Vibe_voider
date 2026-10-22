class_name DashSlashEffect
extends Node2D

## 대시 참격 궤적 — 길고 선명한 수평 칼빛. 외부 이미지 없이 _draw로 그린다.
##   날 끝이 거의 순간적으로 쭉 뻗고(끝점에서 큰 별빛 + 퍼지는 고리), 꼬리가 뒤따라오며 칼빛을 지운다.
##   칼빛은 4겹(넓은 빛 → 보라 날 → 흰 날 → 면도날 같은 흰 심)이라 어떤 배경에서도 또렷하다.
##   위아래로 평행한 잔상 칼빛이 살짝 늦게 따라오고, 칼빛이 지나간 자리에는 가는 "베어낸 자국"이 잠시 남는다.
##   길이를 따라 작은 불티가 흩날린다.
## 좌우는 setup(facing)의 scale.x로 정한다 (반전 노드에 종속되지 않게 값으로 받는다).

@export var glow_color: Color = Color(0.62, 0.3, 1.0, 0.4)
@export var color: Color = Color(0.8, 0.6, 1.0, 1.0)
@export var bright_color: Color = Color(0.97, 0.92, 1.0, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var length: float = 270.0            # 참격 판정 끝(+적 몸통)과 맞춘 길이
@export var thickness: float = 24.0
@export var lifetime: float = 0.32

var _t: float = 0.0                # 0..1 진행도
var _motes: Array[Vector3] = []    # 불티 (길이 위 위치 0..1, 위/아래, 흩어지는 속도)


func _ready() -> void:
	for i in 14:
		_motes.append(Vector3(randf(), -1.0 if randf() < 0.5 else 1.0, randf_range(30.0, 90.0)))


func setup(facing: float) -> void:
	scale = Vector2(signf(facing) if facing != 0.0 else 1.0, 1.0)


func _process(delta: float) -> void:
	_t += delta / maxf(lifetime, 0.0001)
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var tip := length * (1.0 - pow(1.0 - minf(_t * 5.0, 1.0), 3.0))   # 처음 순간에 끝까지 뻗는다
	var tail := length * pow(clampf((_t - 0.3) / 0.7, 0.0, 1.0), 1.2)  # 잠시 온전히 머문 뒤 꼬리가 따라와 지운다
	var fade := 1.0 - _t
	var thin := sqrt(fade)                                              # 사라지며 가늘어진다

	# 베어낸 자국: 칼빛이 지나간 전체 길이에 가는 선이 남아 천천히 사라진다
	draw_line(Vector2.ZERO, Vector2(tip, 0.0), _a(bright_color, 0.7 * fade), 3.0)

	# 본 칼빛 4겹
	if tip - tail > 2.0:
		_blade(tail, tip, 0.0, thickness * 2.4 * thin, _a(glow_color, fade))
		_blade(tail, tip, 0.0, thickness * thin, _a(color, fade))
		_blade(tail, tip, 0.0, thickness * 0.5 * thin, _a(bright_color, fade))
		draw_line(Vector2(lerpf(tail, tip, 0.15), -1.0), Vector2(tip, -1.0), _a(core_color, fade), 3.0)

	# 평행 잔상 칼빛 (살짝 늦게, 더 짧고 가늘게)
	var echo_tip := length * 0.9 * (1.0 - pow(1.0 - clampf((_t - 0.06) * 4.0, 0.0, 1.0), 3.0))
	var echo_tail := maxf(tail, echo_tip * 0.2)
	if echo_tip - echo_tail > 2.0:
		for off in [-thickness * 1.3, thickness * 1.1]:
			_blade(echo_tail, echo_tip, off, thickness * 0.4 * thin, _a(color, 0.65 * fade))
			draw_line(Vector2(lerpf(echo_tail, echo_tip, 0.3), off), Vector2(echo_tip, off), _a(bright_color, 0.65 * fade), 1.5)

	# 불티: 칼빛을 따라 위아래로 흩날린다
	for m in _motes:
		var x := m.x * tip
		if x < tail * 0.8:
			continue
		var y := m.y * (5.0 + m.z * _t)
		draw_rect(Rect2(Vector2(x, y) - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), _a(bright_color, fade))

	# 끝점: 큰 별빛 + 퍼지는 고리 (처음 순간)
	if _t < 0.45:
		var g := 1.0 - _t / 0.45
		var tp := Vector2(tip, 0.0)
		var cc := _a(core_color, g)
		draw_line(tp - Vector2(34.0 * g, 0.0), tp + Vector2(34.0 * g, 0.0), cc, 3.0)
		draw_line(tp - Vector2(0.0, 20.0 * g), tp + Vector2(0.0, 20.0 * g), cc, 3.0)
		draw_circle(tp, 7.0 * g, cc)
		draw_arc(tp, 10.0 + 46.0 * (1.0 - g), 0.0, TAU, 28, _a(color, g), 3.0 * g + 1.0)


## tail→tip 칼날 모양 (높이 y 기준): 앞쪽 2/3 지점이 가장 두껍고 양 끝은 뾰족하다.
## 위쪽이 아래보다 더 부풀어 휘두른 방향감이 생긴다. 아주 가늘어져도 깨지지 않게 사각형으로 직접 그린다.
func _blade(tail: float, tip: float, y: float, thick: float, col: Color) -> void:
	var steps := 14
	var cols := PackedColorArray([col, col, col, col])
	var prev := _edge(tail, tip, y, thick, 0.0)
	for i in range(1, steps + 1):
		var cur := _edge(tail, tip, y, thick, float(i) / steps)
		draw_primitive(PackedVector2Array([prev[0], cur[0], cur[1], prev[1]]), cols, PackedVector2Array())
		prev = cur


func _edge(tail: float, tip: float, y: float, thick: float, u: float) -> PackedVector2Array:
	var x := lerpf(tail, tip, u)
	var h := thick * 0.5 * (u * u * (1.0 - u)) / 0.148
	return PackedVector2Array([Vector2(x, y - h), Vector2(x, y + h * 0.5)])


func _a(c: Color, mul: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(mul, 0.0, 1.0))
