class_name Tuning
extends RefCounted

## 객체 씬의 수치 파일(<씬>_tuning.cfg, 씬과 같은 폴더)을 읽어 노드 속성에 덮어쓴다.
## 수치의 단일 출처는 이 파일이다 — 같은 값이 .gd 기본값이나 .tscn에 있어도 파일 값이 이긴다.
## 섹션 이름은 씬 루트 기준 노드 경로 ("." = 루트, "Combat/Health" 등), 키는 그 노드의 속성 이름.
## 루트의 _enter_tree()에서 부르면 자식들의 _ready()보다 먼저 적용된다 (예: Health가 max_hp로 hp를 채우기 전).


## scene_path를 주면 그 씬의 수치 파일을 쓴다 (다른 씬을 상속한 씬이 원본 수치를 그대로 빌려 쓸 때).
static func apply(root: Node, scene_path: String = "") -> void:
	if scene_path.is_empty():
		scene_path = root.scene_file_path
	if scene_path.is_empty():
		return
	var path := scene_path.get_basename() + "_tuning.cfg"
	if not FileAccess.file_exists(path):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		push_error("[Tuning] %s: load failed (%s)" % [path, error_string(err)])
		return
	for section in cfg.get_sections():
		var node := root.get_node_or_null(NodePath(section))
		if node == null:
			push_warning("[Tuning] %s: node '%s' not found" % [path, section])
			continue
		for key in cfg.get_section_keys(section):
			if not key in node:
				push_warning("[Tuning] %s: '%s' has no property '%s'" % [path, section, key])
				continue
			var value: Variant = cfg.get_value(section, key)
			var current: Variant = node.get(key)
			if current is Array and value is Array:
				# 타입 지정 배열(Array[int] 등)은 set()으로 넣으면 조용히 무시되므로 새 배열에 담아 넣는다
				var typed: Array = (current as Array).duplicate()
				typed.assign(value)
				node.set(key, typed)
			else:
				node.set(key, value)
