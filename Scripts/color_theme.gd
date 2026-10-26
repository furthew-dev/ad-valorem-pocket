extends Node
## Colour themes (Settings > Theme). Autoloaded as "ColorTheme".
##
## The game is drawn in the 24 colours of base_color_palette.tres. A theme swaps each of
## those for its own colour, on every screen, as it opens: scene styles, colours set in
## scripts, the project theme, and flat one-colour artwork (the top/bottom bars, the
## Back/Home/Menu icons, the pop-up paper, the black app icons). Photos and illustrations
## (property icons, Fortuna cards) are left alone.
##
## Colours are looked up by role: "fill" for backgrounds, panels and art, "text" for font
## colours. Dark themes also turn black writing and black line icons light ("ink").
## Add a theme: add it to NAMES / ORDER and give it a "fill" map (default hex -> new hex),
## a "text" map, and "ink" ("" keeps black writing black).

signal theme_changed(key: String)

const NAMES := {"default": "Default", "dark": "Dark Mode", "rosey": "Rosey", "retro": "Retro", "neon": "Neon"}
const ORDER := ["default", "dark", "rosey", "retro", "neon"]
const SETTINGS_SECTION := "display"

const THEMES := {
	"dark": {
		"fill": {"49343d": "101014", "533c44": "1a1a20", "744145": "5a2f36", "96514b": "7a3d3a", "b76051": "9a4e43", "c2855f": "9c6b4b", "cba77a": "c9a86a", "99966d": "2a2c27", "7b7e63": "4c5a45", "5d6558": "3b4540", "534650": "24212a", "625467": "2f2b36", "7a6d79": "3c3744", "92868b": "55505f", "b3a999": "6b6878", "ddcf99": "3a3830", "c0b18f": "18181d", "9a8c7a": "4a4744", "807269": "26252c", "655757": "2a2629", "574749": "211e22", "6d574f": "2e2826", "8a6f5b": "4a3f37", "a78767": "7a6650", "2e2328": "0c0c10", "793c44": "5a2f36", "5a1f22": "3a1416", "e16257": "6e3833", "e6b67d": "4a3f33", "d8d74b": "56532a", "9eccb3": "2d4a40", "cbac93": "4a4038", "adca96": "3d4a33", "9cbf80": "3a4a30", "ab966f": "5a4e3a", "749c5c": "3c5a33", "ebceb0": "4a3f37"},
		"text": {"49343d": "c9c9cf", "533c44": "c9c9cf", "744145": "d5c3c6", "96514b": "d6c3c2", "b76051": "d7c4c1", "c2855f": "d6cac2", "cba77a": "d9d0bf", "99966d": "ccceca", "7b7e63": "cbd0c8", "5d6558": "cacecc", "534650": "cbc9cf", "625467": "cbc9cf", "7a6d79": "cbc9cf", "92868b": "cbcace", "b3a999": "cbcace", "ddcf99": "ece0c0", "c0b18f": "c9c9cf", "9a8c7a": "cdcccb", "807269": "cacace", "655757": "cdcbcd", "574749": "cdcace", "6d574f": "cfcbc9", "8a6f5b": "d0cbc8", "a78767": "d2ccc6", "2e2328": "c8c8d0", "793c44": "d5c3c6", "5a1f22": "dabec0", "e16257": "d6c3c2", "e6b67d": "d1ccc7", "d8d74b": "d6d4c2", "9eccb3": "c5d3ce", "cbac93": "d0ccc8", "adca96": "cbd1c7", "9cbf80": "cbd2c6", "ab966f": "d2cec6", "749c5c": "c8d4c4", "ebceb0": "d0cbc8"},
		"ink": "ece8f2",
	},
	"rosey": {
		"fill": {"49343d": "5c2340", "533c44": "6e2b4d", "744145": "a8456a", "96514b": "c4587a", "b76051": "e07a8f", "c2855f": "eb9ba5", "cba77a": "f7c6cf", "99966d": "f2c4d0", "7b7e63": "b5839d", "5d6558": "8f5f7a", "534650": "5e2c48", "625467": "7e4a68", "7a6d79": "a07090", "92868b": "c697b2", "b3a999": "e6c7d4", "ddcf99": "ffe3ea", "c0b18f": "f6d6df", "9a8c7a": "c9a0b0", "807269": "e3afc0", "655757": "8a5468", "574749": "6b3a50", "6d574f": "8e5266", "8a6f5b": "b07a8d", "a78767": "d49aac", "2e2328": "4a1c34", "793c44": "a8456a", "5a1f22": "6b1f3a", "e16257": "ef9aac", "e6b67d": "f4c1cc", "d8d74b": "5e2c45", "9eccb3": "f3c9d6", "cbac93": "eabfca", "adca96": "e4b3c4", "9cbf80": "d99db2", "ab966f": "c98ea3", "749c5c": "b5839d", "ebceb0": "fbd9e2"},
		"text": {"49343d": "5c2340", "533c44": "6e2b4d", "744145": "a8456a", "96514b": "c4587a", "b76051": "e07a8f", "c2855f": "eb9ba5", "cba77a": "f7c6cf", "99966d": "f2c4d0", "7b7e63": "b5839d", "5d6558": "8f5f7a", "534650": "5e2c48", "625467": "7e4a68", "7a6d79": "a07090", "92868b": "c697b2", "b3a999": "e6c7d4", "ddcf99": "ffe3ea", "c0b18f": "f6d6df", "9a8c7a": "c9a0b0", "807269": "e3afc0", "655757": "8a5468", "574749": "6b3a50", "6d574f": "8e5266", "8a6f5b": "b07a8d", "a78767": "d49aac", "2e2328": "4a1c34", "793c44": "a8456a", "5a1f22": "6b1f3a", "e16257": "ef9aac", "e6b67d": "f4c1cc", "d8d74b": "5e2c45", "9eccb3": "f3c9d6", "cbac93": "eabfca", "adca96": "e4b3c4", "9cbf80": "d99db2", "ab966f": "c98ea3", "749c5c": "b5839d", "ebceb0": "fbd9e2", "f6f2e1": "5c2340"},
		"ink": "",
	},
	"retro": {
		"fill": {"49343d": "3b2618", "533c44": "4e3220", "744145": "9c3d1c", "96514b": "c2502a", "b76051": "e0702c", "c2855f": "eb9a3a", "cba77a": "f3c04a", "99966d": "f0dca8", "7b7e63": "7d9a4a", "5d6558": "3f7a72", "534650": "4a3426", "625467": "2f6b70", "7a6d79": "5f8a86", "92868b": "3e8c8a", "b3a999": "d7c49a", "ddcf99": "fbecc8", "c0b18f": "efd9a7", "9a8c7a": "c79e64", "807269": "d58a3c", "655757": "6b4029", "574749": "553522", "6d574f": "7a4a2c", "8a6f5b": "a8693a", "a78767": "cf9445", "2e2328": "2e1d12", "793c44": "9c3d1c", "5a1f22": "5c2414", "e16257": "e5793a", "e6b67d": "f0c56a", "d8d74b": "553522", "9eccb3": "b8cf8a", "cbac93": "e7c58f", "adca96": "a8bf6a", "9cbf80": "8fad55", "ab966f": "c79e64", "749c5c": "6b8f47", "ebceb0": "f5d9a8"},
		"text": {"49343d": "3b2618", "533c44": "4e3220", "744145": "9c3d1c", "96514b": "c2502a", "b76051": "e0702c", "c2855f": "eb9a3a", "cba77a": "f3c04a", "99966d": "f0dca8", "7b7e63": "7d9a4a", "5d6558": "3f7a72", "534650": "4a3426", "625467": "2f6b70", "7a6d79": "5f8a86", "92868b": "3e8c8a", "b3a999": "d7c49a", "ddcf99": "fbecc8", "c0b18f": "efd9a7", "9a8c7a": "c79e64", "807269": "d58a3c", "655757": "6b4029", "574749": "553522", "6d574f": "7a4a2c", "8a6f5b": "a8693a", "a78767": "cf9445", "2e2328": "2e1d12", "793c44": "9c3d1c", "5a1f22": "5c2414", "e16257": "e5793a", "e6b67d": "f0c56a", "d8d74b": "553522", "9eccb3": "b8cf8a", "cbac93": "e7c58f", "adca96": "a8bf6a", "9cbf80": "8fad55", "ab966f": "c79e64", "749c5c": "6b8f47", "ebceb0": "f5d9a8", "f6f2e1": "3b2618"},
		"ink": "",
	},
	"neon": {
		"fill": {"49343d": "07071a", "533c44": "12122e", "744145": "7a0f6b", "96514b": "d4145a", "b76051": "c4146e", "c2855f": "ff7a1a", "cba77a": "00f0ff", "99966d": "1b1840", "7b7e63": "0b6e6e", "5d6558": "0a4a52", "534650": "1a1238", "625467": "2e1a5c", "7a6d79": "47308a", "92868b": "4b2aa8", "b3a999": "6c5ce7", "ddcf99": "1f2a5c", "c0b18f": "0d0d22", "9a8c7a": "3b3a7a", "807269": "1c1a4a", "655757": "2a1440", "574749": "160f30", "6d574f": "3a1a4f", "8a6f5b": "5a2d82", "a78767": "b14dff", "2e2328": "050512", "793c44": "7a0f6b", "5a1f22": "3d0a2e", "e16257": "a3125e", "e6b67d": "2a1f5e", "d8d74b": "2d2a6e", "9eccb3": "0e4a5c", "cbac93": "2b2560", "adca96": "1d4a3a", "9cbf80": "0b6e4a", "ab966f": "5a2d82", "749c5c": "0b6e6e", "ebceb0": "2a1a50"},
		"text": {"49343d": "7df9ff", "533c44": "7df9ff", "744145": "7df9ff", "96514b": "7df9ff", "b76051": "7df9ff", "c2855f": "7df9ff", "cba77a": "7df9ff", "99966d": "7df9ff", "7b7e63": "7df9ff", "5d6558": "7df9ff", "534650": "7df9ff", "625467": "7df9ff", "7a6d79": "7df9ff", "92868b": "7df9ff", "b3a999": "7df9ff", "ddcf99": "7df9ff", "c0b18f": "7df9ff", "9a8c7a": "7df9ff", "807269": "7df9ff", "655757": "7df9ff", "574749": "7df9ff", "6d574f": "7df9ff", "8a6f5b": "7df9ff", "a78767": "7df9ff", "2e2328": "7df9ff", "793c44": "7df9ff", "5a1f22": "7df9ff", "e16257": "7df9ff", "e6b67d": "7df9ff", "d8d74b": "7df9ff", "9eccb3": "7df9ff", "cbac93": "7df9ff", "adca96": "7df9ff", "9cbf80": "7df9ff", "ab966f": "7df9ff", "749c5c": "7df9ff", "ebceb0": "7df9ff"},
		"ink": "7df9ff",
		"all_text": "7df9ff",   # every bit of writing glows like the app icons
	},
}

