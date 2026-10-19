class_name Grunt
extends Enemy

## 잡몹. 플레이어에게 달려와 물어뜯는 돌진을 하고, 한두 대면 죽는다.
## "휩쓸고 지나가는" 쾌감을 위한 적 — 체력 낮고, 공격은 읽기 쉽고, 넉백에 약하다.

enum Atk { APPROACH, WINDUP, LUNGE, RECOVER }

@export var approach_accel: float = 1400.0
@export var attack_range: float = 76.0
@export var attack_cooldown: float = 1.0
@export var windup_time: float = 0.22
@export var lunge_speed: float = 440.0
@export var lunge_time: float = 0.2
@export var recover_time: float = 0.3
@export var attack_damage: int = 8
@export var attack_knockback: float = 220.0

@onready var _atk_shape_pos: Vector2 = attack_hitbox.position if attack_hitbox else Vector2.ZERO

var _atk: int = Atk.APPROACH
var _atk_timer: float = 0.0
var _cd: float = 0.0


func _enemy_ai(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	match _atk:
		Atk.APPROACH:
			facing = dir_to_target()
			if is_on_floor():
				velocity.x = move_toward(velocity.x, facing * move_speed, approach_accel * delta)
			if is_on_floor() and _cd <= 0.0 and distance_to_target() <= attack_range:
				_begin_windup()
		Atk.WINDUP:
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
				_cd = attack_cooldown


func _begin_windup() -> void:
	_atk = Atk.WINDUP
	_atk_timer = windup_time
	facing = dir_to_target()
	_flash(Color(1.6, 1.4, 0.7, 1.0))   # 텔레그래프: 노랗게 번쩍
	visual.scale = Vector2(0.8, 1.25)


func _begin_lunge() -> void:
	_atk = Atk.LUNGE
	_atk_timer = lunge_time
	visual.scale = Vector2(1.3, 0.8)
	attack_hitbox.reset_hits()
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = attack_knockback
	attack_hitbox.knockback_direction = Vector2(facing, -0.3).normalized()
	attack_hitbox.monitoring = true


func _begin_recover() -> void:
	_atk = Atk.RECOVER
	_atk_timer = recover_time
	attack_hitbox.monitoring = false


func _on_parried_react(_from_pos: Vector2) -> void:
	_atk = Atk.RECOVER
	_atk_timer = recover_time
	_cd = attack_cooldown


func _on_stagger_end() -> void:
	_atk = Atk.APPROACH
