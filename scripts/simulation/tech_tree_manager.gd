## TechTreeManager — Unlock progression via tech points from prestige.
class_name TechTreeManager
extends Node


signal point_spent(node_id: String)
signal points_changed(available: int, total_earned: int)


## Tech tree node definition.
class TechNode:
	var id: String
	var name_key: String
	var description_key: String
	var grid_pos: Vector2i
	var prerequisites: Array[String]  # IDs of required nodes.
	var cost: int


## All defined tech nodes.
var nodes: Dictionary = {}  # Dictionary[String, TechNode]

## Unlocked node IDs.
var unlocked: Array[String] = []

## Available tech points to spend.
var available_points: int = 0:
	set(value):
		available_points = value
		points_changed.emit(available_points, total_earned)

## Total tech points earned over the game.
var total_earned: int = 0


func _ready() -> void:
	define_tech_tree()


## Define the tech tree nodes.
func define_tech_tree() -> void:
	_add_node("escalator_1", "Escalators I", "Unlock escalator placement.", Vector2i(2, 0), [], 2)
	_add_node("elevator_1", "Elevators I", "Unlock elevator placement.", Vector2i(4, 0), [], 2)
	_add_node("escalator_2", "Escalators II", "Faster escalators.", Vector2i(2, 2), ["escalator_1"], 4)
	_add_node("elevator_2", "Elevators II", "Larger capacity elevators.", Vector2i(4, 2), ["elevator_1"], 4)
	_add_node("amenity_garden", "Gardens", "Place gardens for prestige.", Vector2i(1, 4), [], 3)
	_add_node("amenity_seating", "Seating Areas", "Place seating for comfort.", Vector2i(3, 4), [], 3)
	_add_node("staff_cleaner", "Cleaners", "Hire cleaning staff.", Vector2i(0, 2), [], 3)
	_add_node("staff_security", "Security", "Hire security staff.", Vector2i(6, 2), [], 3)
	_add_node("zone_anchor", "Anchor Stores", "Unlock anchor-type zones.", Vector2i(5, 4), [], 5)


func _add_node(id: String, name_key: String, desc: String, pos: Vector2i, pre: Array[String], cost: int) -> void:
	var node := TechNode.new()
	node.id = id; node.name_key = name_key; node.description_key = desc
	node.grid_pos = pos; node.prerequisites = pre; node.cost = cost
	nodes[id] = node


## Earn tech points (from PrestigeManager level-ups).
func earn_points(amount: int) -> void:
	available_points += amount
	total_earned += amount
	points_changed.emit(available_points, total_earned)


## Check if a node can be unlocked.
func can_unlock(node_id: String) -> bool:
	if not nodes.has(node_id):
		return false
	if unlocked.has(node_id):
		return false
	var node: TechNode = nodes[node_id]
	if available_points < node.cost:
		return false
	for pre: String in node.prerequisites:
		if not unlocked.has(pre):
			return false
	return true


## Unlock a tech node.
func unlock_node(node_id: String) -> bool:
	if not can_unlock(node_id):
		return false
	var node: TechNode = nodes[node_id]
	available_points -= node.cost
	unlocked.append(node_id)
	point_spent.emit(node_id)
	EventBus.tech_point_spent.emit(node_id)
	EventBus.tech_points_changed.emit(available_points, total_earned)
	return true


func serialize() -> Dictionary:
	return {"unlocked": unlocked.duplicate(), "available_points": available_points, "total_earned": total_earned}


func deserialize(data: Dictionary) -> void:
	unlocked = data.get("unlocked", [])
	available_points = data.get("available_points", 0)
	total_earned = data.get("total_earned", 0)
