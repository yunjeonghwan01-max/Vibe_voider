class_name DashSlashAbility
extends Node2D

## 대시 참격 — 두 번째 스킬. 대시와 동시에, 또는 대시 중에 스킬 키(E)를 누르면
## 대시가 끝난 뒤 조금 더 파고들며 평타보다 수평으로 긴 참격을 휘두른다.
## 이 노드는 쿨다운, 참격 판정(Hitbox) 설정·on/off, 궤적 이펙트 스폰을 맡는다.
## 입력 예약(대시 중)과 자세(전진/체공/캔슬)는 Player 상태 머신(Action.DASH_SLASH)이 정한다.
## 대시로 지나온 길도 벤다: begin()의 back(지나온 거리)만큼 판정과 칼빛을 뒤쪽(대시 시작점)으로 늘린다.

signal hit_landed(hurtbox: HurtboxComponent)

@export var cooldown: float = 0.9
@export var damage: int = 15                  # 평타 1타(10)의 1.5배
@export var knockback: float = 240.0
@export var reach_offset: float = 116.0       # Hitbox 중심이 몸 앞쪽으로 떨어진 거리 (오른쪽 기준, 판정 길이 260 → 앞으로 약 246까지)
@export var effect_scene: PackedScene

@onready var hitbox: HitboxComponent = $Hitbox
@onready var _shape: RectangleShape2D = ($Hitbox/CollisionShape2D as CollisionShape2D).shape

var _cd: float = 0.0
var _base_width: float = 0.0


func _ready() -> void:
	# 판정 길이를 매번 바꾸므로 씬의 공유 리소스를 건드리지 않게 복제해 쓴다
	_shape = _shape.duplicate() as RectangleShape2D
	($Hitbox/CollisionShape2D as CollisionShape2D).shape = _shape
	_base_width = _shape.size.x
	hitbox.monitoring = false
	hitbox.apply_on_contact = true
	hitbox.hit_landed.connect(hit_landed.emit)


func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)


func can_use() -> bool:
	return _cd <= 0.0


## 참격 시작: 쿨다운을 걸고 판정을 바라보는 쪽으로 맞춘 뒤 궤적을 그린다. 판정 on/off는 set_active로.
## back: 대시로 지나온 거리 — 기본 판정(몸 앞)에 더해 뒤쪽으로 이만큼 늘려 지나온 길의 적도 벤다.
func begin(caster: Node2D, dir: float, back: float = 0.0) -> void:
	_cd = cooldown
	hitbox.source = caster
	hitbox.reset_hits()
	hitbox.damage = damage
	hitbox.knockback_force = knockback
	hitbox.knockback_direction = Vector2(dir, -0.18).normalized()
	_shape.size.x = _base_width + back
	hitbox.position = Vector2((reach_offset - back * 0.5) * dir, hitbox.position.y)
	_spawn_effect(caster.global_position + Vector2((-12.0 - back) * dir, hitbox.position.y), dir, back)


func set_active(on: bool) -> void:
	hitbox.monitoring = on


func _spawn_effect(pos: Vector2, dir: float, back: float) -> void:
	if effect_scene == null:
		return
	var fx := get_tree().get_first_node_in_group("fx")
	var e := effect_scene.instantiate() as DashSlashEffect
	(fx if fx else owner.get_parent()).add_child(e)
	e.length += back
	e.global_position = pos
	e.setup(dir)
