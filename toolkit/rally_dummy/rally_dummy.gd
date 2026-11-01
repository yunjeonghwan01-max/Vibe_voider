extends Knight

## 개발 치트(` + 3) 전용 가짜 보스 — 월식의 기사와 똑같지만 반격 자세(→ 랠리 공방)만 쓰고 쓰러지지 않는다.
## 수치는 원본 기사의 수치 파일을 그대로 빌려 쓴다 (랠리 확률·창 길이·피해가 본편과 같게).
## 본편은 이 폴더를 모른다 — 치트 3번과 이 폴더를 지워도 게임에는 영향이 없다.

@export var tuning_scene: PackedScene                   ## 수치 파일을 빌려 올 원본 씬 (기사)
@export var tint: Color = Color(0.62, 0.8, 1.0)         # 진짜 보스와 구별되는 푸르스름한 몸빛
@export var refill_below: float = 0.25                  # 체력이 이 비율 아래로 내려가면 다시 가득 찬다


func _enter_tree() -> void:
	super()
	if tuning_scene != null:
		Tuning.apply(self, tuning_scene.resource_path)


func _on_ready() -> void:
	super()
	visual.modulate = Color(tint, visual.modulate.a)
	health.damaged.connect(_refill)


## 다음 패턴은 언제나 반격 자세 (쿨타임·거리 무시). 자세가 그냥 풀리면 기사의 짧은 대기 뒤 다시 잡는다.
func _decide(_dist: float) -> void:
	_begin_guard()


## take_damage가 사망을 판정하기 전에 불리므로, 여기서 채우면 쓰러지지 않는다.
func _refill(_amount: int) -> void:
	if health.hp <= int(health.max_hp * refill_below):
		health.hp = health.max_hp
