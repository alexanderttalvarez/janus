## StaffManager — Operations rooms, cleaner task queues, security patrols.
class_name StaffManager
extends Node


var operations_rooms: Array[OperationsRoomData] = []
var all_staff: Array[StaffData] = []
var garbage_queue: Array[Vector2i] = []  # Simulated garbage spawns.
var bins_per_floor: Dictionary = {}  # floor -> bin_count

var _staff_counter: int = 0
var _room_counter: int = 0
var _grid_manager: GridManager


func initialize(gm: GridManager) -> void:
	_grid_manager = gm


## Place an Operations Room (2×2).
func place_room(floor: String, top_left: Vector2i) -> OperationsRoomData:
	var room := OperationsRoomData.new()
	room.id = "room_%d" % _room_counter
	_room_counter += 1
	room.floor = floor
	room.tiles = [top_left, top_left + Vector2i(1, 0), top_left + Vector2i(0, 1), top_left + Vector2i(1, 1)]
	operations_rooms.append(room)
	EventBus.operations_room_placed.emit(room.id, floor.to_int() if floor.is_valid_int() else 0)
	return room


## Hire staff.
func hire_staff(room_id: String, staff_type: OperationsRoomData.StaffType) -> StaffData:
	var staff := StaffData.new()
	staff.id = "staff_%d" % _staff_counter
	_staff_counter += 1
	staff.type = staff_type
	staff.current_room_id = room_id
	all_staff.append(staff)
	EventBus.staff_hired.emit(room_id, "Cleaner" if staff_type == OperationsRoomData.StaffType.CLEANER else "Security", staff.id)
	return staff


## Process staff tick (every visitor_tick).
func on_visitor_tick() -> void:
	_spawn_garbage()
	_assign_cleaner_tasks()
	_calculate_cleanliness()
	_calculate_insecurity()


func _spawn_garbage() -> void:
	var total_visitors := 0  # Would come from VisitorManager reference.
	if total_visitors > 0 and randi() % 5 == 0:
		var x := randi_range(2, 22)
		var y := randi_range(2, 22)
		garbage_queue.append(Vector2i(x, y))


func _assign_cleaner_tasks() -> void:
	if garbage_queue.is_empty():
		return
	for staff: StaffData in all_staff:
		if staff.type == OperationsRoomData.StaffType.CLEANER and staff.state == StaffData.StaffState.IDLE:
			if not garbage_queue.is_empty():
				staff.current_task_position = garbage_queue.pop_front()
				staff.state = StaffData.StaffState.WORKING
				EventBus.staff_task_completed.emit(staff.id, "cleaning")


func _calculate_cleanliness() -> void:
	var score := 100
	var bin_count := 0
	for v: int in bins_per_floor.values():
		bin_count += v
	score -= mini(garbage_queue.size() * 2, 30)
	score += mini(bin_count * 10, 80)
	score = clampi(score, 0, 100)
	EventBus.cleanliness_changed.emit(score)


func _calculate_insecurity() -> void:
	var security_count := 0
	for staff: StaffData in all_staff:
		if staff.type == OperationsRoomData.StaffType.SECURITY:
			security_count += 1
	var score := clampi(float(50.0 - float(security_count) * 10.0 + float(garbage_queue.size()) * 0.5), 0.0, 100.0)
	EventBus.insecurity_changed.emit(score)


func serialize() -> Dictionary:
	return {"rooms": operations_rooms.size(), "staff": all_staff.size(), "staff_counter": _staff_counter, "room_counter": _room_counter}


func deserialize(data: Dictionary) -> void:
	_staff_counter = data.get("staff_counter", 0)
	_room_counter = data.get("room_counter", 0)
