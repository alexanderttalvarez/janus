## Decision 21: Multi-Language Architecture — Godot CSV/PO with tr()
**Date:** 2026-07-28
**Status:** Accepted

### Context
Game must support multiple languages. English is primary, but translations should be easy to add.

### Decision
- **Godot's built-in translation system** — CSV or PO files in `translations/` directory
- **All UI text uses `tr("key")`** — no hardcoded strings in code or scenes
- **Data stores translation keys** — TechTreeData uses `name_key`, `description_key` instead of raw strings
- **TranslationServer handles loading/switching** — no custom translation logic needed

### File Structure
```
translations/
├── en.csv
├── es.csv
├── fr.csv
└── ja.csv
```

### Rationale
- Godot's translation system is mature and well-integrated
- CSV files are easy to edit and version control
- `tr()` is the standard Godot pattern — no custom infrastructure needed

### Consequences
- All UI labels must use `tr()` or be marked for translation in Inspector
- Data dictionaries store keys, not raw strings
- New languages require adding a CSV file and registering it in Project Settings
