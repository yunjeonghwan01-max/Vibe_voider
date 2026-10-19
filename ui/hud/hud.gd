extends CanvasLayer

## 플레이어 HUD — 체력 바와 궁극기 충전 바. 플레이어 시그널에 반응해 갱신한다.
## 궁극기가 가득 차면 바가 번쩍이며 "ULT READY"를 표시한다.

const HP_WIDTH: float = 280.0
const ULT_WIDTH: float = 220.0

@onready var hp_fill: ColorRect = $Root/HealthBar/Fill
@onready var ult_fill: ColorRect = $Root/UltBar/Fill
@onready var ready_label: Label = $Root/UltBar/ReadyLabel

var _ult_ready: bool = false
var _flash: float = 0.0


func bind(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	player.ultimate_changed.connect(_on_ultimate_changed)
	player.ultimate_ready_changed.connect(_on_ultimate_ready_changed)
	# 플레이어가 이미 _ready에서 초기값을 쏜 뒤이므로 현재 값을 직접 읽어 맞춘다.
	_on_health_changed(player.health.hp, player.health.max_hp)
	_on_ultimate_changed(player.ult_charge, player.ultimate_max)
	_on_ultimate_ready_changed(player.is_ultimate_ready())


func _on_health_changed(hp: int, max_hp: int) -> void:
	var ratio := 0.0 if max_hp <= 0 else clampf(float(hp) / float(max_hp), 0.0, 1.0)
	hp_fill.size.x = HP_WIDTH * ratio
	# 체력이 낮을수록 붉어진다.
	hp_fill.color = Color(1.0, 0.3, 0.32).lerp(Color(0.45, 1.0, 0.55), ratio)


func _on_ultimate_changed(charge: float, max_charge: float) -> void:
	var ratio := 0.0 if max_charge <= 0.0 else clampf(charge / max_charge, 0.0, 1.0)
	ult_fill.size.x = ULT_WIDTH * ratio


func _on_ultimate_ready_changed(is_ready: bool) -> void:
	_ult_ready = is_ready
	ready_label.visible = is_ready
	if not is_ready:
		ult_fill.color = Color(0.55, 0.45, 0.95)


func _process(delta: float) -> void:
	if _ult_ready:
		_flash += delta * 6.0
		var p := 0.5 + 0.5 * sin(_flash)
		ult_fill.color = Color(0.7, 0.55, 1.0).lerp(Color(1.0, 0.95, 0.6), p)
		ready_label.modulate.a = 0.4 + 0.6 * p
