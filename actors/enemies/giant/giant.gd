class_name Giant
extends Enemy

## 제3부대 거병 — 거대한 몸집, 금빛 한손 양날도끼. 느리게 걸어오고, 같은 바닥에서 막힘없이 닿을 수 있을 때만
## 쿨다운마다 플레이어 쪽으로 돌진(이동만, 피해 없음)해 거리를 좁힌다. 공격은 무겁고 큰 근접 카유공(MCI).
##
## 핵심 — 방심을 깨는 2차 MCI (CC 자동연쇄도, Knight CCI 랠리도 아니다):
##   1차 내려찍기(RAISE → FLASH1 → STRIKE1)를 반격당해도 기절하지 않는다 → 앞으로 넘어갈 듯 비틀(STUMBLE)
##   → 반동으로 도끼를 다시 크게 치켜듦(RERAISE, 반격 불가) → 새 FLASH2 → 더 크고 아픈 2차 내려찍기(STRIKE2).
##   1차 성공에서 FLASH2까지 stumble_time + reraise_time(≈0.85초)이 걸려 연쇄 반격 예약 창(0.2초)이 먼저 끝난다
##   → 예약만으로는 자동 성공하지 않고, 플레이어가 새 FLASH를 보고 따로 눌러야 한다.
##   2차까지 받아치면 일반 기절보다 긴 heavy_stagger_time 동안 쓰러진다.
##   1차를 못 받아치면 그냥 맞고(또는 피하고) 공격이 끝난다 — 2차는 1차 반격 성공에서만 나온다.
##   2차를 못 받아치거나 피해도 긴 후딜(recover2_time) 뒤 다시 행군 — 재시작 무한 루프는 없다.
## 이 분기는 거병의 on_parried()만 바꾼다 (다른 적의 반격 규칙은 그대로). 공격 동작 중에는 슈퍼아머(맞아도 안 끊긴다),
## 반동 공격 도중에는 다른 적을 반격한 올려베기에도 휘말리지 않는다.

enum Atk { MARCH, CHARGE_PREP, CHARGE, RAISE, FLASH1, STRIKE1, RECOVER, STUMBLE, RERAISE, FLASH2, STRIKE2 }

## Body 시트 프레임 (toolkit/asset_gen/sprite_gen.gd의 _gen_giant 순서)
enum Frame { IDLE_A, IDLE_B, WALK1, WALK2, WALK3, WALK4, CROUCH, CHARGE, RAISE, CHOP, STUMBLE, HURT }

## 프레임별 손(도끼 회전축) 위치 — 시트 그림의 손 위치를 로컬 좌표로 옮긴 값 (오른쪽을 볼 때).
const HAND := [
	Vector2(18, 2), Vector2(18, 2), Vector2(18, 0), Vector2(18, 2), Vector2(18, 0), Vector2(18, 2),
	Vector2(16, 10), Vector2(24, 2), Vector2(0, -58), Vector2(28, 6), Vector2(32, 18), Vector2(10, 14),
]
const AXE_REACH := 56.0
const CARRY_DEG := 72.0         # 행군: 도끼머리가 앞쪽 아래
const TRAIL_DEG := 160.0        # 돌진: 도끼를 뒤로 끈다
const RAISED_DEG := -118.0      # 치켜듦: 도끼머리가 머리 위 뒤쪽
const CHOP_DEG := 70.0          # 내려찍은 끝
const STUMBLE_DEG := 100.0      # 비틀: 도끼가 앞쪽 땅으로 끌려간다
const SECOND_ATTACK := [Atk.STUMBLE, Atk.RERAISE, Atk.FLASH2, Atk.STRIKE2]

@export_group("Move")
@export var approach_accel: float = 600.0
@export var turn_delay: float = 0.35
@export var stop_distance: float = 100.0
@export var charge_min: float = 260.0         # 이 가로 거리 이상 ~ charge_max 이하일 때 돌진
@export var charge_max: float = 700.0
@export var charge_cooldown: float = 4.0
@export var charge_prep: float = 0.35         # 돌진 전 웅크리는 예고
@export var charge_speed: float = 430.0
@export var same_floor_height: float = 30.0   # 높이 차이가 이보다 크면 다른 층 — 돌진하지 않는다

