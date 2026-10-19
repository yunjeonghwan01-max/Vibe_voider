class_name Duelist
extends Enemy

## 진짜 '상대'. 간격을 재고, 공격을 '텔레그래프'하고(=패링 가능), 2연격을 섞고,
## 패링당하면 큰 빈틈을 보이며, 맞은 뒤엔 다시 간격을 잡거나 반격한다.
## 거대한 체력바가 아니라 '검을 겨루는 느낌'을 목표로 한다.

enum Phase { SPACING, APPROACH, WINDUP, STRIKE, RECOVER, DASH_IN }

@export var strike_range: float = 98.0
@export var engage_range: float = 240.0
@export var preferred_near: float = 84.0
@export var preferred_far: float = 160.0
@export var approach_accel: float = 1100.0
@export var dash_in_speed: float = 430.0
@export var strike_lunge: float = 250.0
@export var windup_time: float = 0.36        # 넉넉한 텔레그래프 → 플레이어가 읽고 패링
@export var windup2_time: float = 0.24        # 2타는 더 빠르게
@export var strike_time: float = 0.12
@export var recover_time: float = 0.32
@export var attack_damage: int = 14
@export var attack_knockback: float = 270.0
@export var combo_chance: float = 0.5

@export_group("Scenes")
@export var slash_scene: PackedScene

@onready var _atk_shape_pos: Vector2 = attack_hitbox.position if attack_hitbox else Vector2.ZERO

var _phase: int = Phase.SPACING
var _phase_timer: float = 0.0
var _think: float = 0.4
var _combo_left: int = 0
var _space_dir: float = 0.0


func _on_ready() -> void:
	_enter_spacing(randf_range(0.3, 0.7))


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
				_enter_spacing(randf_range(0.2, 0.4))
		Phase.DASH_IN:
			if is_on_floor():
				velocity.x = facing * dash_in_speed
			_phase_timer -= delta
			if dist <= strike_range or _phase_timer <= 0.0:
				_begin_windup(windup2_time)
		Phase.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, approach_accel * delta)
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
				if _combo_left > 0 and distance_to_target() <= strike_range * 1.15:
					_combo_left -= 1
					_begin_windup(windup2_time)
				else:
					_enter_spacing(randf_range(0.35, 0.7))


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
		_combo_left = (1 if randf() < combo_chance else 0)
		_begin_windup(windup_time)
	elif dist <= engage_range:
		if randf() < 0.45:
			_phase = Phase.DASH_IN
			_phase_timer = 0.5
			facing = dir_to_target()
			_flash(Color(1.3, 1.3, 1.6, 1.0))
		else:
			_phase = Phase.APPROACH
			_phase_timer = 0.6
	else:
		_phase = Phase.APPROACH
		_phase_timer = 0.8


func _enter_spacing(think: float) -> void:
	_phase = Phase.SPACING
	_think = think


func _begin_windup(wtime: float) -> void:
	_phase = Phase.WINDUP
	_phase_timer = wtime
	facing = dir_to_target()
	_flash(Color(1.9, 0.9, 0.7, 1.0))   # 공격 예고: 붉은 번쩍 — 패링 타이밍 신호
	visual.scale = Vector2(0.82, 1.3)    # 칼을 치켜드는 포즈


func _begin_strike() -> void:
	_phase = Phase.STRIKE
	_phase_timer = strike_time
	visual.scale = Vector2(1.35, 0.82)
	if is_on_floor():
		velocity.x = facing * strike_lunge
	attack_hitbox.reset_hits()
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = attack_knockback
	attack_hitbox.knockback_direction = Vector2(facing, -0.25).normalized()
	attack_hitbox.monitoring = true
	_spawn_slash()


func _begin_recover() -> void:
	_phase = Phase.RECOVER
	_phase_timer = recover_time
	attack_hitbox.monitoring = false


func _on_parried_react(_from_pos: Vector2) -> void:
	_combo_left = 0
	_phase = Phase.RECOVER
	_phase_timer = recover_time


func _on_stagger_end() -> void:
	_enter_spacing(randf_range(0.3, 0.6))


func _spawn_slash() -> void:
	if slash_scene == null:
		return
	var fx := get_tree().get_first_node_in_group("fx")
	var parent: Node = fx if fx else get_parent()
	var s := slash_scene.instantiate() as SlashEffect
	s.color = Color(1.0, 0.5, 0.4, 0.9)
	s.core_color = Color(1.0, 0.9, 0.85, 1.0)
	parent.add_child(s)
	s.global_position = global_position + Vector2(signf(facing) * 34.0, -18.0)
	s.setup(facing, 0.0, 1.2)
