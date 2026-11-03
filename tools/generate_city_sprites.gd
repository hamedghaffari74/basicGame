extends SceneTree

# Parametric SVG sprite generator for the city-building (شهرسازی) set:
# house / pine / oak, levels 1..10, flat style matching existing sprites.
# Run: godot --headless --path <project> --script res://tools/generate_city_sprites.gd

const TILE_PATH := "M15 91 64 70 113 91 64 113Z"
const SHADOW := "#35533a"
const GRASS := "#71a762"
const URBAN := "#8d9491"
const WOOD := "#8a6b4a"
const WOOD_D := "#5d4128"
const WALL := "#e8d9b0"
const WALL_D := "#8a6b4a"
const BRICK := "#c47f5e"
const ROOF := "#a5443c"
const ROOF_D := "#6e2a33"
const ROOF_BLUE := "#5d7aab"
const ROOF_GREEN := "#5b9d60"
const CREAM := "#f2ede0"
const TRUNK := "#775437"
const TRUNK_D := "#4e3520"
const PINE := "#3f9052"
const PINE_D := "#2f6b3c"
const PINE_L := "#55a663"
const OAK := "#4f9c57"
const OAK_D := "#367f4b"
const OAK_L := "#62ad69"
const OAK_LL := "#7cbf7e"
const WIN_LIT := "#ffe9a8"
const WIN_DARK := "#3d4a57"
const WATER := "#6fb7d6"
const STONE := "#9aa0a3"
const LEAF_FLOWER_R := "#e86a8a"
const LEAF_FLOWER_W := "#f2f0f0"
const LEAF_FLOWER_Y := "#e8c34a"


func _initialize() -> void:
	var out_dir := "res://assets/sprites"
	for level: int in range(1, 11):
		_write(out_dir + "/house_%d.svg" % level, _house_svg(level))
		_write(out_dir + "/pine_%d.svg" % level, _pine_svg(level))
		_write(out_dir + "/oak_%d.svg" % level, _oak_svg(level))
	_write(out_dir + "/house.svg", _house_svg(1))
	_write(out_dir + "/pine.svg", _pine_svg(1))
	_write(out_dir + "/oak.svg", _oak_svg(1))
	print("CITY SPRITES: wrote 33 files")
	quit()


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("CITY SPRITES: cannot write %s" % path)
		return
	file.store_string(text)
	file.close()


func _s(parts: Array) -> String:
	var out := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">'
	for part: Variant in parts:
		out += str(part)
	return out + "</svg>"


func _el(cx: int, cy: int, rx: int, ry: int, fill: String, op: String = "") -> String:
	if op.is_empty():
		return '<ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="%s"/>' % [cx, cy, rx, ry, fill]
	return '<ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="%s" opacity="%s"/>' % [cx, cy, rx, ry, fill, op]


func _ci(cx: int, cy: int, r: int, fill: String, stroke: String = "", sw: int = 0, op: String = "") -> String:
	var tail := ""
	if not stroke.is_empty():
		tail += ' stroke="%s" stroke-width="%d"' % [stroke, sw]
	if not op.is_empty():
		tail += ' opacity="%s"' % op
	return '<circle cx="%d" cy="%d" r="%d" fill="%s"%s/>' % [cx, cy, r, fill, tail]


func _rc(x: int, y: int, w: int, h: int, fill: String, stroke: String = "", sw: int = 0, op: String = "") -> String:
	var tail := ""
	if not stroke.is_empty():
		tail += ' stroke="%s" stroke-width="%d" stroke-linejoin="round"' % [stroke, sw]
	if not op.is_empty():
		tail += ' opacity="%s"' % op
	return '<rect x="%d" y="%d" width="%d" height="%d" fill="%s"%s/>' % [x, y, w, h, fill, tail]


func _po(points: String, fill: String, stroke: String = "", sw: int = 0) -> String:
	var tail := ""
	if not stroke.is_empty():
		tail += ' stroke="%s" stroke-width="%d" stroke-linejoin="round"' % [stroke, sw]
	return '<polygon points="%s" fill="%s"%s/>' % [points, fill, tail]


