class_name Prince
extends Enemy

## 보스 — 제3부대를 이끄는 왕국 제3왕자. 순보와 돌진으로 파고드는 냉병기 검사 (Phase1 보스 구역).
## 진행: 1페이즈(패턴 1~3 반복) → 체력 phase2_hp → 패턴 4(1회) → 2페이즈(패턴 1~3 빨라짐) → 체력 final_hp → 패턴 5 → 승패.
## 체력은 PrinceHealth.floor_hp에서 멈추므로 큰 피해로 패턴 4·5를 건너뛸 수 없다. 패턴 4·5 동안은 피해 무효.
##
## 패턴 1 근접 검격 (가장 자주): 순보 접근 → 양손으로 치켜듦(RAISE) → FLASH(MCI) → 내려베기.
##   반격당하면 on_parried()에서 후속 여부를 굴린다. 기존 일반 경직이나 CC/CCI 랠리가 아니다:
##   · 후속 있음: 튕겨 나가며 버티는 자세(RECOIL, 초록 번쩍임) → 다시 치켜듦(RERAISE) → 새 FLASH → 새 내려베기.
##     RECOIL + RERAISE가 연쇄 예약 창(0.2초)보다 훨씬 길어서 플레이어가 새 FLASH를 보고 따로 눌러야 한다.
##   · 후속 없음: 곧바로 무릎이 꺾이며(BROKEN) 청록빛 경직 — 분명히 끝났고 지금이 공격 기회다.
## 패턴 2 횡단 돌진: 맵 끝으로 순간이동 → 웅크림 → 반대편 끝까지 가속 돌진 + 뒤에 남는 아우라(PrinceAura, 약한 피해).
##   왕자가 아직 멀리 있을 때만 짧은 FLASH가 켜지고(rush_flash_far ~ rush_flash_near) 그때만 방향 무관 반격 가능 → 돌진 중단 + 기절.
##   점프로도 피한다. 대시는 무적이 끝난 뒤 아직 뜨거운 아우라에 맞을 뿐, 대시 무적을 뚫는 규칙은 없다.
## 패턴 3 원거리 검격: 검을 바닥으로 그어 지면을 달리는 가속 투사체 PrinceWave 한 발 (PRCI, 기존 튕겨내기 경로).
## 패턴 4 천지분쇄 일격 (1회): 맵 중앙 공중에서 3초 충전 → 세 번의 독립된 전역 충격. 각 충격마다 FLASH 동안 반격 키를 누르면
##   그 충격만 막는다 (Player._try_guard — 궁극기·연쇄·패기·경직 등 일반 반격 보상과 분리된 별도 경로).
##   실패한 회차는 그 회차 피해만 받고 다음 회차는 그대로 막을 수 있다. 충격은 플레이어의 피격 무적을 뚫는다
##   (앞 회차에 맞았다고 뒤 회차가 사라지면 세 번의 독립 위협이 아니므로).
## 패턴 5 마지막 일격: 4초 충전 → 플레이어 머리 위로 순간이동 → 느린 낙하. 첫 맞부딪힘은 항상 성립하고(눌러도 안 눌러도),
##   이어지는 힘겨루기(PrinceClash)의 게이지가 승패를 가른다. 그동안 Player는 이벤트 잠금이라 입력이 반격으로 나가지 않는다.
##
## 플레이어가 없거나 쓰러져 있으면 새 공격을 시작하지 않는다. 방의 바닥·좌우 끝은 레벨이 스폰 때 넣어 준다.

enum Atk {
	IDLE, SHUNPO, RAISE, FLASH, STRIKE, RECOVER, RECOIL, RERAISE,
	RUSH_BLINK, RUSH_CROUCH, RUSH, RUSH_END,
	WAVE_WINDUP, WAVE_CAST,
	QUAKE_BLINK, QUAKE_CHARGE, QUAKE_FLASH1, QUAKE_FALL, QUAKE_GAP2, QUAKE_FLASH2, QUAKE_GAP3, QUAKE_FLASH3, QUAKE_END,
	FINALE_BLINK, FINALE_CHARGE, FINALE_DROP, FINALE_FALL, FINALE_CLASH, FINALE_END,
}
enum Pick { MELEE, RUSH, WAVE }

## Body 시트 프레임 (toolkit/asset_gen/sprite_gen.gd의 _gen_prince 순서)
enum Frame { IDLE_A, IDLE_B, DASH, CROUCH, RUSH, RAISE, STRIKE, LOW, RECOIL, BROKEN, PLUNGE, IMPALE, ROAR }

## 프레임별 손(장검 회전축) 위치 — 시트의 "hand"를 로컬 좌표로 옮긴 값 (오른쪽을 볼 때).
const HAND := [
	Vector2(14, -6), Vector2(14, -4), Vector2(-16, -2), Vector2(-14, 8), Vector2(-22, 4), Vector2(-2, -56), Vector2(26, -12),
	Vector2(24, 14), Vector2(-6, -32), Vector2(18, 20), Vector2(0, -16), Vector2(18, 10), Vector2(22, -44),
]
const SWORD_REACH := 80.0
const FOOT := 30.0              # 루트(몸 중심) → 발바닥
const IDLE_DEG := 65.0
const TRAIL_DEG := 165.0        # 순보·돌진: 검을 뒤로 끈다
const RAISED_DEG := -115.0      # 치켜듦: 칼끝이 머리 위 뒤쪽
const STRIKE_END_DEG := 62.0
const LOW_DEG := 34.0           # 바닥을 그은 끝
const RECOIL_DEG := -60.0
const DOWN_DEG := 90.0          # 칼끝이 곧장 아래
const GREEN := Color(0.45, 1.0, 0.58, 1.0)
const SHUNPO_RETRIES := 2
const QUAKE_STATES := [Atk.QUAKE_BLINK, Atk.QUAKE_CHARGE, Atk.QUAKE_FLASH1, Atk.QUAKE_FALL, Atk.QUAKE_GAP2,
	Atk.QUAKE_FLASH2, Atk.QUAKE_GAP3, Atk.QUAKE_FLASH3, Atk.QUAKE_END]

@export_group("Phases")
@export var phase2_hp: int = 660              # 이 체력에서 패턴 4 → 2페이즈
@export var final_hp: int = 60                # 이 체력에서 패턴 5
@export var phase2_speed: float = 1.2         # 2페이즈: 패턴 1~3의 예고·후딜이 이 배율만큼 빨라진다
@export var phase2_flash_scale: float = 0.85  # 2페이즈: 반격 창이 이 배율로 짧아진다
@export var think_time: Vector2 = Vector2(0.45, 0.8)
@export_range(0, 3) var debug_force_pattern: int = 0   # 테스트: 0 = 평소, 1·2·3 = 그 패턴만 쓴다

