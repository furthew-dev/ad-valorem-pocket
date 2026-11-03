extends Node
## Debug readout for testing on phones. Autoloaded as "DebugMonitor".
## Does nothing unless the page address ends in ?debug
##     furthew-dev.github.io/ad-valorem-pocket/?debug
## Every few seconds (and on every screen change) it prints one line to the browser console:
## screen, fps, texture memory, video memory, game memory, node and resource counts.
## The last line is also kept in the tab's sessionStorage, so after iOS kills and reloads the
## page, the first line printed is the reading taken just before it went down.

const EVERY := 3.0
const STORE_KEY := "ad_valorem_debug_last"

var _on := false
var _clock := 0.0
var _scene := ""
var _peak_tex := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		set_process(false)
		return
	_on = bool(JavaScriptBridge.eval("location.search.indexOf('debug') >= 0", true))
	set_process(_on)
	if not _on:
		return
	var last = JavaScriptBridge.eval("(function(){try{return sessionStorage.getItem('%s')||''}catch(e){return ''}})()" % STORE_KEY, true)
	if str(last) != "":
		print("[AV-DEBUG] LAST READING BEFORE THE PAGE RELOADED -> ", last)
	print("[AV-DEBUG] monitor on, logging every %.0fs" % EVERY)

func _process(delta: float) -> void:
	_clock += delta
	var scene := _current_scene()
	if scene != _scene:
		_scene = scene
		_log("screen changed")
		_clock = 0.0
	elif _clock >= EVERY:
		_clock = 0.0
		_log("")

func _current_scene() -> String:
	var s := get_tree().current_scene
	if s and s.scene_file_path != "":
		return s.scene_file_path.get_file().get_basename()
	return str(s.name) if s else "?"

func _mb(bytes: float) -> String:
	return "%.0fMB" % (bytes / 1048576.0)

func _log(note: String) -> void:
	var tex := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	_peak_tex = maxf(_peak_tex, tex)
	var heap = JavaScriptBridge.eval("(function(){try{return engine.rtenv.HEAP8.buffer.byteLength}catch(e){return -1}})()", true)
	var line := "screen=%s fps=%d tex=%s (peak %s) video=%s wasm_heap=%s nodes=%d resources=%d orphans=%d draws=%d %s" % [
		_scene,
		Performance.get_monitor(Performance.TIME_FPS),
		_mb(tex), _mb(_peak_tex),
		_mb(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		_mb(float(heap)) if float(heap) > 0 else "?",
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		note,
	]
	print("[AV-DEBUG] ", line)
	JavaScriptBridge.eval("try{sessionStorage.setItem('%s', %s)}catch(e){}" % [STORE_KEY, JSON.stringify(Time.get_time_string_from_system() + " " + line)])
