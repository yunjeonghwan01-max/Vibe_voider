class_name KnightCross
extends Node2D

## 역반격 창 연출 — 월식의 기사의 반격 자세에 플레이어 공격이 걸린 순간, 세상이 거의 멈춘 동안(window초, 실제 시간)
## 화면이 어두워지고 부딪힌 자리에 거대한 금·은빛 X자 문장이 번쩍 새겨진다. 바깥 고리가 X자로 좁혀 들며
## 남은 시간을 보여 준다. 데미지는 없다 — 순수 연출. 세상이 느려도 실제 시간으로 흐른다 (XSlash와 같은 방식).
##   shatter(): 플레이어가 받아쳤다 — X자가 금빛 조각으로 산산이 부서진다.
##   expire():  창이 닫혔다 — X자가 붉게 식으며 사라진다 (기사는 순간이동 내려찍기로 이어 간다).
## 보스만 쓴다. 스폰한 쪽이 끝을 알려 주지 못해도(사라짐 등) 스스로 expire 한다.

enum End { NONE, SHATTER, EXPIRE }

const STROKE_TIME := 0.06
const DIM_IN := 0.06
const OUT_TIME := 0.32
const SHARDS_PER_STROKE := 6

@export var size: float = 190.0                                   # 획 하나의 반 길이
@export var gold: Color = Color(1.0, 0.8, 0.32, 1.0)
@export var silver: Color = Color(0.82, 0.9, 1.0, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 0.94, 1.0)
@export var expire_color: Color = Color(1.0, 0.25, 0.22, 1.0)
@export var dim_alpha: float = 0.5

@onready var dim: ColorRect = $Dim
@onready var sfx: AudioStreamPlayer2D = $Audio/TimeStop

## 스폰하는 쪽이 add_child 전에 채운다: 받아칠 수 있는 시간(실제 초).
var window: float = 0.5

var _t: float = 0.0
var _last_us: int = 0
var _end: int = End.NONE
var _end_t: float = 0.0
var _shards: Array[Dictionary] = []      # 부서진 조각: a, b(획 위 구간), vel, spin, col


func _ready() -> void:
	_last_us = Time.get_ticks_usec()
	sfx.play()


func shatter() -> void:
	if _end != End.NONE:
		return
	_end = End.SHATTER
	_end_t = _t
	var dirs := [Vector2(-1.0, -1.0).normalized(), Vector2(1.0, -1.0).normalized()]
	for k in 2:
		var d: Vector2 = dirs[k] * size
		for i in SHARDS_PER_STROKE:
			var a := d.lerp(-d, float(i) / SHARDS_PER_STROKE)
			var b := d.lerp(-d, float(i + 1) / SHARDS_PER_STROKE)
			var mid := (a + b) * 0.5
			var out := mid.normalized() if mid.length() > 1.0 else Vector2.from_angle(randf() * TAU)
			_shards.append({
				"a": a - mid, "b": b - mid, "mid": mid,
				"vel": (out * randf_range(500.0, 900.0)).rotated(randf_range(-0.4, 0.4)),
				"spin": randf_range(-14.0, 14.0),
				"col": gold if k == 0 else silver,
			})


func expire() -> void:
	if _end != End.NONE:
		return
	_end = End.EXPIRE
	_end_t = _t


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_t += (now - _last_us) / 1000000.0
	_last_us = now
	if _end == End.NONE and _t >= window + 1.0:
		expire()                          # 안전장치 — 끝을 알려 줄 쪽이 사라졌다
	var out := 0.0 if _end == End.NONE else clampf((_t - _end_t) / OUT_TIME, 0.0, 1.0)
	if out >= 1.0:
		queue_free()
		return
	dim.color.a = dim_alpha * minf(_t / DIM_IN, 1.0) * (1.0 - out)
	queue_redraw()