@export_group("Melee")
@export var shunpo_speed: float = 1900.0
@export var melee_stop: float = 96.0          # 순보가 플레이어에게서 멈추는 거리
@export var attack_range: float = 150.0       # 이 안이면 순보 없이 바로 공격
@export var raise_time: float = 0.42          # 양손으로 치켜드는 예고 (이때 반격하면 헛반격)
@export var strike_time: float = 0.14
@export var strike_lunge: float = 300.0
@export var recover_time: float = 0.55
@export var melee_damage: Array[int] = [14, 16, 20]
@export var melee_knockback: float = 340.0

@export_group("Follow-up")
@export var followup_chance_2: float = 0.55   # 1타 반격 후 2번째 카운터를 요구할 확률
@export var followup_chance_3: float = 0.3    # 2타 반격 후 3번째 카운터를 요구할 확률
@export_range(-1, 2) var debug_followups: int = -1   # 테스트: -1 = 확률대로, 0·1·2 = 후속 횟수 고정
@export var recoil_time: float = 0.42         # 튕겨 나가며 버티는 시간
@export var recoil_push: float = 300.0
@export var reraise_time: float = 0.4         # 다시 치켜드는 예고 (반격 불가)
@export var melee_stun: Array[float] = [1.3, 1.5, 1.9]   # 1·2·3타째 반격으로 끝났을 때의 공격 기회

@export_group("Rush")
@export var rush_edge_margin: float = 50.0    # 맵 끝에서 이만큼 안쪽에 선다
@export var rush_blink_time: float = 0.22     # 사라졌다 맵 끝에 나타나기까지
@export var rush_prep_time: float = 0.85      # 몸을 낮춘 준비 동작
@export var rush_start_speed: float = 260.0
@export var rush_accel: float = 2600.0
@export var rush_max_speed: float = 1700.0
@export var rush_recover: float = 0.75
@export var rush_damage: int = 18
@export var rush_knockback: float = 420.0
@export var rush_flash_far: float = 860.0     # FLASH는 왕자와의 거리가 이 안일 때만 켜진다
@export var rush_flash_near: float = 150.0    # 이보다 가까워지면 FLASH는 꺼진다 (근접 FLASH가 아니다)
@export var rush_flash_lead: float = 0.62     # 지금 속도로 이 시간 뒤면 닿을 거리에서 켜진다 (어디 서 있든 같은 읽기)
@export var rush_flash_time: float = 0.26
@export var rush_stun: float = 2.2
@export var rush_counter_damage: int = 0      # 돌진 반격 X자 피해 (0 = 기절만)
@export var aura_damage: int = 8
@export var aura_knockback: float = 260.0
@export var aura_life: float = 0.34           # 지나간 자리가 뜨거운 시간 (대시 무적 0.3초보다 길고, 점프 체공으로는 넘길 수 있다)
@export var aura_height: float = 36.0         # 아우라 판정 높이

@export_group("Wave")
@export var wave_min_distance: float = 260.0  # 이보다 가까우면 검격 대신 근접을 쓴다
@export var wave_windup: float = 0.6
@export var wave_cast_time: float = 0.16
@export var wave_recover: float = 0.6
@export var wave_height: float = 30.0         # 투사체 중심의 지면 위 높이
@export var wave_start_speed: float = 260.0
@export var wave_accel: float = 1400.0
@export var wave_max_speed: float = 1150.0
@export var wave_damage: int = 12
@export var wave_knockback: float = 300.0
@export var wave_deflect_range: float = 170.0
@export var wave_lifetime: float = 3.5

@export_group("Quake")
@export var quake_hover_y: float = -340.0     # 충전하는 공중 높이
@export var quake_blink_time: float = 0.4
@export var quake_charge_time: float = 3.0
@export var quake_flash1_time: float = 0.42   # ① 낙하 직전 몸의 FLASH
@export var quake_fall_time: float = 0.1      # 매우 빠른 낙하 (①의 입력은 착지까지 유효)
@export var quake_gap2: float = 0.6           # 검이 박힌 뒤 ② 신호까지
@export var quake_flash2_time: float = 0.46
@export var quake_gap3: float = 0.75          # 빛이 사라진 뒤 ③ 신호까지
@export var quake_flash3_time: float = 0.52
@export var quake_end_time: float = 1.1
@export var quake_damage: Array[int] = [18, 10, 30]    # ① 중간 / ② 가장 작음 / ③ 가장 강함
@export var quake_knockback: float = 300.0
@export var quake_pierce: bool = true         # 충격이 무적을 뚫는다 (false면 앞 회차 피격 무적에 뒤 회차가 막힌다)

@export_group("Finale")
@export var finale_blink_time: float = 0.45
@export var finale_charge_time: float = 4.0
@export var finale_drop_height: float = 300.0 # 플레이어 머리 위 이 높이에 나타난다
@export var finale_drop_delay: float = 0.3
@export var finale_fall_time: float = 1.3     # 느린 낙하 (이 동안 누르면 곧바로 맞부딪힌다, 안 눌러도 끝에 자동 성립)
@export var clash_gauge: float = 0.5          # 힘겨루기 시작 게이지 (0~1)
@export var clash_drain: float = 0.16         # 초당 감소
@export var clash_gain: float = 0.085         # 연타 한 번당 증가

@export_group("Scenes")
@export var slash_scene: PackedScene
@export var afterimage_scene: PackedScene
@export var impact_scene: PackedScene
@export var wave_scene: PackedScene
@export var aura_scene: PackedScene
@export var quake_scene: PackedScene
@export var clash_scene: PackedScene

## 레벨이 스폰 때 채운다.
var room_x: Vector2 = Vector2(-680.0, 680.0)  # 몸이 설 수 있는 좌우 끝
var floor_y: float = 0.0

@onready var sword: Sprite2D = $Visual/Sword
@onready var tell: CounterTell = $Tell
@onready var rush_hitbox: HitboxComponent = $Combat/RushHitbox
@onready var prince_health: PrinceHealth = $Combat/Health
@onready var _atk_shape_pos: Vector2 = attack_hitbox.position
@onready var _rush_shape_pos: Vector2 = rush_hitbox.position
@onready var sfx_shunpo: AudioStreamPlayer2D = $Audio/Shunpo
@onready var sfx_swing: AudioStreamPlayer2D = $Audio/Swing
@onready var sfx_clang: AudioStreamPlayer2D = $Audio/Clang
@onready var sfx_blink: AudioStreamPlayer2D = $Audio/Blink
@onready var sfx_rush: AudioStreamPlayer2D = $Audio/Rush
@onready var sfx_charge: AudioStreamPlayer2D = $Audio/Charge
@onready var sfx_cue: AudioStreamPlayer2D = $Audio/Cue
@onready var sfx_slam: AudioStreamPlayer2D = $Audio/Slam
@onready var sfx_rumble: AudioStreamPlayer2D = $Audio/Rumble
@onready var sfx_roar: AudioStreamPlayer2D = $Audio/Roar

