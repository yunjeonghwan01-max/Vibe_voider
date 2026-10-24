class_name Player
extends CharacterBody2D

## 떠돌이 검사(검은 고양이). 빠르고 반응 좋은 이동 + 근접 전투의 핵심.
##
## 이동:  달리기(가감속) / 점프(코요테 타임 + 점프 버퍼 + 가변 높이) / 더블 점프(공중 1회) / 대시(무적·잔상)
## 전투:  3연속 참격 콤보 / 반격(패링) / 스킬(E: 장풍, 대시+E: 대시 참격, 위+E: 벼락) / 궁극기(전투로 충전, 수동 발동 — 월아 참격)
##
## 반격 규칙: 적이 공격 직전 0.4초 동안 금빛으로 "반짝"인다. 그 순간 반격 키를 눌러야만 성공한다.
##   - 카유공(감시자의 + 섬광, 0.4초): 바라보는 방향과 무관하게 반격 키로 받아친다 → X자 참격으로 즉사.
##     단, 그 입력이 ParryBox 안의 반짝이는 근접 공격 반격에 쓰였다면 카유공은 받아치지 못한다.
##   - 연쇄 반격: 반격(근접/카유공)에 성공한 뒤 chain_window(0.2초) 안에 반격 키를 다시 누르면 "예약"된다.
##     예약은 창이 끝날 때까지 유효해서, 그 사이 반짝임/카유공이 생기면 자동으로 받아친다.
##     끝까지 받아칠 게 없으면 헛반격 없이 조용히 끝난다. 받아칠 때마다 창이 다시 열려 계속 이어갈 수 있다.
##     창은 게임 시간으로 재므로 반격 연출의 정지(hit-stop) 동안에는 줄지 않는다.
##   - 패기 방출: 연쇄 반격이 3연속(3, 6, 9...번째) 이어지면 패왕색 패기(HakiBurst)가 터져
##     카메라 화면 안의 모든 적에게 피해를 주고 궁극기 게이지를 크게 채운다.
##   - 누른 순간 ParryBox 안에 반짝이는 적의 공격 판정이 있으면 성공 → 적 경직, 공격 취소.
##   - 아니면 헛반격: 짧은 경직 + 재사용 대기(연타로는 맞출 수 없다). 헛반격엔 무적이 없다.
##
## 피격 반응은 Combat/Health, Combat/Hurtbox 시그널로만 받는다 (take_damage를 직접 갖지 않는다).
## 손맛(hit-stop/shake/VFX/SFX)은 명중·반격 순간에 적용한다.

signal health_changed(hp: int, max_hp: int)
signal ultimate_changed(charge: float, max_charge: float)
signal ultimate_ready_changed(is_ready: bool)
signal died

enum Action { NONE, ATTACK, PARRY, DASH, SKILL, DASH_SLASH, LIGHTNING, ULTIMATE, HURT, DEAD }

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
@export var air_jumps: int = 1                 # 공중 점프 횟수 (착지하면 다시 채워진다)
@export var double_jump_velocity: float = -520.0

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
@export var counter_damage: int = 999            # 카유공 반격 결정타 기본값 (즉사). 적이 counter_strike_damage()로 바꿀 수 있다
@export var chain_window: float = 0.2            # 반격 성공 후 연쇄 반격 입력을 받는 시간
@export var haki_every: int = 3                  # 연쇄 반격이 이만큼 이어질 때마다 패기 방출
@export var haki_damage: int = 15                # 평타 1타(10)의 1.5배
@export var haki_ult_gain: float = 50.0          # 궁극기 게이지 (최대 100)

@export_group("Skill")
@export var skill_windup: float = 0.06         # 손을 내지르는 순간 발사
@export var skill_time: float = 0.24           # 시전 자세 전체 길이 (발사 후에는 대시로 끊을 수 있다)
@export var skill_recoil: float = 170.0        # 쏘는 반동으로 살짝 뒤로 밀린다
@export var skill_air_hang: float = 0.14       # 공중에서 쏘면 이 시간 동안 멈춰 떠 있는다
@export var ult_charge_on_skill_hit: float = 3.0

