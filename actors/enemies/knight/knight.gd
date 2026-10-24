class_name Knight
extends Enemy

## 보스 — 월식의 기사. 플레이어의 약 3배 크기의 갑옷 기사. 등장은 하늘에서 "쿵" 떨어지며(SPAWNING) 땅을 깨뜨린다.
##
## 패턴 4가지:
##   1. 돌격 베기 (MELEE)  — 플레이어가 어디 있든(공중 포함) 바로 앞까지 순식간에 미끄러져 와서, 대검을 치켜들고
##      0.4초 반짝인 뒤 내려 벤다. 반짝일 때 반격 가능(듀얼리스트와 같은 문법). 가끔 2연격.
##   2. 카유공 검기 (RANGED) — 공중으로 떠올라 한 손을 치켜들고 2초 충전(금빛 입자가 손으로 모임) → 0.4초 + 섬광.
##      그때 반격 키 = 방향 무관 반격 성공(X자 결정타로 큰 피해 + 추락·경직). 못 받아치면 거의 즉시
##      플레이어 몸에 붉은 X자가 새겨지는 강한 확정 피해(대시 무적도 뚫는다).
##   3. 반격 자세 (GUARD, 쿨타임 6초) — 0.4초 동안 은빛 초승달 방패 자세. 그동안 플레이어 공격이 닿으면
##      막아내고 → 역반격 창(BAIT): 세상이 거의 멈추고(실제 0.5초) 화면이 어두워지며 부딪힌 자리에 금·은빛 X자
##      문장(KnightCross)이 새겨진다. 그 사이 반격 키 = 방향 무관 역반격(X자 결정타 + 긴 경직).
##      놓치면 플레이어 머리 위로 순간이동 → 잠깐 멈췄다가(붉은 경고 기둥) 내려찍기. 내려찍기는 반격 불가 — 피해야 한다.
##   4. 돌진 (RUSH, 쿨타임 12초) — 바닥 끝으로 미끄러져 물러난 뒤 웅크려 힘을 모으고(붉은 경로선),
##      가속하며 바닥 전체를 돌진한다. 플레이어와 아주 가까워지는 순간만 아주 짧게(0.15초) 반짝인다 —
##      그때 반격하면 긴 스턴. 반대쪽 벽에 부딪히면 벽이 깨진다.
## 3·4가 쿨타임이면 1·2를 2:1 비율로 쓴다(섞인 주머니에서 뽑는다).
##
## 데미지는 Hitbox/Hurtbox 파이프라인으로만 준다. 카유공 실패의 X자는 공용 XSlash(combat/attacks/x_slash)가 준다.
## 날아다니거나 순간이동할 때는 _float(중력 끔)과 collision_mask 0(발판에 걸리지 않게)을 쓰고,
## 다시 떨어질 때 world 충돌을 켠다. 방의 바닥 높이·좌우 끝은 레벨이 스폰 때 넣어 준다.

signal landed                      ## 등장 낙하가 땅에 닿은 순간 (레벨이 발판 균열·음악·HUD를 맞춘다)

enum Atk {
	IDLE, DASH_IN, WINDUP, GLINT, STRIKE, RECOVER,
	RISE, CHARGE, WINDOW, DESCEND,
	GUARD, BAIT, BLINK, HANG, SLAM_FALL, SLAM_RECOVER,
	RETREAT, RUSH_WINDUP, RUSH, CRASH,
	COUNTERED,
}
enum Pick { MELEE, RANGED }

## Body 시트 프레임 (toolkit/asset_gen/sprite_gen.gd의 _gen_knight 순서)
enum Frame { IDLE_A, IDLE_B, WALK1, WALK2, WALK3, WALK4, WINDUP, STRIKE, STAGGER, DASH, CAST, GUARD, SLAM, CROUCH, RUSH, ROAR }

## 프레임별 대검 쥔 손의 아트 좌표 (_gen_knight의 "hand"와 같다)
const HAND_ART := [
	Vector2(49, 54), Vector2(49, 55), Vector2(50, 53), Vector2(49, 54), Vector2(50, 53), Vector2(49, 54),
	Vector2(39, 27), Vector2(58, 57), Vector2(47, 61), Vector2(45, 58), Vector2(50, 57), Vector2(53, 45),
	Vector2(50, 47), Vector2(43, 64), Vector2(45, 61), Vector2(44, 23),
]
const RAISED_HAND_ART := Vector2(30, 7)      # CAST 프레임에서 치켜든 손 (카유공 입자가 모이는 곳)
const ART_ORIGIN := Vector2(36, 93)           # 아트에서 발 중앙
const FOOT := 75.0                            # 루트(몸 중심) → 발바닥
const BLADE_REACH := 130.0
const RAISED_DEG := -140.0
const STRIKE_END_DEG := 75.0
const GUARD_COLOR := Color(0.86, 0.9, 1.0)
const DANGER_COLOR := Color(1.0, 0.25, 0.22)

@export_group("Room")
@export var floor_y: float = 0.0
@export var room_x: Vector2 = Vector2(-760.0, 760.0)    # 몸 중심이 갈 수 있는 좌우 범위
@export var ceiling_y: float = -640.0
@export var target_half_height: float = 27.0             # 플레이어 몸 중심 → 발

@export_group("Melee")
@export var dash_speed: float = 1500.0
@export var dash_max_time: float = 0.6
@export var strike_offset: float = 118.0      # 플레이어 몸 중심에서 이만큼 떨어진 곳까지 다가온다
@export var windup_time: float = 0.28
@export var windup2_time: float = 0.14
@export var strike_time: float = 0.14
@export var recover_time: float = 0.5
@export var melee_damage: int = 22
@export var melee_knockback: float = 460.0
@export var combo_chance: float = 0.45

@export_group("Ranged")
@export var rise_height: float = 320.0
@export var ranged_distance: float = 360.0
@export var rise_time: float = 0.45
@export var charge_time: float = 2.0
@export var window_time: float = 0.4
@export var xmark_damage: int = 34
@export var countered_damage: int = 180       # 카유공을 반격당했을 때 X자 결정타 (최대 체력의 10%)
@export var countered_stun: float = 2.4