var phase: int = 1
var _atk: int = Atk.IDLE
var _atk_timer: float = 0.0
var _atk_time: float = 1.0          # 지금 단계의 전체 길이 (애니메이션 진행률)
var _float: bool = false
var _sword_deg: float = IDLE_DEG
var _bag: Array[int] = []
var _base_glint: float = 0.0
var _base_rush_flash: float = 0.0
var _aura_amt: float = 0.0
var _ghost_t: float = 0.0

var _melee_step: int = 0            # 이번 연속 공격의 몇 번째 타인가 (0부터)
var _shunpo_left: float = 0.0
var _shunpo_dir: float = 1.0
var _shunpo_retry: int = 0
var _shunpo_followup: bool = false  # 이 순보 뒤에는 RAISE가 아니라 RERAISE로 이어진다

var _rush_dir: float = 1.0
var _rush_speed: float = 0.0
var _rush_end_x: float = 0.0
var _rush_window: float = 0.0
var _rush_flash_used: bool = false
var _aura: PrinceAura = null

var _quake_done: bool = false
var _quake_fx: PrinceQuake = null
var _guard_open: bool = false       # 지금 방어 입력을 받는 중 (패턴 4 각 회차 FLASH, 패턴 5 낙하)
var _guarded: bool = false          # 이번 회차를 막았다
var _fall_from_y: float = 0.0

var _finale_started: bool = false
var _finale_won: bool = false
var _clash: PrinceClash = null


func _on_ready() -> void:
	_base_glint = glint_duration
	_base_rush_flash = rush_flash_time
	prince_health.floor_hp = phase2_hp
	health.damaged.connect(_on_damaged)
	attack_hitbox.damage = melee_damage[0]
	rush_hitbox.source = self
	rush_hitbox.monitoring = false
	rush_hitbox.hit_landed.connect(_on_rush_landed)
	tell.mode = CounterTell.Mode.OFF
	_atk_timer = randf_range(think_time.x, think_time.y)


# ─────────────────────────── 물리 ───────────────────────────
func _apply_gravity(delta: float) -> void:
	if _float and state == State.ACTIVE:
		return
	super._apply_gravity(delta)


func _set_float(on: bool) -> void:
	_float = on
	collision_mask = 0 if on else CollisionLayers.WORLD


func _foot_y() -> float:
	return floor_y - FOOT


func _cast() -> float:
	return phase2_speed if phase == 2 else 1.0


func _has_armor() -> bool:
	return true                          # 평타로는 끊기지 않는다 — 반격으로만 무너진다


func _target_down() -> bool:
	var p := get_target() as Player
	return p == null or p.action == Player.Action.DEAD


func _go(atk: int, time: float) -> void:
	_atk = atk
	_atk_timer = time
	_atk_time = maxf(time, 0.001)


func _to_idle(think: float = -1.0) -> void:
	_melee_step = 0
	_go(Atk.IDLE, randf_range(think_time.x, think_time.y) / _cast() if think < 0.0 else think)


func _brake(delta: float, amount: float = 3000.0) -> void:
	velocity.x = move_toward(velocity.x, 0.0, amount * delta)


# ─────────────────────────── 상태 흐름 ───────────────────────────
func _enemy_ai(delta: float) -> void:
	_atk_timer -= delta
	match _atk:
		Atk.IDLE:
			_brake(delta)
			facing = dir_to_target()
			if _atk_timer <= 0.0 and not _target_down() and is_on_floor():
				_decide()
		Atk.SHUNPO:
			_do_shunpo(delta)
		Atk.RAISE, Atk.RERAISE:
			_brake(delta)
			if _atk_timer <= 0.0:
				_begin_flash()
		Atk.FLASH:
			_brake(delta)
			if _atk_timer <= 0.0:
				_begin_strike()
		Atk.STRIKE:
			_brake(delta, 1500.0)
			if _atk_timer <= 0.0:
				attack_hitbox.monitoring = false
				_go(Atk.RECOVER, recover_time / _cast())
		Atk.RECOVER:
			_brake(delta)
			if _atk_timer <= 0.0:
				_to_idle()
		Atk.RECOIL:
			_brake(delta, 1400.0)
			if _atk_timer <= 0.0:
				_after_recoil()
		Atk.RUSH_BLINK:
			if _atk_timer <= 0.0:
				_appear_at_rush_edge()
		Atk.RUSH_CROUCH:
			_brake(delta)
			if _atk_timer <= 0.0:
				_begin_rush_run()
		Atk.RUSH:
			_do_rush(delta)
		Atk.RUSH_END:
			_brake(delta, 2200.0)
			if _atk_timer <= 0.0:
				_to_idle()
		Atk.WAVE_WINDUP:
			_brake(delta)
			if _atk_timer <= 0.0:
				_fire_wave()
		Atk.WAVE_CAST:
			if _atk_timer <= 0.0:
				_go(Atk.RECOVER, wave_recover / _cast())
		Atk.QUAKE_BLINK, Atk.QUAKE_CHARGE, Atk.QUAKE_FLASH1, Atk.QUAKE_FALL, Atk.QUAKE_GAP2, Atk.QUAKE_FLASH2, \
				Atk.QUAKE_GAP3, Atk.QUAKE_FLASH3, Atk.QUAKE_END:
			_do_quake()
		Atk.FINALE_BLINK, Atk.FINALE_CHARGE, Atk.FINALE_DROP, Atk.FINALE_FALL:
			_do_finale(delta)
		Atk.FINALE_CLASH, Atk.FINALE_END:
			velocity = Vector2.ZERO


func _decide() -> void:
	var pick := _next_pick()
	if pick == Pick.WAVE and absf(get_target().global_position.x - global_position.x) < wave_min_distance:
		pick = Pick.MELEE
	match pick:
		Pick.RUSH:
			_begin_rush()
		Pick.WAVE:
			_begin_wave()
		_:
			_begin_melee()


## 패턴 1을 가장 자주 쓴다: 섞인 주머니에서 근접 3 : 돌진 1 : 검격 1.
func _next_pick() -> int:
	if debug_force_pattern > 0:
		return [Pick.MELEE, Pick.RUSH, Pick.WAVE][debug_force_pattern - 1]
	if _bag.is_empty():
		_bag = [Pick.MELEE, Pick.MELEE, Pick.MELEE, Pick.RUSH, Pick.WAVE]
		_bag.shuffle()
	return _bag.pop_back()


