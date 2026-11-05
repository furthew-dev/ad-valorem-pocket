extends CanvasLayer
## Selling a property: the player rolls a black die with white writing, in 3D with real
## physics. Whatever face lands on top decides the sale: with a Listing Agent 5 of the 6
## faces say SOLD, on your own only 2 do (the other faces say FAIL).
##     DiceRoll.open(get_tree(), using_agent, settle)
## `settle` is called with true/false once the die stops. It applies the sale and returns
## {"message": String, "cash": int}. Then this goes to My Properties and the result shows
## in the banner (with the cash notice when it sold).
## In the guided tour a FAIL just lets the player roll again (nothing happens).

const AGENT_SOLD_FACES := 5
const PRIVATE_SOLD_FACES := 2
const BG := Color("534650")
const TRAY := Color("3f3540")
const CREAM := Color("f6f2e1")
const TERRACOTTA := Color("b76051")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const DESTINATION := "res://Scenes/my_properties.tscn"
const TRAY_SIZE := 640.0
const WALL := 1.9            # the die stays inside -WALL..WALL (x and z)
const SETTLE_TIME := 0.35    # still for this long = stopped
const GIVE_UP_AFTER := 8.0   # still tumbling (or balanced on an edge): nudge it
const CAMERA_HEIGHT := 8.0     # sees the whole tray from straight above
# A throw: from a random point around the tray's edge, toward (roughly) the middle.
const THROW_SPEED := Vector2(3.0, 6.5)    # how hard, sideways (m/s, randomly in this range)
const THROW_LIFT := Vector2(0.5, 2.5)     # and upward
const THROW_AIM := 0.45                   # up to ~25 degrees off the middle
const THROW_SPIN := Vector2(8.0, 24.0)    # spin (rad/s), around a random axis
# The sound: a click each time the die hits something, as loud as the hit.
const HIT_MIN := 0.7          # a change of speed (m/s) smaller than this is silent
const HIT_LOUD := 7.0         # ...this or more is full volume
const HIT_GAP := 0.045        # at most one click per this many seconds
const SHADOW_MAP := 1024      # px; 16-bit, about 2 MB
const BOX_HEIGHT := 1.0        # the tray's walls: as high as the die
const BOX_THICK := 0.32        # how thick they are
const BOX_ROUND := 0.38        # their rounded inside corners
const BOX_BEVEL := 0.07        # the bevel along their top edges
const BOX_WOOD := Color("6d574f")
const HITS := [preload("res://Assets/sounds/dice_hit1.mp3"), preload("res://Assets/sounds/dice_hit2.mp3"), preload("res://Assets/sounds/dice_hit3.mp3")]
const SETTLING = preload("res://Assets/sounds/dice_settling.mp3")
const CORNER_RADIUS := 0.16   # rounded edges (the die is 1 x 1 x 1)
const FACES := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]

signal finished

var _agent := false
var _settle: Callable
var _labels: Array = []         # face index -> "SOLD" / "FAIL"
var _die: RigidBody3D
var _viewport: SubViewport
var _roll_button: Button
var _title: Label
var _hint: Label
var _rolling := false
var _still := 0.0
var _clock := 0.0
var _done := false


static func open(tree: SceneTree, agent: bool, settle: Callable) -> Node:
	var roll = load("res://Scripts/dice_roll.gd").new()
	roll.name = "DiceRoll"
	roll._agent = agent
	roll._settle = settle
	tree.root.add_child(roll)
	return roll

func _ready() -> void:
	layer = 50   # over the screen and its menu bar; under the guided tour (110)
	# The die's soft shadow only needs a small shadow map (the default is 2048 x 2048,
	# about 16 MB of video memory, for one little shadow). Nothing else in the game is 3D.
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_MAP, true)
	_pick_faces()
	_build_ui()
	_build_world()
	Sound.play("open")


## ---- THE FACES ----
func _pick_faces() -> void:
	var sold := AGENT_SOLD_FACES if _agent else PRIVATE_SOLD_FACES
	var order := range(6)
	order.shuffle()
	_labels.resize(6)
	for i in 6:
		_labels[order[i]] = "SOLD" if i < sold else "FAIL"