@export_group("Counter Stance")
@export var stance_cooldown: float = 6.0
@export var stance_first: float = 5.0
@export var stance_time: float = 0.4
@export var stance_range: float = 340.0
@export var slam_height: float = 290.0
@export var hang_time: float = 0.38
@export var slam_speed: float = 2300.0
@export var slam_damage: int = 26
@export var slam_recover: float = 0.85
@export var shock_width: float = 1100.0       # 착지 충격파의 좌우 전체 폭 (발판을 뚫고 바닥까지 내려와 터진다)
@export var bait_time: float = 0.5            # 역반격 창 (실제 시간 초 — 세상은 bait_time_scale로 느려진다)
@export var bait_time_scale: float = 0.1
@export var bait_counter_damage: int = 160    # 역반격 성공 X자 결정타
@export var bait_stun: float = 2.8

@export_group("Rush")
@export var rush_cooldown: float = 12.0
@export var rush_first: float = 9.0
@export var retreat_speed: float = 1300.0
@export var rush_windup: float = 0.8
@export var rush_start_speed: float = 260.0
@export var rush_accel: float = 2600.0
@export var rush_max_speed: float = 1900.0
@export var rush_damage: int = 26
@export var rush_knockback: float = 620.0
@export var rush_counter_window: float = 0.15
@export var rush_stun: float = 3.6

@export_group("Intro")
@export var intro_roar_time: float = 1.7

@export_group("Scenes")
@export var slash_scene: PackedScene
@export var afterimage_scene: PackedScene
@export var impact_scene: PackedScene
@export var xslash_scene: PackedScene
@export var cross_scene: PackedScene

@onready var sword: Sprite2D = $Visual/Sword
@onready var tell: CounterTell = $Tell
@onready var slam_hitbox: HitboxComponent = $Combat/SlamHitbox
@onready var shock_hitbox: HitboxComponent = $Combat/ShockHitbox
@onready var rush_hitbox: HitboxComponent = $Combat/RushHitbox
@onready var counter_guard: Area2D = $Sensors/CounterGuard
@onready var sfx_swing: AudioStreamPlayer2D = $Audio/Swing
@onready var sfx_step: AudioStreamPlayer2D = $Audio/Step
@onready var sfx_land: AudioStreamPlayer2D = $Audio/Land
@onready var sfx_slam: AudioStreamPlayer2D = $Audio/Slam
@onready var sfx_roar: AudioStreamPlayer2D = $Audio/Roar
@onready var sfx_blink: AudioStreamPlayer2D = $Audio/Blink
@onready var sfx_guard_ring: AudioStreamPlayer2D = $Audio/GuardRing
@onready var sfx_guard_clang: AudioStreamPlayer2D = $Audio/GuardClang
@onready var sfx_rush_charge: AudioStreamPlayer2D = $Audio/RushCharge
@onready var sfx_charge: AudioStreamPlayer2D = $Audio/Charge
@onready var sfx_cue: AudioStreamPlayer2D = $Audio/Cue

var _atk: int = Atk.IDLE
var _t: float = 0.0                 # 현재 단계 남은 시간
var _think: float = 0.6
var _stance_cd: float = 0.0
var _rush_cd: float = 0.0
var _bag: Array[int] = []
var _combo_left: int = 0
var _float: bool = false
var _move_to: Vector2 = Vector2.ZERO
var _rush_speed: float = 0.0
var _rush_window: float = 0.0       # 돌진 반격 창 남은 시간
var _rush_window_used: bool = false
var _sword_deg: float = 62.0
var _step_t: float = 0.0
var _after_t: float = 0.0
var _intro_landed: bool = false
var _roared: bool = false
var _danger: float = 0.0            # _draw 경고 연출 맥동용
var _bait_end_ms: int = 0           # 역반격 창이 닫히는 실제 시각 (세상이 느려지므로 물리 delta로 세지 않는다)
var _cross: KnightCross = null


func _on_ready() -> void:
	add_to_group("counter_threat")
	_stance_cd = stance_first
	_rush_cd = rush_first
	for hb in [slam_hitbox, shock_hitbox, rush_hitbox]:
		hb.source = self
		hb.monitoring = false
	counter_guard.monitoring = false
	health.died.connect(_on_knight_died)
	# 거대한 몸이 잔펀치마다 크게 찌그러지지 않게 기반의 피격 스쿼시를 줄인다 (기반 핸들러 다음에 불린다).
	hurtbox.hit_received.connect(_soften_hit_squash)


# ─────────────────────────── 등장: 하늘에서 쿵 ───────────────────────────
func _begin_spawn() -> void:
	state = State.SPAWNING
	_state_timer = INF                 # 땅에 닿을 때 정한다
	hurtbox.invincible = true
	velocity = Vector2(0.0, 900.0)
	max_fall_speed = 2000.0


func _intro_land() -> void:
	_intro_landed = true
	_state_timer = intro_roar_time
	velocity = Vector2.ZERO
	visual.scale = Vector2(1.35 * signf(facing), 0.7)
	_sfx(sfx_land, 0.0)
	GameFeel.hit_stop(0.12)
	GameFeel.shake(1.0)
	GameFeel.flash(Color(0.55, 0.4, 0.85), 0.35, 0.4)
	_spawn_impact(Vector2(global_position.x, floor_y), 1.0, 30.0)
	_burst(Color(0.7, 0.55, 1.0, 1.0), 26, 140.0, 0.45, true)
	landed.emit()


# ─────────────────────────── 물리 ───────────────────────────
func _apply_gravity(delta: float) -> void:
	if _float and state == State.ACTIVE:
		return
	super._apply_gravity(delta)


func _set_float(on: bool) -> void:
	_float = on
	collision_mask = 0 if on else CollisionLayers.WORLD


func _target_feet_y() -> float:
	var t := get_target()
	return minf(t.global_position.y + target_half_height, floor_y)


