extends CanvasLayer
## Full-screen app transition. run_animation(color, anim, destination) plays the animation
## and then changes to `destination`. "sold" / "failed" play the "question" lead-in first;
## `on_reveal` runs the moment the result shows (right after the lead-in).

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
	if anim in ["sold", "failed"]:
		animation.play("question")
		await animation.animation_finished
	animation.play(anim)
	if on_reveal.is_valid():
		on_reveal.call()
	await animation.animation_finished
	get_tree().change_scene_to_file(destination)
