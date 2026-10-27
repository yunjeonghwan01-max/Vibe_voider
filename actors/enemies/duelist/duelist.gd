class_name Duelist
extends Enemy

## 진짜 '상대'(망토 검사). 간격을 재고, 칼을 치켜든 뒤 반짝이고(=반격 가능), 최대 3연격을 섞는다.
## 공격 동작 중에는 슈퍼아머라 맞아도 멈추지 않는다 → 마구 때리기보다 반짝임을 읽고 반격해야 한다.
## 반격당하면 큰 빈틈을 보이며, 맞은 뒤엔 다시 간격을 잡거나 곧바로 되받아친다.

enum Phase { SPACING, APPROACH, WINDUP, GLINT, STRIKE, RECOVER, DASH_IN }

## Body 시트 프레임 (toolkit/asset_gen/sprite_gen.gd의 _gen_duelist 순서)
enum Frame { IDLE_A, IDLE_B, WALK1, WALK2, WALK3, WALK4, WINDUP, STRIKE, STAGGER }

## 프레임별 손(칼 회전축) 위치 — 시트 그림의 자세(웅크림/기울임)에 맞춘 값.
const HAND := [
	Vector2(12, -14), Vector2(12, -13), Vector2(12, -16), Vector2(12, -14), Vector2(12, -16),
	Vector2(12, -14), Vector2(10, -8), Vector2(15, -10), Vector2(9, -12),
]
const BLADE_REACH := 56.0
const RAISED_DEG := -140.0
const STRIKE_END_DEG := 72.0

@export var strike_range: float = 100.0
@export var engage_range: float = 260.0
@export var preferred_near: float = 90.0
@export var preferred_far: float = 170.0
@export var approach_accel: float = 1200.0
@export var dash_in_speed: float = 480.0
@export var strike_lunge: float = 300.0
@export var windup_time: float = 0.2          # 칼을 치켜드는 예비 동작 (이후 반짝임 0.4초)
@export var windup2_time: float = 0.1         # 연격의 예비 동작은 더 짧다
@export var strike_time: float = 0.12
@export var recover_time: float = 0.3
@export var attack_damage: int = 18
@export var attack_knockback: float = 300.0
@export var combo_chance: float = 0.6         # 연격 확률 (한 단계씩 굴린다)
@export var max_combo: int = 2                # 첫 타 뒤 최대 추가 타수 → 최대 3연격

@export_group("Scenes")
@export var slash_scene: PackedScene

@onready var _atk_shape_pos: Vector2 = attack_hitbox.position if attack_hitbox else Vector2.ZERO
@onready var blade: Sprite2D = $Visual/Blade
@onready var sfx_swing: AudioStreamPlayer2D = $Audio/Swing

var _phase: int = Phase.SPACING
var _phase_timer: float = 0.0
var _think: float = 0.4
var _combo_left: int = 0
var _blade_deg: float = 35.0


func _on_ready() -> void:
	_enter_spacing(randf_range(0.4, 0.8))


func _enemy_ai(delta: float) -> void:
	var dist := distance_to_target()

	match _phase:
		Phase.SPACING:
			facing = dir_to_target()
			_do_spacing(delta, dist)
			_think -= delta
			if _think <= 0.0:
				_decide(dist)
		Phase.APPROACH:
			facing = dir_to_target()
			if is_on_floor():
				velocity.x = move_toward(velocity.x, facing * move_speed, approach_accel * delta)
			_phase_timer -= delta
			if dist <= strike_range:
				_begin_windup(windup_time)
			elif _phase_timer <= 0.0:
				_enter_spacing(randf_range(0.15, 0.3))
		Phase.DASH_IN:
			if is_on_floor():
				velocity.x = facing * dash_in_speed
			_phase_timer -= delta
			if dist <= strike_range or _phase_timer <= 0.0:
				_begin_windup(windup2_time)
		Phase.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * 1.5 * delta)
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_phase = Phase.GLINT
				_phase_timer = glint_duration
				begin_glint(HAND[Frame.WINDUP] + Vector2.from_angle(deg_to_rad(RAISED_DEG)) * BLADE_REACH)
		Phase.GLINT:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * 1.5 * delta)
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_strike()
		Phase.STRIKE:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_recover()
		Phase.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * delta)
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				attack_hitbox.monitoring = false
				if _combo_left > 0 and distance_to_target() <= strike_range * 1.3:
					_combo_left -= 1
					_begin_windup(windup2_time)
				else:
					_enter_spacing(randf_range(0.25, 0.55))


func _do_spacing(delta: float, dist: float) -> void:
	if not is_on_floor():
		return
	# 선호 간격 유지: 너무 가까우면 물러나고, 너무 멀면 다가온다.
	if dist < preferred_near:
		velocity.x = move_toward(velocity.x, -dir_to_target() * move_speed * 0.9, approach_accel * delta)
	elif dist > preferred_far:
		velocity.x = move_toward(velocity.x, dir_to_target() * move_speed * 0.8, approach_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, approach_accel * delta)