## 하던 공격의 판정·예고를 모두 끈다 (경직·패턴 4/5 진입·추방).
func _end_all_attacks() -> void:
	end_glint()
	attack_hitbox.monitoring = false
	rush_hitbox.monitoring = false
	_rush_window = 0.0
	_guard_open = false
	_guarded = false
	tell.mode = CounterTell.Mode.OFF
	_release_aura(false)
	visual.modulate.a = 1.0


# ─────────────────────────── 패턴 1: 근접 검격 ───────────────────────────
func _begin_melee() -> void:
	_melee_step = 0
	_shunpo_followup = false
	_shunpo_retry = 0
	_approach_or_raise()


func _approach_or_raise() -> void:
	var t := get_target()
	var dx := t.global_position.x - global_position.x
	facing = dir_to_target()
	if absf(dx) <= attack_range or _shunpo_retry > SHUNPO_RETRIES:
		_begin_raise()
		return
	_shunpo_retry += 1
	var goal := clampf(t.global_position.x - signf(dx) * melee_stop, room_x.x, room_x.y)
	_shunpo_dir = signf(goal - global_position.x)
	_shunpo_left = absf(goal - global_position.x)
	_go(Atk.SHUNPO, _shunpo_left / shunpo_speed + 0.2)
	_ghost_t = 0.0
	visual.scale = Vector2(1.3 * signf(facing), 0.8)
	_sfx(sfx_shunpo, 0.08)
	_burst(GREEN, 6, 34.0, 0.2, false)


func _do_shunpo(delta: float) -> void:
	# 마지막 프레임은 남은 거리만큼만 — 목표를 지나치지 않는다. 벽에 닿으면 그 자리에서 멈춘다.
	var spd := minf(shunpo_speed, _shunpo_left / maxf(delta, 0.0001))
	velocity.x = _shunpo_dir * spd
	_shunpo_left -= spd * delta
	_ghost(0.03)
	if _shunpo_left <= 0.5 or is_on_wall() or _atk_timer <= 0.0:
		velocity.x = 0.0
		_approach_or_raise()


func _begin_raise() -> void:
	facing = dir_to_target()                  # 방향은 여기서 고정 — 치켜든 뒤 등 뒤로 돌아가면 헛벤다
	_place_attack_hitbox()
	if _shunpo_followup:
		_go(Atk.RERAISE, reraise_time / _cast())
		_shunpo_followup = false
		_followup_tell()
		return
	_go(Atk.RAISE, raise_time / _cast())
	visual.scale = Vector2(0.86 * signf(facing), 1.16)
	_sfx(sfx_clang, 0.05)


func _place_attack_hitbox() -> void:
	attack_hitbox.position = Vector2(signf(facing) * absf(_atk_shape_pos.x), _atk_shape_pos.y)


func _raised_tip() -> Vector2:
	return HAND[Frame.RAISE] + Vector2.from_angle(deg_to_rad(RAISED_DEG)) * SWORD_REACH


func _begin_flash() -> void:
	_go(Atk.FLASH, glint_duration)
	begin_glint(_raised_tip())


func _begin_strike() -> void:
	end_glint()
	_go(Atk.STRIKE, strike_time)
	visual.scale = Vector2(1.3 * signf(facing), 0.82)
	if is_on_floor():
		velocity.x = facing * strike_lunge
	attack_hitbox.reset_hits()
	_place_attack_hitbox()
	attack_hitbox.damage = melee_damage[mini(_melee_step, melee_damage.size() - 1)]
	attack_hitbox.knockback_force = melee_knockback
	attack_hitbox.knockback_direction = Vector2(facing, -0.3).normalized()
	attack_hitbox.monitoring = true
	GameFeel.shake(0.25)
	_sfx(sfx_swing, 0.06)
	_spawn_slash(Vector2(signf(facing) * 40.0, -18.0), 30.0, 1.5)


## 패턴 1의 반격만 왕자 전용으로 처리한다. FLASH가 아닌 순간에는 일어나지 않는다 (일반 적용 올려베기에도 휘말리지 않는다).
func on_parried(from_pos: Vector2) -> void:
	if state != State.ACTIVE or _atk != Atk.FLASH or not _glinting:
		return
	if _rolls_followup():
		_begin_recoil(from_pos)
		return
	var step := mini(_melee_step, melee_stun.size() - 1)
	_melee_step = 0
	super.on_parried(from_pos)
	_state_timer = melee_stun[step]
	_sfx(sfx_clang, 0.04)


## 이번 반격 뒤에 다음 타가 이어지는가. 첫 타 뒤는 followup_chance_2, 둘째 타 뒤는 followup_chance_3, 셋째 타 뒤는 끝.
func _rolls_followup() -> bool:
	if debug_followups >= 0:
		return _melee_step < debug_followups
	match _melee_step:
		0:
			return randf() < followup_chance_2
		1:
			return randf() < followup_chance_3
	return false


func _begin_recoil(from_pos: Vector2) -> void:
	end_glint()
	attack_hitbox.monitoring = false
	_melee_step += 1
	_go(Atk.RECOIL, recoil_time / _cast())
	var away := signf(global_position.x - from_pos.x)
	velocity.x = (away if away != 0.0 else -facing) * recoil_push
	visual.scale = Vector2(0.8 * signf(facing), 1.22)
	_flash_col = GREEN
	_flash_amount = 1.0
	_sfx(sfx_clang, 0.04)
	_burst(GREEN, 10, 54.0, 0.25, false)


func _after_recoil() -> void:
	_shunpo_followup = true                  # 멀어졌으면 순보로 다시 붙은 뒤 RERAISE로 이어진다 (_begin_raise)
	_shunpo_retry = 0
	_approach_or_raise()


## "다음 타가 온다" 신호 — 몸에 초록빛이 번쩍이고 장검을 크게 돌려 치켜든다. 이후 새 FLASH.
func _followup_tell() -> void:
	visual.scale = Vector2(0.84 * signf(facing), 1.2)
	_flash_col = GREEN
	_flash_amount = 0.9
	_sfx(sfx_rush, 0.04)
	_burst(GREEN, 14, 70.0, 0.3, true)


func _on_stagger_end() -> void:
	_to_idle(0.3 / _cast())


# ─────────────────────────── 패턴 2: 맵 끝 횡단 돌진 ───────────────────────────
func _begin_rush() -> void:
	_go(Atk.RUSH_BLINK, rush_blink_time)
	_vanish()


func _vanish() -> void:
	_sfx(sfx_blink, 0.04)
	_burst(GREEN, 14, 80.0, 0.3, true)
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.0, 0.12)