@export_group("Dash Slash")
@export var dash_slash_lunge: float = 480.0    # 대시가 끝난 뒤 조금 더 파고드는 속도
@export var dash_slash_grace: float = 0.12     # 대시가 끝난 뒤에도 이 시간 안에 E를 누르면 대시 참격 (코요테 타임처럼)
@export var dash_slash_windup: float = 0.03
@export var dash_slash_active: float = 0.1
@export var dash_slash_recovery: float = 0.15
@export var dash_slash_max_path: float = 360.0  # 대시로 지나온 길을 베는 최대 거리
@export var dash_slash_path_margin: float = 40.0 # 베는 동안 앞으로 파고드는 만큼 뒤쪽 판정을 넉넉히

@export_group("Lightning")
@export var lightning_recovery: float = 0.2      # 번개가 꽂힌 뒤에도 이만큼 이동 불가 (도달 전에는 공중이면 떠 있다)

@export_group("Ultimate")
@export var ultimate_max: float = 100.0
@export var ult_charge_on_parry: float = 34.0
@export var ult_charge_on_hit: float = 5.0
@export var ult_charge_on_damaged: float = 8.0
@export var ult_windup: float = 0.14           # 검을 크게 치켜들었다가 내려 베는 순간 발사
@export var ult_time: float = 0.5
@export var moon_slash_scene: PackedScene

@export_group("Scenes")
@export var slash_scene: PackedScene
@export var spark_scene: PackedScene
@export var afterimage_scene: PackedScene
@export var counter_slash_scene: PackedScene
@export var haki_scene: PackedScene

# ─────────────────────────── 노드 ───────────────────────────
@onready var visual: PlayerVisual = $Visual
@onready var trail: Line2D = $Trail
@onready var health: HealthComponent = $Combat/Health
@onready var hurtbox: HurtboxComponent = $Combat/Hurtbox
@onready var attack_hitbox: HitboxComponent = $Combat/AttackHitbox
@onready var parry_box: Area2D = $Combat/ParryBox
@onready var void_orb: VoidOrbAbility = $Combat/VoidOrb
@onready var dash_slash: DashSlashAbility = $Combat/DashSlash
@onready var lightning: LightningAbility = $Combat/Lightning
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
@onready var sfx_orb_cast: AudioStreamPlayer2D = $Audio/OrbCast
@onready var sfx_dash_slash: AudioStreamPlayer2D = $Audio/DashSlash
@onready var sfx_dash_slash_ring: AudioStreamPlayer2D = $Audio/DashSlashRing
@onready var sfx_dash_slash_hit: AudioStreamPlayer2D = $Audio/DashSlashHit

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
var _air_jumps_left: int = 0

var _action_time: float = 0.0        # 현재 액션 경과 시간
var _combo_index: int = 0
var _combo_timer: float = 0.0        # 콤보 연결 유지 타이머
var _attack_buffered: bool = false
var _hitbox_live: bool = false       # 이번 스윙에서 판정이 켜졌는지
var _parry_success: bool = false
var _chain_t: float = 0.0              # 연쇄 반격 창 남은 시간 (반격 성공 시 열림)
var _chain_armed: bool = false         # 창 안에서 반격 키를 눌러 예약됨 → 받아칠 게 생기면 자동 반격
var _chain_skip_press: bool = false    # 창을 연 바로 그 입력으로 예약되지 않게 한 화면 프레임 건너뛴다
var _chain_count: int = 0              # 이어진 연쇄 수 (반격음이 점점 높아진다)
var _counter_buffered: bool = false    # 슬로모션 중 화면 프레임에서 받은 방향 무관 반격 입력 (다음 물리 프레임에 쓴다)
var _skill_fired: bool = false
var _dash_slash_queued: bool = false   # 대시 중 E 입력 → 대시가 끝나면 대시 참격
var _dash_slash_window: float = 0.0    # 대시 직후 대시 참격 유예 시간 (남은 초)
var _dash_start_pos: Vector2 = Vector2.ZERO   # 마지막 대시를 시작한 곳 — 대시 참격이 지나온 길까지 벤다
var _lightning_struck: bool = false

