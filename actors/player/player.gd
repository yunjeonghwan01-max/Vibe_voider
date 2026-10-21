class_name Player
extends CharacterBody2D

## 떠돌이 검사(검은 고양이). 빠르고 반응 좋은 이동 + 근접 전투의 핵심.
##
## 이동:  달리기(가감속) / 점프(코요테 타임 + 점프 버퍼 + 가변 높이) / 대시(무적·잔상)
## 전투:  3연속 참격 콤보 / 반격(패링) / 궁극기(전투로 충전, 수동 발동)
##
## 반격 규칙: 적이 공격 직전 0.4초 동안 금빛으로 "반짝"인다. 그 순간 반격 키를 눌러야만 성공한다.
##   - 누른 순간 ParryBox 안에 반짝이는 적의 공격 판정이 있으면 성공 → 적 경직, 공격 취소.
##   - 아니면 헛반격: 짧은 경직 + 재사용 대기(연타로는 맞출 수 없다). 헛반격엔 무적이 없다.
##
## 피격 반응은 Combat/Health, Combat/Hurtbox 시그널로만 받는다 (take_damage를 직접 갖지 않는다).
## 손맛(hit-stop/shake/VFX/SFX)은 명중·반격 순간에 적용한다.

signal health_changed(hp: int, max_hp: int)
signal ultimate_changed(charge: float, max_charge: float)
signal ultimate_ready_changed(is_ready: bool)
signal died

enum Action { NONE, ATTACK, PARRY, DASH, ULTIMATE, HURT, DEAD }

# ─────────────────────────── 이동 튜닝 ───────────────────────────
@export_group("Movement")
@export var run_speed: float = 330.0
@export var ground_accel: float = 2800.0
@export var ground_friction: float = 3200.0
@export var air_accel: float = 2000.0
@export var air_friction: float = 700.0
@export var gravity: float = 1500.0
@export var fall_gravity_mult: float = 1.55   # 하강은 더 빠르게 → 묵직하고 날렵한 점프
@export var max_fall_speed: float = 1000.0
@export var jump_velocity: float = -560.0
@export var jump_cut_mult: float = 0.42        # 점프 버튼을 떼면 상승 감쇠(가변 높이)
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12

@export_group("Dash")
@export var dash_speed: float = 760.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 0.30
@export var air_dashes: int = 1

# ─────────────────────────── 전투 튜닝 ───────────────────────────
@export_group("Combat")
@export var combo_damage: Array[int] = [10, 12, 20]
@export var combo_lunge: Array[float] = [200.0, 190.0, 300.0]
@export var combo_knockback: Array[float] = [160.0, 160.0, 320.0]
@export var combo_aim_degrees: Array[float] = [22.0, -22.0, 0.0]
@export var swing_windup: float = 0.035
@export var swing_active: float = 0.11
@export var swing_recovery: float = 0.10
@export var combo_reset_time: float = 0.32     # 마지막 입력 후 이 시간 지나면 콤보 초기화

@export_group("Parry")
@export var parry_success_time: float = 0.24     # 성공 후 자세 유지(무적)
@export var parry_whiff_time: float = 0.3        # 헛반격 경직 (무적 없음)
@export var parry_whiff_cooldown: float = 0.5    # 헛반격 후 재입력 금지 — 반짝임(0.4초)보다 길어서 연타가 안 통한다

@export_group("Ultimate")
@export var ultimate_max: float = 100.0
@export var ult_charge_on_parry: float = 34.0
@export var ult_charge_on_hit: float = 5.0
@export var ult_charge_on_damaged: float = 8.0
@export var ult_damage: int = 55
@export var ult_knockback: float = 560.0

@export_group("Scenes")
@export var slash_scene: PackedScene
@export var spark_scene: PackedScene
@export var afterimage_scene: PackedScene

# ─────────────────────────── 노드 ───────────────────────────
@onready var visual: PlayerVisual = $Visual
@onready var trail: Line2D = $Trail
@onready var health: HealthComponent = $Combat/Health
@onready var hurtbox: HurtboxComponent = $Combat/Hurtbox
@onready var attack_hitbox: HitboxComponent = $Combat/AttackHitbox
@onready var attack_shape: CollisionShape2D = $Combat/AttackHitbox/CollisionShape2D
@onready var parry_box: Area2D = $Combat/ParryBox
@onready var sfx_swing: Array[AudioStreamPlayer2D] = [
	$Audio/Swing1 as AudioStreamPlayer2D, $Audio/Swing2 as AudioStreamPlayer2D, $Audio/Swing3 as AudioStreamPlayer2D]
