## DebugStateOverlay — F11 overlay showing current state of selected entities.
## Usage: Add as a child of any Control node. Press F11 to toggle.
## Shows all StateMachine instances in the tree and their current state.
class_name DebugStateOverlay
extends Control


const FONT_SIZE := 14
const PANEL_WIDTH := 300


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_panel()


func _setup_panel() -> void:
	# Semi-transparent background panel anchored to top-right.
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -PANEL_WIDTH
	offset_top = 4
	offset_right = -4
	offset_bottom = 4

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var label := Label.new()
	label.name = "StateList"
	label.position = Vector2(8, 8)
	label.size = Vector2(PANEL_WIDTH - 16, 0)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		visible = not visible
		if visible:
			_refresh()


func _refresh() -> void:
	var label: Label = get_node_or_null("StateList") as Label
	if label == null:
		return

	var lines: Array[String] = []
	lines.append("[b]State Machines[/b]")
	_collect_state_machines(get_tree().root, lines)

	label.text = "\n".join(lines)
	label.size.y = 0  # Auto-wrap height.


func _collect_state_machines(node: Node, lines: Array[String]) -> void:
	for child in node.get_children():
		if child is StateMachine:
			var sm := child as StateMachine
			var current := sm.get_current_state_name()
			var parent_name := sm.get_parent().name if sm.get_parent() else "none"
			lines.append("  [color=#5f5]%s[/color] ← %s" % [current, parent_name])
		_collect_state_machines(child, lines)