func _clamp_x(x: float) -> float:
	return clampf(x, room_x.x, room_x.y)


func _has_armor() -> bool:
	return true                        # 보스는 맞아도 동작이 끊기지 않는다 (반격·카유공·돌진 반격으로만 경직)


func _soften_hit_squash(_d: int, _s: Node, _k: Vector2) -> void:
	if state == State.ACTIVE:
		visual.scale = Vector2(1.07 * signf(facing), 0.95)


# ─────────────────────────── AI ───────────────────────────
func _enemy_ai(delta: float) -> void:
	_stance_cd = maxf(_stance_cd - delta, 0.0)
	_rush_cd = maxf(_rush_cd - delta, 0.0)
	_danger += delta
	var t := get_target()
	if t == null:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
		return
	match _atk:
		Atk.IDLE:
			_do_idle(delta)
		Atk.DASH_IN:
			_do_dash_in(delta)
		Atk.WINDUP:
			_hold(delta)
			_t -= delta
			if _t <= 0.0:
				_atk = Atk.GLINT
				_t = glint_duration
				begin_glint(_hand_local(Frame.WINDUP) + Vector2.from_angle(deg_to_rad(RAISED_DEG)) * BLADE_REACH)
		Atk.GLINT:
			_hold(delta)
			_t -= delta
			if _t <= 0.0:
				_begin_strike()
		Atk.STRIKE:
			velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
			if _float:
				velocity.y = 0.0
			_t -= delta
			if _t <= 0.0:
				attack_hitbox.monitoring = false
				_atk = Atk.RECOVER
				_t = recover_time
		Atk.RECOVER:
			_hold(delta)
			_t -= delta
			if _t <= 0.0:
				if _combo_left > 0 and distance_to_target() <= strike_offset * 1.6:
					_combo_left -= 1
					_begin_windup(windup2_time)
				else:
					_set_float(false)
					_to_idle(0.5)
		Atk.RISE:
			_do_rise(delta)
		Atk.CHARGE:
			_hover_bob(delta)
			_t -= delta
			tell.progress = clampf(1.0 - _t / charge_time, 0.0, 1.0)
			_flash_col = GLINT_COLOR
			_flash_amount = maxf(_flash_amount, tell.progress * 0.45)
			if _t <= 0.0:
				_begin_window()
		Atk.WINDOW:
			_hover_bob(delta)
			tell.aim_point = t.global_position
			_flash_col = GLINT_COLOR
			_flash_amount = 0.75 + 0.25 * sin(_anim_t * 50.0)
			_t -= delta
			if _t <= 0.0:
				_fire_xmark()
		Atk.DESCEND:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_t -= delta
			if is_on_floor() and _t <= 0.0:
				_heavy_land(0.35)
				_to_idle(0.45)
		Atk.GUARD:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			_t -= delta
			if _guard_was_hit():
				_guard_triggered()
			elif _t <= 0.0:
				_end_guard()
				_to_idle(0.3)
		Atk.BAIT:
			velocity = Vector2.ZERO
			_flash_col = Color(1.0, 0.85, 0.45)
			_flash_amount = maxf(_flash_amount, 0.55)
			if Time.get_ticks_msec() >= _bait_end_ms:
				_end_bait()
		Atk.BLINK:
			velocity = Vector2.ZERO
			_t -= delta
			if _t <= 0.0:
				_appear_above_target()
		Atk.HANG:
			velocity = Vector2.ZERO
			_t -= delta
			if _t <= 0.0:
				_begin_slam_fall()
		Atk.SLAM_FALL:
			# 발판에 걸리지 않고 바닥까지 뚫고 내려간다
			velocity = Vector2(0.0, slam_speed)
			if global_position.y + FOOT + slam_speed * delta >= floor_y:
				global_position.y = floor_y - FOOT
				velocity = Vector2.ZERO
				_slam_land()
		Atk.SLAM_RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			_t -= delta
			if _t <= 0.0:
				_to_idle(0.35)
		Atk.RETREAT:
			_do_retreat(delta)
		Atk.RUSH_WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 3000.0 * delta)
			_flash_col = DANGER_COLOR
			_flash_amount = maxf(_flash_amount, 0.25 + 0.25 * (1.0 - _t / rush_windup))
			_t -= delta
			if fmod(_t, 0.12) < delta:
				_scrape_spark()
			if _t <= 0.0:
				_begin_rush()
		Atk.RUSH:
			_do_rush(delta)
		Atk.CRASH:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_t -= delta
			if _t <= 0.0:
				_to_idle(0.4)
		Atk.COUNTERED:
			pass


func _to_idle(think: float) -> void:
	_atk = Atk.IDLE
	_think = think
	_set_float(false)


func _hold(delta: float) -> void:
	facing = dir_to_target() if _atk == Atk.WINDUP else facing
	velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
	if _float:
		velocity.y = 0.0


func _do_idle(delta: float) -> void:
	if not is_on_floor():
		return                           # 떨어지는 중엔 다음 패턴을 고르지 않는다
	facing = dir_to_target()
	var dist := distance_to_target()
	var want := 0.0
	if dist > 280.0:
		want = facing * move_speed
	velocity.x = move_toward(velocity.x, want, 900.0 * delta)
	if absf(velocity.x) > 20.0:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.42
			_sfx(sfx_step, 0.08)
			GameFeel.shake(0.06)
	_think -= delta
	if _think <= 0.0:
		_decide(dist)


## 쿨타임 기술(돌진·반격 자세)이 준비됐으면 먼저 쓰고, 아니면 근접:원거리 = 2:1 주머니에서 뽑는다.
func _decide(dist: float) -> void:
	if _rush_cd <= 0.0:
		_begin_retreat()
		return
	if _stance_cd <= 0.0 and dist <= stance_range:
		_begin_guard()
		return
	if _bag.is_empty():
		_bag = [Pick.MELEE, Pick.MELEE, Pick.RANGED]
		_bag.shuffle()
	if _bag.pop_back() == Pick.MELEE:
		_begin_dash_in()
	else:
		_begin_rise()


