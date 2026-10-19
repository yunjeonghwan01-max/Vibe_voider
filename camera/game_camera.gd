class_name GameCamera
extends Camera2D

## 플레이어를 부드럽게 따라가고, 진행/속도 방향으로 살짝 앞을 본다(look-ahead).
## trauma 기반 흔들림을 가진다 (trauma^2 로 감쇠 — 작은 타격은 작게, 큰 타격은 크게).
## GameFeel.shake()가 현재 카메라를 찾도록 static current를 제공한다.

static var current: GameCamera = null

@export var target: Node2D
@export var follow_lerp: float = 8.0
@export var look_ahead: float = 60.0
@export var look_ahead_lerp: float = 3.0
@export var vertical_offset: float = -24.0

@export_group("Shake")
@export var max_shake_offset: float = 18.0
@export var max_shake_roll: float = 0.08
@export var trauma_decay: float = 1.4

var _trauma: float = 0.0
var _look: float = 0.0
var _noise_seed: float = 0.0


func _ready() -> void:
	current = self
	make_current()
	_noise_seed = randf() * 1000.0
	if target != null:
		global_position = target.global_position + Vector2(0.0, vertical_offset)


func _exit_tree() -> void:
	if current == self:
		current = null


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var facing := 1.0 if target.get("facing") == null else float(target.facing)
		var desired_look := facing * look_ahead
		_look = lerp(_look, desired_look, 1.0 - exp(-look_ahead_lerp * delta))
		var desired := target.global_position + Vector2(_look, vertical_offset)
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_lerp * delta))

	# 흔들림: trauma^2 로 변환해 부드럽게 들어오고 빠르게 빠진다.
	if _trauma > 0.0:
		_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
		var shake := _trauma * _trauma
		var t := Time.get_ticks_msec() / 1000.0
		offset = Vector2(
			max_shake_offset * shake * _rand_noise(t * 37.0 + _noise_seed),
			max_shake_offset * shake * _rand_noise(t * 41.0 + _noise_seed + 100.0)
		)
		rotation = max_shake_roll * shake * _rand_noise(t * 29.0 + _noise_seed + 200.0)
	elif offset != Vector2.ZERO or rotation != 0.0:
		offset = Vector2.ZERO
		rotation = 0.0


## -1..1 범위의 의사 난수 (시간 기반, sin 합성). 외부 노이즈 리소스 없이 떨림을 만든다.
func _rand_noise(x: float) -> float:
	return sin(x * 1.7) * 0.5 + sin(x * 3.1 + 1.3) * 0.3 + sin(x * 5.3 + 2.7) * 0.2
