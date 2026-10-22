extends Node
## Phone browsers: typing into Godot text boxes doesn't open the on-screen keyboard.
## On a touch device running the web build, tapping any LineEdit (name fields, room key,
## SpinBox numbers) opens the browser's own text prompt instead, which brings up the
## phone keyboard, then copies the answer into the box. Autoloaded as "WebTextInput".
## Does nothing on desktop or in the editor.

var _busy := false


func _ready() -> void:
	if _is_touch_web():
		get_viewport().gui_focus_changed.connect(_on_focus_changed)

func _is_touch_web() -> bool:
	return OS.has_feature("web") and (OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or DisplayServer.is_touchscreen_available())

func _on_focus_changed(control: Control) -> void:
	if _busy or not control is LineEdit or not control.editable:
		return
	_busy = true
	await get_tree().process_frame   # let the tap finish first
	var field := control as LineEdit
	var title := field.placeholder_text if field.placeholder_text != "" else "Enter text"
	var spin := field.get_parent() as SpinBox
	if spin:
		title = "Enter a number (%d to %d)" % [spin.min_value, spin.max_value]
	var answer = JavaScriptBridge.eval("prompt(%s, %s)" % [JSON.stringify(title), JSON.stringify(field.text)], true)
	if answer is String:
		if field.max_length > 0:
			answer = answer.left(field.max_length)
		field.text = answer
		field.caret_column = answer.length()
		field.text_changed.emit(answer)   # e.g. the room key box upper-cases itself
	field.release_focus()   # a SpinBox applies the typed number when its box loses focus
	_busy = false
