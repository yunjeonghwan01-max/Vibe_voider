class_name WatcherNeedle
extends Node2D

## 감시자의 바늘. 일직선으로 날아가 플레이어를 찌른다.
## 반격 불가 — 피해야 한다: Hitbox의 layer가 0이라 플레이어 ParryBox(mask=enemy_hitbox)가 감지하지 않는다.
## 대시 무적 중이면 receive_hit이 성립하지 않아 그대로 통과한다.
## 벽(world)에 닿거나 수명이 다하면 부서진다. 한쪽 발판은 통과한다.

@export var speed: float = 620.0
@export var damage: int = 8
@export var knockback: float = 170.0
@export var max_lifetime: float = 2.2
@export var spark_scene: PackedScene

@onready var hitbox: HitboxComponent = $Hitbox
@onready var collision: Area2D = $Collision

## 스폰하는 쪽이 add_child 전에 채운다.
var source: Node = null
var direction: Vector2 = Vector2.RIGHT

var _t: float = 0.0
var _dead: bool = false


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


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	global_position += direction * speed * delta
	if _t >= max_lifetime:
		_shatter()
	queue_redraw()


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
	# 진행 방향(+x)으로 뻗은 가는 바늘: 뒤로 끌리는 붉은 잔광 + 어두운 몸체 + 밝은 끝
	draw_line(Vector2(-46.0, 0.0), Vector2(-8.0, 0.0), Color(1.0, 0.45, 0.4, 0.28), 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(16.0, 0.0), Vector2(-4.0, -2.5), Vector2(-18.0, 0.0), Vector2(-4.0, 2.5)]),
		Color(0.32, 0.12, 0.3))
	draw_line(Vector2(-14.0, 0.0), Vector2(14.0, 0.0), Color(1.0, 0.72, 0.62), 1.5)
	draw_circle(Vector2(15.0, 0.0), 2.0, Color(1.0, 0.95, 0.9))