## ---- SCREEN ----
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 110
	column.offset_bottom = -80
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	bg.add_child(column)

	_title = _label("Roll to sell", 66, FONT)
	column.add_child(_title)
	var odds := "Listing Agent: SOLD on 5 of the 6 sides" if _agent else "Selling on your own: SOLD on 2 of the 6 sides"
	_hint = _label(odds, 26, BODY_FONT)
	_hint.modulate.a = 0.85
	column.add_child(_hint)

	# The tray: a rounded felt box with the 3D die in it. Tap it to roll, too.
	var tray := Panel.new()
	tray.custom_minimum_size = Vector2(TRAY_SIZE, TRAY_SIZE)
	tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tray.add_theme_stylebox_override("panel", StyleBoxEmpty.new())   # the 3D box is the tray
	tray.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_roll())
	column.add_child(tray)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	# No anti-aliasing: the Compatibility renderer has no FXAA (Godot 4.5 reports it as an
	# error), and MSAA costs ~6 MB here. The matte die on felt looks clean without it.
	view.add_child(_viewport)


	_roll_button = Button.new()
	_roll_button.text = "Roll"
	_roll_button.custom_minimum_size = Vector2(320, 110)
	_roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll_button.focus_mode = Control.FOCUS_NONE
	_roll_button.add_theme_font_override("font", FONT)
	_roll_button.add_theme_font_size_override("font_size", 64)
	var normal := StyleBoxFlat.new()
	normal.bg_color = TERRACOTTA
	normal.border_color = CREAM
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(55)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 5)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = TERRACOTTA.darkened(0.15)
	for state in ["normal", "hover", "focus", "disabled"]:
		_roll_button.add_theme_stylebox_override(state, normal)
	_roll_button.add_theme_stylebox_override("pressed", pressed)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		_roll_button.add_theme_color_override(state, CREAM)
	_roll_button.pressed.connect(_roll)
	column.add_child(_roll_button)
	for node in find_children("*", "", true, false):
		ColorTheme.keep(node)   # the same look in every theme, like the old sale animation

func _label(text: String, size: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", CREAM)
	return label


## ---- THE 3D TRAY AND DIE ----
func _build_world() -> void:
	var world := Node3D.new()
	_viewport.add_child(world)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BG   # around the box: the same as the screen
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)

	var camera := Camera3D.new()
	camera.fov = 40
	world.add_child(camera)
	# Straight down from above (a bird's-eye view of the tray).
	camera.look_at_from_position(Vector3(0, CAMERA_HEIGHT, 0), Vector3.ZERO, Vector3.FORWARD)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	world.add_child(sun)
	sun.look_at_from_position(Vector3(1.5, 6, 2.5), Vector3.ZERO)   # a little off to the side: a soft shadow

	# The felt floor inside the box (it catches the shadow), the box itself, and tall
	# invisible walls along its inside faces so nothing can jump out.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WALL * 2 + 0.2, WALL * 2 + 0.2)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = TRAY
	felt.roughness = 1.0
	plane.material = felt
	floor_mesh.mesh = plane
	world.add_child(floor_mesh)
	_build_box(world)
	_add_box_body(world, Vector3(0, -0.5, 0), Vector3(14, 1, 14))
	for side in [Vector3(WALL + 0.5, 0, 0), Vector3(-WALL - 0.5, 0, 0)]:
		_add_box_body(world, side + Vector3(0, 3, 0), Vector3(1, 6, 14))
	for side in [Vector3(0, 0, WALL + 0.5), Vector3(0, 0, -WALL - 0.5)]:
		_add_box_body(world, side + Vector3(0, 3, 0), Vector3(14, 6, 1))
	_add_box_body(world, Vector3(0, 6.5, 0), Vector3(14, 1, 14))   # a lid: nothing flies out

	_die = RigidBody3D.new()
	_die.mass = 1.0
	_die.gravity_scale = 2.2   # snappier than real life, so a roll takes a couple of seconds
	_die.continuous_cd = true
	var bounce := PhysicsMaterial.new()
	bounce.bounce = 0.35
	bounce.friction = 0.7
	_die.physics_material_override = bounce
	_die.angular_damp = 0.6
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.06, 0.06, 0.07)
	black.roughness = 0.55
	black.metallic_specular = 0.3
	var body := MeshInstance3D.new()
	body.mesh = _rounded_cube(CORNER_RADIUS, 8)
	body.material_override = black
	_die.add_child(body)
	var shape := CollisionShape3D.new()   # rounded too, so it tumbles off its edges like a real die
	shape.shape = _rounded_cube(CORNER_RADIUS, 3).create_convex_shape(true, true)
	_die.add_child(shape)
	for i in 6:
		_die.add_child(_face_label(FACES[i], _labels[i]))
	world.add_child(_die)
	_die.freeze = true   # resting in the middle until the player rolls
	_die.position = Vector3(0, 0.5, 0.2)
	_die.rotation = Vector3(0, deg_to_rad(randf_range(-25, 25)), 0)

