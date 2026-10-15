# 龙门下城区城市贴图 C1–C9

按仓库根目录的 `城市贴图美术需求_v1.md` 制作。九张交付 PNG 均放在本目录，
每张旁边有同名 `_tile_3x3.png` 平铺预览；`final_contact.png` 是总览。

| 编号 | 交付图 | 尺寸 | 颜色数 |
|---|---|---:|---:|
| C1 | `city_road.png` | 256×256 | 8 |
| C2 | `city_pavement.png` | 128×128 | 8 |
| C3 | `city_wall.png` | 256×256 | 9 |
| C4 | `city_block_ground.png` | 256×256 | 10 |
| C5 | `city_roof.png` | 256×256 | 9 |
| C6 | `city_plaster.png` | 256×256 | 9 |
| C7 | `city_corrugated.png` | 128×128 | 10 |
| C8 | `city_shutter.png` | 128×128 | 11 |
| C9 | `city_signs.png` | 512×256 | 12 |

C9 是 4×2 格、每格 128×128。阅读顺序：茶餐廳、藥房、當舖、五金、
押、涼茶、旅館、電器。其 3×3 预览重复整个图集，仅供检查。

九张图的绘制源图在 `source_paintings/`。C2 与 C5 还保留了初稿，
便于检查修小缺角和落水口的改动。精确生成提示词在
`generation_prompts.txt`。`build_city_textures.py` 将绘制源图按
42.67 px/m 缩放、限制到需求调色板、修正 C1–C8 四边、生成预览与
`manifest.json`。C7 的来源锈色区域在最终图中占 34.98%。

复现及静态检查：

```powershell
python art/kit/textures/painted/build_city_textures.py
python art/kit/textures/painted/validate_city_textures.py
```

`validation.json` 记录尺寸、颜色数、边缘像素、平均亮度及锈色比例。
全部 PNG 完整，C1–C8 四边像素匹配，预览是对应原图的精确 3×3
复制；C1 与 C4 的平均亮度均低于 C2。3×3 预览也已人工查看。

C1–C4 由已有 `FieldArt` / `CliffFace` 贴图位读取。Godot 4.7.2
无界面编辑器已导入新 PNG，随后 `ResourceLoader.exists` / `load`
对 C1–C4 四个路径均成功并返回正确尺寸。该机器的系统证书库读取、
编辑器设置或日志写入曾报环境权限错误，未影响四张贴图加载。
C5–C9 仍需按需求文档在 Blender 中重烘焙楼体；场景截图和运行时
观感尚未验证。
