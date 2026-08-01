# head_pat_refuse direct-frame contract

## Output

- Action: 拒绝摸头；察觉触碰后克制地避开，并用一只手在帽檐/脸侧形成明确阻止姿势，随后恢复站姿。
- Facing and camera: 正面、固定正交相机；头部只允许轻微转向画面右侧。
- Duration, FPS, and frame count: 约 2.3 秒，10 FPS，计划 23 帧。
- Loop or segments: one-shot，`neutral -> notice -> avoid -> block/hold -> lower -> neutral`。
- Generation size and final cell: 每帧独立生成 1024×1024，统一转为固定 512×512 RGBA cell。
- Pivot and baseline policy: pivot `(256, 492)`；双脚、鞋底和根节点固定；baseline lock 开启。
- Production state: `motion_smoothing_repair_pending_user`

## Authorities

- Design authority: `../character-reference/model-sheet.png`
- Standing proportion authority: `../return_wave/anchors/reason_pose_frame_000_chroma.png` 与 `../return_wave/frames/frame_000.png`
- Additional pose-family authorities: 无；全程属于站立姿势族。
- Authority rule: 时间邻帧只控制动作、接触和运动方向，不得替代设计或比例权威。

## Identity and material locks

- Head and face: 锁定大而圆的头脸、固定刘海与脸宽；只允许视线、眼睑、眉毛和小幅头转变化。
- Body and limb proportions: 保持约四头身、身体厚度、短而有分量的腿、手掌尺寸、肩宽及裙摆体积，不得变瘦或拉长。
- Hair palette and highlight level: 暗哑灰米色，沿用原件克制高光；禁止变亮、漂白或积累条纹/摩尔纹。
- Garment topology and landmarks: 深蓝贝雷帽、奶油色领、橙色结、三枚铜扣、袖口、蕾丝裙边、袜口和鞋型全部固定。
- Shoes and ground contact: 两脚平行站立，间距、鞋底 y、脚尖朝向全程固定。
- Accessories and companion objects: 斜挎带路线不变；画面右侧包和唯一一只兔子固定，不触碰、不遮挡、不复制、不变形。
- Line, shading, texture, camera, and light: 沿用模型锁的细深色线条、柔和克制赛璐璐阴影、固定正面相机与中性光。

## Action arc

| Beat | Frame or range | Pose family | Motion and expression | Contact and occlusion |
|---|---:|---|---|---|
| neutral reference | 0 | standing | 中性站姿；仅作开端比例与恢复目标 | 胸前右手持包带；另一手自然垂在包旁但不触兔子 |
| notice | 1–4 | standing | 视线捕捉触碰，眼神变冷，眉心轻收；身体与双脚不动 | 无外部手；包带和兔子不动 |
| avoid and release strap | 5–8 | standing | 头部向画面右侧逐步避开约 5–7°，下巴微收；画面左侧手指松开包带并开始抬起 | 手离开包带后，带子仍保持原路线与张力观感 |
| raise and block | 9–13 | standing | 肘部贴近身体，前臂逐帧抬至画面左侧帽檐/脸侧；手掌斜向外上方形成克制阻止 | 手可轻触帽檐边缘或停在脸侧前方，不遮住整张脸 |
| refusal press and release | 14–16 | standing | 帽檐旁做一次很小的向外阻止动作，随后手腕回收并开始下降；不是招呼挥手 | 手始终靠近脸侧，不大幅横扫，不穿过脸或帽子 |
| lower | 17–20 | standing | 手从脸侧下降至胸前包带，头部与视线逐渐回正 | 手沿身体外侧下降，不穿过领口、包带、包或兔子 |
| recovery | 21–22 | standing | 手重新握住包带，头脸与视线回到克制中性站姿 | 恢复原持带关系；包和兔子始终不动 |

## Contact ledger

| Object | Count and side | Attachment or owner | Contact points | Occlusion order | Allowed secondary motion |
|---|---|---|---|---|---|
| 贝雷帽 | 1，头顶 | 角色佩戴 | peak 时右手可轻触画面左侧前帽檐，或在其前方停住 | 手/袖在帽檐与脸前，不能完全遮脸 | 仅极小帽檐受力，不允许帽子移位 |
| 斜挎带 | 1，左肩至画面右侧包 | 肩部与包连接 | notice 时右手持带；avoid 时释放；recovery 时重新持带 | 带子始终在裙身前，手指恢复时包住带子 | 不允许改线、断裂、镜像或漂移 |
| 挎包 | 1，画面右侧 | 斜挎带 | 本动作无手部接触 | 位于裙身前侧，兔子在包前 | 只允许几乎不可见的惯性响应 |
| 兔子 | 1，画面右侧包前 | 包上固定/依附 | 本动作无手部接触 | 始终在包前且耳朵数量固定 | 不允许主动动作、放大、变脸或复制 |

## Motion boundary

- Allowed motion: 眼神、眼睑、眉毛、轻微头转/下巴回收；右肩、右肘、右腕和手指；极小袖褶响应。
- Forbidden changes: 不绘制外部人的手；不挥打、不跳跃、不碰包或兔子；不使用护包式胸前挡手；不改变双脚、根节点、比例、服装拓扑、包带路线、发色亮度、相机、光线或背景。
- Intentional holds and timing metadata: peak 的冷淡阻止姿势以单帧时长表达短暂停顿，不用多张近似漂移图制造 hold。
- Segment seams to inspect: neutral→notice、avoid→block、block→lower、recovery→neutral；尤其检查右手不穿过脸、帽檐或包带。

## Key approval gate

- Planned key poses: 已验收四张关键姿势，分别映射为 `F04 notice`、`F08 avoid`、`F13 block_peak`、`F18 lower`；站立比例权威继续只读。
- Key contact sheet: `key-qa/head_pat_refuse-key-contact-sheet.png`
- Automated key report: `key-qa/key-qa-report.json` — `PASS`
- User verdict and date: `accepted_2026-07-30`；用户要求提升至二十多帧并提高时间精度。
- Approved keys are frozen: `yes`

## Full-sequence gate

- User feedback: first 23-frame preview rejected on `2026-07-30` as “有点过于鬼畜”；F07、F09、F11–F12、F15–F17、F19–F20 were redrawn as complete frames to remove hand-path reversals and pose snaps.
- Generic QA report: `qa/qa-report.json` — `PASS` after smoothing repair
- Local identity/material report: `qa/local-identity-report.json` — `PASS` after smoothing repair
- Target-FPS preview: `qa/preview-target-10fps.gif`
- Slow preview: `qa/preview-slow-5fps.gif`
- One-shot contextual preview: `qa/preview-one-shot-context.gif`
- One-shot contextual slow preview: `qa/preview-one-shot-context-slow.gif`
- Timing report: `qa/timing-report.json`
- Close-up identity/contact sheet: `qa/local-identity-contact-sheet.png`
- Motion transition sheet: `qa/motion-transition-sheet.png`
- User verdict and date: pending
- Ready for engine integration: `no`
