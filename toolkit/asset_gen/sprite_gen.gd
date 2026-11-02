extends SceneTree

## 오프라인 픽셀아트 생성기 (개발 도구 — 게임 실행에는 필요 없다).
## 캐릭터 시트, 방 배경, 소품 PNG를 코드로 그려 assets/temporary/ 아래에 저장한다.
## 결과물은 커밋되어 있으므로 아트를 다시 뽑을 때만 실행한다:
##   Godot --headless --path . --script res://toolkit/asset_gen/sprite_gen.gd
## 일부만 다시 그리려면 생성기 이름을 넘긴다 (_gen_ 뒤 이름, 다른 그림 파일은 건드리지 않는다):
##   Godot --headless --path . --script res://toolkit/asset_gen/sprite_gen.gd -- infantry forest
## 같은 seed를 쓰므로 다시 실행해도 같은 그림이 나온다.
## 모든 아트는 "1 아트 픽셀 = 화면 2px" 밀도로 그리고, 씬에서 scale 2로 쓴다.

const OUT := "res://assets/temporary/"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 7
	for dir in ["characters/player", "characters/grunt", "characters/duelist", "characters/watcher", "characters/knight",
			"characters/infantry", "characters/assassin", "characters/crossbowman", "characters/giant", "environment", "effects"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + dir))
	var only := OS.get_cmdline_user_args()
	if not only.is_empty():
		for gen_name in only:
			call("_gen_" + gen_name)
		print("[sprite_gen] done (", only, ")")
		quit()
		return
	_gen_player()
	_gen_grunt()
	_gen_duelist()
	_gen_room()
	_gen_props()
	_gen_effects()   # 맨 뒤에 둔다 — rng 소비 순서가 바뀌면 기존 그림이 달라진다
	_gen_watcher()   # 새 생성기는 항상 이 아래에 추가한다 (같은 이유)
	_gen_knight()
	_gen_infantry()  # Phase1 생성기는 각자 rng.seed를 다시 정해 단독 실행과 같은 그림이 나온다
	_gen_forest()
	_gen_assassin()
	_gen_crossbowman()
	_gen_giant()
	print("[sprite_gen] done")
	quit()


# ═══════════════════════════════ 공용 헬퍼 ═══════════════════════════════
func _new(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _c(r: int, g: int, b: int, a: int = 255) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a / 255.0)


func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _px(img: Image, x: int, y: int) -> Color:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		return img.get_pixel(x, y)
	return Color(0, 0, 0, 0)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(img, xx, yy, c)


func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_put(img, x, y, c)


func _poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	var minp := pts[0]
	var maxp := pts[0]
	for p in pts:
		minp = minp.min(p)
		maxp = maxp.max(p)
	for y in range(floori(minp.y), ceili(maxp.y) + 1):
		for x in range(floori(minp.x), ceili(maxp.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				_put(img, x, y, c)


func _line(img: Image, a: Vector2, b: Vector2, width: float, c: Color) -> void:
	var steps := int(maxf(a.distance_to(b) * 2.0, 1.0))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		_ellipse(img, p.x, p.y, width * 0.5, width * 0.5, c)


## 투명 픽셀 중 불투명 픽셀과 4방향으로 맞닿은 곳에 외곽선을 찍는다.
func _outline(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var marks: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := _px(img, x + d.x, y + d.y)
				if n.a > 0.0 and not n.is_equal_approx(c):
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixel(m.x, m.y, c)


## 좌상단 광원: 위/왼쪽이 비어 있는 가장자리는 밝게, 아래/오른쪽이 비어 있는 가장자리는 어둡게.
func _shade_edges(img: Image, light: float, dark: float, skip: Array = []) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := src.get_pixel(x, y)
			if c.a <= 0.0 or _in_colors(c, skip):
				continue
			if _px(src, x - 1, y).a <= 0.0 or _px(src, x, y - 1).a <= 0.0:
				img.set_pixel(x, y, c.lightened(light))
			elif _px(src, x + 1, y).a <= 0.0 or _px(src, x, y + 1).a <= 0.0:
				img.set_pixel(x, y, c.darkened(dark))


func _in_colors(c: Color, list: Array) -> bool:
	for k in list:
		if c.is_equal_approx(k):
			return true
	return false


func _sheet(frames: Array[Image]) -> Image:
	var fw := frames[0].get_width()
	var fh := frames[0].get_height()
	var sheet := _new(fw * frames.size(), fh)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, fw, fh), Vector2i(i * fw, 0))
	return sheet


func _from_ascii(rows: Array, pal: Dictionary, pad: int = 0) -> Image:
	var w: int = 0
	for r in rows:
		w = maxi(w, (r as String).length())
	var img := _new(w + pad * 2, rows.size() + pad * 2)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x + pad, y + pad, pal[ch])
	return img


func _save(img: Image, path: String) -> void:
	var err := img.save_png(OUT + path)
	print("  saved ", path, " ", img.get_size(), " err=", err)


# ═══════════════════════════════ 플레이어 (검은 고양이) ═══════════════════════════════
# 원본 일러스트(Voider Player01.png)를 28px 격자로 다운샘플한 뒤 손으로 다듬은 도트.
# 검은 손에서 분리해 따로(player_sword.png) 그려, 휘두르는 애니메이션을 만든다.
# 다리(38~39행)와 망토 꼬리(31행 이하, 9열 이하)는 프레임마다 코드로 움직인다.
const CAT := [
	"............#.........................",
	"............#.........#...............",
	"............##........##..............",
	"............###......###..............",
	"............####.....###..............",
	"............#####....####.............",
	"............######..#####.............",
	"............##############............",
	"............##############............",
	"............##############............",
	"............##############............",
	"............###############...........",
	"...........#################..........",
	"...........#################..........",
	"...........#################..........",
	"...........#################..........",
	"...........#########WY####Y#..........",
	"...........########YYYY###Y#..........",
	"...........#########yYy#####..........",
	"...........#############O###..........",
	"...........P################..........",
	"..........PPPPPP###########...........",
	"..........pppppppppppPP#PPP...........",
	"..........PPPPPPPPPPPPPPPPPP..........",
	"..........dddPPPPPPPPPPPPPP...........",
	"..........PPPPddddPPPPPPPPd...........",
	"..........PPPPPPPPPPPPPPPPP...........",
	"..........PPdddddPPPPPPPPPd...........",
	".........PPPPPPPPPd#PPPPPPP...........",
	"........PPPPPPPPPP####PP#PP...........",
	".......PPPPPPPP###########............",
	"..PPPPPPPPPdd#############............",
	".PPPPPPPddddd#############............",
	"PPPPPPdddddddd############............",
	"..PPPddddddddd##########..............",
	".PPPddddddddd###########..............",
	".PP..ddddddddd#########d..............",
	".P....ddd..dddd########...............",
	"......................................",
	"......................................",
]


func _gen_player() -> void:
	var pal := {
		"#": _c(20, 17, 28), "P": _c(124, 58, 130), "p": _c(160, 88, 166), "d": _c(66, 26, 72),
		"Y": _c(255, 206, 44), "y": _c(214, 140, 22), "W": _c(255, 250, 222), "O": _c(244, 150, 72),
	}
	var rim := _c(66, 58, 94)
	var outline := _c(9, 7, 14)
	# 프레임: [다리 L 오프셋, 다리 R 오프셋, 망토 꼬리 dy, 눈 감음]
	var specs := [
		[Vector2i(0, 0), Vector2i(0, 0), 0, false],     # 0 idle
		[Vector2i(1, -1), Vector2i(-1, 0), -1, false],  # 1 run
		[Vector2i(0, 0), Vector2i(0, 0), 0, false],     # 2 run (passing)
		[Vector2i(-1, 0), Vector2i(1, -1), -1, false],  # 3 run
		[Vector2i(0, 0), Vector2i(0, 0), 0, false],     # 4 run (passing)
		[Vector2i(1, -1), Vector2i(0, -1), 1, false],   # 5 jump (다리 접기, 망토 아래로)
		[Vector2i(-1, 0), Vector2i(1, 0), -2, false],   # 6 fall (다리 벌림, 망토 위로)
		[Vector2i(0, 0), Vector2i(1, 0), -1, true],     # 7 hurt
		[Vector2i(-2, -1), Vector2i(1, 0), -2, false],  # 8 dash / lunge
	]
	var frames: Array[Image] = []
	for s in specs:
		var grid: Array = []
		for r in CAT:
			var chars: Array = []
			for ch in (r as String):
				chars.append(ch)
			grid.append(chars)
		# 망토 꼬리 흔들기
		var cape_dy: int = s[2]
		if cape_dy != 0:
			var moved: Array = []
			for y in range(31, 38):
				for x in range(0, 10):
					if grid[y][x] != ".":
						moved.append([x, y, grid[y][x]])
						grid[y][x] = "."
			for m in moved:
				var ny: int = clampi(m[1] + cape_dy, 0, 39)
				grid[ny][m[0]] = m[2]
		# 다리 (3x2 두 개)
		var legs := [[15, s[0]], [20, s[1]]]
		for leg in legs:
			var off: Vector2i = leg[1]
			for ly in 2:
				for lx in 3:
					grid[38 + ly + off.y][leg[0] + lx + off.x] = "#"
		# 피격: 눈을 질끈 감는다
		if s[3]:
			for y in range(16, 19):
				for x in range(18, 28):
					if grid[y][x] in ["Y", "y", "W"]:
						grid[y][x] = "#"
			for x in range(19, 23):
				grid[17][x] = "y"
			grid[17][26] = "y"
		var rows: Array = []
		for g in grid:
			rows.append("".join(g))
		var img := _from_ascii(rows, pal, 1)
		# 좌상단 테두리 빛 — 어두운 배경에서도 검은 실루엣이 읽히게
		var src := img.duplicate() as Image
		for y in img.get_height():
			for x in img.get_width():
				if src.get_pixel(x, y).is_equal_approx(pal["#"]):
					if _px(src, x - 1, y).a <= 0.0 or _px(src, x, y - 1).a <= 0.0:
						img.set_pixel(x, y, rim)
		_outline(img, outline)
		frames.append(img)
	_save(_sheet(frames), "characters/player/player_body.png")

	# 검 (오른쪽을 향함, 손잡이 (1,2)가 회전축)
	var sword := _from_ascii([
		"...g................",
		"kk.gLLLLLLLLLLLLLL..",
		"kkkgSSSSSSSSSSSSSSSW",
		"kk.gssssssssssssss..",
		"...g................",
	], {
		"k": _c(30, 22, 40), "g": _c(96, 80, 122), "L": _c(214, 196, 236),
		"S": _c(132, 110, 160), "s": _c(58, 46, 78), "W": _c(255, 255, 255),
	}, 1)
	_outline(sword, outline)
	_save(sword, "characters/player/player_sword.png")


# ═══════════════════════════════ 잡몹 (공허 임프) ═══════════════════════════════
func _gen_grunt() -> void:
	var specs := [
		{},                                                                   # 0 idle a
		{"sx": 1.05, "sy": 0.94, "dy": 0.6},                                  # 1 idle b
		{"f1": Vector2(1, -1), "f2": Vector2(-1, 0), "dy": -0.6},             # 2 walk
		{"f1": Vector2(0, 0), "f2": Vector2(0, 0)},                           # 3 walk
		{"f1": Vector2(-1, 0), "f2": Vector2(1, -1), "dy": -0.6},             # 4 walk
		{"f1": Vector2(0, 0), "f2": Vector2(0, 0)},                           # 5 walk
		{"sx": 1.14, "sy": 0.84, "dy": 1.2, "eyes": "angry"},                 # 6 windup (웅크림)
		{"sx": 1.18, "sy": 0.9, "dx": 1.5, "eyes": "angry", "mouth": "open",
				"f1": Vector2(-2, 0), "f2": Vector2(1, -1)},                  # 7 lunge (물기)
		{"sx": 0.92, "sy": 1.06, "eyes": "x", "mouth": "small"},              # 8 hurt
	]
	var frames: Array[Image] = []
	for s in specs:
		frames.append(_grunt_frame(s))
	_save(_sheet(frames), "characters/grunt/grunt.png")


func _grunt_frame(p: Dictionary) -> Image:
	var img := _new(30, 26)
	var base := _c(44, 30, 64)
	var top := _c(70, 48, 98)
	var dark := _c(26, 17, 40)
	var horn := _c(150, 112, 170)
	var horn_d := _c(92, 64, 112)
	var foot := _c(22, 14, 32)
	var eye := _c(255, 214, 60)
	var eye_d := _c(232, 128, 30)
	var mouth := _c(70, 10, 28)
	var tooth := _c(240, 232, 214)
	var sx: float = p.get("sx", 1.0)
	var sy: float = p.get("sy", 1.0)
	var cx: float = 15.0 + p.get("dx", 0.0)
	var ground := 24.0
	var rx := 9.5 * sx
	var ry := 7.6 * sy
	var cy: float = ground - 1.5 - ry + p.get("dy", 0.0)
	var f1: Vector2 = p.get("f1", Vector2.ZERO)
	var f2: Vector2 = p.get("f2", Vector2.ZERO)

	# 뿔 (몸 뒤에)
	_poly(img, PackedVector2Array([Vector2(cx - 6, cy - ry + 3), Vector2(cx - 10, cy - ry - 4),
			Vector2(cx - 7.5, cy - ry - 0.5), Vector2(cx - 2.5, cy - ry + 1.5)]), horn_d)
	_poly(img, PackedVector2Array([Vector2(cx + 3, cy - ry + 1.5), Vector2(cx + 8, cy - ry - 4),
			Vector2(cx + 7, cy - ry + 0.5), Vector2(cx + 7, cy - ry + 3)]), horn)
	# 발
	_ellipse(img, cx - 4 + f1.x, ground - 1.0 + f1.y, 2.6, 1.7, foot)
	_ellipse(img, cx + 4 + f2.x, ground - 1.0 + f2.y, 2.6, 1.7, foot)
	# 몸통 (위는 밝고 아래는 어둡게)
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			var c := base
			if ny < -0.5 + nx * 0.2:
				c = top
			elif ny > 0.45:
				c = dark
			_put(img, x, y, c)
	# 등줄기 가시
	for i in 3:
		var bx := cx - 6.0 + i * 3.0
		var by := cy - ry * sqrt(maxf(1.0 - pow((bx - cx) / rx, 2.0), 0.0))
		_put(img, int(bx), int(by) - 1, top.lightened(0.15))
	# 눈 (오른쪽을 본다)
	var ex := int(cx + 1.0)
	var ey := int(cy - 1.0)
	match p.get("eyes", "open"):
		"x":
			for e in [ex, ex + 5]:
				_put(img, e - 1, ey - 1, eye); _put(img, e + 1, ey - 1, eye)
				_put(img, e, ey, eye)
				_put(img, e - 1, ey + 1, eye); _put(img, e + 1, ey + 1, eye)
		"angry":
			for e in [ex, ex + 5]:
				_rect(img, e - 1, ey, 3, 2, eye)
				_put(img, e - 1, ey + 1, eye_d); _put(img, e + 1, ey + 1, eye_d)
			_put(img, ex - 1, ey - 1, dark); _put(img, ex, ey - 1, dark)
			_put(img, ex + 5, ey - 1, dark); _put(img, ex + 6, ey - 1, dark)
			_put(img, ex + 1, ey, dark); _put(img, ex + 4, ey, dark)
		_:
			for e in [ex, ex + 5]:
				_rect(img, e - 1, ey - 1, 2, 3, eye)
				_put(img, e - 1, ey + 1, eye_d); _put(img, e, ey + 1, eye_d)
				_put(img, e - 1, ey - 1, Color(1, 1, 0.9))
	# 입
	var my := int(cy + 3.0)
	match p.get("mouth", "closed"):
		"open":
			_rect(img, ex - 1, my - 1, 8, 4, mouth)
			for i in 4:
				_put(img, ex - 1 + i * 2, my - 1, tooth)
				_put(img, ex + i * 2, my + 2, tooth)
		"small":
			_rect(img, ex + 1, my, 3, 2, mouth)
		_:
			for i in 5:
				_put(img, ex + i, my + (1 if i % 2 == 0 else 0), dark)
	_shade_edges(img, 0.18, 0.2, [eye, eye_d, tooth])
	_outline(img, _c(8, 5, 14))
	return img


