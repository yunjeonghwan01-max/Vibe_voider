class_name WatcherNeedle
extends Node2D

## 감시자의 공허 구체 (예전 이름 "바늘"). 일직선으로 날아가 플레이어를 맞힌다.
## 튕겨내기: 플레이어에게 deflect_range 안으로 다가오는 아주 짧은 순간(≈0.1초)만 금빛으로 살짝 빛난다.
##   그때 반격 키를 누르면 Player가 deflect()를 불러 검으로 지운다 (방향 무관, 감시자에게 패널티 없음).
##   Hitbox의 layer는 0 그대로라 ParryBox의 근접 반격 대상은 아니다 — Player가 "deflectable" 그룹을 직접 읽는다.
## 대시 무적 중이면 receive_hit이 성립하지 않아 그대로 통과한다.
## 벽(world)에 닿거나 수명이 다하면 부서진다. 한쪽 발판은 통과한다.

const ORB_RADIUS := 10.0   # 그리는 반지름 — 판정(Hitbox 원)은 씬에서 이보다 살짝 작게

@export var speed: float = 620.0
@export var damage: int = 8
@export var knockback: float = 170.0
@export var max_lifetime: float = 2.2
@export var deflect_range: float = 88.0   # 플레이어 중심까지 이 거리 안으로 다가오는 동안만 튕겨낼 수 있다 (닿는 거리 ≈26)
@export var spark_scene: PackedScene

@onready var hitbox: HitboxComponent = $Hitbox
@onready var collision: Area2D = $Collision

## 스폰하는 쪽이 add_child 전에 채운다.
var source: Node = null
var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null       # 튕겨내기 거리를 재는 대상 (플레이어)

var _t: float = 0.0
var _dead: bool = false
var _glint: bool = false
var _glint_t: float = 0.0


func _enter_tree() -> void:
	Tuning.apply(self)   # 같은 폴더의 <씬>_tuning.cfg — 자식 _ready()보다 먼저


func _ready() -> void:
	rotation = direction.angle()
	hitbox.source = source
	hitbox.damage = damage
	hitbox.knockback_force = knockback
	hitbox.knockback_direction = Vector2(signf(direction.x), -0.35).normalized()
	hitbox.hit_landed.connect(func(_h: HurtboxComponent) -> void: _shatter())
	collision.body_shape_entered.connect(_on_body_shape_entered)
	add_to_group("deflectable")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	global_position += direction * speed * delta
	_update_glint(delta)
	if _t >= max_lifetime:
		_shatter()
	queue_redraw()


## 플레이어를 향해 다가오며 deflect_range 안에 있는 동안만 빛난다. 스쳐 지나가면 꺼진다.
func _update_glint(delta: float) -> void:
	var was := _glint
	_glint = false
	if target != null and is_instance_valid(target):
		var to := target.global_position - global_position
		_glint = to.length_squared() <= deflect_range * deflect_range and to.dot(direction) > 0.0
	_glint_t = _glint_t + delta if _glint and was else 0.0


func is_deflectable() -> bool:
	return _glint and not _dead


## 플레이어가 검으로 지웠다 — 금빛 조각으로 흩어진다. 피해 없음.
func deflect() -> void:
	if _dead:
		return
	_dead = true
	hitbox.set_deferred("monitoring", false)
	collision.set_deferred("monitoring", false)
	if spark_scene != null:
		var fx := get_tree().get_first_node_in_group("fx")
		var s := spark_scene.instantiate() as SparkEffect
		(fx if fx else get_parent()).add_child(s)
		s.global_position = global_position
		s.burst(Color(1.0, 0.93, 0.58, 1.0), 12, 360.0, 0.0, 46.0, 0.2)
		s.with_ring(Color(1.0, 1.0, 0.9, 1.0), 44.0)
	queue_free()


func _on_body_shape_entered(_rid: RID, body: Node2D, body_shape_index: int, _local_shape_index: int) -> void:
	var co := body as CollisionObject2D
	if co != null and co.is_shape_owner_one_way_collision_enabled(co.shape_find_owner(body_shape_index)):
		return
	_shatter()


func _shatter() -> void:
	if _dead:
		return
	_dead = true
	hitbox.set_deferred("monitoring", false)
	collision.set_deferred("monitoring", false)
	if spark_scene != null:
		var fx := get_tree().get_first_node_in_group("fx")
		var s := spark_scene.instantiate() as SparkEffect
		(fx if fx else get_parent()).add_child(s)
		s.global_position = global_position
		s.burst(Color(1.0, 0.6, 0.5, 1.0), 6, 360.0, 0.0, 22.0, 0.14)
	queue_free()


func _draw() -> void:
	# 동그란 공허 구체: 뒤로 끌리는 붉은 잔광 + 붉은 테두리의 어두운 보라 몸 + 밝은 속 + 하이라이트. 살짝 맥동한다.
	var r := ORB_RADIUS * (1.0 + 0.08 * sin(_t * 30.0))
	for i in 3:
		var k := float(i + 1)
		draw_circle(Vector2(-k * 9.0, 0.0), r * (1.0 - k * 0.22), Color(1.0, 0.45, 0.4, 0.22 - k * 0.05))
	if _glint:
		# 튕겨낼 수 있는 순간: 금빛 후광이 살짝 켜진다 (켜지는 순간 조금 더 크게)
		var pop := 1.0 + 0.5 * maxf(1.0 - _glint_t * 25.0, 0.0)
		draw_circle(Vector2.ZERO, (r + 7.0) * pop, Color(1.0, 0.93, 0.58, 0.28))
		draw_arc(Vector2.ZERO, (r + 3.0) * pop, 0.0, TAU, 24, Color(1.0, 0.93, 0.58, 0.85), 2.0)
	draw_circle(Vector2.ZERO, r + 2.0, Color(1.0, 0.45, 0.4, 0.9))
	draw_circle(Vector2.ZERO, r, Color(0.32, 0.12, 0.3))
	draw_circle(Vector2.ZERO, r * 0.5, Color(1.0, 0.72, 0.62))
	draw_circle(Vector2(r * 0.3, -r * 0.3), r * 0.22, Color(1.0, 0.95, 0.9))
