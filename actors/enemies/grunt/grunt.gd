class_name Grunt
extends Enemy

## 잡몹(공허 임프). 플레이어에게 달려와 웅크렸다가 반짝인 뒤 물어뜯는 돌진을 한다.
## "휩쓸고 지나가는" 쾌감을 위한 적 — 맞으면 공격이 끊기고 넉백에 약하다. 대신 무리로 몰려와 압박한다.

enum Atk { APPROACH, WINDUP, GLINT, LUNGE, RECOVER }

## Body 시트 프레임 (toolkit/asset_gen/sprite_gen.gd의 _gen_grunt 순서)
enum Frame { IDLE_A, IDLE_B, WALK1, WALK2, WALK3, WALK4, WINDUP, LUNGE, HURT }

const GLINT_POS := Vector2(6.0, -12.0)   # 눈 위치 (오른쪽을 볼 때)

@export var approach_accel: float = 1500.0
@export var attack_range: float = 82.0
@export var attack_cooldown: float = 0.8
@export var windup_time: float = 0.14         # 웅크리는 예비 동작 (이후 반짝임 0.4초)
@export var lunge_speed: float = 480.0
@export var lunge_time: float = 0.2
@export var recover_time: float = 0.32
@export var attack_damage: int = 10
@export var attack_knockback: float = 240.0

@onready var _atk_shape_pos: Vector2 = attack_hitbox.position if attack_hitbox else Vector2.ZERO
@onready var sfx_lunge: AudioStreamPlayer2D = $Audio/Lunge

var _atk: int = Atk.APPROACH
var _atk_timer: float = 0.0
var _cd: float = 0.0
var _crowd_offset: float = 0.0   # 무리가 한 점에 겹치지 않도록 개체마다 다른 간격


func _on_ready() -> void:
	_crowd_offset = randf_range(-26.0, 26.0)
	_cd = randf_range(0.2, 0.8)       # 동시에 덤비지 않게 첫 공격 시점을 흩뜨린다


func _enemy_ai(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	match _atk:
		Atk.APPROACH:
			facing = dir_to_target()
			var t := get_target()
			var gap := 0.0
			if t != null:
				gap = absf(t.global_position.x - global_position.x) - 40.0 - _crowd_offset
			var want := facing * move_speed if gap > 0.0 else 0.0
			if is_on_floor():
				velocity.x = move_toward(velocity.x, want, approach_accel * delta)
			if is_on_floor() and _cd <= 0.0 and distance_to_target() <= attack_range:
				_begin_windup()
		Atk.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_atk = Atk.GLINT
				_atk_timer = glint_duration
				attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
				begin_glint(GLINT_POS)
		Atk.GLINT:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_begin_lunge()
		Atk.LUNGE:
			velocity.x = facing * lunge_speed
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_begin_recover()
		Atk.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * delta)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				attack_hitbox.monitoring = false
				_atk = Atk.APPROACH
				_cd = attack_cooldown * randf_range(0.8, 1.3)


func _begin_windup() -> void:
	_atk = Atk.WINDUP
	_atk_timer = windup_time
	facing = dir_to_target()
	visual.scale = Vector2(1.2 * signf(facing), 0.8)


func _begin_lunge() -> void:
	end_glint()
	_atk = Atk.LUNGE
	_atk_timer = lunge_time
	visual.scale = Vector2(1.35 * signf(facing), 0.78)
	attack_hitbox.reset_hits()
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = attack_knockback
	attack_hitbox.knockback_direction = Vector2(facing, -0.3).normalized()
	attack_hitbox.monitoring = true
	_sfx(sfx_lunge, 0.1)


func _begin_recover() -> void:
	_atk = Atk.RECOVER
	_atk_timer = recover_time
	attack_hitbox.monitoring = false


func _on_hurt(_source: Node) -> void:
	# 잡몹은 맞으면 하던 공격이 끊긴다.
	if _atk != Atk.APPROACH:
		_atk = Atk.RECOVER
		_atk_timer = recover_time * 0.5


func _on_parried_react(_from_pos: Vector2) -> void:
	_atk = Atk.RECOVER
	_atk_timer = recover_time
	_cd = attack_cooldown


func _on_stagger_end() -> void:
	_atk = Atk.APPROACH


func _animate(_delta: float) -> void:
	match state:
		State.HITSTUN, State.STAGGER, State.CARRIED:
			body.frame = Frame.HURT
		State.SPAWNING:
			body.frame = Frame.IDLE_A
		_:
			match _atk:
				Atk.WINDUP, Atk.GLINT:
					body.frame = Frame.WINDUP
				Atk.LUNGE:
					body.frame = Frame.LUNGE
				_:
					if absf(velocity.x) > 20.0 and is_on_floor():
						body.frame = Frame.WALK1 + int(_anim_t * 11.0) % 4
					else:
						body.frame = Frame.IDLE_A + int(_anim_t * 2.5) % 2