func _draw() -> void:
	var d1 := Vector2(-1.0, -1.0).normalized() * size      # ＼ 시작점 (왼쪽 위)
	var d2 := Vector2(1.0, -1.0).normalized() * size       # ／ 시작점 (오른쪽 위)
	match _end:
		End.SHATTER:
			_draw_shatter()
			return
		End.EXPIRE:
			var u := clampf((_t - _end_t) / OUT_TIME, 0.0, 1.0)
			var s := 1.0 - 0.35 * u
			var a := 1.0 - u
			_draw_stroke(d1 * s, -d1 * s, 1.0, s, a, gold.lerp(expire_color, minf(u * 3.0, 1.0)))
			_draw_stroke(d2 * s, -d2 * s, 1.0, s, a, silver.lerp(expire_color, minf(u * 3.0, 1.0)))
			return

	var pulse := 1.0 + 0.1 * sin(_t * 38.0)
	_draw_stroke(d1, -d1, clampf(_t / STROKE_TIME, 0.0, 1.0), pulse, 1.0, gold)
	_draw_stroke(d2, -d2, clampf((_t - STROKE_TIME) / STROKE_TIME, 0.0, 1.0), pulse, 1.0, silver)

	# 새겨지는 순간의 하얀 섬광
	if _t < 0.18:
		var f := 1.0 - _t / 0.18
		draw_circle(Vector2.ZERO, 70.0 * f, Color(1, 1, 1, 0.9 * f))

	# 남은 시간 고리: 바깥에서 X자 중심으로 좁혀 든다. 끝이 가까울수록 밝고 빠르게 깜빡인다.
	var k := clampf(_t / window, 0.0, 1.0)
	var r := lerpf(size * 1.55, size * 0.4, k)
	var blink := 0.6 + 0.4 * sin(_t * lerpf(18.0, 60.0, k))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(gold.r, gold.g, gold.b, (0.35 + 0.5 * k) * blink), 3.0 + 4.0 * k)
	for i in 8:
		var ang := TAU * i / 8.0 + _t * 1.5
		var p := Vector2.from_angle(ang)
		draw_line(p * (r - 10.0), p * (r + 10.0), Color(core_color.r, core_color.g, core_color.b, 0.7 * blink), 2.0)


func _draw_shatter() -> void:
	var e := _t - _end_t
	var u := clampf(e / OUT_TIME, 0.0, 1.0)
	var a := 1.0 - u
	for sh in _shards:
		var c: Vector2 = sh.mid + sh.vel * e
		draw_set_transform(c, sh.spin * e, Vector2.ONE)
		_draw_stroke(sh.a, sh.b, 1.0, 0.8 * (1.0 - 0.5 * u), a, sh.col)
	draw_set_transform(Vector2.ZERO)
	# 깨지는 순간의 섬광 + 퍼지는 금빛 고리
	if u < 0.6:
		var f := 1.0 - u / 0.6
		draw_circle(Vector2.ZERO, 90.0 * f, Color(1, 1, 1, 0.95 * f))
		draw_arc(Vector2.ZERO, size * (0.4 + 1.6 * (1.0 - f)), 0.0, TAU, 64, Color(gold.r, gold.g, gold.b, f), 10.0 * f + 1.0)


## a→b 획을 progress만큼 그린다. 가운데가 두껍고 양 끝이 뾰족한 칼날 모양을 3겹(빛·몸·코어)으로.
func _draw_stroke(a: Vector2, b: Vector2, progress: float, thick_mul: float, alpha: float, col: Color) -> void:
	if progress <= 0.0 or alpha <= 0.0:
		return
	var tip := a.lerp(b, 1.0 - pow(1.0 - progress, 3.0))
	_blade(a, tip, 64.0 * thick_mul, Color(col.r, col.g, col.b, 0.35 * alpha))
	_blade(a, tip, 26.0 * thick_mul, Color(col.r, col.g, col.b, alpha))
	_blade(a, tip, 6.0 * thick_mul, Color(core_color.r, core_color.g, core_color.b, alpha))


func _blade(a: Vector2, b: Vector2, thick: float, col: Color) -> void:
	var steps := 12
	var n := (b - a).normalized().orthogonal()
	var cols := PackedColorArray([col, col, col, col])
	var prev_c := a
	var prev_h := 0.0
	for i in range(1, steps + 1):
		var u := float(i) / steps
		var c := a.lerp(b, u)
		var h := thick * 0.5 * pow(sin(PI * u), 0.6)
		draw_primitive(PackedVector2Array([prev_c + n * prev_h, c + n * h, c - n * h, prev_c - n * prev_h]),
				cols, PackedVector2Array())
		prev_c = c
		prev_h = h
