class_name CounterSlash
extends Node2D

## 카유공 반격 성공의 결정타 — 대상 몸에 검보라색 거대한 X자 참격을 새긴다.
## 세상은 GameFeel로 거의 멈춰 있고, 이 연출만 실제 시간으로 흐른다 (그래서 소리와 획이 정확히 맞는다).
##   0.00  플레이어 → 대상으로 공허의 일섬(가는 선)이 번쩍
##   0.00  첫 획 ＼   0.07  둘째 획 ／   (counter_slash.wav의 두 번 가르는 소리와 맞춤)
##   0.14  결정타: target.receive_hit(damage) + 폭발 (같은 소리의 저음 타격과 맞춤)
##   이후  X자 흔적이 맥동하며 남았다가 사라진다.
## 데미지는 공격 쪽이 타이밍을 정하는 문법대로 receive_hit()을 직접 호출한다.

const STROKE_TIME := 0.07
const STRIKE_AT := 0.14
const LIFETIME := 1.0

@export var size: float = 155.0                                  # 획 하나의 반 길이
@export var glow_color: Color = Color(0.55, 0.18, 0.85, 0.55)
@export var body_color: Color = Color(0.2, 0.03, 0.32, 1.0)      # 검보라
@export var edge_color: Color = Color(0.82, 0.55, 1.0, 1.0)
@export var core_color: Color = Color(1.0, 0.95, 1.0, 1.0)
@export var spark_scene: PackedScene

@onready var sfx: AudioStreamPlayer2D = $Audio/Slash

## 스폰하는 쪽이 add_child 전에 채운다.
var target: HurtboxComponent = null
var source: Node = null
var damage: int = 999
var from_pos: Vector2 = Vector2.ZERO     # 반격한 플레이어 위치 (전역)

var _t: float = 0.0
var _last_us: int = 0
var _struck: bool = false
var _strike_t: float = 0.0


func _ready() -> void:
	_last_us = Time.get_ticks_usec()
	sfx.play()


func _process(_delta: float) -> void:
	# 실제 시간으로 진행 (hit-stop/슬로모션의 영향을 받지 않는다)
	var now := Time.get_ticks_usec()
	_t += (now - _last_us) / 1000000.0
	_last_us = now
	if not _struck and _t >= STRIKE_AT:
		_strike()
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _strike() -> void:
	_struck = true
	_strike_t = _t
	var dir := signf(global_position.x - from_pos.x)
	if dir == 0.0:
		dir = 1.0
	if is_instance_valid(target):
		target.receive_hit(damage, source, Vector2(dir * 260.0, -220.0))
	GameFeel.hit_stop(0.13)
	GameFeel.shake(1.0)
	GameFeel.flash(Color(0.4, 0.08, 0.6), 0.3, 0.35)
	if spark_scene == null:
		return
	for spec in [[Color(0.6, 0.25, 0.95, 1.0), 30, 160.0, 0.42], [Color(0.25, 0.05, 0.4, 1.0), 18, 120.0, 0.5],
			[Color(1.0, 0.92, 1.0, 1.0), 12, 200.0, 0.26]]:
		var s := spark_scene.instantiate() as SparkEffect
		get_parent().add_child(s)
		s.global_position = global_position
		s.burst(spec[0], spec[1], 360.0, 0.0, spec[2], spec[3])
		s.with_ring(spec[0], float(spec[2]) * 1.5)


func _draw() -> void:
	# 플레이어에게서 대상까지 공허의 일섬
	if _t < 0.12:
		var k := 1.0 - _t / 0.12
		var a := to_local(from_pos)
		draw_line(a, Vector2.ZERO, Color(glow_color.r, glow_color.g, glow_color.b, 0.6 * k), 14.0 * k)
		draw_line(a, Vector2.ZERO, Color(core_color.r, core_color.g, core_color.b, k), 2.0)

	var after := _t - STRIKE_AT                      # 결정타 이후 경과
	var fade := 1.0 if after < 0.0 else clampf(1.0 - after / (LIFETIME - STRIKE_AT), 0.0, 1.0)
	var swell := 1.0 if after < 0.0 else 1.0 + 0.25 * (1.0 - pow(1.0 - minf(after / 0.12, 1.0), 2.0))
	var pulse := 1.0 if after < 0.0 else 1.0 + 0.12 * sin(after * 30.0) * fade
	var d1 := Vector2(-1.0, -1.0).normalized() * size * swell      # ＼ 시작점 (왼쪽 위)
	var d2 := Vector2(1.0, -1.0).normalized() * size * swell       # ／ 시작점 (오른쪽 위)
	_draw_stroke(d1, -d1, clampf(_t / STROKE_TIME, 0.0, 1.0), fade * pulse, fade)
	_draw_stroke(d2, -d2, clampf((_t - STROKE_TIME) / STROKE_TIME, 0.0, 1.0), fade * pulse, fade)

	# 결정타 순간의 하얀 섬광 + 퍼지는 고리
	if after >= 0.0 and after < 0.35:
		var u := after / 0.35
		draw_circle(Vector2.ZERO, 60.0 * (1.0 - u), Color(1, 1, 1, 0.9 * (1.0 - u)))
		draw_arc(Vector2.ZERO, 40.0 + 220.0 * (1.0 - pow(1.0 - u, 3.0)), 0.0, TAU, 48,
				Color(edge_color.r, edge_color.g, edge_color.b, 1.0 - u), 8.0 * (1.0 - u) + 1.0)


## a→b 획을 progress만큼 그린다. 가운데가 두껍고 양 끝이 뾰족한 칼날 모양을 4겹(빛·검보라·테두리·코어)으로.
func _draw_stroke(a: Vector2, b: Vector2, progress: float, thick_mul: float, alpha: float) -> void:
	if progress <= 0.0 or alpha <= 0.0:
		return
	var reveal := 1.0 - pow(1.0 - progress, 3.0)
	var tip := a.lerp(b, reveal)
	_blade(a, tip, 54.0 * thick_mul, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * alpha))
	_blade(a, tip, 30.0 * thick_mul, Color(edge_color.r, edge_color.g, edge_color.b, alpha))
	_blade(a, tip, 22.0 * thick_mul, Color(body_color.r, body_color.g, body_color.b, alpha))
	_blade(a, tip, 4.0 * thick_mul, Color(core_color.r, core_color.g, core_color.b, alpha))


func _blade(a: Vector2, b: Vector2, thick: float, col: Color) -> void:
	var steps := 14
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