func _reappear() -> void:
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 1.0, 0.1)
	_burst(GREEN, 14, 80.0, 0.3, true)
	visual.scale = Vector2(1.25 * signf(facing), 0.8)


## 플레이어에게서 먼 쪽 끝에 나타난다 — 돌진이 맵을 가로지르고, 거리 조건의 FLASH가 항상 나올 수 있다.
func _appear_at_rush_edge() -> void:
	var left := room_x.x + rush_edge_margin
	var right := room_x.y - rush_edge_margin
	var px := get_target().global_position.x if get_target() != null else 0.0
	var start_x := left if absf(px - left) >= absf(px - right) else right
	_rush_end_x = right if start_x == left else left
	_rush_dir = signf(_rush_end_x - start_x)
	facing = _rush_dir
	global_position = Vector2(start_x, _foot_y())
	velocity = Vector2.ZERO
	_reappear()
	_go(Atk.RUSH_CROUCH, rush_prep_time / _cast())
	_sfx(sfx_rush, 0.03)


func _begin_rush_run() -> void:
	_go(Atk.RUSH, 4.0)                       # 안전장치 (벽·끝에 닿으면 그 전에 끝난다)
	_rush_speed = rush_start_speed
	_rush_flash_used = false
	_rush_window = 0.0
	rush_hitbox.position = Vector2(_rush_dir * absf(_rush_shape_pos.x), _rush_shape_pos.y)
	rush_hitbox.reset_hits()
	rush_hitbox.damage = rush_damage
	rush_hitbox.knockback_force = rush_knockback
	rush_hitbox.knockback_direction = Vector2(_rush_dir, -0.45).normalized()
	rush_hitbox.monitoring = true
	_spawn_aura()
	GameFeel.shake(0.3)
	_sfx(sfx_shunpo, 0.04)


func _spawn_aura() -> void:
	if aura_scene == null:
		return
	_aura = aura_scene.instantiate() as PrinceAura
	_aura.source = self
	_aura.damage = aura_damage
	_aura.knockback = aura_knockback
	_aura.life = aura_life
	_aura.height = aura_height
	_aura.floor_y = floor_y
	_aura.head_x = global_position.x
	_fx_parent().add_child(_aura)


## 돌진이 끝나면 아우라는 남은 시간만큼 지나간 자리에 남는다. spent면 더 맞히지 않는다.
func _release_aura(spent: bool) -> void:
	if is_instance_valid(_aura):
		_aura.release()
		if spent:
			_aura.spent = true
	_aura = null


func _on_rush_landed(_hurt: HurtboxComponent) -> void:
	if is_instance_valid(_aura):
		_aura.spent = true                   # 본체에 맞았으면 같은 돌진의 아우라로 또 맞지 않는다


func _do_rush(delta: float) -> void:
	_rush_speed = minf(_rush_speed + rush_accel * _cast() * delta, rush_max_speed)
	velocity.x = _rush_dir * _rush_speed
	_ghost(0.04)
	if is_instance_valid(_aura):
		_aura.head_x = global_position.x
	_update_rush_flash(delta)
	if (global_position.x - _rush_end_x) * _rush_dir >= -2.0 or is_on_wall() or _atk_timer <= 0.0:
		_finish_rush()


## 왕자가 아직 멀리 있는 구간에서만 켜지는 FLASH. 켜져 있는 동안만 is_counter_open()이 true다.
func _update_rush_flash(delta: float) -> void:
	var t := get_target()
	var gap := (t.global_position.x - global_position.x) * _rush_dir if t != null else -1.0
	if _rush_window > 0.0:
		_rush_window -= delta
		if _rush_window <= 0.0 or gap < rush_flash_near:
			_rush_window = 0.0
			tell.mode = CounterTell.Mode.OFF
	elif not _rush_flash_used and gap >= rush_flash_near and gap <= minf(rush_flash_far, _rush_speed * rush_flash_lead):
		_rush_flash_used = true
		_rush_window = rush_flash_time
		tell.mode = CounterTell.Mode.WINDOW
		tell.scale = Vector2.ONE * 1.1
		_sfx(sfx_cue, 0.0)


func _finish_rush() -> void:
	rush_hitbox.monitoring = false
	_rush_window = 0.0
	tell.mode = CounterTell.Mode.OFF
	_release_aura(false)
	velocity.x = _rush_dir * 120.0
	_go(Atk.RUSH_END, rush_recover / _cast())
	GameFeel.shake(0.2)


func is_counter_open() -> bool:
	return state == State.ACTIVE and _atk == Atk.RUSH and _rush_window > 0.0


func counter_strike_damage(_default_damage: int) -> int:
	return rush_counter_damage


## 돌진 FLASH를 받아쳤다 — 돌진을 즉시 멈추고 자세가 무너져 기절한다.
func on_countered(_from_pos: Vector2) -> void:
	if not is_counter_open():
		return
	rush_hitbox.monitoring = false
	_rush_window = 0.0
	tell.mode = CounterTell.Mode.OFF
	_release_aura(true)
	_melee_step = 0
	_go(Atk.IDLE, 0.0)
	state = State.STAGGER
	_state_timer = rush_stun
	velocity = Vector2(-_rush_dir * 180.0, -160.0)
	_flash_col = Color(1, 1, 1)
	_flash_amount = 1.0
	visual.scale = Vector2(1.3 * signf(facing), 0.72)
	_sfx(sfx_clang, 0.03)
	_burst(GREEN, 16, 80.0, 0.35, true)


# ─────────────────────────── 패턴 3: 원거리 검격 ───────────────────────────
func _begin_wave() -> void:
	facing = dir_to_target()
	_go(Atk.WAVE_WINDUP, wave_windup / _cast())
	visual.scale = Vector2(0.88 * signf(facing), 1.14)
	_sfx(sfx_clang, 0.05)


func _fire_wave() -> void:
	_go(Atk.WAVE_CAST, wave_cast_time)
	visual.scale = Vector2(1.3 * signf(facing), 0.78)
	GameFeel.shake(0.22)
	_sfx(sfx_swing, 0.05)
	_spawn_slash(Vector2(signf(facing) * 44.0, 12.0), 58.0, 1.3)
	if wave_scene == null:
		return
	var w := wave_scene.instantiate() as PrinceWave
	w.source = self
	w.target = get_target()
	w.direction = Vector2(signf(facing), 0.0)
	w.speed = wave_start_speed
	w.accel = wave_accel
	w.max_speed = wave_max_speed
	w.damage = wave_damage
	w.knockback = wave_knockback
	w.deflect_range = wave_deflect_range
	w.max_lifetime = wave_lifetime
	var parent := get_tree().get_first_node_in_group("projectiles")
	(parent if parent != null else _fx_parent()).add_child(w)
	w.global_position = Vector2(global_position.x + signf(facing) * 56.0, floor_y - wave_height)