const TINT_SHADER_CODE := """
shader_type canvas_item;
uniform vec3 multiply = vec3(1.0);
uniform vec4 replace_color = vec4(0.0);   // a > 0: draw every pixel in this colour
void fragment() {
	if (replace_color.a > 0.0) {
		COLOR.rgb = replace_color.rgb;
	} else {
		COLOR.rgb = clamp(COLOR.rgb * multiply, 0.0, 1.0);
	}
}
"""
const MONO_SHARE := 0.8   # a texture counts as one-colour art when this much of it is one colour

var current := "default"
var _ever_themed := false       # nothing to undo until a theme other than Default was used
var _pending: Array = []
var _flush_queued := false
var _mono_cache: Dictionary = {}   # texture -> dominant colour hex, or "" when not one-colour
var _tint_shader: Shader
var _default_clear := Color.BLACK
var _themes_seen: Array = []       # Theme resources already recoloured for `current`


func _ready() -> void:
	_tint_shader = Shader.new()
	_tint_shader.code = TINT_SHADER_CODE
	_default_clear = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color.BLACK)
	get_tree().node_added.connect(_on_node_added)
	var saved: String = Network.load_setting(SETTINGS_SECTION, "theme", "default")
	if saved in ORDER and saved != "default":
		set_theme(saved, false)

