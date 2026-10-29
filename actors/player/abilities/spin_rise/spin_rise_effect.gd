class_name SpinRiseEffect
extends Node2D

## 회전 상승 이펙트 — 플레이어 몸을 감싸고 위로 휘감아 오르는 보라·흰빛 소용돌이. 외부 이미지 없이 _draw로 그린다.
## 각진 외곽선 없이 세 겹으로 부드럽게 쌓는다:
##   1) 빛무리: 위로 갈수록 가늘어지는 물방울 모양을 반투명 원을 겹겹이 쌓아 그라데이션처럼 칠한다.
##   2) 리본: 나선으로 휘감기는 빛줄기 여러 가닥. 앞쪽을 지날 땐 희고 굵게, 뒤쪽은 보랏빛으로 가늘고 흐리게.
##   3) 입자: 밑동에서 흩날려 아래로 흘러내리는 빛 알갱이 (상승하는 몸 뒤에 꼬리처럼 남는다).
## form_in(초)로 작은 빛에서 피어나고, break_out(초)로 바깥으로 풀리며 사라진다.
## 회전 노드(Visual)에 종속되지 않게 반전되지 않는 Combat 아래에 둔다.

@export var purple: Color = Color(0.6, 0.36, 1.0, 1.0)
@export var lavender: Color = Color(0.84, 0.74, 1.0, 1.0)
@export var white: Color = Color(1.0, 0.98, 1.0, 1.0)
@export var tip_y: float = -88.0          # 소용돌이 끝 (몸 중심 기준 위쪽)
@export var base_y: float = 32.0          # 밑동 (발보다 살짝 아래 — 몸이 완전히 잠긴다)
@export var base_half_width: float = 36.0
@export var strands: int = 5              # 휘감기는 리본 가닥 수
@export var twist: float = 1.6            # 아래→위로 리본이 감기는 바퀴 수
@export var spin_speed: float = 2.6       # 회전 속도 (바퀴/초)
@export var particles_per_second: float = 70.0

enum Mode { HIDDEN, FORMING, ON, BREAKING }

const SAMPLES := 20

var _mode: int = Mode.HIDDEN
var _t: float = 0.0
var _dur: float = 0.1
var _amount: float = 0.0     # 0..1 크기/불투명도
var _spin: float = 0.0
var _spawn_acc: float = 0.0
var _parts: Array[Dictionary] = []


func _ready() -> void:
	visible = false


func form_in(duration: float) -> void:
	_mode = Mode.FORMING
	_t = 0.0
	_dur = maxf(duration, 0.001)
	_amount = 0.0
	_parts.clear()
	visible = true


func break_out(duration: float) -> void:
	if _mode == Mode.HIDDEN:
		return
	_mode = Mode.BREAKING
	_t = 0.0
	_dur = maxf(duration, 0.001)
	# 풀릴 때 빛 알갱이가 사방으로 흩어진다
	for i in 14:
		var ang := randf() * TAU
		_spawn_particle(Vector2(cos(ang) * base_half_width * 0.6, lerpf(tip_y, base_y, randf())),
				Vector2(cos(ang), sin(ang) - 0.4) * randf_range(60.0, 160.0))


func hide_now() -> void:
	_mode = Mode.HIDDEN
	_parts.clear()
	visible = false


func _process(delta: float) -> void:
	if _mode == Mode.HIDDEN:
		return
	_t += delta
	_spin += delta * spin_speed
	match _mode:
		Mode.FORMING:
			var u := clampf(_t / _dur, 0.0, 1.0)
			_amount = 1.0 - pow(1.0 - u, 3.0)
			if u >= 1.0:
				_mode = Mode.ON
		Mode.ON:
			_amount = 1.0
		Mode.BREAKING:
			_amount = 1.0 - clampf(_t / _dur, 0.0, 1.0)

	if _mode != Mode.BREAKING:
		_spawn_acc += delta * particles_per_second * _amount
		while _spawn_acc >= 1.0:
			_spawn_acc -= 1.0
			var side := randf_range(-1.0, 1.0)
			_spawn_particle(Vector2(side * base_half_width * 0.9, base_y - randf() * 30.0),
					Vector2(side * randf_range(20.0, 70.0), randf_range(140.0, 300.0)))
	_update_particles(delta)

	if _mode == Mode.BREAKING and _amount <= 0.0 and _parts.is_empty():
		hide_now()
		return
	queue_redraw()


