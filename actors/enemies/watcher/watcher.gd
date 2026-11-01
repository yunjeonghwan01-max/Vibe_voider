class_name Watcher
extends Enemy

## 감시자 — 공중을 떠다니는 원거리 적 (공허의 외눈). 플레이어 위쪽 옆에서 거리를 두고 바늘을 쏜다.
##
## 바늘: 조준(눈을 가늘게, 붉게) → 발사. 몸에 닿기 직전 아주 짧게 빛날 때만 반격으로 지울 수 있다 (WatcherNeedle 참고).
## 카유공(카운터 유도 공격) — 일정 시간마다:
##   CHARGE  2초: 금빛 불빛 입자가 점점 빠르게 몸 중앙으로 모인다. 슈퍼아머.
##   WINDOW  0.4초: 몸에 거대한 + 모양 금빛 섬광. 이 동안 is_counter_open() = true.
##           플레이어가 반격 키를 누르면(바라보는 방향 무관) 반격 성공 → Player가 on_countered()를 부르고 X자 참격으로 즉사시킨다.
##           단, 그 반격 입력이 다른 적의 반짝이는 공격에 쓰였다면 이 광선은 반격되지 않는다(Player 쪽 규칙).
##   FIRE    못 받아치면 히트스캔 광선 — 대시/반격 무적도 무시하는 확정 피격. 지형에 막힐 때만 빗나간다.
##   CHARGE/WINDOW 동안 지형이 시야(플레이어까지의 직선)를 가리면 스스로 시야가 트이는 자리로 날아간다.
## 날아다니므로 중력 대신 감속만 받고, 몸은 지형과 충돌하지 않는다(fly_bounds 안에 머문다).

enum Atk { FLOAT, AIM, CHARGE, WINDOW, RECOVER, COUNTERED }

## Body 시트 프레임 (toolkit/asset_gen/sprite_gen.gd의 _gen_watcher 순서)
enum Frame { IDLE_A, IDLE_B, AIM, SHOOT, CHARGE, HURT }

const EYE := Vector2(0.0, 0.0)          # 바늘/광선이 나가는 곳 (몸 중앙의 눈)

@export_group("Flight")
@export var hover_distance: float = 300.0     # 플레이어와 유지하는 수평 거리
@export var hover_height: float = 180.0       # 플레이어보다 이만큼 위에 떠 있는다
@export var fly_accel: float = 900.0
@export var reposition_speed: float = 560.0   # 카유공 중 시야 확보를 위해 이동하는 속도
@export var fly_bounds: Rect2 = Rect2(-740.0, -620.0, 1480.0, 520.0)   # 레벨이 스폰 때 덮어쓴다

@export_group("Needle")
@export var needle_scene: PackedScene
@export var needle_interval: float = 1.5
@export var aim_time: float = 0.35
@export var needle_range: float = 760.0

@export_group("Counter Attack")
@export var counter_first_delay: float = 4.0
@export var counter_interval: float = 8.0
@export var charge_time: float = 2.0
@export var window_time: float = 0.4
@export var recover_time: float = 0.9
@export var beam_damage: int = 35
@export var beam_knockback: float = 520.0
@export var beam_range: float = 2400.0
@export var beam_scene: PackedScene

@onready var tell: CounterTell = $Tell
@onready var sfx_needle: AudioStreamPlayer2D = $Audio/Needle
@onready var sfx_charge: AudioStreamPlayer2D = $Audio/Charge
@onready var sfx_cue: AudioStreamPlayer2D = $Audio/Cue
@onready var sfx_beam: AudioStreamPlayer2D = $Audio/Beam

var _atk: int = Atk.FLOAT
var _atk_timer: float = 0.0
var _needle_cd: float = 1.2
var _counter_cd: float = 0.0
var _shoot_anim: float = 0.0
var _repos_target: Vector2 = Vector2.ZERO
var _has_repos: bool = false
var _body_base_y: float = 0.0


func _on_ready() -> void:
	add_to_group("counter_threat")
	_counter_cd = counter_first_delay
	_needle_cd = randf_range(1.0, 1.6)
	_body_base_y = body.position.y
	health.died.connect(_on_watcher_died)


# ─────────────────────────── 비행 (중력 대신 감속) ───────────────────────────
func _apply_gravity(delta: float) -> void:
	if state == State.ACTIVE:
		return                           # 활동 중에는 AI가 속도를 직접 정한다
	velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)