# ═══════════════════════════════ 듀얼리스트 (망토 검사) ═══════════════════════════════
## 손(칼 회전축) 위치는 duelist.gd의 HAND 표와 맞춘다 (crouch/lean에 따라 이동).
func _gen_duelist() -> void:
	var specs := [
		{},                                                     # 0 idle a
		{"breath": 1, "flutter": 1.0},                          # 1 idle b
		{"stride": 3.0, "bob": -1, "flutter": 1.5},             # 2 walk
		{"stride": 0.0, "flutter": 0.5},                        # 3 walk
		{"stride": -3.0, "bob": -1, "flutter": 1.5},            # 4 walk
		{"stride": 0.0, "flutter": 0.5},                        # 5 walk
		{"crouch": 3, "lean": -2.5, "stride": 3.5, "flutter": 0.0},          # 6 windup (몸을 낮추고 뒤로 젖힘)
		{"crouch": 2, "lean": 4.0, "stride": 6.0, "flutter": 3.0},           # 7 strike (앞으로 내딛음)
		{"crouch": 1, "lean": -4.0, "stride": -2.0, "flutter": 2.0, "eye": 0.35},  # 8 stagger
	]
	var frames: Array[Image] = []
	for s in specs:
		frames.append(_duelist_frame(s))
	_save(_sheet(frames), "characters/duelist/duelist.png")

	var blade := _from_ascii([
		"...g..........................",
		"hhhgBBBBBBBBBBBBBBBBBBBBBBBB..",
		"hhhgSSSSSSSSSSSSSSSSSSSSSSSSSE",
		"hhhgssssssssssssssssssssssss..",
		"...g..........................",
	], {
		"h": _c(70, 22, 36), "g": _c(186, 146, 70), "B": _c(240, 242, 255),
		"S": _c(178, 182, 202), "s": _c(96, 100, 122), "E": _c(255, 255, 255),
	}, 1)
	_outline(blade, _c(10, 5, 10))
	_save(blade, "characters/duelist/duelist_blade.png")


func _duelist_frame(p: Dictionary) -> Image:
	var img := _new(36, 44)
	var cloak := _c(58, 22, 38)
	var cloak_d := _c(36, 13, 24)
	var trim := _c(150, 30, 48)
	var hood := _c(46, 18, 32)
	var face := _c(8, 4, 10)
	var leg := _c(26, 14, 22)
	var boot := _c(40, 24, 32)
	var scarf := _c(170, 36, 52)
	var eye_on: float = p.get("eye", 1.0)
	var eye := Color(1.0, 0.2, 0.26).lerp(_c(80, 20, 30), 1.0 - eye_on)
	var crouch: float = p.get("crouch", 0) + p.get("breath", 0) * 0.5
	var lean: float = p.get("lean", 0.0)
	var stride: float = p.get("stride", 0.0)
	var flutter: float = p.get("flutter", 0.0)
	var bob: float = p.get("bob", 0)
	var ground := 42.0
	var cx := 17.0
	var hip_y := 30.0 + crouch + bob
	# 기울임: 엉덩이 위쪽 점일수록 lean만큼 앞으로 민다.
	var sh := func(v: Vector2) -> Vector2:
		var y := v.y + crouch + bob
		var t := clampf((hip_y - y) / 26.0, 0.0, 1.0)
		return Vector2(v.x + lean * t, y)

	# 스카프 꼬리 (가장 뒤)
	var n: Vector2 = sh.call(Vector2(cx - 4, 14))
	_poly(img, PackedVector2Array([n, n + Vector2(-8 - flutter, 1 - flutter),
			n + Vector2(-10 - flutter * 1.5, 1.5 - flutter * 0.6), n + Vector2(-5, 3), n + Vector2(1, 2.5)]), scarf)
	_poly(img, PackedVector2Array([n + Vector2(0, 2), n + Vector2(-6 - flutter, 4 - flutter * 0.4),
			n + Vector2(-7 - flutter, 5.5 - flutter * 0.3), n + Vector2(1, 4)]), scarf.darkened(0.3))
	# 다리
	var back_foot := Vector2(cx - 2 - stride, ground - 1)
	var front_foot := Vector2(cx + 3 + stride, ground - 1)
	_line(img, Vector2(cx - 1, hip_y), back_foot, 3.2, leg.darkened(0.25))
	_line(img, Vector2(cx + 2, hip_y), front_foot, 3.2, leg)
	_rect(img, int(back_foot.x) - 2, int(ground) - 2, 5, 2, boot.darkened(0.25))
	_rect(img, int(front_foot.x) - 1, int(ground) - 2, 5, 2, boot)
	# 망토 몸통 (밑단은 너덜너덜)
	var body := PackedVector2Array()
	body.append(sh.call(Vector2(cx - 6, 13)))
	body.append(sh.call(Vector2(cx + 5, 13)))
	body.append(sh.call(Vector2(cx + 7, 22)))
	var hem := [Vector2(cx + 8, 33), Vector2(cx + 6, 31), Vector2(cx + 4, 34), Vector2(cx + 1, 31),
			Vector2(cx - 2, 34), Vector2(cx - 5, 31), Vector2(cx - 8 - flutter, 34 - flutter * 0.5),
			Vector2(cx - 8 - flutter * 0.5, 28)]
	for h in hem:
		body.append(sh.call(h))
	body.append(sh.call(Vector2(cx - 8, 20)))
	_poly(img, body, cloak)
	# 망토 뒤쪽 그늘
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.is_equal_approx(cloak):
				var front: Vector2 = sh.call(Vector2(cx, y - crouch - bob))
				if x < front.x - 3:
					img.set_pixel(x, y, cloak_d)
	# 앞섶 장식선
	for y in range(15, 31):
		var a: Vector2 = sh.call(Vector2(cx + 3, y))
		_put(img, int(a.x), int(a.y), trim)
	# 두건
	var hc: Vector2 = sh.call(Vector2(cx + 1, 8))
	_ellipse(img, hc.x, hc.y, 6.2, 6.6, hood)
	_poly(img, PackedVector2Array([hc + Vector2(-5, -3), hc + Vector2(-9, -7), hc + Vector2(-2, -6)]), hood)
	# 얼굴 그림자 + 붉은 외눈
	_ellipse(img, hc.x + 2.2, hc.y + 1.0, 3.6, 3.8, face)
	_rect(img, int(hc.x + 2.5), int(hc.y + 0.5), 2, 1, eye)
	if eye_on > 0.6:
		_put(img, int(hc.x + 3.5), int(hc.y + 0.5), Color(1, 0.75, 0.75))
	# 어깨 망토 (두건 아래 짧은 케이프)
	var s0: Vector2 = sh.call(Vector2(cx - 7, 14))
	var s1: Vector2 = sh.call(Vector2(cx + 6, 14))
	_poly(img, PackedVector2Array([s0 + Vector2(1, -1), s1 + Vector2(-1, -1), s1 + Vector2(1, 4),
			s0 + Vector2(-1, 5)]), trim.darkened(0.35))
	_shade_edges(img, 0.22, 0.25, [eye, face, Color(1, 0.75, 0.75)])
	_outline(img, _c(8, 3, 8))
	return img


# ═══════════════════════════════ 방 (달빛 성소) ═══════════════════════════════
# 월드 좌표 ↔ 셀: 셀 1개 = 2px. 뒷벽은 x[-1000,1000], y[-800,0] 영역.
const WALL_W := 1000
const WALL_H := 400
const WINDOWS := [290, 500, 710]          # 창문 중심 셀 x (월드 -420, 0, 420)
const PILLARS := [185, 395, 605, 815]     # 기둥 중심 셀 x (월드 ±630, ±210)


func _gen_room() -> void:
	_gen_backwall()
	_gen_sky()
	_gen_floor()
	_gen_side_wall()
	_gen_ledge()


func _stone(base: Color, var_amt: float) -> Color:
	var v := rng.randf_range(-var_amt, var_amt)
	var h := rng.randf_range(-0.01, 0.01)
	return Color(base.r + v + h, base.g + v, base.b + v - h)


func _brick_field(img: Image, x0: int, y0: int, w: int, h: int, row_h: int, wmin: int, wmax: int,
		base: Color, mortar: Color, crack_chance: float) -> void:
	var y := y0
	while y < y0 + h:
		var x := x0 - rng.randi_range(0, wmax)
		while x < x0 + w:
			var bw := rng.randi_range(wmin, wmax)
			_brick(img, x, y, bw, row_h, _stone(base, 0.018), mortar, crack_chance, Rect2i(x0, y0, w, h))
			x += bw
		y += row_h


func _brick(img: Image, x: int, y: int, w: int, h: int, c: Color, mortar: Color, crack_chance: float,
		clip: Rect2i) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if not clip.has_point(Vector2i(xx, yy)):
				continue
			var col := c
			if yy == y or xx == x:
				col = mortar
			elif yy == y + 1:
				col = c.lightened(0.12)
			elif xx == x + 1:
				col = c.lightened(0.05)
			elif yy == y + h - 1 or xx == x + w - 1:
				col = c.darkened(0.18)
			else:
				var nv := rng.randf_range(-0.012, 0.012)
				col = Color(c.r + nv, c.g + nv, c.b + nv)
				if rng.randf() < 0.03:
					col = col.darkened(0.12)
			_put(img, xx, yy, col)
	# 깨진 모서리
	if rng.randf() < 0.12 and clip.has_point(Vector2i(x + 1, y + 1)):
		_rect(img, x + 1, y + 1, 2, 2, mortar)
	# 금
	if rng.randf() < crack_chance:
		var p := Vector2i(x + rng.randi_range(3, maxi(w - 4, 4)), y + 2)
		for i in rng.randi_range(4, 9):
			if clip.has_point(p) and p.x > x + 1 and p.x < x + w - 1 and p.y < y + h - 1:
				_put(img, p.x, p.y, c.darkened(0.35))
			p += Vector2i(rng.randi_range(-1, 1), 1)


func _window_hole(x: int, y: int, wx: int) -> bool:
	var half := 28
	if x < wx - half or x > wx + half - 1:
		return false
	if y >= 150 and y <= 270:
		return true
	if y < 150:
		return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(wx, 150)) <= half
	return false


func _gen_backwall() -> void:
	var img := _new(WALL_W, WALL_H)
	var mortar := _c(22, 22, 34)
	_brick_field(img, 0, 0, WALL_W, WALL_H, 12, 18, 32, _c(48, 50, 72), mortar, 0.07)

	# 아치형 천장(기둥 사이) — 아치 위는 어두운 볼트, 아치 띠는 밝은 돌
	var spans := [[0, PILLARS[0] - 14]]
	for i in PILLARS.size() - 1:
		spans.append([PILLARS[i] + 14, PILLARS[i + 1] - 14])
	spans.append([PILLARS[-1] + 14, WALL_W])
	for sp in spans:
		var a: int = sp[0]
		var b: int = sp[1]
		var mid := (a + b) * 0.5
		var half := (b - a) * 0.5
		for x in range(a, b):
			var t := (x + 0.5 - mid) / half
			var ya := 96.0 - 58.0 * sqrt(maxf(1.0 - t * t, 0.0))
			for y in range(0, 100):
				var c := img.get_pixel(x, y)
				if y < ya:
					img.set_pixel(x, y, c.darkened(0.45))
				elif y < ya + 5.0:
					var seg := int((atan2(y - 96.0, x - mid) + PI) * 18.0)
					var band := _c(78, 80, 108) if seg % 2 == 0 else _c(70, 72, 98)
					if y < ya + 1.0:
						band = band.lightened(0.18)
					elif y >= ya + 4.0:
						band = band.darkened(0.3)
					img.set_pixel(x, y, band)

	# 기둥 윗부분(아치 사이 천장)도 볼트 그늘에 묻는다
	for px in PILLARS:
		for x in range(px - 14, px + 14):
			for y in range(0, 84):
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.4))

	# 창문 (구멍 + 돌 틀 + 창살 + 창턱)
	for wx in WINDOWS:
		for y in range(110, 285):
			for x in range(wx - 36, wx + 36):
				if _window_hole(x, y, wx):
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var near := false
				for d in range(1, 5):
					if _window_hole(x - d, y, wx) or _window_hole(x + d, y, wx) or _window_hole(x, y + d, wx) \
							or _window_hole(x, y - d, wx):
						near = true
						break
				if near:
					var fc := _c(86, 88, 116)
					if _window_hole(x + 1, y, wx) or _window_hole(x, y + 1, wx):
						fc = fc.lightened(0.15)
					img.set_pixel(x, y, fc)
		# 창살
		for bx in [wx - 10, wx + 9]:
			for y in range(118, 271):
				if _window_hole(bx, y, wx):
					_put(img, bx, y, _c(16, 16, 24))
					_put(img, bx + 1, y, _c(40, 40, 54))
		for x in range(wx - 28, wx + 28):
			for y in [205, 206]:
				if _window_hole(x, y, wx):
					_put(img, x, y, _c(16, 16, 24) if y == 206 else _c(40, 40, 54))
		# 창턱
		_rect(img, wx - 34, 271, 68, 2, _c(110, 112, 140))
		_rect(img, wx - 34, 273, 68, 4, _c(70, 72, 96))
		_rect(img, wx - 33, 277, 66, 1, _c(30, 30, 44))

	# 기둥
	for px in PILLARS:
		for y in range(92, 392):
			for u in 28:
				var x: int = px - 14 + u
				var k := 1.0 - pow((u - 9.0) / 19.0, 2.0)
				var c := _c(54, 56, 80).lightened(k * 0.22)
				if u % 6 == 0:
					c = c.darkened(0.2)
				elif u % 6 == 1:
					c = c.lightened(0.06)
				if u >= 25:
					c = c.darkened(0.35)
				if (y - 92) % 40 == 0:
					c = c.darkened(0.15)
				img.set_pixel(x, y, c)
		# 주두(위)와 주춧돌(아래)
		for i in 3:
			var w := 36 - i * 3
			_rect(img, px - w / 2, 84 + i * 3, w, 3, _c(84, 86, 114).darkened(i * 0.08))
			_rect(img, px - w / 2, 84 + i * 3, w, 1, _c(110, 112, 142))
		for i in 3:
			var w := 30 + i * 3
			_rect(img, px - w / 2, 383 + i * 3, w, 3, _c(72, 74, 100).darkened(i * 0.06))
			_rect(img, px - w / 2, 383 + i * 3, w, 1, _c(100, 102, 132))

	# 걸레받이
	_rect(img, 0, 392, WALL_W, 8, _c(36, 36, 52))
	_rect(img, 0, 392, WALL_W, 1, _c(70, 72, 96))

	# 조명: 창문의 달빛(푸른 빛) + 천장/바닥 그늘
	for y in WALL_H:
		for x in WALL_W:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var moon := 0.0
			for wx in WINDOWS:
				var d := Vector2(x, y).distance_to(Vector2(wx, 220))
				moon += exp(-pow(d / 150.0, 2.0)) * 0.9
				var d2 := Vector2(x, y).distance_to(Vector2(wx + 70, 390))
				moon += exp(-pow(d2 / 110.0, 2.0)) * 0.35
			var shade := 0.72 + moon * 0.38
			if y < 100:
				shade *= lerpf(0.55, 1.0, y / 100.0)
			if y > 360:
				shade *= lerpf(1.0, 0.82, (y - 360) / 40.0)
			c = Color(c.r * shade, c.g * shade, c.b * shade)
			c = c.lerp(Color(0.55, 0.65, 0.95), clampf(moon * 0.12, 0.0, 0.25))
			img.set_pixel(x, y, c)
	_save(img, "environment/room_backwall.png")