# A 1 x 1 x 1 cube with rounded edges and corners: each face is a grid of points pushed
# out onto a rounded box (the inner box, plus `radius` along the way out).
func _rounded_cube(radius: float, steps: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := Vector3.ONE * (0.5 - radius)
	for normal in FACES:
		var n: Vector3 = normal
		var u := Vector3(n.y, n.z, n.x) if absf(n.x) < 0.5 else Vector3(0, 1, 0)
		var v := n.cross(u)
		var grid: Array = []
		for row in steps + 1:
			var line: Array = []
			for col in steps + 1:
				var a := (float(col) / steps - 0.5)
				var b := (float(row) / steps - 0.5)
				var on_cube: Vector3 = n * 0.5 + u * a + v * b
				var core := on_cube.clamp(-inner, inner)
				var out := (on_cube - core).normalized()
				line.append([core + out * radius, out])
			grid.append(line)
		for row in steps:
			for col in steps:
				var quad := [grid[row][col], grid[row][col + 1], grid[row + 1][col + 1], grid[row + 1][col]]
				for index in [0, 2, 1, 0, 3, 2]:
					tool.set_normal(quad[index][1])
					tool.add_vertex(quad[index][0])
	tool.index()
	return tool.commit()

# The tray's four walls as one piece: a ring around the felt with rounded inside corners
# and a bevel along the top edges, BOX_HEIGHT tall. Its shape also blocks the die (so the
# rounded corners are solid too).
func _build_box(world: Node3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The wall's cross-section, from the inside bottom, over the top, to the outside bottom:
	# [distance out from the inside face, height].
	var h := BOX_HEIGHT
	var b := BOX_BEVEL
	var t := BOX_THICK
	var profile := [Vector2(0, 0), Vector2(0, h - b), Vector2(b, h), Vector2(t - b, h), Vector2(t, h - b), Vector2(t, 0)]
	# The path around the box: each rounded corner as a quarter circle (straight walls join them).
	var path: Array = []   # [corner centre, outward direction]
	var inner := WALL - BOX_ROUND
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for c in 4:
		var start_angle := c * PI / 2.0
		for step in 9:
			var angle := start_angle + step * (PI / 2.0) / 8.0
			path.append([Vector3(corners[c].x * inner, 0, corners[c].y * inner), Vector3(cos(angle), 0, sin(angle))])
	path.append(path[0])
	for i in path.size() - 1:
		for k in profile.size() - 1:
			var p0: Vector2 = profile[k]
			var p1: Vector2 = profile[k + 1]
			var flat := Vector2(-(p1.y - p0.y), p1.x - p0.x).normalized()   # this strip's facing
			var quad := []
			for j in [i, i + 1]:
				var centre: Vector3 = path[j][0]
				var out: Vector3 = path[j][1]
				var normal := (out * flat.x + Vector3.UP * flat.y).normalized()
				quad.append([centre + out * (BOX_ROUND + p0.x) + Vector3.UP * p0.y, normal])
				quad.append([centre + out * (BOX_ROUND + p1.x) + Vector3.UP * p1.y, normal])
			for index in [0, 1, 3, 0, 3, 2]:
				tool.set_normal(quad[index][1])
				tool.add_vertex(quad[index][0])
	var mesh := tool.commit()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = BOX_WOOD
	wood.roughness = 0.75
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	var walls := MeshInstance3D.new()
	walls.mesh = mesh
	walls.material_override = wood
	world.add_child(walls)
	var solid := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	solid.add_child(shape)
	world.add_child(solid)

func _add_box_body(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = at
	parent.add_child(wall)

# White writing on one face, facing out.
func _face_label(normal: Vector3, text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT   # the game's handwriting, like the titles
	label.font_size = 48        # (a bigger size only fills a bigger font texture: the faces are small)
	label.pixel_size = 0.0064   # small and centred, clear of the rounded edges
	label.outline_size = 3      # a white outline thickens the thin pen strokes a little
	label.outline_modulate = Color.WHITE
	label.modulate = Color.WHITE
	label.shaded = false
	label.double_sided = false
	var up := Vector3.FORWARD if absf(normal.y) > 0.5 else Vector3.UP
	label.transform = Transform3D(Basis.looking_at(-normal, up), normal * 0.502)
	return label


## ---- ROLLING ----
func _roll() -> void:
	if _rolling or _done:
		return
	_rolling = true
	_still = 0.0
	_clock = 0.0
	_title.remove_theme_color_override("font_color")
	_title.add_theme_color_override("font_color", CREAM)
	_roll_button.disabled = true
	_roll_button.modulate.a = 0.4
	_title.text = "Rolling..."
	_title.scale = Vector2.ONE
	await _shake_in_hand()
	# Thrown in from a random side of the tray, toward (roughly) the middle, spinning.
	var from := randf() * TAU
	var start := Vector3(cos(from), 0, sin(from)) * randf_range(1.1, 1.6)
	var aim := (-start).normalized().rotated(Vector3.UP, randf_range(-THROW_AIM, THROW_AIM))
	_die.freeze = false
	_die.position = start + Vector3(0, randf_range(1.6, 2.4), 0)
	_die.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_die.linear_velocity = aim * randf_range(THROW_SPEED.x, THROW_SPEED.y) + Vector3.UP * randf_range(THROW_LIFT.x, THROW_LIFT.y)
	var axis := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	_die.angular_velocity = axis * randf_range(THROW_SPIN.x, THROW_SPIN.y)
	_last_velocity = _die.linear_velocity
	_settled_sound = false

func _physics_process(delta: float) -> void:
	if not _rolling or _die.freeze:
		return
	_listen_for_hits(delta)
	_clock += delta
	if _die.linear_velocity.length() < 0.05 and _die.angular_velocity.length() < 0.08:
		if _still == 0.0 and _top_face() >= 0:
			_settle_sound()   # it has come to rest on a face: the last little sound
		_still += delta
	else:
		_still = 0.0
	if _still >= SETTLE_TIME or _clock >= GIVE_UP_AFTER:
		var face := _top_face()
		if face < 0 or _clock >= GIVE_UP_AFTER:   # leaning on a wall or an edge: nudge it over
			_clock = 0.0
			_still = 0.0
			_die.apply_central_impulse(Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1)))
			_die.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)))
			return
		_rolling = false
		_landed(_labels[face] == "SOLD")

