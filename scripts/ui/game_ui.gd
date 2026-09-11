## GameUI — Presentation composition root for HUD, panels, intents, and notices.
class_name GameUI
extends Control

signal presentation_updated(hud_model: Dictionary)

var _presentation_coordinator: PresentationCoordinator
var _intent_gateway: UIIntentGateway
var _notification_adapter: NotificationAdapter
var _notification_layer: NotificationLayer
var _hud_model: Dictionary = {}


func _ready() -> void:
	# The simulation begins paused, but HUD controls must remain interactive.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel_manager: PanelManager = $PanelLayer/PanelManager as PanelManager
	if panel_manager != null:
		panel_manager.register_panel("finances", load("res://scenes/ui/finances_panel.tscn"))
		panel_manager.register_panel("visitors", load("res://scenes/ui/visitors_panel.tscn"))
	_presentation_coordinator = PresentationCoordinator.new()
	_intent_gateway = UIIntentGateway.new()
	_notification_adapter = NotificationAdapter.new()
	_create_notification_layer()
	_connect_presentation_events()
	var hud_bar: HUDBar = $HUDLayer/HUDBar as HUDBar
	if hud_bar != null:
		hud_bar.bind_presentation(self)
		hud_bar.save_requested.connect(_on_save_requested)
		hud_bar.load_requested.connect(_on_load_requested)
	get_tree().create_timer(0.25).timeout.connect(_refresh_presentation)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		open_notification_log()
		get_viewport().set_input_as_handled()


func get_hud_model() -> Dictionary:
	return _hud_model.duplicate(true)


func open_primary_panel(panel_name: String) -> bool:
	if _presentation_coordinator == null:
		return false
	var sources: Dictionary = _build_sources()
	var hud: Dictionary = _presentation_coordinator.build_hud(sources)
	sources["hud"] = _presentation_coordinator.source(PresentationCoordinator.AVAILABLE, 0, hud.get("metrics", {}))
	var model: Dictionary = _presentation_coordinator.build_panel(panel_name, sources)
	var panel_manager: PanelManager = $PanelLayer/PanelManager as PanelManager
	if panel_manager == null:
		return false
	return panel_manager.open_read_model_panel(panel_name, model)


func open_notification_log() -> bool:
	if _notification_adapter == null:
		return false
	var panel_manager: PanelManager = $PanelLayer/PanelManager as PanelManager
	return panel_manager != null and panel_manager.open_notification_log(_notification_adapter)


func _create_notification_layer() -> void:
	var layer: CanvasLayer = $NotificationLayer as CanvasLayer
	if layer == null:
		return
	var notification_script: Script = load("res://scripts/ui/notification_layer.gd")
	_notification_layer = notification_script.new() as NotificationLayer
	layer.add_child(_notification_layer)
	_notification_layer.bind(_notification_adapter)
	_sync_notification_badge()


func _connect_presentation_events() -> void:
	EventBus.money_changed.connect(func(_balance: int, _delta: int) -> void: _refresh_presentation())
	EventBus.rent_collected.connect(func(_amount: int) -> void: _refresh_presentation())
	EventBus.arrival_realized.connect(func(_envelope: Dictionary) -> void: _refresh_presentation())
	EventBus.visitor_left.connect(func(_visitor_id: String, _satisfaction: int) -> void: _refresh_presentation())
	EventBus.official_prestige_snapshot_changed.connect(func(_snapshot: Dictionary) -> void: _refresh_presentation())
	EventBus.official_tier_changed.connect(func(_previous: Dictionary, _current: Dictionary) -> void: _refresh_presentation())
	EventBus.sim_day_passed.connect(func(_day: int) -> void: _refresh_presentation())
	EventBus.wall_mode_changed.connect(func(_mode: String) -> void: _refresh_presentation())
	EventBus.zone_created.connect(func(_id: String, _type: String, _count: int) -> void: _refresh_presentation())
	EventBus.zone_modified.connect(func(_id: String) -> void: _refresh_presentation())
	EventBus.zone_deleted.connect(func(_id: String) -> void: _refresh_presentation())
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.notification_resolved.connect(_on_notification_resolved)


func _refresh_presentation() -> void:
	if _presentation_coordinator == null:
		return
	var sources: Dictionary = _build_sources()
	_hud_model = _presentation_coordinator.build_hud(sources)
	var hud_bar: HUDBar = $HUDLayer/HUDBar as HUDBar
	if hud_bar != null:
		hud_bar.apply_model(_hud_model)
	presentation_updated.emit(_hud_model.duplicate(true))


