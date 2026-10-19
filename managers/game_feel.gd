extends Node

## GameFeel (Autoload) — 전투 "손맛"의 전역 조율자.
## 지금은 hit-stop(프리즈 프레임)과 카메라 흔들림 라우팅만 담당한다.
## 흔들림 자체는 GameCamera가 가진다. GameFeel은 "어디서든 호출" 편의를 제공한다.

var _hitstop_token: int = 0
var _flash_rect: ColorRect = null


func _ready() -> void:
	# 게임이 멈추거나 time_scale이 0이어도 hit-stop 복구 타이머는 돌아야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_flash_layer()


## 화면 전체 플래시용 레이어 (패링/궁극기 등 "큰 순간"의 명확한 피드백).
func _build_flash_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash_rect)


## 화면을 color로 번쩍이고 duration 동안 사라진다.
func flash(color: Color, start_alpha: float = 0.4, duration: float = 0.14) -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = Color(color.r, color.g, color.b, start_alpha)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD)


## 아주 짧게 시간을 (거의) 멈췄다 되돌린다. 타격의 무게를 만든다.
## scale 0.0 = 완전 정지. duration은 실제 시간(초) 기준.
func hit_stop(duration: float, scale: float = 0.0) -> void:
	if duration <= 0.0:
		return
	_hitstop_token += 1
	var my_token := _hitstop_token
	Engine.time_scale = scale
	# ignore_time_scale = true → time_scale과 무관하게 실제 시간으로 센다.
	await get_tree().create_timer(duration, true, false, true).timeout
	# 더 최근의 hit_stop이 끼어들지 않았을 때만 복구한다.
	if my_token == _hitstop_token:
		Engine.time_scale = 1.0


## 화면 흔들림. 현재 활성 GameCamera로 전달한다.
func shake(trauma: float) -> void:
	if GameCamera.current != null and is_instance_valid(GameCamera.current):
		GameCamera.current.add_trauma(trauma)
