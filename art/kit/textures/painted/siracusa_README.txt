# 叙拉古 · 沃尔西尼旧城区地面 S1–S2

依据仓库根目录的 `叙拉古贴图美术需求_v1.md`，用内置 imagegen 制作两张
手绘源图，再缩至目标像素密度并压到指定调色板。交付图由
`build_siracusa_textures.py` 从 `source_paintings/` 生成（先前的临时图
生成器已删除）。

| S1 | siracusa_road.png | 256×256 | 11 色 | 浅暖色磨损石灰岩石板 |
| S2 | siracusa_block_ground.png | 256×256 | 12 色 | 深色泥地、草、碎石、红瓦 |

旁边同名 `_tile_3x3.png` 是原图的精确平铺预览。
`manifest.json` 包含尺寸、颜色数、调色板、源图哈希和四边接缝状态；
`validation_siracusa.json` 是静态核验结果。绘制提示词保存在
`siracusa_generation_prompts.txt`。

复现和检查：

    python art/kit/textures/painted/build_siracusa_textures.py
    python art/kit/textures/painted/validate_siracusa_textures.py

实测：两张均为 256×256，源图哈希匹配，颜色属于指定调色板，四边最外层
像素精确相等。S1 平均亮度 157.95，S2 为 89.77。3×3 预览已人工查看。
Godot 4.7.2 的可渲染截图脚本 `tests/capture_siracusa_textures.gd` 已保存
阴天与雨夜各一张到项目上级的 `evidence/`：

    siracusa-texture-overcast-2026.png
    siracusa-texture-rain-523645.png

截图使用固定地图种子，记录的是游戏光照与场景中的实拍画面；最终观感由
用户验收。该机器的 Godot 用户日志、证书和着色器缓存写入报过环境错误，
但两张截图保存结果均为 error 0。
