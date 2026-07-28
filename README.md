# Little Chihiro Pet · Godot Native

这是 `little-chihiro-pet-v0.20.0-beta.3` 的原生 Godot 版本。运行时不再使用
Tauri、PixiJS、Node.js、Rust 或 WebView；窗口、渲染、输入、托盘与行为全部由
Godot 4.7/GDScript 承担。

## 已迁移

- 透明、无边框、置顶、不可缩放的 Windows 桌宠窗口
- Godot `StatusIndicator` 原生托盘菜单
- 2D 编辑器内显示待机帧预览，运行时再由逐帧播放器接管纹理
- 原 `pet.json` schema v1，以及 62 组动作、1311 张运行帧
- 自定义逐帧播放器：独立帧时长、片段、倒放、循环与确定性循环变体
- `boot / idle / float / edge_patrol / dragged / drag_fall / land` 等状态机
- 点击、摸头、戳脸、拖拽、急停/反向、直坠与持伞缓降
- 九向注视、距离/角度迟滞、快速扫过、反复横摆和绕圈反应
- A/B 攀墙家族、地面/墙面/顶部飞行、转角、root motion 和降级路线
- 动态 `360 / 424 / 436` 方形渲染箱与边/角停靠
- 位置持久化、自主闲逛开关、光标跟随开关和隐藏/恢复

## 运行

```powershell
godot --path D:\workspace\project-chihiro
```

打开编辑器：

```powershell
godot --editor --path D:\workspace\project-chihiro
```

运行无界面测试：

```powershell
godot --headless --path D:\workspace\project-chihiro --script res://scripts/tests/run_tests.gd
```

安装 Windows export templates 后，可构建单文件版本：

```powershell
godot --headless --path D:\workspace\project-chihiro --export-release "Windows Desktop"
```

## 目录

```text
project.godot
scenes/main.tscn
scripts/main.gd                 # 桌宠运行时与交互编排
scripts/core/                   # 状态机、动画、注视、拖拽、巡逻
scripts/platform/               # Godot DisplayServer/Window 平台层
scripts/tests/run_tests.gd      # 逻辑与资源契约测试
skins/little-chihiro/           # 原 pet.json 与透明 PNG
```

`DesktopWindowBridge.get_system_context()` 留有 Godot 原生扩展挂点，用于后续接入
Win32 外部前台全屏窗口识别；其余桌宠运行路径不依赖平台扩展。
