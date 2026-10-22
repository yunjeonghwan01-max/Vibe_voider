class_name PlayerVisual
extends Node2D

## 플레이어 외형 애니메이션 — 몸통(시트 프레임)과 검(따로 회전하는 파츠)을 움직인다.
## Visual 노드 자체의 좌우 반전/스쿼시/기울임은 Player가 맡고, 여기서는 자식 파츠만 다룬다.
## Player가 상태가 바뀔 때 play()를 부르고, 매 물리 프레임 tick()을 부른다.
## 번쩍임(피격/패링)은 Visual의 hit_flash 머티리얼로 칠한다 (자식은 use_parent_material).

signal footstep

enum Frame { IDLE, RUN1, RUN2, RUN3, RUN4, JUMP, FALL, HURT, DASH }

## 검 각도 키프레임 [시간(초), 각도(도)] — 0° = 정면, +는 아래로. 구간마다 ease-out으로 잇는다.
const KEYS := {
	&"attack_1": [[0.0, -105.0], [0.035, -120.0], [0.145, 72.0], [0.25, 42.0]],
	&"attack_2": [[0.0, 95.0], [0.035, 105.0], [0.145, -82.0], [0.25, -52.0]],
	&"attack_3": [[0.0, -160.0], [0.035, -172.0], [0.16, 58.0], [0.3, 30.0]],
	&"parry": [[0.0, -40.0], [0.05, -78.0], [0.3, -70.0]],
	&"parry_success": [[0.0, -78.0], [0.05, -150.0], [0.22, -60.0]],
	&"cast": [[0.0, -70.0], [0.05, -95.0], [0.1, -8.0], [0.26, 6.0]],
	&"dash_slash": [[0.0, 168.0], [0.03, 176.0], [0.12, -4.0], [0.28, 8.0]],
	&"cast_up": [[0.0, -30.0], [0.06, -105.0], [0.15, -92.0], [0.35, -86.0]],
	&"dash": [[0.0, 120.0], [0.06, 172.0]],
	&"hurt": [[0.0, 60.0], [0.1, 100.0]],
	&"dead": [[0.0, 90.0], [0.3, 115.0]],
}

@onready var body: Sprite2D = $Body
@onready var sword: Sprite2D = $Sword

var anim: StringName = &"locomotion"
var _t: float = 0.0
var _run_cycle: float = 0.0
var _sword_deg: float = 22.0


func play(anim_name: StringName) -> void:
	anim = anim_name
	_t = 0.0


func set_flash(color: Color, amount: float) -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash", clampf(amount, 0.0, 1.0))


func tick(delta: float, vel: Vector2, on_floor: bool, run_speed: float) -> void:
	_t += delta
	var frame_i: int = Frame.IDLE
	var target: float = _sword_deg
	var snap := false
	var breath := 0.0

	match anim:
		&"locomotion":
			if not on_floor:
				frame_i = Frame.JUMP if vel.y < 0.0 else Frame.FALL
				target = -12.0 if vel.y < 0.0 else 38.0
				_run_cycle = 0.0
			elif absf(vel.x) > 30.0:
				var prev := int(_run_cycle)
				_run_cycle = fmod(_run_cycle + delta * 12.0 * clampf(absf(vel.x) / run_speed, 0.6, 1.2), 4.0)
				var idx := int(_run_cycle)
				if idx != prev and (idx == 0 or idx == 2):
					footstep.emit()
				frame_i = Frame.RUN1 + idx
				target = 32.0 + 5.0 * sin(_run_cycle * PI)
			else:
				_run_cycle = 0.0
				frame_i = Frame.IDLE
				target = 22.0 + 3.0 * sin(_t * 2.4)
				breath = sin(_t * 2.4) * 0.025
		&"attack_1", &"attack_2", &"attack_3":
			target = _keyed(KEYS[anim], _t)
			snap = true
			frame_i = Frame.DASH if _t >= 0.035 and _t < 0.17 else Frame.IDLE
		&"cast":
			# 장풍: 검을 뒤로 젖혔다가 앞으로 내지르며 쏜다
			target = _keyed(KEYS[anim], _t)
			snap = true
			frame_i = Frame.DASH if _t >= 0.05 and _t < 0.18 else Frame.IDLE
		&"cast_up":
			# 벼락: 검을 하늘로 치켜든다
			target = _keyed(KEYS[anim], _t)
			snap = true
			frame_i = Frame.IDLE if on_floor else Frame.FALL
		&"dash_slash":
			# 대시 참격: 뒤로 끌던 검을 앞으로 수평에 가깝게 쓸어 벤다
			target = _keyed(KEYS[anim], _t)
			snap = true
			frame_i = Frame.DASH if _t < 0.2 else Frame.IDLE
		&"ultimate":
			target = -90.0 + 1080.0 * (1.0 - pow(1.0 - clampf(_t / 0.4, 0.0, 1.0), 2.0))
			snap = true
			frame_i = Frame.DASH
		&"dash":
			target = _keyed(KEYS[anim], _t)
			snap = true
			frame_i = Frame.DASH
		&"hurt", &"dead":
			target = _keyed(KEYS[anim], _t)
			snap = true
			frame_i = Frame.HURT
		_:
			if KEYS.has(anim):
				target = _keyed(KEYS[anim], _t)
				snap = true

	if snap:
		_sword_deg = target
	else:
		_sword_deg = lerpf(_sword_deg, target, 1.0 - exp(-18.0 * delta))
	sword.rotation_degrees = _sword_deg
	body.frame = frame_i
	body.scale = Vector2(2.0 - breath, 2.0 + breath * 2.0)


func _keyed(keys: Array, t: float) -> float:
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var u := (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			u = 1.0 - pow(1.0 - u, 3.0)
			return lerpf(a[1], b[1], u)
	return keys[-1][1]