# ─────────────────────────── 1. 돌격 베기 ───────────────────────────
func _begin_dash_in() -> void:
	var t := get_target()
	var side := signf(global_position.x - t.global_position.x)
	if side == 0.0:
		side = -facing
	var tx := t.global_position.x + side * strike_offset
	if tx < room_x.x or tx > room_x.y:
		tx = t.global_position.x - side * strike_offset
	_move_to = Vector2(_clamp_x(tx), _target_feet_y() - FOOT)
	_atk = Atk.DASH_IN
	_t = dash_max_time
	_set_float(true)
	_combo_left = 1 if randf() < combo_chance else 0
	facing = signf(_move_to.x - global_position.x) if absf(_move_to.x - global_position.x) > 4.0 else dir_to_target()
	visual.scale = Vector2(1.2 * signf(facing), 0.85)
	_sfx(sfx_blink, 0.1)


func _do_dash_in(delta: float) -> void:
	var to := _move_to - global_position
	_t -= delta
	_trail(0.04)
	if to.length() <= dash_speed * delta * 1.2 or _t <= 0.0:
		global_position = _move_to if to.length() <= dash_speed * delta * 1.2 else global_position
		velocity = Vector2.ZERO
		_begin_windup(windup_time)
		return
	velocity = to.normalized() * dash_speed


func _begin_windup(wtime: float) -> void:
	_atk = Atk.WINDUP
	_t = wtime
	facing = dir_to_target()
	# 서 있는 높이가 땅이 아니면 공중에 떠서 벤다
	_set_float(global_position.y + FOOT < floor_y - 6.0)
	velocity = Vector2.ZERO
	attack_hitbox.position = Vector2(signf(facing) * 108.0, -42.0)
	visual.scale = Vector2(0.88 * signf(facing), 1.15)


func _begin_strike() -> void:
	end_glint()
	_atk = Atk.STRIKE
	_t = strike_time
	visual.scale = Vector2(1.25 * signf(facing), 0.85)
	if not _float:
		velocity.x = facing * 320.0
	attack_hitbox.reset_hits()
	attack_hitbox.position = Vector2(signf(facing) * 108.0, -42.0)
	attack_hitbox.damage = melee_damage
	attack_hitbox.knockback_force = melee_knockback
	attack_hitbox.knockback_direction = Vector2(facing, -0.35).normalized()
	attack_hitbox.monitoring = true
	_sfx(sfx_swing, 0.06)
	GameFeel.shake(0.25)
	_spawn_slash(Vector2(signf(facing) * 70.0, -40.0), 20.0, 2.3)


# ─────────────────────────── 2. 카유공 검기 ───────────────────────────
func _begin_rise() -> void:
	var t := get_target()
	var side := signf(global_position.x - t.global_position.x)
	if side == 0.0:
		side = 1.0
	var tx := t.global_position.x + side * ranged_distance
	if tx < room_x.x or tx > room_x.y:
		tx = t.global_position.x - side * ranged_distance
	_move_to = Vector2(_clamp_x(tx), maxf(floor_y - FOOT - rise_height, ceiling_y + FOOT))
	_atk = Atk.RISE
	_t = rise_time
	_set_float(true)
	visual.scale = Vector2(0.8 * signf(facing), 1.25)
	_sfx(sfx_blink, 0.0)
	_burst(Color(0.6, 0.45, 1.0, 1.0), 12, 70.0, 0.3, false)


func _do_rise(delta: float) -> void:
	facing = dir_to_target()
	_t -= delta
	_trail(0.06)
	var to := _move_to - global_position
	var speed := maxf(to.length() / maxf(_t, 0.05), 300.0)
	if to.length() <= speed * delta or _t <= 0.0:
		global_position = _move_to
		velocity = Vector2.ZERO
		_atk = Atk.CHARGE
		_t = charge_time
		tell.progress = 0.0
		tell.mode = CounterTell.Mode.CHARGE
		_sfx(sfx_charge, 0.0)
		return
	velocity = to.normalized() * speed


func _hover_bob(_delta: float) -> void:
	facing = dir_to_target()
	velocity = Vector2(0.0, sin(_anim_t * 3.0) * 14.0)


func _begin_window() -> void:
	_atk = Atk.WINDOW
	_t = window_time
	tell.mode = CounterTell.Mode.WINDOW
	tell.aim_point = get_target().global_position
	visual.scale = Vector2(1.25 * signf(facing), 1.25)
	_flash_col = Color.WHITE
	_flash_amount = 1.0
	_sfx(sfx_cue, 0.0)
	GameFeel.shake(0.2)


func is_counter_open() -> bool:
	if state != State.ACTIVE:
		return false
	return _atk == Atk.WINDOW or _atk == Atk.BAIT or (_atk == Atk.RUSH and _rush_window > 0.0)


func counter_strike_damage(_default_damage: int) -> int:
	match _atk:
		Atk.WINDOW:
			return countered_damage
		Atk.BAIT:
			return bait_counter_damage
	return 0


## 받아치지 못했다 — 손에서 검기가 번쩍 날아가 플레이어 몸에 붉은 X자를 새긴다 (확정 피격).
func _fire_xmark() -> void:
	tell.mode = CounterTell.Mode.OFF
	var t := get_target()
	var hand := global_position + Vector2(_raised_hand_local().x * signf(facing), _raised_hand_local().y)
	_sfx(sfx_swing, 0.0)
	visual.scale = Vector2(1.2 * signf(facing), 0.85)
	velocity = Vector2(-facing * 120.0, 0.0)
	if xslash_scene != null:
		var x := xslash_scene.instantiate() as XSlash
		x.target = _find_target_hurtbox()
		x.source = self
		x.damage = xmark_damage
		x.from_pos = hand
		x.pierce_invincibility = true
		x.hit_stop_time = 0.1
		x.knockback_x = 320.0
		x.size = 110.0
		x.glow_color = Color(1.0, 0.3, 0.2, 0.55)
		x.body_color = Color(0.35, 0.02, 0.05, 1.0)
		x.edge_color = Color(1.0, 0.75, 0.4, 1.0)
		x.core_color = Color(1.0, 0.97, 0.85, 1.0)
		x.screen_flash = Color(0.85, 0.12, 0.1)
		_fx_parent().add_child(x)
		x.global_position = t.global_position
	_atk = Atk.DESCEND
	_t = 0.25
	_set_float(false)


