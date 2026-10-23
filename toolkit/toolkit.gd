extends CanvasLayer


@onready var debug_hud: Control = $DebugHud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	debug_hud.visible = false   # 게임 HUD를 가리지 않도록 기본은 숨김 (tool_toggle_hud = F1로 켠다)


func _unhandled_input(event: InputEvent) -> void:
	# 치트 키(`)를 누르고 있는 동안의 숫자 키는 Cheats가 쓴다 — 보조 키가 숫자인 단축키가 같이 발동하지 않게.
	if Input.is_action_pressed("tool_cheat"):
		return
	if event.is_action_pressed("tool_toggle_hud"):
		_toggle_debug_hud()
	elif event.is_action_pressed("tool_restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("tool_pause"):
		get_tree().paused = not get_tree().paused


func _toggle_debug_hud() -> void:
	debug_hud.visible = not debug_hud.visible