# ─────────────────────────── 패턴 4: 천지분쇄 일격 ───────────────────────────
func _begin_quake() -> void:
	_end_all_attacks()
	state = State.ACTIVE
	_airborne = false
	hurtbox.invincible = true
	velocity = Vector2.ZERO
	_go(Atk.QUAKE_BLINK, quake_blink_time)
	_vanish()
	if quake_scene != null:
		_quake_fx = quake_scene.instantiate() as PrinceQuake
		_quake_fx.target = get_target()
		_quake_fx.room_x = room_x
		_quake_fx.floor_y = floor_y
		_fx_parent().add_child(_quake_fx)


func _do_quake() -> void:
	velocity = Vector2.ZERO
	match _atk:
		Atk.QUAKE_BLINK:
			if _atk_timer <= 0.0:
				_set_float(true)
				global_position = Vector2((room_x.x + room_x.y) * 0.5, quake_hover_y)
				_reappear()
				facing = dir_to_target()
				tell.mode = CounterTell.Mode.CHARGE
				tell.scale = Vector2.ONE * 1.5
				_go(Atk.QUAKE_CHARGE, quake_charge_time)
				_sfx(sfx_charge, 0.0)
				sfx_rumble.play()
		Atk.QUAKE_CHARGE:
			var k := 1.0 - clampf(_atk_timer / quake_charge_time, 0.0, 1.0)
			tell.progress = k
			tell.aim_point = global_position
			_aura_amt = k
			if _atk_timer <= 0.0:
				_open_quake_flash(Atk.QUAKE_FLASH1, quake_flash1_time + quake_fall_time, quake_flash1_time, 1.5, 260.0, 0)
		Atk.QUAKE_FLASH1:
			tell.aim_point = global_position
			_shine(GREEN)
			if _atk_timer <= 0.0:
				_fall_from_y = global_position.y
				_go(Atk.QUAKE_FALL, quake_fall_time)
				tell.mode = CounterTell.Mode.OFF
		Atk.QUAKE_FALL:
			global_position.y = lerpf(_fall_from_y, _foot_y(), 1.0 - clampf(_atk_timer / quake_fall_time, 0.0, 1.0))
			if _atk_timer <= 0.0:
				global_position.y = _foot_y()
				_set_float(false)
				_aura_amt = 0.0
				_quake_impact(0)
				_go(Atk.QUAKE_GAP2, quake_gap2)
		Atk.QUAKE_GAP2:
			if _atk_timer <= 0.0:
				_open_quake_flash(Atk.QUAKE_FLASH2, quake_flash2_time, quake_flash2_time, 1.3, 240.0, 1)
				if is_instance_valid(_quake_fx):
					_quake_fx.pillars(quake_flash2_time + 0.32)
		Atk.QUAKE_FLASH2:
			tell.aim_point = global_position
			_shine(GREEN)
			if _atk_timer <= 0.0:
				tell.mode = CounterTell.Mode.OFF
				_quake_impact(1)
				_go(Atk.QUAKE_GAP3, quake_gap3)
		Atk.QUAKE_GAP3:
			if _atk_timer <= 0.0:
				_open_quake_flash(Atk.QUAKE_FLASH3, quake_flash3_time, quake_flash3_time, 2.1, 340.0, 2)
				sfx_rumble.play()
		Atk.QUAKE_FLASH3:
			tell.aim_point = global_position
			_shine(GREEN)
			if _atk_timer <= 0.0:
				tell.mode = CounterTell.Mode.OFF
				_quake_impact(2)
				_go(Atk.QUAKE_END, quake_end_time)
				_sfx(sfx_roar, 0.03)
		Atk.QUAKE_END:
			if _atk_timer <= 0.0:
				_enter_phase2()


## 몸 전체를 빛나게 유지한다 (Enemy._update_flash가 그린다).
func _shine(color: Color) -> void:
	_flash_col = color
	_flash_amount = 0.65 + 0.3 * sin(_anim_t * 40.0)


## 방어 입력을 받기 시작한다. guard_time 동안 받고(그 끝이 충격 순간), 몸의 FLASH는 flash_time 동안 보인다.
func _open_quake_flash(atk: int, guard_time: float, flash_time: float, tell_scale: float, ring_size: float, index: int) -> void:
	_go(atk, flash_time)
	_guard_open = true
	_guarded = false
	tell.mode = CounterTell.Mode.WINDOW
	tell.scale = Vector2.ONE * tell_scale
	tell.aim_point = global_position
	GameFeel.flash(GREEN, 0.22, 0.22)
	_sfx(sfx_cue, 0.0)
	if is_instance_valid(_quake_fx):
		_quake_fx.ring(guard_time, ring_size, index)


## 충격 순간. 막았으면 피해 없음, 못 막았으면 이 회차 피해만 받는다 (위치와 무관). 다음 회차에는 영향이 없다.
func _quake_impact(index: int) -> void:
	var blocked := _guarded
	_guard_open = false
	_guarded = false
	if is_instance_valid(_quake_fx):
		_quake_fx.clear_ring()
	var strength := [0.6, 0.4, 1.0][index] as float
	GameFeel.shake(strength)
	match index:
		0:
			_sfx(sfx_slam, 0.03)
			_spawn_impact(Vector2(global_position.x, floor_y), 1.1, 8.0)
			visual.scale = Vector2(1.35 * signf(facing), 0.72)
		1:
			_sfx(sfx_clang, 0.03)
		2:
			_sfx(sfx_slam, 0.0)
			sfx_rumble.play()
			GameFeel.flash(Color(0.75, 1.0, 0.8), 0.3, 0.3)
			for x in [room_x.x + 200.0, global_position.x, room_x.y - 200.0]:
				_spawn_impact(Vector2(x, floor_y), 1.4, 10.0)
	var p := get_target() as Player
	if _target_down():
		return                               # 이미 쓰러져 있다 — 부활 무적을 건드리지 않는다
	if is_instance_valid(_quake_fx):
		_quake_fx.result(blocked)
	if blocked:
		p.on_guard_impact(strength)
		GameFeel.flash(Color(0.9, 1.0, 0.85), 0.4, 0.22)
		GameFeel.hit_stop(0.07, 0.05)
		_sfx(sfx_clang, 0.02)
		sfx_clang.pitch_scale *= 1.4       # 맑게 튕겨 내는 금속음
		return
	if quake_pierce:
		p.hurtbox.invincible = false
	var dir := signf(p.global_position.x - global_position.x)
	p.hurtbox.receive_hit(quake_damage[index], self, Vector2(dir if dir != 0.0 else 1.0, -0.7).normalized() * quake_knockback)
	GameFeel.flash(Color(1.0, 0.1, 0.08), 0.55, 0.35)   # 일반 피격보다 확실한 실패 신호
	GameFeel.hit_stop(0.12, 0.05)