@export_group("Chop")
@export var attack_range: float = 130.0
@export var attack_height: float = 100.0
@export var attack_cooldown: float = 2.0
@export var crowd_attack_gap: float = 0.35
@export var raise_time: float = 0.8           # 1차: 도끼를 천천히 치켜드는 예고 (반격 불가)
@export var strike_time: float = 0.16
@export var strike_step: float = 120.0
@export var recover_time: float = 1.0
@export var damage1: int = 22
@export var knockback1: float = 320.0

@export_group("Second Chop")
@export var stumble_time: float = 0.45        # 1차 반격당한 뒤 비틀거리는 시간 (기절 아님)
@export var reraise_time: float = 0.4         # 반동으로 다시 치켜드는 예고 (반격 불가)
@export var flash2_time: float = 0.4          # 2차 FLASH — 이때만 반격 성공
@export var strike2_time: float = 0.18
@export var strike2_step: float = 220.0
@export var recover2_time: float = 1.2
@export var damage2: int = 32
@export var knockback2: float = 480.0
@export var hitbox2_scale: Vector2 = Vector2(1.35, 1.15)   # 2차 판정은 더 넓다
@export var heavy_stagger_time: float = 2.6   # 2차까지 받아치면 이만큼 쓰러진다 (일반 기절 parry_stagger_time보다 길게)

@export_group("Scenes")
@export var slash_scene: PackedScene

@onready var _atk_shape_pos: Vector2 = attack_hitbox.position
@onready var _atk_shape: CollisionShape2D = $Combat/AttackHitbox/CollisionShape2D
@onready var axe: Sprite2D = $Visual/Axe
@onready var sfx_raise: AudioStreamPlayer2D = $Audio/Raise
@onready var sfx_reraise: AudioStreamPlayer2D = $Audio/Reraise
@onready var sfx_chop: AudioStreamPlayer2D = $Audio/Chop
@onready var sfx_slam: AudioStreamPlayer2D = $Audio/Slam
@onready var sfx_step: AudioStreamPlayer2D = $Audio/Step

var _atk: int = Atk.MARCH
var _atk_timer: float = 0.0
var _atk_elapsed: float = 0.0
var _cd: float = 0.0
var _charge_cd: float = 0.0
var _turn_t: float = 0.0
var _axe_deg: float = CARRY_DEG
var _last_frame: int = -1


func _on_ready() -> void:
	_cd = randf_range(0.5, 1.2)
	_charge_cd = randf_range(1.0, 2.5)


