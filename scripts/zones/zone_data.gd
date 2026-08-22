## ZoneData — Resource representing a single zone on one explicit plot and floor.
class_name ZoneData
extends Resource


## Zone type: Retail, FoodBeverage, Entertainment, Services, Anchor.
enum ZoneType { RETAIL, FOOD_BEVERAGE, ENTERTAINMENT, SERVICES, ANCHOR }

## Zone type names: maps ZoneType enum to display strings.
const ZONE_TYPE_NAMES: Array[String] = ["Retail", "Food & Beverage", "Entertainment", "Services", "Anchor"]

## Zone type IDs for the shader overlay: matches zone_overlay.gdshader.
const ZONE_TYPE_IDS: Dictionary = {
	ZONE_TYPE_NAMES[0]: 1,
	ZONE_TYPE_NAMES[1]: 2,
	ZONE_TYPE_NAMES[2]: 3,
	ZONE_TYPE_NAMES[3]: 4,
	ZONE_TYPE_NAMES[4]: 5,
}


## Unique identifier for this zone.
@export var id: String = ""

## Owning plot; required for all zone and split operations.
@export var plot_id: String = ""

## Zone type as a string (for example, "Retail" or "Food & Beverage").
@export var type: String = ""

## Legacy zone-level business subtype. Parcel subtype data is introduced later.
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

## Valid parcel subdivisions created by ZoneSplitter after an accepted commit.
var parcels: Array[Parcel] = []
