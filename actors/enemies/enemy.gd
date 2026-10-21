class_name Enemy
extends CharacterBody2D

## 적 공통 기반 — 두 실사용자(Grunt, Duelist)가 공유하는 문법.
## 중력/이동/피격 반응(번쩍임·넉백·히트스턴)/반격당함(스태거)/등장/사망 연출을 담당한다.
## 구체 AI는 하위 클래스가 _enemy_ai(delta)를, 외형 애니메이션은 _animate(delta)를 오버라이드해 구현한다.
##
## 반짝임(glint): 모든 공격은 휘두르기 직전 glint_duration(0.4초) 동안 금빛으로 반짝인다.
##   이 시간 동안만 is_glinting()이 true → 플레이어가 그때 반격 키를 누르면 반격 성공.
##   하위 클래스가 공격 단계에서 begin_glint() / end_glint()로 구간을 연다/닫는다.
##
## 피격은 Combat/Health, Combat/Hurtbox 시그널로만 받는다 (take_damage를 직접 갖지 않는다).

signal defeated(enemy: Enemy)

enum State { SPAWNING, ACTIVE, HITSTUN, STAGGER, DEAD }

const GLINT_COLOR := Color(1.0, 0.93, 0.58)
const HIT_COLOR := Color(1.0, 0.42, 0.42)
const STAGGER_COLOR := Color(0.45, 0.9, 1.0)

@export_group("Body")
@export var gravity: float = 1400.0
@export var max_fall_speed: float = 1100.0
@export var move_speed: float = 120.0

@export_group("Reactions")
@export var hitstun_time: float = 0.14       # 피격 시 짧게 AI 정지 (타격감)
@export var parry_stagger_time: float = 1.0  # 반격당하면 큰 빈틈
@export var knockback_resist: float = 0.0    # 0 = 넉백 그대로, 1 = 완전 저항
@export var spawn_time: float = 0.6          # 등장 연출 동안은 공격하지 않고 맞지도 않는다

@export_group("Glint")
@export var glint_duration: float = 0.4      # 반격 가능한 반짝임 시간

@export_group("Scenes")
@export var spark_scene: PackedScene
@export var glint_scene: PackedScene

@onready var visual: Node2D = $Visual
@onready var body: Sprite2D = $Visual/Body
@onready var health: HealthComponent = $Combat/Health
@onready var hurtbox: HurtboxComponent = $Combat/Hurtbox
@onready var attack_hitbox: HitboxComponent = get_node_or_null("Combat/AttackHitbox")
@onready var sfx_glint: AudioStreamPlayer2D = get_node_or_null("Audio/Glint")
@onready var sfx_death: AudioStreamPlayer2D = get_node_or_null("Audio/Death")
@onready var sfx_spawn: AudioStreamPlayer2D = get_node_or_null("Audio/Spawn")

var state: int = State.SPAWNING
var facing: float = -1.0
var _state_timer: float = 0.0
var _target: Node2D = null
var _anim_t: float = 0.0             # 하위 클래스 애니메이션용 누적 시간

var _glinting: bool = false
var _glint_t: float = 0.0
var _glint_fx: Node2D = null
var _flash_amount: float = 0.0
var _flash_col: Color = Color.WHITE


func _ready() -> void:
	hurtbox.health = health          # 씬의 NodePath 직렬화에 의존하지 않고 코드로 확실히 연결
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	if attack_hitbox != null:
		attack_hitbox.source = self
		attack_hitbox.monitoring = false
	_find_target()
	facing = dir_to_target()
	_on_ready()
	_begin_spawn()


## 하위 클래스 초기화 훅.
func _on_ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	_anim_t += delta
	if _glinting:
		_glint_t += delta
	match state:
		State.DEAD:
			_apply_gravity(delta)
		State.SPAWNING:
			_state_timer -= delta
			_apply_gravity(delta)
			if _state_timer <= 0.0:
				state = State.ACTIVE
				hurtbox.invincible = false
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
	if state != State.DEAD:
		_animate(delta)


## 하위 클래스가 구현하는 AI. 기본은 정지.
func _enemy_ai(_delta: float) -> void:
	pass


## 하위 클래스가 구현하는 외형 애니메이션 (Body 프레임, 무기 각도 등).
func _animate(_delta: float) -> void:
	pass


## 스태거(반격당함)가 끝났을 때 훅.
func _on_stagger_end() -> void:
	pass


## true인 동안은 맞아도 경직되지 않는다(슈퍼아머). 공격 동작 중인 강한 적이 쓴다.
func _has_armor() -> bool:
	return false


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
	var d := signf(t.global_position.x - global_position.x)
	return d if d != 0.0 else facing


# ─────────────────────────── 반짝임 (반격 가능 구간) ───────────────────────────
## local_pos: 오른쪽을 볼 때 기준의 별빛 위치(무기 끝/눈). 좌우는 facing으로 맞춘다.
func begin_glint(local_pos: Vector2) -> void:
	_glinting = true
	_glint_t = 0.0
	_flash_amount = 0.0
	_sfx(sfx_glint, 0.03)
	if glint_scene != null:
		var g := glint_scene.instantiate() as GlintEffect
		g.lifetime = glint_duration
		add_child(g)                     # 반전되지 않는 루트에 붙이고 좌우는 값으로 넘긴다
		g.position = Vector2(local_pos.x * signf(facing), local_pos.y)
		_glint_fx = g


func end_glint() -> void:
	_glinting = false
	if _glint_fx != null and is_instance_valid(_glint_fx):
		_glint_fx.queue_free()
	_glint_fx = null


func is_glinting() -> bool:
	return _glinting and state == State.ACTIVE


