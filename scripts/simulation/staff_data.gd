## StaffData — Individual staff member state.
class_name StaffData
extends RefCounted


enum StaffState { IDLE, MOVING_TO_TASK, WORKING }


var id: String = ""
var type: OperationsRoomData.StaffType = OperationsRoomData.StaffType.CLEANER
var state: StaffState = StaffState.IDLE
var current_room_id: String = ""
var current_task_position: Vector2i = Vector2i.ZERO
var salary: int = 50  # Monthly salary.