var _squash: Vector2 = Vector2.ONE   # 스쿼시&스트레치
var _attack_hitbox_base_pos: Vector2
var _was_on_floor: bool = false
var _run_bob: float = 0.0
var _flash_amount: float = 0.0
var _flash_color: Color = Color.WHITE


func _enter_tree() -> void:
	Tuning.apply(self)   # 같은 폴더의 <씬>_tuning.cfg — 자식 _ready()보다 먼저


func _ready() -> void:
	_spawn_position = global_position
	hurtbox.health = health          # 씬의 NodePath 직렬화에 의존하지 않고 코드로 확실히 연결
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	attack_hitbox.hit_landed.connect(_on_attack_landed)
	visual.footstep.connect(_on_footstep)
	void_orb.hit_landed.connect(_on_skill_hit)
	void_orb.ready_again.connect(_on_skill_ready)
	dash_slash.hit_landed.connect(_on_dash_slash_landed)
	lightning.hit_landed.connect(_on_lightning_hit)

	attack_hitbox.source = self
	attack_hitbox.monitoring = false
	attack_hitbox.apply_on_contact = true
	parry_box.monitoring = true      # 항상 감시 — 반격 키를 누른 그 순간의 겹침을 바로 읽는다
	_attack_hitbox_base_pos = attack_hitbox.position

	_air_dashes_left = air_dashes
	_air_jumps_left = air_jumps
	trail.clear_points()
	trail.top_level = true
	trail.visible = false

	health_changed.emit(health.hp, health.max_hp)
	ultimate_changed.emit(ult_charge, ultimate_max)


func _process(_delta: float) -> void:
	# 보스의 역반격 창처럼 세상이 느려진 동안엔 물리 프레임이 드물다 — 그 사이의 반격 입력을 모아 둔다.
	if Engine.time_scale < 1.0 and Input.is_action_just_pressed("player_parry") and _can_take_counter_press() 			and not _open_counter_threats().is_empty():
		_counter_buffered = true
	# 연쇄 반격 입력은 hit-stop(물리 정지) 중에도 놓치지 않도록 화면 프레임마다 읽는다.
	if _chain_skip_press:
		_chain_skip_press = false
		return
	if _chain_t > 0.0 and not _chain_armed and Input.is_action_just_pressed("player_parry"):
		_chain_armed = true
		_set_flash(Color(0.6, 0.95, 1.0), 0.7)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_tick_chain(delta)
	if _counter_buffered:
		_counter_buffered = false
		if _can_take_counter_press() and not _open_counter_threats().is_empty():
			_start_parry()

	match action:
		Action.DASH:
			_process_dash(delta)
		Action.ATTACK:
			_process_attack(delta)
		Action.PARRY:
			_process_parry(delta)
		Action.SKILL:
			_process_skill(delta)
		Action.LIGHTNING:
			_process_lightning(delta)
		Action.DASH_SLASH:
			_process_dash_slash(delta)
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
			_air_jumps_left = air_jumps
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_parry_cd = maxf(_parry_cd - delta, 0.0)
	_dash_slash_window = maxf(_dash_slash_window - delta, 0.0)
	if _combo_timer > 0.0:
		_combo_timer = maxf(_combo_timer - delta, 0.0)
		if _combo_timer == 0.0:
			_combo_index = 0