@onready var sfx_hit: AudioStreamPlayer2D = $Audio/Hit
@onready var sfx_hit_heavy: AudioStreamPlayer2D = $Audio/HitHeavy
@onready var sfx_parry: AudioStreamPlayer2D = $Audio/Parry
@onready var sfx_whiff: AudioStreamPlayer2D = $Audio/ParryWhiff
@onready var sfx_dash: AudioStreamPlayer2D = $Audio/Dash
@onready var sfx_jump: AudioStreamPlayer2D = $Audio/Jump
@onready var sfx_land: AudioStreamPlayer2D = $Audio/Land
@onready var sfx_step: AudioStreamPlayer2D = $Audio/Step
@onready var sfx_hurt: AudioStreamPlayer2D = $Audio/Hurt
@onready var sfx_death: AudioStreamPlayer2D = $Audio/Death
@onready var sfx_ult_cast: AudioStreamPlayer2D = $Audio/UltCast
@onready var sfx_ult_hit: AudioStreamPlayer2D = $Audio/UltHit

# ─────────────────────────── 상태 ───────────────────────────
var facing: float = 1.0
var action: int = Action.NONE
var ult_charge: float = 0.0

var _spawn_position: Vector2
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _dash_cd: float = 0.0
var _parry_cd: float = 0.0
var _air_dashes_left: int = 0

var _action_time: float = 0.0        # 현재 액션 경과 시간
var _combo_index: int = 0
var _combo_timer: float = 0.0        # 콤보 연결 유지 타이머
var _attack_buffered: bool = false
var _hitbox_live: bool = false       # 이번 스윙에서 판정이 켜졌는지
var _parry_success: bool = false

var _squash: Vector2 = Vector2.ONE   # 스쿼시&스트레치
var _attack_hitbox_base_pos: Vector2
var _was_on_floor: bool = false
var _run_bob: float = 0.0
var _flash_amount: float = 0.0
var _flash_color: Color = Color.WHITE


func _ready() -> void:
	_spawn_position = global_position
	hurtbox.health = health          # 씬의 NodePath 직렬화에 의존하지 않고 코드로 확실히 연결
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	attack_hitbox.hit_landed.connect(_on_attack_landed)
	visual.footstep.connect(_on_footstep)

	attack_hitbox.source = self
	attack_hitbox.monitoring = false
	attack_hitbox.apply_on_contact = true
	parry_box.monitoring = true      # 항상 감시 — 반격 키를 누른 그 순간의 겹침을 바로 읽는다
	_attack_hitbox_base_pos = attack_hitbox.position

	_air_dashes_left = air_dashes
	trail.clear_points()
	trail.top_level = true
	trail.visible = false

	health_changed.emit(health.hp, health.max_hp)
	ultimate_changed.emit(ult_charge, ultimate_max)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	match action:
		Action.DASH:
			_process_dash(delta)
		Action.ATTACK:
			_process_attack(delta)
		Action.PARRY:
			_process_parry(delta)
		Action.ULTIMATE:
			_process_ultimate(delta)
		Action.HURT:
			_process_hurt(delta)
		Action.DEAD:
			_apply_gravity(delta)
		_:
			_process_free(delta)

	move_and_slide()
	_update_facing_from_input()
	_update_visual(delta)
	_update_trail()


# ─────────────────────────── 타이머 ───────────────────────────
func _tick_timers(delta: float) -> void:
	if is_on_floor():
		_coyote = coyote_time
		if action != Action.DASH:
			_air_dashes_left = air_dashes
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_parry_cd = maxf(_parry_cd - delta, 0.0)
	if _combo_timer > 0.0:
		_combo_timer = maxf(_combo_timer - delta, 0.0)
		if _combo_timer == 0.0:
			_combo_index = 0