func _pa(d: String, fill: String, stroke: String = "", sw: int = 0) -> String:
	var tail := ""
	if not stroke.is_empty():
		tail += ' stroke="%s" stroke-width="%d" stroke-linecap="round" stroke-linejoin="round"' % [stroke, sw]
	return '<path d="%s" fill="%s"%s/>' % [d, fill, tail]


func _ground(fill: String) -> Array:
	return [_el(64, 108, 45, 9, SHADOW, "0.25"), _pa(TILE_PATH, fill, "", 0)]


func _fence(x0: int, x1: int, top: int, bot: int) -> Array:
	var p: Array = []
	p.append(_rc(x0, top + 6, x1 - x0, 5, WOOD, WOOD_D, 2))
	p.append(_rc(x0, bot - 11, x1 - x0, 5, WOOD, WOOD_D, 2))
	var x := x0
	while x <= x1:
		p.append(_rc(x - 3, top, 6, bot - top, WOOD, WOOD_D, 2))
		x += 20
	return p


func _bush(cx: int, base: int, s: int) -> Array:
	return [
		_ci(cx - s, base - s, s, OAK_L, OAK_D, 2),
		_ci(cx + s, base - s, s, OAK, OAK_D, 2),
		_ci(cx, base - s - 3, s + 1, OAK_LL, OAK_D, 2),
	]


func _flowers(cx: int, base: int, colors: Array) -> Array:
	var p: Array = []
	var offsets: Array = [-8, 0, 8]
	for i in range(mini(3, colors.size())):
		var fx: int = cx + int(offsets[i])
		p.append(_rc(fx - 1, base - 10, 2, 10, OAK_D, "", 0))
		p.append(_ci(fx, base - 12, 3, str(colors[i]), OAK_D, 2))
	return p


func _rocks(cx: int, base: int) -> Array:
	return [
		_el(cx - 8, base - 2, 7, 4, STONE, ""),
		_el(cx + 7, base - 2, 5, 3, "#7d838c", ""),
	]


func _birds() -> Array:
	return [
		_pa("M16 22 q5 -5 10 0 q5 -5 10 0", "none", "#4a5a5a", 2),
		_pa("M88 16 q4 -4 8 0 q4 -4 8 0", "none", "#4a5a5a", 2),
	]


func _pond(cx: int, cy: int, rx: int, ry: int) -> Array:
	return [
		_el(cx, cy, rx, ry, WATER, ""),
		_el(cx - rx / 3, cy - 1, rx / 4, 1, "#d7f0fa", "0.8"),
	]


func _bench(cx: int, base: int) -> Array:
	return [
		_rc(cx - 12, base - 12, 4, 12, WOOD_D, "", 0),
		_rc(cx + 8, base - 12, 4, 12, WOOD_D, "", 0),
		_rc(cx - 14, base - 14, 28, 5, WOOD, WOOD_D, 2),
		_rc(cx - 14, base - 26, 28, 9, WOOD, WOOD_D, 2),
	]


func _lamp(x: int, base: int) -> Array:
	return [
		_rc(x - 2, base - 34, 4, 34, "#3d4a57", "", 0),
		_ci(x, base - 36, 4, WIN_LIT, "#3d4a57", 2),
		_ci(x, base - 36, 8, WIN_LIT, "", 0, "0.25"),
	]


func _chimney(x: int, roof_y: int, h: int) -> Array:
	return [
		_rc(x, roof_y - h, 8, h + 4, BRICK, WALL_D, 2),
		_ci(x + 11, roof_y - h - 4, 3, "#e8e8e8", "", 0, "0.7"),
		_ci(x + 14, roof_y - h - 10, 4, "#e8e8e8", "", 0, "0.5"),
	]


