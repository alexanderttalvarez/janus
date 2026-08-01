## HeatmapManager — Manages the SubViewport-based heatmap overlay system.
##
## Creates a SubViewport with a full-screen ColorRect using the heatmap
## overlay shader. Tile data is written into an ImageTexture for the shader
## to sample. Toggled via GameManager.active_heatmap.
##
## This is NOT an autoload — it is a child of the UI layer in game_ui.tscn.
class_name HeatmapManager
extends Control


## Reference to the GridManager for tile data queries.
var _grid_manager: GridManager

## The Image used as the data texture (updated each frame when active).
var _data_image: Image

## The ImageTexture bound to the heatmap shader.
var _data_texture: ImageTexture

## SubViewport for the heatmap overlay.
var _sub_viewport: SubViewport

## ColorRect with the heatmap shader inside the SubViewport.
var _heatmap_rect: ColorRect

## Current grid dimensions (width, height in tiles).
var _grid_width: int = 0
var _grid_height: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


## Initialize with a GridManager reference and grid dimensions.
func initialize(grid_manager: GridManager, grid_width: int, grid_height: int) -> void:
	_grid_manager = grid_manager
	_grid_width = grid_width
	_grid_height = grid_height
	_setup_viewport()
	_setup_heatmap_rect()

	# Listen for heatmap toggle.
	EventBus.heatmap_toggled.connect(_on_heatmap_toggled)


## Create the SubViewport for the heatmap overlay.
func _setup_viewport() -> void:
	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "HeatmapViewport"
	_sub_viewport.size = Vector2i(_grid_width * 4, _grid_height * 4)
	_sub_viewport.transparent_bg = true
	add_child(_sub_viewport)

	# Cover the full parent area.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Create the ColorRect with the heatmap shader inside the SubViewport.
func _setup_heatmap_rect() -> void:
	_heatmap_rect = ColorRect.new()
	_heatmap_rect.name = "HeatmapColorRect"
	_heatmap_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_viewport.add_child(_heatmap_rect)

	# Create the data texture.
	_data_image = Image.create(_grid_width, _grid_height, false, Image.FORMAT_R8)
	_data_image.fill(Color(0, 0, 0, 0))  # Start with all zeros.
	_data_texture = ImageTexture.create_from_image(_data_image)

	# Load and apply the heatmap shader.
	var shader := load("res://assets/shaders/heatmap_overlay.gdshader") as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("data_texture", _data_texture)
		mat.set_shader_parameter("intensity", 1.0)
		mat.set_shader_parameter("opacity", 0.5)
		_heatmap_rect.material = mat


## Called when the heatmap mode is toggled.
func _on_heatmap_toggled(mode: String, active: bool) -> void:
	if active:
		_update_data(mode)
		show()
	else:
		hide()


## Update the data texture with current tile values for the given mode.
func _update_data(_mode: String) -> void:
	if _grid_manager == null:
		return

	# Resize image if needed.
	if _data_image.get_width() != _grid_width or _data_image.get_height() != _grid_height:
		_data_image = Image.create(_grid_width, _grid_height, false, Image.FORMAT_R8)
		_data_texture = ImageTexture.create_from_image(_data_image)
		if _heatmap_rect.material is ShaderMaterial:
			_heatmap_rect.material.set_shader_parameter("data_texture", _data_texture)

	# For now, fill based on owned tiles (density placeholder).
	# TODO Phase 7: Replace with actual visitor density / zone viability data.
	var fg := _grid_manager.get_floor_grid()
	if fg == null:
		return

	for x in range(_grid_width):
		for y in range(_grid_height):
			var tile := fg.get_tile(x, y)
			if tile != null and tile.owned:
				# Placeholder: owned tiles get a base value.
				# Future: map actual heatmap data per mode.
				_data_image.set_pixel(x, y, Color(0.5, 0, 0, 0))
			else:
				_data_image.set_pixel(x, y, Color(0, 0, 0, 0))

	_data_texture.update(_data_image)


## Refresh the heatmap data (called from GameManager or per-frame).
func refresh() -> void:
	if visible and not GameManager.active_heatmap.is_empty():
		_update_data(GameManager.active_heatmap)
