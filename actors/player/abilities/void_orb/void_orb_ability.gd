class_name VoidOrbAbility
extends Node2D

## 장풍(공허 구체) — 플레이어의 첫 번째 스킬 (player_skill, E).
## 이 노드는 쿨다운과 구체 발사(스폰)를 맡는다. 입력 우선순위와 시전 자세(반동/체공)는 Player 상태 머신이 정한다.
## 구체 자체의 관통·다단히트·넉백은 VoidOrbProjectile이 처리한다.

signal hit_landed(hurtbox: HurtboxComponent)
signal ready_again                       # 쿨다운이 끝난 순간 (플레이어가 살짝 빛나 알려준다)

@export var projectile_scene: PackedScene
@export var cooldown: float = 0.9
# 구체 수치 — 발사할 때 구체에 넘긴다 (수치 파일은 player_tuning.cfg 하나로 모은다)
@export var damage_per_hit: int = 7
@export var max_hits_per_target: int = 3
@export var knockback_per_hit: float = 60.0
@export var first_knockback: float = 420.0
@export var speed: float = 1725.0
@export var max_distance: float = 950.0
@export var spawn_offset: Vector2 = Vector2(0.0, -8.0)    # 플레이어 몸 중심에서 발사 (오른쪽 기준, 좌우는 dir로 맞춘다)

var _cd: float = 0.0


func _physics_process(delta: float) -> void:
	if _cd > 0.0:
		_cd = maxf(_cd - delta, 0.0)
		if _cd == 0.0:
			ready_again.emit()


func can_cast() -> bool:
	return _cd <= 0.0 and projectile_scene != null


func cast(caster: Node2D, dir: float) -> void:
	_cd = cooldown
	var orb := projectile_scene.instantiate() as VoidOrbProjectile
	orb.source = caster
	orb.direction = dir
	orb.damage_per_hit = damage_per_hit
	orb.max_hits_per_target = max_hits_per_target
	orb.knockback_per_hit = knockback_per_hit
	orb.first_knockback = first_knockback
	orb.speed = speed
	orb.max_distance = max_distance
	orb.hit_landed.connect(hit_landed.emit)
	_projectile_parent().add_child(orb)
	orb.global_position = caster.global_position + Vector2(spawn_offset.x * dir, spawn_offset.y)


func _projectile_parent() -> Node:
	var container := get_tree().get_first_node_in_group("projectiles")
	return container if container else owner.get_parent()