# ─────────────────────── 자유 상태(이동/입력) ───────────────────────
func _process_free(delta: float) -> void:
	# 액션 입력 우선순위: 궁극기 > 반격 > 대시 > 공격 > 점프
	# (반격은 타이밍이 생명이라 다른 입력에 밀리지 않게 앞에 둔다)
	if Input.is_action_just_pressed("player_ultimate") and is_ultimate_ready():
		_start_ultimate()
		return
	if Input.is_action_just_pressed("player_parry") and _parry_cd <= 0.0:
		_start_parry()
		return
	if Input.is_action_just_pressed("player_dash") and _can_dash():
		_start_dash()
		return
	if Input.is_action_just_pressed("player_attack"):
		_start_attack(0)
		return

	if Input.is_action_just_pressed("player_jump"):
		_jump_buffer = jump_buffer_time
	_try_jump()

	_apply_horizontal(delta, _move_input(), true)
	_apply_gravity(delta)


func _move_input() -> float:
	return Input.get_axis("player_move_left", "player_move_right")


func _apply_horizontal(delta: float, dir: float, _allow_turn: bool) -> void:
	var on_floor := is_on_floor()
	var accel := ground_accel if on_floor else air_accel
	var friction := ground_friction if on_floor else air_friction
	if absf(dir) > 0.01:
		velocity.x = move_toward(velocity.x, dir * run_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := gravity
	if velocity.y > 0.0:
		g *= fall_gravity_mult
	# 점프 버튼을 떼면 상승을 잘라 가변 높이를 만든다.
	if velocity.y < 0.0 and not Input.is_action_pressed("player_jump"):
		velocity.y *= jump_cut_mult
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _try_jump() -> void:
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash = Vector2(0.78, 1.26)
		_sfx(sfx_jump, 0.08)


# ─────────────────────────── 대시 ───────────────────────────
func _can_dash() -> bool:
	if _dash_cd > 0.0:
		return false
	if is_on_floor():
		return true
	return _air_dashes_left > 0


func _start_dash() -> void:
	action = Action.DASH
	_action_time = 0.0
	_dash_cd = dash_cooldown
	if not is_on_floor():
		_air_dashes_left -= 1
	var dir := _move_input()
	if absf(dir) < 0.01:
		dir = facing
	facing = signf(dir)
	velocity = Vector2(facing * dash_speed, 0.0)
	hurtbox.invincible = true
	trail.visible = true
	_squash = Vector2(1.35, 0.7)
	visual.play(&"dash")
	_sfx(sfx_dash, 0.06)
	_spawn_afterimage()


func _process_dash(delta: float) -> void:
	_action_time += delta
	velocity.y = 0.0
	velocity.x = facing * dash_speed
	if fmod(_action_time, 0.035) < delta:
		_spawn_afterimage()
	# 대시 중 공격 입력 → 대시 공격으로 캔슬(스타일리시), 반격 입력 → 반격
	if Input.is_action_just_pressed("player_attack"):
		_end_dash()
		_start_attack(0)
		return
	if Input.is_action_just_pressed("player_parry") and _parry_cd <= 0.0:
		_end_dash()
		_start_parry()
		return
	if _action_time >= dash_time:
		_end_dash()


func _end_dash() -> void:
	action = Action.NONE
	hurtbox.invincible = false
	trail.visible = false
	velocity.x *= 0.5
	visual.play(&"locomotion")


# ─────────────────────────── 공격 콤보 ───────────────────────────
func _start_attack(index: int) -> void:
	action = Action.ATTACK
	_action_time = 0.0
	_hitbox_live = false
	_attack_buffered = false
	_combo_index = clampi(index, 0, combo_damage.size() - 1)
	# 입력 방향으로 돌아보며 친다.
	var dir := _move_input()
	if absf(dir) > 0.01:
		facing = signf(dir)
	# 전진 런지
	var lunge: float = combo_lunge[_combo_index]
	velocity.x = facing * lunge
	_squash = Vector2(1.2, 0.86)
	attack_hitbox.reset_hits()
	attack_hitbox.position = Vector2(facing * absf(_attack_hitbox_base_pos.x), _attack_hitbox_base_pos.y)
	attack_hitbox.damage = combo_damage[_combo_index]
	attack_hitbox.knockback_force = combo_knockback[_combo_index]
	attack_hitbox.knockback_direction = Vector2(facing, -0.18).normalized()
	visual.play(StringName("attack_%d" % (_combo_index + 1)))
	_sfx(sfx_swing[_combo_index], 0.07)
	_spawn_slash(combo_aim_degrees[_combo_index])


func _process_attack(delta: float) -> void:
	_action_time += delta
	# 스윙 내내 공격 입력을 버퍼링 → 연타가 매끄럽게 이어진다(윈드업 중 눌러도 유효).
	if Input.is_action_just_pressed("player_attack"):
		_attack_buffered = true

	# 지상이면 마찰로 런지 감속, 공중이면 약한 제어
	if is_on_floor():
		velocity.x = move_toward(velocity.x, _move_input() * run_speed * 0.4, ground_friction * 0.6 * delta)
	else:
		_apply_horizontal(delta, _move_input() * 0.5, false)
	_apply_gravity(delta)

	var active_start := swing_windup
	var active_end := swing_windup + swing_active

	if _action_time >= active_start and _action_time < active_end and not _hitbox_live:
		_hitbox_live = true
		attack_hitbox.monitoring = true
	elif _action_time >= active_end and _hitbox_live:
		_hitbox_live = false
		attack_hitbox.monitoring = false

	# 반격은 스윙 어느 순간에도 끼어들 수 있다(타이밍을 놓치지 않게). 대시는 액티브 이후부터.
	if Input.is_action_just_pressed("player_parry") and _parry_cd <= 0.0:
		_end_attack()
		_start_parry()
		return
	if _action_time >= active_start and Input.is_action_just_pressed("player_dash") and _can_dash():
		_end_attack()
		_start_dash()
		return

	var total := swing_windup + swing_active + swing_recovery
	if _action_time >= total:
		if _attack_buffered and _combo_index < combo_damage.size() - 1:
			_start_attack(_combo_index + 1)
		else:
			_end_attack()


func _end_attack() -> void:
	attack_hitbox.monitoring = false
	_hitbox_live = false
	action = Action.NONE
	_combo_timer = combo_reset_time
	visual.play(&"locomotion")


func _on_attack_landed(hurt: HurtboxComponent) -> void:
	if action == Action.ULTIMATE:
		_on_ultimate_hit(hurt)
		return
	# 기본 콤보: 끊김이 안 느껴지게 프리즈는 가볍게, 마무리(3타)만 묵직하게
	var finisher := _combo_index >= combo_damage.size() - 1
	GameFeel.hit_stop(0.06 if finisher else 0.03)
	GameFeel.shake(0.34 if finisher else 0.17)
	_sfx(sfx_hit_heavy if finisher else sfx_hit, 0.1)
	_add_ultimate(ult_charge_on_hit)
	var hit_pos: Vector2 = hurt.global_position
	_spawn_spark(hit_pos, Color(1.0, 0.95, 0.7, 1.0), 10 if finisher else 7, 95.0,
			rad_to_deg(Vector2(facing, -0.2).angle()), 62.0 if finisher else 48.0)
	# 명중 시 살짝 더 파고드는 런지
	velocity.x = facing * maxf(absf(velocity.x), 120.0)


func _on_ultimate_hit(hurt: HurtboxComponent) -> void:
	# 궁극기 명중 — 맞는 적 몸에 강한 폭발형 버스트 + 화면 플래시
	GameFeel.hit_stop(0.09)
	GameFeel.shake(0.6)
	GameFeel.flash(Color(0.85, 0.6, 1.0), 0.28, 0.16)
	_sfx(sfx_ult_hit, 0.08)
	_spawn_impact(hurt.global_position)


func _spawn_impact(pos: Vector2) -> void:
	if spark_scene == null:
		return
	var s := spark_scene.instantiate() as SparkEffect
	_fx_parent().add_child(s)
	s.global_position = pos
	s.burst(Color(1.0, 0.85, 1.0, 1.0), 22, 360.0, 0.0, 110.0, 0.34)
	s.with_ring(Color(0.9, 0.7, 1.0, 1.0), 120.0)


# ─────────────────────────── 반격(패링) ───────────────────────────
func _start_parry() -> void:
	action = Action.PARRY
	_action_time = 0.0
	velocity.x = move_toward(velocity.x, 0.0, run_speed)
	_squash = Vector2(0.86, 1.14)

	var targets := _glinting_attackers()
	if targets.is_empty():
		# 헛반격 — 반짝이지 않을 때 눌렀다. 경직 + 재사용 대기, 무적 없음.
		_parry_success = false
		_parry_cd = parry_whiff_cooldown
		var dir := _move_input()
		if absf(dir) > 0.01:
			facing = signf(dir)
		visual.play(&"parry")
		_set_flash(Color(0.55, 0.7, 0.9), 0.35)
		_sfx(sfx_whiff, 0.05)
		_spawn_parry_stance(false)
		return

	_parry_success = true
	_parry_cd = 0.0                   # 성공하면 바로 다음 공격(연격)도 받아칠 수 있다
	facing = signf(targets[0].global_position.x - global_position.x)
	if facing == 0.0:
		facing = 1.0
	hurtbox.invincible = true
	visual.play(&"parry_success")
	_spawn_parry_stance(true)
	_trigger_parry_success(targets)


## ParryBox 안에서 지금 반짝이고 있는(= 반격 가능한) 적들.
func _glinting_attackers() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for area in parry_box.get_overlapping_areas():
		var hb := area as HitboxComponent
		if hb == null:
			continue
		var enemy := hb.source as Enemy
		if enemy != null and enemy.is_glinting() and not found.has(enemy):
			found.append(enemy)
	return found


func _process_parry(delta: float) -> void:
	_action_time += delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	_apply_gravity(delta)

	var duration := parry_success_time if _parry_success else parry_whiff_time
	if _action_time >= duration:
		action = Action.NONE
		hurtbox.invincible = false
		visual.play(&"locomotion")


func _trigger_parry_success(targets: Array[Enemy]) -> void:
	# 아주 명확한 손맛: 금속음 + 화면 플래시 + 긴 프리즈 + 큰 흔들림 + 양쪽 링 스파크 + 궁극기 대량 충전
	GameFeel.hit_stop(0.17, 0.02)
	GameFeel.shake(0.8)
	GameFeel.flash(Color(0.85, 0.97, 1.0), 0.55, 0.2)
	_sfx(sfx_parry, 0.04)
	_add_ultimate(ult_charge_on_parry)
	_set_flash(Color(0.85, 1.0, 1.0), 1.0)
	_spawn_parry_spark(global_position + Vector2(facing * 26.0, -16.0), 1.0)
	for enemy in targets:
		var contact := (global_position + enemy.global_position) * 0.5 + Vector2(0.0, -18.0)
		_spawn_parry_spark(contact, 1.4)
		enemy.on_parried(global_position)


# ─────────────────────────── 궁극기 ───────────────────────────
func is_ultimate_ready() -> bool:
	return ult_charge >= ultimate_max


func _add_ultimate(amount: float) -> void:
	var was_ready := is_ultimate_ready()
	ult_charge = clampf(ult_charge + amount, 0.0, ultimate_max)
	ultimate_changed.emit(ult_charge, ultimate_max)
	if is_ultimate_ready() != was_ready:
		ultimate_ready_changed.emit(is_ultimate_ready())


func _start_ultimate() -> void:
	action = Action.ULTIMATE
	_action_time = 0.0
	_hitbox_live = false
	ult_charge = 0.0
	ultimate_changed.emit(ult_charge, ultimate_max)
	ultimate_ready_changed.emit(false)
	hurtbox.invincible = true
	velocity = Vector2(0.0, -220.0)       # 살짝 떠오르며 발동
	_squash = Vector2(0.7, 1.4)
	GameFeel.hit_stop(0.08)
	GameFeel.shake(0.4)
	_sfx(sfx_ult_cast, 0.0)
	_set_flash(Color(0.85, 0.65, 1.0), 0.8)
	visual.play(&"ultimate")
	# 거대한 참격 — 전방위 스윕
	attack_hitbox.reset_hits()
	attack_hitbox.position = Vector2.ZERO
	attack_hitbox.damage = ult_damage
	attack_hitbox.knockback_force = ult_knockback
	attack_hitbox.knockback_direction = Vector2(facing, -0.3).normalized()
	attack_shape.scale = Vector2(3.4, 3.4)
	_spawn_slash(0.0, 2.6)
	_spawn_slash(180.0, 2.6)
	_spawn_parry_spark(global_position, 1.0)


func _process_ultimate(delta: float) -> void:
	_action_time += delta
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	_apply_gravity(delta)

	if _action_time >= 0.06 and not _hitbox_live:
		_hitbox_live = true
		attack_hitbox.monitoring = true
		trail.visible = true
	elif _action_time >= 0.28 and _hitbox_live:
		_hitbox_live = false
		attack_hitbox.monitoring = false

	if _action_time >= 0.5:
		# 원복
		attack_hitbox.monitoring = false
		attack_shape.scale = Vector2.ONE
		attack_hitbox.position = _attack_hitbox_base_pos
		hurtbox.invincible = false
		trail.visible = false
		action = Action.NONE
		visual.play(&"locomotion")


# ─────────────────────────── 피격 / 사망 ───────────────────────────
func _on_hit_received(damage: int, source: Node, knockback: Vector2) -> void:
	if health.hp - damage <= 0:
		return                          # 치명타는 _on_died가 처리
	_add_ultimate(ult_charge_on_damaged)
	GameFeel.hit_stop(0.07)
	GameFeel.shake(0.4)
	GameFeel.flash(Color(1.0, 0.25, 0.25), 0.18, 0.12)
	_sfx(sfx_hurt, 0.06)
	health_changed.emit(health.hp - damage, health.max_hp)

	# 넉백 + 피격 경직
	if knockback != Vector2.ZERO:
		velocity = knockback
	else:
		var dir := signf(global_position.x - source.global_position.x) if source else -facing
		velocity = Vector2(dir * 240.0, -160.0)
	action = Action.HURT
	_action_time = 0.0
	attack_hitbox.monitoring = false
	attack_shape.scale = Vector2.ONE
	trail.visible = false
	_set_flash(Color(1.0, 0.35, 0.35), 0.9)
	visual.play(&"hurt")


func _process_hurt(delta: float) -> void:
	_action_time += delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * 0.8 * delta)
	_apply_gravity(delta)
	# 짧은 경직 뒤 복귀 (대시로 탈출 허용 → 답답함 완화)
	if Input.is_action_just_pressed("player_dash") and _can_dash():
		_start_dash()
		return
	if _action_time >= 0.24:
		action = Action.NONE
		visual.play(&"locomotion")