## 플레이어 몸 중심에 겹친 Hurtbox (방향/거리와 무관한 확정 공격용). 없으면 null — 연출만 나간다.
func _find_target_hurtbox() -> HurtboxComponent:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = get_target().global_position
	q.collision_mask = CollisionLayers.PLAYER_HURTBOX
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_point(q, 4):
		var hb := hit.collider as HurtboxComponent
		if hb != null:
			return hb
	return null


# ─────────────────────────── 3. 반격 자세 → 순간이동 내려찍기 ───────────────────────────
func _begin_guard() -> void:
	_atk = Atk.GUARD
	_t = stance_time
	_stance_cd = stance_cooldown
	facing = dir_to_target()
	hurtbox.invincible = true
	counter_guard.monitoring = true
	visual.scale = Vector2(0.9 * signf(facing), 1.12)
	_sfx(sfx_guard_ring, 0.0)


## 반격 자세 중 플레이어의 "켜져 있는" 공격 판정이 몸에 닿았는가 (평타·장풍·벼락·궁극기 모두).
func _guard_was_hit() -> bool:
	for area in counter_guard.get_overlapping_areas():
		var hb := area as HitboxComponent
		if hb != null and hb.monitoring:
			return true
	return false


func _end_guard() -> void:
	counter_guard.set_deferred("monitoring", false)
	hurtbox.invincible = false


## 막았다 → 역반격 창. 세상이 거의 멈춘 채(실제 bait_time초) X자 문장이 새겨지고, 그 사이에만 받아칠 수 있다.
func _guard_triggered() -> void:
	_end_guard()
	hurtbox.invincible = true              # 창·순간이동 중에는 맞지 않는다 (받아치면 on_countered가, 나타나면 풀린다)
	_sfx(sfx_guard_clang, 0.0)
	_sfx(sfx_cue, 0.0)
	GameFeel.hit_stop(bait_time, bait_time_scale)
	GameFeel.shake(0.45)
	GameFeel.flash(Color(1.0, 0.9, 0.65), 0.35, 0.04)   # 게임 시간 0.04초 = 느려진 세상에선 창 내내 옅어진다
	_flash_col = Color.WHITE
	_flash_amount = 1.0
	var clash := global_position + Vector2(facing * 60.0, -40.0)
	if spark_scene != null:
		var s := spark_scene.instantiate() as SparkEffect
		_fx_parent().add_child(s)
		s.global_position = clash
		s.burst(GUARD_COLOR, 18, 360.0, 0.0, 90.0, 0.3)
		s.with_ring(GUARD_COLOR, 110.0)
	_atk = Atk.BAIT
	velocity = Vector2.ZERO
	_bait_end_ms = Time.get_ticks_msec() + int(bait_time * 1000.0)
	if cross_scene != null:
		_cross = cross_scene.instantiate() as KnightCross
		_cross.window = bait_time
		_fx_parent().add_child(_cross)
		_cross.global_position = clash


## 역반격 창이 닫혔다 (받아치지 못했다) — 원래대로 순간이동 내려찍기.
func _end_bait() -> void:
	_release_cross(false)
	_atk = Atk.BLINK
	_t = 0.16
	_trail(0.0)
	_sfx(sfx_blink, 0.0)
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, 0.08)


func _appear_above_target() -> void:
	var t := get_target()
	var y := maxf(_target_feet_y() - FOOT - slam_height, ceiling_y + FOOT)
	global_position = Vector2(_clamp_x(t.global_position.x), y)
	facing = dir_to_target()
	_set_float(true)
	velocity = Vector2.ZERO
	visual.modulate.a = 1.0
	visual.scale = Vector2(0.8 * signf(facing), 1.3)
	hurtbox.invincible = false
	_atk = Atk.HANG
	_t = hang_time
	_danger = 0.0
	_burst(Color(0.55, 0.3, 1.0, 1.0), 18, 90.0, 0.35, true)
	_sfx(sfx_blink, 0.05)


func _begin_slam_fall() -> void:
	_atk = Atk.SLAM_FALL
	_float = false
	collision_mask = 0
	slam_hitbox.reset_hits()
	slam_hitbox.damage = slam_damage
	slam_hitbox.knockback_force = 420.0
	slam_hitbox.knockback_direction = Vector2(0.0, -1.0)
	slam_hitbox.monitoring = true
	visual.scale = Vector2(0.75 * signf(facing), 1.35)


func _slam_land() -> void:
	slam_hitbox.monitoring = false
	velocity = Vector2.ZERO
	_atk = Atk.SLAM_RECOVER
	_t = slam_recover
	collision_mask = CollisionLayers.WORLD
	# 등장 착지만큼 무거운 연출 — 땅이 갈라지고 화면이 크게 흔들린다
	_heavy_land(1.0)
	GameFeel.hit_stop(0.1)
	GameFeel.flash(Color(0.9, 0.3, 0.3), 0.3, 0.35)
	var ground := Vector2(global_position.x, floor_y)
	_spawn_impact(ground, 1.0, 14.0)
	for side in [-1.0, 1.0]:
		_spawn_impact(ground + Vector2(side * shock_width * 0.3, 0.0), 0.6, 8.0)
	_burst(Color(1.0, 0.4, 0.35, 1.0), 30, 160.0, 0.5, true)
	# 착지 충격파 — 바닥을 따라 넓게
	shock_hitbox.reset_hits()
	shock_hitbox.damage = int(slam_damage * 0.6)
	shock_hitbox.knockback_force = 480.0
	var t := get_target()
	shock_hitbox.knockback_direction = Vector2(signf(t.global_position.x - global_position.x), -0.8).normalized()
	shock_hitbox.monitoring = true
	get_tree().create_timer(0.15, false).timeout.connect(func() -> void:
		if is_instance_valid(shock_hitbox):
			shock_hitbox.monitoring = false)


