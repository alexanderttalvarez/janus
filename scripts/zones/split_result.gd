## SplitResult — Immutable-style output from the pure ZoneSplitter geometry pass.
class_name SplitResult
extends RefCounted


enum Status { SUCCESS, INVALID_ZONE_GEOMETRY, NO_VALID_FRONTAGE, INSUFFICIENT_RENTABLE_SPACE }


## Overall result of the split attempt.
var status: Status = Status.INVALID_ZONE_GEOMETRY

## Valid, non-overlapping fronted rectangular parcels.
var parcels: Array[Parcel] = []

## Tenant tiles proposed for Decoration conversion on successful splits.
var residual_tiles: Array[Vector2i] = []

## Stable diagnostics for future UI and notification handling.
var diagnostics: Array[String] = []


func is_success() -> bool:
	return status == Status.SUCCESS


static func success(
	p_parcels: Array[Parcel], p_residual_tiles: Array[Vector2i], p_diagnostics: Array[String] = []
) -> SplitResult:
	var result := SplitResult.new()
	result.status = Status.SUCCESS
	result.parcels = p_parcels
	result.residual_tiles = p_residual_tiles
	result.diagnostics = p_diagnostics
	return result


static func failure(p_status: Status, p_diagnostic: String) -> SplitResult:
	var result := SplitResult.new()
	result.status = p_status
	result.diagnostics = [p_diagnostic]
	return result