func _on_died() -> void:
	action = Action.DEAD
	attack_hitbox.monitoring = false
	attack_shape.scale = Vector2.ONE
	hurtbox.invincible = true
	trail.visible = false
	velocity = Vector2(-facing * 200.0, -260.0)
	GameFeel.hit_stop(0.2)
	GameFeel.shake(0.8)
	GameFeel.flash(Color(1.0, 0.2, 0.25), 0.4, 0.4)
	_sfx(sfx_death, 0.0)
	_set_flash(Color(1.0, 0.3, 0.3), 1.0)
	visual.play(&"dead")
	health_changed.emit(0, health.max_hp)
	died.emit()
	_respawn_after(1.4)


func _respawn_after(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	global_position = _spawn_position
	velocity = Vector2.ZERO
	health.hp = health.max_hp
	ult_charge = 0.0
	action = Action.NONE
	hurtbox.invincible = false
	visual.rotation = 0.0
	visual.play(&"locomotion")
	_set_flash(Color(0.75, 0.55, 1.0), 1.0)
	_spawn_parry_spark(global_position, 1.0)
	health_changed.emit(health.hp, health.max_hp)
	ultimate_changed.emit(ult_charge, ultimate_max)
	ultimate_ready_changed.emit(false)


# ─────────────────────────── 표시/연출 ───────────────────────────
func _update_facing_from_input() -> void:
	if action == Action.NONE:
		var dir := _move_input()
		if absf(dir) > 0.01:
			facing = signf(dir)


func _update_visual(delta: float) -> void:
	# 스쿼시&스트레치 완화
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))

	# 착지 스쿼시 + 착지음
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and velocity.y >= 0.0:
		_squash = Vector2(1.3, 0.72)
		if action != Action.DEAD:
			_sfx(sfx_land, 0.08)
	_was_on_floor = on_floor

	# 달리기 바운스
	if on_floor and absf(velocity.x) > 40.0 and action == Action.NONE:
		_run_bob += delta * 18.0
		visual.position.y = -absf(sin(_run_bob)) * 2.5
	else:
		_run_bob = 0.0
		visual.position.y = lerp(visual.position.y, 0.0, 1.0 - exp(-14.0 * delta))

	visual.scale = Vector2(facing * _squash.x, _squash.y)
	if action == Action.DEAD:
		# 쓰러짐: 뒤로 넘어간다
		visual.rotation = lerp(visual.rotation, -facing * 1.35, 1.0 - exp(-10.0 * delta))
	else:
		# 속도에 따른 살짝의 기울임
		var lean := clampf(velocity.x / run_speed, -1.0, 1.0) * 0.07
		visual.rotation = lerp(visual.rotation, lean, 1.0 - exp(-12.0 * delta))

	visual.tick(delta, velocity, on_floor, run_speed)

	# 번쩍임 감쇠
	if _flash_amount > 0.0:
		_flash_amount = maxf(_flash_amount - delta * 5.0, 0.0)
		visual.set_flash(_flash_color, _flash_amount)