func theme_name(key: String = current) -> String:
	return NAMES.get(key, key)

# Settings button: the next theme in ORDER.
func next_theme() -> String:
	return ORDER[(ORDER.find(current) + 1) % ORDER.size()]

func set_theme(key: String, save: bool = true) -> void:
	if not key in ORDER:
		return
	current = key
	if key != "default":
		_ever_themed = true
	if save:
		Network.save_setting(SETTINGS_SECTION, "theme", key)
	_themes_seen.clear()
	RenderingServer.set_default_clear_color(map_color(_default_clear, "fill"))
	var theme := ThemeDB.get_project_theme()
	if theme:
		_recolor_theme(theme)
	for node in get_tree().root.find_children("*", "", true, false):
		_recolor_node(node)
	theme_changed.emit(key)


## ---- COLOUR LOOKUP ----
# The themed version of a default-palette colour (alpha kept). Anything else is unchanged.
func map_color(color: Color, role: String = "fill") -> Color:
	if current == "default":
		return color
	var theme: Dictionary = THEMES[current]
	if role == "text" and theme.has("all_text"):
		return Color(Color(theme["all_text"]), color.a)
	if role != "fill" and theme["ink"] != "" and _is_ink(color):
		return Color(Color(theme["ink"]), color.a)
	var hex := color.to_html(false)
	var table: Dictionary = theme["text"] if role == "text" else theme["fill"]
	if table.has(hex):
		return Color(Color(table[hex]), color.a)
	return color

