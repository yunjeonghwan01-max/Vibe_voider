class_name Infantry
extends Enemy

## 제3부대 보병 — 제3왕자를 따라 숲을 순찰하는 평범한 보병 (Phase1 필드몹, 그룹 field_mob).
## 질보다 양: 한 번에 2~6명이 뚜벅뚜벅 걸어와, 사정거리에서 느리고 판정이 넉넉한 근접 카유공(MCI) 하나만 쓴다.
##   예고(양손검을 머리 위로 치켜듦 + 쇳소리, 반격 불가) → FLASH(glint_duration, 이때만 반격 가능)
##   → 내려베기(판정 strike_time) → 긴 후딜 → 다시 행군.
## 반격당하면 기존 일반 MCI 규칙 그대로 (Enemy.on_parried → 기절). 맞으면 하던 공격이 끊긴다.
## 가독성 조정(패턴 아님): 보병끼리 공격 시작 사이에 최소 간격(crowd_attack_gap)을 두어 FLASH가 완전히 겹치지 않게 하고,
## 같은 쪽에서 앞 동료와 ally_spacing 이내로 붙지 않아 한 줄로 늘어선다 (바디끼리는 충돌하지 않는 레이어 구성이라 대신 걸음으로 지킨다).

enum Atk { MARCH, RAISE, FLASH, STRIKE, RECOVER }

## Body 시트 프레임 (toolkit/asset_gen/sprite_gen.gd의 _gen_infantry 순서)
enum Frame { IDLE_A, IDLE_B, WALK1, WALK2, WALK3, WALK4, RAISE, STRIKE, HURT }

## 프레임별 손(검 회전축) 위치 — 시트 그림의 손 위치를 로컬 좌표로 옮긴 값 (오른쪽을 볼 때).
const HAND := [
	Vector2(12, -6), Vector2(12, -6), Vector2(12, -8), Vector2(12, -6), Vector2(12, -8),
	Vector2(12, -6), Vector2(4, -62), Vector2(20, -4), Vector2(6, -2),
]
const BLADE_REACH := 70.0
const CARRY_DEG := -58.0        # 행군: 검을 앞으로 비스듬히 세워 든다
const RAISED_DEG := -118.0      # 치켜듦: 칼끝이 머리 위 뒤쪽
const STRIKE_END_DEG := 38.0    # 내려벤 끝: 칼끝이 앞쪽 땅 근처

@export var attack_range: float = 100.0       # 이 가로 거리 안이면 공격을 시작한다
@export var attack_height: float = 90.0       # 플레이어와의 세로 차이가 이보다 크면 공격하지 않는다 (머리 위 점프 등)
@export var stop_distance: float = 58.0       # 플레이어 앞 이 거리에서 멈춰 선다
@export var ally_spacing: float = 36.0        # 같은 쪽 앞 동료와 이만큼은 떨어져 걷는다
@export var approach_accel: float = 900.0
@export var turn_delay: float = 0.22          # 플레이어가 반대편으로 넘어가면 이만큼 늦게 돌아선다 (묵직함)
@export var raise_time: float = 0.55          # 검을 치켜드는 예고 (이 동안은 반격해도 헛반격)
@export var strike_time: float = 0.13         # 내려베기 판정 시간
@export var strike_step: float = 140.0        # 내려벨 때 앞으로 내딛는 속도
@export var recover_time: float = 0.8         # 내려벤 뒤 후딜
@export var attack_cooldown: float = 1.6      # 후딜이 끝난 뒤 다음 공격까지 (개체마다 ±25% 흔든다)
@export var crowd_attack_gap: float = 0.35    # 다른 보병이 검을 치켜든 지 이 시간이 안 됐으면 기다린다
@export var attack_damage: int = 15
@export var attack_knockback: float = 260.0

@export_group("Scenes")
@export var slash_scene: PackedScene

@onready var _atk_shape_pos: Vector2 = attack_hitbox.position
@onready var blade: Sprite2D = $Visual/Blade
@onready var sfx_raise: AudioStreamPlayer2D = $Audio/Raise
@onready var sfx_swing: AudioStreamPlayer2D = $Audio/Swing
@onready var sfx_step: AudioStreamPlayer2D = $Audio/Step

