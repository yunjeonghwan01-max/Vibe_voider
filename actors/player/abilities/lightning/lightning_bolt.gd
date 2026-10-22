class_name LightningBolt
extends Node2D

## 벼락 본체 (Attack 프리셋: Hitbox + 그리기 + 수명). 노드 위치 = 번개가 꽂히는 지점(시전 순간의 플레이어 위치).
##   0 ~ travel_time   가는 전조 번개가 하늘에서 지그재그로 내려온다.
##   travel_time       도달 — 굵은 깊은 검보라 번개가 꽂히고 크게 번쩍인다. 판정 on (한 번만).
##                     판정 = 하늘→도달점 경로(세로 사각형) + 도달점 중심 원. 한 적은 한 번만 맞는다.
##   이후 linger_time  바로 사라지지 않고 번개가 몇 번 더 내리치듯 맥동(PULSES)하며, 갈래 번개가 자라나고
##                     도달점에서 전기 줄기가 사방으로 기어 나가며 퍼진다. 점점 가늘고 흐려지다 사라진다.
## 번개 모양은 실제 시간으로 계속 다시 그려서, hit-stop으로 세상이 멈춘 순간에도 요동친다.
## Hitbox는 apply_on_contact = false — 적마다 도달점에서 바깥쪽으로 밀어내는 넉백을 직접 계산해 receive_hit()한다.

signal hit_landed(hurtbox: HurtboxComponent)

const SEG := 26.0                 # 번개 마디 길이
const RESHAPE_EVERY := 0.035      # 요동 주기 (실제 시간)
## 도달 후 다시 내리치는 맥동: [도달 후 시간(초), 세기]. 첫 항목이 본 타격.
const PULSES := [[0.0, 1.0], [0.11, 0.85], [0.24, 0.7], [0.4, 0.5]]
const CRAWLERS := 9               # 도달점에서 사방으로 퍼지는 전기 줄기 수

@export var hit_radius: float = 120.0
@export var path_width: float = 56.0
@export var active_time: float = 0.08
@export var linger_time: float = 0.75
@export var knockback: float = 220.0
@export var main_width: float = 34.0       # 본 번개 몸통 굵기 (맥동 최고점 기준)
@export var glow_color: Color = Color(0.42, 0.1, 0.68, 0.5)
@export var edge_color: Color = Color(0.7, 0.42, 1.0, 1.0)
@export var body_color: Color = Color(0.17, 0.02, 0.28, 1.0)     # 깊은 검보라
@export var core_color: Color = Color(1.0, 0.96, 1.0, 1.0)
@export var spark_scene: PackedScene

@onready var hitbox: HitboxComponent = $Hitbox
@onready var path_shape: CollisionShape2D = $Hitbox/Path
@onready var area_shape: CollisionShape2D = $Hitbox/Area
@onready var sfx: AudioStreamPlayer2D = $Audio/Strike

## 스폰하는 쪽이 add_child 전에 채운다.
var source: Node = null
var damage: int = 20
var travel_time: float = 0.15
var sky_height: float = 760.0

var _t: float = 0.0
var _struck: bool = false
var _stop_pending: bool = false
var _pulse_idx: int = 0
var _points: PackedVector2Array = PackedVector2Array()
var _branch_seeds: Array[Vector4] = []      # (본 번개 위 위치 0..1, 방향, 가로 길이, 세로 길이)
var _branches: Array[PackedVector2Array] = []
var _crawl_seeds: Array[Vector2] = []       # (각도, 최대 거리 배율)
var _crawlers: Array[PackedVector2Array] = []
var _flick: float = 1.0
var _reshape_left: float = 0.0
var _last_us: int = 0


func _ready() -> void:
	hitbox.source = source
	hitbox.apply_on_contact = false
	hitbox.monitoring = false
	hitbox.hurtbox_entered.connect(_on_hurtbox_entered)
	# 판정 모양을 값에 맞춘다: 하늘→도달점 기둥 + 도달점 원
	var rect := RectangleShape2D.new()
	rect.size = Vector2(path_width, sky_height)
	path_shape.shape = rect
	path_shape.position = Vector2(0.0, -sky_height * 0.5)
	var circ := CircleShape2D.new()
	circ.radius = hit_radius
	area_shape.shape = circ
	# 전기 줄기는 위쪽 반원 + 바닥을 따라 퍼진다 (땅속으로 파고들지 않게)
	for i in CRAWLERS:
		var u := (float(i) + randf_range(-0.3, 0.3)) / (CRAWLERS - 1)
		var ang := lerpf(PI + 0.12, TAU - 0.12, clampf(u, 0.0, 1.0))
		_crawl_seeds.append(Vector2(ang, randf_range(1.1, 1.8)))
	_last_us = Time.get_ticks_usec()
	_reshape()
	sfx.play()