func _enemy_ai(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_charge_cd = maxf(_charge_cd - delta, 0.0)
	_atk_elapsed += delta
	if _atk != Atk.MARCH and _atk != Atk.CHARGE:
		velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
	_atk_timer -= delta
	match _atk:
		Atk.MARCH:
			_march(delta)
		Atk.CHARGE_PREP:
			if _atk_timer <= 0.0:
				_atk = Atk.CHARGE
				_atk_timer = charge_max / charge_speed + 0.3
				_sfx(sfx_step, 0.05)
		Atk.CHARGE:
			_process_charge()
		Atk.RAISE:
			if _atk_timer <= 0.0:
				_atk = Atk.FLASH1
				_atk_timer = glint_duration
				begin_glint(_raised_tip())
		Atk.FLASH1:
			if _atk_timer <= 0.0:
				_begin_strike(false)
		Atk.STRIKE1, Atk.STRIKE2:
			if _atk_timer <= 0.0:
				var second := _atk == Atk.STRIKE2
				attack_hitbox.monitoring = false
				_atk = Atk.RECOVER
				_atk_timer = recover2_time if second else recover_time
		Atk.RECOVER:
			if _atk_timer <= 0.0:
				_atk = Atk.MARCH
				_atk_shape.scale = Vector2.ONE
				_cd = attack_cooldown * randf_range(0.85, 1.2)
		Atk.STUMBLE:
			if _atk_timer <= 0.0:
				_begin_reraise()
		Atk.RERAISE:
			if _atk_timer <= 0.0:
				_atk = Atk.FLASH2
				_atk_timer = flash2_time
				begin_glint(_raised_tip())
				_burst(Color(1.0, 0.8, 0.35, 1.0), 14, 70.0, 0.3, true)   # 2차는 더 크게 번쩍
		Atk.FLASH2:
			if _atk_timer <= 0.0:
				_begin_strike(true)


# ─────────────────────────── 이동 / 돌진 ───────────────────────────
func _march(delta: float) -> void:
	var t := get_target()
	if t == null:
		velocity.x = move_toward(velocity.x, 0.0, approach_accel * delta)
		return
	var want_dir := dir_to_target()
	if want_dir != facing:
		_turn_t += delta
		if _turn_t >= turn_delay:
			facing = want_dir
			_turn_t = 0.0
	else:
		_turn_t = 0.0
	var dx := t.global_position.x - global_position.x
	var dy := absf(t.global_position.y - global_position.y)
	var gap := absf(dx) - stop_distance
	var speed := move_speed if gap > 0.0 and signf(dx) == facing else 0.0
	if is_on_floor():
		velocity.x = move_toward(velocity.x, facing * speed, approach_accel * delta)
	if not is_on_floor() or signf(dx) != facing:
		return
	if _cd <= 0.0 and absf(dx) <= attack_range and dy <= attack_height and _crowd_allows_attack():
		_begin_raise()
	elif _charge_cd <= 0.0 and dy <= same_floor_height and absf(dx) >= charge_min and absf(dx) <= charge_max \
			and _floor_path_clear(dx):
		_atk = Atk.CHARGE_PREP
		_atk_timer = charge_prep
		_charge_cd = charge_cooldown
		visual.scale = Vector2(1.2 * signf(facing), 0.82)


## 같은 바닥으로 이어져 있는가: 수평선상에 벽이 없고, 가는 길 내내 발밑이 있다.
func _floor_path_clear(dx: float) -> bool:
	var x := global_position.x
	var y := global_position.y
	if not _ray(Vector2(x, y - 20.0), Vector2(x + dx, y - 20.0)).is_empty():
		return false
	var s := 32.0
	while s < absf(dx):
		if _ray(Vector2(x + signf(dx) * s, y - 10.0), Vector2(x + signf(dx) * s, y + 80.0)).is_empty():
			return false
		s += 32.0
	return true


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, CollisionLayers.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q)


func _process_charge() -> void:
	var t := get_target()
	var ahead := Vector2(global_position.x + facing * 40.0, global_position.y)
	var edge := _ray(ahead + Vector2(0.0, -10.0), ahead + Vector2(0.0, 80.0)).is_empty()
	var dx := (t.global_position.x - global_position.x) if t != null else 0.0
	if t == null or edge or is_on_wall() or _atk_timer <= 0.0 or absf(dx) <= stop_distance or signf(dx) != facing:
		velocity.x = facing * 80.0
		_atk = Atk.MARCH
		return
	velocity.x = facing * charge_speed


## 다른 제3부대가 방금 공격을 치켜들었으면 기다린다 — FLASH가 완전히 겹치지 않게 하는 가독성 조정.
func _crowd_allows_attack() -> bool:
	for n in get_tree().get_nodes_in_group("field_mob"):
		var e := n as Enemy
		if e == null or e == self or e.state != State.ACTIVE:
			continue
		var inf := e as Infantry
		if inf != null and (inf._atk == Infantry.Atk.RAISE or inf._atk == Infantry.Atk.FLASH) and inf._atk_elapsed < crowd_attack_gap:
			return false
		var asn := e as Assassin
		if asn != null and (asn._atk == Assassin.Atk.RAISE or asn._atk == Assassin.Atk.FLASH) and asn._atk_elapsed < crowd_attack_gap:
			return false
		var g := e as Giant
		if g != null and (g._atk == Atk.RAISE or g._atk == Atk.FLASH1) and g._atk_elapsed < crowd_attack_gap:
			return false
	return true


