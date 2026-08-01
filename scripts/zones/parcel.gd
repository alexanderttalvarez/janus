## Parcel — A sub-division of a zone created by ZoneSplitter.
## Each parcel represents a contiguous group of tiles assigned to one business/tenant.
class_name Parcel
extends RefCounted


## Unique parcel identifier.
var id: String = ""

## Tile positions in this parcel.
var tiles: Array[Vector2i] = []

## Frontage tiles (tiles bordering walkable areas).
var frontage_tiles: Array[Vector2i] = []

## Business type assigned to this parcel (after ZoneBusinessAssigner).
var business_type: String = ""

## Whether this parcel has an active tenant.
var has_tenant: bool = false

## Reference to the tenant occupying this parcel (set by TenantManager).
var tenant_id: String = ""
