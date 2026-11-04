class_name PrinceQuake
extends Node2D

## 천지분쇄 일격(패턴 4)의 신호·지면 연출. 겉모습만 맡는다 — 판정과 피해는 Prince가 정한다.
## 고리(ring): 플레이어 둘레에서 조여들어 몸에 닿는 순간이 곧 충격 순간이다. 어디를 보고 있어도 읽히는 큰 FLASH.
## 빛기둥(pillars): 지면 전체에서 초록빛이 솟는다 (2차 충격).
## 글자·UI 없이 이펙트만 쓴다. 입력 순간: 빛의 창들이 고리와 함께 플레이어로 모여들고 몸이 달아오른다.
## 눌렀으면 흰빛 막이 몸을 감싼다. 결과(result): 막으면 충격파 + 파편 + 지면을 양쪽으로 가르는 빛,
## 못 막으면 지면에서 솟은 붉은 번개가 몸을 꿰뚫고 붉은 파편이 튄다.

const RESULT_TIME := 0.7
const CUE := Color(1.0, 0.93, 0.58)
const OK_COLOR := Color(0.55, 1.0, 0.65)
const FAIL_COLOR := Color(1.0, 0.25, 0.22)

## 스폰하는 쪽이 add_child 전에 채운다.
var target: Node2D = null
var room_x: Vector2 = Vector2(-680.0, 680.0)
var floor_y: float = 0.0

var _ring_t: float = 0.0
var _ring_time: float = 0.0
var _ring_size: float = 0.0
var _pillar_t: float = 0.0
var _pillar_time: float = 0.0
var _pillar_x: Array[float] = []
var _clock: float = 0.0
var _locked: bool = false
var _index: int = 0
var _result_t: float = -1.0             # 결과 연출 경과 (음수 = 없음)
var _result_ok: bool = false
var _result_at: Vector2 = Vector2.ZERO


func _ready() -> void:
	global_position = Vector2.ZERO
	var x := room_x.x
	while x < room_x.y:
		_pillar_x.append(x + randf_range(-14.0, 14.0))
		x += 68.0


## 조여드는 고리. size = 시작 반지름 (클수록 더 큰 신호).
func ring(duration: float, size: float, index: int) -> void:
	_index = index
	_locked = false
	_ring_t = 0.0
	_ring_time = duration
	_ring_size = size


## 지면 전체에서 빛이 솟았다가 duration 뒤 사라진다.
func pillars(duration: float) -> void:
	_pillar_t = 0.0
	_pillar_time = duration


func clear_ring() -> void:
	_ring_time = 0.0


## 이번 회차 입력이 들어갔다 — 충격이 올 때까지 고리가 흰빛으로 잠긴다.
func lock_ring() -> void:
	_locked = true


## 충격 순간의 성패 연출.
func result(blocked: bool) -> void:
	_result_ok = blocked
	_result_t = 0.0
	if target != null and is_instance_valid(target):
		_result_at = target.global_position


func _process(delta: float) -> void:
	_clock += delta
	if _ring_time > 0.0:
		_ring_t += delta
		if _ring_t >= _ring_time:
			_ring_time = 0.0
	if _result_t >= 0.0:
		_result_t += delta
		if _result_t >= RESULT_TIME:
			_result_t = -1.0
	if _pillar_time > 0.0:
		_pillar_t += delta
		if _pillar_t >= _pillar_time:
			_pillar_time = 0.0
	queue_redraw()


func _draw() -> void:
	if _pillar_time > 0.0:
		var u := _pillar_t / _pillar_time
		var grow := minf(u * 2.2, 1.0)
		var fade := 1.0 - maxf(u - 0.6, 0.0) / 0.4
		for i in _pillar_x.size():
			var h := (150.0 + 90.0 * sin(float(i) * 2.3 + _clock * 9.0)) * grow
			var x := _pillar_x[i]
			draw_rect(Rect2(x - 15.0, floor_y - h, 30.0, h), Color(0.3, 1.0, 0.5, 0.22 * fade))
			draw_rect(Rect2(x - 5.0, floor_y - h, 10.0, h), Color(0.85, 1.0, 0.88, 0.75 * fade))
	if target == null or not is_instance_valid(target):
		return
	var p := target.global_position
	if _ring_time > 0.0:
		_draw_cue(p)
	if _result_t >= 0.0:
		_draw_result()


