class_name Enemy
extends CharacterBody2D

## 적 공통 기반 — 두 실사용자(Grunt, Duelist)가 공유하는 문법.
## 중력/이동/피격 반응(플래시·넉백·히트스턴)/패링당함(스태거)/사망을 담당한다.
## 구체 AI는 하위 클래스가 _enemy_ai(delta)를 오버라이드해 구현한다.
##
## 피격은 Combat/Health, Combat/Hurtbox 시그널로만 받는다 (take_damage를 직접 갖지 않는다).

signal defeated(enemy: Enemy)

enum State { ACTIVE, HITSTUN, STAGGER, DEAD }

@export_group("Body")
@export var gravity: float = 1400.0
@export var max_fall_speed: float = 1100.0
@export var move_speed: float = 120.0

@export_group("Reactions")
@export var hitstun_time: float = 0.12       # 피격 시 짧게 AI 정지 (타격감)
@export var parry_stagger_time: float = 0.75  # 패링당하면 큰 빈틈
@export var knockback_resist: float = 0.0     # 0 = 넉백 그대로, 1 = 완전 저항
@export var flash_color: Color = Color(2.2, 1.2, 1.2, 1.0)
@export var stagger_color: Color = Color(0.6, 0.9, 1.3, 1.0)

@export_group("Scenes")
@export var spark_scene: PackedScene

@onready var visual: Node2D = $Visual
@onready var health: HealthComponent = $Combat/Health
@onready var hurtbox: HurtboxComponent = $Combat/Hurtbox
@onready var attack_hitbox: HitboxComponent = get_node_or_null("Combat/AttackHitbox")

var state: int = State.ACTIVE
var facing: float = -1.0
var _state_timer: float = 0.0
var _target: Node2D = null


func _ready() -> void:
	hurtbox.health = health          # 씬의 NodePath 직렬화에 의존하지 않고 코드로 확실히 연결
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	if attack_hitbox != null:
		attack_hitbox.source = self
		attack_hitbox.monitoring = false
	_find_target()
	_on_ready()


## 하위 클래스 초기화 훅.
func _on_ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	match state:
		State.DEAD:
			_apply_gravity(delta)
		State.HITSTUN:
			_state_timer -= delta
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
			_apply_gravity(delta)
			if _state_timer <= 0.0:
				state = State.ACTIVE
		State.STAGGER:
			_state_timer -= delta
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
			_apply_gravity(delta)
			if _state_timer <= 0.0:
				state = State.ACTIVE
				_on_stagger_end()
		_:
			_enemy_ai(delta)
			_apply_gravity(delta)

	move_and_slide()
	_update_flash(delta)
	_update_visual(delta)


## 하위 클래스가 구현하는 AI. 기본은 정지.
func _enemy_ai(_delta: float) -> void:
	pass


## 스태거(패링당함)가 끝났을 때 훅.
func _on_stagger_end() -> void:
	pass


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		return
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


# ─────────────────────────── 타깃 ───────────────────────────
func _find_target() -> void:
	_target = get_tree().get_first_node_in_group("player")


func get_target() -> Node2D:
	if _target == null or not is_instance_valid(_target):
		_find_target()
	return _target


func distance_to_target() -> float:
	var t := get_target()
	return INF if t == null else global_position.distance_to(t.global_position)


func dir_to_target() -> float:
	var t := get_target()
	if t == null:
		return facing
	return signf(t.global_position.x - global_position.x)


# ─────────────────────────── 피격 / 패링 / 사망 ───────────────────────────
func _on_hit_received(_damage: int, source: Node, knockback: Vector2) -> void:
	if state == State.DEAD:
		return
	_flash(flash_color)
	if attack_hitbox != null:
		attack_hitbox.monitoring = false
	if knockback != Vector2.ZERO:
		velocity += knockback * (1.0 - knockback_resist)
	elif source != null:
		var away := signf(global_position.x - source.global_position.x)
		velocity.x += away * 160.0 * (1.0 - knockback_resist)
	if state != State.STAGGER:
		state = State.HITSTUN
		_state_timer = hitstun_time
	_on_hurt(source)


## 하위 클래스 피격 훅.
func _on_hurt(_source: Node) -> void:
	pass


## 플레이어가 이 적의 공격을 패링했을 때 호출된다.
func on_parried(from_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	if attack_hitbox != null:
		attack_hitbox.monitoring = false
	state = State.STAGGER
	_state_timer = parry_stagger_time
	_flash(stagger_color)
	var away := signf(global_position.x - from_pos.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 260.0, -180.0)
	_on_parried_react(from_pos)


## 하위 클래스 패링 피격 훅.
func _on_parried_react(_from_pos: Vector2) -> void:
	pass


func _on_died() -> void:
	state = State.DEAD
	hurtbox.monitoring = false
	hurtbox.set_deferred("monitorable", false)
	if attack_hitbox != null:
		attack_hitbox.monitoring = false
	collision_layer = 0
	_spawn_death_spark()
	defeated.emit(self)
	GameFeel.hit_stop(0.07)
	GameFeel.shake(0.3)
	_die_dissolve()


func _die_dissolve() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", visual.scale * Vector2(1.3, 0.2), 0.28)
	tween.tween_property(visual, "modulate:a", 0.0, 0.28)
	tween.chain().tween_callback(queue_free)


# ─────────────────────────── 연출 ───────────────────────────
var _flash_amount: float = 0.0
var _flash_col: Color = Color.WHITE

func _flash(col: Color) -> void:
	_flash_col = col
	_flash_amount = 1.0


func _update_flash(delta: float) -> void:
	if state == State.DEAD:
		return
	if _flash_amount > 0.0:
		_flash_amount = maxf(_flash_amount - delta * 7.0, 0.0)
		visual.modulate = Color.WHITE.lerp(_flash_col, _flash_amount)
	elif state == State.STAGGER:
		# 패링당한 빈틈 — 스태거 내내 청록빛으로 "지금 때려" 신호를 유지한다.
		visual.modulate = Color(0.55, 0.8, 1.35)
	elif visual.modulate != Color.WHITE:
		visual.modulate = Color.WHITE


func _update_visual(delta: float) -> void:
	if state == State.DEAD:
		return
	# 스쿼시 복구 — 어떤 상태(히트스턴/스태거 포함)에서도 매 프레임 크기를 1로 되돌린다.
	# (예전엔 ACTIVE에서만 복구돼서 피격 중 눌린 채 멈추는 "뭉개짐" 버그가 있었다.)
	var mag := visual.scale.abs().lerp(Vector2.ONE, 1.0 - exp(-16.0 * delta))
	var sign := signf(facing) if facing != 0.0 else 1.0
	visual.scale = Vector2(mag.x * sign, mag.y)


func _spawn_death_spark() -> void:
	if spark_scene == null:
		return
	var fx := get_tree().get_first_node_in_group("fx")
	var parent: Node = fx if fx else get_parent()
	var s := spark_scene.instantiate() as SparkEffect
	parent.add_child(s)
	s.global_position = global_position + Vector2(0, -20)
	s.burst(Color(1.0, 0.5, 0.4, 1.0), 16, 360.0, 0.0, 70.0, 0.3)
