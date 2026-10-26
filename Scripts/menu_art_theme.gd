extends RefCounted
## Title screen artwork in the colour theme: the wall, floor and desk, the cork board and
## its sticky notes, the pencil cup, the coffee mug and the pencil on the How to Play pad.
##
## The pictures are painted, not flat palette colours, so each one has a small "region
## mask" next to it (Assets/main_menu/<name>_mask.png, region number x 40 in the red
## channel). Every region is given a palette colour to stand for; a theme recolours the
## region so its average colour becomes that palette colour's themed version, keeping
## all of the painting's shading and texture. Default theme = the original art.
##     MenuArtTheme.apply(texture_rect, "pin_board")

const MASK_DIR := "res://Assets/main_menu/"

const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D region_mask : filter_nearest;
uniform vec3 mul[8];
void fragment() {
	int region = int(floor(texture(region_mask, UV).r * 255.0 / 40.0 + 0.5));
	if (region > 0 && region < 8) {
		COLOR.rgb = clamp(COLOR.rgb * mul[region], 0.0, 1.0);
	}
}
"""

# picture -> region number -> [the region's average colour in the art, palette colour it stands for]
const REGIONS := {
	"background": {
		1: [Color8(173, 130, 101), "7a6d79"],   # top of the wall
		2: [Color8(193, 132, 95), "92868b"],    # wall
		3: [Color8(150, 85, 78), "96514b"],     # skirting board
		4: [Color8(100, 86, 104), "625467"],    # skirting board shadow line
		5: [Color8(189, 165, 131), "9a8c7a"],   # floorboards
		6: [Color8(175, 139, 117), "8a6f5b"],   # desk
	},
	"pin_board": {
		1: [Color8(238, 205, 168), "ebceb0"],   # wooden frame
		2: [Color8(208, 154, 107), "6d574f"],   # cork
		3: [Color8(222, 184, 143), "ebceb0"],   # Resume Game note
		4: [Color8(248, 233, 183), "e6b67d"],   # Join Game note
		5: [Color8(152, 148, 108), "9eccb3"],   # Host Game note
	},
	"pencil_holder": {
		1: [Color8(228, 216, 203), "ebceb0"],   # the cup
		2: [Color8(153, 117, 109), "b76051"],   # pencils
	},
	"coffee_mug": {
		1: [Color8(195, 134, 127), "e16257"],   # the mug
	},
	"paper": {
		1: [Color8(200, 168, 130), "c2855f"],   # the pencil
	},
}

static var _shader: Shader

static func apply(item: CanvasItem, picture: String) -> void:
	if not REGIONS.has(picture):
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var material := item.material as ShaderMaterial
	if material == null or material.shader != _shader:
		material = ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("region_mask", load(MASK_DIR + picture + "_mask.png"))
		item.material = material
	var multipliers := PackedVector3Array()
	multipliers.resize(8)
	for i in 8:
		multipliers[i] = Vector3.ONE
	for region in REGIONS[picture]:
		var average: Color = REGIONS[picture][region][0]
		var target := ColorTheme.map_color(Color(REGIONS[picture][region][1]), "fill")
		if ColorTheme.current != "default":
			multipliers[region] = Vector3(target.r / maxf(average.r, 0.02), target.g / maxf(average.g, 0.02), target.b / maxf(average.b, 0.02))
	material.set_shader_parameter("mul", multipliers)
