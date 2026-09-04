## ParcelLabelRenderer — Floor-scoped read-only projection of committed parcels.
class_name ParcelLabelRenderer
extends Node


const TILE_LABEL_Y_OFFSET: float = 0.12
const NAME_LABEL_Y_OFFSET: float = 0.24
const LABEL_OPACITY: float = 0.2
const TILE_FONT_SIZE: int = 28
const NAME_FONT_SIZE: int = 42
const LABEL_PIXEL_SIZE: float = 0.008

## Supplied by MainGame before this node enters the scene tree.
var zone_manager: ZoneManager
var camera_manager: CameraManager
var source_plot_id: String = ""
var projection_plot_id: String = ""
var _projection_coordinator: ProjectionCoordinator
var _active_floor_level: String = GridManager.GROUND_FLOOR


func configure_plot_mapping(source_id: String, projected_id: String) -> void:
	source_plot_id = source_id
	projection_plot_id = projected_id


func _ready() -> void:
	if zone_manager == null:
		push_error("ParcelLabelRenderer: ZoneManager is required.")
		return
	_connect_events()
	if camera_manager != null:
		_active_floor_level = camera_manager.get_current_floor()
	hydrate_active_floor()


func _exit_tree() -> void:
	_disconnect_events()


## Rebuild committed labels for the active instantiated floor only.
func hydrate_active_floor() -> void:
	_bind_projection_events()
	_clear_all_label_containers()
	if not DebugManager.show_parcel_labels:
		return
	var floor := _get_active_floor()
	if floor == null:
		return
	for zone: ZoneData in zone_manager.get_zones_on_floor(_active_floor_level):
		if _zone_matches_floor(zone, floor):
			_render_zone(floor, zone)


func _connect_events() -> void:
	if not EventBus.zone_created.is_connected(_on_zone_created):
		EventBus.zone_created.connect(_on_zone_created)
	if not EventBus.zone_modified.is_connected(_on_zone_modified):
		EventBus.zone_modified.connect(_on_zone_modified)
	if not EventBus.zone_deleted.is_connected(_on_zone_deleted):
		EventBus.zone_deleted.connect(_on_zone_deleted)
	if not DebugManager.parcel_labels_visibility_changed.is_connected(_on_parcel_labels_visibility_changed):
		DebugManager.parcel_labels_visibility_changed.connect(_on_parcel_labels_visibility_changed)
	if camera_manager != null and not camera_manager.floor_changed.is_connected(_on_floor_changed):
		camera_manager.floor_changed.connect(_on_floor_changed)
	_bind_projection_events()


func _disconnect_events() -> void:
	if EventBus.zone_created.is_connected(_on_zone_created):
		EventBus.zone_created.disconnect(_on_zone_created)
	if EventBus.zone_modified.is_connected(_on_zone_modified):
		EventBus.zone_modified.disconnect(_on_zone_modified)
	if EventBus.zone_deleted.is_connected(_on_zone_deleted):
		EventBus.zone_deleted.disconnect(_on_zone_deleted)
	if DebugManager.parcel_labels_visibility_changed.is_connected(_on_parcel_labels_visibility_changed):
		DebugManager.parcel_labels_visibility_changed.disconnect(_on_parcel_labels_visibility_changed)
	if camera_manager != null and camera_manager.floor_changed.is_connected(_on_floor_changed):
		camera_manager.floor_changed.disconnect(_on_floor_changed)
	if _projection_coordinator != null and _projection_coordinator.projection_committed.is_connected(_on_projection_committed):
		_projection_coordinator.projection_committed.disconnect(_on_projection_committed)


func _bind_projection_events() -> void:
	if _projection_coordinator == null:
		var world := get_parent()
		if world != null:
			_projection_coordinator = world.get_node_or_null("ProjectionCoordinator") as ProjectionCoordinator
	if _projection_coordinator != null and not _projection_coordinator.projection_committed.is_connected(_on_projection_committed):
		_projection_coordinator.projection_committed.connect(_on_projection_committed)


func _on_projection_committed(_manifest: Dictionary) -> void:
	hydrate_active_floor()


func _on_zone_created(zone_id: String, _zone_type: String, _tile_count: int) -> void:
	_refresh_committed_zone(zone_id)


func _on_zone_modified(zone_id: String) -> void:
	_refresh_committed_zone(zone_id)


func _on_zone_deleted(zone_id: String) -> void:
	_remove_zone_group_from_all_floors(zone_id)


func _on_parcel_labels_visibility_changed(is_visible: bool) -> void:
	if is_visible:
		hydrate_active_floor()
	else:
		_clear_all_label_containers()


func _on_floor_changed(floor_level: String) -> void:
	_active_floor_level = floor_level
	hydrate_active_floor()


