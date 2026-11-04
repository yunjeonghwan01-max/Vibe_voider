class_name PrinceWave
extends WatcherNeedle

## 왕자의 원거리 검격 — 지면을 따라 수평으로 날아가며 점점 빨라지는 실제 투사체 (PRCI 대상).
## 충돌·피격·튕겨내기는 WatcherNeedle을 그대로 쓴다: "deflectable" 그룹, 플레이어에게 deflect_range 안으로
## 다가오는 짧은 순간에만 금빛으로 빛나고(is_deflectable), 그때 반격 키를 누르면 Player가 deflect()로 지운다.
## 추적·복수탄 없음. 수치는 스폰하는 왕자가 add_child 전에 채운다 (prince_tuning.cfg) — 이 씬에는 수치 파일이 없다.

const HALF_HEIGHT := 30.0

var accel: float = 1400.0
var max_speed: float = 1150.0


func _physics_process(delta: float) -> void:
	speed = minf(speed + accel * delta, max_speed)
	super._physics_process(delta)


func _draw() -> void:
	var k := clampf(speed / maxf(max_speed, 1.0), 0.0, 1.0)
	var tail := -40.0 - 90.0 * k
	# 뒤로 끌리는 초록 잔광
	draw_colored_polygon(PackedVector2Array([Vector2(tail, 0.0), Vector2(-6.0, -HALF_HEIGHT * 0.8), Vector2(-6.0, HALF_HEIGHT * 0.8)]),
			Color(0.35, 0.95, 0.5, 0.22))
	if _glint:
		# 지울 수 있는 순간: 금빛 테두리가 켜진다 (켜지는 순간 조금 더 크게)
		var pop := 1.0 + 0.4 * maxf(1.0 - _glint_t * 20.0, 0.0)
		draw_circle(Vector2(6.0, 0.0), 44.0 * pop, Color(1.0, 0.93, 0.58, 0.26))
		draw_arc(Vector2(6.0, 0.0), 38.0 * pop, 0.0, TAU, 32, Color(1.0, 0.93, 0.58, 0.95), 3.0)
	# 초승달 검격: 바깥 초록 → 안쪽 흰 날
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 13:
		var a := lerpf(-1.25, 1.25, i / 12.0)
		outer.append(Vector2(cos(a) * 26.0 - 8.0, sin(a) * HALF_HEIGHT))
		inner.append(Vector2(cos(a) * 10.0 - 8.0, sin(a) * (HALF_HEIGHT - 3.0)))
	var body := outer.duplicate()
	var core := PackedVector2Array()
	for i in range(12, -1, -1):
		body.append(inner[i])
		core.append(Vector2(lerpf(inner[i].x, outer[i].x, 0.55), inner[i].y))
	for i in 13:
		core.append(outer[i])
	draw_colored_polygon(body, Color(0.32, 0.9, 0.48, 0.95))
	draw_colored_polygon(core, Color(0.9, 1.0, 0.92, 1.0))
