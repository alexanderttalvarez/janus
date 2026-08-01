## GridTile — Lightweight Resource representing a single grid tile.
## Pure data: owned, floor_built, walls_built, zone_id, element, typology, condition.
class_name GridTile
extends Resource


## What occupies this tile.
enum TileElement { NONE, SHOP, DECORATION, COLUMN, CIRCULATION, AMENITY }

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


## Reset all tile data to defaults.
func reset() -> void:
	owned = false
	floor_built = false
	walls_built = false
	zone_id = ""
	element = TileElement.NONE
	typology = TileTypology.TENANT
	condition = 100
