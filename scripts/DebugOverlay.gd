# scripts/DebugOverlay.gd
extends CanvasLayer

# --- Configuration ---
const TOGGLE_ACTION: String = "debug_toggle" 
const REFRESH_RATE: float = 0.1 # Update UI every 100ms

# --- State ---
var _visible: bool = false
var _stats: Dictionary = {} 
var _time_since_last_update: float = 0.0
var _label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	visible = false
	
	_setup_ui()
	_setup_input()

func _setup_ui() -> void:
	_label = Label.new()
	_label.position = Vector2(20, 20)
	_label.modulate = Color(0.2, 1.0, 0.2) # Matrix Green
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.show_behind_parent = true
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	# Add some padding to background
	bg.offset_left = -10
	bg.offset_top = -10
	bg.offset_right = 10
	bg.offset_bottom = 10
	
	_label.add_child(bg)
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
	if not _visible:
		return

	_time_since_last_update += delta
	if _time_since_last_update < REFRESH_RATE:
		return
	_time_since_last_update = 0.0

	_update_text()

# --- Public API ---

## Set a value directly (Position, State Strings, etc)
func monitor_set(category: String, key: String, value: Variant) -> void:
	if not _stats.has(category): _stats[category] = {}
	_stats[category][key] = value

## Add/Subtract from a number (Counts)
func monitor_increment(category: String, key: String, amount: int) -> void:
	if not _stats.has(category): _stats[category] = {}
	var current = _stats[category].get(key, 0)
	_stats[category][key] = current + amount

# --- Rendering ---

func _update_text() -> void:
	var s = "=== SYSTEM METRICS ===\n"
	
	# Engine Stats
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
	
	# Custom Stats
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