# ─────────────────────── 자유 상태(이동/입력) ───────────────────────
func _process_free(delta: float) -> void:
	# 액션 입력 우선순위: 궁극기 > 반격 > (대시+스킬 동시 = 대시 참격) > 스킬 > 대시 > 공격 > 점프
	# (반격은 타이밍이 생명이라 다른 입력에 밀리지 않게 앞에 둔다)
	if Input.is_action_just_pressed("player_ultimate") and is_ultimate_ready():
		_start_ultimate()
		return
	if Input.is_action_just_pressed("player_parry") and _parry_cd <= 0.0:
		_start_parry()
		return
	if Input.is_action_just_pressed("player_dash") and Input.is_action_just_pressed("player_skill") \
			and _can_dash() and dash_slash.can_use():
		_start_dash()                    # 같은 프레임의 E는 _start_dash가 대시 참격으로 예약한다
		return
	# 대시가 막 끝난 유예 시간 안의 E는 (위를 누르고 있어도) 대시 참격 — 대시 중과 같은 규칙
	if Input.is_action_just_pressed("player_skill") and _dash_slash_window > 0.0 and dash_slash.can_use():
		_start_dash_slash()
		return
	# 위(W/↑)를 누른 채 E = 벼락. 쿨다운 중이면 아무것도 나가지 않는다 (장풍으로 새지 않게).
	if Input.is_action_just_pressed("player_skill") and _up_held():
		if lightning.can_cast():
			_start_lightning()
			return
	elif Input.is_action_just_pressed("player_skill") and void_orb.can_cast():
		_start_skill()
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


func _up_held() -> bool:
	return Input.is_action_pressed("player_move_up")


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
	elif Input.is_action_just_pressed("player_jump") and _coyote <= 0.0 and _air_jumps_left > 0:
		_double_jump()


## 공중에서 한 번 더 — 발밑에서 보랏빛 고리가 터지며 다시 솟구친다. 가변 높이(버튼 떼면 감쇠)도 그대로 적용된다.
func _double_jump() -> void:
	_air_jumps_left -= 1
	_jump_buffer = 0.0
	velocity.y = double_jump_velocity
	_squash = Vector2(0.72, 1.32)
	_sfx(sfx_jump, 0.05)
	sfx_jump.pitch_scale *= 1.3              # 첫 점프보다 높은 소리
	_spawn_afterimage()
	if spark_scene != null:
		var s := spark_scene.instantiate() as SparkEffect
		_fx_parent().add_child(s)
		s.global_position = global_position + Vector2(0.0, 26.0)
		s.burst(Color(0.78, 0.55, 1.0, 1.0), 10, 140.0, 90.0, 34.0, 0.2)   # 발밑 아래쪽으로 뿜는다
		s.with_ring(Color(0.85, 0.7, 1.0, 1.0), 46.0)


# ─────────────────────────── 대시 ───────────────────────────
func _can_dash() -> bool:
	if _dash_cd > 0.0:
		return false
	if is_on_floor():
		return true
	return _air_dashes_left > 0


func _start_dash() -> void:
	action = Action.DASH
	_dash_start_pos = global_position
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
	_dash_slash_queued = false
	if Input.is_action_just_pressed("player_skill"):
		_queue_dash_slash()


func _process_dash(delta: float) -> void:
	_action_time += delta
	velocity.y = 0.0
	velocity.x = facing * dash_speed
	if fmod(_action_time, 0.035) < delta:
		_spawn_afterimage()
	# 대시 중 스킬 입력 → 대시가 끝나면 대시 참격(예약), 공격 입력 → 대시 공격으로 캔슬, 반격 입력 → 반격
	if Input.is_action_just_pressed("player_skill"):
		_queue_dash_slash()
	if Input.is_action_just_pressed("player_attack") and not _dash_slash_queued:
		_end_dash()
		_start_attack(0)
		return
	if Input.is_action_just_pressed("player_parry") and _parry_cd <= 0.0:
		_end_dash()
		_start_parry()
		return
	if _action_time >= dash_time:
		var queued := _dash_slash_queued
		_end_dash()
		if queued and dash_slash.can_use():
			_start_dash_slash()
		else:
			_dash_slash_window = dash_slash_grace   # 대시를 끝까지 탔으면 잠깐 더 받아준다


