// Terrace kit pieces with baked textures (tools/blender/kit): the bake already
// holds colour and ambient occlusion; the scene's lights shade it
// (场景渲染统一改造案_v1 S3).
shader_type spatial;
render_mode cull_back;
#include "res://world/kit_piece.gdshaderinc"
