## Decision 15: Save/Load Architecture — JSON with Manager Serialization
**Date:** 2026-07-28
**Status:** Accepted

### Context
The game needs to persist economy, grid, zones, tenants, visitors, time, tech tree, prestige, and staff state. Settings (volume, keybindings) also need persistence. We needed to decide on serialization format, save structure, and responsibility.

### Decision
- **JSON serialization** — human-readable, easy to debug, fast enough for this game
- **Single monolithic file per save slot** — atomic saves, simple management
- **SaveManager orchestrates** — each manager implements `serialize()` and `deserialize()`
- **Settings use ConfigFile** — separate file at `user://settings.cfg`
- **Save format versioning** — `meta.version` field enables migration between versions

### SaveManager Structure
```
SaveManager (Node, autoload)
├── save_game(slot) → Error
├── load_game(slot) → Error
├── delete_save(slot) → Error
├── has_save(slot) → bool
├── get_save_meta(slot) → Dictionary
├── save_setting(section, key, value)
├── load_setting(section, key, default) → Variant
├── SAVE_DIR = "user://saves/"
├── MAX_SLOTS = 5
└── SETTINGS_PATH = "user://settings.cfg"
```

### Save File Structure
```json
{
  "meta": { "slot": 1, "timestamp": 1722182400, "version": "0.1.0" },
  "economy": { "balance": 500000, "loans": [...] },
  "grid": { "plots": { "plot_0": { "floors": {...} } } },
  "zones": [...],
  "tenants": [...],
  "visitors": [...],
  "time": { "sim_time": 86400.0, "visual_time": 600.0 },
  "tech_tree": { "unlocked_nodes": [...], "tech_points": 5 },
  "prestige": { "scale": 42, "quality": 68 },
  "staff": { "operations_rooms": [...] }
}
```

### Manager Interface
```gdscript
# Each manager implements:
func serialize() -> Dictionary:
    return { "balance": balance, "loans": loans.map(func(l): return l.serialize()) }

func deserialize(data: Dictionary) -> void:
    balance = data["balance"]
    for loan_data in data["loans"]:
        loans.append(LoanData.deserialize(loan_data))
```

### Rationale
- JSON is human-readable — saves can be inspected and debugged
- Single file is atomic — no partial saves
- Manager-owned serialization keeps data ownership clear
- ConfigFile for settings is Godot's built-in solution for key-value persistence
- Version field enables forward-compatible save migration

### Consequences
- Each manager must implement serialize/deserialize
- SaveManager needs references to all managers (or they register themselves)
- Migration functions needed when save format changes between versions
- Settings are loaded at game start, saved immediately when changed