func _enter_phase2() -> void:
	_quake_done = true
	phase = 2
	prince_health.floor_hp = final_hp
	glint_duration = _base_glint * phase2_flash_scale
	rush_flash_time = _base_rush_flash * phase2_flash_scale
	hurtbox.invincible = false
	if is_instance_valid(_quake_fx):
		_quake_fx.queue_free()
	_quake_fx = null
	_to_idle(0.2)


## 방어 경로(Player._try_guard): 패턴 4의 FLASH 또는 패턴 5의 낙하 동안 열린다.
func is_guard_open() -> bool:
	return state == State.ACTIVE and _guard_open and not _guarded


func on_guarded() -> void:
	_guarded = true
	if is_instance_valid(_quake_fx):
		_quake_fx.lock_ring()
	if _atk == Atk.FINALE_FALL:
		_begin_clash()


# ─────────────────────────── 패턴 5: 마지막 일격 ───────────────────────────
func _begin_finale() -> void:
	_finale_started = true
	_end_all_attacks()
	state = State.ACTIVE
	_airborne = false
	hurtbox.invincible = true
	velocity = Vector2.ZERO
	_go(Atk.FINALE_BLINK, finale_blink_time)
	_vanish()


func _do_finale(delta: float) -> void:
	match _atk:
		Atk.FINALE_BLINK:
			velocity = Vector2.ZERO
			if _atk_timer <= 0.0:
				global_position = Vector2((room_x.x + room_x.y) * 0.5, _foot_y())
				facing = dir_to_target()
				_reappear()
				tell.mode = CounterTell.Mode.CHARGE
				tell.scale = Vector2.ONE * 2.2
				_go(Atk.FINALE_CHARGE, finale_charge_time)
				_sfx(sfx_charge, 0.0)
				_sfx(sfx_roar, 0.03)
				sfx_rumble.play()
		Atk.FINALE_CHARGE:
			velocity = Vector2.ZERO
			var k := 1.0 - clampf(_atk_timer / finale_charge_time, 0.0, 1.0)
			tell.progress = k
			tell.aim_point = global_position
			_aura_amt = 0.5 + k
			GameFeel.shake(0.03 + 0.05 * k)
			if _atk_timer <= 0.0:
				_vanish()
				tell.mode = CounterTell.Mode.OFF
				_go(Atk.FINALE_DROP, finale_drop_delay)
		Atk.FINALE_DROP:
			velocity = Vector2.ZERO
			if _atk_timer <= 0.0:
				_begin_finale_fall()
		Atk.FINALE_FALL:
			_do_finale_fall(delta)


func _begin_finale_fall() -> void:
	var t := get_target()
	_set_float(true)
	global_position = t.global_position + Vector2(0.0, -finale_drop_height)
	_fall_from_y = global_position.y
	_reappear()
	_go(Atk.FINALE_FALL, finale_fall_time)
	_guard_open = true
	_guarded = false
	GameFeel.flash(GREEN, 0.25, 0.25)
	_sfx(sfx_cue, 0.0)


## 플레이어 머리 위로 천천히 내려온다. 플레이어를 따라가므로 도망쳐도 맞부딪힘은 항상 성립한다 (승패는 힘겨루기가 가른다).
func _do_finale_fall(_delta: float) -> void:
	velocity = Vector2.ZERO
	var t := get_target()
	var k := 1.0 - clampf(_atk_timer / finale_fall_time, 0.0, 1.0)
	global_position = Vector2(t.global_position.x, lerpf(_fall_from_y, t.global_position.y - 74.0, k * k))
	_shine(GLINT_COLOR)
	if _atk_timer <= 0.0:
		_begin_clash()


func _begin_clash() -> void:
	if _atk == Atk.FINALE_CLASH:
		return
	var p := get_target() as Player
	_guard_open = false
	_go(Atk.FINALE_CLASH, 0.0)
	_aura_amt = 1.2
	global_position = p.global_position + Vector2(0.0, -74.0)
	p.begin_event_lock()
	GameFeel.hit_stop(0.1, 0.05)
	GameFeel.shake(0.8)
	GameFeel.flash(Color(1.0, 1.0, 0.9), 0.5, 0.25)
	_sfx(sfx_clang, 0.0)
	_burst(GLINT_COLOR, 22, 110.0, 0.35, true)
	_clash = clash_scene.instantiate() as PrinceClash
	_clash.gauge = clash_gauge
	_clash.drain = clash_drain
	_clash.gain = clash_gain
	_clash.pressed.connect(_on_clash_pressed)
	_clash.finished.connect(_on_clash_finished)
	_fx_parent().add_child(_clash)
	_clash.global_position = p.global_position + Vector2(0.0, -170.0)


func _on_clash_pressed() -> void:
	GameFeel.shake(0.12)
	_sfx(sfx_clang, 0.08)
	_burst(GLINT_COLOR, 6, 46.0, 0.16, false)


func _on_clash_finished(won: bool) -> void:
	_go(Atk.FINALE_END, 0.0)
	_finale_won = won
	_aura_amt = 0.0
	if is_instance_valid(_clash):
		_clash.queue_free()
	_clash = null
	var p := get_target() as Player
	if won:
		_set_float(false)
		prince_health.floor_hp = 0
		hurtbox.invincible = false
		p.event_final_strike(self, health.hp)
	else:
		p.end_event_lock()
		_spawn_slash(Vector2(0.0, 50.0), 80.0, 2.2)
		_sfx(sfx_swing, 0.0)
		_sfx(sfx_slam, 0.0)
		GameFeel.shake(0.9)
		p.hurtbox.invincible = false
		p.hurtbox.receive_hit(p.health.hp, self, Vector2(-facing, -0.6).normalized() * 420.0)


# ─────────────────────────── 체력 경계 ───────────────────────────
func _on_damaged(_amount: int) -> void:
	if state == State.DEAD or health.hp > prince_health.floor_hp or prince_health.floor_hp <= 0:
		return
	if not _quake_done:
		if not _atk in QUAKE_STATES:
			_begin_quake()
	elif not _finale_started:
		_begin_finale()


## 치트/테스트: 체력을 다음 경계까지 내려 패턴 4 또는 5로 바로 넘어간다. 넘어갈 수 없으면 "".
func debug_next_stage() -> String:
	if state == State.DEAD or state == State.SPAWNING or _finale_started or _atk in QUAKE_STATES:
		return ""
	var label := "Pattern 5" if _quake_done else "Pattern 4"
	health.take_damage(health.hp - prince_health.floor_hp)
	return label


