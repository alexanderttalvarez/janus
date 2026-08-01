## OperationsRoomData — A 2×2 Operations Room placed on the grid.
## Houses staff (cleaners, security). Provides coverage for nearby floors.
class_name OperationsRoomData
extends RefCounted


enum StaffType { CLEANER, SECURITY }


var id: String = ""
var floor: String = "G"
var tiles: Array[Vector2i] = []
var capacity: int = 4
var staff: Array = []  # Array[StaffData]
