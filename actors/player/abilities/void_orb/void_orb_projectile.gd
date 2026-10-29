class_name VoidOrbProjectile
extends Node2D

## 장풍(공허 구체). 빠르게 일직선으로 날아가며 적을 관통한다.
## 다단히트: 같은 적과 겹쳐 있는 동안 hit_interval마다 다시 때린다 (적마다 최대 max_hits_per_target).
## 적마다 첫 타는 first_knockback으로 크게 밀어내고, 이후 타는 knockback_per_hit으로 살짝 민다.
## 벽(world)에 닿거나 카메라 화면 끝(진행 방향)에 닿으면 흩어진다 (max_distance는 안전장치).
## 한쪽으로만 막히는 발판은 그냥 지나간다.
##
## Hitbox는 apply_on_contact = false — 대상별 타이밍/데미지는 여기서 receive_hit()으로 직접 정한다.

signal hit_landed(hurtbox: HurtboxComponent)

@export var speed: float = 1725.0
@export var max_distance: float = 950.0
@export var damage_per_hit: int = 7           # × 최대 3타 ≈ 평타(10)의 2배
@export var max_hits_per_target: int = 3
@export var hit_interval: float = 0.03       # 빠른 구체라 짧게 — 스치는 동안 3타가 들어가게
@export var knockback_per_hit: float = 60.0
@export var first_knockback: float = 420.0   # 적마다 첫 타의 큰 넉백
@export var fade_time: float = 0.16
@export var spark_scene: PackedScene

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D
@onready var hitbox: HitboxComponent = $Hitbox
@onready var collision: Area2D = $Collision
@onready var sfx_hit: AudioStreamPlayer2D = $Audio/Hit

## 스폰하는 쪽이 add_child 전에 채운다.
var source: Node = null
var direction: float = 1.0

var _t: float = 0.0
var _travelled: float = 0.0
var _targets: Dictionary = {}        # HurtboxComponent -> { "hits": int, "next": float }
var _dying: bool = false
var _die_t: float = 0.0
var _pulse: float = 0.0              # 명중 순간 구체가 부풀었다 돌아온다


func _ready() -> void:
	hitbox.source = source
	hitbox.apply_on_contact = false
	hitbox.damage = damage_per_hit
	hitbox.hurtbox_entered.connect(_on_hurtbox_entered)
	collision.body_shape_entered.connect(_on_body_shape_entered)
	visual.scale = Vector2(0.45 * direction, 0.45)


func _physics_process(delta: float) -> void:
	_t += delta
	if _dying:
		_die_t += delta
		var u := clampf(_die_t / fade_time, 0.0, 1.0)
		visual.scale = Vector2(direction, 1.0) * (1.0 + u * 0.7)
		modulate.a = 1.0 - u
		queue_redraw()
		if u >= 1.0 and not sfx_hit.playing:
			queue_free()
		return

	var step := speed * delta
	global_position.x += direction * step
	_travelled += step
	_tick_multi_hits()
	if _travelled >= max_distance or _past_screen_edge():
		_dissipate()

	_pulse = maxf(_pulse - delta * 8.0, 0.0)
	var grow := minf(_t / 0.06, 1.0)              # 손에서 튀어나오며 커진다
	var s := lerpf(0.45, 1.0, grow) * (1.0 + _pulse * 0.18)
	visual.scale = Vector2(s * direction, s)
	sprite.frame = int(_t * 22.0) % sprite.hframes
	queue_redraw()


# ─────────────────────────── 다단히트 ───────────────────────────
func _on_hurtbox_entered(hurt: HurtboxComponent) -> void:
	if _dying:
		return
	_targets[hurt] = {"hits": 0, "next": 0.0}
	_try_hit(hurt)


func _tick_multi_hits() -> void:
	for hurt in _targets.keys():
		if not is_instance_valid(hurt):
			_targets.erase(hurt)
			continue
		var rec: Dictionary = _targets[hurt]
		if int(rec["hits"]) >= max_hits_per_target or _t < float(rec["next"]):
			continue
		if hitbox.overlaps_area(hurt):
			_try_hit(hurt)


