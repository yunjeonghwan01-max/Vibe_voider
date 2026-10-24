class_name RisingSlashAbility
extends Node2D

## 승천 참격 — 아래(S/↓)를 누른 채 E. 자세를 낮춰 잠깐 모았다가, 몸 주위 원을
## 뒤쪽 아래 → 머리 위 → 앞쪽 아래 (공중이면 → 발밑까지) 한 번에 베고, 그 반동으로 위로 튀어 오른다.
## 이 노드는 쿨다운, 원형 판정(Hitbox) on/off, 베는 궤적 그리기를 맡는다.
## 자세(웅크림/체공/튀어오름)는 Player 상태 머신(Action.RISING_SLASH)이 정한다.
## 튀어 오르는 동안에는 판정이 없다 — 몸으로 적을 쳐도 피해가 없다.

signal hit_landed(hurtbox: HurtboxComponent)

const START_DEG := 135.0                      # 뒤쪽 아래 (오른쪽을 볼 때 기준, 0 = 정면, + = 아래)
const END_GROUND_DEG := 405.0                 # 머리 위를 지나 앞쪽 아래
const END_AIR_DEG := 450.0                    # 공중이면 발밑까지
const FADE_TIME := 0.22
const COLOR_EDGE := Color(1.0, 0.95, 1.0, 1.0)
const COLOR_GLOW := Color(0.72, 0.5, 1.0, 1.0)

@export var cooldown: float = 3.0
@export var damage: int = 20                  # 평타 1타(10)의 2배
@export var knockback: float = 260.0
@export var radius: float = 120.0             # 베는 원의 반지름 (판정 = 그리기)
@export var sweep_time: float = 0.12          # 원을 베는 데 걸리는 시간

@onready var hitbox: HitboxComponent = $Hitbox

var _cd: float = 0.0
var _dir: float = 1.0
var _end_deg: float = END_GROUND_DEG
var _t: float = -1.0                          # 베기 경과 시간 (< 0 = 그리지 않음)


func _ready() -> void:
	(($Hitbox/CollisionShape2D as CollisionShape2D).shape as CircleShape2D).radius = radius
	hitbox.monitoring = false
	hitbox.apply_on_contact = true
	hitbox.hit_landed.connect(hit_landed.emit)


func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	if _t >= 0.0:
		_t += delta
		if _t >= sweep_time:
			hitbox.monitoring = false
		if _t >= sweep_time + FADE_TIME:
			_t = -1.0
		queue_redraw()


func can_use() -> bool:
	return _cd <= 0.0


## 쿨다운은 시전 순간에 건다 — 웅크리는 동안 맞아서 끊겨도 쿨다운은 돈다.
func start_cooldown() -> void:
	_cd = cooldown


func sweep(caster: Node2D, dir: float, airborne: bool) -> void:
	_dir = dir
	_end_deg = END_AIR_DEG if airborne else END_GROUND_DEG
	_t = 0.0
	hitbox.source = caster
	hitbox.reset_hits()
	hitbox.damage = damage
	hitbox.knockback_force = knockback
	hitbox.knockback_direction = Vector2(dir * 0.5, -1.0).normalized()
	hitbox.monitoring = true
	queue_redraw()


func cancel() -> void:
	hitbox.monitoring = false


## 검 각도(오른쪽 기준) → 화면 각도. 왼쪽을 보면 좌우를 뒤집는다.
func _screen_rad(deg: float) -> float:
	return deg_to_rad(deg if _dir > 0.0 else 180.0 - deg)


func _draw() -> void:
	if _t < 0.0:
		return
	var u := clampf(_t / sweep_time, 0.0, 1.0)
	var head := lerpf(START_DEG, _end_deg, 1.0 - pow(1.0 - u, 2.0))
	var fade := 1.0 - clampf((_t - sweep_time) / FADE_TIME, 0.0, 1.0)
	var c := hitbox.position
	var a0 := _screen_rad(START_DEG)
	var a1 := _screen_rad(head)
	# 바깥 광채 → 두꺼운 칼빛 → 가는 흰 날
	draw_arc(c, radius - 6.0, a0, a1, 40, Color(COLOR_GLOW, 0.25 * fade), 34.0 * fade + 4.0)
	draw_arc(c, radius - 4.0, a0, a1, 40, Color(COLOR_GLOW, 0.7 * fade), 14.0 * fade + 2.0)
	draw_arc(c, radius, a0, a1, 40, Color(COLOR_EDGE, fade), 3.0)
	if u < 1.0:
		draw_circle(c + Vector2.from_angle(a1) * radius, 9.0, Color(COLOR_EDGE, 0.9))