func _physics_process(delta: float) -> void:
	_t += delta
	if _stop_pending:
		_stop_pending = false            # 판정이 한 프레임 잡힌 뒤에 멈춰야 맞은 적이 같이 굳는다
		GameFeel.hit_stop(0.07)
	if not _struck and _t >= travel_time:
		_strike()
	elif _struck:
		if hitbox.monitoring and _t >= travel_time + active_time:
			hitbox.monitoring = false
		_tick_pulses()
	if _t >= travel_time + linger_time:
		visible = false
		if not sfx.playing:              # 우르릉 꼬리가 끝까지 들리도록 소리가 끝난 뒤에 지운다
			queue_free()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_reshape_left -= (now - _last_us) / 1000000.0
	_last_us = now
	if _reshape_left <= 0.0:
		_reshape_left = RESHAPE_EVERY
		_reshape()
	queue_redraw()


func _strike() -> void:
	_struck = true
	_pulse_idx = 1
	hitbox.monitoring = true
	_stop_pending = true
	_add_branches(4)
	_reshape()
	GameFeel.flash(Color(0.82, 0.62, 1.0), 0.3, 0.18)   # 화면은 살짝만 — 크게 번쩍이는 건 도달점의 섬광이 맡는다
	GameFeel.shake(0.55)
	_spark(global_position, Color(0.8, 0.6, 1.0, 1.0), 22, 110.0, 0.3, true)
	_spark(global_position, Color(1.0, 0.96, 1.0, 1.0), 10, 150.0, 0.18, false)


## 남아 있는 동안 번개가 다시 내리치는 맥동 — 갈래가 늘고, 살짝 흔들리고, 도달점에서 불꽃이 튄다.
func _tick_pulses() -> void:
	if _pulse_idx >= PULSES.size():
		return
	var at: float = PULSES[_pulse_idx][0]
	if _t - travel_time < at:
		return
	var power: float = PULSES[_pulse_idx][1]
	_pulse_idx += 1
	_add_branches(2)
	_reshape()
	GameFeel.shake(0.14 * power)
	_spark(global_position, Color(0.75, 0.5, 1.0, 1.0), int(10 * power), 90.0 * power + 30.0, 0.22, false)


func _on_hurtbox_entered(hurt: HurtboxComponent) -> void:
	var dir := signf(hurt.global_position.x - global_position.x)
	if dir == 0.0:
		dir = 1.0 if randf() < 0.5 else -1.0
	var kb := Vector2(dir, -0.6).normalized() * knockback
	if hurt.receive_hit(damage, source, kb):
		GameFeel.shake(0.2)              # 맞은 적마다 살짝 더 흔들린다
		_spark(hurt.global_position, Color(0.85, 0.65, 1.0, 1.0), 9, 55.0, 0.2, false)
		hit_landed.emit(hurt)


func _spark(pos: Vector2, color: Color, count: int, length: float, life: float, ring: bool) -> void:
	if spark_scene == null:
		return
	var s := spark_scene.instantiate() as SparkEffect
	get_parent().add_child(s)
	s.global_position = pos
	s.burst(color, count, 360.0, 0.0, length, life)
	if ring:
		s.with_ring(color, hit_radius)


# ─────────────────────────── 세기 ───────────────────────────
## 도달 후 a초 시점의 번개 세기 (0..1): 맥동마다 확 밝아졌다가 빠르게 잦아든다.
func _intensity(a: float) -> float:
	var v := 0.0
	for p in PULSES:
		var dt: float = a - float(p[0])
		if dt >= 0.0:
			v = maxf(v, float(p[1]) * exp(-dt * 12.0))
	return v


## 도달 후 a초의 남은 정도 (1 → 0).
func _life(a: float) -> float:
	return clampf(1.0 - a / linger_time, 0.0, 1.0)


# ─────────────────────────── 모양 ───────────────────────────
func _add_branches(n: int) -> void:
	for i in n:
		_branch_seeds.append(Vector4(randf_range(0.3, 0.97), -1.0 if randf() < 0.5 else 1.0,
				randf_range(60.0, 140.0), randf_range(40.0, 140.0)))


