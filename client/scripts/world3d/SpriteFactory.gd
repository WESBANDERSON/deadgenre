## SpriteFactory — Builds billboard textures for the 2.5D world.
##
## PURPOSE:
##   Provide a deterministic, programmatic fallback for every character/prop
##   billboard so the game looks coherent even before AI-generated art is
##   delivered. When a real generated asset exists under `res://assets/generated/`,
##   we prefer it; otherwise we synthesize a stylized Dreadmyst-flavored sprite.
##
## STYLE TARGET:
##   "Dreadmyst meets Megabonk" — moody dark-fantasy silhouettes with a
##   strong rim/glow color, slight color noise for hand-painted feel,
##   transparent background ready to be billboarded onto a Sprite3D.
##
## EXTENDING:
##   Add a new `_build_<archetype>()` function and register it in
##   `_ARCHETYPE_BUILDERS`. Anything in that map is callable from
##   `build_billboard(archetype, palette)`.
##
## REAL ASSET MAPPING:
##   `generated_path_for(subtype)` returns the canonical
##   `res://assets/generated/characters/<subtype>.png` path. Callers should
##   load that first; this factory is the fallback.
class_name SpriteFactory
extends RefCounted

const SPRITE_W := 128
const SPRITE_H := 192

## Centralized Dreadmyst palette — pulled in by procedural sprites and by
## tile/fog setup so visuals stay coherent.
const PALETTE := {
	"void":      Color(0.04, 0.05, 0.09, 1.0),
	"midnight":  Color(0.10, 0.12, 0.18, 1.0),
	"slate":     Color(0.22, 0.26, 0.34, 1.0),
	"bone":      Color(0.78, 0.78, 0.72, 1.0),
	"mist":      Color(0.55, 0.62, 0.72, 1.0),
	"ember":     Color(0.96, 0.55, 0.20, 1.0),
	"blood":     Color(0.62, 0.13, 0.18, 1.0),
	"witchfire": Color(0.42, 0.92, 0.65, 1.0),
	"ghost":     Color(0.65, 0.78, 0.95, 1.0),
	"copper":    Color(0.72, 0.45, 0.22, 1.0),
	"moss":      Color(0.25, 0.42, 0.22, 1.0),
}

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Returns the canonical generated-asset path for a subtype, regardless of
## whether the file currently exists. Used by content pipeline and loaders.
static func generated_path_for(category: String, subtype: String) -> String:
	return "res://assets/generated/%s/%s.png" % [category, subtype]

## Try to load a generated billboard texture. Returns null when missing or
## when the file is just the asset-generator placeholder (1×1 transparent
## PNG), so callers can fall back to the procedural builder.
const MIN_GENERATED_DIMENSION := 32

static func try_load_generated(category: String, subtype: String) -> Texture2D:
	var path := generated_path_for(category, subtype)
	if not ResourceLoader.exists(path):
		return null
	var tex = load(path)
	if not tex is Texture2D:
		return null
	if tex.get_width() < MIN_GENERATED_DIMENSION or tex.get_height() < MIN_GENERATED_DIMENSION:
		# Placeholder waiting on a real render — keep procedural visuals.
		return null
	return tex

## Build a billboard texture for a known archetype. Always returns a texture.
##   archetype  — "player_warrior", "goblin", "merchant", "oak_tree", etc.
##   subtype    — optional finer identifier (used as color seed)
static func build_billboard(archetype: String, subtype: String = "") -> ImageTexture:
	var img := Image.create(SPRITE_W, SPRITE_H, true, Image.FORMAT_RGBA8)
	# Fill fully transparent
	img.fill(Color(0, 0, 0, 0))

	# Seed RNG from subtype so each variant looks consistent across sessions
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(archetype + ":" + subtype)

	match archetype:
		"player_warrior":  _draw_hero(img, rng, PALETTE["slate"], PALETTE["ember"])
		"player_ranger":   _draw_hero(img, rng, PALETTE["moss"],  PALETTE["witchfire"])
		"player_mage":     _draw_hero(img, rng, PALETTE["midnight"], PALETTE["ghost"])
		"goblin":          _draw_goblin(img, rng, Color(0.22, 0.45, 0.20))
		"goblin_shaman":   _draw_goblin(img, rng, Color(0.20, 0.38, 0.20), true)
		"skeleton":        _draw_skeleton(img, rng)
		"wolf":            _draw_quadruped(img, rng, Color(0.32, 0.28, 0.22))
		"dread_wraith":    _draw_wraith(img, rng)
		"merchant_alice":  _draw_npc(img, rng, Color(0.62, 0.50, 0.32), Color(0.95, 0.82, 0.45))
		"npc":             _draw_npc(img, rng, Color(0.48, 0.42, 0.36), Color(0.80, 0.78, 0.62))
		"oak_tree":        _draw_tree(img, rng)
		"copper_vein":     _draw_rock(img, rng, Color(0.55, 0.32, 0.18))
		"stone_pillar":    _draw_rock(img, rng, Color(0.40, 0.42, 0.45))
		"fish_spot":       _draw_water_ripple(img, rng)
		_:                 _draw_hero(img, rng, PALETTE["slate"], PALETTE["ember"])

	return ImageTexture.create_from_image(img)

