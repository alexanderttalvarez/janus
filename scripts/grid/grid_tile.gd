## GridTile — Lightweight Resource representing a single grid tile.
## Pure data: owned, floor_built, walls_built, zone_id, element, typology, condition.
class_name GridTile
extends Resource


## What occupies this tile.
enum TileElement { NONE, SHOP, DECORATION, COLUMN, CIRCULATION, AMENITY }

## Door flags for the four edges of a tile. Values are combinable bit flags.
enum DoorSide { NORTH = 1, SOUTH = 2, EAST = 4, WEST = 8 }

## Zone typology classification (used for zone painting and splitting).
enum TileTypology { TENANT, DECORATION, TRANSIT }


## Whether this tile has been purchased by the player.
@export var owned: bool = false

## Whether the floor structure (floor plane) exists here.
@export var floor_built: bool = false

## Whether walls have been built on this tile's edges.
@export var walls_built: bool = false

## ID of the zone this tile belongs to (empty = none).
@export var zone_id: String = ""

## What element occupies this tile.
@export var element: TileElement = TileElement.NONE

## Zone typology classification.
@export var typology: TileTypology = TileTypology.TENANT

## Tile condition (0-100, used for maintenance system post-MVP).
@export var condition: int = 100

## Door sides stored as a combinable DoorSide bitmask.
@export_flags("North", "South", "East", "West") var door_sides: int = 0


## Return whether this tile edge contains a door.
func has_door(side: DoorSide) -> bool:
	return (door_sides & int(side)) != 0


## Set or clear a door on this tile edge.
func set_door(side: DoorSide, enabled: bool = true) -> void:
	if enabled:
		door_sides |= int(side)
	else:
		door_sides &= ~int(side)


## Reset all tile data to defaults.
func reset() -> void:
	owned = false
	floor_built = false
	walls_built = false
	zone_id = ""
	element = TileElement.NONE
	typology = TileTypology.TENANT
	condition = 100
	door_sides = 0
