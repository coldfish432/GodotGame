# Lappland 八方向像素动画（Godot 4）

## 文件

- `lappland_8dir_walk_4frames.png`：原始图集，888×1776，4 列 × 8 行，每格 222×222，透明背景。每行 4 帧。
- `lappland_8dir_walk_32.png`：**项目实际使用的图集**，128×256，每格 32×32。由原始图集按预乘 alpha 做 BOX 降采样、并把 alpha 阈值化为硬边缘得到。
- `Lappland8DirWalk.tres` / `Lappland8DirWalk32.tres`：SpriteFrames，各含 8 个方向的循环行走动画和对应的单帧待机（`walk_<方向>` / `idle_<方向>`），分别指向上面两张图集。
- `LapplandSpriteAnimator.gd`：**2D 版**驱动脚本（AnimatedSprite2D，父节点为 CharacterBody2D）。本项目是 3D，未使用，保留作参考。
- `lappland_animator_3d.gd`（`LapplandAnimator3D`）：**本项目使用的 3D 版**，AnimatedSprite3D + billboard，父节点为 CharacterBody3D。

方向行顺序：南、南西、西、北西、北、北东、东、南东。动画速度 8 FPS；纹理使用 nearest 过滤。

## 为什么要降采样

图集是高分辨率插画（5 万多种颜色、无像素块对齐），不是真正的像素画。游戏世界渲染在 320×180 的 SubViewport 里（见 `game/pixel_display.gd`），正交相机 size 11，1 世界单位 ≈ 16.36 屏幕像素，主角只占约 30 像素高。把 222×222 的原图缩到这个尺寸再用 nearest 采样会糊成一团并在移动时抖动，所以离线预先缩到每格 32×32，让 1 纹理像素正好对应约 1 个渲染像素。

对应地，`LapplandAnimator3D.PIXEL_SIZE = 0.06`（32 texel × 0.06 ≈ 1.92 世界单位一格，角色约 1.8 单位高），`FOOT_DROP = 0.65` 让精灵底边落在玩家 1.3 高胶囊的底部。想让角色显示得更小/更大就改 `PIXEL_SIZE`，但偏离 0.06 会牺牲 1:1 的像素对应关系。

## 接入方式（downfall-godot）

`entities/player.gd` 的 `_build_visual()` 里把原先程序生成的 `Sprite3D` 换成了 `LapplandAnimator3D.new()`，玩家自己不再手动换帧。

方向选择不是直接用世界坐标：图集的方向是**按屏幕画的**（第 0 行正对镜头），所以脚本把角色的水平速度投影到相机的水平右/前轴上，再换算成 2D 角度取行号。相机偏航若改变，朝向会跟着变而不会错位。转向沿用 2D 版的迟滞 + 逐格转身逻辑（`turn_hysteresis_degrees`、`turn_step_seconds`），攻击时由 `Player.attack()` 调 `face_world_direction()` 临时朝向目标。

注意：billboard 精灵不受节点旋转影响，`Player` 里保留的 `look_at()` 现在只用于计算攻击方向。

## v1 场景与敌人美术接入

2026-09-25：拉普兰德原素材保留。当前世界视口为 640×360（2 倍最近邻放大），相机 size 20；以上旧版 320×180 / size 11 为历史说明。新敌人及场景图集、来源、提示词见 `art/field/`。