# ─────────────────────────── 4. 돌진 ───────────────────────────
func _begin_retreat() -> void:
	var t := get_target()
	var side := signf(global_position.x - t.global_position.x)
	if side == 0.0:
		side = 1.0 if global_position.x < 0.0 else -1.0
	_move_to = Vector2(room_x.y if side > 0.0 else room_x.x, global_position.y)
	_atk = Atk.RETREAT
	_rush_cd = rush_cooldown
	_t = 1.2
	facing = -side                     # 플레이어를 바라본 채 뒤로 미끄러진다
	_set_float(false)
	_sfx(sfx_blink, 0.1)


func _do_retreat(delta: float) -> void:
	_t -= delta
	_trail(0.05)
	var dx := _move_to.x - global_position.x
	if absf(dx) <= retreat_speed * delta * 1.2 or _t <= 0.0 or is_on_wall():
		velocity.x = 0.0
		_atk = Atk.RUSH_WINDUP
		_t = rush_windup
		facing = -signf(_move_to.x) if _move_to.x != 0.0 else dir_to_target()
		_danger = 0.0
		visual.scale = Vector2(1.2 * signf(facing), 0.85)
		_sfx(sfx_rush_charge, 0.0)
		_sfx(sfx_step, 0.0)
		return
	velocity.x = signf(dx) * retreat_speed


func _begin_rush() -> void:
	_atk = Atk.RUSH
	_rush_speed = rush_start_speed
	_rush_window = 0.0
	_rush_window_used = false
	rush_hitbox.reset_hits()
	rush_hitbox.position = Vector2(signf(facing) * 34.0, -6.0)
	rush_hitbox.damage = rush_damage
	rush_hitbox.knockback_force = rush_knockback
	rush_hitbox.knockback_direction = Vector2(facing, -0.55).normalized()
	rush_hitbox.monitoring = true
	_sfx(sfx_roar, 0.15)
	GameFeel.shake(0.3)


func _do_rush(delta: float) -> void:
	_rush_speed = minf(_rush_speed + rush_accel * delta, rush_max_speed)
	velocity.x = facing * _rush_speed
	_trail(0.035)
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.11
		_sfx(sfx_step, 0.1)
		GameFeel.shake(0.08)
	# 반격 창: 플레이어가 바로 앞(같은 높이)으로 다가오는 아주 짧은 순간만 반짝인다
	if _rush_window > 0.0:
		_rush_window -= delta
		if _rush_window <= 0.0 or not rush_hitbox.hit_targets.is_empty():
			_rush_window = 0.0
			end_glint()
	elif not _rush_window_used:
		var t := get_target()
		var ahead := (t.global_position.x - global_position.x) * facing
		var dy := absf((t.global_position.y + target_half_height) - (global_position.y + FOOT))
		if ahead > 0.0 and dy < 150.0 and (ahead - 90.0) / _rush_speed <= rush_counter_window:
			_rush_window_used = true
			_rush_window = rush_counter_window
			var keep := glint_duration
			glint_duration = rush_counter_window     # 별빛도 창 길이만큼만 보인다
			begin_glint(Vector2(70.0, -70.0))
			glint_duration = keep
	var edge := room_x.y if facing > 0.0 else room_x.x
	if is_on_wall() or (global_position.x - edge) * facing >= -2.0:
		_rush_crash()


func _rush_crash() -> void:
	rush_hitbox.monitoring = false
	end_glint()
	_rush_window = 0.0
	velocity = Vector2(-facing * 260.0, -260.0)
	_atk = Atk.CRASH
	_t = 1.0
	visual.scale = Vector2(0.7 * signf(facing), 1.3)
	_sfx(sfx_slam, 0.1)
	GameFeel.shake(0.8)
	GameFeel.hit_stop(0.06)
	if impact_scene != null:
		var g := impact_scene.instantiate() as GroundImpact
		_fx_parent().add_child(g)
		g.global_position = Vector2((room_x.y if facing > 0.0 else room_x.x) + facing * 40.0, global_position.y - 20.0)
		g.crack_wall(-facing, 0.8)


func _rush_stunned(from_pos: Vector2) -> void:
	rush_hitbox.monitoring = false
	_rush_window = 0.0
	state = State.STAGGER
	_state_timer = rush_stun
	var away := signf(global_position.x - from_pos.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 420.0, -320.0)
	visual.scale = Vector2(0.7 * signf(facing), 1.3)
	_sfx(sfx_guard_clang, 0.0)
	GameFeel.shake(0.9)


# ─────────────────────────── 반격당함 ───────────────────────────
func _on_parried_react(from_pos: Vector2) -> void:
	_set_float(false)
	_end_all_attacks()
	if _atk == Atk.RUSH:
		_rush_stunned(from_pos)
	else:
		velocity *= 0.5
	_atk = Atk.COUNTERED


