class_name MoonSlash
extends Node2D

## 궁극기 — 월아 참격. 거대한 반달 참격이 처음엔 느리게, 점점 지수함수처럼 빨라지며 날아간다.
##   FLY     본체(Body Hitbox)가 적에게 닿으면 그 순간 겹친 적 전부 1타(body_damage) + 띄우기, 그리고 그 자리에서 깨진다.
##           벽(world, 한쪽 발판 제외)에 닿아도 깨진다. 사거리를 다 날면 그냥 흩어진다(폭발 없음).
##   VORTEX  깨진 자리에 양옆으로 벌어지는 열린 회오리가 vortex_time 동안 휘몰아친다.
##   BURST   회오리가 위로 기다란 기둥으로 터진다: Burst Hitbox(위로 긴 사각형)에 닿은 적 전부 2타(burst_damage) + 크게 띄우기.
## 띄우기: 위쪽 넉백이 Enemy.LAUNCH_THRESHOLD보다 강하면 적이 착지할 때까지 경직된다 (에어본).
## 두 Hitbox 모두 apply_on_contact = false — 적마다 띄우는 방향/세기를 직접 정해 receive_hit()한다 (Hitbox가 1회씩 중복 방지).
## 좌우는 direction 값으로 받는다 (그리기는 scale.x 대신 dir을 곱해서).
## 모양은 일부러 깔끔하지 않다: 반달의 안쪽 날은 톱니처럼 들쭉날쭉하고 바깥 날엔 이가 빠져 있으며,
## 폭발 기둥은 찢긴 가장자리 + 가시 왕관 + 옆으로 튀는 가시 + 일렁이는 균열선으로 그린다 (RESHAPE마다 다시 흔든다).

enum Phase { FLY, VORTEX, BURST, DONE }

const RADIUS := 120.0             # 반달 바깥 호의 반지름
const HALF_ANGLE := 1.36          # 반달 끝까지의 각도 (라디안, 약 78°)
const THICK := 44.0               # 반달 가운데 두께
const ARC_STEPS := 28
const PILLAR_STEPS := 16
const RESHAPE_EVERY := 0.045      # 들쭉날쭉한 모양을 다시 흔드는 주기

@export var start_speed: float = 140.0
@export var growth: float = 4.2               # 속도 = start_speed × e^(growth × t)
@export var max_speed: float = 2600.0
@export var max_distance: float = 1500.0
@export var body_damage: int = 20             # 평타 1타(10)의 2배
@export var burst_damage: int = 40            # 평타 1타(10)의 4배
@export var body_launch: Vector2 = Vector2(180.0, -560.0)   # x는 진행 방향 기준
@export var burst_launch: float = -780.0
@export var vortex_time: float = 0.32         # moon_slash_burst.wav의 폭발 시점과 맞춘다
@export var burst_active: float = 0.08
@export var burst_fade: float = 0.5
@export var glow_color: Color = Color(0.6, 0.25, 1.0, 0.4)
@export var body_color: Color = Color(0.14, 0.03, 0.24, 1.0)
@export var edge_color: Color = Color(0.86, 0.62, 1.0, 1.0)
@export var core_color: Color = Color(1.0, 0.97, 1.0, 1.0)
@export var spark_scene: PackedScene

@onready var body_hitbox: HitboxComponent = $Body
@onready var burst_hitbox: HitboxComponent = $Burst
@onready var collision: Area2D = $Collision
@onready var sfx_fly: AudioStreamPlayer2D = $Audio/Fly
@onready var sfx_burst: AudioStreamPlayer2D = $Audio/Burst

## 스폰하는 쪽이 add_child 전에 채운다.
var source: Node = null
var direction: float = 1.0

var _phase: int = Phase.FLY
var _t: float = 0.0               # FLY 경과
var _pt: float = 0.0              # 현재 단계 경과
var _speed: float = 0.0
var _travelled: float = 0.0
var _stop_pending: bool = false
var _shards: Array[Vector4] = []  # 깨질 때 튀는 조각 (x, y, vx, vy)
var _reshape_left: float = 0.0
var _arc_jit: PackedFloat32Array = PackedFloat32Array()     # 반달 안쪽 날 두께 흔들림
var _arc_notch: PackedFloat32Array = PackedFloat32Array()   # 바깥 날 이 빠진 깊이
var _col_jit: PackedFloat32Array = PackedFloat32Array()     # 기둥 좌우 가장자리 흔들림 (좌, 우 번갈아)
var _crown: PackedFloat32Array = PackedFloat32Array()       # 기둥 꼭대기 가시 높이
var _spikes: Array[Vector4] = []                            # 옆 가시 (높이 비율, 좌우, 길이, 기울기)
var _cracks: Array[PackedVector2Array] = []                 # 기둥 속 균열선 (0..1 정규 좌표)