func _end_dash() -> void:
	action = Action.NONE
	_dash_slash_queued = false
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
	# 판정이 끝난 뒤(후딜)에는 장풍/벼락으로 이어 쓸 수 있다 — 베고 바로 쏘는 콤보
	if _action_time >= active_end and Input.is_action_just_pressed("player_skill"):
		if _up_held():
			if lightning.can_cast():
				_end_attack()
				_start_lightning()
				return
		elif void_orb.can_cast():
			_end_attack()
			_start_skill()
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


# ─────────────────────────── 스킬: 장풍 ───────────────────────────
func _start_skill() -> void:
	action = Action.SKILL
	_action_time = 0.0
	_skill_fired = false
	var dir := _move_input()
	if absf(dir) > 0.01:
		facing = signf(dir)
	velocity.x *= 0.3
	if not is_on_floor():
		velocity.y = 0.0               # 공중 시전: 잠깐 멈춰 떠서 쏜다
	_squash = Vector2(0.86, 1.14)
	visual.play(&"cast")


func _process_skill(delta: float) -> void:
	_action_time += delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * 0.5 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
	if is_on_floor() or _action_time >= skill_air_hang:
		_apply_gravity(delta)
	else:
		velocity.y = 0.0

	# 쏘기 직전에 대시가 들어오면 "E와 대시를 거의 동시에" 누른 것 → 장풍 대신 대시 참격
	if not _skill_fired and Input.is_action_just_pressed("player_dash") and _can_dash() and dash_slash.can_use():
		_start_dash()
		_queue_dash_slash()
		return
	if not _skill_fired and _action_time >= skill_windup:
		_fire_skill()

	# 발사 후에는 대시/반격으로 끊을 수 있다
	if _skill_fired:
		if Input.is_action_just_pressed("player_parry") and _parry_cd <= 0.0:
			_start_parry()
			return
		if Input.is_action_just_pressed("player_dash") and _can_dash():
			_start_dash()
			return
	if _action_time >= skill_time:
		action = Action.NONE
		visual.play(&"locomotion")


func _fire_skill() -> void:
	_skill_fired = true
	void_orb.cast(self, facing)
	velocity.x = -facing * skill_recoil  # 쏘는 반동
	_squash = Vector2(1.28, 0.82)
	GameFeel.shake(0.14)
	_sfx(sfx_orb_cast, 0.06)
	_set_flash(Color(0.75, 0.55, 1.0), 0.6)
	_spawn_spark(global_position + Vector2(facing * 34.0, -8.0), Color(0.85, 0.7, 1.0, 1.0), 8, 70.0,
			0.0 if facing > 0.0 else 180.0, 40.0)


func _on_skill_hit(_hurt: HurtboxComponent) -> void:
	_add_ultimate(ult_charge_on_skill_hit)


func _on_skill_ready() -> void:
	# 쿨다운이 끝났다는 신호 — 몸이 은은하게 보랏빛으로 한 번 빛난다
	if action != Action.DEAD and _flash_amount < 0.3:
		_set_flash(Color(0.75, 0.55, 1.0), 0.4)


# ─────────────────────────── 스킬: 벼락 ───────────────────────────
## 시전하면 그 자리에 굳는다(이동 불가). 공중이면 번개가 도달할 때까지 떠 있고, 도달 후 lightning_recovery만큼 더 굳는다.
func _start_lightning() -> void:
	action = Action.LIGHTNING
	_action_time = 0.0
	_lightning_struck = false
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y = 0.0
	_squash = Vector2(0.85, 1.18)
	_set_flash(Color(0.7, 0.5, 1.0), 0.5)
	visual.play(&"cast_up")
	lightning.cast(self)


func _process_lightning(delta: float) -> void:
	_action_time += delta
	velocity.x = 0.0
	var arrived := _action_time >= lightning.travel_time
	if not arrived:
		velocity.y = 0.0               # 번개가 닿을 때까지 공중에 떠 있다
		return
	if not _lightning_struck:
		_lightning_struck = true
		_squash = Vector2(1.3, 0.75)
		_set_flash(Color(0.92, 0.82, 1.0), 1.0)
	_apply_gravity(delta)
	# 번개가 꽂힌 뒤에는 반격으로만 끊을 수 있다 (이동은 여전히 불가)
	if Input.is_action_just_pressed("player_parry") and _parry_cd <= 0.0:
		_start_parry()
		return
	if _action_time >= lightning.travel_time + lightning_recovery:
		action = Action.NONE
		visual.play(&"locomotion")


