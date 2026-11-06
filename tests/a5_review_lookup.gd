extends SceneTree
## A5 (agent-written): the lookups behind the MATERIALS.md review. Prints each
## integer enum the audit names, from the engine's own constants, and each
## texture's loaded format from get_image().get_format().

func _initialize() -> void:
	print("ENUM Environment.TONE_MAPPER LINEAR ", Environment.TONE_MAPPER_LINEAR, " REINHARDT ", Environment.TONE_MAPPER_REINHARDT, " FILMIC ", Environment.TONE_MAPPER_FILMIC, " ACES ", Environment.TONE_MAPPER_ACES, " AGX ", Environment.TONE_MAPPER_AGX)
	print("ENUM Environment.BG CLEAR_COLOR ", Environment.BG_CLEAR_COLOR, " COLOR ", Environment.BG_COLOR, " SKY ", Environment.BG_SKY)
	print("ENUM Environment.AMBIENT_SOURCE BG ", Environment.AMBIENT_SOURCE_BG, " DISABLED ", Environment.AMBIENT_SOURCE_DISABLED, " COLOR ", Environment.AMBIENT_SOURCE_COLOR, " SKY ", Environment.AMBIENT_SOURCE_SKY)
	print("ENUM Environment.REFLECTION_SOURCE BG ", Environment.REFLECTION_SOURCE_BG, " DISABLED ", Environment.REFLECTION_SOURCE_DISABLED, " SKY ", Environment.REFLECTION_SOURCE_SKY)
	print("ENUM Image.FORMAT L8 ", Image.FORMAT_L8, " RGB8 ", Image.FORMAT_RGB8, " RGBA8 ", Image.FORMAT_RGBA8, " RGTC_RG ", Image.FORMAT_RGTC_RG, " BPTC_RGBA ", Image.FORMAT_BPTC_RGBA)
	print("ENUM Shader hint for sampler2D (PROPERTY_HINT_RESOURCE_TYPE) ", PROPERTY_HINT_RESOURCE_TYPE, " PROPERTY_HINT_RANGE ", PROPERTY_HINT_RANGE, " PROPERTY_HINT_NONE ", PROPERTY_HINT_NONE)
	for p in ["res://textures/cargo_panel/rusty_metal_sheet_diff_1k.png", "res://textures/cargo_panel/rusty_metal_sheet_rough_1k.png",
			"res://textures/cargo_panel/rusty_metal_sheet_nor_gl_1k.png", "res://textures/cargo_panel/rusty_metal_sheet_nor_dx_1k.png",
			"res://textures/cargo_panel/rusty_metal_sheet_nor_dx_1k_inverty.png", "res://textures/hint_experiment/greys_3x1.png"]:
		var img := (load(p) as Texture2D).get_image()
		print("FORMAT ", p.get_file(), " ", img.get_format(), " mipmaps ", img.has_mipmaps(), " bytes ", img.get_data().size())
	quit(0)
