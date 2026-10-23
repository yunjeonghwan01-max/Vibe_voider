class_name Arena
extends Node2D

## 달빛 성소 — 한 방짜리 전투 공간.
## 플레이어는 씬에 배치돼 있고, 적(잡몹 무리 + 듀얼리스트 1)은 코드로 스폰한다.
## 쓰러진 적은 잠시 뒤 플레이어에게서 떨어진 지점에 다시 나타나 전투 흐름이 끊기지 않게 한다.
## 창문 너머 하늘과 전경 사슬은 카메라 위치에 맞춰 다른 속도로 움직여 깊이감을 준다.
##
## 보스전 (임시 흐름): 감시자를 watchers_for_boss(3)번 쓰러뜨리면 남은 적을 모두 추방하고 음악이 끊긴 뒤,
## 방이 흔들리며 천장 부스러기가 떨어지고 월식의 기사가 "쿵" 떨어진다 (바닥이 깨지고 발판에 금이 간다).
## 보스를 쓰러뜨리면 잠시 뒤 평소 음악과 적들이 돌아오고 처치 수가 다시 0부터 센다 (반복 플레이용).

@export var grunt_scene: PackedScene
@export var duelist_scene: PackedScene
@export var watcher_scene: PackedScene
@export var knight_scene: PackedScene
@export var impact_scene: PackedScene
@export var watchers_for_boss: int = 3
@export var room_floor_y: float = 0.0
@export var room_x: Vector2 = Vector2(-760.0, 760.0)     # 보스 몸 중심이 갈 수 있는 좌우 범위
@export var room_ceiling_y: float = -640.0
@export var grunt_count: int = 4
@export var grunt_respawn_delay: float = 2.5
@export var duelist_respawn_delay: float = 6.0
@export var watcher_respawn_delay: float = 7.0
@export var watcher_fly_bounds: Rect2 = Rect2(-740.0, -620.0, 1480.0, 520.0)   # 감시자가 날 수 있는 방 안쪽
@export var sky_parallax: float = 0.35          # 1보다 작을수록 멀리 있는 것처럼 느리게 움직인다
@export var foreground_parallax: float = 0.18   # 전경은 카메라보다 빠르게 지나간다
@export var min_spawn_distance: float = 280.0   # 플레이어 바로 옆에서 튀어나오지 않게

@onready var actors: Node2D = $Actors
@onready var effects: Node2D = $Effects
@onready var projectiles: Node2D = $Projectiles
@onready var camera: GameCamera = $GameCamera
@onready var player: Player = $Actors/Player
@onready var hud: CanvasLayer = $Hud
@onready var sky_layer: Node2D = $World/SkyLayer
@onready var foreground: Node2D = $World/Foreground
@onready var music: AudioStreamPlayer = $Audio/Music
@onready var boss_music: AudioStreamPlayer = $Audio/BossMusic
@onready var sfx_banish: AudioStreamPlayer = $Audio/Banish
@onready var sfx_rumble: AudioStreamPlayer = $Audio/Rumble
@onready var ledges: Array[Node2D] = [$World/LedgeLeft, $World/LedgeRight, $World/LedgeTop]

var _watcher_kills: int = 0
var _boss_phase: bool = false
var _music_db: float = 0.0
var _music_tween: Tween

var _spawn_points: Array[Vector2] = [
	Vector2(-660, -30), Vector2(-380, -30), Vector2(380, -30), Vector2(660, -30), Vector2(-120, -30), Vector2(120, -30),
]
var _duelist_spawn_points: Array[Vector2] = [Vector2(560, -40), Vector2(-560, -40)]
var _watcher_spawn_points: Array[Vector2] = [Vector2(-520, -320), Vector2(520, -320)]


func _ready() -> void:
	# 적이 찾을 수 있도록 플레이어를 그룹에 넣고, VFX/투사체 컨테이너도 그룹에 등록한다.
	player.add_to_group("player")
	add_to_group("arena")            # 개발 치트(toolkit/cheats.gd)가 보스를 부를 때 찾는다
	effects.add_to_group("fx")
	projectiles.add_to_group("projectiles")

	camera.target = player
	hud.bind(player)
	# 루프 정보가 없는 환경에서도 음악이 끊기지 않게 한 번 더 보장한다.
	music.finished.connect(music.play)
	boss_music.finished.connect(boss_music.play)
	_music_db = music.volume_db
	_spawn_wave()


func _spawn_wave() -> void:
	hud.set_tally(_watcher_kills, watchers_for_boss)
	for i in grunt_count:
		_spawn_grunt(_spawn_points[[0, 3, 1, 2][i % 4]])
	_spawn_duelist(_duelist_spawn_points[0])
	_spawn_watcher(_watcher_spawn_points[1])


func _process(_delta: float) -> void:
	var cx := camera.global_position.x
	sky_layer.position.x = cx * (1.0 - sky_parallax)
	foreground.position.x = -cx * foreground_parallax


func _pick_spawn(points: Array[Vector2]) -> Vector2:
	var far: Array[Vector2] = []
	for p in points:
		if absf(p.x - player.global_position.x) >= min_spawn_distance:
			far.append(p)
	return (far if not far.is_empty() else points).pick_random()


func _spawn_grunt(pos: Vector2) -> void:
	if grunt_scene == null:
		return
	var g := grunt_scene.instantiate() as Enemy
	g.position = pos                 # add_child 전에 위치를 정해야 등장 연출이 제자리에서 터진다
	actors.add_child(g)
	g.add_to_group("enemy")
	g.defeated.connect(_on_grunt_defeated)