## 카유공(+섬광) 또는 돌진 반짝임을 방향 무관 반격으로 받아쳤다.
func on_countered(from_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	var was := _atk
	_release_cross(was == Atk.BAIT)
	_set_float(false)
	_end_all_attacks()
	end_glint()
	_flash_col = Color(0.75, 0.45, 1.0)
	_flash_amount = 1.0
	if was == Atk.RUSH:
		_rush_stunned(from_pos)
	else:
		state = State.STAGGER
		_state_timer = bait_stun if was == Atk.BAIT else countered_stun
		velocity = Vector2.ZERO
		visual.scale = Vector2(1.3 * signf(facing), 0.75)
	_atk = Atk.COUNTERED


## X자 문장을 끝낸다: 받아쳤으면 산산이 부서지고, 아니면 식어서 사라진다.
func _release_cross(shatter: bool) -> void:
	if is_instance_valid(_cross):
		if shatter:
			_cross.shatter()
		else:
			_cross.expire()
	_cross = null


func _end_all_attacks() -> void:
	_release_cross(false)
	tell.mode = CounterTell.Mode.OFF
	sfx_charge.stop()
	sfx_rush_charge.stop()
	attack_hitbox.monitoring = false
	slam_hitbox.monitoring = false
	shock_hitbox.monitoring = false
	rush_hitbox.monitoring = false
	_end_guard()
	visual.modulate.a = 1.0


func _on_stagger_end() -> void:
	_to_idle(0.35)


func _on_knight_died() -> void:
	_end_all_attacks()
	counter_guard.set_deferred("monitorable", false)
	GameFeel.hit_stop(0.35, 0.1)
	GameFeel.flash(Color(0.85, 0.7, 1.0), 0.6, 0.8)
	GameFeel.shake(1.0)
	_spawn_impact(Vector2(global_position.x, floor_y), 0.8, 12.0)


## 쓰러짐: 무릎 꿇듯 주저앉아 깜빡이다가 보랏빛으로 흩어진다.
func _die_dissolve() -> void:
	_set_flash(Color(0.85, 0.7, 1.0), 1.0)
	body.frame = Frame.STAGGER
	var sgn := signf(facing)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector2(1.1 * sgn, 0.8), 0.25).set_trans(Tween.TRANS_BACK)
	for i in 6:
		tw.tween_property(visual, "modulate:a", 0.35, 0.08)
		tw.tween_property(visual, "modulate:a", 1.0, 0.08)
	tw.tween_callback(func() -> void:
		_burst(Color(0.75, 0.5, 1.0, 1.0), 40, 220.0, 0.7, true)
		_burst(Color(1.0, 0.9, 1.0, 1.0), 20, 140.0, 0.4, false))
	tw.set_parallel(true)
	tw.tween_property(visual, "scale", Vector2(1.6 * sgn, 0.1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(visual, "modulate:a", 0.0, 0.5)
	tw.chain().tween_interval(1.6)
	tw.chain().tween_callback(queue_free)


# ─────────────────────────── 연출 ───────────────────────────
func _heavy_land(strength: float) -> void:
	velocity.x = 0.0
	visual.scale = Vector2(1.3 * signf(facing), 0.75)
	_sfx(sfx_slam if strength >= 0.5 else sfx_step, 0.05)
	GameFeel.shake(strength)
	_spawn_impact(Vector2(global_position.x, global_position.y + FOOT), strength, 4.0 + strength * 4.0)


func _spawn_impact(at: Vector2, strength: float, persist: float) -> void:
	if impact_scene == null:
		return
	var g := impact_scene.instantiate() as GroundImpact
	_fx_parent().add_child(g)
	g.global_position = at
	g.crack_ground(strength, persist)


func _scrape_spark() -> void:
	if spark_scene == null:
		return
	var s := spark_scene.instantiate() as SparkEffect
	_fx_parent().add_child(s)
	s.global_position = global_position + Vector2(-facing * 20.0, FOOT - 4.0)
	s.burst(Color(1.0, 0.6, 0.3, 1.0), 5, 50.0, -90.0 - facing * 60.0, 30.0, 0.2)


## 빠르게 움직일 때 몸+대검 잔상을 interval마다 남긴다 (0이면 지금 한 번).
func _trail(interval: float) -> void:
	_after_t -= get_physics_process_delta_time()
	if interval > 0.0 and _after_t > 0.0:
		return
	_after_t = interval
	if afterimage_scene == null:
		return
	for src in [body, sword]:
		var a := afterimage_scene.instantiate() as Afterimage
		_fx_parent().add_child(a)
		a.setup_from_sprite(src, Color(0.55, 0.35, 1.0, 1.0))


func _spawn_slash(offset: Vector2, aim_deg: float, scale_mul: float) -> void:
	if slash_scene == null:
		return
	var s := slash_scene.instantiate() as SlashEffect
	s.color = Color(0.75, 0.45, 1.0, 0.9)
	s.core_color = Color(1.0, 0.95, 1.0, 1.0)
	_fx_parent().add_child(s)
	s.global_position = global_position + offset
	s.setup(facing, aim_deg, scale_mul)


func _art_to_local(p: Vector2) -> Vector2:
	return (p - ART_ORIGIN) * 2.0 + Vector2(0.0, FOOT)


## 오른쪽을 볼 때 기준의 손 위치 (반전은 Visual이 한다)
func _hand_local(frame: int) -> Vector2:
	return _art_to_local(HAND_ART[frame])


func _raised_hand_local() -> Vector2:
	return _art_to_local(RAISED_HAND_ART)


func _animate(delta: float) -> void:
	if state == State.SPAWNING:
		_animate_intro()
		return
	var frame_i: int = Frame.IDLE_A
	var target := 62.0 + 3.0 * sin(_anim_t * 2.0)
	var snap := false
	match state:
		State.HITSTUN, State.STAGGER:
			frame_i = Frame.STAGGER
			target = 115.0
		_:
			match _atk:
				Atk.DASH_IN, Atk.RETREAT:
					frame_i = Frame.DASH
					target = 165.0
				Atk.WINDUP, Atk.GLINT:
					frame_i = Frame.WINDUP
					target = RAISED_DEG
					snap = _atk == Atk.GLINT
				Atk.STRIKE:
					frame_i = Frame.STRIKE
					var u := 1.0 - clampf(_t / strike_time, 0.0, 1.0)
					target = lerpf(RAISED_DEG, STRIKE_END_DEG, 1.0 - pow(1.0 - u, 3.0))
					snap = true
				Atk.RECOVER:
					frame_i = Frame.STRIKE if _t > recover_time * 0.5 else Frame.IDLE_A
					target = 70.0
				Atk.RISE, Atk.CHARGE, Atk.WINDOW:
					frame_i = Frame.CAST
					target = 88.0
				Atk.DESCEND:
					frame_i = Frame.DASH
					target = 100.0
				Atk.GUARD, Atk.BAIT:
					frame_i = Frame.GUARD
					target = -90.0
					snap = true
				Atk.BLINK, Atk.HANG, Atk.SLAM_FALL, Atk.SLAM_RECOVER:
					frame_i = Frame.SLAM
					target = 90.0
					snap = true
				Atk.RUSH_WINDUP:
					frame_i = Frame.CROUCH
					target = 170.0
				Atk.RUSH:
					frame_i = Frame.RUSH
					target = 170.0
				Atk.CRASH:
					frame_i = Frame.STAGGER
					target = 120.0
				_:
					if absf(velocity.x) > 20.0 and is_on_floor():
						frame_i = Frame.WALK1 + int(_anim_t * 6.0) % 4
						target = 58.0
					else:
						frame_i = Frame.IDLE_A + int(_anim_t * 1.6) % 2
	_pose(frame_i, target, snap, delta)
	# 카유공 입자는 치켜든 손에 모인다 (Tell은 반전되지 않으므로 좌우를 값으로 맞춘다)
	var rh := _raised_hand_local()
	tell.position = Vector2(rh.x * signf(facing), rh.y)
	queue_redraw()


func _animate_intro() -> void:
	queue_redraw()
	if not _intro_landed:
		_pose(Frame.SLAM, 90.0, true, 0.0)
		if is_on_floor():
			_intro_land()
		return
	var since := intro_roar_time - _state_timer
	if since >= 0.35 and not _roared:
		_roared = true
		_sfx(sfx_roar, 0.0)
		GameFeel.shake(0.6)
		visual.scale = Vector2(0.9 * signf(facing), 1.15)
		_burst(Color(1.0, 0.35, 0.3, 1.0), 16, 120.0, 0.4, true)
	if since < 0.35:
		_pose(Frame.CROUCH, 170.0, true, 0.0)
	else:
		_pose(Frame.ROAR, -88.0, false, get_physics_process_delta_time())
	if _state_timer <= get_physics_process_delta_time():
		_to_idle(0.8)


func _pose(frame_i: int, deg: float, snap: bool, delta: float) -> void:
	body.frame = frame_i
	if snap or delta <= 0.0:
		_sword_deg = deg
	else:
		_sword_deg = lerpf(_sword_deg, deg, 1.0 - exp(-14.0 * delta))
	sword.position = _hand_local(frame_i)
	sword.rotation_degrees = _sword_deg


## 경고 연출 (루트는 반전되지 않는다): 반격 자세의 은빛 초승달 방패 / 내려찍기 붉은 기둥 / 돌진 경로선.
func _draw() -> void:
	if state == State.SPAWNING and not _intro_landed:
		# 떨어질 자리에 점점 짙어지고 좁아지는 그림자
		var ground := floor_y - global_position.y
		var k := clampf(1.0 - (ground - FOOT) / 1000.0, 0.0, 1.0)
		draw_set_transform(Vector2(0.0, ground), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, lerpf(170.0, 80.0, k), Color(0.02, 0.0, 0.05, 0.15 + 0.4 * k))
		draw_circle(Vector2.ZERO, lerpf(110.0, 50.0, k), Color(0.02, 0.0, 0.05, 0.2 + 0.4 * k))
		draw_set_transform(Vector2.ZERO)
		return
	if state != State.ACTIVE:
		return
	match _atk:
		Atk.GUARD, Atk.BAIT:
			var u := 1.0 if _atk == Atk.BAIT else 1.0 - clampf(_t / stance_time, 0.0, 1.0)
			var pulse := 1.0 if _atk == Atk.BAIT else 0.6 + 0.4 * sin(_anim_t * 40.0)
			var c := Vector2(facing * 30.0, -30.0)
			var a0 := (0.0 if facing > 0.0 else PI) - 1.25
			draw_arc(c, 105.0, a0, a0 + 2.5, 24, Color(GUARD_COLOR.r, GUARD_COLOR.g, GUARD_COLOR.b, 0.25 * pulse), 18.0)
			draw_arc(c, 105.0, a0, a0 + 2.5, 24, Color(1, 1, 1, 0.85 * pulse), 4.0)
			draw_arc(c, 92.0 + 10.0 * u, a0 + 0.3, a0 + 2.2, 20, Color(GUARD_COLOR.r, GUARD_COLOR.g, GUARD_COLOR.b, 0.5), 2.0)
		Atk.HANG:
			var k := clampf(_danger / hang_time, 0.0, 1.0)
			var depth := floor_y - global_position.y
			var pulse := 0.55 + 0.45 * sin(_anim_t * 45.0)
			var w := lerpf(130.0, 70.0, k)
			draw_rect(Rect2(-w * 0.5, FOOT, w, depth - FOOT), Color(DANGER_COLOR.r, DANGER_COLOR.g, DANGER_COLOR.b, 0.12 + 0.12 * pulse))
			draw_line(Vector2(-w * 0.5, depth), Vector2(w * 0.5, depth), Color(1.0, 0.5, 0.4, 0.9 * pulse), 4.0)
			# 충격파가 덮을 바닥 범위
			var sw := shock_width * 0.5
			draw_rect(Rect2(-sw, depth - 60.0, shock_width, 60.0), Color(DANGER_COLOR.r, DANGER_COLOR.g, DANGER_COLOR.b, (0.05 + 0.12 * k) * pulse))
			draw_line(Vector2(-sw, depth), Vector2(sw, depth), Color(1.0, 0.45, 0.35, (0.3 + 0.5 * k) * pulse), 3.0)
		Atk.RUSH_WINDUP:
			var k := clampf(_danger / rush_windup, 0.0, 1.0)
			var edge := (room_x.y if facing > 0.0 else room_x.x) - global_position.x
			var pulse := 0.65 + 0.35 * sin(_anim_t * 30.0)
			var y := FOOT - 30.0
			draw_line(Vector2(facing * 40.0, y), Vector2(edge, y), Color(DANGER_COLOR.r, DANGER_COLOR.g, DANGER_COLOR.b, (0.15 + 0.35 * k) * pulse), 6.0 + 30.0 * k)
			draw_line(Vector2(facing * 40.0, y), Vector2(edge, y), Color(1.0, 0.6, 0.5, 0.6 * k), 2.0)
