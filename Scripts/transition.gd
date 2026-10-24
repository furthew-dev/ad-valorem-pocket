extends CanvasLayer
## Full-screen app transition. run_animation(color, anim, destination) plays the animation
## and then changes to `destination`. "sold" / "failed" play the "question" lead-in first;
## `on_reveal` runs the moment the result shows (right after the lead-in).
##
## Each animation's frames live in their own file (Assets/SpriteSheets/frames/<name>.tres)
## and only the ones being played are loaded. (They used to all sit in this scene, so
## every screen that could show a transition loaded ~290 MB of sprite sheets.)

const FRAMES_DIR := "res://Assets/SpriteSheets/frames/"

@onready var app_color: ColorRect = $app_color
@onready var animation: AnimatedSprite2D = $app_color/Panel/animation


func _ready() -> void:
	layer = 50   # above every screen (several screens are CanvasLayers on layer 1)

func run_animation(color: String, anim: String, destination: String, on_reveal := Callable()) -> void:
	if anim == "":
		push_error("transition.run_animation: empty animation name")
		return
	app_color.color = Color(color)
	if anim == "purchasing":
		animation.scale = Vector2.ONE
	var frames := _frames(anim)   # load before anything plays, so there's no hitch later
	if frames == null:
		get_tree().change_scene_to_file(destination)
		return
	if anim in ["sold", "failed"]:
		var lead_in := _frames("question")
		if lead_in:
			animation.sprite_frames = lead_in
			animation.play("question")
			await animation.animation_finished
	animation.sprite_frames = frames
	animation.play(anim)
	if on_reveal.is_valid():
		on_reveal.call()
	await animation.animation_finished
	get_tree().change_scene_to_file(destination)

func _frames(anim: String) -> SpriteFrames:
	var path := FRAMES_DIR + anim + ".tres"
	if not ResourceLoader.exists(path):
		push_error("transition: no frames for '%s'" % anim)
		return null
	return load(path)