func _house_unit(cx: int, base: int, w: int, wh: int, wall: String, roof: String, roof_d: String, garden: bool = false) -> Array:
	var p: Array = []
	var x0 := cx - w / 2
	p.append(_rc(x0, base - wh, w, wh, wall, WALL_D, 3))
	var rh := wh / 2 + 6
	p.append(_po("%d,%d %d,%d %d,%d" % [x0 - 5, base - wh, x0 + w + 5, base - wh, cx, base - wh - rh], roof, roof_d, 3))
	var dw := maxi(7, w / 5)
	p.append(_rc(cx - dw / 2, base - dw - 7, dw, dw + 7, WOOD_D, "", 0))
	p.append(_ci(cx + dw / 2 - 2, base - dw - 3, 1, WIN_LIT, "", 0))
	var ww := maxi(7, w / 5)
	var wy := base - wh + 5
	p.append(_rc(x0 + 4, wy, ww, ww, WIN_LIT, WALL_D, 2))
	p.append(_rc(x0 + w - 4 - ww, wy, ww, ww, WIN_LIT, WALL_D, 2))
	if garden:
		p.append(_rc(x0 + 4, wy + ww + 1, ww, 3, WOOD, WOOD_D, 1))
		p.append(_ci(x0 + 6, wy + ww - 1, 2, LEAF_FLOWER_R, "", 0))
		p.append(_ci(x0 + 4 + ww - 2, wy + ww - 1, 2, LEAF_FLOWER_Y, "", 0))
		p.append(_rc(x0 + w - 4 - ww, wy + ww + 1, ww, 3, WOOD, WOOD_D, 1))
		p.append(_ci(x0 + w - 2 - ww, wy + ww - 1, 2, LEAF_FLOWER_W, "", 0))
		p.append(_ci(x0 + w - 6, wy + ww - 1, 2, LEAF_FLOWER_R, "", 0))
	return p


func _mansion() -> Array:
	var p: Array = []
	p.append(_rc(36, 52, 56, 42, WALL, WALL_D, 3))
	p.append(_rc(36, 70, 56, 4, WALL_D, "", 0))
	p.append(_po("30,52 98,52 64,34", ROOF, ROOF_D, 3))
	for i in range(4):
		var wx := 42 + i * 13
		p.append(_rc(wx, 56, 7, 9, WIN_LIT, WALL_D, 2))
	p.append_array(_chimney(82, 44, 12))
	for i in range(4):
		var colx := 40 + i * 16
		p.append(_rc(colx, 74, 6, 20, CREAM, WALL_D, 2))
	p.append(_rc(58, 80, 12, 14, WOOD_D, "", 0))
	p.append(_rc(54, 94, 20, 3, STONE, "", 0))
	p.append(_rc(50, 97, 28, 3, "#7d838c", "", 0))
	p.append_array(_bush(28, 98, 6))
	p.append_array(_bush(100, 98, 6))
	return p


func _tower(x: int, top: int, w: int, base: int, wall: String, seed: int) -> Array:
	var p: Array = []
	p.append(_rc(x, top, w, base - top, wall, WALL_D, 3))
	p.append(_rc(x - 2, top - 5, w + 4, 6, WALL_D, "", 0))
	var cols := maxi(2, w / 11)
	var rows := maxi(2, (base - top - 12) / 13)
	var cell := (w - 10) / maxi(1, cols)
	for r in range(rows):
		for c in range(cols):
			var wx := x + 5 + c * cell
			var wy := top + 8 + r * 13
			var ww := maxi(3, cell - 3)
			var lit := (c * 5 + r * 7 + seed) % 3 == 0
			p.append(_rc(wx, wy, ww, 7, WIN_LIT if lit else WIN_DARK, WALL_D, 1))
	if w >= 18:
		p.append(_rc(x + w / 2 - 5, base - 11, 10, 11, WOOD_D, "", 0))
	return p


func _pine(cx: int, base: int, s: float, layers: int) -> Array:
	var p: Array = []
	var trunk_w := maxi(3, int(6.0 * s))
	var trunk_h := maxi(6, int(12.0 * s))
	p.append(_rc(cx - trunk_w / 2, base - trunk_h, trunk_w, trunk_h, TRUNK, TRUNK_D, 2))
	var apex := base - trunk_h - int(30.0 * s)
	var step := maxi(4, int(30.0 * s / float(maxi(1, layers))))
	for i in range(layers):
		var ly := apex + i * step
		var half := int((10.0 + 11.0 * float(i)) * s)
		var shade := PINE_D if i % 2 == 0 else PINE
		if i == 0:
			shade = PINE_L
		p.append(_po("%d,%d %d,%d %d,%d" % [cx - half, ly + step + 4, cx + half, ly + step + 4, cx, ly], shade, TRUNK_D, 2))
	return p


