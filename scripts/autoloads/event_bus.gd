## EventBus — Decoupled signal relay for cross-system communication.
## Registered as autoload "EventBus" in project settings.
##
## All cross-system signals are declared here. Systems emit to EventBus;
## listeners connect to EventBus. This prevents direct dependencies
## between systems (e.g., Economy should not import VisitorSimulation).
##
## This autoload is process mode ALWAYS so signals can fire while paused.
extends Node

# ── Economy ──────────────────────────────────────────────────────────

## Player's money balance changed.
signal money_changed(new_balance: int, delta: int)

## Daily rent collected from tenants.
signal rent_collected(amount: int)

## Loan taken by the player.
signal loan_taken(loan_id: String, amount: int, interest_rate: float)

## Loan payment made (or missed).
signal loan_payment(loan_id: String, paid: bool)

## Loan default occurred (failed payment).
signal loan_default(loan_id: String, failed_count: int)

## Loan fully repaid.
signal loan_repaid(loan_id: String)

# ── Prestige & Progression ───────────────────────────────────────────

## Prestige score recalculated (monthly).
signal prestige_recalculated(new_prestige: int, scale: int, quality: int)

## Mall level advanced.
signal mall_level_up(new_level: String, tech_points_earned: int)

## Tech point spent in the tech tree.
signal tech_point_spent(node_id: String)

## Tech points balance changed.
signal tech_points_changed(available: int, total_earned: int)

# ── Zones & Building ─────────────────────────────────────────────────

## A new zone was created.
signal zone_created(zone_id: String, zone_type: String, tile_count: int)

## A zone was modified (tiles added/removed).
signal zone_modified(zone_id: String)

## A zone was deleted/demolished.
signal zone_deleted(zone_id: String)

## A zone's wall mode changed.
signal zone_wall_mode_changed(zone_id: String, walls_enabled: bool)

## A tile was purchased on a floor.
signal tile_purchased(floor: int, tile_x: int, tile_y: int)

## A tile was sold/demolished.
signal tile_sold(floor: int, tile_x: int, tile_y: int)

## A floor was acquired.
signal floor_acquired(floor_level: String)

# ── Tenants ──────────────────────────────────────────────────────────

## A tenant applied to a vacant zone.
signal tenant_applied(zone_id: String, tenant_id: String, tier: int)

## A tenant began construction.
signal tenant_construction_started(zone_id: String, tenant_id: String)

## A tenant's construction progressed.
signal tenant_construction_progress(zone_id: String, tenant_id: String, progress: float)

## A tenant opened for business.
signal tenant_opened(zone_id: String, tenant_id: String)

## A tenant's viability status changed.
signal tenant_viability_changed(tenant_id: String, status: String)

## A tenant closed/evicted.
signal tenant_closed(zone_id: String, tenant_id: String)

## A tenant upgraded tier.
signal tenant_upgraded(tenant_id: String, new_tier: int)

# ── Visitors ─────────────────────────────────────────────────────────

## A visitor entered the district.
signal visitor_entered(visitor_id: String)

## A visitor left the district.
signal visitor_left(visitor_id: String, satisfaction: int)

## Aggregate visitor satisfaction updated.
signal visitor_satisfaction_updated(average: float)

## Visitor thought aggregation changed.
signal visitor_thoughts_updated(top_thoughts: Array)

# ── Time & Simulation ────────────────────────────────────────────────

## Simulation tick (every sim day).
signal sim_day_passed(day: int)

## Simulation month passed (every 30 sim days).
signal sim_month_passed(month: int)

## Visual day/night phase changed.
signal visual_phase_changed(phase: String)

## Season changed.
signal season_changed(season: String)

# ── Circulation & Transit ────────────────────────────────────────────

## A circulation element was placed.
signal circulation_placed(element_type: String, floor: int, tile_x: int, tile_y: int)

## A circulation element was removed.
signal circulation_removed(element_type: String, floor: int)

## Congestion detected on a tile.
signal congestion_detected(floor: int, tile_x: int, tile_y: int, severity: float)

# ── Walls ────────────────────────────────────────────────────────────

## Wall visualization mode changed.
signal wall_mode_changed(mode: String)

## Wall material changed (post-MVP).
signal wall_material_changed(scope: String, material_id: String)

# ── Staff ────────────────────────────────────────────────────────────

## An Operations Room was placed.
signal operations_room_placed(room_id: String, floor: int)

## An Operations Room was removed.
signal operations_room_removed(room_id: String)

## A staff member was hired.
signal staff_hired(room_id: String, staff_type: String, staff_id: String)

## A staff member was fired.
signal staff_fired(room_id: String, staff_type: String, staff_id: String)

## A staff task was completed.
signal staff_task_completed(staff_id: String, task_type: String)

## Cleanliness score changed.
signal cleanliness_changed(score: int)

## Insecurity score changed.
signal insecurity_changed(score: float)

# ── Synergy ──────────────────────────────────────────────────────────

## Synergy scores recalculated.
signal synergy_recalculated(zone_synergies: Dictionary)

## A synergy relationship changed.
signal synergy_changed(zone_a: String, zone_b: String, old_value: int, new_value: int)

# ── Terraces ─────────────────────────────────────────────────────────

## A terrace tile was placed.
signal terrace_placed(floor: int, tile_x: int, tile_y: int)

## A terrace tile was removed.
signal terrace_removed(floor: int, tile_x: int, tile_y: int)

## A terrace door was placed.
signal terrace_door_placed(floor: int, tile_x: int, tile_y: int, direction: int)

# ── Notifications ────────────────────────────────────────────────────

## A notification should be shown.
signal notification_requested(text: String, category: String, priority: String, action_target: String)

## A notification was resolved.
signal notification_resolved(notification_id: String)

# ── UI ───────────────────────────────────────────────────────────────

## A heatmap mode was toggled.
signal heatmap_toggled(mode: String, active: bool)

## An informational panel was opened.
signal panel_opened(panel_name: String)

## An informational panel was closed.
signal panel_closed(panel_name: String)

## UI mode changed (Build, Observe, EditZone).
signal ui_mode_changed(mode: String)

## Camera rotated.
signal camera_rotated(direction: int)

## Camera focused on an element.
signal camera_focused(element_type: String, element_id: String)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
