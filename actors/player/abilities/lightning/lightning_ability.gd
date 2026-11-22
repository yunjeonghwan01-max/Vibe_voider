class_name LightningAbility
extends Node2D

## 벼락 — 세 번째 스킬 (위(W/↑)를 누른 채 E). 하늘에서 깊은 검보라 번개가 플레이어에게 떨어진다.
## 이 노드는 쿨다운, 번개(LightningBolt) 스폰, 시전 자세의 타이밍을 맡는다.
## Player는 Action.LIGHTNING 동안 start_pose / update_pose를 부르고, 몸 표현(찌그러짐·번쩍임·애니메이션)과
## 반격 캔슬·자세 종료는 직접 처리한다.

signal hit_landed(hurtbox: HurtboxComponent)

@export var bolt_scene: PackedScene
@export var cooldown: float = 2.0
@export var travel_time: float = 0.15        # 하늘에서 플레이어까지 떨어지는 시간 (lightning.wav의 "콰직" 시점과 맞춤)
@export var damage: int = 20                 # 평타 1타(10)의 2배
@export var sky_height: float = 760.0        # 번개가 시작되는 높이 (화면 위 바깥)
@export var recovery: float = 0.2            # 번개가 꽂힌 뒤에도 이만큼 이동 불가

var _cd: float = 0.0
var _pose_t: float = 0.0                     # 시전 자세 경과 시간
var _struck: bool = false                    # 이번 시전에서 번개가 이미 꽂혔는가


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


# ─────────────── 시전 자세 (Player가 Action.LIGHTNING 동안 사용) ───────────────
## 이동 불가. 공중이면 번개가 닿을 때까지 떠 있고, 닿은 뒤 recovery만큼 더 굳는다.

func start_pose(player: Player) -> void:
	_pose_t = 0.0
	_struck = false
	player.velocity.x = 0.0
	if not player.is_on_floor():
		player.velocity.y = 0.0
	cast(player)


## 매 물리 프레임 호출. 번개가 꽂힌 바로 그 프레임에만 true를 돌려준다.
func update_pose(player: Player, delta: float) -> bool:
	_pose_t += delta
	player.velocity.x = 0.0
	if _pose_t < travel_time:
		player.velocity.y = 0.0      # 번개가 닿을 때까지 공중에 떠 있다
		return false
	if _struck:
		return false
	_struck = true
	return true


func has_struck() -> bool:
	return _struck


func is_pose_over() -> bool:
	return _pose_t >= travel_time + recovery