## 하늘(0, -sky_height)에서 현재 끝점까지 지그재그 번개를 새로 만든다.
## 도달 후에는 갈래 번개(시간이 갈수록 길어진다)와 사방으로 기어 나가는 전기 줄기도 만든다.
func _reshape() -> void:
	var reach := 1.0
	if not _struck:
		reach = pow(clampf(_t / maxf(travel_time, 0.001), 0.0, 1.0), 0.8)   # 화면 안에서 내려오는 모습이 보이게
	var tip_y := lerpf(-sky_height, 0.0, reach)
	_points = _jagged(Vector2(0.0, -sky_height), Vector2(0.0, tip_y), 20.0, 38.0)
	_flick = randf_range(0.6, 1.0)
	_branches.clear()
	_crawlers.clear()
	if not _struck:
		return
	var a := _t - travel_time
	var grow := 0.45 + 1.0 * (1.0 - exp(-a * 6.0))           # 갈래가 점점 길게 뻗는다
	for s in _branch_seeds:
		var k := clampi(int(s.x * (_points.size() - 1)), 0, _points.size() - 1)
		var start := _points[k]
		var end := start + Vector2(s.y * s.z, s.w) * grow
		_branches.append(_jagged(start, end, 12.0, 999.0))
	var spread := 1.0 - exp(-a * 5.0)                         # 도달점에서 사방으로 퍼진다
	for c in _crawl_seeds:
		var dist := hit_radius * c.y * spread
		if dist < 16.0:
			continue
		var dir := Vector2.from_angle(c.x)
		_crawlers.append(_jagged(dir * 10.0, dir * dist, 9.0, 999.0))


func _jagged(a: Vector2, b: Vector2, wiggle: float, max_off: float) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var n := maxi(int(a.distance_to(b) / SEG), 1)
	var nrm := (b - a).normalized().orthogonal()
	var off := 0.0
	for i in range(1, n):
		off = clampf(off + randf_range(-wiggle, wiggle), -max_off, max_off)
		pts.append(a.lerp(b, float(i) / n) + nrm * off)
	pts.append(b)
	return pts


# ─────────────────────────── 그리기 ───────────────────────────
func _draw() -> void:
	if _points.size() < 2:
		return
	if not _struck:
		# 전조: 지직거리며 내려온다
		draw_polyline(_points, _a(glow_color, 0.9 * _flick), 18.0)
		draw_polyline(_points, _a(body_color, _flick), 8.0)
		draw_polyline(_points, _a(edge_color, _flick), 2.0)
		return

	var a := _t - travel_time
	var life := _life(a)
	var power := _intensity(a)
	var alpha := clampf(0.3 + power, 0.0, 1.0) * pow(life, 0.6) * _flick
	var w := main_width * (0.5 + 0.5 * power) * (0.55 + 0.45 * life)

	# 사방으로 퍼지는 전기 줄기 (본 번개 뒤에)
	for line in _crawlers:
		_bolt_line(line, w * 0.32, alpha * 0.9)
	# 갈래 번개
	for line in _branches:
		_bolt_line(line, w * 0.45, alpha)
	# 본 번개
	_bolt_line(_points, w, alpha)

	# 도달점: 맥동마다 번쩍이는 빛 + 처음의 큰 섬광
	var f := clampf(a / 0.2, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 150.0 * (1.0 - f * 0.4), _a(glow_color, 0.9 * (1.0 - f)))
	draw_circle(Vector2.ZERO, 70.0 * (1.0 - f) + 6.0, _a(core_color, 1.0 - f))
	draw_circle(Vector2.ZERO, 26.0 + 40.0 * power, _a(glow_color, 0.6 * power * life))
	draw_circle(Vector2.ZERO, 8.0 + 18.0 * power, _a(core_color, power * life))
	# 피해 범위를 알려주는 고리
	var rr := hit_radius * (0.55 + 0.45 * (1.0 - pow(1.0 - f, 3.0)))
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, _a(edge_color, life * 0.8), 5.0 * life + 1.0)


## 번개 한 줄기를 4겹으로: 넓은 빛 → 밝은 테두리 → 두꺼운 검보라 몸통 → 가는 흰 심.
func _bolt_line(line: PackedVector2Array, w: float, alpha: float) -> void:
	if line.size() < 2 or alpha <= 0.0:
		return
	draw_polyline(line, _a(glow_color, alpha), w * 2.4)
	draw_polyline(line, _a(edge_color, alpha), w * 1.25)
	draw_polyline(line, _a(body_color, alpha), w)
	draw_polyline(line, _a(core_color, alpha * 0.8), maxf(w * 0.12, 1.5))


func _a(c: Color, mul: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(mul, 0.0, 1.0))