func _set_flash(color: Color, amount: float) -> void:
	_flash_color = color
	_flash_amount = amount
	visual.set_flash(color, amount)


func _update_trail() -> void:
	if not trail.visible:
		if trail.get_point_count() > 0:
			trail.clear_points()
		return
	trail.add_point(global_position + Vector2(0.0, -8.0))
	while trail.get_point_count() > 10:
		trail.remove_point(0)


func _on_footstep() -> void:
	_sfx(sfx_step, 0.15)


func _sfx(player: AudioStreamPlayer2D, pitch_var: float) -> void:
	player.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	player.play()


# ─────────────────────────── VFX 스폰 ───────────────────────────
func _fx_parent() -> Node:
	var fx := get_tree().get_first_node_in_group("fx")
	return fx if fx else get_parent()


func _spawn_slash(aim_degrees: float, scale_mul: float = 1.0) -> void:
	if slash_scene == null:
		return
	var s := slash_scene.instantiate() as SlashEffect
	_fx_parent().add_child(s)
	s.global_position = global_position + Vector2(facing * 30.0, -14.0)
	s.setup(facing, aim_degrees, scale_mul)


func _spawn_spark(pos: Vector2, color: Color, count: int, spread: float, dir_deg: float, length: float) -> void:
	if spark_scene == null:
		return
	var s := spark_scene.instantiate() as SparkEffect
	_fx_parent().add_child(s)
	s.global_position = pos
	s.burst(color, count, spread, dir_deg, length)


