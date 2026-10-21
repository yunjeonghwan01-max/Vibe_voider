extends CanvasLayer

## 플레이어 HUD — 초상화, 체력 바, 궁극기 충전 바. 플레이어 시그널에 반응해 갱신한다.
## 체력이 깎이면 흰 잔상 바가 잠깐 남았다가 따라 줄어들어 "얼마나 맞았는지"가 보인다.
## 궁극기가 가득 차면 바가 번쩍이며 "ULT READY"를 표시한다.

@onready var hp_fill: ColorRect = $Root/HealthBar/Fill
@onready var hp_lag: ColorRect = $Root/HealthBar/Lag
@onready var ult_fill: ColorRect = $Root/UltBar/Fill
@onready var ready_label: Label = $Root/UltBar/ReadyLabel
@onready var portrait: Control = $Root/Portrait

var _hp_width: float
var _ult_width: float
var _ult_ready: bool = false
var _flash: float = 0.0
var _last_ratio: float = 1.0
var _lag_tween: Tween
var _shake: float = 0.0
var _portrait_pos: Vector2


func _ready() -> void:
	_hp_width = hp_fill.size.x
	_ult_width = ult_fill.size.x
	_portrait_pos = portrait.position


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
	hp_fill.size.x = _hp_width * ratio
	# 체력이 낮을수록 붉어진다.
	hp_fill.color = Color(0.95, 0.25, 0.32).lerp(Color(0.5, 0.95, 0.6), ratio)
	if _lag_tween != null:
		_lag_tween.kill()
	if ratio < _last_ratio:
		_shake = 1.0
		_lag_tween = create_tween()
		_lag_tween.tween_interval(0.3)
		_lag_tween.tween_property(hp_lag, "size:x", _hp_width * ratio, 0.35).set_trans(Tween.TRANS_QUAD)
	else:
		hp_lag.size.x = _hp_width * ratio
	_last_ratio = ratio


func _on_ultimate_changed(charge: float, max_charge: float) -> void:
	var ratio := 0.0 if max_charge <= 0.0 else clampf(charge / max_charge, 0.0, 1.0)
	ult_fill.size.x = _ult_width * ratio


func _on_ultimate_ready_changed(is_ready: bool) -> void:
	_ult_ready = is_ready
	ready_label.visible = is_ready
	if not is_ready:
		ult_fill.color = Color(0.55, 0.42, 0.95)


func _process(delta: float) -> void:
	if _ult_ready:
		_flash += delta * 6.0
		var p := 0.5 + 0.5 * sin(_flash)
		ult_fill.color = Color(0.7, 0.55, 1.0).lerp(Color(1.0, 0.95, 0.6), p)
		ready_label.modulate.a = 0.4 + 0.6 * p
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 4.0, 0.0)
		portrait.position = _portrait_pos + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0)) * _shake
