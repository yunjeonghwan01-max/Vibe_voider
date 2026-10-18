class_name HitboxComponent
extends Area2D

## 공격 판정 영역. 상대 진영의 HurtboxComponent에 닿으면 receive_hit()을 호출한다.
## reset_hits()부터 다음 reset_hits()까지(= 한 번의 공격 판정) 같은 Hurtbox는 한 번만 친다.
## 판정 on/off는 사용하는 쪽이 monitoring으로 제어한다.
##
## apply_on_contact = false면 데미지를 직접 주지 않고 hurtbox_entered만 알린다.
## (다단히트처럼 공격 쪽이 대상별 타이밍/데미지를 직접 처리하는 경우)

signal hit_landed(hurtbox: HurtboxComponent)
signal hurtbox_entered(hurtbox: HurtboxComponent)

@export var damage: int = 10
@export var knockback_force: float = 0.0
@export var apply_on_contact: bool = true

## 공격자. 비어 있으면 owner(이 Hitbox를 가진 씬 루트)를 쓴다. 투사체는 스폰한 Actor를 넣는다.
var source: Node = null
var knockback_direction: Vector2 = Vector2.ZERO
var hit_targets: Array[HurtboxComponent] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func reset_hits() -> void:
	hit_targets.clear()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null or hurtbox in hit_targets:
		return

	if not apply_on_contact:
		hit_targets.append(hurtbox)
		hurtbox_entered.emit(hurtbox)
		return

	var attacker := source if source else owner
	if hurtbox.receive_hit(damage, attacker, knockback_direction * knockback_force):
		hit_targets.append(hurtbox)
		hit_landed.emit(hurtbox)
