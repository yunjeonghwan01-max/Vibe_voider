extends SceneTree

## 오프라인 사운드 합성기 (개발 도구 — 게임 실행에는 필요 없다).
## 효과음과 배경 음악 루프를 코드로 합성해 assets/temporary/audio/ 에 16-bit mono WAV로 저장한다.
## 루프 사운드는 WAV smpl 청크에 루프 구간을 넣어 Godot가 자동으로 반복 재생한다.
##   Godot --headless --path . --script res://toolkit/asset_gen/audio_gen.gd
## 같은 seed를 쓰므로 다시 실행해도 같은 소리가 나온다.

const OUT := "res://assets/temporary/audio/"
const SR := 44100
const MUSIC_SR := 22050

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 11
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# 플레이어
	_save("swing_1", _swing(0.17, 1500.0, 0.0), SR)
	_save("swing_2", _swing(0.17, 1800.0, 0.0), SR)
	_save("swing_3", _swing(0.26, 1100.0, 0.5), SR)
	_save("hit", _hit(false), SR)
	_save("hit_heavy", _hit(true), SR)
	_save("parry", _parry(), SR)
	_save("parry_whiff", _whiff(), SR)
	_save("dash", _dash(), SR)
	_save("jump", _jump(), SR)
	_save("land", _land(), SR)
	_save("step", _step(), SR)
	_save("player_hurt", _player_hurt(), SR)
	_save("player_death", _player_death(), SR)
	_save("ult_cast", _ult_cast(), SR)
	_save("ult_hit", _ult_hit(), SR)
	# 적
	_save("glint", _glint(), SR)
	_save("enemy_swing", _swing(0.24, 850.0, 0.7), SR)
	_save("grunt_lunge", _growl(), SR)
	_save("enemy_death", _enemy_death(), SR)
	_save("spawn", _spawn(), SR)
	# 환경 / 음악 (루프)
	_save("fire_loop", _fire_loop(), SR, true)
	_save("music_loop", _music(), MUSIC_SR, true)
	# 스킬 — 맨 뒤에 둔다 (rng 소비 순서가 바뀌면 기존 소리가 달라진다)
	_save("orb_cast", _orb_cast(), SR)
	_save("orb_hit", _orb_hit(), SR)
	_save("dash_slash", _swing(0.2, 2300.0, 0.35), SR)   # 대시 참격: 짧고 날카로운 바람 + 약간의 무게
	# 감시자 / 카유공 — 새 소리는 항상 이 아래에 추가한다 (rng 소비 순서 유지)
	_save("needle_shot", _needle_shot(), SR)
	_save("counter_charge", _counter_charge(), SR)
	_save("counter_cue", _counter_cue(), SR)
	_save("beam_fire", _beam_fire(), SR)
	_save("counter_slash", _counter_slash(), SR)
	_save("lightning", _lightning(), SR)
	_save("dash_slash_ring", _dash_slash_ring(), SR)
	_save("dash_slash_hit", _dash_slash_hit(), SR)
	_save("haki_burst", _haki_burst(), SR)
	_save("moon_slash_fly", _moon_slash_fly(), SR)
	_save("moon_slash_burst", _moon_slash_burst(), SR)
	# 보스 — 월식의 기사 (rng 소비 순서 유지를 위해 항상 맨 뒤)
	_save("boss_land", _boss_impact(2.0, 1.0), SR)
	_save("boss_slam", _boss_impact(1.1, 0.7), SR)
	_save("boss_step", _boss_step(), SR)
	_save("boss_swing", _swing(0.36, 620.0, 1.0), SR)
	_save("boss_roar", _boss_roar(), SR)
	_save("banish", _banish(), SR)
	_save("rumble", _rumble(), SR)
	_save("boss_blink", _boss_blink(), SR)
	_save("guard_ring", _guard_ring(), SR)
	_save("guard_clang", _guard_clang(), SR)
	_save("rush_charge", _rush_charge(), SR)
	_save("boss_death", _boss_death(), SR)
	_save("boss_music_loop", _boss_music(), MUSIC_SR, true)
	print("[audio_gen] done")
	quit()


# ═══════════════════════════════ 공용 ═══════════════════════════════
func _buf(sec: float, sr: int = SR) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * sr))
	return b


func _n() -> float:
	return rng.randf_range(-1.0, 1.0)


## Chamberlin state-variable filter. run()을 샘플마다 호출하고 low/band/high 출력을 읽는다.
class SVF:
	var low := 0.0
	var band := 0.0
	var high := 0.0

	func run(x: float, fc: float, q: float, sr: int = 44100) -> SVF:
		var f := 2.0 * sin(PI * minf(fc, sr * 0.22) / sr)
		low += f * band
		high = x - low - q * band
		band += f * high
		return self