func _gen_sky() -> void:
	# 1400x520px (월드 x[-700,700], y[-640,-120]) — 창문 너머로만 보인다.
	var w := 700
	var h := 260
	var img := _new(w, h)
	for y in h:
		var t := float(y) / h
		var c := Color(0.035, 0.045, 0.11).lerp(Color(0.17, 0.15, 0.32), pow(t, 1.3))
		for x in w:
			img.set_pixel(x, y, c)
	# 구름 띠
	for band in [[70, 0.06], [118, 0.05], [150, 0.07], [200, 0.05]]:
		var by: int = band[0]
		for x in w:
			var thick := 3.0 + 3.0 * sin(x * 0.031 + by) + 2.0 * sin(x * 0.07 + by * 0.3)
			for y in range(by, by + int(maxf(thick, 0.0))):
				if y < h:
					img.set_pixel(x, y, img.get_pixel(x, y).lightened(band[1]))
	# 별
	for i in 320:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, int(h * 0.8))
		var b := rng.randf_range(0.35, 1.0)
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.85, 0.88, 1.0), b))
		if b > 0.93:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				_put(img, x + d.x, y + d.y, img.get_pixel(x, y).lerp(Color(0.8, 0.85, 1), 0.4))
	# 달 (가운데 창문 뒤)
	var mc := Vector2(350, 85)
	var mr := 21.0
	for y in range(int(mc.y - mr) - 1, int(mc.y + mr) + 2):
		for x in range(int(mc.x - mr) - 1, int(mc.x + mr) + 2):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(mc)
			if d > mr:
				continue
			var lit := Vector2(x + 0.5, y + 0.5).distance_to(mc + Vector2(-5, -5)) / (mr * 1.6)
			var c := Color(0.97, 0.96, 1.0).lerp(Color(0.72, 0.74, 0.9), clampf(lit, 0.0, 1.0))
			img.set_pixel(x, y, c)
	for cr in [[Vector2(343, 80), 4.0], [Vector2(357, 92), 3.0], [Vector2(352, 74), 2.0], [Vector2(340, 95), 2.5]]:
		var cc: Vector2 = cr[0]
		var rr: float = cr[1]
		for y in range(int(cc.y - rr), int(cc.y + rr) + 1):
			for x in range(int(cc.x - rr), int(cc.x + rr) + 1):
				if Vector2(x + 0.5, y + 0.5).distance_to(cc) <= rr:
					img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.12))
	_save(img, "environment/room_sky.png")


func _gen_floor() -> void:
	# 2000x200px (월드 x[-1000,1000], y[0,200])
	var w := 1000
	var h := 100
	var img := _new(w, h)
	_brick_field(img, 0, 9, w, h - 9, 18, 26, 44, _c(40, 40, 58), _c(16, 16, 24), 0.08)
	# 윗면(원근 느낌의 석판)
	var x := 0
	while x < w:
		var sw := rng.randi_range(30, 52)
		var c := _stone(_c(70, 70, 96), 0.02)
		for yy in range(2, 8):
			for xx in range(x, mini(x + sw, w)):
				var cc := c.darkened((yy - 2) * 0.05)
				if xx == x:
					cc = _c(30, 30, 44)
				_put(img, xx, yy, cc)
		x += sw
	_rect(img, 0, 0, w, 1, _c(150, 150, 186))
	_rect(img, 0, 1, w, 1, _c(104, 104, 136))
	_rect(img, 0, 8, w, 1, _c(14, 14, 22))
	# 아래로 갈수록 어둠 속으로
	for y in range(9, h):
		var k := clampf((y - 9) / 60.0, 0.0, 1.0)
		for xx in w:
			var c := img.get_pixel(xx, y)
			img.set_pixel(xx, y, c.darkened(k * 0.75))
	_save(img, "environment/room_floor.png")


func _gen_side_wall() -> void:
	# 200x840px — 왼쪽 벽 기준(오른쪽 면이 방 안쪽). 오른쪽 벽은 flip_h로 재사용.
	var w := 100
	var h := 420
	var img := _new(w, h)
	_brick_field(img, 0, 0, w, h, 16, 24, 40, _c(30, 30, 44), _c(12, 12, 18), 0.06)
	# 안쪽 모서리 기둥 띠
	for y in h:
		for u in 10:
			var xx := w - 10 + u
			var c := _c(64, 64, 88).lightened(0.12 if u < 2 else 0.0).darkened(u * 0.04)
			if y % 48 == 0:
				c = _c(20, 20, 30)
			img.set_pixel(xx, y, c)
	# 바깥쪽으로 갈수록 어둡게
	for y in h:
		for xx in w - 10:
			var c := img.get_pixel(xx, y)
			img.set_pixel(xx, y, c.darkened(clampf((w - 10 - xx) / 90.0, 0.0, 1.0) * 0.55))
	_save(img, "environment/room_side_wall.png")


func _gen_ledge() -> void:
	# 240x52px 석조 발판 (윗면이 텍스처 맨 위 = 충돌 윗면)
	var w := 120
	var h := 26
	var img := _new(w, h)
	_brick_field(img, 0, 5, w, 9, 9, 16, 26, _c(52, 52, 74), _c(20, 20, 30), 0.05)
	_rect(img, 0, 0, w, 1, _c(160, 160, 194))
	_rect(img, 0, 1, w, 1, _c(112, 112, 144))
	_rect(img, 0, 2, w, 3, _c(80, 80, 108))
	_rect(img, 0, 14, w, 1, _c(18, 18, 28))
	# 받침돌
	for cx in [18, 101]:
		for y in range(15, h):
			var half := int(lerpf(8.0, 2.0, (y - 15) / float(h - 15)))
			for xx in range(cx - half, cx + half):
				var c := _c(46, 46, 66).darkened((y - 15) * 0.03)
				if xx == cx - half:
					c = c.lightened(0.1)
				_put(img, xx, y, c)
	_save(img, "environment/ledge.png")


# ═══════════════════════════════ 소품 ═══════════════════════════════
func _gen_props() -> void:
	_gen_brazier()
	_gen_banner()
	_gen_chain()


func _gen_brazier() -> void:
	var iron := _c(42, 36, 52)
	var iron_l := _c(96, 86, 112)
	var coal := _c(255, 140, 50)
	var img := _new(24, 28)
	# 그릇
	for y in range(0, 8):
		var half := int(lerpf(11.0, 6.0, y / 7.0))
		for x in range(12 - half, 12 + half):
			_put(img, x, y, iron if y > 1 else iron_l)
	for x in range(2, 22):
		if x % 2 == 0:
			_put(img, x, 0, coal)
	_rect(img, 3, 3, 18, 1, iron_l.darkened(0.2))
	# 기둥 + 받침
	_rect(img, 10, 8, 4, 13, iron)
	_rect(img, 10, 8, 1, 13, iron_l)
	_rect(img, 8, 12, 8, 2, iron_l.darkened(0.15))
	_poly(img, PackedVector2Array([Vector2(12, 20), Vector2(20, 27), Vector2(17, 27), Vector2(12, 23),
			Vector2(7, 27), Vector2(4, 27)]), iron)
	_outline(img, _c(8, 6, 12))
	_save(img, "environment/brazier.png")

	# 불꽃 4프레임 (16x24)
	var frames: Array[Image] = []
	for f in 4:
		var fl := _new(16, 24)
		for y in 24:
			for x in 16:
				var hgt := 1.0 - y / 23.0                      # 0 바닥 → 1 꼭대기
				var sway := sin(hgt * 4.0 + f * 1.57) * 2.0 * hgt
				var width := 6.5 * pow(maxf(1.0 - hgt, 0.0), 0.55) * (0.9 + 0.1 * sin(f * 2.1 + hgt * 9.0))
				var dx := absf(x + 0.5 - (8.0 + sway))
				var dens := 1.0 - dx / maxf(width, 0.01)
				dens -= 0.18 * sin(x * 1.7 + y * 0.9 + f * 2.3)
				if dens <= 0.0:
					continue
				var c := _c(190, 40, 20)
				if dens > 0.75 and hgt < 0.55:
					c = _c(255, 246, 190)
				elif dens > 0.5:
					c = _c(255, 196, 70)
				elif dens > 0.25:
					c = _c(255, 120, 34)
				fl.set_pixel(x, y, c)
		frames.append(fl)
	_save(_sheet(frames), "environment/brazier_flame.png")


func _gen_banner() -> void:
	var w := 24
	var h := 84
	var img := _new(w, h)
	var cloth := _c(96, 40, 110)
	var gold := _c(176, 140, 74)
	# 막대
	_rect(img, 0, 0, w, 3, _c(40, 30, 30))
	_rect(img, 0, 0, w, 1, _c(110, 90, 70))
	for y in range(3, h):
		for x in range(2, w - 2):
			# 제비꼬리 밑단
			if y > h - 12 and absf(x + 0.5 - w * 0.5) < (y - (h - 12)) * 0.9:
				continue
			var fold := sin(x * 0.75) * 0.08
			var c := cloth.lightened(maxf(fold, 0.0)).darkened(maxf(-fold, 0.0) + (y / float(h)) * 0.25)
			if x == 2 or x == w - 3:
				c = gold
			_put(img, x, y, c)
	_rect(img, 2, 5, w - 4, 1, gold)
	# 문장: 초승달 + 고양이 눈
	var mc := Vector2(12, 32)
	for y in range(22, 44):
		for x in range(2, 22):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(mc) <= 7.5 and p.distance_to(mc + Vector2(3, -2)) > 6.0:
				_put(img, x, y, _c(240, 214, 130))
	_rect(img, 13, 31, 3, 2, _c(255, 206, 44))
	_outline(img, _c(16, 8, 20))
	_save(img, "environment/banner.png")


func _gen_chain() -> void:
	var w := 7
	var h := 220
	var img := _new(w, h)
	var iron := _c(38, 34, 48)
	var iron_l := _c(84, 78, 100)
	var y := 0
	var i := 0
	while y < h:
		if i % 2 == 0:
			_rect(img, 1, y, 5, 8, iron)
			_rect(img, 2, y + 2, 3, 4, Color(0, 0, 0, 0))
			_rect(img, 1, y, 1, 8, iron_l)
		else:
			_rect(img, 3, y, 2, 8, iron)
			_rect(img, 3, y, 1, 8, iron_l)
		y += 6
		i += 1
	_save(img, "environment/chain.png")


# ═══════════════════════════════ 이펙트 ═══════════════════════════════
func _gen_effects() -> void:
	_gen_void_orb()


## 장풍(공허 구체) — 4프레임 회전 시트. 지름 38 아트 픽셀 = 화면 76px (플레이어 키).
## 팔 두 개짜리 소용돌이라 45°씩 4프레임이면 반 바퀴 = 이음매 없이 반복된다.
func _gen_void_orb() -> void:
	var frames: Array[Image] = []
	for f in 4:
		frames.append(_void_orb_frame(f))
	_save(_sheet(frames), "effects/void_orb.png")


func _void_orb_frame(f: int) -> Image:
	var size := 40
	var img := _new(size, size)
	var cx := size * 0.5
	var cy := size * 0.5
	var r := 19.0
	var outline := _c(30, 10, 52)
	var rim := _c(196, 150, 255)
	var deep := _c(74, 32, 128)
	var mid := _c(112, 58, 184)
	var arm := _c(156, 100, 232)
	var arm_hot := _c(206, 168, 255)
	var core := _c(222, 196, 255)
	var hot := _c(255, 248, 255)
	var spin := f * PI / 4.0
	for y in size:
		for x in size:
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				continue
			var c := deep if d > r * 0.62 else mid
			if d > r - 1.2:
				c = outline
			elif d > r - 2.6:
				c = rim
			else:
				# 소용돌이 팔: 각도 + 반지름에 따라 휘어진다
				var a := atan2(dy, dx)
				var w := sin(2.0 * (a - spin) + d * 0.34)
				if d > r * 0.28:
					if w > 0.82:
						c = arm_hot
					elif w > 0.45:
						c = arm
				if d < 7.6:
					c = core
				if d < 4.2:
					c = hot
			img.set_pixel(x, y, c)
	# 테두리 안쪽에서 반짝이는 점 몇 개 (프레임마다 다르게)
	for i in 5:
		var a := rng.randf() * TAU
		var dd := rng.randf_range(r * 0.5, r - 3.0)
		_put(img, int(cx + cos(a) * dd), int(cy + sin(a) * dd), hot)
	return img