# ─────────────────────────── 내려찍기 (MCI 1차 / 2차) ───────────────────────────
func _raised_tip() -> Vector2:
	return HAND[Frame.RAISE] + Vector2.from_angle(deg_to_rad(RAISED_DEG)) * AXE_REACH


func _place_hitbox(second: bool) -> void:
	_atk_shape.scale = hitbox2_scale if second else Vector2.ONE
	var x := absf(_atk_shape_pos.x) * (hitbox2_scale.x if second else 1.0)
	attack_hitbox.position = Vector2(signf(facing) * x, _atk_shape_pos.y)


func _begin_raise() -> void:
	_atk = Atk.RAISE
	_atk_timer = raise_time
	_atk_elapsed = 0.0
	_turn_t = 0.0
	_place_hitbox(false)                     # 방향은 여기서 고정
	visual.scale = Vector2(0.9 * signf(facing), 1.12)
	_sfx(sfx_raise, 0.04)


func _begin_strike(second: bool) -> void:
	end_glint()
	_atk = Atk.STRIKE2 if second else Atk.STRIKE1
	_atk_timer = strike2_time if second else strike_time
	_place_hitbox(second)
	visual.scale = Vector2(1.3 * signf(facing), 0.8)
	if is_on_floor():
		velocity.x = facing * (strike2_step if second else strike_step)
	attack_hitbox.reset_hits()
	attack_hitbox.damage = damage2 if second else damage1
	attack_hitbox.knockback_force = knockback2 if second else knockback1
	attack_hitbox.knockback_direction = Vector2(facing, -0.35).normalized()
	attack_hitbox.monitoring = true
	GameFeel.shake(0.55 if second else 0.3)
	_sfx(sfx_slam if second else sfx_chop, 0.05)
	_spawn_slash(second)
	if second:
		_burst(Color(1.0, 0.75, 0.3, 1.0), 18, 90.0, 0.3, true)


## 1차를 반격당했다 — 기절 대신 앞으로 넘어갈 듯 비틀거린다 (곧 반동 2차가 온다).
func _begin_stumble() -> void:
	end_glint()
	attack_hitbox.monitoring = false
	_atk = Atk.STUMBLE
	_atk_timer = stumble_time
	_flash_col = Color(1, 1, 1)
	_flash_amount = 1.0
	velocity.x = facing * 40.0               # 헛친 힘에 앞으로 쏠린다
	visual.scale = Vector2(1.15 * signf(facing), 0.85)


func _begin_reraise() -> void:
	_atk = Atk.RERAISE
	_atk_timer = reraise_time
	facing = dir_to_target()                 # 중심을 되찾으며 플레이어 쪽으로 다시 겨눈다
	_place_hitbox(true)
	visual.scale = Vector2(0.85 * signf(facing), 1.2)
	_sfx(sfx_reraise, 0.04)


# ─────────────────────────── 반격당함 / 피격 ───────────────────────────
## 거병만의 분기: 1차 FLASH 반격 → 비틀(기절 아님), 2차 FLASH 반격 → 긴 기절.
## 반짝이지 않을 때 불린 것(다른 적을 반격한 올려베기)은 공격 동작 중이면 무시, 아니면 일반 규칙.
func on_parried(from_pos: Vector2) -> void:
	if state == State.DEAD or state == State.STAGGER:
		return                               # 이미 쓰러져 있다 — 반격 직후 올려베기가 긴 기절을 짧게 덮어쓰지 않게
	var countered := _glinting and state == State.ACTIVE
	if countered and _atk == Atk.FLASH1:
		_begin_stumble()
		return
	if countered and _atk == Atk.FLASH2:
		super.on_parried(from_pos)
		_state_timer = heavy_stagger_time
		return
	if _has_armor():
		return
	super.on_parried(from_pos)


func _has_armor() -> bool:
	return _atk in [Atk.RAISE, Atk.FLASH1, Atk.STRIKE1, Atk.STUMBLE, Atk.RERAISE, Atk.FLASH2, Atk.STRIKE2]


func _on_hurt(_source: Node) -> void:
	# 걷기/돌진/후딜 중에 맞으면 잠깐 멈췄다 다시 걷는다 (공격 동작 중엔 슈퍼아머라 여기 오지 않는다).
	_atk = Atk.MARCH
	_atk_shape.scale = Vector2.ONE
	_cd = maxf(_cd, 0.5)


