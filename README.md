# Little Chihiro Pet · Godot Native

这是 `little-chihiro-pet-v0.20.0-beta.3` 迁移后的原生 Godot 版本，当前版本为
`0.21.0-beta.1`。运行时不再使用
Tauri、PixiJS、Node.js、Rust 或 WebView；窗口、渲染、输入、托盘与行为全部由
Godot 4.7/GDScript 承担。

## 已迁移

- 透明、无边框、置顶、不可缩放的 Windows 桌宠窗口
- Godot `StatusIndicator` 原生托盘菜单
- 2D 编辑器内显示待机帧预览，运行时再由逐帧播放器接管纹理
- 原 `pet.json` schema v1，以及 83 组动作、1575 张运行帧
- 自定义逐帧播放器：独立帧时长、片段、倒放、循环与确定性循环变体
- `boot / idle / float / edge_patrol / dragged / drag_fall / land` 等状态机
- 点击、摸头、戳脸、拖拽、急停/反向、直坠与持伞缓降
- 九向注视、距离/角度迟滞、快速扫过、反复横摆和绕圈反应
- A/B 攀墙家族、地面/墙面/顶部飞行、转角、root motion 和降级路线
- 动态 `360 / 424 / 436` 方形渲染箱与边/角停靠
- 位置持久化、自主闲逛开关、光标跟随开关和隐藏/恢复
- `energy / boredom / curiosity / irritation / affection` 五项生命状态与五档关系
- 可复现随机种子的行为评分、最近三次去重、冷却、抢占和动作会话
- 140 条离线中文气泡台词、标题稳定/隐私过滤、最近 12 条去重
- 9 个 CC0 动作音效与独立音效开关
- Win32 C++ GDExtension：窗口枚举、Z 序遮挡、窗口顶边行走/乘坐/掉落/换座
- F10 调试面板：状态、属性、候选分数与当前平台
- 右键或托盘打开“动作总览”：按 16 个生活行为族浏览、搜索、播放和逐帧检查全部动作

## 运行

```powershell
& 'D:\godot\引擎版本\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe' --path 'D:\workspace\project-chihiro'
```

打开编辑器：

```powershell
& 'D:\godot\引擎版本\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe' --editor --path 'D:\workspace\project-chihiro'
```

运行无界面测试：

```powershell
& 'D:\godot\引擎版本\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\workspace\project-chihiro' --log-file 'D:\workspace\project-chihiro\godot-tests.log' --script res://scripts/tests/run_tests.gd
```

当前基线为 `PASS: 245 assertions`。

先构建 Windows GDExtension（详见 `native/windows/README.md`），再安装 Godot
4.7.1 export templates 并导出：

```powershell
& 'D:\godot\引擎版本\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\workspace\project-chihiro' --export-release 'Windows Desktop'
```

输出为 `build/LittleChihiroPet.exe` 与同目录的 Windows GDExtension DLL。

## 目录

```text
project.godot
scenes/main.tscn
scripts/main.gd                 # 桌宠运行时与交互编排
scripts/core/                   # 状态机、动画、注视、拖拽、巡逻
scripts/platform/               # Godot DisplayServer/Window 平台层
scripts/tests/run_tests.gd      # 逻辑与资源契约测试
skins/little-chihiro/           # 原 pet.json 与透明 PNG
data/                           # 行为参数、动作分类与 140 条静态台词
native/windows/                 # Win32 GDExtension 与固定 godot-cpp 子模块
art/animation-production/       # 动画模型锁、动作契约与审核产物
```

动画制作遵循逐动作确认：角色模型锁确认后，先审关键姿势，再生成中间帧，最后审
GIF、接触表和自动 QA 报告。运行时代码对尚未完成的新动画使用现有动作降级，旧动画
目录保持不变。