var _atk: int = Atk.MARCH
var _atk_timer: float = 0.0
var _atk_elapsed: float = 0.0   # 이번 공격(치켜듦)을 시작한 뒤 흐른 시간 — 다른 보병이 간격을 재는 데 쓴다
var _cd: float = 0.0
var _turn_t: float = 0.0
var _crowd_offset: float = 0.0
var _blade_deg: float = CARRY_DEG
var _last_frame: int = -1


func _on_ready() -> void:
	_crowd_offset = randf_range(-8.0, 8.0)
	_cd = randf_range(0.3, 1.2)       # 첫 공격 시점을 흩뜨린다


func _enemy_ai(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_atk_elapsed += delta
	match _atk:
		Atk.MARCH:
			_march(delta)
		Atk.RAISE:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * 2.0 * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_atk = Atk.FLASH
				_atk_timer = glint_duration
				begin_glint(HAND[Frame.RAISE] + Vector2.from_angle(deg_to_rad(RAISED_DEG)) * BLADE_REACH)
		Atk.FLASH:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * 2.0 * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_begin_strike()
		Atk.STRIKE:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, approach_accel * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_begin_recover()
		Atk.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * 2.0 * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_atk = Atk.MARCH
				_cd = attack_cooldown * randf_range(0.75, 1.25)


func _march(delta: float) -> void:
	var t := get_target()
	if t == null:
		velocity.x = move_toward(velocity.x, 0.0, approach_accel * delta)
		return
	# 방향 전환은 turn_delay만큼 늦게 — 플레이어가 등 뒤로 넘어가면 잠깐 빈틈이 생긴다.
	var want_dir := dir_to_target()
	if want_dir != facing:
		_turn_t += delta
		if _turn_t >= turn_delay:
			facing = want_dir
			_turn_t = 0.0
	else:
		_turn_t = 0.0
	var dx := t.global_position.x - global_position.x
	var gap := absf(dx) - stop_distance - _crowd_offset
	var speed := move_speed if gap > 0.0 and signf(dx) == facing and not _ally_ahead() else 0.0
	if is_on_floor():
		velocity.x = move_toward(velocity.x, facing * speed, approach_accel * delta)
	if is_on_floor() and _cd <= 0.0 and signf(dx) == facing and absf(dx) <= attack_range \
			and absf(t.global_position.y - global_position.y) <= attack_height and _crowd_allows_attack():
		_begin_raise()


## 같은 쪽에서 플레이어 쪽으로 바로 앞에 선 동료가 있는가 (그 뒤에 줄을 선다).
func _ally_ahead() -> bool:
	for n in get_tree().get_nodes_in_group("field_mob"):
		var other := n as Infantry
		if other == null or other == self or other.state == State.DEAD:
			continue
		var ahead := (other.global_position.x - global_position.x) * facing
		if ahead > 0.0 and ahead < ally_spacing and absf(other.global_position.y - global_position.y) < 40.0:
			return true
	return false


## 다른 보병이 방금 검을 치켜들었으면 기다린다 — 여럿의 FLASH가 완전히 겹치지 않게 하는 가독성 조정.
func _crowd_allows_attack() -> bool:
	for n in get_tree().get_nodes_in_group("field_mob"):
		var other := n as Infantry
		if other == null or other == self or other.state != State.ACTIVE:
			continue
		if (other._atk == Atk.RAISE or other._atk == Atk.FLASH) and other._atk_elapsed < crowd_attack_gap:
			return false
	return true


func _begin_raise() -> void:
	_atk = Atk.RAISE
	_atk_timer = raise_time
	_atk_elapsed = 0.0
	_turn_t = 0.0
	# 방향은 여기서 고정된다 — 치켜든 뒤에 등 뒤로 돌아가면 헛친다.
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
	visual.scale = Vector2(0.88 * signf(facing), 1.15)
	_sfx(sfx_raise, 0.06)


func _begin_strike() -> void:
	end_glint()
	_atk = Atk.STRIKE
	_atk_timer = strike_time
	visual.scale = Vector2(1.25 * signf(facing), 0.86)
	if is_on_floor():
		velocity.x = facing * strike_step
	attack_hitbox.reset_hits()
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = attack_knockback
	attack_hitbox.knockback_direction = Vector2(facing, -0.3).normalized()
	attack_hitbox.monitoring = true
	_sfx(sfx_swing, 0.08)
	_spawn_slash()


func _begin_recover() -> void:
	_atk = Atk.RECOVER
	_atk_timer = recover_time
	attack_hitbox.monitoring = false


func _on_hurt(_source: Node) -> void:
	# 일반 필드몹: 맞으면 하던 공격이 끊기고 잠깐 뒤에 다시 다가온다.
	if _atk != Atk.MARCH:
		_atk = Atk.RECOVER
		_atk_timer = recover_time * 0.4
	_cd = maxf(_cd, attack_cooldown * 0.4)


func _on_parried_react(_from_pos: Vector2) -> void:
	_atk = Atk.RECOVER
	_atk_timer = 0.0
	_cd = attack_cooldown            # 기절이 풀리자마자 다시 내려치지 않는다


func _on_stagger_end() -> void:
	_atk = Atk.MARCH
	_cd = maxf(_cd, attack_cooldown * 0.5)


# ─────────────────────────── 외형 ───────────────────────────
func _animate(delta: float) -> void:
	var frame_i: int = Frame.IDLE_A
	var target := CARRY_DEG
	var snap := false
	match state:
		State.HITSTUN, State.CARRIED:
			frame_i = Frame.HURT
			target = 70.0
		State.STAGGER:
			frame_i = Frame.HURT
			target = 105.0             # 검이 축 늘어진다 — "지금 때려"
		State.SPAWNING:
			frame_i = Frame.IDLE_A
		_:
			match _atk:
				Atk.RAISE:
					frame_i = Frame.RAISE
					var u := 1.0 - clampf(_atk_timer / raise_time, 0.0, 1.0)
					target = lerpf(CARRY_DEG, RAISED_DEG, 1.0 - pow(1.0 - u, 2.0))
					snap = true
				Atk.FLASH:
					frame_i = Frame.RAISE
					target = RAISED_DEG
					snap = true
				Atk.STRIKE:
					frame_i = Frame.STRIKE
					var u := 1.0 - clampf(_atk_timer / strike_time, 0.0, 1.0)
					target = lerpf(RAISED_DEG, STRIKE_END_DEG, 1.0 - pow(1.0 - u, 3.0))   # 머리 위 → 앞 → 아래
					snap = true
				Atk.RECOVER:
					frame_i = Frame.STRIKE if _atk_timer > recover_time * 0.35 else Frame.IDLE_A
					target = STRIKE_END_DEG if _atk_timer > recover_time * 0.35 else CARRY_DEG
				_:
					if absf(velocity.x) > 15.0 and is_on_floor():
						frame_i = Frame.WALK1 + int(_anim_t * 6.0) % 4    # 뚜벅뚜벅 — 느린 걸음
					else:
						frame_i = Frame.IDLE_A + int(_anim_t * 2.0) % 2
					target = CARRY_DEG + 3.0 * sin(_anim_t * 2.0)
	body.frame = frame_i
	if (frame_i == Frame.WALK1 or frame_i == Frame.WALK3) and frame_i != _last_frame:
		_sfx(sfx_step, 0.1)
	_last_frame = frame_i
	if snap:
		_blade_deg = target
	else:
		_blade_deg = lerpf(_blade_deg, target, 1.0 - exp(-12.0 * delta))
	blade.position = HAND[frame_i]
	blade.rotation_degrees = _blade_deg


func _spawn_slash() -> void:
	if slash_scene == null:
		return
	var s := slash_scene.instantiate() as SlashEffect
	s.color = Color(0.5, 0.95, 0.62, 0.85)          # 초록빛 궤적 — 다른 적의 붉은/보라 궤적과 구분
	s.core_color = Color(0.92, 1.0, 0.94, 1.0)
	_fx_parent().add_child(s)
	s.global_position = global_position + Vector2(signf(facing) * 26.0, -46.0)
	s.setup(facing, 20.0, 1.2)
