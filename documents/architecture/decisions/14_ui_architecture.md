## Decision 14: UI Architecture — Multi-CanvasLayer with game_ui.tscn Sub-scene
**Date:** 2026-07-28
**Status:** Accepted

### Context
Janus has a layered UI system: HUD bar, bottom toolbar, informational panels, notifications, and thought bubbles. We needed to decide on scene structure, panel lifecycle, and data flow.

### Decision
- **UI lives in `game_ui.tscn`** — a sub-scene instanced into `main_game.tscn`
- **Multiple CanvasLayers** (5 layers: HUD, Toolbar, Panel, Notification, Overlay)
- **PanelManager controls panel lifecycle** — opens/closes/stacks panels (max 3 simultaneously)
- **Hybrid data flow** — direct access for initial state, EventBus signals for reactive updates
- **Each panel is a separate `.tscn` file**, instanced by PanelManager at runtime

### Scene Structure
```
main_game.tscn (Node3D)
├── World (Node3D)
├── Simulation (Node)
└── GameUI (game_ui.tscn instanced)
    ├── HUDLayer (CanvasLayer, layer 1)
    │   └── HUDBar (Control)
    ├── ToolbarLayer (CanvasLayer, layer 2)
    │   └── BottomToolbar (Control)
    ├── PanelLayer (CanvasLayer, layer 3)
    │   └── PanelContainer (Control) ← PanelManager script
    ├── NotificationLayer (CanvasLayer, layer 4)
    │   └── NotificationSystem (Control)
    └── OverlayLayer (CanvasLayer, layer 5)
        └── ThoughtBubbleContainer (Control)
```

### Panel Lifecycle
1. Player clicks toolbar button → `PanelManager.open_panel("finances")`
2. PanelManager instantiates `finances_panel.tscn`, adds to PanelContainer
3. Panel reads initial state from managers, connects to EventBus signals
4. Player clicks X or Escape → `PanelManager.close_panel("finances")`
5. Panel disconnects signals, queues free, PanelManager repositions remaining panels

### Data Flow Pattern (Hybrid)
```gdscript
func _ready() -> void:
    # Initial state — direct access
    $BalanceLabel.text = "%,d K" % EconomyManager.balance
    # Future updates — signals
    EventBus.money_changed.connect(_on_money_changed)

func _on_money_changed(balance: int, delta: int) -> void:
    $BalanceLabel.text = "%,d K" % balance

func _exit_tree() -> void:
    EventBus.money_changed.disconnect(_on_money_changed)
```

### Rationale
- `game_ui.tscn` keeps `main_game.tscn` clean and allows independent UI iteration
- Multiple CanvasLayers give explicit layer ordering and independent visibility control
- PanelManager enforces max-3 rule and handles stacking logic centrally
- Hybrid data flow ensures panels show correct data immediately on open (signals alone would cause blank panels)

### Consequences
- Each panel must implement the hybrid pattern (read state + connect signals + disconnect on exit)
- PanelManager needs a registry mapping panel names to `.tscn` paths
- CanvasLayer ordering must be maintained (HUD always on top, panels below, etc.)
