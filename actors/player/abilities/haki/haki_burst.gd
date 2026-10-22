class_name HakiBurst
extends Node2D

## 패기 방출 — 연쇄 반격 3연속의 보상. 몸에 모은 검붉은 기운을 한 방에 사방으로 터뜨린다 (번개를 곁들인 노바).
## 노드 위치 = 방출 중심(플레이어). 연출은 실제 시간으로 흐르고, 세상은 GameFeel로 잠깐 느려진다.
## 화면을 덮지 않는다: 모든 연출은 중심과 날아가는 번개 화살, 맞은 적 주변에만 그린다.
##   0 ~ RELEASE_AT   모으기: 핏빛 고리가 조여들고 기운이 빨려들며 검은 핵이 부푼다.
##   RELEASE_AT       방출: 짧은 검붉은 번개 화살 DARTS개가 한꺼번에 사방으로 쏘아지고, 얇은 충격파 고리가 같은 속도로 퍼진다.
##                    카메라 화면 안의 모든 적이 고리가 닿는 순간 맞고, 맞은 자리에서 작은 번개가 지직거린다.
## 데미지는 공격 쪽이 타이밍을 정하는 문법대로 각 적의 Hurtbox에 receive_hit()을 직접 호출한다.

const RELEASE_AT := 0.28          # haki_burst.wav의 파열 시점과 맞춘다
const DARTS := 32
const SPEED := 2300.0             # 번개 화살과 충격파(=피격)가 퍼지는 속도 px/s
const DART_LEN := 78.0
const RESHAPE_EVERY := 0.035

@export var glow_color: Color = Color(0.85, 0.04, 0.12, 0.5)     # 핏빛 기운
@export var edge_color: Color = Color(1.0, 0.2, 0.24, 1.0)
@export var body_color: Color = Color(0.12, 0.0, 0.03, 1.0)      # 검붉은 심
@export var hot_color: Color = Color(1.0, 0.82, 0.82, 1.0)
@export var spark_scene: PackedScene

@onready var sfx: AudioStreamPlayer2D = $Audio/Burst

## 스폰하는 쪽이 add_child 전에 채운다.
var source: Node = null
var damage: int = 15
var knockback: float = 300.0

var _t: float = 0.0
var _last_us: int = 0
var _reshape_left: float = 0.0
var _released: bool = false
var _max_reach: float = 1200.0                    # 화면 끝까지의 거리 (방출 때 정한다)
var _dart_dirs: Array[Vector2] = []
var _dart_speed: Array[float] = []
var _dart_shapes: Array[PackedVector2Array] = []
var _pending: Array[Dictionary] = []              # {"hurt", "at"} 아직 고리가 닿지 않은 적
var _zaps: Array[Dictionary] = []                 # {"pos", "at", "arcs"} 맞은 적 주변 번개


func _ready() -> void:
	_last_us = Time.get_ticks_usec()
	for i in DARTS:
		var ang := TAU * (float(i) + randf_range(-0.3, 0.3)) / DARTS
		_dart_dirs.append(Vector2.from_angle(ang))
		_dart_speed.append(SPEED * randf_range(0.9, 1.1))
	_reshape()
	sfx.play()
	GameFeel.hit_stop(RELEASE_AT, 0.12)    # 모으는 동안 세상이 살짝 느려진다


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _last_us) / 1000000.0
	_last_us = now
	_t += dt
	if not _released and _t >= RELEASE_AT:
		_release()
	if _released:
		_apply_pending_hits()
	_reshape_left -= dt
	if _reshape_left <= 0.0:
		_reshape_left = RESHAPE_EVERY
		_reshape()
	if _released and _t - RELEASE_AT > _max_reach / SPEED + 0.35 and _pending.is_empty() and not sfx.playing:
		queue_free()
		return
	queue_redraw()


# ─────────────────────────── 방출 / 피격 ───────────────────────────
func _release() -> void:
	_released = true
	GameFeel.flash(Color(0.8, 0.05, 0.12), 0.2, 0.15)
	GameFeel.shake(0.85)
	var view := _visible_world_rect()
	var reach := 0.0
	for corner in [view.position, view.end, Vector2(view.position.x, view.end.y), Vector2(view.end.x, view.position.y)]:
		reach = maxf(reach, global_position.distance_to(corner))
	_max_reach = reach
	for n in get_tree().get_nodes_in_group("enemy"):
		var enemy := n as Enemy
		if enemy == null or enemy.state == Enemy.State.DEAD or not view.grow(40.0).has_point(enemy.global_position):
			continue
		var d := enemy.global_position.distance_to(global_position)
		_pending.append({"hurt": enemy.hurtbox, "at": RELEASE_AT + d / SPEED})
	_spark(global_position, Color(0.95, 0.1, 0.15, 1.0), 24, 120.0, 0.3)
	_spark(global_position, hot_color, 10, 90.0, 0.18)


func _apply_pending_hits() -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		if _t < float(p["at"]):
			continue
		_pending.remove_at(i)
		var hurt := p["hurt"] as HurtboxComponent
		if not is_instance_valid(hurt):
			continue
		var pos: Vector2 = hurt.global_position
		var away := (pos - global_position).normalized()
		if hurt.receive_hit(damage, source, Vector2(away.x, minf(away.y, 0.0) - 0.5).normalized() * knockback):
			_zaps.append({"pos": pos, "at": _t, "arcs": _zap_arcs()})
			_spark(pos, Color(0.95, 0.15, 0.2, 1.0), 10, 60.0, 0.22)
			GameFeel.shake(0.12)


