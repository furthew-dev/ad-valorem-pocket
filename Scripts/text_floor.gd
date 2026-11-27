extends Node
## Smallest text size anywhere in the game (autoloaded as "TextFloor").
## After play-tests on small iPhones, Matt set a floor: no writing smaller than the
## Environment app's "Worth $X at the end ($5 each)" line (24 px at the 720-wide design
## size). Every Label, Button, text box and rich text that appears is checked when it
## enters the tree, and again whenever its theme or overrides change (a screen that shrinks
## a title to fit can't take it below the floor either). Anything smaller is raised to 24
## (28 for the handwriting font, which draws smaller letters).
##
## Screens are still designed with their own sizes; this only lifts the small ones.
## A node can opt out with set_meta("small_text_ok", true) (none do today).

const MIN_SIZE := 24
# The handwriting font draws smaller letters at the same size (x-height 0.48 of the size vs
# Comfortaa's 0.55), so it needs 28 to look as big as Comfortaa at 24.
const MIN_HANDWRITING := 28

# Rich text has a size per style.
const RICH_SIZES := ["normal_font_size", "bold_font_size", "italics_font_size",
		"bold_italics_font_size", "mono_font_size"]

var lifted := 0   # how many nodes were raised (for tests)


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if not node is Control:
		return
	if not (node is Label or node is BaseButton or node is LineEdit or node is TextEdit or node is RichTextLabel):
		return
	# Scripts often set the size right after adding the node: check once that's done,
	# and again whenever the overrides or the theme change.
	_lift.call_deferred(node)
	var control := node as Control
	if not control.theme_changed.is_connected(_lift.bind(control)):
		control.theme_changed.connect(_lift.bind(control))

func _lift(node) -> void:   # (untyped: the node may be gone by the time this runs)
	if not is_instance_valid(node) or node.has_meta("small_text_ok"):
		return
	var control := node as Control
	if control is RichTextLabel:
		for item in RICH_SIZES:
			if control.get_theme_font_size(item) < MIN_SIZE:
				control.add_theme_font_size_override(item, MIN_SIZE)
				lifted += 1
		return
	if control is Label and control.label_settings:
		if control.label_settings.font_size < MIN_SIZE:
			control.label_settings = control.label_settings.duplicate()
			control.label_settings.font_size = MIN_SIZE
			lifted += 1
		return
	var font := control.get_theme_font("font")
	var floor_size := MIN_HANDWRITING if font and font.resource_path.contains("Handwriting") else MIN_SIZE
	if control.get_theme_font_size("font_size") < floor_size:
		control.add_theme_font_size_override("font_size", floor_size)
		lifted += 1
