class_name PrinceHealth
extends HealthComponent

## 왕자 전용 체력 — floor_hp 아래로는 내려가지 않는다 (공용 HealthComponent의 API·동작은 그대로).
## 아무리 큰 피해도 페이즈 경계에서 멈추므로, 천지분쇄(패턴 4)와 마지막 일격(패턴 5)을 건너뛰고 쓰러질 수 없다.

var floor_hp: int = 0


func take_damage(amount: int) -> bool:
	return super.take_damage(mini(amount, hp - floor_hp))
