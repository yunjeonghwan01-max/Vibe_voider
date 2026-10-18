class_name HurtboxComponent
extends Area2D

## 피격 판정 영역 (layer만 가지고 mask는 0 — 스스로 감지하지 않고 Hitbox에게 감지당한다).
## Hitbox에게 맞으면 hit_received로 Actor에게 알리고, 연결된 Health에 데미지를 전달한다.
## invincibility_duration > 0이면 맞은 직후 그 시간 동안 추가 피격을 받지 않는다.

signal hit_received(damage: int, source: Node, knockback: Vector2)

@export var health: HealthComponent
@export var invincibility_duration: float = 0.0

var invincible: bool = false


## 피격이 성립했으면 true (데미지가 0이어도 성립). 무적이거나 이미 죽었으면 false.
func receive_hit(damage: int, source: Node, knockback: Vector2 = Vector2.ZERO) -> bool:
	if health == null:
		# owner가 없으면(씬에 저장되지 않고 코드로만 생성) 컴포넌트 자신의 이름으로 기록한다.
		var label := owner.name if owner else name
		push_warning("[Hurtbox] %s: health reference is missing" % label)
		return false
	if invincible or health.is_dead():
		return false

	hit_received.emit(damage, source, knockback)
	health.take_damage(damage)

	if invincibility_duration > 0.0 and not health.is_dead():
		_start_invincibility()
	return true


func _start_invincibility() -> void:
	invincible = true
	await get_tree().create_timer(invincibility_duration).timeout
	invincible = false