func _on_hurt(_source: Node) -> void:
	pass                                 # 경직 중의 피격 — 경직 시간을 건드리지 않는다


func _on_banished() -> void:
	_end_all_attacks()
	if is_instance_valid(_quake_fx):
		_quake_fx.queue_free()
	if is_instance_valid(_clash):
		_clash.queue_free()
	_aura_amt = 0.0


func _on_died() -> void:
	_end_all_attacks()
	_aura_amt = 0.0
	queue_redraw()
	super._on_died()


func _can_contact() -> bool:
	return false


# ─────────────────────────── 외형 ───────────────────────────
func _animate(delta: float) -> void:
	var frame_i: int = Frame.IDLE_A + int(_anim_t * 2.2) % 2
	var target := IDLE_DEG + 4.0 * sin(_anim_t * 3.0)
	var snap := false
	var u := 1.0 - clampf(_atk_timer / _atk_time, 0.0, 1.0)
	match state:
		State.STAGGER:
			frame_i = Frame.BROKEN
			target = 112.0
		State.HITSTUN, State.CARRIED:
			frame_i = Frame.RECOIL
		State.SPAWNING:
			pass
		_:
			match _atk:
				Atk.SHUNPO:
					frame_i = Frame.DASH
					target = TRAIL_DEG
					snap = true
				Atk.RAISE:
					frame_i = Frame.RAISE
					target = lerpf(IDLE_DEG, RAISED_DEG, 1.0 - pow(1.0 - u, 2.0))
					snap = true
				Atk.RERAISE:
					frame_i = Frame.RAISE
					# 튕겨 나간 장검을 뒤로 크게 돌려 다시 치켜든다
					target = lerpf(RECOIL_DEG + 360.0, RAISED_DEG + 360.0, 1.0 - pow(1.0 - u, 2.0))
					snap = true
				Atk.FLASH:
					frame_i = Frame.RAISE
					target = RAISED_DEG
					snap = true
				Atk.STRIKE:
					frame_i = Frame.STRIKE
					target = lerpf(RAISED_DEG, STRIKE_END_DEG, 1.0 - pow(1.0 - u, 3.0))
					snap = true
				Atk.RECOVER:
					frame_i = Frame.STRIKE if u < 0.5 else Frame.IDLE_A
					target = STRIKE_END_DEG
				Atk.RECOIL:
					frame_i = Frame.RECOIL
					target = RECOIL_DEG
					snap = true
				Atk.RUSH_CROUCH:
					frame_i = Frame.CROUCH
					target = TRAIL_DEG
					snap = true
				Atk.RUSH:
					frame_i = Frame.RUSH
					target = TRAIL_DEG
					snap = true
				Atk.RUSH_END:
					frame_i = Frame.CROUCH if u < 0.6 else Frame.IDLE_A
					target = TRAIL_DEG if u < 0.6 else IDLE_DEG
				Atk.WAVE_WINDUP:
					frame_i = Frame.RAISE
					target = lerpf(IDLE_DEG, RAISED_DEG, 1.0 - pow(1.0 - u, 2.0))
					snap = true
				Atk.WAVE_CAST:
					frame_i = Frame.LOW
					target = lerpf(RAISED_DEG, LOW_DEG, minf(u * 2.0, 1.0))
					snap = true
				Atk.QUAKE_CHARGE, Atk.QUAKE_FLASH1, Atk.QUAKE_FALL:
					frame_i = Frame.PLUNGE
					target = DOWN_DEG
					snap = true
				Atk.QUAKE_GAP2, Atk.QUAKE_FLASH2, Atk.QUAKE_GAP3, Atk.QUAKE_FLASH3:
					frame_i = Frame.IMPALE
					target = 78.0
					snap = true
				Atk.QUAKE_END:
					frame_i = Frame.ROAR
					target = RAISED_DEG + 60.0
				Atk.FINALE_CHARGE:
					frame_i = Frame.RAISE
					target = -92.0
					snap = true
				Atk.FINALE_FALL, Atk.FINALE_CLASH:
					frame_i = Frame.PLUNGE
					target = DOWN_DEG
					snap = true
				Atk.FINALE_END:
					frame_i = Frame.BROKEN if _finale_won else Frame.STRIKE
					target = 112.0 if _finale_won else STRIKE_END_DEG
	body.frame = frame_i
	if snap:
		_sword_deg = target
	else:
		_sword_deg = lerpf(_sword_deg, target, 1.0 - exp(-14.0 * delta))
	sword.position = HAND[frame_i]
	sword.rotation_degrees = _sword_deg
	queue_redraw()


## 몸 뒤의 초록 기운 — 충전이 쌓일수록 커진다. 2페이즈에는 은은하게 남는다. 판정 없는 겉모습.
func _draw() -> void:
	var amt := maxf(_aura_amt, 0.22 if phase == 2 else 0.0)
	if amt <= 0.01 or state == State.DEAD:
		return
	var r := 46.0 + 44.0 * amt + 4.0 * sin(_anim_t * 18.0)
	draw_circle(Vector2(0.0, -6.0), r, Color(GREEN.r, GREEN.g, GREEN.b, 0.1 + 0.12 * minf(amt, 1.0)))
	draw_arc(Vector2(0.0, -6.0), r, 0.0, TAU, 40, Color(GREEN.r, GREEN.g, GREEN.b, 0.3 + 0.4 * minf(amt, 1.0)), 2.5)


func _ghost(interval: float) -> void:
	_ghost_t -= get_physics_process_delta_time()
	if _ghost_t > 0.0 or afterimage_scene == null:
		return
	_ghost_t = interval
	var a := afterimage_scene.instantiate() as Afterimage
	_fx_parent().add_child(a)
	a.setup_from_sprite(body, GREEN)


func _spawn_slash(offset: Vector2, aim_deg: float, scale_mul: float) -> void:
	if slash_scene == null:
		return
	var s := slash_scene.instantiate() as SlashEffect
	s.color = Color(0.4, 1.0, 0.55, 0.85)
	s.core_color = Color(0.92, 1.0, 0.94, 1.0)
	_fx_parent().add_child(s)
	s.global_position = global_position + offset
	s.setup(facing, aim_deg, scale_mul)


func _spawn_impact(at: Vector2, strength: float, persist: float) -> void:
	if impact_scene == null:
		return
	var g := impact_scene.instantiate() as GroundImpact
	_fx_parent().add_child(g)
	g.global_position = at
	g.crack_ground(strength, persist)