# Black / near-black writing.
func _is_ink(color: Color) -> bool:
	return color.r < 0.25 and color.g < 0.25 and color.b < 0.25 and absf(color.r - color.b) < 0.08

# Recolours one colour slot, always starting from its ORIGINAL colour (kept in metadata),
# so switching theme again works. If a script changed the colour since we last set it,
# the new value becomes the original.
func _remap(holder: Object, slot: String, value: Color, role: String) -> Color:
	var key := "ct_" + slot.replace("/", "__").replace(" ", "_")
	var original := value
	if holder.has_meta(key) and holder.get_meta(key + "_set") == value:
		original = holder.get_meta(key)
	var result := map_color(original, role)
	if result == original and not holder.has_meta(key):
		return value   # not a palette colour: nothing to remember
	holder.set_meta(key, original)
	holder.set_meta(key + "_set", result)
	return result


## ---- APPLYING ----
func _on_node_added(node: Node) -> void:
	if current == "default" and not _ever_themed:
		return
	_pending.append(node)
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()   # after the new screen's _ready() has set up its styles

func _flush() -> void:
	_flush_queued = false
	var nodes := _pending
	_pending = []
	for node in nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			_recolor_node(node)

# Keeps a node exactly as designed in every theme (e.g. writing on an illustration).
func keep(node: Node) -> void:
	node.set_meta("ct_skip", true)

func _recolor_node(node: Node) -> void:
	if node.has_meta("ct_skip"):
		return
	if node is Control:
		var control := node as Control
		for prop_name in _override_props(control):
			var value = control.get(prop_name)
			if value is Color:
				control.set(prop_name, _remap(control, prop_name, value, "text"))
			elif value is StyleBoxFlat:
				_recolor_style(value)
		if control.theme and not control.theme in _themes_seen:
			_recolor_theme(control.theme)
		if control is ColorRect:
			control.color = _remap(control, "color", control.color, "fill")
		elif control is Label and control.label_settings:
			var settings: LabelSettings = control.label_settings
			settings.font_color = _remap(settings, "font_color", settings.font_color, "text")
			settings.outline_color = _remap(settings, "outline_color", settings.outline_color, "text")
	if node is CanvasItem:
		var item := node as CanvasItem
		item.modulate = _remap(item, "modulate", item.modulate, "fill")
		item.self_modulate = _remap(item, "self_modulate", item.self_modulate, "fill")
		_tint_texture(item)

# The theme_override_colors/... and theme_override_styles/... property names of a kind of
# control. Asking every node for its whole property list was the slowest part of
# theming a screen, and the list is the same for every Label (Button, ...), so it's
# worked out once per class.
var _props_by_class: Dictionary = {}

func _override_props(control: Control) -> Array:
	var key := control.get_class()
	var script: Script = control.get_script()
	if script:
		key += ":" + script.resource_path   # a script can add its own theme items
	if not _props_by_class.has(key):
		var names := []
		for prop in control.get_property_list():
			var prop_name: String = prop["name"]
			if prop_name.begins_with("theme_override_colors/") or prop_name.begins_with("theme_override_styles/"):
				names.append(prop_name)
		_props_by_class[key] = names
	return _props_by_class[key]

func _recolor_style(style: StyleBoxFlat) -> void:
	style.bg_color = _remap(style, "bg_color", style.bg_color, "fill")
	style.border_color = _remap(style, "border_color", style.border_color, "border")
	style.shadow_color = _remap(style, "shadow_color", style.shadow_color, "fill")

