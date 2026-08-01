## ZoneData — Resource representing a single zone on the grid.
## Owned by ZoneManager. Contains tile positions, typologies, parcels, and metadata.
class_name ZoneData
extends Resource


## Zone type: Retail, FoodBeverage, Entertainment, Services, Anchor.
enum ZoneType { RETAIL, FOOD_BEVERAGE, ENTERTAINMENT, SERVICES, ANCHOR }

## Zone type names: maps ZoneType enum to display strings.
const ZONE_TYPE_NAMES: Array[String] = ["Retail", "Food & Beverage", "Entertainment", "Services", "Anchor"]

## Zone type IDs for the shader overlay: matches zone_overlay.gdshader.
const ZONE_TYPE_IDS: Dictionary = {
	ZONE_TYPE_NAMES[0]: 1,  # Retail -> Orange
	ZONE_TYPE_NAMES[1]: 2,  # Food -> Red
	ZONE_TYPE_NAMES[2]: 3,  # Entertainment -> Purple
	ZONE_TYPE_NAMES[3]: 4,  # Services -> Blue
	ZONE_TYPE_NAMES[4]: 5,  # Anchor -> Gold
}


## Unique identifier for this zone.
@export var id: String = ""

## Zone type as a string (e.g., "Retail", "Food & Beverage").
@export var type: String = ""

## Business subtype assigned after splitting (e.g., "Clothing", "Restaurant").
var subtype: String = ""

## Floor level this zone is on.
@export var floor: String = "G"

## All tile positions belonging to this zone.
@export var tiles: Array[Vector2i] = []

## Per-tile typology classification.
var typologies: Dictionary = {}  # Dictionary[Vector2i, GridTile.TileTypology]

## Whether this zone has walls enabled.
@export var walls_enabled: bool = true

## Display name for this zone (optional, for UI).
@export var zone_name: String = ""

## Parcels (sub-divisions) created by ZoneSplitter.
var parcels: Array = []  # Array[Parcel]