func _spawn_parry_spark(pos: Vector2, size_mul: float) -> void:
	if spark_scene == null:
		return
	var s := spark_scene.instantiate() as SparkEffect
	_fx_parent().add_child(s)
	s.global_position = pos
	s.burst(Color(0.8, 0.95, 1.0, 1.0), int(16 * size_mul), 360.0, 0.0, 78.0 * size_mul, 0.32)
	s.with_ring(Color(1.0, 1.0, 1.0, 1.0), 100.0 * size_mul)


func _spawn_parry_stance(success: bool) -> void:
	# 반격 자세: 앞쪽에 청록 호. 성공이면 크고 밝게, 헛반격이면 작고 흐리게.
	if slash_scene == null:
		return
	var s := slash_scene.instantiate() as SlashEffect
	s.color = Color(0.5, 0.9, 1.0, 0.85 if success else 0.35)
	s.core_color = Color(0.9, 1.0, 1.0, 1.0 if success else 0.5)
	s.arc_degrees = 160.0 if success else 110.0
	s.lifetime = 0.26 if success else 0.16
	_fx_parent().add_child(s)
	s.global_position = global_position + Vector2(facing * 26.0, -10.0)
	s.setup(facing, -10.0, 1.25 if success else 0.8)


func _spawn_afterimage() -> void:
	if afterimage_scene == null:
		return
	var a := afterimage_scene.instantiate() as Afterimage
	_fx_parent().add_child(a)
	a.setup_from_sprite(visual.body, Color(0.7, 0.5, 1.0, 1.0))
