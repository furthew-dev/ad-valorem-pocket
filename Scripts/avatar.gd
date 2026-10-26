extends RefCounted
## Player characters ("avatars"): a head built from four stacked layers of art in
## Assets/icons/character, bottom to top:
##     1. skin tone   (the round head, tinted)
##     2. expression
##     3. accessory   (glasses, ears...)
##     4. hair or hat (hair can be dyed; hats keep their colours)
## on a round badge in the background colour the player picked.
## A character is stored and sent as six numbers, [skin, face, accessory, top, hair colour,
## background], indexes into the lists below. (Older saves with four numbers still work.)
## Use it with:
##     const Avatar = preload("res://Scripts/avatar.gd")
##     var icon := Avatar.make(Avatar.for_name("Erika"), 64)

const DIR := "res://Assets/icons/character/"
const LAYERS := ["Skin", "Face", "Accessory", "Hair / Hat", "Hair Colour", "Background"]
const COUNT := 6

const SKINS := [
	["Porcelain", Color("f6e1d3")], ["Ivory", Color("f1d0b5")], ["Peach", Color("eebd9c")],
	["Sand", Color("deb08a")], ["Honey", Color("c99064")], ["Caramel", Color("b07848")],
	["Bronze", Color("8f5b37")], ["Chestnut", Color("6f4429")], ["Espresso", Color("4b2e1e")],
	["Alien Green", Color("9ccf7a")], ["Ocean Blue", Color("7fb2dd")], ["Lavender", Color("b9a0dc")],
	["Bubblegum", Color("f2a3c4")], ["Pumpkin", Color("f0a04b")], ["Ghost", Color("e8e8ef")],
]
const FACES := [
	["Funko", "expressions/12.png"], ["Cheerful", "expressions/13.png"],
	["Starstruck", "expressions/14.png"], ["Jack-o'-Lantern", "expressions/15.png"],
	["Mischief", "expressions/16.png"], ["Angry", "expressions/17.png"],
	["Appalled", "expressions/18.png"], ["Unimpressed", "expressions/19.png"],
	["Labubu Grin", "expressions/20.png"], ["Blissful", "expressions/21.png"],
	["Goofy", "expressions/22.png"], ["Fuming", "expressions/23.png"],
]
const ACCESSORIES := [
	["None", ""], ["Aviators", "accessories/24.png"], ["Glasses", "accessories/25.png"],
	["Shutter Shades", "accessories/26.png"], ["Cracked Glasses", "accessories/27.png"],
	["Nerd Glasses", "accessories/28.png"], ["Disguise Kit", "accessories/29.png"],
	["Elf Ears", "accessories/10.png"], ["Battle Scar", "accessories/11.png"],
]
const TOPS := [
	["Bald", ""],
	["Swoop", "Hair_Hats/hair_styles/style1.png"], ["Side Part", "Hair_Hats/hair_styles/style2.png"],
	["Pompadour", "Hair_Hats/hair_styles/style3.png"], ["Curly Crop", "Hair_Hats/hair_styles/style4.png"],
	["Silver Fox", "Hair_Hats/hair_styles/style5.png"], ["Spikes", "Hair_Hats/hair_styles/style6.png"],
	["Big Bob", "Hair_Hats/hair_styles/style7.png"], ["Long Waves", "Hair_Hats/hair_styles/style8.png"],
	["Platinum Waves", "Hair_Hats/hair_styles/style9.png"], ["Shag", "Hair_Hats/hair_styles/style10.png"],
	["Fringe & Tuft", "Hair_Hats/hair_styles/style11.png"], ["Rock Star", "Hair_Hats/hair_styles/style12.png"],
	["Top Knot", "Hair_Hats/hair_styles/style13.png"],
	["Baseball Cap", "Hair_Hats/hats/baseball_hat.png"], ["Beanie", "Hair_Hats/hats/beanie.png"],
	["Beret", "Hair_Hats/hats/french_hat.png"], ["Kitty Ears", "Hair_Hats/hats/kitty_ears.png"],
	["Pirate Hat", "Hair_Hats/hats/pirate_hat.png"], ["Pumpkin Hat", "Hair_Hats/hats/pumpkin_hat.png"],
	["Winter Hat", "Hair_Hats/hats/winter_hat.png"], ["Witch Hat", "Hair_Hats/hats/witch_hat.png"],
]

