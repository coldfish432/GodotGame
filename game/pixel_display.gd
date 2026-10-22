extends Node

## Renders the 3D world in its own SubViewport, with the HUD/inventory panel
## outside it. It used to render at 640x360 and upscale 2x nearest for a
## chunky pixel look; the world now renders at the window's resolution with
## MSAA and FXAA (场景渲染统一改造案_v1 §4.1, 用户 2026-10-20: 角色用烘焙像素图，
## 场景用原始建模) — the characters keep their pixel sprites, the scene is drawn
## whole. GameManager itself is unaware of any of this; it just gets handed a
## ui_root to attach its CanvasLayers to instead of attaching them to itself
## (see GameManager.ui_root).

const RENDER_WIDTH := 1280
const RENDER_HEIGHT := 720
@export var persist_sessions := true

func _ready() -> void:
	var world_viewport := SubViewport.new()
	world_viewport.size = Vector2i(RENDER_WIDTH, RENDER_HEIGHT)
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d = Viewport.MSAA_4X
	world_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

	var world_layer := CanvasLayer.new()
	world_layer.layer = 0
	add_child(world_layer)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = 1
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	# Title, loading and settings only in the real game; tests instantiate this
	# scene under their own SceneTree and go straight in.
	if get_tree().current_scene == self:
		var system_layer := CanvasLayer.new()
		system_layer.layer = 30
		add_child(system_layer)
		var screens := SystemScreens.new()
		screens.game = game
		system_layer.add_child(screens)
		game.system_screens = screens
		screens.show_title()