# ═══════════════════════════════ 감시자 (공중 원거리 중간 보스 — 공허의 감시자) ═══════════════════════════════
## 잡몹보다 한 급 위의 위엄: 금장 테두리 갑각, 금빛 가시 왕관 + 떠 있는 후광, 두 쌍의 칼날깃 날개,
## 큰 외눈 주위의 작은 눈 넷, 아래로 늘어진 척추 꼬리와 보석. 프레임 순서는 watcher.gd의 Frame enum과 맞춘다.
## 캔버스 72x60, 큰 눈의 중심 = (36, 27) → 씬에서 Body를 (0, 6)에 두면 눈이 루트 원점에 온다.
func _gen_watcher() -> void:
	var specs := [
		{"wing": 0},                              # 0 idle a (날개 위)
		{"wing": 1, "dy": 1},                     # 1 idle b (날개 아래)
		{"wing": 0, "eye": "aim"},                # 2 조준 (눈을 가늘게, 붉게)
		{"wing": 1, "eye": "wide", "dx": -1},     # 3 발사 반동
		{"wing": 2, "eye": "charge"},             # 4 카유공 충전 (날개 활짝, 온몸의 눈이 빛남)
		{"wing": 1, "eye": "x", "dy": 1},         # 5 피격
	]
	var frames: Array[Image] = []
	for s in specs:
		frames.append(_watcher_frame(s))
	_save(_sheet(frames), "characters/watcher/watcher.png")


func _watcher_frame(p: Dictionary) -> Image:
	var img := _new(72, 60)
	var shell := _c(52, 32, 76)
	var shell_top := _c(82, 54, 112)
	var shell_dark := _c(28, 16, 42)
	var socket := _c(18, 8, 24)
	var wing := _c(54, 24, 80)
	var wing_edge := _c(112, 72, 156)
	var gold := _c(226, 176, 72)
	var gold_d := _c(150, 98, 40)
	var bone := _c(198, 176, 150)
	var gem := _c(236, 70, 90)
	var sclera := _c(236, 226, 204)
	var iris := _c(255, 206, 60)
	var iris_d := _c(222, 120, 30)
	var pupil := _c(20, 8, 24)
	var hot := _c(255, 244, 196)
	var eye_mode: String = p.get("eye", "open")
	var cx: float = 36.0 + p.get("dx", 0.0)
	var cy: float = 27.0 + p.get("dy", 0.0)
	var w: int = p.get("wing", 0)

	# ── 척추 꼬리 + 보석 (가장 뒤)
	var sway := 1.0 if w == 1 else -1.0
	var prev := Vector2(cx, cy + 10.0)
	for k in 6:
		var q := Vector2(cx + sin(k * 0.9) * 1.2 * sway, cy + 12.0 + k * 2.4)
		_line(img, prev, q, 2.0, bone.darkened(0.25))
		_ellipse(img, q.x, q.y, 2.0 - k * 0.18, 1.3, bone)
		prev = q
	_poly(img, PackedVector2Array([prev + Vector2(0, 1), prev + Vector2(2.5, 4), prev + Vector2(0, 8), prev + Vector2(-2.5, 4)]), gem)
	_put(img, int(prev.x), int(prev.y + 3), Color(1, 0.8, 0.85))
	# 옆 촉수 (금 고리)
	for side in [-1.0, 1.0]:
		var a := Vector2(cx + side * 7.0, cy + 8.0)
		var b := Vector2(cx + side * 9.5 - sway * side, cy + 19.0)
		var c := Vector2(cx + side * 8.0 + sway * 0.5, cy + 26.0)
		_line(img, a, b, 1.6, shell_dark)
		_line(img, b, c, 1.1, shell_dark)
		_put(img, int(b.x), int(b.y), gold)
		_put(img, int(b.x) + 1, int(b.y), gold_d)

	# ── 날개: 위 3장(큰 칼날깃) + 아래 2장(작은 깃)
	var upper := [[-58.0, -34.0, -10.0], [-24.0, -4.0, 16.0], [-44.0, -20.0, 4.0]]
	var lower := [[24.0, 44.0], [36.0, 58.0], [28.0, 50.0]]
	var lens := [21.0, 24.0, 17.0]
	for side in [-1.0, 1.0]:
		for i in 2:
			_feather(img, Vector2(cx + side * 9.0, cy + 4.0), lower[w][i], 11.0 - i * 2.0, side, wing, wing_edge, gold, 2.2)
		for i in 3:
			_feather(img, Vector2(cx + side * 10.0, cy - 3.0 + i * 1.5), upper[w][i], lens[i], side, wing, wing_edge, gold, 3.2)

	# ── 후광 (떠 있는 금빛 고리) + 가시 왕관
	for y in range(int(cy - 26), int(cy - 15)):
		for x in range(int(cx - 13), int(cx + 14)):
			var nx := (x + 0.5 - cx) / 11.0
			var ny := (y + 0.5 - (cy - 20.5)) / 3.0
			var d := nx * nx + ny * ny
			if d <= 1.0 and d >= 0.45:
				_put(img, x, y, gold if ny < 0.0 else gold_d)
	var spikes := [[0.0, 11.0], [-24.0, 8.5], [24.0, 8.5], [-46.0, 6.0], [46.0, 6.0]]
	for sp in spikes:
		var ang := deg_to_rad(-90.0 + float(sp[0]))
		var dir := Vector2.from_angle(ang)
		var root := Vector2(cx, cy) + dir * 9.5
		var n := dir.orthogonal()
		_poly(img, PackedVector2Array([root + n * 1.8, root + dir * float(sp[1]), root - n * 1.8]), gold)
		_line(img, root + n * 0.8, root + dir * (float(sp[1]) - 1.5), 0.8, gold_d)

	# ── 갑각 몸통 (위는 밝고 아래는 어둡게)
	var rx := 12.0
	var ry := 11.0
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			var c := shell
			if ny < -0.45 + nx * 0.2:
				c = shell_top
			elif ny > 0.5:
				c = shell_dark
			_put(img, x, y, c)
	# 갑각 판 이음새
	for side in [-1.0, 1.0]:
		_line(img, Vector2(cx + side * 9.5, cy - 6.0), Vector2(cx + side * 11.0, cy + 3.0), 0.8, shell_dark)
	_line(img, Vector2(cx - 4.0, cy + 9.0), Vector2(cx + 4.0, cy + 9.0), 0.8, shell_dark)
	# 금장 테두리 (눈구멍 둘레)
	for y in range(int(cy - 9), int(cy + 10)):
		for x in range(int(cx - 10), int(cx + 11)):
			var nx := (x + 0.5 - cx) / 8.6
			var ny := (y + 0.5 - cy) / 7.4
			var d := nx * nx + ny * ny
			if d <= 1.0 and d >= 0.66:
				_put(img, x, y, gold if ny < 0.15 else gold_d)
	_ellipse(img, cx, cy, 6.8, 5.6, socket)

	# ── 작은 눈 넷
	var small_col := _c(255, 110, 80) if eye_mode == "aim" else (hot if eye_mode == "charge" else _c(214, 90, 70))
	if eye_mode == "x":
		small_col = shell_dark
	for se in [Vector2(-9, -6), Vector2(9, -6), Vector2(-10, 4), Vector2(10, 4)]:
		_rect(img, int(cx + se.x) - 1, int(cy + se.y), 2, 1, small_col)

	# ── 큰 외눈
	var ex := cx
	var ey := cy
	match eye_mode:
		"aim":
			_ellipse(img, ex, ey, 6.0, 2.0, sclera)
			_rect(img, int(ex) - 2, int(ey) - 1, 5, 2, _c(255, 90, 56))
			_rect(img, int(ex) - 7, int(ey) - 3, 14, 1, gold_d)
		"wide":
			_ellipse(img, ex, ey, 6.4, 5.4, sclera)
			_ellipse(img, ex + 0.5, ey, 2.8, 2.8, iris)
			_rect(img, int(ex), int(ey), 1, 1, pupil)
		"charge":
			_ellipse(img, ex, ey, 6.4, 5.4, _c(255, 228, 150))
			_ellipse(img, ex, ey, 4.2, 3.6, hot)
			_ellipse(img, ex, ey, 2.0, 2.0, Color(1, 1, 1))
		"x":
			for k in range(-4, 5):
				_put(img, int(ex) + k, int(ey) + k, iris)
				_put(img, int(ex) + k, int(ey) - k, iris)
		_:
			_ellipse(img, ex, ey, 6.0, 4.8, sclera)
			_ellipse(img, ex + 0.5, ey, 3.6, 4.0, iris)
			_ellipse(img, ex + 1.0, ey + 1.5, 2.2, 1.5, iris_d)
			_rect(img, int(ex), int(ey) - 3, 1, 6, pupil)
			_put(img, int(ex) - 2, int(ey) - 2, Color(1, 1, 0.94))
			_put(img, int(ex) - 1, int(ey) - 3, Color(1, 1, 0.94))
	_shade_edges(img, 0.16, 0.22, [sclera, iris, iris_d, pupil, gold, gold_d, gem, hot, small_col, socket,
			_c(255, 228, 150), _c(255, 90, 56), Color(1, 1, 1), Color(1, 1, 0.94)])
	_outline(img, _c(8, 4, 14))
	return img


## 칼날깃 하나: root에서 angle_deg 방향(오른쪽 기준, side로 좌우 반전)으로 뻗는 날 모양 깃. 끝은 금빛.
func _feather(img: Image, root: Vector2, angle_deg: float, length: float, side: float,
		body: Color, edge: Color, tip: Color, width: float) -> void:
	var dir := Vector2.from_angle(deg_to_rad(angle_deg))
	dir.x *= side
	var n := dir.orthogonal()
	var end := root + dir * length
	var pts := PackedVector2Array([root + n * width * 0.6, root + dir * length * 0.55 + n * width,
			end, root + dir * length * 0.5 - n * width * 0.5, root - n * width * 0.4])
	_poly(img, pts, body)
	_line(img, root + n * width * 0.4, end, 0.9, edge)
	_line(img, root + dir * (length - 3.0), end, 1.2, tip)


# ═══════════════════════════════ 보스 — 월식의 기사 ═══════════════════════════════
# 플레이어의 약 3배(몸 ~84 아트 픽셀 = 화면 ~168px)인 갑옷 기사. 투구 위 금빛 초승달, 와인빛 깃털 장식, 찢긴 망토.
# 대검은 손에서 분리해(knight_sword.png) 따로 회전시킨다.
# 프레임 순서와 손 위치("hand")는 actors/enemies/knight/knight.gd의 Frame / HAND와 같아야 한다.
const KNIGHT_W := 76
const KNIGHT_H := 96
const KNIGHT_GROUND := 93
const KNIGHT_CX := 36


func _gen_knight() -> void:
	var specs := [
		{"hand": Vector2(49, 54)},                                                              # 0 idle a
		{"hand": Vector2(49, 55), "breath": 1, "flutter": 1.0},                                 # 1 idle b
		{"hand": Vector2(50, 53), "stride": 5.0, "bob": -1, "flutter": 1.5},                    # 2 walk
		{"hand": Vector2(49, 54), "flutter": 0.5},                                              # 3 walk
		{"hand": Vector2(50, 53), "stride": -5.0, "bob": -1, "flutter": 1.5},                   # 4 walk
		{"hand": Vector2(49, 54), "flutter": 0.5},                                              # 5 walk
		{"hand": Vector2(39, 27), "crouch": 3, "lean": -3.0, "stride": 5.0},                    # 6 windup (대검을 머리 위 뒤로)
		{"hand": Vector2(58, 57), "crouch": 4, "lean": 6.0, "stride": 9.0, "flutter": 4.0},     # 7 strike
		{"hand": Vector2(47, 61), "crouch": 2, "lean": -6.0, "stride": -3.0, "flutter": 2.0, "eye": "dim"},   # 8 stagger
		{"hand": Vector2(45, 58), "crouch": 3, "lean": 8.0, "stride": 10.0, "flutter": 7.0},    # 9 dash
		{"hand": Vector2(50, 57), "raise": true, "lean": -2.0, "flutter": 3.0, "eye": "hot"},   # 10 cast (한 손을 치켜듦)
		{"hand": Vector2(53, 45), "crouch": 2, "stride": 6.0, "eye": "hot"},                    # 11 guard (반격 자세)
		{"hand": Vector2(50, 47), "crouch": 5, "lean": 3.0, "stride": 4.0, "flutter": 5.0, "eye": "rage"},    # 12 slam
		{"hand": Vector2(43, 64), "crouch": 8, "lean": 7.0, "stride": 8.0, "flutter": 2.0, "eye": "rage"},    # 13 crouch (돌진 준비)
		{"hand": Vector2(45, 61), "crouch": 4, "lean": 11.0, "stride": 12.0, "flutter": 8.0, "eye": "rage"},  # 14 rush
		{"hand": Vector2(44, 23), "lean": -4.0, "stride": 6.0, "flutter": 3.0, "eye": "rage"},  # 15 roar (등장 포효)
	]
	var frames: Array[Image] = []
	for s in specs:
		frames.append(_knight_frame(s))
	_save(_sheet(frames), "characters/knight/knight.png")
	_save(_knight_sword(), "characters/knight/knight_sword.png")


