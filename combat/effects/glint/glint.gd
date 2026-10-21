class_name GlintEffect
extends Node2D

## 적 공격 직전의 "반짝!" — 4갈래 별빛이 커지며 돌다가 사라진다.
## 이 별이 떠 있는 시간(lifetime) = 패링 가능한 시간. 적이 begin_glint에서 길이를 맞춘다.

@export var color: Color = Color(1.0, 0.92, 0.55, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var size: float = 30.0

var lifetime: float = 0.4
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta / maxf(lifetime, 0.0001)
	if _t >= 1.0:
		queue_free()
		return
	rotation += delta * 2.5
	queue_redraw()


func _draw() -> void:
	# 처음엔 확 커지고(팝), 끝으로 갈수록 빠르게 줄어든다.
	var pop := minf(_t / 0.12, 1.0)
	var k := (1.0 - pow(1.0 - pop, 3.0)) * (1.0 - pow(_t, 4.0))
	var pulse := 1.0 + 0.15 * sin(_t * 40.0)
	var r := size * k * pulse
	for i in 4:
		var dir := Vector2.from_angle(i * PI * 0.5)
		var side := dir.orthogonal() * r * 0.16
		draw_colored_polygon(PackedVector2Array([dir * r, side, -dir * r * 0.0, -side]), color)
	for i in 4:
		var dir := Vector2.from_angle(PI * 0.25 + i * PI * 0.5)
		var side := dir.orthogonal() * r * 0.08
		draw_colored_polygon(PackedVector2Array([dir * r * 0.5, side, -side]), color)
	draw_circle(Vector2.ZERO, r * 0.22, core_color)
	var ring := color
	ring.a = 0.6 * (1.0 - _t)
	draw_arc(Vector2.ZERO, r * 0.8 + 10.0 * _t, 0.0, TAU, 24, ring, 2.0, true)