func _crown(cx: int, cy: int, rx: int, ry: int, n: int, r: int, shades: Array) -> Array:
	var p: Array = []
	for i in range(n):
		var ang := TAU * float(i) / float(maxi(1, n)) + 0.4
		var px := cx + int(float(rx) * cos(ang))
		var py := cy + int(float(ry) * sin(ang))
		p.append(_ci(px, py, r, str(shades[i % shades.size()]), OAK_D, 2))
	p.append(_ci(cx, cy, r + 2, str(shades[1 % shades.size()]), OAK_D, 2))
	return p


func _oak(cx: int, base: int, s: float, crown_r: int, apples: bool = false) -> Array:
	var p: Array = []
	var trunk_w := maxi(4, int(7.0 * s))
	var trunk_h := maxi(10, int(20.0 * s))
	p.append(_rc(cx - trunk_w / 2, base - trunk_h, trunk_w, trunk_h, TRUNK, TRUNK_D, 2))
	var cy := base - trunk_h - int(float(crown_r) * 0.7)
	p.append_array(_crown(cx, cy, int(float(crown_r) * s), int(float(crown_r) * 0.75 * s), 6, maxi(4, int(float(crown_r) * 0.45 * s)), [OAK_D, OAK, OAK_L, OAK_LL]))
	if apples:
		p.append(_ci(cx - 8, cy - 2, 2, LEAF_FLOWER_R, "", 0))
		p.append(_ci(cx + 7, cy + 3, 2, LEAF_FLOWER_R, "", 0))
		p.append(_ci(cx + 1, cy - 8, 2, LEAF_FLOWER_R, "", 0))
	return p


