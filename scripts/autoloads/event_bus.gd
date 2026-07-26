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

# ── Prestige & Progression ───────────────────────────────────────────

## Prestige score recalculated (monthly).
signal prestige_recalculated(new_prestige: int, scale: int, quality: int)

## Mall level advanced.
signal mall_level_up(new_level: String, tech_points_earned: int)

## Tech point spent in the tech tree.
signal tech_point_spent(node_id: String)

# ── Zones & Building ─────────────────────────────────────────────────

## A new zone was created.
signal zone_created(zone_id: String, zone_type: String, tile_count: int)

## A zone was modified (tiles added/removed).
signal zone_modified(zone_id: String)

## A zone was deleted/demolished.
signal zone_deleted(zone_id: String)

## A tile was purchased on a floor.
signal tile_purchased(floor: int, tile_x: int, tile_y: int)

## A tile was sold/demolished.
signal tile_sold(floor: int, tile_x: int, tile_y: int)

# ── Tenants ──────────────────────────────────────────────────────────

## A tenant applied to a vacant zone.
signal tenant_applied(zone_id: String, tenant_id: String, tier: int)

## A tenant began construction.
signal tenant_construction_started(zone_id: String, tenant_id: String)

## A tenant opened for business.
signal tenant_opened(zone_id: String, tenant_id: String)

## A tenant's viability status changed.
signal tenant_viability_changed(tenant_id: String, status: String)

## A tenant closed/evicted.
signal tenant_closed(zone_id: String, tenant_id: String)

# ── Visitors ─────────────────────────────────────────────────────────

## A visitor entered the district.
signal visitor_entered(visitor_id: String)

## A visitor left the district.
signal visitor_left(visitor_id: String, satisfaction: int)

## Aggregate visitor satisfaction updated.
signal visitor_satisfaction_updated(average: float)

# ── Time & Simulation ────────────────────────────────────────────────

## Simulation tick (every sim day).
signal sim_day_passed(day: int)

## Simulation month passed (every 30 sim days).
signal sim_month_passed(month: int)

## Visual day/night phase changed.
signal visual_phase_changed(phase: String)

## Season changed.
signal season_changed(season: String)

# ── UI ───────────────────────────────────────────────────────────────

## A heatmap mode was toggled.
signal heatmap_toggled(mode: String, active: bool)

## An informational panel was opened.
signal panel_opened(panel_name: String)

## An informational panel was closed.
signal panel_closed(panel_name: String)

# ── General ──────────────────────────────────────────────────────────

## A notification should be shown to the player.
signal notification_requested(text: String, type: String)

## The player requested to undo the last action.
signal undo_requested

## The player requested to redo an undone action.
signal redo_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