# Dye for the hair art (it's drawn in greys). "Natural" leaves it as drawn.
const HAIR_COLORS := [
	["Natural", Color(0, 0, 0, 0)], ["Jet Black", Color("2b2624")], ["Chocolate", Color("6b4430")],
	["Auburn", Color("9a4a2c")], ["Copper", Color("c8733a")], ["Golden Blonde", Color("e5c06e")],
	["Platinum", Color("f2ead2")], ["Silver", Color("c9ccd3")], ["Cotton Candy", Color("f39bc2")],
	["Electric Blue", Color("4f8fe6")], ["Mint", Color("7fd6a6")], ["Grape", Color("8b5cc7")],
	["Cherry", Color("d23c4a")],
]
const BACKGROUNDS := [
	["Cream", Color("e9dcb5")], ["Sage", Color("aebd98")], ["Sky", Color("a9cbe6")],
	["Blush", Color("efc0c2")], ["Lavender", Color("c9b8e3")], ["Mint", Color("b6e2c8")],
	["Sunshine", Color("f4dc7a")], ["Coral", Color("f0a487")], ["Plum", Color("7d5468")],
	["Slate", Color("6f7c8c")], ["Charcoal", Color("3c3a3f")], ["Snow", Color("f7f5ef")],
]
const BADGE := Color("e9dcb5")
const BADGE_BORDER := Color("533c44")

static var _white_skin: Texture2D   # the head shape in white, so it can be tinted any colour


## ---- DATA ----
static func options(layer: int) -> Array:
	return [SKINS, FACES, ACCESSORIES, TOPS, HAIR_COLORS, BACKGROUNDS][layer]

# The first TOPS that are hairstyles (dyeable); after them come the hats.
static func is_hair(top: int) -> bool:
	return TOPS[top][1].contains("hair_styles")

static func part_name(layer: int, index: int) -> String:
	var list := options(layer)
	return list[posmod(index, list.size())][0]

static func random_code() -> Array:
	var code := []
	for layer in COUNT:
		code.append(randi() % options(layer).size())
	return code

# Any value (a save, a message from another phone) -> six valid numbers. A four-number
# character from before hair colour and background existed gets the defaults for those.
static func normalize(code) -> Array:
	if not code is Array or code.size() < 4:
		return [0, 0, 0, 0, 0, 0]
	var out := []
	for layer in COUNT:
		var value = code[layer] if layer < code.size() else 0
		out.append(posmod(int(value) if (value is int or value is float) else 0, options(layer).size()))
	return out

# The character a player picked, by the name shown in the game.
static func for_name(player_name: String) -> Array:
	return normalize(Network.avatars.get(player_name, Network.avatars.get(player_name.trim_suffix(" (reconnecting)"), null)))

static func has_name(player_name: String) -> bool:
	return Network.avatars.has(player_name)


## ---- DRAWING ----
# A round badge with the character on it, `size` pixels across. Tapping does nothing
# unless you connect to it (it passes taps through by default).
static func make(code: Array, size: float, badge: bool = true) -> Control:
	code = normalize(code)
	var root := Control.new()
	root.custom_minimum_size = Vector2(size, size)
	root.size = Vector2(size, size)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("ct_skip", true)   # art colours stay as drawn in every theme
	if badge:
		var circle := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = BACKGROUNDS[code[5]][1]
		style.border_color = ColorTheme.map_color(BADGE_BORDER, "fill")
		style.set_border_width_all(maxi(2, int(size * 0.04)))
		style.set_corner_radius_all(int(size))
		style.anti_aliasing = true
		circle.add_theme_stylebox_override("panel", style)
		circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle.set_meta("ct_skip", true)
		root.add_child(circle)
	var art := Control.new()   # the 200x200 art, a little inside the badge
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := size * (0.02 if badge else 0.0)
	art.offset_left = inset
	art.offset_top = inset
	art.offset_right = -inset
	art.offset_bottom = -inset
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_meta("ct_skip", true)
	root.add_child(art)
	var skin := _layer(art, _skin_texture())
	skin.self_modulate = SKINS[code[0]][1]
	_layer(art, _texture(FACES[code[1]][1]))
	_skin_tint(_layer(art, _texture(ACCESSORIES[code[2]][1])), code)
	_dye(_layer(art, _texture(TOPS[code[3]][1])), code)
	root.set_meta("avatar_code", code)
	return root