func _house_svg(level: int) -> String:
	var p: Array = []
	match level:
		1:
			p.append_array(_ground(GRASS))
			p.append_array(_fence(22, 106, 76, 98))
			p.append(_rc(46, 86, 36, 10, "none", WOOD_D, 3))
			p.append(_rc(30, 78, 5, 20, WOOD, WOOD_D, 2))
			p.append(_rc(93, 78, 5, 20, WOOD, WOOD_D, 2))
			p.append(_pa("M30 80 L98 80", "none", "#d9c9a8", 2))
		2:
			p.append_array(_ground(GRASS))
			p.append_array(_fence(22, 106, 76, 98))
			p.append(_rc(51, 72, 26, 22, WOOD, WOOD_D, 3))
			p.append(_po("46,72 82,72 64,58", "#6b4a2f", WOOD_D, 3))
			p.append(_rc(60, 80, 8, 14, WOOD_D, "", 0))
			p.append(_rc(54, 76, 6, 6, WIN_LIT, WOOD_D, 2))
			p.append_array(_bush(34, 97, 6))
		3:
			p.append_array(_ground(GRASS))
			p.append_array(_house_unit(64, 94, 40, 26, WALL, ROOF, ROOF_D))
			p.append_array(_chimney(78, 62, 12))
			p.append_array(_bush(30, 97, 6))
			p.append_array(_flowers(96, 97, [LEAF_FLOWER_R, LEAF_FLOWER_Y, LEAF_FLOWER_W]))
		4:
			p.append_array(_ground(GRASS))
			p.append_array(_mansion())
			p.append(_rc(60, 100, 8, 10, "#d9c9a8", "", 0))
		5:
			p.append_array(_ground(GRASS))
			p.append_array(_house_unit(42, 94, 30, 20, WALL, ROOF, ROOF_D))
			p.append_array(_house_unit(86, 94, 30, 20, CREAM, ROOF_BLUE, "#3d5578"))
			p.append_array(_bush(64, 97, 6))
		6:
			p.append_array(_ground(GRASS))
			p.append_array(_house_unit(34, 94, 26, 18, WALL, ROOF, ROOF_D))
			p.append_array(_house_unit(64, 94, 28, 20, CREAM, ROOF_BLUE, "#3d5578"))
			p.append_array(_house_unit(94, 94, 26, 18, BRICK, ROOF_GREEN, "#3a6b40"))
		7:
			p.append_array(_ground(GRASS))
			p.append_array(_house_unit(32, 94, 26, 18, WALL, ROOF, ROOF_D, true))
			p.append_array(_house_unit(64, 94, 28, 20, CREAM, ROOF_BLUE, "#3d5578", true))
			p.append_array(_house_unit(96, 94, 26, 18, BRICK, ROOF_GREEN, "#3a6b40", true))
			p.append_array(_bush(48, 98, 5))
			p.append_array(_bush(80, 98, 5))
		8:
			p.append_array(_ground(URBAN))
			p.append_array(_tower(28, 44, 34, 94, WALL, 1))
			p.append_array(_house_unit(90, 94, 26, 18, CREAM, ROOF, ROOF_D))
			p.append_array(_pine(14, 97, 0.5, 2))
		9:
			p.append_array(_ground(URBAN))
			p.append_array(_tower(24, 34, 22, 94, WALL, 2))
			p.append_array(_tower(78, 28, 24, 94, CREAM, 5))
			p.append_array(_house_unit(62, 94, 22, 15, BRICK, ROOF_GREEN, "#3a6b40"))
			p.append_array(_lamp(14, 96))
			p.append_array(_lamp(114, 96))
			p.append_array(_bush(51, 98, 5))
		_:
			p.append_array(_ground(URBAN))
			p.append_array(_tower(14, 40, 20, 94, WALL, 1))
			p.append_array(_tower(38, 26, 22, 94, CREAM, 3))
			p.append_array(_tower(64, 34, 20, 94, BRICK, 6))
			p.append_array(_tower(88, 44, 20, 94, "#b9c4c9", 4))
			p.append_array(_bush(50, 98, 5))
			p.append_array(_bush(80, 98, 5))
			p.append_array(_birds())
	return _s(p)


func _pine_svg(level: int) -> String:
	var p: Array = []
	p.append_array(_ground(GRASS))
	match level:
		1:
			p.append(_rc(61, 78, 5, 18, WOOD, WOOD_D, 2))
			p.append_array(_pine(70, 96, 0.45, 1))
		2:
			p.append_array(_pine(64, 96, 0.7, 2))
		3:
			p.append_array(_pine(64, 96, 0.85, 3))
			p.append_array(_bush(36, 97, 6))
		4:
			p.append_array(_pine(64, 96, 1.0, 4))
			p.append_array(_bush(34, 97, 6))
			p.append_array(_flowers(94, 97, [LEAF_FLOWER_R, LEAF_FLOWER_W, LEAF_FLOWER_Y]))
		5:
			p.append_array(_pine(44, 96, 0.9, 3))
			p.append_array(_pine(86, 96, 0.7, 3))
		6:
			p.append_array(_pine(36, 96, 0.8, 3))
			p.append_array(_pine(64, 96, 0.95, 3))
			p.append_array(_pine(92, 96, 0.75, 3))
		7:
			p.append_array(_pine(28, 96, 0.7, 3))
			p.append_array(_pine(52, 96, 0.9, 3))
			p.append_array(_pine(78, 96, 0.8, 3))
			p.append_array(_pine(100, 96, 0.65, 2))
			p.append_array(_bush(40, 98, 5))
			p.append_array(_bush(90, 98, 5))
		8:
			p.append_array(_pine(24, 96, 0.65, 3))
			p.append_array(_pine(44, 96, 0.9, 4))
			p.append_array(_pine(66, 96, 1.0, 4))
			p.append_array(_pine(88, 96, 0.8, 3))
			p.append_array(_pine(106, 96, 0.6, 2))
			p.append_array(_flowers(34, 98, [LEAF_FLOWER_Y, LEAF_FLOWER_R, LEAF_FLOWER_W]))
		9:
			p.append_array(_pine(22, 96, 0.6, 3))
			p.append_array(_pine(40, 96, 0.85, 4))
			p.append_array(_pine(58, 96, 0.95, 4))
			p.append_array(_pine(76, 96, 0.85, 4))
			p.append_array(_pine(94, 96, 0.7, 3))
			p.append_array(_pine(108, 96, 0.55, 2))
			p.append_array(_rocks(50, 99))
		_:
			p.append_array(_pine(20, 96, 0.6, 3))
			p.append_array(_pine(36, 96, 0.8, 4))
			p.append_array(_pine(52, 96, 0.7, 3))
			p.append_array(_pine(68, 96, 0.95, 4))
			p.append_array(_pine(84, 96, 0.8, 4))
			p.append_array(_pine(99, 96, 0.65, 3))
			p.append_array(_pine(111, 96, 0.5, 2))
			p.append_array(_bush(30, 99, 5))
			p.append_array(_bush(92, 99, 5))
			p.append_array(_birds())
	return _s(p)


