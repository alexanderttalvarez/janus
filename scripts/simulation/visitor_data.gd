## VisitorData — All state for a single visitor agent.
## Visitors exist as data in the all_visitors array regardless of visibility.
## When visible, a Node3D is created to display the visitor.
class_name VisitorData
extends RefCounted


## Visitor purpose/goal types.
enum VisitPurpose { SHOPPING, DINING, ENTERTAINMENT, SERVICES, BROWSING }

## Visitor needs.
enum NeedType { HUNGER, BOREDOM, SHOPPING_URGE, REST, SOCIAL }


## Unique identifier.
var id: String = ""

## Current state machine state name (e.g., "entering", "moving", "leaving").
var current_state: String = "entering"

## Primary purpose for visiting.
var purpose: VisitPurpose = VisitPurpose.BROWSING

## Budget in Kreds (how much they'll spend).
var budget: int = 0

## Current need levels (0-100, higher = more urgent).
var needs: Dictionary = {}  # Dictionary[NeedType, int]

## Patience level (0-100, decreases while waiting, 0 = leave).
var patience: int = 80

## Current world position.
var position: Vector3 = Vector3.ZERO

## Target world position (for move_toward interpolation).
var target_position: Vector3 = Vector3.ZERO

## Current floor level.
var floor_level: String = "G"

## Current walkable area type. Visitors begin on the exterior ring.
var location_type: String = "pedestrian_area"

## Door side currently used for building entry, or NONE when outside.
var entry_door_side: int = 0

## Stable plot spawn point used for entry or voluntary exit.
var spawn_point_id: String = ""

## Current waypoint index in the walkable area's route.
var waypoint_index: int = 0

## Queue of goals to visit (zone_ids).
var goal_queue: Array[String] = []

## Satisfaction score (0-100, reported on exit).
var satisfaction: int = 50

## Whether this visitor is currently visible (has a Node3D).
var is_visible: bool = false

## Reference to the visual Node3D (null when not visible).
var visual_node: Node3D

## Entry time (sim_time when spawned).
var spawn_time: float = 0.0


## Initialize a new visitor with randomized attributes.
func initialize(p_id: String, p_floor: String, p_position: Vector3) -> void:
	id = p_id
	floor_level = p_floor
	location_type = "pedestrian_area"
	entry_door_side = 0
	spawn_point_id = ""
	waypoint_index = 0
	position = p_position
	target_position = p_position

	# Randomize purpose.
	var purposes := [VisitPurpose.SHOPPING, VisitPurpose.DINING, VisitPurpose.ENTERTAINMENT, VisitPurpose.SERVICES, VisitPurpose.BROWSING]
	purpose = purposes[randi() % purposes.size()]

	# Randomize budget (100-500 Kreds).
	budget = randi_range(100, 500)

	# Initialize needs.
	needs = {
		NeedType.HUNGER: randi_range(20, 60),
		NeedType.BOREDOM: randi_range(10, 50),
		NeedType.SHOPPING_URGE: randi_range(30, 80),
		NeedType.REST: randi_range(0, 30),
		NeedType.SOCIAL: randi_range(10, 40),
	}

	patience = randi_range(60, 100)
	satisfaction = 50


## Decay needs over time (called on visitor tick).
func decay_needs() -> void:
	for key: NeedType in needs:
		needs[key] += randi_range(1, 3)
		needs[key] = mini(needs[key], 100)


## Generate a thought bubble text based on current state.
func get_thought() -> String:
	if patience < 30:
		return "This line is too slow..."
	if current_state == "satisfying_need":
		return "Nice place!"
	if current_state == "exploring":
		return "What's over there?"
	if current_state == "moving":
		return "Where's the food court?"
	if current_state == "leaving":
		return "Good visit!"
	return "Hmm..."
