extends Control

## 개발용 치트 (플레이 테스트 단축키). 치트 키(tool_cheat = `)를 누른 채 숫자 키를 누르면 발동한다.
## 목록은 docs/cheats.txt에 정리한다 — 치트를 추가/변경하면 그 파일과 아래 CHEATS를 같이 고친다.
##
## 숫자 키는 따로 입력 액션을 만들지 않고 물리 키(KEY_1~KEY_9)로 읽는다. 숫자 1·5·6은 툴킷 단축키
## (tool_toggle_hud / tool_restart / tool_pause)의 보조 키이기도 해서, 치트로 쓴 입력은 여기서 소비한다
## (이 노드가 Toolkit의 자식이라 입력을 먼저 받는다).
## 발동하면 화면 위 가운데에 치트 이름을 잠깐 띄운다.

## 화면 표시용 이름 (기본 글꼴이 한글을 못 그릴 수 있어 영어로 둔다)
const CHEATS := {
	KEY_1: "Chain Counter x3 (Haki Burst)",
	KEY_2: "Summon Boss",
}

@onready var toast: Label = $Toast

var _toast_tween: Tween


func _ready() -> void:
	toast.visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if not Input.is_action_pressed("tool_cheat"):
		return
	var code := key.physical_keycode
	if code < KEY_1 or code > KEY_9:
		return
	get_viewport().set_input_as_handled()
	_run(code)


func _run(code: Key) -> void:
	var ok := false
	match code:
		KEY_1:
			var player := get_tree().get_first_node_in_group("player") as Player
			if player != null:
				player.force_chain_burst()
				ok = true
		KEY_2:
			var arena := get_tree().get_first_node_in_group("arena") as Arena
			ok = arena != null and arena.summon_boss_now()
	if not CHEATS.has(code):
		_show("CHEAT %d: (none)" % (code - KEY_0), false)
	else:
		_show("CHEAT %d: %s" % [code - KEY_0, CHEATS[code]], ok)


func _show(text: String, ok: bool) -> void:
	toast.text = text if ok else text + "  - not available now"
	toast.modulate = Color(1.0, 0.9, 0.55) if ok else Color(0.75, 0.7, 0.85)
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: toast.visible = false)