func _knight_frame(p: Dictionary) -> Image:
	var img := _new(KNIGHT_W, KNIGHT_H)
	var steel := _c(72, 76, 108)
	var steel_l := _c(128, 134, 176)
	var steel_d := _c(42, 42, 68)
	var steel_dd := _c(26, 24, 42)
	var gold := _c(218, 172, 82)
	var gold_d := _c(148, 102, 48)
	var cape := _c(46, 24, 74)
	var cape_d := _c(28, 14, 46)
	var lining := _c(128, 30, 56)
	var plume := _c(104, 32, 70)
	var plume_d := _c(62, 18, 44)
	var visor := _c(10, 6, 16)
	var eye_mode: String = p.get("eye", "normal")
	var eye_col := _c(196, 156, 255)
	match eye_mode:
		"hot":
			eye_col = _c(255, 232, 150)
		"rage":
			eye_col = _c(255, 92, 80)
		"dim":
			eye_col = _c(92, 72, 132)
	var crouch: float = p.get("crouch", 0) + p.get("breath", 0) * 0.5
	var lean: float = p.get("lean", 0.0)
	var stride: float = p.get("stride", 0.0)
	var flutter: float = p.get("flutter", 0.0)
	var bob: float = p.get("bob", 0)
	var hand: Vector2 = p.get("hand", Vector2(49, 54))
	var raise: bool = p.get("raise", false)
	var g := float(KNIGHT_GROUND)
	var cx := float(KNIGHT_CX)
	var hip_y := g - 28.0 + crouch + bob
	# 서 있을 때 기준 좌표 → 웅크림/기울임 적용 (엉덩이 위로 갈수록 lean만큼 앞으로)
	var sh := func(v: Vector2) -> Vector2:
		var y := v.y + crouch + bob
		var t := clampf((hip_y - y) / 40.0, 0.0, 1.0)
		return Vector2(v.x + lean * t, y)
	var hc: Vector2 = sh.call(Vector2(cx + 2, g - 71))

	# ── 깃털 장식 (가장 뒤, 투구 뒤로 흩날린다)
	_poly(img, PackedVector2Array([hc + Vector2(-2, -9), hc + Vector2(-12 - flutter, -8), hc + Vector2(-20 - flutter * 1.5, -3),
			hc + Vector2(-23 - flutter * 1.7, 3), hc + Vector2(-15 - flutter, 1), hc + Vector2(-5, -2)]), plume)
	_line(img, hc + Vector2(-4, -6), hc + Vector2(-19 - flutter * 1.5, 0), 1.0, plume_d)

	# ── 망토 (몸 뒤) — 밑단은 찢겨 있고 안감이 비친다
	var c_top0: Vector2 = sh.call(Vector2(cx - 12, g - 60))
	var c_top1: Vector2 = sh.call(Vector2(cx + 3, g - 60))
	var hem_y := g - 9.0 + crouch * 0.4
	var cape_pts := PackedVector2Array([c_top0, c_top1, Vector2(cx - 2 + lean * 0.3, hem_y - 6),
			Vector2(cx - 5, hem_y - 2), Vector2(cx - 9, hem_y - 6), Vector2(cx - 13 - flutter * 0.5, hem_y),
			Vector2(cx - 17 - flutter * 0.8, hem_y - 5), Vector2(cx - 22 - flutter * 1.3, hem_y + 1 - flutter * 0.4),
			Vector2(cx - 24 - flutter * 1.5, hem_y - 12 - flutter * 0.3), Vector2(cx - 21 - flutter * 0.8, g - 40),
			c_top0 + Vector2(-5, 6)])
	_poly(img, cape_pts, cape)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if not c.is_equal_approx(cape):
				continue
			if _px(img, x, y + 1).a <= 0.0 or _px(img, x, y + 2).a <= 0.0:
				img.set_pixel(x, y, lining)
			elif x < cx - 10 - lean * 0.3:
				img.set_pixel(x, y, cape_d)

	# ── 뒤팔 (치켜들지 않을 때는 몸통 뒤에 거의 가려진다)
	var back_sh: Vector2 = sh.call(Vector2(cx - 9, g - 57))
	if not raise:
		var bh: Vector2 = sh.call(Vector2(cx - 12, g - 40))
		_line(img, back_sh, bh, 5.0, steel_dd)
		_ellipse(img, bh.x, bh.y, 2.8, 2.8, steel_d)

	# ── 다리 (판금 정강이 + 금빛 무릎)
	var back_foot := Vector2(cx - 5 - stride, g - 2)
	var front_foot := Vector2(cx + 6 + stride, g - 2)
	var b_hip := Vector2(cx - 5, hip_y)
	var f_hip := Vector2(cx + 5, hip_y)
	var b_knee := (b_hip + back_foot) * 0.5 + Vector2(crouch * 0.5 + 1, 0)
	var f_knee := (f_hip + front_foot) * 0.5 + Vector2(2 + crouch * 0.8, -crouch * 0.2)
	_line(img, b_hip, b_knee, 7.0, steel_d)
	_line(img, b_knee, back_foot, 6.0, steel_d)
	_poly(img, PackedVector2Array([back_foot + Vector2(-4, -3), back_foot + Vector2(5, -2), back_foot + Vector2(7, 2),
			back_foot + Vector2(-4, 2)]), steel_dd)
	_line(img, f_hip, f_knee, 7.5, steel)
	_line(img, f_knee, front_foot, 6.5, steel)
	_poly(img, PackedVector2Array([front_foot + Vector2(-4, -3), front_foot + Vector2(6, -2), front_foot + Vector2(9, 2),
			front_foot + Vector2(-4, 2)]), steel_d)
	_ellipse(img, b_knee.x + 1, b_knee.y, 2.4, 2.2, gold_d)
	_ellipse(img, f_knee.x + 1, f_knee.y, 2.8, 2.5, gold)

	# ── 뒤 견갑 (어둡게)
	_ellipse(img, back_sh.x - 1, back_sh.y, 8.0, 6.5, steel_d)

	# ── 갑옷 치마(태싯) — 겹친 판
	var tasset := PackedVector2Array()
	for v in [Vector2(cx - 13, g - 37), Vector2(cx + 12, g - 37), Vector2(cx + 14, g - 24), Vector2(cx + 7, g - 21),
			Vector2(cx + 1, g - 24), Vector2(cx - 6, g - 21), Vector2(cx - 13, g - 24), Vector2(cx - 15, g - 30)]:
		tasset.append(sh.call(v))
	_poly(img, tasset, steel_d)
	for ly in [g - 35.0, g - 30.0, g - 25.0]:
		_line(img, sh.call(Vector2(cx - 13, ly)), sh.call(Vector2(cx + 13, ly)), 1.0, steel)
	_line(img, sh.call(Vector2(cx + 1, g - 36)), sh.call(Vector2(cx + 1, g - 23)), 1.0, steel_dd)

	# ── 흉갑
	var torso := PackedVector2Array()
	for v in [Vector2(cx - 12, g - 61), Vector2(cx + 9, g - 63), Vector2(cx + 14, g - 52), Vector2(cx + 12, g - 38),
			Vector2(cx - 11, g - 37), Vector2(cx - 14, g - 50)]:
		torso.append(sh.call(v))
	_poly(img, torso, steel)
	_line(img, sh.call(Vector2(cx + 5, g - 60)), sh.call(Vector2(cx + 3, g - 41)), 1.0, steel_l)   # 가운데 능선
	_line(img, sh.call(Vector2(cx - 13, g - 47)), sh.call(Vector2(cx + 13, g - 47)), 0.8, steel_d)  # 판 이음새
	# 가슴의 금빛 초승달 문장
	var em: Vector2 = sh.call(Vector2(cx + 1, g - 54))
	for y in range(int(em.y) - 4, int(em.y) + 5):
		for x in range(int(em.x) - 4, int(em.x) + 5):
			var d1 := Vector2(x + 0.5, y + 0.5).distance_to(em)
			var d2 := Vector2(x + 0.5, y + 0.5).distance_to(em + Vector2(1.6, -1.2))
			if d1 <= 3.6 and d2 > 3.0:
				_put(img, x, y, gold)
	# 허리띠 + 버클
	_line(img, sh.call(Vector2(cx - 11, g - 38)), sh.call(Vector2(cx + 12, g - 38)), 2.0, gold_d)
	var bk: Vector2 = sh.call(Vector2(cx + 4, g - 39))
	_rect(img, int(bk.x) - 1, int(bk.y), 3, 3, gold)
	# 목가리개
	var gor: Vector2 = sh.call(Vector2(cx + 1, g - 63))
	_ellipse(img, gor.x, gor.y, 7.0, 3.0, steel_d)

	# ── 치켜든 뒤팔 (카유공): 몸통 위, 투구 뒤
	if raise:
		var rh := Vector2(cx - 6, 7)
		var rel := (back_sh + rh) * 0.5 + Vector2(-5, 1)
		_line(img, back_sh, rel, 5.5, steel_d)
		_line(img, rel, rh, 7.0, _c(14, 10, 24))
		_line(img, rel, rh, 5.0, steel)
		_ellipse(img, rel.x, rel.y, 2.4, 2.4, gold_d)
		_ellipse(img, rh.x, rh.y, 3.2, 3.0, steel_l)
		for k in 3:
			_line(img, rh + Vector2(-2 + k * 2, -1), rh + Vector2(-2.5 + k * 2.5, -5), 1.0, steel_l)
		_put(img, int(rh.x), int(rh.y), _c(255, 236, 170))

	# ── 투구 (통투구 + 세로 능선 + 시야 틈 + 빛나는 눈) 와 금빛 초승달 장식
	_ellipse(img, hc.x, hc.y, 7.5, 9.0, steel)
	_rect(img, int(hc.x) + 1, int(hc.y) - 6, 7, 13, steel)
	_line(img, hc + Vector2(3, -8), hc + Vector2(3, -2), 1.0, steel_l)
	_rect(img, int(hc.x) - 2, int(hc.y) - 1, 10, 2, visor)
	for k in 3:
		_put(img, int(hc.x) + 3 + k * 2, int(hc.y) + 3, visor)
		_put(img, int(hc.x) + 3 + k * 2, int(hc.y) + 5, visor)
	_rect(img, int(hc.x) + 4, int(hc.y) - 1, 3, 1, eye_col)
	if eye_mode != "dim":
		_put(img, int(hc.x) + 6, int(hc.y) - 1, Color(1, 1, 1))
		_put(img, int(hc.x) + 5, int(hc.y), eye_col.darkened(0.3))
	_line(img, hc + Vector2(-6, 8), hc + Vector2(8, 7), 1.0, gold_d)
	var cc := hc + Vector2(-1, -15)
	for y in range(int(cc.y) - 9, int(cc.y) + 9):
		for x in range(int(cc.x) - 9, int(cc.x) + 10):
			var q := Vector2(x + 0.5, y + 0.5)
			if q.distance_to(cc) <= 8.0 and q.distance_to(cc + Vector2(0, -4)) > 8.0:
				_put(img, x, y, gold if q.y < cc.y + 6.0 else gold_d)

	# ── 앞 견갑 (겹판 + 금테 + 리벳)
	var ps: Vector2 = sh.call(Vector2(cx + 8, g - 57))
	_ellipse(img, ps.x + 1, ps.y + 6, 8.0, 3.5, steel_d)
	_ellipse(img, ps.x, ps.y, 9.5, 6.5, steel)
	_line(img, ps + Vector2(-8, 4), ps + Vector2(9, 3), 1.0, gold)
	_put(img, int(ps.x) + 2, int(ps.y) - 3, gold)
	_put(img, int(ps.x) - 4, int(ps.y) - 2, gold_d)

	# ── 앞팔 (어깨 → 팔꿈치 → 대검 쥔 손)
	var f_sh := ps + Vector2(1, 3)
	var to := hand - f_sh
	var dist := to.length()
	var seg := 11.5
	var mid := (f_sh + hand) * 0.5
	var elbow := mid
	if dist < seg * 2.0:
		var n := to.normalized().orthogonal()
		if n.x > 0.0 or (absf(n.x) < 0.2 and n.y < 0.0):
			n = -n
		elbow = mid + n * sqrt(maxf(seg * seg - dist * dist * 0.25, 0.0))
	var rim := _c(14, 10, 24)                                  # 팔이 흉갑에 묻히지 않게 어두운 테두리
	_line(img, f_sh, elbow, 8.0, rim)
	_line(img, elbow, hand, 7.0, rim)
	_ellipse(img, hand.x, hand.y, 4.6, 4.4, rim)
	_line(img, f_sh, elbow, 6.0, steel_l.darkened(0.15))
	_line(img, elbow, hand, 5.0, steel_l.darkened(0.15))
	_ellipse(img, elbow.x, elbow.y, 2.6, 2.6, gold_d)
	_ellipse(img, hand.x, hand.y, 3.4, 3.2, steel_l)
	_put(img, int(hand.x), int(hand.y), steel_d)

	_shade_edges(img, 0.2, 0.25, [visor, eye_col, Color(1, 1, 1), eye_col.darkened(0.3), _c(255, 236, 170), rim])
	_outline(img, _c(8, 4, 14))
	return img


## 대검 — 손잡이 중심(8, 6)이 회전축. 칼날 가운데 홈에 보랏빛 룬이 박혀 있다.
func _knight_sword() -> Image:
	var img := _new(74, 13)
	var gold := _c(218, 172, 82)
	var gold_d := _c(148, 102, 48)
	var cy := 6
	_ellipse(img, 3.0, 6.5, 2.2, 2.2, gold)                  # 폼멜
	_rect(img, 4, 5, 8, 3, _c(56, 26, 42))                   # 손잡이
	for x in [5, 7, 9, 11]:
		_put(img, x, 5, _c(96, 48, 66))
	_rect(img, 12, 1, 3, 11, gold)                           # 가드
	_rect(img, 14, 1, 1, 11, gold_d)
	for x in range(15, 72):
		var u := float(x - 15) / 56.0
		var hw := 3 if u < 0.78 else int(round(lerpf(3.0, 0.0, (u - 0.78) / 0.22)))
		for y in range(cy - hw, cy + hw + 1):
			var c := _c(178, 182, 206)
			if y == cy - hw:
				c = _c(236, 240, 255)
			elif y == cy + hw:
				c = _c(104, 108, 136)
			elif y == cy and x < 58:
				c = _c(92, 94, 128) if (x - 18) % 7 != 0 else _c(184, 132, 255)
			_put(img, x, y, c)
	_put(img, 71, cy, Color(1, 1, 1))
	_outline(img, _c(8, 4, 14))
	return img


# ═══════════════════════════════ Phase1 — 제3부대 보병 ═══════════════════════════════
# 단정한 서양식 제복(어두운 회청색 + 어둑한 초록 깃·견장·허리띠·모자 띠), 각진 얼굴 가면, 철제 양손검.
# 프레임 36x52, 발바닥 = 50행, 몸 중심 x = 18. 씬에서 Body는 (0, 32)에 offset (-18, -50), scale 2.
# → 아트 (x, y) = 로컬 (2x - 36, 2y - 68). infantry.gd의 HAND는 각 프레임 "hand"를 이 식으로 옮긴 값이다.
const INF_W := 36
const INF_H := 52


func _gen_infantry() -> void:
	rng.seed = 3301
	var specs := [
		{"hand": Vector2(24, 31)},                                                    # 0 idle a
		{"hand": Vector2(24, 31), "breath": 1},                                       # 1 idle b
		{"hand": Vector2(24, 30), "stride": 3.0, "bob": -1},                          # 2 walk
		{"hand": Vector2(24, 31)},                                                    # 3 walk
		{"hand": Vector2(24, 30), "stride": -3.0, "bob": -1},                         # 4 walk
		{"hand": Vector2(24, 31)},                                                    # 5 walk
		{"hand": Vector2(20, 3), "lean": -2.0, "stride": 2.5},                        # 6 raise (양손검을 머리 위로)
		{"hand": Vector2(28, 32), "lean": 3.5, "stride": 5.0, "crouch": 2},           # 7 strike (내려 벤 자세)
		{"hand": Vector2(21, 33), "lean": -3.5, "stride": -1.5, "crouch": 1},         # 8 hurt / 기절
	]
	var frames: Array[Image] = []
	for s in specs:
		frames.append(_infantry_frame(s))
	_save(_sheet(frames), "characters/infantry/infantry.png")
	_save(_infantry_sword(), "characters/infantry/infantry_sword.png")