func _spawn_duelist(pos: Vector2) -> void:
	if duelist_scene == null:
		return
	var d := duelist_scene.instantiate() as Enemy
	d.position = pos
	actors.add_child(d)
	d.add_to_group("enemy")
	d.defeated.connect(_on_duelist_defeated)


func _spawn_watcher(pos: Vector2) -> void:
	if watcher_scene == null:
		return
	var w := watcher_scene.instantiate() as Watcher
	w.position = pos
	w.fly_bounds = watcher_fly_bounds
	actors.add_child(w)
	w.add_to_group("enemy")
	w.defeated.connect(_on_watcher_defeated)


func _on_watcher_defeated(_e: Enemy) -> void:
	if _boss_phase:
		return
	_watcher_kills += 1
	hud.set_tally(_watcher_kills, watchers_for_boss)
	if _watcher_kills >= watchers_for_boss:
		_begin_boss()
		return
	await get_tree().create_timer(watcher_respawn_delay).timeout
	if is_instance_valid(self) and is_inside_tree() and not _boss_phase:
		_spawn_watcher(_pick_spawn(_watcher_spawn_points))


func _on_grunt_defeated(_e: Enemy) -> void:
	await get_tree().create_timer(grunt_respawn_delay).timeout
	if is_instance_valid(self) and is_inside_tree() and not _boss_phase:
		_spawn_grunt(_pick_spawn(_spawn_points))


func _on_duelist_defeated(_e: Enemy) -> void:
	await get_tree().create_timer(duelist_respawn_delay).timeout
	if is_instance_valid(self) and is_inside_tree() and not _boss_phase:
		_spawn_duelist(_pick_spawn(_duelist_spawn_points))


# ─────────────────────────── 보스전 ───────────────────────────
## 치트/디버그: 감시자 처치 수와 상관없이 보스를 바로 부른다 (적 추방은 하고, 지진 대기 없이 곧장 떨어진다).
## 이미 보스전 중이면 아무것도 하지 않고 false.
func summon_boss_now() -> bool:
	if _boss_phase:
		return false
	_begin_boss(true)
	return true


func _begin_boss(quick: bool = false) -> void:
	_boss_phase = true
	hud.set_tally(0, 0)
	# 1) 추방 — 남은 적과 바늘이 공허로 빨려 사라진다
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e != null:
			e.banish()
	for c in projectiles.get_children():
		if c is WatcherNeedle:
			c.queue_free()
	sfx_banish.play()
	GameFeel.flash(Color(0.45, 0.2, 0.8), 0.3, 0.6)
	_fade_music(music, -40.0, 1.4, true)
	if quick:
		sfx_rumble.play()
		GameFeel.shake(0.4)
		_spawn_knight(Vector2(_pick_drop_x(), -980.0))
		return
	await get_tree().create_timer(1.0, false).timeout
	if not is_inside_tree():
		return
	# 2) 지진 — 방이 흔들리고 천장에서 돌 부스러기가 떨어진다
	sfx_rumble.play()
	_spawn_rubble(Rect2(room_x.x, -760.0, room_x.y - room_x.x, 760.0 + room_floor_y), 1.8)
	for i in 18:
		GameFeel.shake(0.1 + 0.012 * i)
		await get_tree().create_timer(0.1, false).timeout
		if not is_inside_tree():
			return
	# 3) 낙하 — 플레이어 화면 안, 발판이 없는 자리로 떨어진다
	_spawn_knight(Vector2(_pick_drop_x(), -980.0))


func _pick_drop_x() -> float:
	var best := 220.0
	var best_score := INF
	for x in [-660.0, -220.0, 220.0, 660.0]:
		var score := absf(absf(x - player.global_position.x) - 380.0)
		if score < best_score:
			best_score = score
			best = x
	return best


func _spawn_knight(pos: Vector2) -> void:
	if knight_scene == null:
		return
	var k := knight_scene.instantiate() as Knight
	k.position = pos
	k.floor_y = room_floor_y
	k.room_x = room_x
	k.ceiling_y = room_ceiling_y
	actors.add_child(k)
	k.add_to_group("enemy")
	k.landed.connect(_on_knight_landed.bind(k))
	k.defeated.connect(_on_knight_defeated)


func _on_knight_landed(k: Knight) -> void:
	# 충격에 발판들도 금이 가고 부스러기가 떨어진다
	for ledge in ledges:
		if impact_scene == null:
			break
		var g := impact_scene.instantiate() as GroundImpact
		effects.add_child(g)
		g.global_position = ledge.global_position
		g.crack_ledge(220.0, room_floor_y - ledge.global_position.y)
	boss_music.volume_db = _music_db
	boss_music.play()
	if is_instance_valid(k):
		hud.show_boss(k.health)
		camera.focus = k                 # 멀리서 하는 예고 동작(돌진 준비 등)이 화면에 담기게 함께 비춘다


func _on_knight_defeated(_e: Enemy) -> void:
	hud.hide_boss()
	camera.focus = null
	_fade_music(boss_music, -40.0, 2.5, true)
	await get_tree().create_timer(4.0, false).timeout
	if not is_inside_tree():
		return
	music.volume_db = -40.0
	music.play()
	_fade_music(music, _music_db, 1.5, false)
	_boss_phase = false
	_watcher_kills = 0
	_spawn_wave()


func _spawn_rubble(area: Rect2, duration: float) -> void:
	if impact_scene == null:
		return
	var g := impact_scene.instantiate() as GroundImpact
	effects.add_child(g)
	g.position = Vector2.ZERO
	g.rain_rubble(area, duration)


func _fade_music(p: AudioStreamPlayer, to_db: float, time: float, stop_after: bool) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(p, "volume_db", to_db, time)
	if stop_after:
		_music_tween.tween_callback(p.stop)