func _on_parried_react(_from_pos: Vector2) -> void:
	_atk = Atk.MARCH
	_atk_shape.scale = Vector2.ONE
	_cd = attack_cooldown


func _on_stagger_end() -> void:
	_atk = Atk.MARCH
	_cd = maxf(_cd, attack_cooldown * 0.5)


# ─────────────────────────── 외형 ───────────────────────────
func _animate(delta: float) -> void:
	var frame_i: int = Frame.IDLE_A
	var target := CARRY_DEG
	var snap := false
	match state:
		State.HITSTUN, State.CARRIED, State.STAGGER:
			frame_i = Frame.HURT
			target = 110.0
		State.SPAWNING:
			frame_i = Frame.IDLE_A
		_:
			match _atk:
				Atk.CHARGE_PREP:
					frame_i = Frame.CROUCH
					target = TRAIL_DEG
				Atk.CHARGE:
					frame_i = Frame.CHARGE
					target = TRAIL_DEG
				Atk.RAISE:
					frame_i = Frame.RAISE
					var u := 1.0 - clampf(_atk_timer / raise_time, 0.0, 1.0)
					target = lerpf(CARRY_DEG, RAISED_DEG, 1.0 - pow(1.0 - u, 2.0))
					snap = true
				Atk.RERAISE:
					frame_i = Frame.RAISE
					var u := 1.0 - clampf(_atk_timer / reraise_time, 0.0, 1.0)
					# 반동: 땅에 끌린 도끼를 뒤로 크게 돌려 올린다 (아래 → 뒤 → 머리 위)
					target = lerpf(STUMBLE_DEG, RAISED_DEG + 360.0, 1.0 - pow(1.0 - u, 2.0))
					snap = true
				Atk.FLASH1, Atk.FLASH2:
					frame_i = Frame.RAISE
					target = RAISED_DEG
					snap = true
				Atk.STRIKE1, Atk.STRIKE2:
					frame_i = Frame.CHOP
					var dur := strike2_time if _atk == Atk.STRIKE2 else strike_time
					var u := 1.0 - clampf(_atk_timer / dur, 0.0, 1.0)
					target = lerpf(RAISED_DEG, CHOP_DEG, 1.0 - pow(1.0 - u, 3.0))
					snap = true
				Atk.STUMBLE:
					frame_i = Frame.STUMBLE
					target = STUMBLE_DEG
				Atk.RECOVER:
					frame_i = Frame.CHOP if _atk_timer > 0.4 else Frame.IDLE_A
					target = CHOP_DEG if _atk_timer > 0.4 else CARRY_DEG
				_:
					if absf(velocity.x) > 15.0 and is_on_floor():
						frame_i = Frame.WALK1 + int(_anim_t * 4.5) % 4     # 쿵, 쿵 — 느린 걸음
					else:
						frame_i = Frame.IDLE_A + int(_anim_t * 1.5) % 2
					target = CARRY_DEG + 3.0 * sin(_anim_t * 1.5)
	body.frame = frame_i
	if (frame_i == Frame.WALK1 or frame_i == Frame.WALK3) and frame_i != _last_frame:
		_sfx(sfx_step, 0.08)
	_last_frame = frame_i
	if snap:
		_axe_deg = target
	else:
		_axe_deg = lerpf(_axe_deg, target, 1.0 - exp(-10.0 * delta))
	axe.position = HAND[frame_i]
	axe.rotation_degrees = _axe_deg


func _spawn_slash(second: bool) -> void:
	if slash_scene == null:
		return
	var s := slash_scene.instantiate() as SlashEffect
	s.color = Color(1.0, 0.8, 0.35, 0.9) if second else Color(0.95, 0.78, 0.4, 0.8)
	s.core_color = Color(1.0, 0.97, 0.85, 1.0)
	_fx_parent().add_child(s)
	s.global_position = global_position + Vector2(signf(facing) * 44.0, -40.0)
	s.setup(facing, 30.0, 2.0 if second else 1.6)