func _infantry_frame(p: Dictionary) -> Image:
	var img := _new(INF_W, INF_H)
	var coat := _c(46, 52, 66)
	var trouser := _c(30, 32, 42)
	var boot := _c(14, 14, 18)
	var green := _c(58, 118, 78)
	var cap := _c(30, 34, 44)
	var mask := _c(200, 194, 176)
	var mask_d := _c(138, 132, 118)
	var slit := _c(10, 12, 12)
	var glove := _c(26, 26, 30)
	var button := _c(150, 156, 160)
	var crouch: float = p.get("crouch", 0) + p.get("breath", 0) * 0.5
	var lean: float = p.get("lean", 0.0)
	var stride: float = p.get("stride", 0.0)
	var bob: float = p.get("bob", 0)
	var hand: Vector2 = p["hand"]
	var arms_back: bool = p.get("arms_back", false)
	var ground := 50.0
	var cx := 18.0
	var hip_y := 35.0 + crouch + bob
	# 기울임: 엉덩이 위쪽 점일수록 lean만큼 앞으로 민다.
	var sh := func(v: Vector2) -> Vector2:
		var y := v.y + crouch + bob
		var t := clampf((hip_y - y) / 28.0, 0.0, 1.0)
		return Vector2(v.x + lean * t, y)

	# 뒷팔 (몸 뒤)
	var bs: Vector2 = sh.call(Vector2(cx - 3, 21))
	_line(img, bs, hand + Vector2(-1, 1), 3.2, coat.darkened(0.35))
	_ellipse(img, hand.x - 1, hand.y + 1, 1.8, 1.8, glove.darkened(0.3))
	# 다리 + 군화
	var back_foot := Vector2(cx - 2 - stride, ground - 2)
	var front_foot := Vector2(cx + 3 + stride, ground - 2)
	_line(img, Vector2(cx - 2, hip_y), back_foot, 3.6, trouser.darkened(0.3))
	_line(img, Vector2(cx + 2, hip_y), front_foot, 3.6, trouser)
	_rect(img, int(back_foot.x) - 2, int(ground) - 3, 6, 3, boot.darkened(0.2))
	_rect(img, int(front_foot.x) - 1, int(ground) - 3, 6, 3, boot)
	# 상의 (각진 어깨의 단정한 제복)
	var body := PackedVector2Array()
	for v in [Vector2(cx - 7, 19), Vector2(cx + 6, 19), Vector2(cx + 7, 24), Vector2(cx + 6, 31), Vector2(cx + 8, 39),
			Vector2(cx - 7, 39), Vector2(cx - 7, 31), Vector2(cx - 8, 24)]:
		body.append(sh.call(v))
	_poly(img, body, coat)
	for y in INF_H:
		var back: Vector2 = sh.call(Vector2(cx - 3, y - crouch - bob))
		for x in INF_W:
			if x < back.x and img.get_pixel(x, y).is_equal_approx(coat):
				img.set_pixel(x, y, coat.darkened(0.22))   # 등 쪽 그늘
	# 초록 허리띠 + 단추 + 깃 + 견장
	_poly(img, PackedVector2Array([sh.call(Vector2(cx - 7.5, 30)), sh.call(Vector2(cx + 7, 30)),
			sh.call(Vector2(cx + 7, 32)), sh.call(Vector2(cx - 7.5, 32))]), green)
	for y in [22, 25, 28]:
		var b: Vector2 = sh.call(Vector2(cx + 3, y))
		_put(img, int(b.x), int(b.y), button)
	_poly(img, PackedVector2Array([sh.call(Vector2(cx - 4, 17.5)), sh.call(Vector2(cx + 5, 17.5)),
			sh.call(Vector2(cx + 5, 20)), sh.call(Vector2(cx - 4, 20))]), green)
	_poly(img, PackedVector2Array([sh.call(Vector2(cx + 2, 18.5)), sh.call(Vector2(cx + 7, 18.5)),
			sh.call(Vector2(cx + 7.5, 20.5)), sh.call(Vector2(cx + 2, 20.5))]), green.darkened(0.15))
	# 앞팔 — 치켜든 자세에서는 머리 뒤로 지나가므로 머리보다 먼저 그린다
	if arms_back:
		_infantry_front_arm(img, sh.call(Vector2(cx + 4, 21)), hand, coat, green, glove)
	# 머리: 뒷머리 → 케피 모자(초록 띠, 챙) → 각진 가면(눈구멍 한 줄, 이마의 부대 표식)
	var hc: Vector2 = sh.call(Vector2(cx + 1, 13))
	_ellipse(img, hc.x - 1, hc.y, 5.0, 5.5, cap.darkened(0.35))
	_poly(img, PackedVector2Array([hc + Vector2(-6, -9), hc + Vector2(4, -9), hc + Vector2(5, -3), hc + Vector2(-6, -3)]), cap)
	_rect(img, int(hc.x - 6), int(hc.y - 5), 11, 2, green)
	_rect(img, int(hc.x + 3), int(hc.y - 3), 5, 1, boot)
	_poly(img, PackedVector2Array([hc + Vector2(-3, -3), hc + Vector2(5, -3), hc + Vector2(6, -1), hc + Vector2(6, 5),
			hc + Vector2(4, 7), hc + Vector2(-2, 7), hc + Vector2(-3, 5)]), mask)
	_rect(img, int(hc.x - 3), int(hc.y - 2), 2, 8, mask_d)
	_rect(img, int(hc.x + 1), int(hc.y - 1), 5, 1, mask_d)
	_rect(img, int(hc.x + 1), int(hc.y), 5, 1, slit)
	_rect(img, int(hc.x - 1), int(hc.y + 4), 6, 1, mask_d)
	_rect(img, int(hc.x + 2), int(hc.y - 2), 2, 1, green)
	if not arms_back:
		_infantry_front_arm(img, sh.call(Vector2(cx + 4, 21)), hand, coat, green, glove)
	_shade_edges(img, 0.2, 0.25, [slit, green, button])
	_outline(img, _c(8, 8, 12))
	return img


func _infantry_front_arm(img: Image, shoulder: Vector2, hand: Vector2, coat: Color, green: Color, glove: Color) -> void:
	_line(img, shoulder, hand, 3.4, coat)
	_line(img, shoulder.lerp(hand, 0.72), shoulder.lerp(hand, 0.86), 3.8, green)   # 초록 소맷부리
	_ellipse(img, hand.x, hand.y, 2.0, 2.0, glove)


## 철제 양손검 — 긴 손잡이(초록 감개), 일자 가드, 무광 철 칼날. 회전축 = 손잡이 가운데 (5.5, 4.5).
## 칼끝까지 ≈ 36 아트px = 72 로컬px (infantry.gd의 BLADE_REACH).
func _infantry_sword() -> Image:
	var img := _new(43, 9)
	var cy := 4
	_ellipse(img, 1.5, 4.5, 1.5, 1.6, _c(92, 94, 102))            # 폼멜
	_rect(img, 2, 3, 7, 3, _c(34, 56, 42))                         # 손잡이 (초록 가죽 감개)
	for x in [3, 5, 7]:
		_put(img, x, 3, _c(62, 98, 72))
	_rect(img, 9, 1, 1, 7, _c(70, 72, 82))                         # 가드
	for x in range(10, 41):
		var hw := 1 if x < 39 else 0
		for y in range(cy - hw, cy + hw + 1):
			var c := _c(138, 144, 154)
			if hw > 0 and y == cy - hw:
				c = _c(196, 200, 208)
			elif hw > 0 and y == cy + hw:
				c = _c(84, 88, 98)
			_put(img, x, y, c)
	_put(img, 41, cy, _c(222, 226, 232))
	_outline(img, _c(8, 8, 12))
	return img


# ═══════════════════════════════ Phase1 — 숲 (placeholder 배경) ═══════════════════════════════
# 월드: 바닥 윗면 y = 0, 싸움터 안쪽 x[-1100, 1100]. 모두 1 아트 픽셀 = 2px, 씬에서 scale 2.
const FOREST_W := 1300   # 중경 나무/바닥 너비(셀) → 월드 x[-1300, 1300]


func _gen_forest() -> void:
	rng.seed = 4401
	_gen_forest_far()
	_gen_forest_trees()
	_gen_forest_ground()
	_gen_forest_edge()
	_gen_forest_fern()
	_gen_forest_leaves()


## 먼 배경: 밤하늘 + 달 + 안개 낀 전나무 능선 두 겹. 2200x800px (SkyLayer, 시차 이동).
func _gen_forest_far() -> void:
	var w := 1100
	var h := 400
	var img := _new(w, h)
	for y in h:
		var c := Color(0.025, 0.04, 0.06).lerp(Color(0.10, 0.17, 0.18), pow(float(y) / h, 1.4))
		for x in w:
			img.set_pixel(x, y, c)
	for i in 140:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, int(h * 0.4))
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.8, 0.9, 0.88), rng.randf_range(0.25, 0.75)))
	var mc := Vector2(380, 70)
	for y in range(int(mc.y) - 44, int(mc.y) + 45):
		for x in range(int(mc.x) - 44, int(mc.x) + 45):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(mc)
			if d <= 13.0:
				var lit := Vector2(x + 0.5, y + 0.5).distance_to(mc + Vector2(-4, -4)) / 21.0
				_put(img, x, y, Color(0.9, 0.95, 0.9).lerp(Color(0.66, 0.74, 0.72), clampf(lit, 0.0, 1.0)))
			elif d <= 44.0:
				_put(img, x, y, _px(img, x, y).lerp(Color(0.5, 0.62, 0.6), pow(1.0 - d / 44.0, 2.0) * 0.3))
	_tree_line(img, 250, 40.0, 90.0, Color(0.085, 0.14, 0.15), 10, 22)
	for y in range(225, 305):
		var k := 1.0 - absf(y - 265.0) / 40.0
		for x in w:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.16, 0.24, 0.24), k * 0.35))
	_tree_line(img, 305, 60.0, 135.0, Color(0.05, 0.085, 0.095), 14, 30)
	_save(img, "environment/forest_far.png")


## 전나무 실루엣 줄 — 톱니 모양 가지 층, 아래는 같은 색으로 채운다.
func _tree_line(img: Image, base_y: int, hmin: float, hmax: float, c: Color, gap_min: int, gap_max: int) -> void:
	var w := img.get_width()
	_rect(img, 0, base_y, w, img.get_height() - base_y, c)
	var x := -rng.randi_range(0, gap_max)
	while x < w + gap_max:
		var th := rng.randf_range(hmin, hmax)
		var half := th * rng.randf_range(0.2, 0.28)
		var tiers := 5
		var right := PackedVector2Array()
		var left := PackedVector2Array()
		for i in range(1, tiers + 1):
			var yy := base_y - th + th * float(i) / tiers
			var hw := half * float(i) / tiers
			right.append(Vector2(x + hw, yy))
			left.append(Vector2(x - hw, yy))
			if i < tiers:
				right.append(Vector2(x + hw * 0.55, yy + 1.0))
				left.append(Vector2(x - hw * 0.55, yy + 1.0))
		var pts := PackedVector2Array([Vector2(x, base_y - th)])
		pts.append_array(right)
		left.reverse()
		pts.append_array(left)
		_poly(img, pts, c)
		x += rng.randi_range(gap_min, gap_max)


## 중경: 큰 나무 줄기들 + 안개 속 가는 줄기 + 위쪽 우거진 잎 + 늘어진 덩굴. 2600x840px, 투명 배경.
func _gen_forest_trees() -> void:
	var w := FOREST_W
	var h := 420
	var img := _new(w, h)
	for i in 26:
		var x := rng.randi_range(0, w)
		_rect(img, x, 0, rng.randi_range(4, 8), h, Color(0.075, 0.115, 0.12))
	for tx in [60, 210, 330, 520, 780, 900, 1080, 1240]:
		_trunk(img, tx, rng.randi_range(16, 30), h)
	# 캐노피 — 아래 가장자리가 출렁이는 잎 덩어리
	var edge: Array[float] = []
	for x in w:
		edge.append(62.0 + 24.0 * sin(x * 0.013) + 13.0 * sin(x * 0.041 + 1.0))
	for x in w:
		for y in int(edge[x]):
			_put(img, x, y, Color(0.035, 0.065, 0.05))
	for i in 520:
		var x := rng.randi_range(0, w - 1)
		var y := edge[x] + rng.randf_range(-22.0, 6.0)
		var col := Color(0.035, 0.065, 0.05) if rng.randf() < 0.55 else Color(0.06, 0.105, 0.075)
		_ellipse(img, x, y, rng.randf_range(5.0, 13.0), rng.randf_range(3.5, 8.0), col)
	for i in 900:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, int(edge[x]) + 4)
		if _px(img, x, y).a > 0.0:
			_put(img, x, y, Color(0.1, 0.18, 0.12))
	# 덩굴
	for i in 16:
		var x0 := rng.randi_range(10, w - 10)
		var len := rng.randi_range(40, 170)
		var ph := rng.randf_range(0.0, TAU)
		for s in len:
			var p := Vector2(x0 + 2.0 * sin(s * 0.08 + ph), edge[x0] + s)
			_put(img, int(p.x), int(p.y), Color(0.05, 0.1, 0.06))
			if s % 6 == 0:
				_ellipse(img, p.x + (1.5 if s % 12 == 0 else -1.5), p.y, 1.6, 1.0, Color(0.07, 0.13, 0.08))
	_save(img, "environment/forest_trees.png")


## 나무 줄기 — 세로 결, 왼쪽 달빛 테두리, 아래 뿌리 퍼짐, 이끼 몇 점.
func _trunk(img: Image, cx: int, tw: int, h: int) -> void:
	var grain: Array[float] = []
	for i in 64:
		grain.append(rng.randf_range(-0.018, 0.018))
	var lean := rng.randf_range(-0.04, 0.04)
	for y in h:
		var flare := 0.0
		if y > h - 36:
			flare = pow((y - (h - 36)) / 36.0, 2.0) * 16.0
		var mid := cx + lean * (h - y)
		var x0 := int(mid - tw * 0.5 - flare)
		var x1 := int(mid + tw * 0.5 + flare)
		for x in range(x0, x1 + 1):
			var u := float(x - x0) / maxf(x1 - x0, 1.0)
			var v: float = grain[(x - int(mid) + 32) % 64]
			var c := Color(0.065 + v, 0.075 + v, 0.07 + v)
			if u < 0.12:
				c = c.lerp(Color(0.15, 0.2, 0.2), 0.6)
			elif u > 0.8:
				c = c.darkened(0.35)
			_put(img, x, y, c)
	for i in 6:
		var my := rng.randi_range(120, h - 20)
		var mx := cx + lean * (h - my) + rng.randf_range(-tw * 0.3, tw * 0.3)
		_ellipse(img, mx, my, rng.randf_range(2.0, 5.0), rng.randf_range(3.0, 7.0), Color(0.1, 0.17, 0.11))