func _draw_cue(p: Vector2) -> void:
	var k := clampf(_ring_t / _ring_time, 0.0, 1.0)
	var r := lerpf(_ring_size, 40.0, k * k)
	if _locked:
		# 입력이 들어갔다: 흰빛 막이 몸을 감싸고 빛 알갱이가 돈다
		draw_circle(p, 46.0, Color(0.8, 1.0, 0.85, 0.28))
		draw_arc(p, 46.0, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.95), 5.0)
		for i in 6:
			var o := Vector2.from_angle(_clock * 9.0 + i * TAU / 6.0) * 46.0
			draw_circle(p + o, 5.0, Color(0.9, 1.0, 0.92, 0.95))
		return
	var pulse := 0.65 + 0.35 * sin(_clock * 42.0)
	# 몸이 달아오른다 (충격이 가까울수록 밝게)
	draw_circle(p, 44.0 + 30.0 * k, Color(CUE.r, CUE.g, CUE.b, 0.12 + 0.3 * k))
	draw_circle(p, 30.0, Color(1.0, 1.0, 0.9, 0.2 + 0.55 * k * k))
	draw_arc(p, r, 0.0, TAU, 56, Color(CUE.r, CUE.g, CUE.b, pulse), 11.0)
	draw_arc(p, r + 13.0, 0.0, TAU, 56, Color(0.4, 1.0, 0.55, 0.7 * pulse), 5.0)
	# 사방에서 몸으로 모여드는 빛의 창 — 뒤 회차일수록 많고 길다
	var spears := 10 + _index * 5
	for i in spears:
		var d := Vector2.from_angle(i * TAU / spears + 0.2 * sin(_clock * 3.0))
		var n := d.orthogonal() * (7.0 + 2.0 * _index)
		var tip := p + d * (r * 0.72)
		var back := p + d * (r + 70.0 + 40.0 * _index)
		draw_colored_polygon(PackedVector2Array([tip, back + n, back - n]), Color(1.0, 0.97, 0.75, 0.75 * pulse))


func _draw_result() -> void:
	var u := _result_t / RESULT_TIME
	var a := 1.0 - u * u
	var p := _result_at
	var scale_k := 1.0 + 0.3 * _index
	if _result_ok:
		var r := (40.0 + 300.0 * sqrt(u)) * scale_k
		draw_arc(p, r, 0.0, TAU, 56, Color(1.0, 1.0, 0.85, a), 12.0 * a + 2.0)
		draw_arc(p, r * 0.7, 0.0, TAU, 48, Color(OK_COLOR.r, OK_COLOR.g, OK_COLOR.b, a * 0.8), 6.0)
		draw_arc(p, 56.0, PI, TAU, 28, Color(1.0, 1.0, 1.0, a), 9.0)      # 충격을 받아 낸 방어막
		# 지면을 양쪽으로 가르는 빛
		var reach := 620.0 * sqrt(u)
		draw_line(Vector2(p.x - reach, floor_y - 3.0), Vector2(p.x + reach, floor_y - 3.0), Color(1.0, 1.0, 0.85, a), 7.0 * a + 1.0)
		for i in 18:
			var d := Vector2.from_angle(-PI * (float(i) + 0.5) / 18.0)    # 위쪽 반원으로 튀는 금빛 파편
			var q := p + d * (60.0 + (200.0 + 60.0 * sin(i * 2.1)) * sqrt(u)) * scale_k
			draw_line(q, q + d * 26.0 * a, Color(1.0, 0.95, 0.6, a), 5.0)
	else:
		draw_circle(p, (70.0 + 60.0 * u) * scale_k, Color(FAIL_COLOR.r, FAIL_COLOR.g, FAIL_COLOR.b, 0.32 * a))
		# 지면에서 솟아 몸을 꿰뚫는 번개 (시간에 따라 떨린다)
		for b in 5:
			var pts := PackedVector2Array()
			var x0 := p.x + (b - 2) * 46.0
			for j in 7:
				var v := j / 6.0
				var wob := sin(_clock * 50.0 + b * 3.0 + j * 2.0) * 16.0 * (1.0 - absf(v - 0.5))
				pts.append(Vector2(lerpf(x0, p.x, v) + wob, lerpf(floor_y, p.y - 90.0 - 40.0 * _index, v)))
			draw_polyline(pts, Color(FAIL_COLOR.r, FAIL_COLOR.g, FAIL_COLOR.b, a), 9.0)
			draw_polyline(pts, Color(1.0, 0.85, 0.75, a), 3.0)
		for i in 14:
			var d := Vector2.from_angle(i * TAU / 14.0 + 0.3)
			var q := p + d * (40.0 + 170.0 * sqrt(u)) * scale_k
			draw_line(q, q + d * 22.0 * a, Color(1.0, 0.35, 0.28, a), 5.0)