func _ready() -> void:
	for hb in [body_hitbox, burst_hitbox]:
		hb.source = source
		hb.apply_on_contact = false
	# 본체/벽 판정은 반달이 있는 앞쪽에 있다 — 왼쪽으로 쏘면 뒤집는다
	for shape in [$Body/CollisionShape2D, $Collision/CollisionShape2D]:
		shape.position.x = absf(shape.position.x) * direction
	body_hitbox.hurtbox_entered.connect(_on_body_hit)
	burst_hitbox.hurtbox_entered.connect(_on_burst_hit)
	burst_hitbox.monitoring = false
	collision.body_shape_entered.connect(_on_wall)
	_reshape()
	sfx_fly.play()


func _process(delta: float) -> void:
	_reshape_left -= delta
	if _reshape_left <= 0.0:
		_reshape_left = RESHAPE_EVERY
		_reshape()


## 들쭉날쭉한 모양을 새로 흔든다 (반달 톱니, 이 빠짐, 기둥 가장자리, 가시 왕관, 옆 가시, 균열선).
func _reshape() -> void:
	_arc_jit.resize(ARC_STEPS + 1)
	_arc_notch.resize(ARC_STEPS + 1)
	for i in ARC_STEPS + 1:
		_arc_jit[i] = randf_range(0.55, 1.3) if i % 2 == 0 else randf_range(0.8, 1.05)
		_arc_notch[i] = randf_range(4.0, 11.0) if randf() < 0.18 else 0.0
	_col_jit.resize((PILLAR_STEPS + 1) * 2)
	for i in _col_jit.size():
		_col_jit[i] = randf_range(0.7, 1.25)
	_crown.resize(9)
	for i in 9:
		_crown[i] = randf_range(0.05, 0.22) * (1.6 if i % 2 == 0 else 0.6)
	_spikes.clear()
	for i in 9:
		_spikes.append(Vector4(randf_range(0.1, 0.85), -1.0 if randf() < 0.5 else 1.0, randf_range(40.0, 130.0),
				randf_range(-0.9, -0.2)))
	_cracks.clear()
	for c in 4:
		var line := PackedVector2Array()
		var x := randf_range(-0.35, 0.35)
		for k in 9:
			x = clampf(x + randf_range(-0.16, 0.16), -0.45, 0.45)
			line.append(Vector2(x, float(k) / 8.0))
		_cracks.append(line)


func _physics_process(delta: float) -> void:
	if _stop_pending:
		_stop_pending = false
		GameFeel.hit_stop(0.12)
	_pt += delta
	match _phase:
		Phase.FLY:
			_t += delta
			_speed = minf(start_speed * exp(growth * _t), max_speed)
			var step := _speed * delta
			global_position.x += direction * step
			_travelled += step
			if _travelled >= max_distance:
				_phase = Phase.DONE
				_pt = 0.0
				body_hitbox.set_deferred("monitoring", false)
				collision.set_deferred("monitoring", false)
		Phase.VORTEX:
			if _pt >= vortex_time:
				_burst()
		Phase.BURST:
			if burst_hitbox.monitoring and _pt >= burst_active:
				burst_hitbox.monitoring = false
			if _pt >= burst_fade:
				_phase = Phase.DONE
				_pt = 0.0
		Phase.DONE:
			if _pt >= 0.25 and not sfx_burst.playing:
				queue_free()
	for i in _shards.size():
		var s := _shards[i]
		_shards[i] = Vector4(s.x + s.z * delta, s.y + s.w * delta, s.z * 0.96, s.w + 900.0 * delta)
	queue_redraw()


# ─────────────────────────── 1타: 본체 ───────────────────────────
func _on_body_hit(hurt: HurtboxComponent) -> void:
	if _phase != Phase.FLY and _phase != Phase.VORTEX:
		return
	var kb := Vector2(body_launch.x * direction, body_launch.y)
	if hurt.receive_hit(body_damage, source, kb):
		_spark(hurt.global_position, edge_color, 12, 80.0, 0.25)
	if _phase == Phase.FLY:
		_break(hurt.global_position.x)   # 처음 닿은 적 자리에서 깨진다 (같은 프레임에 겹친 다른 적도 함께 맞는다)