func _visible_world_rect() -> Rect2:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var a := inv * Vector2.ZERO
	var b := inv * get_viewport().get_visible_rect().size
	return Rect2(a, b - a).abs()


func _spark(pos: Vector2, color: Color, count: int, length: float, life: float) -> void:
	if spark_scene == null:
		return
	var s := spark_scene.instantiate() as SparkEffect
	get_parent().add_child(s)
	s.global_position = pos
	s.burst(color, count, 360.0, 0.0, length, life)


# ─────────────────────────── 모양 (요동) ───────────────────────────
func _reshape() -> void:
	_dart_shapes.clear()
	for i in DARTS:
		# 화살 하나 = 진행 방향으로 짧게 꺾이는 번개 4마디 (끝점 기준 뒤쪽으로)
		var dir := _dart_dirs[i]
		var nrm := dir.orthogonal()
		var pts := PackedVector2Array([Vector2.ZERO])
		for k in range(1, 4):
			pts.append(-dir * DART_LEN * k / 4.0 + nrm * randf_range(-9.0, 9.0))
		pts.append(-dir * DART_LEN)
		_dart_shapes.append(pts)
	for z in _zaps:
		z["arcs"] = _zap_arcs()


func _zap_arcs() -> Array:
	var arcs: Array = []
	for k in 3:
		var a := Vector2.from_angle(randf() * TAU) * randf_range(8.0, 16.0)
		var b := a + Vector2.from_angle(randf() * TAU) * randf_range(22.0, 40.0)
		var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * randf_range(-8.0, 8.0)
		arcs.append(PackedVector2Array([a, mid, b]))
	return arcs


# ─────────────────────────── 그리기 ───────────────────────────
func _draw() -> void:
	if not _released:
		_draw_gather(_t / RELEASE_AT)
		return
	var a := _t - RELEASE_AT
	# 방출 순간 중심 섬광 (짧게)
	var f := clampf(a / 0.14, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 30.0 + 90.0 * f, _a(glow_color, 1.0 - f))
	draw_circle(Vector2.ZERO, 40.0 * (1.0 - f), _a(hot_color, 1.0 - f))
	# 충격파 고리: 얇고 빠르게, 화살과 같은 속도
	var ring_life := clampf(1.0 - a / 0.45, 0.0, 1.0)
	if ring_life > 0.0:
		var r := SPEED * a
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, _a(glow_color, ring_life), 10.0 * ring_life + 2.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, _a(edge_color, ring_life), 2.5)
	# 번개 화살
	for i in DARTS:
		var dist := 40.0 + _dart_speed[i] * a
		if dist > _max_reach + DART_LEN:
			continue
		var fade := clampf(1.0 - (dist - _max_reach * 0.7) / (_max_reach * 0.3 + 1.0), 0.0, 1.0)
		var dir := _dart_dirs[i]
		var tip := dir * dist
		var line := PackedVector2Array()
		for p in _dart_shapes[i]:
			line.append(tip + p)
		# 뒤로 끌리는 옅은 잔광
		draw_line(tip - dir * DART_LEN, tip - dir * DART_LEN * 2.4, _a(glow_color, 0.45 * fade), 4.0)
		draw_polyline(line, _a(glow_color, fade), 13.0)
		draw_polyline(line, _a(edge_color, fade), 5.0)
		draw_polyline(line, _a(body_color, fade), 2.0)
		draw_circle(tip, 3.5, _a(hot_color, fade))
	# 맞은 적 주변에서 지직거리는 번개
	for z in _zaps:
		var k := clampf(1.0 - (_t - float(z["at"])) / 0.28, 0.0, 1.0)
		if k <= 0.0:
			continue
		var c := to_local(z["pos"])
		for arc in z["arcs"]:
			var pts := PackedVector2Array()
			for p in arc:
				pts.append(c + p)
			draw_polyline(pts, _a(glow_color, k), 7.0)
			draw_polyline(pts, _a(edge_color, k), 2.0)


## 모으기: 핏빛 고리가 조여들고 기운 줄기가 빨려들며 검은 핵이 떨며 부푼다. (반지름 140 안쪽에만)
func _draw_gather(u: float) -> void:
	var ring_r := lerpf(140.0, 34.0, u * u)
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, _a(glow_color, 0.5 + 0.5 * u), 8.0)
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, _a(edge_color, 0.6 + 0.4 * u), 2.0)
	for i in 12:
		var ang := TAU * float(i) / 12.0 + _t * 4.0
		var ph := fmod(u * 2.5 + float(i) * 0.29, 1.0)
		var p := Vector2.from_angle(ang) * 130.0 * (1.0 - ph)
		draw_line(p, p * 0.75, _a(edge_color, ph), 2.5)
	var jitter := Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)) * u
	var core := 8.0 + 20.0 * u
	draw_circle(jitter, core * 1.8, _a(glow_color, 0.4 + 0.5 * u))
	draw_circle(jitter, core, body_color)
	draw_arc(jitter, core, 0.0, TAU, 24, _a(edge_color, 0.9), 2.0)


func _a(c: Color, mul: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(mul, 0.0, 1.0))