func _on_lightning_hit(_hurt: HurtboxComponent) -> void:
	_add_ultimate(ult_charge_on_hit)


# ─────────────────────────── 스킬: 대시 참격 ───────────────────────────
func _queue_dash_slash() -> void:
	if _dash_slash_queued or not dash_slash.can_use():
		return
	_dash_slash_queued = true
	_set_flash(Color(0.9, 0.8, 1.0), 0.55)   # 예약됐다는 작은 신호


func _start_dash_slash() -> void:
	action = Action.DASH_SLASH
	_dash_slash_window = 0.0
	_action_time = 0.0
	_hitbox_live = false
	velocity = Vector2(facing * dash_slash_lunge, 0.0)
	_squash = Vector2(1.32, 0.78)
	trail.visible = true
	# 대시로 지나온 길(대시 시작점 → 지금)도 함께 벤다
	var path := (global_position.x - _dash_start_pos.x) * facing
	var back := 0.0
	if path > 1.0:
		back = minf(path + dash_slash_path_margin, dash_slash_max_path)
	dash_slash.begin(self, facing, back)
	visual.play(&"dash_slash")
	_sfx(sfx_dash_slash, 0.06)
	_sfx(sfx_dash_slash_ring, 0.03)      # 전용 칼날 울림 "스링—"
	GameFeel.shake(0.12)
	_spawn_afterimage()


func _process_dash_slash(delta: float) -> void:
	_action_time += delta
	var active_start := dash_slash_windup
	var active_end := dash_slash_windup + dash_slash_active

	# 앞으로 미끄러지듯 파고들었다가 감속. 베는 동안은 공중에서도 떨어지지 않는다(대시의 연장).
	var friction := ground_friction * 0.55 if is_on_floor() else air_friction * 2.0
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if _action_time < active_end:
		velocity.y = 0.0
	else:
		_apply_gravity(delta)

	if _action_time >= active_start and _action_time < active_end and not _hitbox_live:
		_hitbox_live = true
		dash_slash.set_active(true)
	elif _action_time >= active_end and _hitbox_live:
		_hitbox_live = false
		dash_slash.set_active(false)
		trail.visible = false

	# 후딜에는 반격/평타로 이어갈 수 있다
	if _action_time >= active_end:
		if Input.is_action_just_pressed("player_parry") and _parry_cd <= 0.0:
			_end_dash_slash()
			_start_parry()
			return
		if Input.is_action_just_pressed("player_attack"):
			_end_dash_slash()
			_start_attack(0)
			return

	if _action_time >= active_end + dash_slash_recovery:
		_end_dash_slash()
		visual.play(&"locomotion")


func _end_dash_slash() -> void:
	dash_slash.set_active(false)
	_hitbox_live = false
	trail.visible = false
	action = Action.NONE


func _on_dash_slash_landed(hurt: HurtboxComponent) -> void:
	GameFeel.hit_stop(0.065)
	GameFeel.shake(0.36)
	_sfx(sfx_dash_slash_hit, 0.08)       # 전용 명중음 "촥!"
	_set_flash(Color(0.9, 0.8, 1.0), 0.5)
	_add_ultimate(ult_charge_on_hit)
	_spawn_spark(hurt.global_position, Color(0.92, 0.8, 1.0, 1.0), 10, 50.0,
			0.0 if facing > 0.0 else 180.0, 64.0)


