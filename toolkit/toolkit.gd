extends CanvasLayer


@onready var debug_hud: Control = $DebugHud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tool_toggle_hud"):
		_toggle_debug_hud()
	elif event.is_action_pressed("tool_restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("tool_pause"):
		get_tree().paused = not get_tree().paused


func _toggle_debug_hud() -> void:
	debug_hud.visible = not debug_hud.visible