# Re-draws an icon made by make() with another character (the editor's preview).
static func update(icon: Control, code: Array) -> void:
	code = normalize(code)
	var art: Control = icon.get_child(icon.get_child_count() - 1)
	art.get_child(0).self_modulate = SKINS[code[0]][1]
	art.get_child(1).texture = _texture(FACES[code[1]][1])
	art.get_child(2).texture = _texture(ACCESSORIES[code[2]][1])
	_skin_tint(art.get_child(2), code)
	art.get_child(3).texture = _texture(TOPS[code[3]][1])
	_dye(art.get_child(3), code)
	if icon.get_child_count() > 1:   # the badge
		var style: StyleBoxFlat = icon.get_child(0).get_theme_stylebox("panel")
		style.bg_color = BACKGROUNDS[code[5]][1]
	icon.set_meta("avatar_code", code)

static func for_player(player_name: String, size: float) -> Control:
	return make(for_name(player_name), size)

static func _layer(parent: Control, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_meta("ct_skip", true)
	parent.add_child(rect)
	return rect

# Hair is drawn in greys: the dye shader colours it by brightness (shadows stay darker,
# highlights lighter), so the strands still show. Hats are left alone.
const DYE_SHADER := """
shader_type canvas_item;
uniform vec4 dye : source_color;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(clamp(dye.rgb * (0.62 + 0.75 * l), 0.0, 1.0), c.a * COLOR.a);
}
"""
static var _dye_shader: Shader

static func _dye(rect: TextureRect, code: Array) -> void:
	var color: Color = HAIR_COLORS[code[4]][1]
	if color.a == 0.0 or not is_hair(code[3]):
		rect.material = null
		return
	if _dye_shader == null:
		_dye_shader = Shader.new()
		_dye_shader.code = DYE_SHADER
	var material := ShaderMaterial.new()
	material.shader = _dye_shader
	material.set_shader_parameter("dye", color)
	rect.material = material

# Elf Ears are drawn in the same grey as the head art: tint them to the skin colour
# (the grey becomes exactly the skin; the darker inner line stays darker).
const SKIN_PARTS := ["accessories/10.png"]
const SKIN_GREY := 172.0 / 255.0
const SKIN_SHADER := """
shader_type canvas_item;
uniform vec4 skin : source_color;
uniform float grey = 0.675;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(clamp(skin.rgb * c.rgb / grey, 0.0, 1.0), c.a * COLOR.a);
}
"""
static var _skin_shader: Shader

static func _skin_tint(rect: TextureRect, code: Array) -> void:
	if not ACCESSORIES[code[2]][1] in SKIN_PARTS:
		rect.material = null
		return
	if _skin_shader == null:
		_skin_shader = Shader.new()
		_skin_shader.code = SKIN_SHADER
	var material := ShaderMaterial.new()
	material.shader = _skin_shader
	material.set_shader_parameter("skin", SKINS[code[0]][1])
	material.set_shader_parameter("grey", SKIN_GREY)
	rect.material = material

static func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	return load(DIR + path)

# skjin_color.png is a grey circle; a white copy can be tinted to exactly the skin colour.
static func _skin_texture() -> Texture2D:
	if _white_skin == null:
		var source: Texture2D = load(DIR + "skjin_color.png")
		var image := source.get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				if c.a > 0.0:
					image.set_pixel(x, y, Color(1, 1, 1, c.a))
		_white_skin = ImageTexture.create_from_image(image)
	return _white_skin