## Special-case helper: build a square ground-reticle texture. Returns its
## own ImageTexture so the reticle is not affected by SPRITE_H.
static func build_reticle(color: Color = PALETTE["ember"], size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := size / 2
	var cy := size / 2
	var outer := int(size * 0.46)
	var inner := int(size * 0.38)
	for y in size:
		for x in size:
			var d := Vector2(x - cx, y - cy).length()
			if d <= outer and d >= inner:
				var t := (d - inner) / float(outer - inner)
				var a := 1.0 - abs(t * 2.0 - 1.0)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	# Four cardinal ticks
	for r in range(outer + 1, outer + 5):
		if cx + r < size: img.set_pixel(cx + r, cy, color)
		if cx - r >= 0:   img.set_pixel(cx - r, cy, color)
		if cy + r < size: img.set_pixel(cx, cy + r, color)
		if cy - r >= 0:   img.set_pixel(cx, cy - r, color)
	return ImageTexture.create_from_image(img)

# ─────────────────────────────────────────────────────────────────────────────
# Archetype renderers — programmatic Dreadmyst billboards
# ─────────────────────────────────────────────────────────────────────────────

static func _draw_hero(img: Image, rng: RandomNumberGenerator,
		body: Color, accent: Color) -> void:
	var w := SPRITE_W
	var cx := w / 2
	var ground_y := SPRITE_H - 18

	# Long cloak silhouette (trapezoid)
	_fill_trapezoid(img, cx, ground_y - 96, 28, 54, 96, body.darkened(0.25))
	_fill_trapezoid(img, cx, ground_y - 88, 24, 46, 80, body)

	# Cloak inner shadow
	for y in range(20, 80):
		var alpha := 0.18 * (1.0 - y / 80.0)
		_draw_horizontal_line(img, cx - 18 + y / 6, cx + 18 - y / 6,
				ground_y - 88 + y, Color(0, 0, 0, alpha))

	# Pauldrons (shoulder lumps)
	_fill_circle(img, cx - 16, ground_y - 100, 9, body.darkened(0.15))
	_fill_circle(img, cx + 16, ground_y - 100, 9, body.darkened(0.15))

	# Head/hood
	_fill_circle(img, cx, ground_y - 120, 14, body.darkened(0.40))
	# Hood opening (face shadow)
	_fill_circle(img, cx, ground_y - 116, 10, PALETTE["void"])

	# Glowing eyes — signature Dreadmyst rim color
	_fill_circle(img, cx - 4, ground_y - 117, 2, accent)
	_fill_circle(img, cx + 4, ground_y - 117, 2, accent)
	_fill_circle(img, cx - 4, ground_y - 117, 3, Color(accent.r, accent.g, accent.b, 0.45))
	_fill_circle(img, cx + 4, ground_y - 117, 3, Color(accent.r, accent.g, accent.b, 0.45))

	# Weapon — diagonal blade with accent rim
	_draw_line(img, cx + 22, ground_y - 92, cx + 36, ground_y - 138,
			Color(0.75, 0.75, 0.72), 3)
	_draw_line(img, cx + 22, ground_y - 92, cx + 36, ground_y - 138,
			Color(accent.r, accent.g, accent.b, 0.55), 1)

	# Ground shadow disc
	_fill_ellipse(img, cx, ground_y, 26, 6, Color(0, 0, 0, 0.55))

	# Subtle noise breakup
	_overlay_noise(img, rng, 0.04)


static func _draw_goblin(img: Image, rng: RandomNumberGenerator,
		skin: Color, is_shaman: bool = false) -> void:
	var cx := SPRITE_W / 2
	var ground_y := SPRITE_H - 22

	_fill_ellipse(img, cx, ground_y, 18, 5, Color(0, 0, 0, 0.5))

	# Hunched body
	_fill_ellipse(img, cx, ground_y - 26, 16, 22, skin.darkened(0.10))
	# Loincloth / robe
	var cloth := Color(0.30, 0.20, 0.15) if not is_shaman else Color(0.32, 0.18, 0.40)
	_fill_trapezoid(img, cx, ground_y - 8, 14, 22, 28, cloth)

	# Head with big ears
	_fill_circle(img, cx, ground_y - 52, 14, skin)
	_fill_triangle(img, Vector2(cx - 14, ground_y - 52),
			Vector2(cx - 24, ground_y - 60),
			Vector2(cx - 12, ground_y - 44), skin)
	_fill_triangle(img, Vector2(cx + 14, ground_y - 52),
			Vector2(cx + 24, ground_y - 60),
			Vector2(cx + 12, ground_y - 44), skin)

	# Yellow eyes
	var eye_color := Color(0.95, 0.85, 0.20) if not is_shaman else Color(0.40, 0.95, 0.60)
	_fill_circle(img, cx - 4, ground_y - 54, 2, eye_color)
	_fill_circle(img, cx + 4, ground_y - 54, 2, eye_color)

	# Snaggle teeth
	_draw_horizontal_line(img, cx - 3, cx + 3, ground_y - 47, Color(0.95, 0.93, 0.85))
	img.set_pixel(cx - 2, ground_y - 46, Color(0.95, 0.93, 0.85))
	img.set_pixel(cx + 2, ground_y - 46, Color(0.95, 0.93, 0.85))

	if is_shaman:
		# Staff with green orb
		_draw_line(img, cx - 18, ground_y - 4, cx - 22, ground_y - 68,
				Color(0.30, 0.20, 0.10), 2)
		_fill_circle(img, cx - 22, ground_y - 72, 5, Color(0.40, 0.95, 0.60))
		_fill_circle(img, cx - 22, ground_y - 72, 7,
				Color(0.40, 0.95, 0.60, 0.40))
	else:
		# Crude knife
		_draw_line(img, cx + 16, ground_y - 12, cx + 22, ground_y - 30,
				Color(0.75, 0.72, 0.70), 2)

	_overlay_noise(img, rng, 0.05)


static func _draw_skeleton(img: Image, rng: RandomNumberGenerator) -> void:
	var cx := SPRITE_W / 2
	var ground_y := SPRITE_H - 20
	var bone := PALETTE["bone"]

	_fill_ellipse(img, cx, ground_y, 20, 5, Color(0, 0, 0, 0.5))

	# Pelvis to ribs
	_fill_trapezoid(img, cx, ground_y - 10, 14, 18, 26, bone.darkened(0.15))
	# Ribs (three horizontal bars)
	for i in 3:
		_draw_horizontal_line(img, cx - 9, cx + 9, ground_y - 38 + i * 6,
				bone.darkened(0.30))
	# Spine highlight
	_draw_line(img, cx, ground_y - 40, cx, ground_y - 18, bone.lightened(0.15), 1)

	# Skull
	_fill_circle(img, cx, ground_y - 56, 13, bone)
	# Eye sockets
	_fill_circle(img, cx - 5, ground_y - 58, 3, PALETTE["void"])
	_fill_circle(img, cx + 5, ground_y - 58, 3, PALETTE["void"])
	# Glowing pinpoint inside socket
	img.set_pixel(cx - 5, ground_y - 58, PALETTE["witchfire"])
	img.set_pixel(cx + 5, ground_y - 58, PALETTE["witchfire"])
	# Jaw
	for x in range(-6, 7, 3):
		_draw_vertical_line(img, cx + x, ground_y - 47, ground_y - 43, bone.darkened(0.30))

	# Rusted sword
	_draw_line(img, cx + 14, ground_y - 16, cx + 28, ground_y - 52,
			Color(0.55, 0.42, 0.30), 2)

	_overlay_noise(img, rng, 0.04)


static func _draw_quadruped(img: Image, rng: RandomNumberGenerator, fur: Color) -> void:
	var cx := SPRITE_W / 2
	var ground_y := SPRITE_H - 14

	_fill_ellipse(img, cx, ground_y, 28, 6, Color(0, 0, 0, 0.5))

	# Long body
	_fill_ellipse(img, cx, ground_y - 22, 26, 12, fur)
	# Legs
	for x_off in [-18, -8, 8, 18]:
		_fill_rect(img, cx + x_off - 2, ground_y - 14, 4, 14, fur.darkened(0.20))
	# Head
	_fill_circle(img, cx + 22, ground_y - 28, 10, fur)
	# Snout
	_fill_rect(img, cx + 28, ground_y - 26, 6, 4, fur.darkened(0.10))
	# Ear
	_fill_triangle(img, Vector2(cx + 18, ground_y - 36),
			Vector2(cx + 22, ground_y - 42),
			Vector2(cx + 22, ground_y - 32), fur.darkened(0.20))
	# Eye glow
	img.set_pixel(cx + 24, ground_y - 28, PALETTE["ember"])
	img.set_pixel(cx + 25, ground_y - 28,
			Color(PALETTE["ember"].r, PALETTE["ember"].g, PALETTE["ember"].b, 0.6))
	# Tail
	_draw_line(img, cx - 24, ground_y - 22, cx - 32, ground_y - 30, fur, 3)

	_overlay_noise(img, rng, 0.05)


static func _draw_wraith(img: Image, rng: RandomNumberGenerator) -> void:
	var cx := SPRITE_W / 2
	var ground_y := SPRITE_H - 10

	# Floating ground glow
	_fill_ellipse(img, cx, ground_y, 24, 4,
			Color(PALETTE["witchfire"].r, PALETTE["witchfire"].g,
				PALETTE["witchfire"].b, 0.30))

	# Tattered cloak — wider at bottom, jagged edge
	for y in range(0, 110):
		var t := y / 110.0
		var half_w := lerp(8.0, 28.0, t)
		var alpha := lerp(0.85, 0.10, t)
		var color := PALETTE["midnight"]
		color.a = alpha
		_draw_horizontal_line(img,
				cx - int(half_w + (sin(y * 0.4) * 2.0)),
				cx + int(half_w + (cos(y * 0.4) * 2.0)),
				ground_y - 110 + y,
				color)

	# Skull-like face
	_fill_circle(img, cx, ground_y - 110, 10, PALETTE["bone"].darkened(0.50))
	_fill_circle(img, cx - 4, ground_y - 110, 3, PALETTE["witchfire"])
	_fill_circle(img, cx + 4, ground_y - 110, 3, PALETTE["witchfire"])
	_fill_circle(img, cx - 4, ground_y - 110, 4,
			Color(PALETTE["witchfire"].r, PALETTE["witchfire"].g,
				PALETTE["witchfire"].b, 0.5))
	_fill_circle(img, cx + 4, ground_y - 110, 4,
			Color(PALETTE["witchfire"].r, PALETTE["witchfire"].g,
				PALETTE["witchfire"].b, 0.5))

	_overlay_noise(img, rng, 0.06)


static func _draw_npc(img: Image, rng: RandomNumberGenerator,
		clothes: Color, accent: Color) -> void:
	var cx := SPRITE_W / 2
	var ground_y := SPRITE_H - 18

	_fill_ellipse(img, cx, ground_y, 22, 5, Color(0, 0, 0, 0.5))

	# Robe / tunic
	_fill_trapezoid(img, cx, ground_y - 12, 18, 30, 70, clothes)
	# Belt
	_fill_rect(img, cx - 15, ground_y - 42, 30, 4, accent.darkened(0.20))
	# Chest accent (sash)
	_fill_rect(img, cx - 3, ground_y - 76, 6, 38, accent)

	# Head
	var skin := Color(0.85, 0.72, 0.58)
	_fill_circle(img, cx, ground_y - 90, 12, skin)
	# Hair
	_fill_ellipse(img, cx, ground_y - 96, 13, 7, Color(0.30, 0.20, 0.15))
	# Eyes
	img.set_pixel(cx - 4, ground_y - 90, PALETTE["void"])
	img.set_pixel(cx + 4, ground_y - 90, PALETTE["void"])
	# Mouth
	_draw_horizontal_line(img, cx - 2, cx + 2, ground_y - 84,
			Color(0.45, 0.25, 0.22))

	# Friendly indicator — a tiny glowing exclamation above
	_fill_rect(img, cx - 1, ground_y - 116, 2, 8, PALETTE["ember"])
	img.set_pixel(cx, ground_y - 106, PALETTE["ember"])

	_overlay_noise(img, rng, 0.04)


static func _draw_tree(img: Image, rng: RandomNumberGenerator) -> void:
	var cx := SPRITE_W / 2
	var ground_y := SPRITE_H - 14

	_fill_ellipse(img, cx, ground_y, 36, 7, Color(0, 0, 0, 0.55))

	# Trunk
	_fill_rect(img, cx - 5, ground_y - 80, 10, 70, Color(0.22, 0.16, 0.12))
	_draw_vertical_line(img, cx - 5, ground_y - 80, ground_y - 10,
			Color(0.10, 0.08, 0.06))

	# Canopy — three overlapping dark ellipses
	_fill_ellipse(img, cx - 14, ground_y - 110, 22, 18, Color(0.10, 0.16, 0.10))
	_fill_ellipse(img, cx + 14, ground_y - 116, 24, 20, Color(0.10, 0.16, 0.10))
	_fill_ellipse(img, cx, ground_y - 130, 28, 22, Color(0.12, 0.22, 0.13))

	# Highlight tufts
	for _i in 8:
		var px := cx + rng.randi_range(-26, 26)
		var py := ground_y - 130 + rng.randi_range(-12, 18)
		_fill_circle(img, px, py, 3, Color(0.22, 0.36, 0.20, 0.9))

	# Eerie eye in trunk hollow (Dreadmyst signature)
	_fill_circle(img, cx, ground_y - 50, 3, PALETTE["void"])
	img.set_pixel(cx, ground_y - 50, PALETTE["witchfire"])

	_overlay_noise(img, rng, 0.04)


static func _draw_rock(img: Image, rng: RandomNumberGenerator, base: Color) -> void:
	var cx := SPRITE_W / 2
	var ground_y := SPRITE_H - 18

	_fill_ellipse(img, cx, ground_y, 30, 6, Color(0, 0, 0, 0.5))

	# Rocky polygon
	var pts := [
		Vector2(cx - 30, ground_y - 10),
		Vector2(cx - 22, ground_y - 38),
		Vector2(cx - 8,  ground_y - 50),
		Vector2(cx + 12, ground_y - 48),
		Vector2(cx + 26, ground_y - 30),
		Vector2(cx + 30, ground_y - 8),
	]
	_fill_polygon(img, pts, base)

	# Highlight strokes
	for _i in 6:
		var i := rng.randi_range(0, pts.size() - 2)
		var a: Vector2 = pts[i] + Vector2(0, 4)
		var b: Vector2 = pts[i + 1] + Vector2(0, 4)
		_draw_line(img, int(a.x), int(a.y), int(b.x), int(b.y),
				base.lightened(0.20), 1)

	# Ore vein sparkle for copper variant
	if base.r > 0.5:
		for _i in 4:
			var px := cx + rng.randi_range(-18, 18)
			var py := ground_y - rng.randi_range(15, 40)
			img.set_pixel(px, py, Color(1.0, 0.85, 0.45))

	_overlay_noise(img, rng, 0.05)


static func _draw_water_ripple(img: Image, rng: RandomNumberGenerator) -> void:
	var cx := SPRITE_W / 2
	var ground_y := SPRITE_H - 24

	_fill_ellipse(img, cx, ground_y, 36, 10, Color(0.10, 0.20, 0.32, 0.85))
	_fill_ellipse(img, cx, ground_y - 2, 28, 7, Color(0.20, 0.40, 0.55, 0.85))
	_fill_ellipse(img, cx, ground_y - 4, 18, 4, Color(0.40, 0.65, 0.80, 0.85))

	# Reed accents
	for _i in 4:
		var px := cx + rng.randi_range(-26, 26)
		_draw_vertical_line(img, px, ground_y - 18, ground_y - 6,
				Color(0.30, 0.42, 0.22))

	_overlay_noise(img, rng, 0.03)


# ─────────────────────────────────────────────────────────────────────────────
# Low-level pixel primitives (image-space; no shaders, no draw API)
# ─────────────────────────────────────────────────────────────────────────────

static func _in_bounds(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height()

static func _blend_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if not _in_bounds(img, x, y):
		return
	if color.a >= 0.999:
		img.set_pixel(x, y, color)
		return
	var src := img.get_pixel(x, y)
	var out_a := color.a + src.a * (1.0 - color.a)
	if out_a <= 0.0:
		return
	var out_color := Color(
		(color.r * color.a + src.r * src.a * (1.0 - color.a)) / out_a,
		(color.g * color.a + src.g * src.a * (1.0 - color.a)) / out_a,
		(color.b * color.a + src.b * src.a * (1.0 - color.a)) / out_a,
		out_a)
	img.set_pixel(x, y, out_color)

static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_blend_pixel(img, xx, yy, color)

static func _fill_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for yy in range(cy - r, cy + r + 1):
		for xx in range(cx - r, cx + r + 1):
			var dx := xx - cx
			var dy := yy - cy
			if dx * dx + dy * dy <= r * r:
				_blend_pixel(img, xx, yy, color)

static func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	for yy in range(cy - ry, cy + ry + 1):
		for xx in range(cx - rx, cx + rx + 1):
			var dx := (xx - cx) / float(rx)
			var dy := (yy - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				_blend_pixel(img, xx, yy, color)

static func _fill_trapezoid(img: Image, cx: int, top_y: int,
		top_half_w: int, bottom_half_w: int, h: int, color: Color) -> void:
	for y in h:
		var t := y / float(h)
		var hw := int(lerp(float(top_half_w), float(bottom_half_w), t))
		_draw_horizontal_line(img, cx - hw, cx + hw, top_y + y, color)

static func _fill_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := int(min(a.x, min(b.x, c.x)))
	var max_x := int(max(a.x, max(b.x, c.x)))
	var min_y := int(min(a.y, min(b.y, c.y)))
	var max_y := int(max(a.y, max(b.y, c.y)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_triangle(Vector2(x, y), a, b, c):
				_blend_pixel(img, x, y, color)

static func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign(p, a, b)
	var d2 := _sign(p, b, c)
	var d3 := _sign(p, c, a)
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)

static func _sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)

static func _fill_polygon(img: Image, pts: Array, color: Color) -> void:
	# Simple scan-line fill via triangle fan from pts[0]
	for i in range(1, pts.size() - 1):
		_fill_triangle(img, pts[0], pts[i], pts[i + 1], color)

static func _draw_horizontal_line(img: Image, x0: int, x1: int, y: int, color: Color) -> void:
	var a := mini(x0, x1)
	var b := maxi(x0, x1)
	for x in range(a, b + 1):
		_blend_pixel(img, x, y, color)

static func _draw_vertical_line(img: Image, x: int, y0: int, y1: int, color: Color) -> void:
	var a := mini(y0, y1)
	var b := maxi(y0, y1)
	for y in range(a, b + 1):
		_blend_pixel(img, x, y, color)

static func _draw_line(img: Image, x0: int, y0: int, x1: int, y1: int,
		color: Color, thickness: int = 1) -> void:
	# Bresenham with brush
	var dx := abs(x1 - x0)
	var dy := abs(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var t := thickness / 2
	while true:
		for oy in range(-t, t + 1):
			for ox in range(-t, t + 1):
				_blend_pixel(img, x0 + ox, y0 + oy, color)
		if x0 == x1 and y0 == y1: break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

static func _overlay_noise(img: Image, rng: RandomNumberGenerator, strength: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.02:
				continue
			var n := (rng.randf() - 0.5) * strength
			img.set_pixel(x, y, Color(
				clampf(c.r + n, 0.0, 1.0),
				clampf(c.g + n, 0.0, 1.0),
				clampf(c.b + n, 0.0, 1.0),
				c.a))