## 흙바닥 — 위 6행은 풀잎(투명 배경), 그 아래가 바닥 윗면(월드 y = 0). 2600x200px.
func _gen_forest_ground() -> void:
	var w := FOREST_W
	var h := 100
	var top := 6
	var img := _new(w, h)
	for y in range(top, h):
		var t := float(y - top) / (h - top)
		for x in w:
			var c := Color(0.15, 0.11, 0.085).lerp(Color(0.04, 0.03, 0.03), clampf(t * 1.6, 0.0, 1.0))
			var n := rng.randf_range(-0.012, 0.012)
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	for i in 120:
		var py := rng.randf_range(top + 7.0, h - 24.0)
		var pr := rng.randf_range(1.0, 2.5)
		_ellipse(img, rng.randf_range(0.0, w), py, pr, pr * 0.7, Color(0.2, 0.18, 0.16).darkened(clampf((py - top) / 60.0, 0.0, 0.8)))
	for i in 14:
		var a := Vector2(rng.randf_range(0.0, w), top + 2.0)
		var dirx := 1.0 if rng.randf() < 0.5 else -1.0
		var b := a + Vector2(dirx * rng.randf_range(20.0, 50.0), rng.randf_range(10.0, 26.0))
		_line(img, a, b, 2.0, Color(0.09, 0.07, 0.055))
	for x in w:
		var drip := int(2.0 + 2.0 * sin(x * 0.3) + rng.randi_range(0, 2))
		for y in range(top, top + 3 + drip):
			var c := Color(0.12, 0.2, 0.12).darkened((y - top) * 0.12)
			if y == top:
				c = Color(0.18, 0.28, 0.16)
			img.set_pixel(x, y, c)
		if rng.randf() < 0.55:
			var gh := rng.randi_range(1, 5)
			var tilt := rng.randi_range(-1, 1)
			for k in gh:
				_put(img, x + (tilt if k > 2 else 0), top - 1 - k, Color(0.14, 0.24, 0.14).lerp(Color(0.22, 0.34, 0.2), float(k) / 5.0))
	_save(img, "environment/forest_ground.png")


## 싸움터 양 끝의 빽빽한 숲 벽 (왼쪽 기준, 오른쪽 면이 안쪽 — 오른쪽은 flip_h). 240x840px.
func _gen_forest_edge() -> void:
	var w := 120
	var h := 420
	var img := _new(w, h)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(0.02, 0.035, 0.03).lerp(Color(0.035, 0.06, 0.05), float(x) / w))
	_trunk(img, 84, 56, h)
	for i in 40:
		_ellipse(img, rng.randf_range(0.0, w), rng.randf_range(350.0, h), rng.randf_range(6.0, 16.0),
				rng.randf_range(4.0, 10.0), Color(0.03, 0.06, 0.045) if i % 2 == 0 else Color(0.05, 0.09, 0.065))
	_save(img, "environment/forest_edge.png")


## 전경 고사리 (화면 아래 가장자리, 어두운 실루엣). 220x80px.
func _gen_forest_fern() -> void:
	var img := _new(110, 40)
	var base := Vector2(55, 39)
	for i in 9:
		var ang := lerpf(-160.0, -20.0, i / 8.0) + rng.randf_range(-8.0, 8.0)
		var droop := 50.0 if ang > -90.0 else -50.0
		var length := rng.randf_range(30.0, 52.0)
		var p := base
		for s in int(length):
			var u := s / length
			var d := Vector2.from_angle(deg_to_rad(ang + u * u * droop))
			p += d
			_put(img, int(p.x), int(p.y), Color(0.05, 0.09, 0.06))
			if s % 3 == 0 and s > 4:
				var leaf := (1.0 - u) * 6.0 + 1.0
				var n := Vector2(-d.y, d.x)
				_line(img, p, p + n * leaf, 1.0, Color(0.025, 0.045, 0.035))
				_line(img, p, p - n * leaf, 1.0, Color(0.025, 0.045, 0.035))
	_save(img, "environment/forest_fern.png")


## 전경 위쪽에 늘어진 잎 가장자리 (어두운 실루엣). 320x120px.
func _gen_forest_leaves() -> void:
	var w := 160
	var h := 60
	var img := _new(w, h)
	var col := Color(0.02, 0.04, 0.03)
	_rect(img, 0, 0, w, 10, col)
	for i in 70:
		var x := rng.randf_range(0.0, w)
		_ellipse(img, x, rng.randf_range(6.0, 22.0), rng.randf_range(4.0, 10.0), rng.randf_range(3.0, 6.0), col)
	for i in 9:
		var x0 := rng.randf_range(4.0, w - 4.0)
		var len := rng.randi_range(14, 52)
		for s in len:
			_put(img, int(x0 + sin(s * 0.2 + i)), 14 + s, col)
			if s % 5 == 0:
				_ellipse(img, x0 + sin(s * 0.2 + i) + 1.5, 14 + s, 1.8, 1.1, col)
	_save(img, "environment/forest_leaves.png")


# ═══════════════════════════════ Phase1 — 제3부대 암살자 ═══════════════════════════════
# 보병보다 가는 실루엣: 같은 제복(초록 포인트) 위에 뒤집어쓴 두건 망토, 앞으로 뾰족한 가면, 한손 단검.
# 프레임 34x50, 발바닥 = 48행, 몸 중심 x = 17. 씬에서 Body는 (0, 28)에 offset (-17, -48), scale 2.
# → 아트 (x, y) = 로컬 (2x - 34, 2y - 68). assassin.gd의 HAND는 각 프레임 "hand"를 이 식으로 옮긴 값이다.
func _gen_assassin() -> void:
	rng.seed = 5501
	var specs := [
		{"hand": Vector2(22, 30), "flutter": 0.5},                                         # 0 idle a
		{"hand": Vector2(22, 30), "breath": 1, "flutter": 1.0},                            # 1 idle b
		{"hand": Vector2(13, 31), "lean": 5.0, "stride": 5.0, "flutter": 6.0},             # 2 dash (순보)
		{"hand": Vector2(22, 33), "crouch": 3, "lean": 2.0, "stride": 3.0, "flutter": 2.0},  # 3 crouch (도착)
		{"hand": Vector2(14, 12), "lean": -2.0, "stride": 3.0, "flutter": 1.5},            # 4 raise (단검을 치켜듦)
		{"hand": Vector2(29, 27), "lean": 5.0, "stride": 6.0, "crouch": 2, "flutter": 3.0},  # 5 stab
		{"hand": Vector2(19, 34), "lean": -3.0, "stride": -1.5, "crouch": 1, "flutter": 2.0},  # 6 hurt / 기절
	]
	var frames: Array[Image] = []
	for sp in specs:
		frames.append(_assassin_frame(sp))
	_save(_sheet(frames), "characters/assassin/assassin.png")
	_save(_assassin_dagger(), "characters/assassin/assassin_dagger.png")


func _assassin_frame(p: Dictionary) -> Image:
	var img := _new(34, 50)
	var cloak := _c(26, 34, 32)
	var uniform := _c(42, 48, 60)
	var trouser := _c(28, 30, 38)
	var boot := _c(14, 14, 18)
	var green := _c(58, 118, 78)
	var mask := _c(206, 200, 184)
	var mask_d := _c(140, 134, 122)
	var slit := _c(10, 12, 12)
	var glove := _c(24, 24, 28)
	var crouch: float = p.get("crouch", 0) + p.get("breath", 0) * 0.5
	var lean: float = p.get("lean", 0.0)
	var stride: float = p.get("stride", 0.0)
	var flutter: float = p.get("flutter", 0.0)
	var hand: Vector2 = p["hand"]
	var ground := 48.0
	var cx := 17.0
	var hip_y := 33.0 + crouch
	var sh := func(v: Vector2) -> Vector2:
		var y := v.y + crouch
		var t := clampf((hip_y - y) / 26.0, 0.0, 1.0)
		return Vector2(v.x + lean * t, y)

	# 등 뒤로 늘어진 망토 (가장 뒤)
	var n: Vector2 = sh.call(Vector2(cx - 2, 13))
	_poly(img, PackedVector2Array([n + Vector2(2, 0), n + Vector2(-6 - flutter, 5), n + Vector2(-8 - flutter * 1.5, 18 - flutter * 0.7),
			n + Vector2(-5 - flutter, 23 - flutter * 0.5), n + Vector2(-1, 21), n + Vector2(3, 8)]), cloak.darkened(0.2))
	# 뒷팔
	_line(img, sh.call(Vector2(cx - 2, 20)), hand + Vector2(-1, 1), 2.6, uniform.darkened(0.35))
	# 다리 (가늘게) + 군화
	var back_foot := Vector2(cx - 2 - stride, ground - 2)
	var front_foot := Vector2(cx + 3 + stride, ground - 2)
	_line(img, Vector2(cx - 1, hip_y), back_foot, 2.8, trouser.darkened(0.3))
	_line(img, Vector2(cx + 2, hip_y), front_foot, 2.8, trouser)
	_rect(img, int(back_foot.x) - 2, int(ground) - 2, 5, 2, boot.darkened(0.2))
	_rect(img, int(front_foot.x) - 1, int(ground) - 2, 5, 2, boot)
	# 몸통 (좁은 제복) + 대각 초록 띠 + 허리띠
	var body := PackedVector2Array()
	for v in [Vector2(cx - 5, 18), Vector2(cx + 5, 18), Vector2(cx + 5, 26), Vector2(cx + 4, 34), Vector2(cx - 5, 34), Vector2(cx - 6, 26)]:
		body.append(sh.call(v))
	_poly(img, body, uniform)
	_line(img, sh.call(Vector2(cx - 4, 19)), sh.call(Vector2(cx + 4, 29)), 1.4, green)
	_poly(img, PackedVector2Array([sh.call(Vector2(cx - 5.5, 30)), sh.call(Vector2(cx + 5, 30)),
			sh.call(Vector2(cx + 5, 31.5)), sh.call(Vector2(cx - 5.5, 31.5))]), green.darkened(0.2))
	# 어깨를 덮는 짧은 망토
	var s0: Vector2 = sh.call(Vector2(cx - 6, 17))
	var s1: Vector2 = sh.call(Vector2(cx + 5, 17))
	_poly(img, PackedVector2Array([s0, s1, s1 + Vector2(1, 4), s0 + Vector2(-1, 6)]), cloak)
	# 두건 (뒤로 뾰족) + 초록 테두리
	var hc: Vector2 = sh.call(Vector2(cx + 1, 11))
	_ellipse(img, hc.x - 0.5, hc.y, 5.5, 6.2, cloak)
	_poly(img, PackedVector2Array([hc + Vector2(-3, -5), hc + Vector2(-10 - flutter * 0.4, -2), hc + Vector2(-4, 2)]), cloak)
	_line(img, hc + Vector2(1, -6), hc + Vector2(5, -2), 1.0, green)
	# 날카로운 가면 — 앞으로 뾰족하게 나온 코, 비스듬한 눈구멍
	_poly(img, PackedVector2Array([hc + Vector2(0, -3), hc + Vector2(4, -3), hc + Vector2(9, 1), hc + Vector2(5, 3),
			hc + Vector2(4, 6), hc + Vector2(0, 5)]), mask)
	_rect(img, int(hc.x), int(hc.y - 2), 1, 7, mask_d)
	_line(img, hc + Vector2(2, -1), hc + Vector2(6, 0), 1.0, slit)
	# 앞팔 + 초록 소맷부리 + 장갑
	var fs: Vector2 = sh.call(Vector2(cx + 3, 20))
	_line(img, fs, hand, 2.8, uniform)
	_line(img, fs.lerp(hand, 0.72), fs.lerp(hand, 0.86), 3.2, green)
	_ellipse(img, hand.x, hand.y, 1.7, 1.7, glove)
	_shade_edges(img, 0.2, 0.25, [slit, green, green.darkened(0.2)])
	_outline(img, _c(8, 8, 12))
	return img


## 한손 단검 — 회전축 = 손잡이 가운데 (3.5, 3.5). 칼끝까지 ≈ 13 아트px = 26 로컬px (assassin.gd의 DAGGER_REACH).
func _assassin_dagger() -> Image:
	var img := _new(19, 7)
	var cy := 3
	_put(img, 1, cy, _c(92, 94, 102))                             # 폼멜
	_rect(img, 2, 2, 4, 2, _c(34, 56, 42))                         # 손잡이 (초록 감개)
	_rect(img, 6, 1, 1, 5, _c(70, 72, 82))                         # 가드
	for x in range(7, 16):
		_put(img, x, cy - 1, _c(206, 210, 216))
		_put(img, x, cy, _c(140, 146, 156) if x < 15 else _c(206, 210, 216))
	_put(img, 16, cy - 1, _c(230, 234, 240))
	_outline(img, _c(8, 8, 12))
	return img


# ═══════════════════════════════ Phase1 — 제3부대 석궁병 ═══════════════════════════════
# 보병과 같은 단정한 제복(초록 포인트) + 둥근 챙 없는 군모, 각지면서도 둥근 가면, 은제 석궁(따로 그려 회전).
# 프레임 34x50, 발바닥 = 48행, 몸 중심 x = 17. 씬에서 Body는 (0, 28)에 offset (-17, -48), scale 2.
# → 아트 (x, y) = 로컬 (2x - 34, 2y - 68). crossbowman.gd의 HAND는 각 프레임 "hand"를 이 식으로 옮긴 값이다.
func _gen_crossbowman() -> void:
	rng.seed = 6601
	var specs := [
		{"hand": Vector2(23, 30)},                                              # 0 idle a
		{"hand": Vector2(23, 30), "breath": 1},                                 # 1 idle b
		{"hand": Vector2(24, 29), "crouch": 2, "stride": 4.0, "lean": 1.0},     # 2 aim (가슴 높이로 겨눔)
		{"hand": Vector2(21, 32), "crouch": 1, "lean": 1.5},                    # 3 reload (아래로 숙여 장전)
		{"hand": Vector2(20, 28), "lean": -4.0, "stride": -3.0},                # 4 retreat (뒤로 순보)
		{"hand": Vector2(19, 33), "lean": -3.0, "stride": -1.5, "crouch": 1},   # 5 hurt / 기절
	]
	var frames: Array[Image] = []
	for sp in specs:
		frames.append(_crossbowman_frame(sp))
	_save(_sheet(frames), "characters/crossbowman/crossbowman.png")
	_save(_crossbow(), "characters/crossbowman/crossbow.png")


