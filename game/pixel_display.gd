extends Node

## Renders the 3D world at a 640x360 internal resolution and upscales it with
## nearest-neighbor filtering for a chunky pixel-art look. The HUD/inventory
## panel stay outside the low-res SubViewport so on-screen text stays
## legible — a common pattern for "pixel-art 3D" games: only the world gets
## the retro treatment, not the UI. GameManager itself is unaware of any of
## this; it just gets handed a ui_root to attach its CanvasLayers to instead
## of attaching them to itself (see GameManager.ui_root).

const RENDER_WIDTH := 640
const RENDER_HEIGHT := 360
@export var persist_sessions := true

func _ready() -> void:
	var world_viewport := SubViewport.new()
	world_viewport.size = Vector2i(RENDER_WIDTH, RENDER_HEIGHT)
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d = Viewport.MSAA_DISABLED

	var world_layer := CanvasLayer.new()
	world_layer.layer = 0
	add_child(world_layer)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_layer.add_child(container)
	container.add_child(world_viewport)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)

	var game := GameManager.new()
	game.save_enabled = persist_sessions
	game.ui_root = ui_layer
	world_viewport.add_child(game)
