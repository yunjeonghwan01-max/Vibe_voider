class_name SlashEffect
extends Node2D

## 검격 궤적 VFX. 외부 이미지 없이 _draw로 초승달(crescent) 호를 그린다.
## 순간적으로 나타났다가 살짝 늘어나며 빠르게 사라진다 → 빠르고 날카로운 참격 느낌.
## 방향/각도는 노드의 rotation과 scale.x(좌우 반전)로 지정한다 (반전 노드에 종속되지 않게 값으로 받는다).

@export var color: Color = Color(0.78, 0.45, 1.0, 0.9)      # 보라빛 궤적 (주인공 스카프 톤)
@export var core_color: Color = Color(1.0, 0.98, 1.0, 1.0)  # 밝은 코어
@export var outer_radius: float = 78.0
@export var inner_radius: float = 34.0
@export var arc_degrees: float = 115.0
@export var lifetime: float = 0.16

var _t: float = 0.0  # 0..1 진행도


## facing: +1 오른쪽 / -1 왼쪽. aim_degrees: 궤적 중심 각도(도). spread: 호 크기 배율.
func setup(facing: float, aim_degrees: float = 0.0, scale_mul: float = 1.0) -> void:
	scale = Vector2(signf(facing) if facing != 0.0 else 1.0, 1.0) * scale_mul
	rotation = deg_to_rad(aim_degrees)


func _process(delta: float) -> void:
	_t += delta / maxf(lifetime, 0.0001)
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _t
	# 살짝 커지며 사라진다.
	var grow := 1.0 + _t * 0.3
	var outer := outer_radius * grow
	var inner := inner_radius * grow
	var half_span := deg_to_rad(arc_degrees) * 0.5
	var steps := 14

	var pts := PackedVector2Array()
	for i in steps + 1:
		var a: float = lerp(-half_span, half_span, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * outer)
	for i in steps + 1:
		var a: float = lerp(half_span, -half_span, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * inner)

	var c := color
	c.a = color.a * fade
	draw_colored_polygon(pts, c)

	# 밝은 바깥 코어 선 — 날의 번뜩임.
	var edge := PackedVector2Array()
	var core_r := outer * 0.97
	for i in steps + 1:
		var a: float = lerp(-half_span, half_span, float(i) / steps)
		edge.append(Vector2(cos(a), sin(a)) * core_r)
	var cc := core_color
	cc.a = core_color.a * fade * fade
	draw_polyline(edge, cc, 3.0, true)