func _crossbowman_frame(p: Dictionary) -> Image:
	var img := _new(34, 50)
	var coat := _c(46, 52, 66)
	var trouser := _c(30, 32, 42)
	var boot := _c(14, 14, 18)
	var green := _c(58, 118, 78)
	var cap := _c(30, 34, 44)
	var mask := _c(204, 198, 182)
	var mask_d := _c(140, 134, 122)
	var slit := _c(10, 12, 12)
	var glove := _c(26, 26, 30)
	var crouch: float = p.get("crouch", 0) + p.get("breath", 0) * 0.5
	var lean: float = p.get("lean", 0.0)
	var stride: float = p.get("stride", 0.0)
	var hand: Vector2 = p["hand"]
	var ground := 48.0
	var cx := 17.0
	var hip_y := 33.0 + crouch
	var sh := func(v: Vector2) -> Vector2:
		var y := v.y + crouch
		var t := clampf((hip_y - y) / 26.0, 0.0, 1.0)
		return Vector2(v.x + lean * t, y)

	_line(img, sh.call(Vector2(cx - 3, 20)), hand + Vector2(-1, 1), 3.0, coat.darkened(0.35))
	var back_foot := Vector2(cx - 2 - stride, ground - 2)
	var front_foot := Vector2(cx + 3 + stride, ground - 2)
	_line(img, Vector2(cx - 2, hip_y), back_foot, 3.2, trouser.darkened(0.3))
	_line(img, Vector2(cx + 2, hip_y), front_foot, 3.2, trouser)
	_rect(img, int(back_foot.x) - 2, int(ground) - 2, 6, 2, boot.darkened(0.2))
	_rect(img, int(front_foot.x) - 1, int(ground) - 2, 6, 2, boot)
	# 짧은 제복 상의 (보병보다 짧고 허리가 잘록) + 화살통 띠
	var body := PackedVector2Array()
	for v in [Vector2(cx - 6, 18), Vector2(cx + 5, 18), Vector2(cx + 6, 24), Vector2(cx + 5, 30), Vector2(cx + 6, 36),
			Vector2(cx - 6, 36), Vector2(cx - 6, 30), Vector2(cx - 7, 24)]:
		body.append(sh.call(v))
	_poly(img, body, coat)
	for y in 50:
		var back: Vector2 = sh.call(Vector2(cx - 2, y - crouch))
		for x in 34:
			if x < back.x and img.get_pixel(x, y).is_equal_approx(coat):
				img.set_pixel(x, y, coat.darkened(0.22))
	_line(img, sh.call(Vector2(cx + 4, 19)), sh.call(Vector2(cx - 5, 31)), 1.4, green.darkened(0.15))   # 어깨띠
	_poly(img, PackedVector2Array([sh.call(Vector2(cx - 6.5, 30)), sh.call(Vector2(cx + 6, 30)),
			sh.call(Vector2(cx + 6, 31.5)), sh.call(Vector2(cx - 6.5, 31.5))]), green)
	# 등의 화살통 (짧은 볼트 깃이 삐죽)
	var qv: Vector2 = sh.call(Vector2(cx - 7, 20))
	_rect(img, int(qv.x) - 2, int(qv.y), 3, 11, _c(40, 34, 30))
	for k in 3:
		_put(img, int(qv.x) - 2 + k, int(qv.y) - 1 - (k % 2), _c(180, 186, 190))
	_poly(img, PackedVector2Array([sh.call(Vector2(cx - 4, 16.5)), sh.call(Vector2(cx + 5, 16.5)),
			sh.call(Vector2(cx + 5, 19)), sh.call(Vector2(cx - 4, 19))]), green)
	# 머리: 둥근 군모(초록 띠) + 각지면서도 둥근 가면 (넓은 눈구멍 둘)
	var hc: Vector2 = sh.call(Vector2(cx + 1, 11))
	_ellipse(img, hc.x - 1, hc.y, 5.0, 5.5, cap.darkened(0.35))
	_ellipse(img, hc.x - 0.5, hc.y - 4.5, 6.0, 3.6, cap)
	_rect(img, int(hc.x - 6), int(hc.y - 3), 12, 2, green)
	_poly(img, PackedVector2Array([hc + Vector2(-2, -2), hc + Vector2(4, -2), hc + Vector2(6, 0), hc + Vector2(6.5, 3),
			hc + Vector2(5, 6), hc + Vector2(1, 7), hc + Vector2(-2, 6)]), mask)
	_rect(img, int(hc.x - 2), int(hc.y - 1), 2, 7, mask_d)
	_rect(img, int(hc.x + 1), int(hc.y), 2, 2, slit)
	_rect(img, int(hc.x + 4), int(hc.y), 2, 2, slit)
	_rect(img, int(hc.x + 1), int(hc.y + 4), 4, 1, mask_d)
	# 앞팔
	var fs: Vector2 = sh.call(Vector2(cx + 3, 20))
	_line(img, fs, hand, 3.0, coat)
	_line(img, fs.lerp(hand, 0.72), fs.lerp(hand, 0.86), 3.4, green)
	_ellipse(img, hand.x, hand.y, 1.8, 1.8, glove)
	_shade_edges(img, 0.2, 0.25, [slit, green, green.darkened(0.15)])
	_outline(img, _c(8, 8, 12))
	return img


## 은제 석궁 — 회전축 = 손잡이 (5.5, 10). 볼트가 나가는 앞끝은 회전축에서 (18.5, -3.5) 아트px = (37, -7) 로컬px.
func _crossbow() -> Image:
	var img := _new(27, 15)
	var silver := _c(196, 204, 214)
	var silver_d := _c(120, 128, 142)
	var cy := 7
	_rect(img, 1, cy - 1, 21, 3, silver_d)                        # 몸체
	_rect(img, 1, cy - 1, 21, 1, silver)
	_rect(img, 4, cy + 2, 3, 4, _c(34, 56, 42))                    # 손잡이 (초록 감개)
	_rect(img, 1, cy, 3, 3, silver_d.darkened(0.2))                # 개머리
	for y in range(1, 14):                                         # 활대 (은빛, 위아래로 휜다)
		var bend := int(round(absf(y - cy) * absf(y - cy) / 14.0))
		_put(img, 21 - bend, y, silver)
		_put(img, 22 - bend, y, silver_d)
	_line(img, Vector2(18, 1.5), Vector2(11, cy + 0.5), 1.0, _c(220, 224, 228))   # 시위
	_line(img, Vector2(18, 13.5), Vector2(11, cy + 0.5), 1.0, _c(220, 224, 228))
	_rect(img, 12, cy - 2, 12, 1, _c(150, 156, 166))               # 걸린 볼트
	_put(img, 24, cy - 2, _c(236, 240, 246))
	_outline(img, _c(8, 8, 12))
	return img


# ═══════════════════════════════ Phase1 — 제3부대 거병 ═══════════════════════════════
# 거대한 몸집의 같은 제복(초록 포인트), 각지고 별 무늬가 있는 가면, 매우 거대한 금빛 한손 양날도끼(따로 그려 회전).
# 프레임 48x64, 발바닥 = 62행, 몸 중심 x = 22. 씬에서 Body는 (0, 50)에 offset (-22, -62), scale 2.
# → 아트 (x, y) = 로컬 (2x - 44, 2y - 74). giant.gd의 HAND는 각 프레임 "hand"를 이 식으로 옮긴 값이다.
func _gen_giant() -> void:
	rng.seed = 7701
	var specs := [
		{"hand": Vector2(31, 38)},                                                # 0 idle a
		{"hand": Vector2(31, 38), "breath": 1},                                   # 1 idle b
		{"hand": Vector2(31, 37), "stride": 4.0, "bob": -1},                      # 2 walk
		{"hand": Vector2(31, 38)},                                                # 3 walk
		{"hand": Vector2(31, 37), "stride": -4.0, "bob": -1},                     # 4 walk
		{"hand": Vector2(31, 38)},                                                # 5 walk
		{"hand": Vector2(30, 42), "crouch": 4, "lean": 2.0, "stride": 4.0},       # 6 crouch (돌진 준비)
		{"hand": Vector2(34, 38), "crouch": 2, "lean": 6.0, "stride": 7.0},       # 7 charge
		{"hand": Vector2(22, 8), "lean": -3.0, "stride": 4.0},                    # 8 raise (도끼를 머리 위 뒤로)
		{"hand": Vector2(36, 40), "crouch": 4, "lean": 5.0, "stride": 7.0},       # 9 chop (내려찍은 자세)
		{"hand": Vector2(38, 46), "crouch": 5, "lean": 9.0, "stride": 8.0},       # 10 stumble (앞으로 넘어갈 듯)
		{"hand": Vector2(27, 44), "crouch": 2, "lean": -4.0, "stride": -2.0},     # 11 hurt / 기절
	]
	var frames: Array[Image] = []
	for sp in specs:
		frames.append(_giant_frame(sp))
	_save(_sheet(frames), "characters/giant/giant.png")
	_save(_giant_axe(), "characters/giant/giant_axe.png")


func _giant_frame(p: Dictionary) -> Image:
	var img := _new(48, 64)
	var coat := _c(46, 52, 66)
	var trouser := _c(30, 32, 42)
	var boot := _c(14, 14, 18)
	var green := _c(58, 118, 78)
	var mask := _c(198, 192, 174)
	var mask_d := _c(136, 130, 116)
	var slit := _c(10, 12, 12)
	var glove := _c(26, 26, 30)
	var crouch: float = p.get("crouch", 0) + p.get("breath", 0) * 0.5
	var lean: float = p.get("lean", 0.0)
	var stride: float = p.get("stride", 0.0)
	var bob: float = p.get("bob", 0)
	var hand: Vector2 = p["hand"]
	var ground := 62.0
	var cx := 22.0
	var hip_y := 44.0 + crouch + bob
	var sh := func(v: Vector2) -> Vector2:
		var y := v.y + crouch + bob
		var t := clampf((hip_y - y) / 36.0, 0.0, 1.0)
		return Vector2(v.x + lean * t, y)

	_line(img, sh.call(Vector2(cx - 6, 24)), hand + Vector2(-2, 1), 5.5, coat.darkened(0.35))   # 뒷팔
	var back_foot := Vector2(cx - 4 - stride, ground - 2)
	var front_foot := Vector2(cx + 4 + stride, ground - 2)
	_line(img, Vector2(cx - 4, hip_y), back_foot, 6.0, trouser.darkened(0.3))
	_line(img, Vector2(cx + 4, hip_y), front_foot, 6.0, trouser)
	_rect(img, int(back_foot.x) - 4, int(ground) - 4, 9, 4, boot.darkened(0.2))
	_rect(img, int(front_foot.x) - 3, int(ground) - 4, 9, 4, boot)
	# 넓은 몸통 (두꺼운 어깨, 불룩한 배)
	var body := PackedVector2Array()
	for v in [Vector2(cx - 11, 20), Vector2(cx + 10, 20), Vector2(cx + 12, 28), Vector2(cx + 12, 38), Vector2(cx + 10, 48),
			Vector2(cx - 10, 48), Vector2(cx - 12, 38), Vector2(cx - 13, 28)]:
		body.append(sh.call(v))
	_poly(img, body, coat)
	for y in 64:
		var back: Vector2 = sh.call(Vector2(cx - 4, y - crouch - bob))
		for x in 48:
			if x < back.x and img.get_pixel(x, y).is_equal_approx(coat):
				img.set_pixel(x, y, coat.darkened(0.22))
	_poly(img, PackedVector2Array([sh.call(Vector2(cx - 12.5, 40)), sh.call(Vector2(cx + 12, 40)),
			sh.call(Vector2(cx + 12, 43)), sh.call(Vector2(cx - 12.5, 43))]), green)              # 넓은 초록 허리띠
	_rect(img, int(sh.call(Vector2(cx + 3, 40)).x), int(sh.call(Vector2(cx, 40)).y), 4, 3, _c(196, 160, 70))   # 금 버클
	for y in [25, 30, 35]:
		var b: Vector2 = sh.call(Vector2(cx + 6, y))
		_rect(img, int(b.x), int(b.y), 2, 1, _c(150, 156, 160))
	_poly(img, PackedVector2Array([sh.call(Vector2(cx + 2, 18.5)), sh.call(Vector2(cx + 12, 18.5)),
			sh.call(Vector2(cx + 13, 22)), sh.call(Vector2(cx + 2, 22))]), green.darkened(0.1))   # 견장
	_poly(img, PackedVector2Array([sh.call(Vector2(cx - 6, 17)), sh.call(Vector2(cx + 7, 17)),
			sh.call(Vector2(cx + 7, 21)), sh.call(Vector2(cx - 6, 21))]), green)                  # 깃
	# 머리: 짧게 깎은 뒷머리 + 각진 큰 가면(별 무늬)
	var hc: Vector2 = sh.call(Vector2(cx + 2, 11))
	_ellipse(img, hc.x - 2, hc.y, 7.0, 7.5, _c(28, 28, 34))
	_poly(img, PackedVector2Array([hc + Vector2(-4, -7), hc + Vector2(7, -7), hc + Vector2(8, -5), hc + Vector2(8, 6),
			hc + Vector2(6, 8), hc + Vector2(-3, 8), hc + Vector2(-4, 6)]), mask)
	_rect(img, int(hc.x - 4), int(hc.y - 6), 2, 13, mask_d)
	_rect(img, int(hc.x - 1), int(hc.y - 2), 8, 1, mask_d)
	_rect(img, int(hc.x), int(hc.y - 1), 3, 1, slit)
	_rect(img, int(hc.x + 5), int(hc.y - 1), 3, 1, slit)
	_rect(img, int(hc.x - 1), int(hc.y + 5), 8, 1, mask_d)
	var star := PackedVector2Array()
	var sc := hc + Vector2(3.5, -4.5)
	for i in 10:
		var r := 2.6 if i % 2 == 0 else 1.1
		star.append(sc + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * r)
	_poly(img, star, green)                                                                      # 이마의 별
	_line(img, hc + Vector2(3.5, 1), hc + Vector2(3.5, 4), 1.0, mask_d)                          # 콧날
	# 앞팔 (굵게) + 초록 소맷부리 + 장갑
	var fs: Vector2 = sh.call(Vector2(cx + 6, 24))
	_line(img, fs, hand, 6.0, coat)
	_line(img, fs.lerp(hand, 0.74), fs.lerp(hand, 0.88), 6.4, green)
	_ellipse(img, hand.x, hand.y, 3.0, 3.0, glove)
	_shade_edges(img, 0.2, 0.25, [slit, green, green.darkened(0.1), _c(196, 160, 70)])
	_outline(img, _c(8, 8, 12))
	return img


## 거대한 금빛 한손 양날도끼 — 회전축 = 손잡이 끝 쪽 (4, 15). 도끼머리 중심까지 28 아트px = 56 로컬px.
func _giant_axe() -> Image:
	var img := _new(42, 31)
	var gold := _c(226, 184, 84)
	var gold_l := _c(252, 222, 140)
	var gold_d := _c(150, 104, 44)
	var cy := 15
	_rect(img, 1, cy - 1, 30, 3, _c(70, 46, 32))                   # 자루
	for x in [3, 6, 9]:
		_rect(img, x, cy - 1, 1, 3, _c(40, 70, 52))                 # 초록 감개
	_rect(img, 0, cy - 2, 2, 5, gold_d)                             # 자루 끝
	_rect(img, 28, cy - 4, 6, 9, gold_d)                            # 도끼머리 몸
	# 양날 — 위아래로 크게 휜 초승달 날
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(27, cy + side * 3), Vector2(35, cy + side * 3), Vector2(40, cy + side * 14),
				Vector2(31, cy + side * 11), Vector2(22, cy + side * 14)])
		_poly(img, pts, gold)
		_line(img, Vector2(22, cy + side * 14), Vector2(40, cy + side * 14), 1.0, gold_l)   # 날 끝 반짝
	_rect(img, 30, cy - 1, 2, 3, gold_l)
	_outline(img, _c(30, 18, 8))
	return img