func _enemy_ai(delta: float) -> void:
	_needle_cd = maxf(_needle_cd - delta, 0.0)
	_counter_cd = maxf(_counter_cd - delta, 0.0)
	_shoot_anim = maxf(_shoot_anim - delta, 0.0)
	var t := get_target()
	if t == null:
		velocity = velocity.move_toward(Vector2.ZERO, fly_accel * delta)
		return

	match _atk:
		Atk.FLOAT:
			_hover(delta, move_speed)
			if _counter_cd <= 0.0:
				_begin_charge()
			elif _needle_cd <= 0.0 and distance_to_target() <= needle_range and _has_los(global_position):
				_atk = Atk.AIM
				_atk_timer = aim_time
				_flash_col = Color(1.0, 0.45, 0.35)
				_flash_amount = 0.6
		Atk.AIM:
			_hover(delta, move_speed * 0.35)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_fire_needle()
				_atk = Atk.FLOAT
				_needle_cd = needle_interval * randf_range(0.85, 1.25)
		Atk.CHARGE:
			_hold_with_sight(delta, reposition_speed)
			_atk_timer -= delta
			tell.progress = clampf(1.0 - _atk_timer / charge_time, 0.0, 1.0)
			# 몸도 점점 금빛으로 달아오른다
			_flash_col = GLINT_COLOR
			_flash_amount = maxf(_flash_amount, tell.progress * 0.45)
			if _atk_timer <= 0.0:
				_begin_window()
		Atk.WINDOW:
			_hold_with_sight(delta, reposition_speed * 1.6)
			tell.aim_point = t.global_position
			_flash_col = GLINT_COLOR
			_flash_amount = 0.75 + 0.25 * sin(_anim_t * 50.0)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_fire_beam()
		Atk.RECOVER:
			_hover(delta, move_speed * 0.6)
			_atk_timer -= delta
			if _atk_timer <= 0.0:
				_atk = Atk.FLOAT
				_counter_cd = counter_interval * randf_range(0.9, 1.15)
				_needle_cd = maxf(_needle_cd, 0.6)
		Atk.COUNTERED:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)


## 플레이어의 위쪽 옆 자리로 떠간다. 지금 있는 쪽을 유지하되, 벽에 막히면 반대쪽으로 넘어간다.
func _hover(delta: float, speed: float) -> void:
	var t := get_target()
	facing = dir_to_target()
	var side := signf(global_position.x - t.global_position.x)
	if side == 0.0:
		side = 1.0
	var desired := t.global_position + Vector2(side * hover_distance, -hover_height)
	if desired.x < fly_bounds.position.x or desired.x > fly_bounds.end.x:
		desired.x = t.global_position.x - side * hover_distance
	desired = _clamp_to_bounds(desired)
	desired.y += sin(_anim_t * 2.1) * 16.0       # 둥실거림
	var to := desired - global_position
	var want := to.normalized() * minf(speed, to.length() * 3.0)
	velocity = velocity.move_toward(want, fly_accel * delta)


## 카유공 중: 시야가 트여 있으면 제자리에서 멈춰 버티고, 막히면 시야가 트이는 가장 가까운 자리로 빠르게 옮긴다.
func _hold_with_sight(delta: float, speed: float) -> void:
	facing = dir_to_target()
	if _has_los(global_position):
		_has_repos = false
		velocity = velocity.move_toward(Vector2.ZERO, fly_accel * 2.0 * delta)
		return
	if not _has_repos or not _has_los(_repos_target):
		_repos_target = _find_sight_spot()
		_has_repos = true
	var to := _repos_target - global_position
	var want := to.normalized() * minf(speed, to.length() * 6.0)
	velocity = velocity.move_toward(want, fly_accel * 4.0 * delta)


func _find_sight_spot() -> Vector2:
	var tp := get_target().global_position
	var best := global_position
	var best_d := INF
	for side in [1.0, -1.0]:
		for off in [Vector2(300, -180), Vector2(220, -260), Vector2(380, -110), Vector2(140, -320), Vector2(0, -300)]:
			var c := _clamp_to_bounds(tp + Vector2(off.x * side, off.y))
			if not _has_los(c):
				continue
			var d := c.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = c
	return best


func _clamp_to_bounds(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, fly_bounds.position.x, fly_bounds.end.x),
			clampf(p.y, fly_bounds.position.y, fly_bounds.end.y))