func _recolor_theme(theme: Theme) -> void:
	_themes_seen.append(theme)
	for type in theme.get_type_list():
		for color_name in theme.get_color_list(type):
			var value: Color = theme.get_color(color_name, type)
			theme.set_color(color_name, type, _remap(theme, type + "__" + color_name, value, "text"))
		for style_name in theme.get_stylebox_list(type):
			var style := theme.get_stylebox(style_name, type)
			if style is StyleBoxFlat:
				_recolor_style(style)


## ---- ONE-COLOUR ARTWORK ----
# Flat artwork in a palette colour is tinted to the theme's colour (keeping its shading);
# black line icons are redrawn in the theme's ink colour on dark themes.
func _tint_texture(item: CanvasItem) -> void:
	var texture: Texture2D = null
	if item is TextureRect:
		texture = item.texture
	elif item is TextureButton:
		texture = item.texture_normal
	elif item is Sprite2D:
		texture = item.texture
	elif item is NinePatchRect:
		texture = item.texture
	if texture == null:
		return
	if item.material and not item.has_meta("ct_tint"):
		return   # it has its own material: leave it alone
	if item.has_meta("ct_as_ink"):   # see ink_icon()
		var ink: String = "" if current == "default" else str(THEMES[current]["ink"])
		var ink_material := ShaderMaterial.new()
		ink_material.shader = _tint_shader
		ink_material.set_shader_parameter("replace_color", Color(Color(ink) if ink != "" else Color.BLACK, 1.0))
		item.material = ink_material
		item.set_meta("ct_tint", true)
		return
	var base := _mono_color(texture)
	var material: ShaderMaterial = null
	if base != "" and current != "default":
		var from := Color(base)
		var role := "ink" if _is_ink(from) else "fill"
		var to := map_color(from, role)
		if to != from:
			material = ShaderMaterial.new()
			material.shader = _tint_shader
			if role == "ink":
				material.set_shader_parameter("replace_color", Color(to, 1.0))
			else:
				material.set_shader_parameter("multiply", Vector3(to.r / maxf(from.r, 0.01), to.g / maxf(from.g, 0.01), to.b / maxf(from.b, 0.01)))
	if material:
		item.material = material
		item.set_meta("ct_tint", true)
	elif item.has_meta("ct_tint"):
		item.material = null
		item.remove_meta("ct_tint")

# One-colour icon art drawn like the black line icons beside it (black, or the theme's
# ink colour on dark themes), whatever colour the picture itself is in. Used where card
# art in a beige palette colour sits in a list of black icons (My Actions).
func ink_icon(item: CanvasItem) -> void:
	var texture: Texture2D = item.get("texture")
	if texture == null or _mono_color(texture) == "":
		return   # a photo or illustration: leave it
	item.set_meta("ct_as_ink", true)
	_tint_texture(item)

# The colour (hex) covering most of a texture, if it's one-colour art; "" otherwise.
func _mono_color(texture: Texture2D) -> String:
	if _mono_cache.has(texture):
		return _mono_cache[texture]
	var result := ""
	if not texture is AtlasTexture:   # sprite-sheet frames: animations, leave them
		var image := texture.get_image()
		if image:
			if image.is_compressed():
				image = image.duplicate()
				image.decompress()
			var counts := {}
			var total := 0
			var inky := 0   # near-black pixels (a scanned line icon is many shades of black)
			var step := maxi(1, maxi(image.get_width(), image.get_height()) / 48)
			for y in range(0, image.get_height(), step):
				for x in range(0, image.get_width(), step):
					var pixel := image.get_pixel(x, y)
					if pixel.a < 0.8:
						continue
					total += 1
					if _is_ink(pixel):
						inky += 1
					var hex := pixel.to_html(false)
					counts[hex] = counts.get(hex, 0) + 1
			var best := ""
			for hex in counts:
				if best == "" or counts[hex] > counts[best]:
					best = hex
			if total > 0 and float(inky) / total >= MONO_SHARE:
				result = "000000"
			elif total > 0 and float(counts.get(best, 0)) / total >= MONO_SHARE:
				var color := Color(best)
				if _is_ink(color) or THEMES["dark"]["fill"].has(best):
					result = best
	_mono_cache[texture] = result
	return result