func _decide(dist: float) -> void:
	if dist <= strike_range:
		_roll_combo()
		_begin_windup(windup_time)
	elif dist <= engage_range:
		if randf() < 0.5:
			_roll_combo()
			_phase = Phase.DASH_IN
			_phase_timer = 0.5
			facing = dir_to_target()
		else:
			_phase = Phase.APPROACH
			_phase_timer = 0.6
	else:
		_phase = Phase.APPROACH
		_phase_timer = 0.8


func _roll_combo() -> void:
	_combo_left = 0
	while _combo_left < max_combo and randf() < combo_chance:
		_combo_left += 1


func _enter_spacing(think: float) -> void:
	_phase = Phase.SPACING
	_think = think


func _begin_windup(wtime: float) -> void:
	_phase = Phase.WINDUP
	_phase_timer = wtime
	facing = dir_to_target()
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
	visual.scale = Vector2(0.85 * signf(facing), 1.18)    # 칼을 치켜드는 포즈


func _begin_strike() -> void:
	end_glint()
	_phase = Phase.STRIKE
	_phase_timer = strike_time
	visual.scale = Vector2(1.3 * signf(facing), 0.85)
	if is_on_floor():
		velocity.x = facing * strike_lunge
	attack_hitbox.reset_hits()
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = attack_knockback
	attack_hitbox.knockback_direction = Vector2(facing, -0.25).normalized()
	attack_hitbox.monitoring = true
	_sfx(sfx_swing, 0.08)
	_spawn_slash()


func _begin_recover() -> void:
	_phase = Phase.RECOVER
	_phase_timer = recover_time
	attack_hitbox.monitoring = false


func _has_armor() -> bool:
	return _phase == Phase.WINDUP or _phase == Phase.GLINT or _phase == Phase.STRIKE


func _on_hurt(_source: Node) -> void:
	# 빈틈에 맞았다 — 곧바로 판단해 물러나거나 되받아친다.
	_combo_left = 0
	_enter_spacing(randf_range(0.05, 0.25))


func _on_parried_react(_from_pos: Vector2) -> void:
	_combo_left = 0
	_phase = Phase.RECOVER
	_phase_timer = recover_time


func _on_stagger_end() -> void:
	_enter_spacing(randf_range(0.2, 0.45))


# ─────────────────────────── 외형 ───────────────────────────
func _animate(delta: float) -> void:
	var frame_i: int = Frame.IDLE_A
	var target := 35.0
	var snap := false
	match state:
		State.HITSTUN, State.CARRIED:
			frame_i = Frame.STAGGER
			target = 70.0
		State.STAGGER:
			frame_i = Frame.STAGGER
			target = 115.0
		State.SPAWNING:
			frame_i = Frame.IDLE_A
		_:
			match _phase:
				Phase.WINDUP:
					frame_i = Frame.WINDUP
					target = RAISED_DEG
				Phase.GLINT:
					frame_i = Frame.WINDUP
					target = RAISED_DEG
					snap = true
				Phase.STRIKE:
					frame_i = Frame.STRIKE
					var u := 1.0 - clampf(_phase_timer / strike_time, 0.0, 1.0)
					target = lerpf(RAISED_DEG, STRIKE_END_DEG, 1.0 - pow(1.0 - u, 3.0))
					snap = true
				Phase.RECOVER:
					frame_i = Frame.STRIKE if _phase_timer > recover_time * 0.5 else Frame.IDLE_A
					target = 55.0
				Phase.DASH_IN:
					frame_i = Frame.WALK1 + int(_anim_t * 14.0) % 4
					target = 165.0
				_:
					if absf(velocity.x) > 20.0 and is_on_floor():
						frame_i = Frame.WALK1 + int(_anim_t * 8.0) % 4
					else:
						frame_i = Frame.IDLE_A + int(_anim_t * 2.0) % 2
					target = 35.0 + 4.0 * sin(_anim_t * 2.0)
	body.frame = frame_i
	if snap:
		_blade_deg = target
	else:
		_blade_deg = lerpf(_blade_deg, target, 1.0 - exp(-14.0 * delta))
	blade.position = HAND[frame_i]
	blade.rotation_degrees = _blade_deg


func _spawn_slash() -> void:
	if slash_scene == null:
		return
	var s := slash_scene.instantiate() as SlashEffect
	s.color = Color(1.0, 0.4, 0.4, 0.9)
	s.core_color = Color(1.0, 0.92, 0.88, 1.0)
	_fx_parent().add_child(s)
	s.global_position = global_position + Vector2(signf(facing) * 34.0, -18.0)
	s.setup(facing, 15.0, 1.25)