func _on_wall(_rid: RID, body: Node2D, body_shape_index: int, _local_shape_index: int) -> void:
	if _phase != Phase.FLY:
		return
	var co := body as CollisionObject2D
	if co != null and co.is_shape_owner_one_way_collision_enabled(co.shape_find_owner(body_shape_index)):
		return
	_break()


## 참격이 깨진다 — 적에게 닿았으면 그 적 자리에, 벽이면 반달 몸통 자리에 열린 회오리가 생긴다.
func _break(at_x: float = NAN) -> void:
	_phase = Phase.VORTEX
	_pt = 0.0
	var old_x := global_position.x
	global_position.x = at_x if not is_nan(at_x) else old_x + float($Body/CollisionShape2D.position.x)
	var body_x := global_position.x - old_x
	body_hitbox.set_deferred("monitoring", false)
	collision.set_deferred("monitoring", false)
	sfx_fly.stop()
	sfx_burst.play()
	GameFeel.hit_stop(0.06)
	GameFeel.shake(0.45)
	for i in 14:
		var ang := randf_range(-HALF_ANGLE, HALF_ANGLE)
		var p := Vector2(cos(ang) * RADIUS * direction - body_x, sin(ang) * RADIUS)
		var v := p.normalized() * randf_range(120.0, 320.0) + Vector2(0.0, -120.0)
		_shards.append(Vector4(p.x, p.y, v.x, v.y))


# ─────────────────────────── 2타: 회오리 폭발 ───────────────────────────
func _burst() -> void:
	_phase = Phase.BURST
	_pt = 0.0
	burst_hitbox.monitoring = true
	_stop_pending = true            # 판정이 한 프레임 잡힌 뒤 멈춘다
	GameFeel.flash(Color(0.85, 0.6, 1.0), 0.35, 0.25)
	GameFeel.shake(1.0)
	_spark(global_position, edge_color, 26, 160.0, 0.4)
	_spark(global_position + Vector2(0.0, -160.0), core_color, 14, 120.0, 0.3)


func _on_burst_hit(hurt: HurtboxComponent) -> void:
	var dx := signf(hurt.global_position.x - global_position.x)
	if hurt.receive_hit(burst_damage, source, Vector2(dx * 120.0, burst_launch)):
		_spark(hurt.global_position, core_color, 14, 90.0, 0.3)


func _spark(pos: Vector2, color: Color, count: int, length: float, life: float) -> void:
	if spark_scene == null:
		return
	var s := spark_scene.instantiate() as SparkEffect
	get_parent().add_child(s)
	s.global_position = pos
	s.burst(color, count, 360.0, 0.0, length, life)


# ─────────────────────────── 그리기 ───────────────────────────
func _draw() -> void:
	match _phase:
		Phase.FLY:
			# 빨라질수록 뒤로 잔상이 길게 늘어진다
			var stretch := clampf(_speed / max_speed, 0.0, 1.0)
			for k in range(3, 0, -1):
				var off := Vector2(-direction * k * (10.0 + 34.0 * stretch), 0.0)
				_draw_crescent(off, 1.0 - k * 0.08, 0.18 * (4 - k) * (0.4 + stretch))
			_draw_crescent(Vector2.ZERO, 1.0, 1.0)
		Phase.VORTEX:
			_draw_shards(1.0)
			_draw_vortex(clampf(_pt / vortex_time, 0.0, 1.0))
		Phase.BURST:
			_draw_shards(clampf(1.0 - _pt / 0.3, 0.0, 1.0))
			_draw_pillar(clampf(_pt / burst_fade, 0.0, 1.0))
		Phase.DONE:
			pass