func _oak_svg(level: int) -> String:
	var p: Array = []
	p.append_array(_ground(GRASS))
	match level:
		1:
			p.append(_rc(62, 76, 4, 20, WOOD, WOOD_D, 2))
			p.append(_ci(64, 70, 7, OAK_L, OAK_D, 2))
			p.append(_rc(56, 78, 4, 18, WOOD, WOOD_D, 2))
		2:
			p.append_array(_oak(64, 96, 0.7, 12))
		3:
			p.append_array(_oak(64, 96, 0.85, 15))
			p.append_array(_bush(36, 97, 6))
		4:
			p.append_array(_oak(64, 96, 1.0, 18, true))
			p.append_array(_flowers(36, 97, [LEAF_FLOWER_R, LEAF_FLOWER_Y, LEAF_FLOWER_W]))
		5:
			p.append_array(_oak(44, 96, 0.85, 15))
			p.append_array(_oak(86, 96, 0.7, 13))
		6:
			p.append_array(_oak(34, 96, 0.75, 14))
			p.append_array(_oak(64, 96, 0.95, 17))
			p.append_array(_oak(94, 96, 0.7, 13))
		7:
			p.append_array(_oak(28, 96, 0.7, 13))
			p.append_array(_oak(52, 96, 0.9, 16))
			p.append_array(_oak(78, 96, 0.8, 14))
			p.append_array(_oak(102, 96, 0.6, 11))
			p.append_array(_flowers(40, 98, [LEAF_FLOWER_W, LEAF_FLOWER_R, LEAF_FLOWER_Y]))
			p.append_array(_bush(90, 98, 5))
		8:
			p.append_array(_oak(30, 96, 0.7, 13))
			p.append_array(_oak(54, 96, 0.9, 16))
			p.append_array(_oak(80, 96, 0.8, 14))
			p.append_array(_oak(102, 96, 0.6, 11))
			p.append_array(_pond(86, 102, 13, 5))
			p.append_array(_bush(42, 98, 5))
		9:
			p.append_array(_oak(28, 96, 0.7, 13))
			p.append_array(_oak(56, 96, 0.9, 16))
			p.append_array(_oak(84, 96, 0.8, 15))
			p.append_array(_oak(106, 96, 0.55, 10))
			p.append_array(_bench(44, 98))
			p.append_array(_flowers(72, 98, [LEAF_FLOWER_R, LEAF_FLOWER_Y, LEAF_FLOWER_W]))
		_:
			p.append_array(_oak(22, 96, 0.65, 13))
			p.append_array(_oak(40, 96, 0.85, 16))
			p.append_array(_oak(60, 96, 0.75, 14))
			p.append_array(_oak(80, 96, 0.9, 16))
			p.append_array(_oak(99, 96, 0.7, 13))
			p.append_array(_oak(112, 96, 0.5, 10))
			p.append_array(_bush(32, 99, 5))
			p.append_array(_bush(90, 99, 5))
			p.append_array(_birds())
	return _s(p)
