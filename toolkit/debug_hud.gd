extends Control


@onready var info_label: Label = $InfoLabel


func _process(_delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var frame_time: float = 1000.0 / max(fps, 1)

	info_label.text = (
		"IBBD DEBUG\n"
		+ "FPS: %d\n" % fps
		+ "Frame Time: %.2f ms\n" % frame_time
		+ "Scene: %s" % get_tree().current_scene.name
	)