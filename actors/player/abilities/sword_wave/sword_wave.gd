class_name SwordWave
extends Node2D

## 궁극기 — 검격 날리기. 거대한 반달 검기가 처음엔 느리게, 점점 지수함수처럼 빨라지며 수평으로 날아간다.
##   FLY      첫 적(Body Hitbox에 닿은 Hurtbox) 또는 벽(world, 한쪽 발판 제외)에 닿으면 그 자리에서 EXPLODE.
##            아무것도 맞히지 못하고 카메라 화면 밖으로 나가면 그냥 사라진다 (max_distance는 안전장치).
##   EXPLODE  원형 폭발: 반지름 explosion_radius 안의 모든 적(그룹 "enemy")에게 표식(VoidMark)을 붙이고 explosion_damage.
##            표식은 mark_delay초 뒤 터져 주변 적에게 mark_damage (VoidMark 참고).
## 데미지는 공격 쪽이 대상을 정하는 문법대로 각 적의 Hurtbox에 receive_hit()을 직접 호출한다 (HakiBurst와 같다).
## 비행 모양(들쭉날쭉한 반달)은 월아 참격(MoonSlash)과 같은 그리기를 쓴다.

enum Phase { FLY, EXPLODE, DONE }

const RADIUS := 120.0             # 반달 바깥 호의 반지름
const HALF_ANGLE := 1.36          # 반달 끝까지의 각도 (라디안, 약 78°)
const THICK := 44.0               # 반달 가운데 두께
const ARC_STEPS := 28
const RESHAPE_EVERY := 0.045
const EXPLODE_TIME := 0.5

@export var start_speed: float = 140.0
@export var growth: float = 4.2               # 속도 = start_speed × e^(growth × t)
@export var max_speed: float = 2600.0
@export var max_distance: float = 4000.0
@export var explosion_radius: float = 220.0
@export var explosion_damage: int = 50        # 임시 5N
@export var explosion_knockback: float = 0.0  # 미정 — 흩어지면 표식 중첩이 줄어든다
@export var mark_damage: int = 10             # 임시 1N (표식 하나가 터질 때)
@export var mark_radius: float = 140.0
@export var mark_delay: float = 2.0
@export var glow_color: Color = Color(0.6, 0.25, 1.0, 0.4)
@export var body_color: Color = Color(0.14, 0.03, 0.24, 1.0)
@export var edge_color: Color = Color(0.86, 0.62, 1.0, 1.0)
@export var core_color: Color = Color(1.0, 0.97, 1.0, 1.0)
@export var spark_scene: PackedScene

@onready var body_hitbox: HitboxComponent = $Body
@onready var collision: Area2D = $Collision
@onready var sfx_fly: AudioStreamPlayer2D = $Audio/Fly
@onready var sfx_burst: AudioStreamPlayer2D = $Audio/Burst

## 스폰하는 쪽이 add_child 전에 채운다.
var source: Node = null
var direction: float = 1.0

var _phase: int = Phase.FLY
var _t: float = 0.0
var _pt: float = 0.0
var _speed: float = 0.0
var _travelled: float = 0.0
var _reshape_left: float = 0.0
var _arc_jit: PackedFloat32Array = PackedFloat32Array()
var _arc_notch: PackedFloat32Array = PackedFloat32Array()
var _shards: Array[Vector4] = []  # 폭발로 튀는 조각 (x, y, vx, vy)


func _ready() -> void:
	body_hitbox.source = source
	body_hitbox.apply_on_contact = false
	for shape in [$Body/CollisionShape2D, $Collision/CollisionShape2D]:
		shape.position.x = absf(shape.position.x) * direction
	body_hitbox.hurtbox_entered.connect(_on_body_hit)
	collision.body_shape_entered.connect(_on_wall)
	_reshape()
	sfx_fly.play()


func _process(delta: float) -> void:
	_reshape_left -= delta
	if _reshape_left <= 0.0:
		_reshape_left = RESHAPE_EVERY
		_reshape()


func _reshape() -> void:
	_arc_jit.resize(ARC_STEPS + 1)
	_arc_notch.resize(ARC_STEPS + 1)
	for i in ARC_STEPS + 1:
		_arc_jit[i] = randf_range(0.55, 1.3) if i % 2 == 0 else randf_range(0.8, 1.05)
		_arc_notch[i] = randf_range(4.0, 11.0) if randf() < 0.18 else 0.0


func _physics_process(delta: float) -> void:
	_pt += delta
	match _phase:
		Phase.FLY:
			_t += delta
			_speed = minf(start_speed * exp(growth * _t), max_speed)
			var step := _speed * delta
			global_position.x += direction * step
			_travelled += step
			if _travelled >= max_distance or _past_screen_edge():
				_stop_flying()
				_phase = Phase.DONE
				_pt = 0.0
		Phase.EXPLODE:
			if _pt >= EXPLODE_TIME:
				_phase = Phase.DONE
				_pt = 0.0
		Phase.DONE:
			if _pt >= 0.25 and not sfx_burst.playing:
				queue_free()
	for i in _shards.size():
		var s := _shards[i]
		_shards[i] = Vector4(s.x + s.z * delta, s.y + s.w * delta, s.z * 0.96, s.w + 900.0 * delta)
	queue_redraw()