# ─────────────────────────── 반격(패링) ───────────────────────────
func _start_parry() -> void:
	action = Action.PARRY
	_action_time = 0.0
	velocity.x = move_toward(velocity.x, 0.0, run_speed)
	_squash = Vector2(0.86, 1.14)

	var targets := _glinting_attackers()
	if targets.is_empty():
		# 반짝이는 근접 공격이 없으면, 열려 있는 카유공을 방향 무관하게 받아친다.
		var threats := _open_counter_threats()
		if not threats.is_empty():
			_start_counter(threats)
			return
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
	_open_chain()
	facing = signf(targets[0].global_position.x - global_position.x)
	if facing == 0.0:
		facing = 1.0
	hurtbox.invincible = true
	visual.play(&"parry_success")
	_spawn_parry_stance(true)
	_trigger_parry_success(targets)
	_check_haki()


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


## 카유공 창이 열려 있는 적들 (방향·거리 무관).
func _open_counter_threats() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("counter_threat"):
		var enemy := n as Enemy
		if enemy != null and enemy.is_counter_open():
			found.append(enemy)
	return found


## 카유공 반격 성공 — 세상이 거의 멈추고, 각 대상 몸에 검보라 X자 참격을 새겨 즉사시킨다.
func _start_counter(threats: Array[Enemy]) -> void:
	_parry_success = true
	_parry_cd = 0.0
	_open_chain()
	facing = signf(threats[0].global_position.x - global_position.x)
	if facing == 0.0:
		facing = 1.0
	hurtbox.invincible = true
	visual.play(&"parry_success")
	_spawn_parry_stance(true)
	GameFeel.hit_stop(0.16, 0.05)
	GameFeel.flash(Color(0.3, 0.05, 0.45), 0.22, 0.2)
	GameFeel.shake(0.6)
	_sfx(sfx_parry, 0.0)
	sfx_parry.pitch_scale *= 1.0 + 0.07 * _chain_count
	_add_ultimate(ult_charge_on_parry)
	_set_flash(Color(0.75, 0.45, 1.0), 1.0)
	_spawn_parry_spark(global_position + Vector2(facing * 26.0, -16.0), 1.2)
	for enemy in threats:
		# 반격당한 뒤에는 적의 상태가 바뀌므로 결정타 데미지를 먼저 묻는다 (0 = X자 없이 경직만)
		var dmg := enemy.counter_strike_damage(counter_damage)
		enemy.on_countered(global_position)
		if dmg > 0:
			_spawn_counter_slash(enemy, dmg)
	_check_haki()


func _spawn_counter_slash(enemy: Enemy, dmg: int) -> void:
	if counter_slash_scene == null:
		return
	var cs := counter_slash_scene.instantiate() as XSlash
	cs.target = enemy.hurtbox
	cs.source = self
	cs.damage = dmg
	cs.from_pos = global_position + Vector2(0.0, -8.0)
	_fx_parent().add_child(cs)
	cs.global_position = enemy.global_position


# ─────────────────────────── 연쇄 반격 ───────────────────────────
## 반격 성공 순간 호출 — 연쇄 창을 (다시) 연다. 이미 창 안에서 이어진 성공이면 연쇄 수가 오른다.
func _open_chain() -> void:
	_chain_count = _chain_count + 1 if _chain_t > 0.0 or _chain_armed else 0
	_chain_t = chain_window
	_chain_armed = false
	_chain_skip_press = true


## 연쇄 반격이 haki_every번째로 이어진 순간이면 패기를 방출한다 (반격 연출이 먼저 걸린 뒤에 불러야
## 패기의 슬로모션이 반격 hit-stop에 덮이지 않는다).
func _check_haki() -> void:
	if haki_scene == null or (_chain_count + 1) % haki_every != 0:
		return
	var h := haki_scene.instantiate() as HakiBurst
	h.source = self
	h.damage = haki_damage
	_fx_parent().add_child(h)
	h.global_position = global_position + Vector2(0.0, -8.0)
	_add_ultimate(haki_ult_gain)
	_set_flash(Color(1.0, 0.25, 0.3), 1.0)