func _spawn_particle(pos: Vector2, vel: Vector2) -> void:
	_parts.append({
		"p": pos, "v": vel, "life": 0.0,
		"max": randf_range(0.22, 0.42),
		"r": randf_range(1.6, 3.6),
		"white": randf() < 0.45,
	})


func _update_particles(delta: float) -> void:
	for i in range(_parts.size() - 1, -1, -1):
		var q: Dictionary = _parts[i]
		q.life += delta
		if q.life >= q.max:
			_parts.remove_at(i)
			continue
		q.v *= 1.0 - 3.0 * delta          # 공기 저항 — 흩날리다 멈춘다
		q.p += q.v * delta


## 아래(u=0)에서 위(u=1)로 갈수록 가늘어지는 물방울 윤곽 반폭.
func _radius(u: float) -> float:
	var body := pow(1.0 - u, 0.62)
	var round_base := sqrt(clampf(u / 0.12, 0.0, 1.0)) * 0.35 + 0.65   # 밑동을 둥글게 오므린다
	return base_half_width * body * round_base


func _draw() -> void:
	var a := _amount
	var open := 1.0                            # 풀릴 때 바깥으로 벌어진다
	if _mode == Mode.BREAKING:
		open = 1.0 + (1.0 - a) * 0.9
	var tip := lerpf(base_y - 20.0, tip_y, a if _mode != Mode.BREAKING else 1.0)
	var height := base_y - tip
	var breathe := 1.0 + 0.06 * sin(_spin * TAU * 1.7)

	if a > 0.0 and height > 2.0:
		# 1) 빛무리 — 반투명 원을 겹겹이 쌓아 경계 없이 번지게
		for k in 16:
			var u := float(k) / 15.0
			var y := base_y - height * u
			var r := _radius(u) * open * breathe
			draw_circle(Vector2(0.0, y), r * 1.5 + 6.0, _with(purple, 0.05 * a))
			draw_circle(Vector2(0.0, y), r * 1.05, _with(purple, 0.07 * a))
			draw_circle(Vector2(0.0, y), r * 0.55, _with(lavender, 0.08 * a))
			draw_circle(Vector2(0.0, y), r * 0.22, _with(white, 0.1 * a))

		# 2) 리본 — 뒤쪽 가닥을 먼저, 앞쪽 가닥을 나중에 그려 감싸는 깊이감을 만든다
		for pass_front in [false, true]:
			for s in strands:
				_draw_strand(s, tip, height, open * breathe, a, pass_front)

		# 끝머리의 부드러운 빛
		var tp := Vector2(0.0, tip + 4.0)
		draw_circle(tp, 11.0, _with(lavender, 0.25 * a))
		draw_circle(tp, 6.0, _with(white, 0.55 * a))
		draw_circle(tp, 3.0, _with(white, 0.95 * a))

	# 3) 입자
	for q in _parts:
		var f: float = 1.0 - float(q.life) / float(q.max)
		var c: Color = white if q.white else lavender
		draw_circle(q.p, float(q.r) * (0.5 + 0.5 * f) * 2.2, _with(purple, 0.18 * f))
		draw_circle(q.p, float(q.r) * (0.5 + 0.5 * f), _with(c, 0.9 * f))


func _draw_strand(s: int, tip: float, height: float, scale_r: float, a: float, front_pass: bool) -> void:
	var phase := float(s) / strands * TAU + _spin * TAU
	var prev := Vector2.ZERO
	var prev_depth := 0.0
	for i in range(SAMPLES + 1):
		var u := float(i) / SAMPLES
		var ang := phase + u * twist * TAU
		var r := _radius(u) * scale_r * (0.75 + 0.25 * sin(u * 9.0 + _spin * 5.0 + s))   # 가닥마다 살짝 출렁인다
		var p := Vector2(sin(ang) * r, base_y - height * u)
		var depth := cos(ang)                      # +1 = 앞, -1 = 뒤
		if i > 0:
			var d := (depth + prev_depth) * 0.5
			if (d >= 0.0) == front_pass:
				var k := d * 0.5 + 0.5               # 0 = 뒤, 1 = 앞
				var ends := sin(u * PI)               # 양 끝은 가늘고 흐리게 사라진다
				var col := purple.lerp(lavender, k).lerp(white, k * k)
				var w := (1.2 + 3.6 * k) * (0.35 + 0.65 * ends)
				draw_line(prev, p, _with(purple, 0.22 * a * ends), w * 2.6, true)   # 은은한 번짐
				draw_line(prev, p, _with(col, (0.35 + 0.6 * k) * a * ends), w, true)
		prev = p
		prev_depth = depth


func _with(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))