## from에서 플레이어 중심까지 지형(world)이 가리지 않는가. 한쪽 발판도 가리는 것으로 본다.
func _has_los(from: Vector2) -> bool:
	var t := get_target()
	if t == null:
		return false
	var q := PhysicsRayQueryParameters2D.create(from, t.global_position, CollisionLayers.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


# ─────────────────────────── 바늘 ───────────────────────────
func _fire_needle() -> void:
	if needle_scene == null:
		return
	var t := get_target()
	var from := global_position + EYE
	var n := needle_scene.instantiate() as WatcherNeedle
	n.source = self
	n.direction = (t.global_position - from).normalized()
	n.target = t
	_projectile_parent().add_child(n)
	n.global_position = from + n.direction * 18.0
	_shoot_anim = 0.15
	visual.scale = Vector2(0.85 * signf(facing), 1.15)
	_sfx(sfx_needle, 0.08)


func _projectile_parent() -> Node:
	var c := get_tree().get_first_node_in_group("projectiles")
	return c if c else get_parent()


# ─────────────────────────── 카유공 ───────────────────────────
func _begin_charge() -> void:
	_atk = Atk.CHARGE
	_atk_timer = charge_time
	_has_repos = false
	tell.progress = 0.0
	tell.mode = CounterTell.Mode.CHARGE
	_sfx(sfx_charge, 0.0)


func _begin_window() -> void:
	_atk = Atk.WINDOW
	_atk_timer = window_time
	tell.mode = CounterTell.Mode.WINDOW
	tell.aim_point = get_target().global_position
	visual.scale = Vector2(1.35 * signf(facing), 1.35)
	_flash_col = Color.WHITE
	_flash_amount = 1.0
	_sfx(sfx_cue, 0.0)
	GameFeel.shake(0.15)


func is_counter_open() -> bool:
	return _atk == Atk.WINDOW and state == State.ACTIVE


func _has_armor() -> bool:
	return _atk == Atk.CHARGE or _atk == Atk.WINDOW


## 받아치지 못했다 — 확정 히트스캔 광선.
func _fire_beam() -> void:
	tell.mode = CounterTell.Mode.OFF
	_atk = Atk.RECOVER
	_atk_timer = recover_time
	var t := get_target()
	var from := global_position + EYE
	var dir := (t.global_position - from).normalized()
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * beam_range,
			CollisionLayers.WORLD | CollisionLayers.PLAYER_HURTBOX)
	q.collide_with_areas = true
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var end := from + dir * beam_range
	var hurt: HurtboxComponent = null
	if not hit.is_empty():
		end = hit.position
		hurt = hit.collider as HurtboxComponent

	_sfx(sfx_beam, 0.0)
	velocity = -dir * 260.0                      # 쏘는 반동
	visual.scale = Vector2(0.7 * signf(facing), 1.3)
	_spawn_beam(from, end, hurt != null)
	if hurt == null:
		GameFeel.shake(0.4)
		return
	# 확정 피격: 대시 무적이나 다른 적을 반격하는 중의 무적도 뚫는다.
	hurt.invincible = false
	var kb := Vector2(signf(dir.x) * beam_knockback, -280.0)
	if hurt.receive_hit(beam_damage, self, kb):
		_beam_impact(end)


func _spawn_beam(from: Vector2, to: Vector2, hit: bool) -> void:
	if beam_scene == null:
		return
	var b := beam_scene.instantiate() as WatcherBeam
	_fx_parent().add_child(b)
	b.global_position = from
	b.setup(to, hit)


## 광선 명중 — 화면이 하얗게 타고 긴 정지 + 큰 흔들림 + 명중점 대폭발.
func _beam_impact(pos: Vector2) -> void:
	GameFeel.flash(Color(1.0, 0.92, 0.7), 0.6, 0.35)
	GameFeel.hit_stop(0.2)
	GameFeel.shake(1.0)
	if spark_scene == null:
		return
	for spec in [[Color(1.0, 0.9, 0.55, 1.0), 26, 130.0, 0.4], [Color(1.0, 0.5, 0.3, 1.0), 16, 80.0, 0.3],
			[Color(1.0, 1.0, 1.0, 1.0), 10, 170.0, 0.22]]:
		var s := spark_scene.instantiate() as SparkEffect
		_fx_parent().add_child(s)
		s.global_position = pos
		s.burst(spec[0], spec[1], 360.0, 0.0, spec[2], spec[3])
		s.with_ring(spec[0], float(spec[2]) * 1.4)


## Player가 WINDOW 안에 반격했다 — 공격 취소, 결정타(X자 참격)를 기다리며 굳는다.
func on_countered(_from_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	_atk = Atk.COUNTERED
	tell.mode = CounterTell.Mode.OFF
	sfx_charge.stop()
	state = State.STAGGER
	_state_timer = 3.0
	velocity = Vector2.ZERO
	_flash_col = Color(0.75, 0.45, 1.0)
	_flash_amount = 1.0
	visual.scale = Vector2(1.3 * signf(facing), 0.75)


func _on_stagger_end() -> void:
	_atk = Atk.RECOVER
	_atk_timer = recover_time


func _on_hurt(_source: Node) -> void:
	# 조준 중에 맞으면 바늘이 취소된다 (카유공은 슈퍼아머라 끊기지 않는다)
	if _atk == Atk.AIM:
		_atk = Atk.FLOAT
		_needle_cd = needle_interval * 0.6


func _on_watcher_died() -> void:
	tell.mode = CounterTell.Mode.OFF
	sfx_charge.stop()


func _on_banished() -> void:
	_on_watcher_died()


# ─────────────────────────── 외형 ───────────────────────────
func _animate(_delta: float) -> void:
	body.position.y = _body_base_y + sin(_anim_t * 5.0) * 2.0
	match state:
		State.HITSTUN, State.STAGGER:
			body.frame = Frame.HURT
			return
		State.SPAWNING:
			body.frame = Frame.IDLE_A
			return
	match _atk:
		Atk.AIM:
			body.frame = Frame.AIM
		Atk.CHARGE, Atk.WINDOW:
			body.frame = Frame.CHARGE
		_:
			if _shoot_anim > 0.0:
				body.frame = Frame.SHOOT
			else:
				body.frame = Frame.IDLE_A + int(_anim_t * 7.0) % 2
