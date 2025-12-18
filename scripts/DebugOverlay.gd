# scripts/DebugOverlay.gd
extends CanvasLayer

const TOGGLE_ACTION: String = "debug_toggle" 
const REFRESH_RATE: float = 0.1 

var _visible: bool = false
var _stats: Dictionary = {} 
var _time_since_last_update: float = 0.0
var _label: Label
var _bg: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	visible = false
	_setup_ui()
	_setup_input()

func _setup_ui() -> void:
	# Create a background that auto-resizes
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.6)
	_bg.position = Vector2(10, 10)
	add_child(_bg)

	_label = Label.new()
	_label.position = Vector2(20, 20)
	_label.modulate = Color(0.2, 1.0, 0.2) # Matrix Green
	add_child(_label)

func _setup_input() -> void:
	if not InputMap.has_action(TOGGLE_ACTION):
		var ev = InputEventKey.new()
		ev.keycode = KEY_F3
		InputMap.add_action(TOGGLE_ACTION)
		InputMap.action_add_event(TOGGLE_ACTION, ev)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION):
		_visible = not _visible
		visible = _visible

func _process(delta: float) -> void:
	if not _visible: return

	_time_since_last_update += delta
	if _time_since_last_update >= REFRESH_RATE:
		_time_since_last_update = 0.0
		_update_text()

# --- Public API ---

func monitor_set(category: String, key: String, value: Variant) -> void:
	if not _stats.has(category): _stats[category] = {}
	_stats[category][key] = value

func monitor_increment(category: String, key: String, amount: int) -> void:
	if not _stats.has(category): _stats[category] = {}
	var current = _stats[category].get(key, 0)
	_stats[category][key] = current + amount

# --- Rendering ---

func _update_text() -> void:
	var s = "=== SYSTEM METRICS ===\n"
	
	var fps = Engine.get_frames_per_second()
	var mem = OS.get_static_memory_usage() / 1048576.0
	var vram = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	var frame_time = 1000.0 / fps if fps > 0 else 0.0

	s += "FPS: %d  |  Frame: %.2f ms\n" % [fps, frame_time]
	s += "RAM: %.1f MB  |  VRAM: %.1f MB\n" % [mem, vram]
	s += "Draw Calls: %d\n" % [draw_calls]
	s += "Nodes: %d  |  Objects: %d\n\n" % [nodes, objects]
	
	for category in _stats:
		s += "--- %s ---\n" % category
		for key in _stats[category]:
			var val = _stats[category][key]
			if val is Vector3:
				s += "%s: (%.1f, %.1f, %.1f)\n" % [key, val.x, val.y, val.z]
			elif val is Vector2:
				s += "%s: (%.1f, %.1f)\n" % [key, val.x, val.y]
			else:
				s += "%s: %s\n" % [key, str(val)]
		s += "\n"
	
	_label.text = s
	# Adjust background size to fit text
	_bg.size = _label.get_combined_minimum_size() + Vector2(20, 20)