func _normalize(b: PackedFloat32Array, peak: float = 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for s in b:
		m = maxf(m, absf(s))
	for i in b.size():
		b[i] = b[i] / m * peak
	return b


func _save(name: String, data: PackedFloat32Array, sr: int, loop: bool = false) -> void:
	var n := data.size()
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		pcm.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(OUT + name + ".wav", FileAccess.WRITE)
	var smpl_size := 60 if loop else 0
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(4 + 24 + 8 + pcm.size() + (8 + smpl_size if loop else 0))
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)        # PCM
	f.store_16(1)        # mono
	f.store_32(sr)
	f.store_32(sr * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	if loop:
		f.store_buffer("smpl".to_ascii_buffer())
		f.store_32(smpl_size)
		for v in [0, 0, int(1.0e9 / sr), 60, 0, 0, 0, 1, 0]:
			f.store_32(v)
		for v in [0, 0, 0, n - 1, 0, 0]:   # cue id, forward, start, end, fraction, 무한 반복
			f.store_32(v)
	f.close()
	print("  saved %s.wav  %.2fs%s" % [name, float(n) / sr, "  (loop)" if loop else ""])


# ═══════════════════════════════ 효과음 ═══════════════════════════════
## 바람 가르는 소리: 밴드패스 노이즈의 중심 주파수가 휙 올라갔다 내려온다. weight > 0 이면 묵직한 저음 추가.
func _swing(dur: float, center: float, weight: float) -> PackedFloat32Array:
	var b := _buf(dur + 0.05)
	var st := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var u := clampf(t / dur, 0.0, 1.0)
		var fc := center * (0.55 + 1.3 * sin(PI * pow(u, 0.7)))
		var env := pow(sin(PI * pow(u, 0.45)), 2.0) if t < dur else 0.0
		var s := st.run(_n(), fc, 0.9).band * env
		if weight > 0.0:
			s += sin(TAU * (90.0 + 60.0 * (1.0 - u)) * t) * env * weight * 0.5
		b[i] = s
	return _normalize(b, 0.85)


func _hit(heavy: bool) -> PackedFloat32Array:
	var dur := 0.32 if heavy else 0.2
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var phase := 0.0
	for i in b.size():
		var t := float(i) / SR
		var f0 := (150.0 if heavy else 190.0) * exp(-t * 18.0) + (42.0 if heavy else 60.0)
		phase += TAU * f0 / SR
		var thump := sin(phase) * exp(-t * (14.0 if heavy else 24.0))
		var nz := _n()
		var crack := st.run(nz, 2600.0, 0.6).high * exp(-t * (45.0 if heavy else 70.0))
		var slice := st2.run(nz, 4200.0, 0.3).band * exp(-t * 110.0)
		var s := thump * 1.1 + crack * 0.55 + slice * 0.5
		if heavy:
			s += _n() * exp(-t * 22.0) * 0.25
		b[i] = tanh(s * (2.2 if heavy else 1.6))
	return _normalize(b, 0.95)


## 패링: 날카로운 금속 충돌음 — 비조화 배음 + 강한 트랜지언트 + 낮은 붐 + "쉬잉" 꼬리.
func _parry() -> PackedFloat32Array:
	var b := _buf(1.1)
	var ratios := [1.0, 2.32, 3.86, 5.41, 7.13, 9.2]
	var amps := [1.0, 0.75, 0.55, 0.4, 0.28, 0.18]
	var decays := [3.2, 4.2, 5.5, 7.0, 9.0, 12.0]
	var f0 := 1250.0
	var st := SVF.new()
	var st2 := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var s := 0.0
		for k in ratios.size():
			var f: float = f0 * ratios[k]
			var e: float = exp(-t * decays[k]) * amps[k]
			s += (sin(TAU * f * t) + sin(TAU * f * 1.0045 * t + 0.7)) * 0.5 * e
		s *= 0.55
		var nz := _n()
		s += st.run(nz, 5000.0, 0.5).high * exp(-t * 160.0) * 1.4
		s += st2.run(nz, 7000.0 + 2500.0 * t, 0.25).band * exp(-t * 7.0) * 0.35
		s += sin(TAU * (55.0 + 50.0 * exp(-t * 20.0)) * t) * exp(-t * 9.0) * 0.6
		b[i] = tanh(s * 1.4)
	return _normalize(b, 0.95)


func _whiff() -> PackedFloat32Array:
	var b := _swing(0.12, 2400.0, 0.0)
	for i in b.size():
		var t := float(i) / SR
		b[i] = b[i] * 0.6 + sin(TAU * 2900.0 * t) * exp(-t * 70.0) * 0.35
	return _normalize(b, 0.7)


## 번쩍임 "키잉—": 높은 종소리 배음 + 비브라토 + 반짝이는 잔음. 패링 타이밍 신호이므로 또렷하게.
func _glint() -> PackedFloat32Array:
	var b := _buf(0.6)
	var sparkles := []
	for k in 10:
		sparkles.append([rng.randf_range(0.0, 0.3), rng.randf_range(5200.0, 8200.0)])
	for i in b.size():
		var t := float(i) / SR
		var glide := 0.965 + 0.035 * (1.0 - exp(-t * 40.0))
		var vib := 1.0 + 0.004 * sin(TAU * 9.0 * t)
		var att := clampf(t / 0.004, 0.0, 1.0)
		var env := att * exp(-maxf(t - 0.04, 0.0) * 6.5)
		var f := 2093.0 * glide * vib
		var s := sin(TAU * f * t) + 0.55 * sin(TAU * f * 1.5 * t) + 0.35 * sin(TAU * f * 2.0 * t + 1.0) \
				+ 0.2 * sin(TAU * f * 3.01 * t)
		s *= env
		for sp in sparkles:
			var dt: float = t - sp[0]
			if dt > 0.0 and dt < 0.08:
				s += sin(TAU * sp[1] * dt) * exp(-dt * 60.0) * 0.25
		b[i] = s
	return _normalize(b, 0.85)


func _dash() -> PackedFloat32Array:
	var b := _buf(0.3)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / SR
		var fc := 3200.0 * exp(-t * 9.0) + 500.0
		var a := 1.0 - exp(-TAU * fc / SR)
		lp += a * (_n() - lp)
		var env := clampf(t / 0.012, 0.0, 1.0) * exp(-t * 11.0)
		b[i] = lp * env * 1.6 + sin(TAU * (130.0 - 60.0 * t) * t) * env * 0.35
	return _normalize(b, 0.8)


func _jump() -> PackedFloat32Array:
	var b := _buf(0.14)
	var st := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var u := t / 0.14
		var env := sin(PI * u) * (1.0 - u)
		b[i] = st.run(_n(), 600.0 + 1400.0 * u, 0.8).band * env + sin(TAU * (300.0 + 300.0 * u) * t) * env * 0.12
	return _normalize(b, 0.55)


func _land() -> PackedFloat32Array:
	var b := _buf(0.16)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / SR
		lp += 0.08 * (_n() - lp)
		b[i] = sin(TAU * (60.0 + 70.0 * exp(-t * 30.0)) * t) * exp(-t * 32.0) + lp * exp(-t * 45.0) * 2.0
	return _normalize(b, 0.6)


func _step() -> PackedFloat32Array:
	var b := _buf(0.07)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / SR
		lp += 0.18 * (_n() - lp)
		b[i] = lp * exp(-t * 85.0) * 2.0 + sin(TAU * 140.0 * t) * exp(-t * 60.0) * 0.4
	return _normalize(b, 0.45)


## 피격: 둔탁한 충격 + 고양이 하악질(고역 노이즈).
func _player_hurt() -> PackedFloat32Array:
	var b := _hit(true)
	var out := _buf(0.42)
	var st := SVF.new()
	for i in out.size():
		var t := float(i) / SR
		var s := b[i] * 0.8 if i < b.size() else 0.0
		var hiss_env := clampf((t - 0.03) / 0.04, 0.0, 1.0) * exp(-maxf(t - 0.12, 0.0) * 9.0)
		s += st.run(_n(), 5200.0, 1.1).band * hiss_env * 0.9
		out[i] = s
	return _normalize(out, 0.9)


func _player_death() -> PackedFloat32Array:
	var b := _buf(1.3)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var f := 380.0 * exp(-t * 1.6) + 60.0
		ph += TAU * f / SR
		var tone := (fposmod(ph / TAU, 1.0) * 2.0 - 1.0)
		lp += 0.05 * (tone - lp)
		b[i] = lp * exp(-t * 2.2) * 1.2 + sin(TAU * (75.0 - 30.0 * t) * t) * exp(-t * 3.0) * 0.8 \
				+ _n() * exp(-t * 12.0) * 0.3
	return _normalize(b, 0.85)


func _ult_cast() -> PackedFloat32Array:
	var b := _buf(0.55)
	var lp := 0.0
	var ph := 0.0
	var st := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var u := clampf(t / 0.4, 0.0, 1.0)
		var f := 110.0 * pow(8.0, u)
		ph += TAU * f / SR
		var saw := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		lp += (0.02 + 0.2 * u) * (saw - lp)
		var env := pow(u, 1.5) * (1.0 if t < 0.4 else exp(-(t - 0.4) * 30.0))
		b[i] = (lp * 0.8 + st.run(_n(), 800.0 + 5000.0 * u, 0.7).band * 0.6) * env
	return _normalize(b, 0.85)


func _ult_hit() -> PackedFloat32Array:
	var b := _buf(1.1)
	var st := SVF.new()
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var f := 140.0 * exp(-t * 10.0) + 34.0
		ph += TAU * f / SR
		var s := sin(ph) * exp(-t * 4.5) * 1.3
		s += st.run(_n(), 1800.0, 0.4).low * exp(-t * 14.0) * 0.9
		for k in 4:
			var ff: float = 620.0 * [1.0, 2.41, 3.9, 5.6][k]
			s += sin(TAU * ff * t) * exp(-t * (3.0 + k * 2.0)) * 0.22
		b[i] = tanh(s * 1.8)
	return _normalize(b, 0.95)


## 잡몹 돌진: 거친 으르렁(톱니파 + 진폭 떨림 + 포먼트 필터).
func _growl() -> PackedFloat32Array:
	var b := _buf(0.34)
	var ph := 0.0
	var st := SVF.new()
	var st2 := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var f := 95.0 + 25.0 * sin(TAU * 6.0 * t) + rng.randf_range(-6.0, 6.0)
		ph += TAU * f / SR
		var saw := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		var am := 0.6 + 0.4 * sin(TAU * 28.0 * t)
		var src := saw * am + _n() * 0.35
		var s := st.run(src, 700.0, 0.35).band + st2.run(src, 1500.0, 0.5).band * 0.6
		var env := clampf(t / 0.03, 0.0, 1.0) * exp(-maxf(t - 0.1, 0.0) * 9.0)
		b[i] = tanh(s * env * 2.0)
	return _normalize(b, 0.8)


## 적 소멸: 아래로 꺼지는 공허음 + 부서지는 잔음.
func _enemy_death() -> PackedFloat32Array:
	var b := _buf(0.7)
	var st := SVF.new()
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var fc := 2200.0 * exp(-t * 4.0) + 250.0
		var s := st.run(_n(), fc, 0.4).band * exp(-t * 5.0)
		var f := 320.0 * exp(-t * 5.0) + 70.0
		ph += TAU * f / SR
		s += sin(ph) * exp(-t * 6.0) * 0.6
		if rng.randf() < 0.004 and t < 0.4:
			s += _n() * 0.8
		b[i] = s
	return _normalize(b, 0.8)


## 소환: 역재생처럼 차오르는 소리.
func _spawn() -> PackedFloat32Array:
	var b := _buf(0.6)
	var st := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var u := clampf(t / 0.5, 0.0, 1.0)
		var env := pow(u, 2.2) * (1.0 if t < 0.5 else exp(-(t - 0.5) * 50.0))
		var s := st.run(_n(), 200.0 + 2600.0 * u, 0.6).band
		s += sin(TAU * (60.0 + 80.0 * u) * t) * 0.7
		b[i] = s * env
	return _normalize(b, 0.7)


func _fire_loop() -> PackedFloat32Array:
	var dur := 3.0
	var xf := 0.3
	var b := _buf(dur + xf)
	var brown := 0.0
	var st := SVF.new()
	var pop_env := 0.0
	for i in b.size():
		brown = clampf(brown + _n() * 0.02, -1.0, 1.0) * 0.998
		if rng.randf() < 30.0 / SR:
			pop_env = rng.randf_range(0.3, 1.0)
		pop_env *= 0.995
		var crackle := st.run(_n(), 3200.0, 0.5).band * pop_env
		b[i] = brown * 0.5 + crackle * 0.8
	# 끝을 앞부분에 겹쳐 이음매 없는 루프로 만든다.
	var n := int(dur * SR)
	var nx := int(xf * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = b[i]
	for i in nx:
		var a := float(i) / nx
		out[i] = b[n + i] * (1.0 - a) + b[i] * a
	return _normalize(out, 0.6)


# ═══════════════════════════════ 배경 음악 ═══════════════════════════════
## 120BPM, 16마디(32초) 루프. D단조의 어두운 전투곡: 질주하는 베이스, 킥/스네어/하이햇,
## 패드 화음, 후반 8마디에 아르페지오. 음 꼬리는 버퍼 앞쪽으로 감싸 넣어 이음매 없이 반복된다.
const BEAT := 0.5
const CHORDS := [
	[38, 41, 45], [38, 41, 45], [34, 38, 41], [36, 40, 43], [38, 41, 45], [38, 41, 45], [43, 46, 50], [45, 49, 52],
	[38, 41, 45], [34, 38, 41], [43, 46, 50], [45, 49, 52], [38, 41, 45], [34, 38, 41], [36, 40, 43], [45, 49, 52],
]


func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _music() -> PackedFloat32Array:
	var sr := MUSIC_SR
	var total := int(BEAT * 4.0 * CHORDS.size() * sr)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var bar_len := BEAT * 4.0
	for bar in CHORDS.size():
		var chord: Array = CHORDS[bar]
		var t0 := bar * bar_len
		# 베이스: 8분음 질주, 마지막 박은 옥타브 위
		for k in 8:
			var note: float = chord[0] - 12 + (12 if k == 7 or k == 3 else 0)
			_add_bass(mix, t0 + k * BEAT * 0.5, BEAT * 0.42, _midi(note), 0.32)
		# 패드
		for m in chord:
			_add_pad(mix, t0, bar_len, _midi(m + 12), 0.05)
		# 드럼
		for beat in 4:
			var tb := t0 + beat * BEAT
			if beat == 0 or beat == 2:
				_add_kick(mix, tb, 0.85)
			else:
				_add_snare(mix, tb, 0.45)
			_add_hat(mix, tb + BEAT * 0.5, 0.12)
			if bar >= 8:
				_add_hat(mix, tb + BEAT * 0.25, 0.06)
				_add_hat(mix, tb + BEAT * 0.75, 0.06)
		if bar % 2 == 1:
			_add_kick(mix, t0 + BEAT * 3.5, 0.6)
		# 후반 아르페지오 (16분음)
		if bar >= 8:
			var arp := [chord[0] + 24, chord[1] + 24, chord[2] + 24, chord[1] + 24]
			for k in 16:
				_add_pluck(mix, t0 + k * BEAT * 0.25, BEAT * 0.22, _midi(arp[k % 4] + (12 if k % 8 == 6 else 0)), 0.07)
	# 에코(점8분 딜레이)를 루프 전체에 두 바퀴 돌려 안정 상태로 만든다.
	var dl := int(BEAT * 0.75 * sr)
	var wet := mix.duplicate()
	for pass_i in 2:
		for i in total:
			wet[i] = mix[i] + wet[(i - dl + total) % total] * 0.3
	for i in total:
		mix[i] = tanh((mix[i] * 0.85 + (wet[i] - mix[i]) * 0.35) * 1.3)
	return _normalize(mix, 0.8)


func _wrap_add(mix: PackedFloat32Array, i: int, v: float) -> void:
	mix[i % mix.size()] += v


func _add_bass(mix: PackedFloat32Array, t: float, dur: float, f: float, amp: float) -> void:
	var sr := MUSIC_SR
	var start := int(t * sr)
	var n := int((dur + 0.05) * sr)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var tt := float(i) / sr
		ph += f / sr
		var saw := fposmod(ph, 1.0) * 2.0 - 1.0
		var sq := 1.0 if fposmod(ph * 0.5, 1.0) < 0.5 else -1.0
		var fc := 300.0 + 1500.0 * exp(-tt * 18.0)
		lp += (1.0 - exp(-TAU * fc / sr)) * ((saw * 0.7 + sq * 0.3) - lp)
		var env := clampf(tt / 0.004, 0.0, 1.0) * (1.0 if tt < dur else exp(-(tt - dur) * 120.0))
		_wrap_add(mix, start + i, lp * env * amp)


func _add_pad(mix: PackedFloat32Array, t: float, dur: float, f: float, amp: float) -> void:
	var sr := MUSIC_SR
	var start := int(t * sr)
	var n := int((dur + 0.6) * sr)
	var p1 := rng.randf()
	var p2 := rng.randf()
	var lp := 0.0
	for i in n:
		var tt := float(i) / sr
		p1 += f * 0.997 / sr
		p2 += f * 1.004 / sr
		var s := (fposmod(p1, 1.0) + fposmod(p2, 1.0) - 1.0)
		lp += 0.06 * (s - lp)
		var env := clampf(tt / 0.35, 0.0, 1.0) * (1.0 if tt < dur else exp(-(tt - dur) * 7.0))
		_wrap_add(mix, start + i, lp * env * amp)


func _add_pluck(mix: PackedFloat32Array, t: float, dur: float, f: float, amp: float) -> void:
	var sr := MUSIC_SR
	var start := int(t * sr)
	var n := int((dur + 0.15) * sr)
	for i in n:
		var tt := float(i) / sr
		var ph := fposmod(f * tt, 1.0)
		var tri := 4.0 * absf(ph - 0.5) - 1.0
		_wrap_add(mix, start + i, tri * exp(-tt * 14.0) * amp)


func _add_kick(mix: PackedFloat32Array, t: float, amp: float) -> void:
	var sr := MUSIC_SR
	var start := int(t * sr)
	var ph := 0.0
	for i in int(0.32 * sr):
		var tt := float(i) / sr
		ph += TAU * (45.0 + 110.0 * exp(-tt * 35.0)) / sr
		_wrap_add(mix, start + i, (sin(ph) * exp(-tt * 9.0) + _n() * exp(-tt * 300.0) * 0.3) * amp)


func _add_snare(mix: PackedFloat32Array, t: float, amp: float) -> void:
	var sr := MUSIC_SR
	var start := int(t * sr)
	var st := SVF.new()
	for i in int(0.22 * sr):
		var tt := float(i) / sr
		var nz := st.run(_n(), 1900.0, 0.7, sr).band
		_wrap_add(mix, start + i, (nz * exp(-tt * 16.0) * 1.2 + sin(TAU * 185.0 * tt) * exp(-tt * 30.0) * 0.5) * amp)


func _add_hat(mix: PackedFloat32Array, t: float, amp: float) -> void:
	var sr := MUSIC_SR
	var start := int(t * sr)
	var lp := 0.0
	for i in int(0.05 * sr):
		var tt := float(i) / sr
		var nz := _n()
		lp += 0.5 * (nz - lp)
		_wrap_add(mix, start + i, (nz - lp) * exp(-tt * 70.0) * amp)


# ═══════════════════════════════ 스킬 ═══════════════════════════════
## 장풍 발사: 휙 하는 바람 + 위로 솟는 공명음(공허 에너지).
func _orb_cast() -> PackedFloat32Array:
	var dur := 0.36
	var b := _buf(dur)
	var st := SVF.new()
	var phase := 0.0
	for i in b.size():
		var t := float(i) / SR
		var u := t / dur
		var env := minf(t / 0.012, 1.0) * pow(1.0 - u, 1.6)
		var fc := 700.0 + 2600.0 * sin(PI * minf(u * 1.4, 1.0))
		var wind := st.run(_n(), fc, 0.7).band
		var f := 180.0 + 520.0 * (1.0 - exp(-t * 14.0))
		phase += TAU * f / SR
		var tone := sin(phase) + 0.35 * sin(phase * 2.01) + 0.2 * sin(phase * 0.5)
		b[i] = (wind * 0.7 + tone * 0.45) * env
	return _normalize(b, 0.85)


## 장풍 다단히트: 짧고 지직거리는 에너지 타격음 (연달아 겹쳐도 거슬리지 않게 짧다).
func _orb_hit() -> PackedFloat32Array:
	var dur := 0.13
	var b := _buf(dur)
	var st := SVF.new()
	var phase := 0.0
	for i in b.size():
		var t := float(i) / SR
		var env := exp(-t * 32.0)
		var f := 140.0 + 700.0 * exp(-t * 40.0)
		phase += TAU * f / SR
		var thump := signf(sin(phase)) * 0.35 + sin(phase) * 0.5
		var crack := st.run(_n(), 2400.0, 0.5).band * exp(-t * 70.0)
		b[i] = (thump + crack * 1.2) * env
	return _normalize(b, 0.8)


# ═══════════════════════════════ 감시자 / 카유공 ═══════════════════════════════
## 바늘 발사: 짧고 높은 "픽-" 소리.
func _needle_shot() -> PackedFloat32Array:
	var dur := 0.14
	var b := _buf(dur)
	var st := SVF.new()
	var phase := 0.0
	for i in b.size():
		var t := float(i) / SR
		var env := minf(t / 0.004, 1.0) * exp(-t * 26.0)
		var f := 2400.0 - 1300.0 * minf(t / dur, 1.0)
		phase += TAU * f / SR
		var air := st.run(_n(), 5200.0, 0.6).band * exp(-t * 45.0)
		b[i] = (sin(phase) * 0.5 + air) * env
	return _normalize(b, 0.7)


## 카유공 충전 (정확히 2초): 점점 높아지고 빨라지는 웅웅거림 + 빨려드는 바람. 끝으로 갈수록 커진다.
func _counter_charge() -> PackedFloat32Array:
	var dur := 2.0
	var b := _buf(dur)
	var st := SVF.new()
	var phase := 0.0
	var lfo := 0.0
	for i in b.size():
		var t := float(i) / SR
		var u := t / dur
		var env := minf(t / 0.05, 1.0) * (0.25 + 0.75 * u * u) * minf((dur - t) / 0.02, 1.0)
		lfo += TAU * (3.0 + 22.0 * u * u) / SR
		var f := 110.0 + 520.0 * u * u
		phase += TAU * f * (1.0 + 0.02 * sin(lfo)) / SR
		var hum := sin(phase) + 0.4 * sin(phase * 2.0) + 0.25 * sin(phase * 3.01)
		var suck := st.run(_n(), 400.0 + 3600.0 * u, 0.5).band
		b[i] = (hum * (0.6 + 0.4 * sin(lfo)) * 0.6 + suck * 0.5) * env
	return _normalize(b, 0.8)


## 카유공 신호 "팅!": 날카롭고 맑은 금속성 종소리 (반격하라는 신호).
func _counter_cue() -> PackedFloat32Array:
	var dur := 0.6
	var b := _buf(dur)
	var partials := [[1760.0, 1.0, 7.0], [2640.0, 0.6, 9.0], [4120.0, 0.45, 13.0], [5300.0, 0.25, 18.0], [880.0, 0.35, 5.0]]
	for i in b.size():
		var t := float(i) / SR
		var s := 0.0
		for pt in partials:
			s += sin(TAU * pt[0] * t) * pt[1] * exp(-t * pt[2])
		var click := _n() * exp(-t * 400.0) * 0.8
		b[i] = s * minf(t / 0.002, 1.0) + click
	return _normalize(b, 0.9)


## 광선 발사: 거대한 저음 폭발 + 지글거리는 에너지 + 내려가는 톱니파.
func _beam_fire() -> PackedFloat32Array:
	var dur := 1.0
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var p1 := 0.0
	var p2 := 0.0
	for i in b.size():
		var t := float(i) / SR
		var env := minf(t / 0.006, 1.0) * exp(-t * 3.2)
		var boom_f := 40.0 + 120.0 * exp(-t * 14.0)
		p1 += TAU * boom_f / SR
		var boom := sin(p1) * exp(-t * 5.0) * 1.2
		var saw_f := 900.0 * exp(-t * 2.5) + 120.0
		p2 += saw_f / SR
		var saw := (fmod(p2, 1.0) * 2.0 - 1.0) * 0.35
		var sizzle := st.run(_n(), 3000.0 + 2000.0 * sin(t * 90.0), 0.4).band * 0.7
		var body := st2.run(_n(), 500.0, 0.8).low * 0.8
		b[i] = (boom + saw + sizzle + body) * env
	return _normalize(b, 0.95)


## 반격 X자 참격: 두 번 가르는 바람(\ /) + 묵직한 결정타 저음.
func _counter_slash() -> PackedFloat32Array:
	var dur := 1.1
	var b := _buf(dur)
	var cuts := [[0.0, 1700.0], [0.07, 2100.0]]
	for c in cuts:
		var st := SVF.new()
		var start := int(float(c[0]) * SR)
		var n_len := int(0.16 * SR)
		for k in n_len:
			var u := float(k) / n_len
			var env := pow(sin(PI * pow(u, 0.4)), 2.0)
			var fc: float = float(c[1]) * (0.6 + 1.2 * sin(PI * pow(u, 0.6)))
			b[start + k] += st.run(_n(), fc, 0.8).band * env
	var st3 := SVF.new()
	var phase := 0.0
	var hit := int(0.14 * SR)
	for i in range(hit, b.size()):
		var t := float(i - hit) / SR
		var env := minf(t / 0.004, 1.0) * exp(-t * 4.0)
		phase += TAU * (36.0 + 110.0 * exp(-t * 16.0)) / SR
		var crunch := st3.run(_n(), 900.0, 0.6).band * exp(-t * 22.0)
		b[i] += (sin(phase) * 1.3 + crunch * 1.5) * env
	return _normalize(b, 0.95)


# ═══════════════════════════════ 벼락 ═══════════════════════════════
## 벼락: 0.15초 동안 지직거리며 내려오는 전조 → 도달 순간 찢어지는 "콰직!" + 길게 우르릉.
## 도달 시점(0.15초)은 lightning_ability.gd의 travel_time과 맞춘다.
func _lightning() -> PackedFloat32Array:
	var dur := 1.3
	var strike := 0.15
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var st3 := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var s := 0.0
		if t < strike:
			# 전조: 점점 촘촘해지는 지직거림
			var dens := 0.02 + 0.25 * pow(t / strike, 2.0)
			if rng.randf() < dens:
				s += _n() * 0.6 * (t / strike)
			s += st.run(_n(), 6000.0, 0.5).band * 0.15 * (t / strike)
		else:
			var u := t - strike
			var crack := st2.run(_n(), 3500.0 * exp(-u * 6.0) + 600.0, 0.3).band * exp(-u * 18.0) * 2.2
			var snap := _n() * exp(-u * 90.0) * 1.5
			var rumble := st3.run(_n(), 180.0, 0.7).low * exp(-u * 2.6) * (1.0 + 0.4 * sin(u * 37.0)) * 3.0
			s += crack + snap + rumble
		b[i] = s
	return _normalize(b, 0.95)


# ═══════════════════════════════ 대시 참격 전용 ═══════════════════════════════
## 대시 참격 칼날 울림 "스링—": 짧은 쇳소리 마찰 뒤 맑고 긴 금속 공명 (dash_slash.wav의 바람 소리와 겹쳐 재생).
func _dash_slash_ring() -> PackedFloat32Array:
	var dur := 0.75
	var b := _buf(dur)
	var st := SVF.new()
	# [주파수, 세기, 감쇠] — 가까운 두 배음(2950/2963)이 맥놀이로 반짝이는 울림을 만든다
	var partials := [[2950.0, 1.0, 5.5], [2963.0, 0.7, 5.5], [4420.0, 0.6, 8.0], [6080.0, 0.42, 11.0],
			[7700.0, 0.25, 15.0], [1480.0, 0.3, 4.5]]
	for i in b.size():
		var t := float(i) / SR
		var ring := 0.0
		for pt in partials:
			ring += sin(TAU * float(pt[0]) * (1.0 - 0.01 * t) * t) * float(pt[1]) * exp(-t * float(pt[2]))
		var scrape := st.run(_n(), 5200.0 + 3000.0 * minf(t / 0.03, 1.0), 0.4).band * exp(-t * 55.0) * 1.6
		b[i] = ring * minf(t / 0.003, 1.0) * 0.55 + scrape
	return _normalize(b, 0.8)


## 대시 참격 명중 "촥!": 날카로운 베임 트랜지언트 + 찢어지는 소리 + 짧은 쇳소리 + 묵직한 저음.
func _dash_slash_hit() -> PackedFloat32Array:
	var dur := 0.36
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var phase := 0.0
	for i in b.size():
		var t := float(i) / SR
		var crack := st.run(_n(), 6000.0, 0.5).high * exp(-t * 70.0) * 1.4
		var tear := st2.run(_n(), 4200.0 * exp(-t * 12.0) + 700.0, 0.6).band * exp(-t * 16.0) * 1.3
		var clink := (sin(TAU * 3500.0 * t) + 0.6 * sin(TAU * 5230.0 * t)) * exp(-t * 26.0) * 0.4
		phase += TAU * (55.0 + 90.0 * exp(-t * 20.0)) / SR
		var thump := sin(phase) * exp(-t * 13.0) * 1.1
		b[i] = (crack + tear + clink + thump) * minf(t / 0.0015, 1.0)
	return _normalize(b, 0.92)


# ═══════════════════════════════ 패기 방출 ═══════════════════════════════
## 패기 방출 (2초): 0.28초 동안 짓눌리는 압력(낮게 떨리며 차오름) → "쩌억!" 깨지는 파열음 + 땅 울리는 저음 +
## 지직거리는 검은 번개 + 으르렁거리는 왜곡음이 길게 남는다. 방출 시점(0.28초)은 haki_burst.gd의 RELEASE_AT과 맞춘다.
func _haki_burst() -> PackedFloat32Array:
	var dur := 2.0
	var rel := 0.28
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var st3 := SVF.new()
	var p_low := 0.0
	var p_growl := 0.0
	for i in b.size():
		var t := float(i) / SR
		var s := 0.0
		if t < rel:
			var u := t / rel
			p_low += TAU * (38.0 + 30.0 * u) / SR
			var trem := 0.6 + 0.4 * sin(t * TAU * (6.0 + 30.0 * u))
			s += sin(p_low) * trem * u * 0.9
			s += st.run(_n(), 200.0 + 1200.0 * u * u, 0.6).low * u * u * 1.2
		else:
			var v := t - rel
			var shatter := st2.run(_n(), 5000.0, 0.4).high * exp(-v * 26.0) * 2.0
			var glass := 0.0
			for k in 5:
				glass += sin(TAU * (3100.0 + k * 1270.0) * v) * exp(-v * (30.0 + k * 9.0))
			p_low += TAU * (30.0 + 70.0 * exp(-v * 9.0)) / SR
			var boom := sin(p_low) * exp(-v * 2.6) * 1.6
			var crackle := 0.0
			if rng.randf() < 0.06 * exp(-v * 1.8):
				crackle = _n() * 1.2 * exp(-v * 1.5)
			p_growl += TAU * 52.0 / SR
			var growl := tanh(3.0 * sin(p_growl) + st3.run(_n(), 300.0, 0.7).low * 4.0) * exp(-v * 2.4) * 0.45
			s += shatter + glass * 0.35 + boom + crackle + growl
		b[i] = s
	return _normalize(b, 0.95)


# ═══════════════════════════════ 궁극기: 월아 참격 ═══════════════════════════════
## 날아가는 반달 참격: 처음엔 낮고 느린 바람이 점점 빨라지며 높아진다 (지수 가속과 맞춤) + 낮게 깔린 울림.
func _moon_slash_fly() -> PackedFloat32Array:
	var dur := 1.1
	var b := _buf(dur)
	var st := SVF.new()
	var phase := 0.0
	for i in b.size():
		var t := float(i) / SR
		var g := minf(exp(t * 3.4) - 1.0, 25.0) / 25.0          # 0 → 1 지수 상승
		var env := minf(t / 0.03, 1.0) * (0.35 + 0.65 * g) * minf((dur - t) / 0.15, 1.0)
		var wind := st.run(_n(), 300.0 + 5200.0 * g, 0.5).band
		phase += TAU * (70.0 + 260.0 * g) / SR
		var hum := (sin(phase) + 0.4 * sin(phase * 2.0)) * 0.35
		b[i] = (wind + hum) * env
	return _normalize(b, 0.8)


## 참격이 깨지는 소리: 0.32초 동안 빨라지는 회오리 바람 → "콰앙!" 폭발 + 위로 솟는 바람 + 파편.
## 폭발 시점(0.32초)은 moon_slash.gd의 vortex_time과 맞춘다.
func _moon_slash_burst() -> PackedFloat32Array:
	var dur := 1.6
	var rel := 0.32
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var st3 := SVF.new()
	var lfo := 0.0
	var p_boom := 0.0
	for i in b.size():
		var t := float(i) / SR
		var s := 0.0
		# 깨짐 "챙" (처음 순간)
		s += st3.run(_n(), 4500.0, 0.4).high * exp(-t * 40.0) * 1.2
		if t < rel + 0.1:
			var u := minf(t / rel, 1.0)
			lfo += TAU * (4.0 + 26.0 * u) / SR
			var swirl := st.run(_n(), 700.0 + 900.0 * sin(lfo) + 1600.0 * u, 0.35).band
			s += swirl * (0.3 + 0.9 * u) * (1.0 if t < rel else maxf(1.0 - (t - rel) / 0.1, 0.0))
		if t >= rel:
			var v := t - rel
			p_boom += TAU * (34.0 + 120.0 * exp(-v * 12.0)) / SR
			var boom := sin(p_boom) * exp(-v * 3.0) * 1.8
			var crack := _n() * exp(-v * 45.0) * 1.4
			var rise := st2.run(_n(), 600.0 + 4000.0 * minf(v / 0.4, 1.0), 0.5).band * exp(-v * 3.5) * 1.1
			var debris := 0.0
			if rng.randf() < 0.04 * exp(-v * 2.5):
				debris = _n() * 0.8
			s += boom + crack + rise + debris
		b[i] = s
	return _normalize(b, 0.95)


# ═══════════════════════════════ 보스 — 월식의 기사 ═══════════════════════════════
## 거대한 낙하/내려찍기: 땅이 꺼지는 저음 붐 + 깨지는 "콰직" + 오래 굴러떨어지는 돌 부스러기.
## scale은 1이 등장 착지(가장 큼), 작을수록 짧고 가볍다.
func _boss_impact(dur: float, scale: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var st3 := SVF.new()
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		ph += TAU * (28.0 + 90.0 * exp(-t * 9.0)) / SR
		var boom := sin(ph) * exp(-t * (2.2 / scale)) * 1.6
		var crack := st.run(_n(), 1800.0, 0.5).band * exp(-t * 26.0) * 1.6
		var body := st2.run(_n(), 160.0, 0.9).low * exp(-t * (3.0 / scale)) * 2.2
		var debris := 0.0
		if rng.randf() < 0.012 * exp(-t * 1.6 / scale):
			debris = _n() * rng.randf_range(0.3, 0.9)
		var grit := st3.run(_n(), 3200.0, 0.4).band * exp(-t * 3.0 / scale) * 0.25
		b[i] = tanh((boom + crack + body + debris + grit) * 1.4)
	return _normalize(b, 0.97)


## 갑옷 발걸음: 둔탁한 쿵 + 쇳소리 짤랑.
func _boss_step() -> PackedFloat32Array:
	var b := _buf(0.3)
	var ph := 0.0
	var st := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		ph += TAU * (50.0 + 70.0 * exp(-t * 30.0)) / SR
		var thud := sin(ph) * exp(-t * 18.0)
		var clink := (sin(TAU * 2300.0 * t) * 0.5 + sin(TAU * 3470.0 * t) * 0.35) * exp(-t * 40.0) * 0.4
		var dirt := st.run(_n(), 900.0, 0.6).band * exp(-t * 35.0) * 0.6
		b[i] = thud + clink + dirt
	return _normalize(b, 0.85)


## 등장 포효: 투구 안에서 울리는 낮은 쇳빛 울부짖음 — 톱니파에 모음 공명 + 쇠 울림, 점점 커졌다 끊긴다.
func _boss_roar() -> PackedFloat32Array:
	var dur := 1.7
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var st3 := SVF.new()
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var u := t / dur
		var f := 62.0 + 18.0 * sin(PI * u) + rng.randf_range(-3.0, 3.0) + 4.0 * sin(TAU * 7.0 * t)
		ph += f / SR
		var saw := fposmod(ph, 1.0) * 2.0 - 1.0
		var src := saw + _n() * 0.45
		var vowel := st.run(src, 520.0 + 260.0 * sin(PI * u), 0.25).band + st2.run(src, 1250.0, 0.35).band * 0.6
		var ring := (sin(TAU * 410.0 * t) + sin(TAU * 637.0 * t) * 0.6) * 0.12
		var hiss := st3.run(_n(), 2600.0, 0.5).band * 0.25
		var env := clampf(t / 0.25, 0.0, 1.0) * clampf((dur - t) / 0.35, 0.0, 1.0)
		b[i] = tanh((vowel * 1.6 + ring + hiss) * env * 2.2)
	return _normalize(b, 0.9)


## 추방: 공허로 빨려드는 "쓔우욱 — 퐁" (역방향으로 차오르다 끊긴다).
func _banish() -> PackedFloat32Array:
	var dur := 0.75
	var b := _buf(dur)
	var st := SVF.new()
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var u := clampf(t / 0.55, 0.0, 1.0)
		var env := pow(u, 1.8) * (1.0 if t < 0.55 else exp(-(t - 0.55) * 40.0))
		var suck := st.run(_n(), 300.0 + 3800.0 * u * u, 0.4).band
		ph += TAU * (90.0 + 600.0 * u * u) / SR
		var s := (suck + sin(ph) * 0.5) * env
		if t >= 0.55:
			s += sin(TAU * 140.0 * t) * exp(-(t - 0.55) * 25.0) * 0.7
		b[i] = s
	return _normalize(b, 0.8)


## 지진 울림: 낮게 흔들리는 땅울림 + 돌가루 — 보스 등장 직전.
func _rumble() -> PackedFloat32Array:
	var dur := 2.4
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var u := t / dur
		var env := clampf(t / 1.2, 0.0, 1.0) * clampf((dur - t) / 0.15, 0.0, 1.0)
		var low := st.run(_n(), 70.0 + 30.0 * sin(TAU * 1.3 * t), 0.7).low * 3.0
		var wob := 0.7 + 0.3 * sin(TAU * (5.0 + 8.0 * u) * t)
		var grit := 0.0
		if rng.randf() < 0.004 + 0.01 * u:
			grit = _n() * 0.4
		grit += st2.run(_n(), 2500.0, 0.5).band * 0.08 * u
		b[i] = tanh((low * wob + grit) * env * 1.5)
	return _normalize(b, 0.85)


## 순간이동: 공기가 찢기며 사라지는 "쯧—" + 아래로 꺼지는 공허음.
func _boss_blink() -> PackedFloat32Array:
	var dur := 0.4
	var b := _buf(dur)
	var st := SVF.new()
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var zap := st.run(_n(), 6000.0 * exp(-t * 9.0) + 400.0, 0.3).band * exp(-t * 9.0)
		ph += TAU * (900.0 * exp(-t * 14.0) + 80.0) / SR
		b[i] = zap + sin(ph) * exp(-t * 10.0) * 0.6
	return _normalize(b, 0.8)


## 반격 자세: 칼날이 우는 "스릉—" (위로 휘어 올라가는 금속 울림).
func _guard_ring() -> PackedFloat32Array:
	var dur := 0.55
	var b := _buf(dur)
	var st := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var bend := 1.0 + 0.06 * (1.0 - exp(-t * 10.0))
		var s := sin(TAU * 1480.0 * bend * t) * 0.7 + sin(TAU * 2960.0 * bend * t) * 0.3 + sin(TAU * 3700.0 * t) * 0.15
		var scrape := st.run(_n(), 5000.0 + 3000.0 * t, 0.3).band * exp(-t * 14.0) * 0.8
		b[i] = (s * minf(t / 0.01, 1.0) * exp(-t * 4.5) + scrape)
	return _normalize(b, 0.75)


## 반격 자세에 걸림: 묵직한 막기 "깡!" — 패링보다 낮고 두껍다.
func _guard_clang() -> PackedFloat32Array:
	var b := _buf(0.8)
	var ratios := [1.0, 2.1, 3.3, 4.7, 6.2]
	var amps := [1.0, 0.7, 0.5, 0.3, 0.2]
	var st := SVF.new()
	for i in b.size():
		var t := float(i) / SR
		var s := 0.0
		for k in ratios.size():
			s += sin(TAU * 620.0 * ratios[k] * t) * amps[k] * exp(-t * (4.0 + k * 2.5))
		s *= 0.5
		s += st.run(_n(), 3800.0, 0.5).high * exp(-t * 120.0) * 1.3
		s += sin(TAU * (48.0 + 60.0 * exp(-t * 18.0)) * t) * exp(-t * 8.0) * 0.8
		b[i] = tanh(s * 1.5)
	return _normalize(b, 0.95)


## 돌진 준비: 바닥을 긁는 쇳소리 + 차오르는 엔진 같은 저음.
func _rush_charge() -> PackedFloat32Array:
	var dur := 1.0
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var ph := 0.0
	for i in b.size():
		var t := float(i) / SR
		var u := t / dur
		var scrape := st.run(_n(), 2200.0 + 1800.0 * sin(TAU * 11.0 * t), 1.2).band * (0.4 + 0.6 * u)
		ph += TAU * (45.0 + 70.0 * u * u) / SR
		var growl := (sin(ph) + 0.5 * sin(ph * 2.0)) * (0.3 + 0.7 * u)
		var hiss := st2.run(_n(), 600.0, 0.6).band * 0.4 * u
		var env := clampf(t / 0.05, 0.0, 1.0) * clampf((dur - t) / 0.03, 0.0, 1.0)
		b[i] = tanh((scrape * 0.8 + growl + hiss) * env * 1.4)
	return _normalize(b, 0.85)


## 보스 쓰러짐: 갑옷이 무너지는 쇳소리 + 긴 공허의 붕괴음 + 거대한 저음.
func _boss_death() -> PackedFloat32Array:
	var dur := 2.8
	var b := _buf(dur)
	var st := SVF.new()
	var st2 := SVF.new()
	var ph := 0.0
	var ph2 := 0.0
	for i in b.size():
		var t := float(i) / SR
		ph += TAU * (30.0 + 80.0 * exp(-t * 4.0)) / SR
		var boom := sin(ph) * exp(-t * 1.5) * 1.4
		var fall := st.run(_n(), 3000.0 * exp(-t * 1.2) + 200.0, 0.4).band * exp(-t * 1.1)
		var metal := 0.0
		if rng.randf() < 0.006 * exp(-t * 1.5):
			metal = _n() * 0.8
		ph2 += TAU * (520.0 * exp(-t * 0.9) + 60.0) / SR
		var void_tone := sin(ph2) * exp(-t * 1.2) * 0.35
		var ring := (sin(TAU * 880.0 * t) + sin(TAU * 1323.0 * t) * 0.5) * exp(-t * 2.0) * 0.12
		var hiss := st2.run(_n(), 5000.0, 0.5).band * exp(-t * 6.0) * 0.4
		b[i] = tanh((boom + fall + metal + void_tone + ring + hiss) * 1.3)
	return _normalize(b, 0.95)


## 보스전 음악: 140BPM, 16마디 루프. D단조의 무거운 곡 — 두 박마다 쿵쿵 울리는 킥, 질주하는 16분 베이스,
## 낮은 성가대 같은 패드, 후반 8마디에 날카로운 아르페지오. 음 꼬리는 앞쪽으로 감싸 이음매 없이 반복된다.
const BOSS_BEAT := 60.0 / 140.0
const BOSS_CHORDS := [
	[38, 41, 45], [38, 41, 45], [34, 38, 41], [37, 40, 45], [38, 41, 45], [39, 43, 46], [34, 38, 41], [37, 40, 45],
	[38, 41, 45], [36, 39, 43], [34, 38, 41], [37, 40, 45], [38, 41, 45], [39, 43, 46], [41, 45, 48], [37, 40, 45],
]


func _boss_music() -> PackedFloat32Array:
	var sr := MUSIC_SR
	var beat := BOSS_BEAT
	var total := int(beat * 4.0 * BOSS_CHORDS.size() * sr)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var bar_len := beat * 4.0
	for bar in BOSS_CHORDS.size():
		var chord: Array = BOSS_CHORDS[bar]
		var t0 := bar * bar_len
		# 베이스: 16분음 질주 (박마다 옥타브 강세)
		for k in 16:
			var note: float = chord[0] - 12 + (12 if k % 4 == 2 else 0)
			_add_bass(mix, t0 + k * beat * 0.25, beat * 0.2, _midi(note), 0.24 if k % 4 == 0 else 0.17)
		# 낮은 성가대 패드 (두 옥타브에 걸쳐)
		for m in chord:
			_add_pad(mix, t0, bar_len, _midi(m + 12), 0.05)
			_add_pad(mix, t0, bar_len, _midi(m + 24), 0.025)
		# 드럼: 무거운 킥 패턴 + 2·4박 스네어 + 8분 하이햇
		for beat_i in 4:
			var tb := t0 + beat_i * beat
			if beat_i == 0 or beat_i == 2:
				_add_kick(mix, tb, 0.95)
				_add_kick(mix, tb + beat * 0.5, 0.55)
			else:
				_add_snare(mix, tb, 0.55)
			_add_hat(mix, tb + beat * 0.5, 0.14)
			_add_hat(mix, tb, 0.07)
		if bar % 4 == 3:
			for k in 4:
				_add_snare(mix, t0 + beat * 3.0 + k * beat * 0.25, 0.25 + 0.08 * k)
		# 후반 아르페지오
		if bar >= 8:
			var arp := [chord[0] + 24, chord[2] + 24, chord[1] + 36, chord[2] + 24]
			for k in 16:
				_add_pluck(mix, t0 + k * beat * 0.25, beat * 0.2, _midi(arp[k % 4]), 0.06)
	var dl := int(beat * 0.75 * sr)
	var wet := mix.duplicate()
	for pass_i in 2:
		for i in total:
			wet[i] = mix[i] + wet[(i - dl + total) % total] * 0.28
	for i in total:
		mix[i] = tanh((mix[i] * 0.85 + (wet[i] - mix[i]) * 0.3) * 1.4)
	return _normalize(mix, 0.8)