func _try_hit(hurt: HurtboxComponent) -> void:
	var rec: Dictionary = _targets[hurt]
	var force := first_knockback if int(rec["hits"]) == 0 else knockback_per_hit
	var kb := Vector2(direction, -0.12).normalized() * force
	# 무적(등장 중 등)이면 성립하지 않는다 → 횟수를 쓰지 않고 다음 프레임에 다시 시도
	if not hurt.receive_hit(damage_per_hit, source, kb):
		return
	rec["hits"] = int(rec["hits"]) + 1
	rec["next"] = _t + hit_interval
	_on_hit(hurt, int(rec["hits"]) == 1)


func _on_hit(hurt: HurtboxComponent, first: bool) -> void:
	_pulse = 1.0
	sfx_hit.pitch_scale = randf_range(0.92, 1.1) + (0.0 if first else 0.08)
	sfx_hit.play()
	if first:
		GameFeel.hit_stop(0.035)
		GameFeel.shake(0.2)
	else:
		GameFeel.shake(0.08)
	_spawn_spark(hurt.global_position, 9 if first else 5, 58.0 if first else 40.0)
	hit_landed.emit(hurt)


# ─────────────────────────── 벽 / 소멸 ───────────────────────────
## 구체 중심이 카메라 화면의 진행 방향 끝을 넘었는가 (카메라가 따라 움직여도 그 순간의 화면 기준).
func _past_screen_edge() -> bool:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var a := inv * Vector2.ZERO
	var b := inv * get_viewport().get_visible_rect().size
	var x := global_position.x
	return x > maxf(a.x, b.x) if direction > 0.0 else x < minf(a.x, b.x)

func _on_body_shape_entered(_rid: RID, body: Node2D, body_shape_index: int, _local_shape_index: int) -> void:
	var co := body as CollisionObject2D
	if co != null:
		var owner_id := co.shape_find_owner(body_shape_index)
		if co.is_shape_owner_one_way_collision_enabled(owner_id):
			return                       # 한쪽 발판은 통과
	_dissipate()


func _dissipate() -> void:
	if _dying:
		return
	_dying = true
	hitbox.set_deferred("monitoring", false)
	collision.set_deferred("monitoring", false)
	_spawn_spark(global_position, 14, 70.0, 360.0)


func _spawn_spark(pos: Vector2, count: int, length: float, spread: float = 110.0) -> void:
	if spark_scene == null:
		return
	var fx := get_tree().get_first_node_in_group("fx")
	var s := spark_scene.instantiate() as SparkEffect
	(fx if fx else get_parent()).add_child(s)
	s.global_position = pos
	s.burst(Color(0.82, 0.62, 1.0, 1.0), count, spread, 0.0 if direction > 0.0 else 180.0, length, 0.2)


# ─────────────────────────── 잔광 ───────────────────────────
func _draw() -> void:
	# 구체 뒤 은은한 후광 + 뒤로 끌리는 잔상 + 흩날리는 공허 입자 (스프라이트보다 먼저 그려진다)
	var fade := 1.0 - (clampf(_die_t / fade_time, 0.0, 1.0) if _dying else 0.0)
	var halo := 44.0 * absf(visual.scale.y)
	draw_circle(Vector2.ZERO, halo, Color(0.55, 0.3, 1.0, 0.13 * fade))
	draw_circle(Vector2.ZERO, halo * 0.9, Color(0.6, 0.35, 1.0, 0.16 * fade))
	if _dying:
		return
	var reach := minf(_travelled / 140.0, 1.0)   # 손 뒤로 잔상이 삐져나오지 않게
	for k in range(1, 7):
		var u := float(k) / 7.0
		var p := Vector2(-direction * k * 15.0 * reach, 0.0)
		draw_circle(p, 34.0 * (1.0 - u), Color(0.5, 0.28, 0.95, 0.22 * (1.0 - u)))
	for i in 7:
		var off := fmod(_t * 520.0 + i * 41.0, 130.0) * reach
		var y := sin(_t * 18.0 + i * 1.9) * 24.0 * (1.0 - off / 140.0)
		var a := 0.75 * (1.0 - off / 130.0)
		draw_rect(Rect2(Vector2(-direction * (18.0 + off), y) - Vector2(2, 2), Vector2(4, 4)),
				Color(0.86, 0.72, 1.0, a))