# ─────────────────────────── 등장 ───────────────────────────
func _begin_spawn() -> void:
	state = State.SPAWNING
	_state_timer = spawn_time
	hurtbox.invincible = true
	visual.modulate.a = 0.0
	_flash_col = Color(0.6, 0.35, 1.0)
	_flash_amount = 1.0
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 1.0, spawn_time * 0.6)
	visual.scale = Vector2(0.4 * signf(facing), 1.6)
	_sfx(sfx_spawn, 0.05)
	_burst(Color(0.6, 0.4, 1.0, 1.0), 14, 60.0, 0.4, true)


# ─────────────────────────── 피격 / 반격당함 / 사망 ───────────────────────────
func _on_hit_received(_damage: int, source: Node, knockback: Vector2) -> void:
	if state == State.DEAD:
		return
	_flash_col = HIT_COLOR
	_flash_amount = 1.0
	var armored := _has_armor() and state == State.ACTIVE
	var resist := 0.85 if armored else knockback_resist
	if knockback != Vector2.ZERO:
		velocity += knockback * (1.0 - resist)
	elif source != null and source is Node2D:
		var away := signf(global_position.x - (source as Node2D).global_position.x)
		velocity.x += away * 160.0 * (1.0 - resist)
	visual.scale = Vector2(1.25 * signf(facing), 0.8)   # 맞는 순간 찌그러짐 (매 프레임 복구된다)
	if armored:
		return                           # 슈퍼아머: 공격 동작을 끊지 않는다
	if attack_hitbox != null:
		attack_hitbox.monitoring = false
	end_glint()
	if state != State.STAGGER:
		state = State.HITSTUN
		_state_timer = hitstun_time
	_on_hurt(source)


## 하위 클래스 피격 훅 (슈퍼아머로 버틴 피격에는 호출되지 않는다).
func _on_hurt(_source: Node) -> void:
	pass


## 플레이어가 반짝임 순간에 반격했을 때 호출된다.
func on_parried(from_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	end_glint()
	if attack_hitbox != null:
		attack_hitbox.monitoring = false
	state = State.STAGGER
	_state_timer = parry_stagger_time
	_flash_col = Color(1, 1, 1)
	_flash_amount = 1.0
	var away := signf(global_position.x - from_pos.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 300.0, -200.0)
	visual.scale = Vector2(0.75 * signf(facing), 1.3)
	_on_parried_react(from_pos)


## 하위 클래스 반격당함 훅.
func _on_parried_react(_from_pos: Vector2) -> void:
	pass


func _on_died() -> void:
	end_glint()
	state = State.DEAD
	hurtbox.monitoring = false
	hurtbox.set_deferred("monitorable", false)
	if attack_hitbox != null:
		attack_hitbox.monitoring = false
		attack_hitbox.set_deferred("monitorable", false)
	collision_layer = 0
	_burst(Color(0.75, 0.45, 1.0, 1.0), 22, 90.0, 0.4, true)
	_burst(Color(1.0, 0.55, 0.45, 1.0), 10, 50.0, 0.25, false)
	defeated.emit(self)
	GameFeel.hit_stop(0.08)
	GameFeel.shake(0.35)
	_sfx(sfx_death, 0.08)
	_die_dissolve()


func _die_dissolve() -> void:
	_set_flash(Color(0.85, 0.7, 1.0), 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(1.5 * signf(facing), 0.15), 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	# 사망음이 끝까지 들리도록 잠시 남아 있다가 사라진다.
	tween.chain().tween_interval(0.6)
	tween.chain().tween_callback(queue_free)


# ─────────────────────────── 연출 ───────────────────────────
func _update_flash(delta: float) -> void:
	if state == State.DEAD:
		return
	if _glinting:
		# 반격 신호: 몸 전체가 금빛으로 강하게 빛나며 맥동한다.
		var p := 0.5 + 0.5 * sin(_glint_t * 50.0)
		_set_flash(GLINT_COLOR, 0.62 + 0.3 * p)
	elif _flash_amount > 0.0:
		_flash_amount = maxf(_flash_amount - delta * 7.0, 0.0)
		_set_flash(_flash_col, _flash_amount)
	elif state == State.STAGGER:
		# 반격당한 빈틈 — 스태거 내내 청록빛으로 "지금 때려" 신호를 유지한다.
		_set_flash(STAGGER_COLOR, 0.38 + 0.12 * sin(_anim_t * 14.0))
	else:
		_set_flash(Color.WHITE, 0.0)


func _set_flash(color: Color, amount: float) -> void:
	var mat := visual.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash", amount)


func _update_visual(delta: float) -> void:
	if state == State.DEAD:
		return
	# 스쿼시 복구 — 어떤 상태(히트스턴/스태거 포함)에서도 매 프레임 크기를 1로 되돌린다.
	var mag := visual.scale.abs().lerp(Vector2.ONE, 1.0 - exp(-16.0 * delta))
	var sgn := signf(facing) if facing != 0.0 else 1.0
	visual.scale = Vector2(mag.x * sgn, mag.y)
	# 반짝이는 동안은 힘을 모으듯 미세하게 떤다.
	visual.position.x = randf_range(-1.0, 1.0) if _glinting else 0.0


func _sfx(player: AudioStreamPlayer2D, pitch_var: float) -> void:
	if player == null:
		return
	player.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	player.play()


func _fx_parent() -> Node:
	var fx := get_tree().get_first_node_in_group("fx")
	return fx if fx else get_parent()


func _burst(color: Color, count: int, length: float, lifetime: float, ring: bool) -> void:
	if spark_scene == null:
		return
	var s := spark_scene.instantiate() as SparkEffect
	_fx_parent().add_child(s)
	s.global_position = global_position + Vector2(0, -12)
	s.burst(color, count, 360.0, 0.0, length, lifetime)
	if ring:
		s.with_ring(color, length * 1.3)
