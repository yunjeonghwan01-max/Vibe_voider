class_name Main
extends Node

## 게임 최상위 셸. 현재 Level과 개발 Toolkit을 자식으로 가진다.
## Level 콘텐츠(TileMap, Actor, World Object)는 여기에 직접 두지 않고 levels/의 Level 씬에 둔다.
##
## 개발 치트 8(` + 8)이 levels를 차례로 돌며 레벨을 바꾼다 (씬을 다시 불러 처음 상태로 시작).
## 고른 레벨은 재시작(F5)해도 유지되고, 게임을 껐다 켜면 기본 레벨(levels[0])로 돌아간다.

## 고를 수 있는 레벨. levels[0]은 main.tscn에 미리 놓인 기본 레벨(level)과 같은 씬이어야 한다.
@export var levels: Array[PackedScene] = []
## main.tscn에 미리 놓인 기본 레벨 인스턴스
@export var level: Node

## 씬을 다시 불러와도 남도록 static에 둔다.
static var _level_index: int = 0


func _enter_tree() -> void:
	add_to_group("main")   # 개발 치트(toolkit/cheats.gd)가 레벨을 바꿀 때 찾는다
	# 자식이 트리에 들어가기 전에 바꿔서, 기본 레벨이 한 프레임도 돌지 않게 한다.
	if _level_index <= 0 or _level_index >= levels.size() or level == null:
		return
	var next := levels[_level_index].instantiate()
	var index := level.get_index()
	remove_child(level)
	level.free()
	add_child(next)
	move_child(next, index)
	level = next


## 다음 레벨로 바꾼다 (씬을 다시 불러 처음부터). 바뀐 레벨의 노드 이름을 돌려준다.
func cycle_level() -> String:
	if levels.size() < 2:
		return ""
	_level_index = (_level_index + 1) % levels.size()
	get_tree().reload_current_scene.call_deferred()
	return levels[_level_index].get_state().get_node_name(0)
