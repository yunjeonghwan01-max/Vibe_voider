class_name LightningAbility
extends Node2D

## 벼락 — 세 번째 스킬 (위(W/↑)를 누른 채 E). 하늘에서 깊은 검보라 번개가 플레이어에게 떨어진다.
## 이 노드는 쿨다운과 번개(LightningBolt) 스폰을 맡는다. 시전 자세(이동 불가, 공중이면 도달까지 체공)는
## Player 상태 머신(Action.LIGHTNING)이 travel_time을 보고 정한다.

signal hit_landed(hurtbox: HurtboxComponent)

@export var bolt_scene: PackedScene
@export var cooldown: float = 2.0
@export var travel_time: float = 0.15        # 하늘에서 플레이어까지 떨어지는 시간 (lightning.wav의 "콰직" 시점과 맞춤)
@export var damage: int = 20                 # 평타 1타(10)의 2배
@export var sky_height: float = 760.0        # 번개가 시작되는 높이 (화면 위 바깥)

var _cd: float = 0.0


func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)


func can_cast() -> bool:
	return _cd <= 0.0 and bolt_scene != null


func cast(caster: Node2D) -> void:
	_cd = cooldown
	var bolt := bolt_scene.instantiate() as LightningBolt
	bolt.source = caster
	bolt.damage = damage
	bolt.travel_time = travel_time
	bolt.sky_height = sky_height
	bolt.hit_landed.connect(hit_landed.emit)
	var fx := get_tree().get_first_node_in_group("fx")
	(fx if fx else owner.get_parent()).add_child(bolt)
	bolt.global_position = caster.global_position
