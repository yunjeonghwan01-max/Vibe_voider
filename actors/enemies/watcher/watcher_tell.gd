class_name WatcherTell
extends Node2D

## 카유공 예고 연출 (반전되지 않도록 Watcher 루트 직속에 둔다). Watcher가 매 프레임 mode/progress/aim_point를 채운다.
## CHARGE: 금빛 불빛 입자들이 몸 중앙으로 빨려든다. progress(0→1)가 오를수록 빨라지고 많아지며, 중심 빛이 커진다.
## WINDOW: 몸에 거대한 + 모양 섬광이 맥동하고, 플레이어를 향한 가는 조준선이 깜빡인다 (= 지금 반격!).

enum Mode { OFF, CHARGE, WINDOW }

const MOTES := 34

@export var color: Color = Color(1.0, 0.86, 0.5, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 0.95, 1.0)

var mode: int = Mode.OFF:
	set(v):
		if v != mode:
			_mode_t = 0.0
		mode = v
		visible = v != Mode.OFF
var progress: float = 0.0
var aim_point: Vector2 = Vector2.ZERO   # 전역 좌표

var _mode_t: float = 0.0
var _cycle: float = 0.0                 # 입자 흐름 누적 (속도가 변해도 끊기지 않게)
var _seeds: Array[Vector3] = []         # (각도, 시작 반지름, 위상)


func _ready() -> void:
	visible = false
	for i in MOTES:
		_seeds.append(Vector3(randf() * TAU, randf_range(70.0, 150.0), float(i) / MOTES))


func _process(delta: float) -> void:
	if mode == Mode.OFF:
		return
	_mode_t += delta
	_cycle += delta * lerpf(0.5, 4.2, progress * progress)   # 점점 빠르게 모인다
	queue_redraw()


func _draw() -> void:
	match mode:
		Mode.CHARGE:
			_draw_charge()
		Mode.WINDOW:
			_draw_window()


func _draw_charge() -> void:
	var shown := int(lerpf(10.0, MOTES, progress))
	for i in shown:
		var s := _seeds[i]
		var ph := fmod(_cycle + s.z, 1.0)               # 0 = 바깥, 1 = 중심 도착
		var r := s.y * pow(1.0 - ph, 1.4)
		var a := s.x + ph * 2.2
		var p := Vector2.from_angle(a) * r
		var size := lerpf(3.0, 6.0, ph)
		var c := color
		c.a = minf(ph * 3.0, 1.0)
		# 은은한 번짐 + 밝은 알갱이
		draw_rect(Rect2(p - Vector2(size, size) * 1.1, Vector2(size, size) * 2.2), Color(c.r, c.g, c.b, c.a * 0.25))
		draw_rect(Rect2(p - Vector2(size, size) * 0.5, Vector2(size, size)), c)
		# 빨려드는 꼬리
		var tail := Vector2.from_angle(a - 0.3) * minf(r + 22.0, s.y)
		c.a *= 0.6
		draw_line(p, tail, c, 2.0)
	# 중심에 모이는 빛 (눈이 가려지지 않게 작게 시작해 끝에서만 커진다)
	var glow := lerpf(3.0, 14.0, progress * progress) * (1.0 + 0.15 * sin(_mode_t * (10.0 + 30.0 * progress)))
	draw_circle(Vector2.ZERO, glow * 2.0, Color(color.r, color.g, color.b, 0.1 + 0.15 * progress))
	draw_circle(Vector2.ZERO, glow, Color(core_color.r, core_color.g, core_color.b, 0.35 + 0.6 * progress))


func _draw_window() -> void:
	# + 섬광: 처음에 확 터지고(팝) 이후 강하게 맥동한다
	var pop := 1.0 - pow(1.0 - minf(_mode_t / 0.07, 1.0), 3.0)
	var pulse := 1.0 + 0.18 * sin(_mode_t * 55.0)
	var arm := 96.0 * pop * pulse
	var thick := 9.0 * pop
	for dir in [Vector2.RIGHT, Vector2.UP]:
		var d: Vector2 = dir
		var n := d.orthogonal()
		draw_colored_polygon(PackedVector2Array([d * arm, n * thick, -d * arm, -n * thick]),
				Color(color.r, color.g, color.b, 0.85))
		draw_colored_polygon(PackedVector2Array([d * arm * 0.7, n * thick * 0.4, -d * arm * 0.7, -n * thick * 0.4]),
				core_color)
	draw_circle(Vector2.ZERO, 26.0 * pop * pulse, Color(color.r, color.g, color.b, 0.35))
	draw_circle(Vector2.ZERO, 14.0 * pop, core_color)
	# 바깥으로 퍼지는 고리 (처음 순간)
	var ring_t := minf(_mode_t / 0.25, 1.0)
	draw_arc(Vector2.ZERO, 20.0 + 90.0 * ring_t, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - ring_t)), 3.0)
	# 조준선 (깜빡임)
	var to := to_local(aim_point)
	var flick := 0.35 + 0.35 * signf(sin(_mode_t * 70.0))
	draw_line(Vector2.ZERO, to, Color(1.0, 0.5, 0.35, flick), 1.5)