func _refresh_committed_zone(zone_id: String) -> void:
	if not DebugManager.show_parcel_labels:
		return
	var zone: ZoneData = zone_manager.zones.get(zone_id, null)
	if zone == null or zone.floor != _active_floor_level:
		return
	var floor := _find_floor(zone.plot_id, zone.floor)
	if floor == null or floor != _get_active_floor() or not _zone_matches_floor(zone, floor):
		return
	_remove_zone_group(floor, zone_id)
	_render_zone(floor, zone)


func _render_zone(floor: Floor, zone: ZoneData) -> void:
	var container := _get_or_create_label_container(floor)
	_remove_zone_group(floor, zone.id)
	for parcel: Parcel in zone.parcels:
		if parcel.display_number <= 0:
			continue
		var parcel_group := Node3D.new()
		parcel_group.name = parcel.id
		parcel_group.set_meta("zone_id", zone.id)
		container.add_child(parcel_group)
		_render_tile_labels(floor, parcel_group, parcel)
		_render_name_label(floor, parcel_group, parcel)


func _render_tile_labels(floor: Floor, parcel_group: Node3D, parcel: Parcel) -> void:
	for tile_position: Vector2i in parcel.tiles:
		var label := _make_label(str(parcel.display_number), TILE_FONT_SIZE)
		label.name = "Tile_%d_%d" % [tile_position.x, tile_position.y]
		label.position = floor.tile_center_to_local(tile_position) + Vector3(0.0, TILE_LABEL_Y_OFFSET, 0.0)
		parcel_group.add_child(label)


func _render_name_label(floor: Floor, parcel_group: Node3D, parcel: Parcel) -> void:
	var display_name := DebugBusinessSubtypeCatalog.display_name_for(parcel.assigned_subtype_id)
	if display_name.is_empty():
		display_name = "Unassigned Parcel"
	var label := _make_label(display_name, NAME_FONT_SIZE)
	label.name = "Name"
	var anchor_tile := parcel.label_anchor_tile()
	label.position = floor.tile_center_to_local(anchor_tile) + Vector3(0.0, NAME_LABEL_Y_OFFSET, 0.0)
	parcel_group.add_child(label)


func _make_label(text: String, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = LABEL_PIXEL_SIZE
	label.modulate = Color(1.0, 1.0, 1.0, LABEL_OPACITY)
	label.outline_size = 2
	label.outline_modulate = Color(0.0, 0.0, 0.0, LABEL_OPACITY)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _zone_matches_floor(zone: ZoneData, floor: Floor) -> bool:
	return not source_plot_id.is_empty() and not projection_plot_id.is_empty() and zone.plot_id == source_plot_id and floor.plot_id == projection_plot_id


func _get_projection_root() -> Node3D:
	_bind_projection_events()
	return _projection_coordinator.get_active_root() if _projection_coordinator != null else null


func _get_active_floor() -> Floor:
	var projection_root := _get_projection_root()
	if projection_root == null:
		return null
	for child in projection_root.get_children():
		var floor := child as Floor
		if floor != null and floor.floor_level == _active_floor_level:
			return floor
	return null


func _find_floor(plot_id: String, floor_level: String) -> Floor:
	var projection_root := _get_projection_root()
	if projection_root == null:
		return null
	if plot_id != source_plot_id or projection_plot_id.is_empty():
		return null
	for child in projection_root.get_children():
		var floor := child as Floor
		if floor != null and floor.plot_id == plot_id and floor.floor_level == floor_level:
			return floor
	return null


func _get_or_create_label_container(floor: Floor) -> Node3D:
	var container := floor.get_node_or_null("ParcelLabelContainer") as Node3D
	if container != null:
		return container
	container = Node3D.new()
	container.name = "ParcelLabelContainer"
	floor.add_child(container)
	return container


func _remove_zone_group(floor: Floor, zone_id: String) -> void:
	var container := floor.get_node_or_null("ParcelLabelContainer") as Node3D
	if container == null:
		return
	for parcel_group in container.get_children():
		if parcel_group.get_meta("zone_id", "") == zone_id:
			container.remove_child(parcel_group)
			parcel_group.queue_free()


func _remove_zone_group_from_all_floors(zone_id: String) -> void:
	var projection_root := _get_projection_root()
	if projection_root == null:
		return
	for child in projection_root.get_children():
		var floor := child as Floor
		if floor != null:
			_remove_zone_group(floor, zone_id)


func _clear_all_label_containers() -> void:
	var projection_root := _get_projection_root()
	if projection_root == null:
		return
	for child in projection_root.get_children():
		var floor := child as Floor
		if floor == null:
			continue
		var container := floor.get_node_or_null("ParcelLabelContainer") as Node3D
		if container == null:
			continue
		for label_group in container.get_children():
			container.remove_child(label_group)
			label_group.queue_free()