## 치트/디버그: 연쇄 반격을 haki_every(3)번 이어 간 것처럼 패기 방출을 바로 터뜨린다 (그 단계의 반격음과 함께).
func force_chain_burst() -> void:
	if action == Action.DEAD:
		return
	_chain_count = haki_every - 1
	_sfx(sfx_parry, 0.0)
	sfx_parry.pitch_scale *= 1.0 + 0.07 * _chain_count
	_check_haki()
	_chain_count = 0


func _tick_chain(delta: float) -> void:
	if _chain_armed and _has_counter_target():
		_start_parry()                 # 받아칠 대상이 있을 때만 부르므로 헛반격이 되지 않는다
		return
	if _chain_t > 0.0:
		_chain_t = maxf(_chain_t - delta, 0.0)
		if _chain_t == 0.0:
			_chain_armed = false       # 끝까지 받아칠 게 없었다 — 페널티 없이 조용히 끝


## 지금 반격 키를 받아 줄 수 있는 상태인가 (피격·궁극기·이미 반격 중·죽음이면 아니다).
func _can_take_counter_press() -> bool:
	return _parry_cd <= 0.0 and action not in [Action.PARRY, Action.HURT, Action.ULTIMATE, Action.DEAD]


func _has_counter_target() -> bool:
	return not _glinting_attackers().is_empty() or not _open_counter_threats().is_empty()


func _cancel_chain() -> void:
	_chain_t = 0.0
	_chain_armed = false
	_chain_count = 0


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
	sfx_parry.pitch_scale *= 1.0 + 0.07 * _chain_count   # 연쇄할수록 반격음이 높아진다
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


## 궁극기 — 월아 참격: 검을 크게 치켜들었다가(무적) 내려 베며 거대한 반달 참격(MoonSlash)을 날린다.
## 공중에서 쓰면 발사할 때까지 떠 있다. 참격 자체(가속·깨짐·회오리·폭발·띄우기)는 MoonSlash가 처리한다.
func _start_ultimate() -> void:
	action = Action.ULTIMATE
	_action_time = 0.0
	_hitbox_live = false                 # 이 궁극기에서는 "발사했는가"로 쓴다
	ult_charge = 0.0
	ultimate_changed.emit(ult_charge, ultimate_max)
	ultimate_ready_changed.emit(false)
	hurtbox.invincible = true
	var dir := _move_input()
	if absf(dir) > 0.01:
		facing = signf(dir)
	velocity = Vector2.ZERO
	_squash = Vector2(0.75, 1.35)
	GameFeel.hit_stop(0.08)
	GameFeel.shake(0.3)
	_sfx(sfx_ult_cast, 0.0)
	_set_flash(Color(0.85, 0.65, 1.0), 0.8)
	visual.play(&"ult_cast")
	_spawn_parry_spark(global_position + Vector2(facing * 10.0, -40.0), 0.8)


func _process_ultimate(delta: float) -> void:
	_action_time += delta
	velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
	if not _hitbox_live:
		velocity.y = 0.0                 # 발사할 때까지 공중에서도 떠 있다
		if _action_time >= ult_windup:
			_fire_moon_slash()
	else:
		_apply_gravity(delta)
	if _action_time >= ult_time:
		hurtbox.invincible = false
		action = Action.NONE
		visual.play(&"locomotion")


func _fire_moon_slash() -> void:
	_hitbox_live = true
	velocity.x = -facing * 140.0         # 내려 베는 반동
	_squash = Vector2(1.35, 0.75)
	GameFeel.shake(0.55)
	_sfx(sfx_ult_hit, 0.0)
	_spawn_slash(0.0, 2.2)
	if moon_slash_scene == null:
		return
	var m := moon_slash_scene.instantiate() as MoonSlash
	m.source = self
	m.direction = facing
	_fx_parent().add_child(m)
	m.global_position = global_position + Vector2(facing * 20.0, -8.0)


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
	dash_slash.set_active(false)
	_cancel_chain()
	_dash_slash_queued = false
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
	dash_slash.set_active(false)
	_cancel_chain()
	_dash_slash_queued = false
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