## 반달 뒤끝까지 카메라 화면의 진행 방향 끝을 넘었는가.
func _past_screen_edge() -> bool:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var a := inv * Vector2.ZERO
	var b := inv * get_viewport().get_visible_rect().size
	var x := global_position.x
	return x > maxf(a.x, b.x) + RADIUS if direction > 0.0 else x < minf(a.x, b.x) - RADIUS


func _on_body_hit(hurt: HurtboxComponent) -> void:
	if _phase == Phase.FLY:
		_explode(hurt.global_position)


func _on_wall(_rid: RID, body: Node2D, body_shape_index: int, _local_shape_index: int) -> void:
	if _phase != Phase.FLY:
		return
	var co := body as CollisionObject2D
	if co != null and co.is_shape_owner_one_way_collision_enabled(co.shape_find_owner(body_shape_index)):
		return
	_explode(global_position + Vector2(float($Collision/CollisionShape2D.position.x), 0.0))


func _stop_flying() -> void:
	body_hitbox.set_deferred("monitoring", false)
	collision.set_deferred("monitoring", false)
	sfx_fly.stop()


## 원형 폭발 — 범위 안의 모든 적에게 표식을 먼저 붙이고(폭발로 죽어도 시체가 표식과 함께 남는다) 피해를 준다.
func _explode(at: Vector2) -> void:
	_phase = Phase.EXPLODE
	_pt = 0.0
	global_position = at
	_stop_flying()
	sfx_burst.play()
	GameFeel.hit_stop(0.1)
	GameFeel.shake(0.9)
	GameFeel.flash(Color(0.85, 0.6, 1.0), 0.35, 0.25)
	for i in 18:
		var ang := randf() * TAU
		var v := Vector2.from_angle(ang) * randf_range(160.0, 380.0) + Vector2(0.0, -120.0)
		_shards.append(Vector4(0.0, 0.0, v.x, v.y))
	var parent: Node = get_parent()
	for n in get_tree().get_nodes_in_group("enemy"):
		var enemy := n as Enemy
		if enemy == null or enemy.state == Enemy.State.DEAD:
			continue
		if enemy.hurtbox.global_position.distance_to(at) > explosion_radius:
			continue
		var mark := VoidMark.new()
		mark.target = enemy
		mark.damage = mark_damage
		mark.radius = mark_radius
		mark.delay = mark_delay
		parent.add_child(mark)
		var away := signf(enemy.global_position.x - at.x)
		var kb := Vector2(away if away != 0.0 else direction, -0.4).normalized() * explosion_knockback
		if enemy.hurtbox.receive_hit(explosion_damage, source, kb):
			_spark(enemy.hurtbox.global_position, core_color, 12, 90.0, 0.3)
	_spark(at, edge_color, 26, 160.0, 0.4)


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
		Phase.EXPLODE:
			_draw_explosion(clampf(_pt / EXPLODE_TIME, 0.0, 1.0))
			_draw_shards(clampf(1.0 - _pt / 0.4, 0.0, 1.0))


## 원형 폭발: 범위만큼 확 번지는 검보라 구 + 흰 충격 고리 + 표식이 퍼져 나가는 가는 고리.
func _draw_explosion(u: float) -> void:
	var e := 1.0 - pow(1.0 - minf(u / 0.35, 1.0), 3.0)
	var fade := 1.0 - clampf((u - 0.25) / 0.75, 0.0, 1.0)
	var r := explosion_radius * e
	draw_circle(Vector2.ZERO, r * 1.08, Color(glow_color.r, glow_color.g, glow_color.b, 0.35 * fade))
	draw_circle(Vector2.ZERO, r * 0.85, Color(body_color.r, body_color.g, body_color.b, 0.8 * fade))
	draw_circle(Vector2.ZERO, r * 0.3 * (1.0 - u), Color(core_color.r, core_color.g, core_color.b, fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(edge_color.r, edge_color.g, edge_color.b, fade), 6.0 * fade + 1.0)
	draw_arc(Vector2.ZERO, explosion_radius * minf(u * 1.6, 1.0), 0.0, TAU, 56,
			Color(core_color.r, core_color.g, core_color.b, 0.6 * fade), 2.0)


## 반달: 바깥 호 위의 점에서 안쪽으로 두께만큼 들어간 모양 (가운데 두껍고 양 끝 뾰족). 진행 방향(+dir)으로 볼록.
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
	var core := Color(core_color.r, core_color.g, core_color.b, alpha)
	for i in ARC_STEPS:
		if _arc_notch[i] > 0.0 or _arc_notch[i + 1] > 0.0:
			continue
		var a0 := lerpf(-HALF_ANGLE * 0.94, HALF_ANGLE * 0.94, float(i) / ARC_STEPS)
		var a1 := lerpf(-HALF_ANGLE * 0.94, HALF_ANGLE * 0.94, float(i + 1) / ARC_STEPS)
		draw_line(offset + Vector2(cos(a0) * direction, sin(a0)) * (r - 3.0),
				offset + Vector2(cos(a1) * direction, sin(a1)) * (r - 3.0), core, 3.0)


func _draw_shards(alpha: float) -> void:
	for s in _shards:
		var p := Vector2(s.x, s.y)
		var v := Vector2(s.z, s.w).normalized() * 9.0
		draw_line(p - v, p + v, Color(edge_color.r, edge_color.g, edge_color.b, alpha), 3.0)