func _build_sources() -> Dictionary:
	var root: Node = get_tree().current_scene
	if root == null:
		return {}
	var sources: Dictionary = {}
	var economy: EconomyManager = root.get_node_or_null("Simulation/EconomyManager") as EconomyManager
	if economy != null:
		var economy_values: Dictionary = economy.serialize()
		sources["economy"] = _presentation_coordinator.source(
			PresentationCoordinator.AVAILABLE,
			economy.authority_revision,
			{"balance": economy_values.get("balance", economy.balance)},
		)
	var visitors: VisitorManager = root.get_node_or_null("Simulation/VisitorManager") as VisitorManager
	if visitors != null:
		var metrics: Dictionary = visitors.get_metrics_snapshot().duplicate(true)
		sources["visitors"] = _presentation_coordinator.source(
			PresentationCoordinator.AVAILABLE,
			int(metrics.get("metric_revision", -1)),
			metrics,
		)
	var prestige: PrestigeManager = root.get_node_or_null("Simulation/PrestigeManager") as PrestigeManager
	if prestige != null and prestige.is_initialized():
		var snapshot: OfficialPrestigeSnapshot = prestige.get_committed_snapshot()
		var prestige_values: Dictionary = snapshot.to_dictionary()
		if bool(prestige_values.get("numeric_prestige_present", false)):
			prestige_values["official_prestige"] = prestige_values.get("numeric_prestige", 0)
		sources["prestige"] = _presentation_coordinator.source(
			PresentationCoordinator.AVAILABLE,
			snapshot.get_authority_revision(),
			prestige_values,
		)
	var time_manager: TimeManager = root.get_node_or_null("Simulation/TimeManager") as TimeManager
	if time_manager != null:
		var time_values: Dictionary = time_manager.serialize()
		time_values["simulation_speed"] = GameManager.speed
		time_values["clock"] = time_manager.get_visual_clock_string()
		sources["time"] = _presentation_coordinator.source(
			PresentationCoordinator.AVAILABLE,
			int(time_values.get("sim_time", 0)),
			time_values,
		)
	sources["presentation"] = _presentation_coordinator.source(
			PresentationCoordinator.AVAILABLE,
			0,
			{"wall_mode": GameManager.WALL_MODE_NAMES[GameManager.wall_mode]},
		)
	var tenants: TenantManager = root.get_node_or_null("Simulation/TenantManager") as TenantManager
	if tenants != null:
		var tenant_values: Dictionary = tenants.serialize()
		sources["tenant"] = _presentation_coordinator.source(
			PresentationCoordinator.AVAILABLE,
			int(tenant_values.get("revision", 0)),
			{"tenants": tenant_values.get("tenants", [])},
		)
	return sources


func _on_notification_requested(text: String, category: String, priority: String, action_target: String) -> void:
	if _notification_adapter == null:
		return
	var calendar_identity: String = _calendar_identity()
	var source_identity: String = "event:%s:%s:%s:%s" % [calendar_identity, category, action_target, text]
	_notification_adapter.project({
		"source_identity": source_identity,
		"text": text,
		"category": category,
		"priority": priority,
		"navigation_target": action_target,
		"source_revision": 0,
		"calendar_identity": calendar_identity,
	})
	_sync_notification_badge()


func _on_notification_resolved(notification_id: String) -> void:
	if _notification_adapter != null:
		_notification_adapter.mark_resolved(notification_id)
	_sync_notification_badge()


func _sync_notification_badge() -> void:
	var toolbar: BottomToolbar = $ToolbarLayer/BottomToolbar as BottomToolbar
	if toolbar != null and _notification_adapter != null:
		toolbar.set_notification_unresolved(_notification_adapter.has_unresolved_high_priority())


func _calendar_identity() -> String:
	var root: Node = get_tree().current_scene
	var time_manager: TimeManager = root.get_node_or_null("Simulation/TimeManager") as TimeManager if root != null else null
	return "sim_day:%d" % int(time_manager.serialize().get("sim_time", 0)) if time_manager != null else ""


func _on_save_requested() -> void:
	var result: Error = SaveManager.save_game(1)
	var hud_bar: HUDBar = $HUDLayer/HUDBar as HUDBar
	if hud_bar != null:
		hud_bar.set_save_status(result == OK, "Saved slot 1" if result == OK else "Save failed: %s" % error_string(result))


func _on_load_requested() -> void:
	var result: Dictionary = SaveManager.load_game(1)
	var hud_bar: HUDBar = $HUDLayer/HUDBar as HUDBar
	if hud_bar != null:
		hud_bar.set_load_status(bool(result.get("valid", false)), "Loaded slot 1" if bool(result.get("valid", false)) else "Load failed: %s" % String(result.get("reason_code", "unknown error")))
	if bool(result.get("valid", false)):
		_refresh_presentation()