## 반달: 바깥 호 위의 점에서 안쪽으로 두께만큼 들어간 모양 (가운데 두껍고 양 끝 뾰족). 진행 방향(+dir)으로 볼록.
## 안쪽 날은 톱니처럼 들쭉날쭉(_arc_jit), 바깥 날엔 이가 빠지고(_arc_notch), 흰 심은 군데군데 끊긴다.
func _draw_crescent(offset: Vector2, size_mul: float, alpha: float) -> void:
	var r := RADIUS * size_mul
	for layer in [[THICK * 1.9, glow_color, 0.5], [THICK * 1.1, edge_color, 1.0], [THICK, body_color, 1.0]]:
		var th: float = layer[0] * size_mul
		var col: Color = layer[1]
		var ragged: float = layer[2]
		col = Color(col.r, col.g, col.b, col.a * alpha)
		var cols := PackedColorArray([col, col, col, col])
		var prev_o := Vector2.ZERO
		var prev_i := Vector2.ZERO
		for i in ARC_STEPS + 1:
			var ang := lerpf(-HALF_ANGLE, HALF_ANGLE, float(i) / ARC_STEPS)
			var dir := Vector2(cos(ang) * direction, sin(ang))
			var t := th * pow(cos(ang * PI * 0.5 / HALF_ANGLE), 1.3) * lerpf(1.0, _arc_jit[i], ragged)
			var o := offset + dir * (r - _arc_notch[i] * ragged)
			var inn := offset + dir * (r - t)
			if i > 0:
				draw_primitive(PackedVector2Array([prev_o, o, inn, prev_i]), cols, PackedVector2Array())
			prev_o = o
			prev_i = inn
	# 바깥 날의 흰 심 — 이 빠진 곳에서 끊긴다
	var core := Color(core_color.r, core_color.g, core_color.b, alpha)
	for i in ARC_STEPS:
		if _arc_notch[i] > 0.0 or _arc_notch[i + 1] > 0.0:
			continue
		var a0 := lerpf(-HALF_ANGLE * 0.94, HALF_ANGLE * 0.94, float(i) / ARC_STEPS)
		var a1 := lerpf(-HALF_ANGLE * 0.94, HALF_ANGLE * 0.94, float(i + 1) / ARC_STEPS)
		draw_line(offset + Vector2(cos(a0) * direction, sin(a0)) * (r - 3.0),
				offset + Vector2(cos(a1) * direction, sin(a1)) * (r - 3.0), core, 3.0)
	# 양 끝에서 뒤로 찢겨 나간 가는 가시
	for sgn in [-1.0, 1.0]:
		var tip := offset + Vector2(cos(HALF_ANGLE) * direction, sin(HALF_ANGLE) * sgn) * r
		var back := tip + Vector2(-direction * 34.0 * size_mul, sgn * 10.0)
		draw_line(tip, back, Color(edge_color.r, edge_color.g, edge_color.b, 0.8 * alpha), 2.0)


func _draw_shards(alpha: float) -> void:
	for s in _shards:
		var p := Vector2(s.x, s.y)
		var v := Vector2(s.z, s.w).normalized() * 9.0
		draw_line(p - v, p + v, Color(edge_color.r, edge_color.g, edge_color.b, alpha), 3.0)


## 양옆으로 벌어지는 열린 회오리: 중심에서 나선 팔들이 좌우로 길게 벌어지며 돈다. u(0→1)에 따라 커지고 빨라진다.
func _draw_vortex(u: float) -> void:
	var spin := _pt * lerpf(8.0, 22.0, u)
	var size := lerpf(40.0, 185.0, 1.0 - pow(1.0 - u, 2.0))
	var arms := 6
	for a in arms:
		var base := TAU * float(a) / arms + spin
		var pts := PackedVector2Array()
		for k in 16:
			var th := float(k) / 15.0 * 2.6                    # 나선 각도 진행 (닫히지 않는 열린 팔)
			var r := size * (0.12 + 0.88 * float(k) / 15.0)
			var p := Vector2.from_angle(base + th) * r
			pts.append(Vector2(p.x * 1.7, p.y * 0.75))          # 좌우로 벌어지게 가로로 늘린다
		var w := 7.0 * (1.0 - float(a % 2) * 0.35)
		draw_polyline(pts, Color(glow_color.r, glow_color.g, glow_color.b, 0.6), w * 2.4)
		draw_polyline(pts, Color(edge_color.r, edge_color.g, edge_color.b, 0.9), w)
		draw_polyline(pts, Color(core_color.r, core_color.g, core_color.b, 0.7), maxf(w * 0.3, 1.5))
	# 회오리 눈 + 곧 터질 듯 떨리는 핵
	var jitter := Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)) * u
	draw_circle(jitter, 18.0 + 14.0 * u, Color(glow_color.r, glow_color.g, glow_color.b, 0.7))
	draw_circle(jitter, 10.0 + 8.0 * u, body_color)
	draw_circle(jitter, 4.0 + 6.0 * u * u, core_color)