## ---- SOUND ----
# One hit sound each time the die hits the felt or a wall, as loud as the hit was hard
# (judged by how suddenly its speed changed, beyond what gravity does), picked at random
# from three recordings. The settling sound plays once, when it comes to rest for good.
var _last_velocity := Vector3.ZERO
var _since_hit := 1.0
var _hit_players: Array = []
var _settled_sound := false

func _listen_for_hits(delta: float) -> void:
	var velocity := _die.linear_velocity
	var gravity := Vector3.DOWN * 9.8 * _die.gravity_scale * delta
	var jolt := (velocity - _last_velocity - gravity).length()
	_last_velocity = velocity
	_since_hit += delta
	if jolt >= HIT_MIN and _since_hit >= HIT_GAP:
		_since_hit = 0.0
		_click(clampf(inverse_lerp(HIT_MIN, HIT_LOUD, jolt), 0.0, 1.0))

func _player() -> AudioStreamPlayer:
	if _hit_players.is_empty():
		for i in 5:
			var player := AudioStreamPlayer.new()
			add_child(player)
			_hit_players.append(player)
	var player: AudioStreamPlayer = _hit_players.pop_front()
	_hit_players.append(player)
	return player

func _click(strength: float, pitch: float = 1.0) -> void:
	if not Sound.enabled:
		return
	var player := _player()
	player.stream = HITS.pick_random()
	player.volume_db = lerpf(-24.0, 0.0, sqrt(strength))
	player.pitch_scale = pitch * randf_range(0.93, 1.07)
	player.play()

func _settle_sound() -> void:
	if _settled_sound or not Sound.enabled:
		return
	_settled_sound = true
	var player := _player()
	player.stream = SETTLING
	player.volume_db = 0.0
	player.pitch_scale = 1.0
	player.play()

# The die rattling in your hand for a moment before it's thrown: a few quick, soft,
# slightly higher hits.
func _shake_in_hand() -> void:
	for i in 4:
		_click(randf_range(0.03, 0.1), 1.25)
		await get_tree().create_timer(randf_range(0.05, 0.09)).timeout

# The face pointing up, or -1 if none is flat enough to read.
func _top_face() -> int:
	var best := -1
	var best_dot := 0.0
	for i in 6:
		var dot: float = (_die.global_transform.basis * FACES[i]).normalized().dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best = i
	return best if best_dot > 0.97 else -1


## ---- THE RESULT ----
func _landed(sold: bool) -> void:
	_die.freeze = true
	# The result in big letters above the tray (never over the die).
	_title.text = "SOLD!" if sold else "FAIL"
	_title.add_theme_color_override("font_color", CREAM if sold else Color("f2b0a4"))
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2(0.3, 0.3)
	_title.create_tween().tween_property(_title, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not sold and get_tree().root.has_node("Tutorial"):   # practice: a FAIL costs nothing
		Sound.play("aww")
		_hint.text = "Practice roll: a FAIL costs nothing here. Roll again!"
		_roll_button.disabled = false
		_roll_button.modulate.a = 1.0
		return
	_done = true
	Sound.play("continue" if sold else "aww")
	await get_tree().create_timer(1.4).timeout
	var outcome: Dictionary = _settle.call(sold)
	get_tree().change_scene_to_file(DESTINATION)
	await get_tree().process_frame
	await get_tree().process_frame
	if outcome.get("cash", 0) > 0:
		Global.add_cash(outcome["cash"], "Property Sale")
	var message: String = outcome.get("message", "")
	if sold:
		Global.banner(message)
	else:   # logged as a setback, no second sound (the "aww" already played)
		Activity.add(message, "error")
		Global.banner_requested.emit(message, "")
	finished.emit()
	queue_free()