## 위로 기다란 폭발 기둥 (Burst Hitbox 모양과 같은 범위): 찢긴 가장자리, 가시 왕관, 옆으로 튀는 가시, 일렁이는 균열선.
## 확 솟았다가 가늘어지며 사라진다. 바닥에는 들쭉날쭉한 충격파와 갈라짐.
func _draw_pillar(u: float) -> void:
	var shape := ($Burst/CollisionShape2D as CollisionShape2D)
	var rect := (shape.shape as RectangleShape2D).size
	var bottom := shape.position.y + rect.y * 0.5
	var top := shape.position.y - rect.y * 0.5
	var rise := 1.0 - pow(1.0 - minf(u * 4.0, 1.0), 3.0)
	var y_top := lerpf(bottom, top, rise)
	var height := bottom - y_top
	var fade := 1.0 - u
	var half := rect.x * 0.5 * lerpf(1.1, 0.4, u)
	for layer in [[1.3, glow_color, 0.6], [0.85, edge_color, 0.85], [0.35, core_color, 1.0]]:
		var wmul: float = layer[0]
		var c: Color = layer[1]
		var col := Color(c.r, c.g, c.b, c.a * float(layer[2]) * fade)
		_ragged_column(bottom, height, half * wmul, col)
	# 옆으로 튀는 날카로운 가시
	for sp in _spikes:
		var y := bottom - height * sp.x
		var w := half * (1.0 - 0.5 * sp.x)
		var root := Vector2(sp.y * w * 0.8, y)
		var dir := Vector2(sp.y, sp.w).normalized()
		var tip := root + dir * sp.z * fade
		var n := dir.orthogonal() * 6.0
		var sc := Color(edge_color.r, edge_color.g, edge_color.b, 0.85 * fade)
		draw_primitive(PackedVector2Array([root + n, tip, root - n]), PackedColorArray([sc, sc, sc]), PackedVector2Array())
	# 속에서 일렁이는 균열선 (번개처럼 꺾인 흰 줄기)
	for line in _cracks:
		var pts := PackedVector2Array()
		for q in line:
			pts.append(Vector2(q.x * half * 1.6, bottom - height * q.y))
		draw_polyline(pts, Color(core_color.r, core_color.g, core_color.b, 0.9 * fade), 2.0)
	# 바닥: 들쭉날쭉한 충격파 + 갈라짐
	var ring := 50.0 + 330.0 * (1.0 - pow(1.0 - u, 3.0))
	var pts := PackedVector2Array()
	for i in 33:
		var ang := TAU * float(i) / 32.0
		var jr := ring * (0.86 + 0.28 * _col_jit[i % _col_jit.size()] * 0.5)
		pts.append(Vector2(cos(ang) * jr, bottom - 40.0 + sin(ang) * jr * 0.2))
	draw_polyline(pts, Color(edge_color.r, edge_color.g, edge_color.b, fade), 4.0 * fade + 1.0)
	for i in 6:
		var sx := (float(i) / 5.0 - 0.5) * ring * 1.4
		draw_line(Vector2(sx * 0.3, bottom - 36.0), Vector2(sx, bottom - 36.0 + _col_jit[i] * 10.0 - 5.0),
				Color(core_color.r, core_color.g, core_color.b, 0.7 * fade), 2.0)


## 아래(bottom)에서 height만큼 솟은 기둥 하나: 좌우 가장자리가 마디마다 들쭉날쭉하고 위로 갈수록 좁아지며,
## 꼭대기는 높이가 제각각인 가시로 끝난다 (반듯하게 잘린 윗변이 없다).
func _ragged_column(bottom: float, height: float, half: float, col: Color) -> void:
	if height < 2.0 or half < 1.0:
		return
	var cols := PackedColorArray([col, col, col, col])
	var prev_l := Vector2(-half * _col_jit[0], bottom)
	var prev_r := Vector2(half * _col_jit[1], bottom)
	for k in range(1, PILLAR_STEPS + 1):
		var v := float(k) / PILLAR_STEPS
		var y := bottom - height * v
		var w := half * (1.0 - 0.55 * v)
		var l := Vector2(-w * _col_jit[k * 2], y)
		var r := Vector2(w * _col_jit[k * 2 + 1], y)
		draw_primitive(PackedVector2Array([prev_l, prev_r, r, l]), cols, PackedVector2Array())
		prev_l = l
		prev_r = r
	# 가시 왕관: 꼭대기 폭을 나눠 높이가 제각각인 날카로운 가시들
	var n := _crown.size()
	for i in n:
		var x0 := lerpf(prev_l.x, prev_r.x, float(i) / n)
		var x1 := lerpf(prev_l.x, prev_r.x, float(i + 1) / n)
		var peak := Vector2((x0 + x1) * 0.5 + randf_range(-3.0, 3.0), prev_l.y - height * _crown[i])
		draw_primitive(PackedVector2Array([Vector2(x0, prev_l.y), peak, Vector2(x1, prev_l.y)]),
				PackedColorArray([col, col, col]), PackedVector2Array())   # 아주 가늘어져도 깨지지 않게 직접 그린다
