# head_pat_accept direct-frame contract

## Output

- Action: 接受摸头的专用 one-shot；从中性站姿察觉触碰，克制地侧倾迎合，闭眼短暂停留，再略有不舍地恢复中性。
- Facing and camera: 正面、固定正交相机、完整全身、无透视变化。
- Duration, FPS, and frame count: 约 2.1 秒，8 FPS，17 帧；中央停留通过帧时长表达，不制造多张近似漂移图。
- Loop or segments: 非循环 one-shot；`notice 0-3`、`accept 4-7`、`hold 8-10`、`release 11-13`、`recover 14-16`。
- Generation size and final cell: 每帧独立以 1024×1024 生成，统一转为固定 512×512 RGBA cell；禁止逐帧裁切。
- Pivot and baseline policy: 固定 pivot `(256, 492)`，双脚原位，visible baseline 锁定在中性站姿基线附近。
- Production state: `full_sequence_ready_for_user_review`

## Authorities

- Design authority: `../character-reference/model-sheet.png` 与 `../character-reference/identity-lock.json`，只读。
- Standing proportion authority: `../return_wave/anchors/reason_pose_frame_000_chroma.png`。
- Neutral temporal endpoint: `../return_wave/frames/frame_000.png`。
- Rhythm-only legacy reference: `../../skins/little-chihiro/animations/head_pat/`；只允许参考节奏，不得作为身份、比例或表面权威。
- Additional pose-family authorities: 无；全程保持同一站立比例族。
- Authority rule: 时间邻帧只控制动作方向、间距与表情弧线，绝不替代设计或比例权威。

## Identity and material locks

- Head and face: 大而圆的头脸、固定刘海分束与面部宽高；只允许视线、眼睑、最多约 4° 的轻微侧倾与极小闭口微笑变化。
- Body and limb proportions: 约四头身、身体厚度、肩宽、裙摆宽度、腿粗、袜筒与鞋尺寸固定；禁止变瘦、拉长或缩头。
- Hair palette and highlight level: 暗哑灰米色短发，沿用原件低亮度高光；禁止发白、发金、发亮或累积纹理噪声。
- Garment topology and landmarks: 深海军蓝贝雷帽与后方暗绿蝴蝶结、奶油色圆领、橙色领结、三枚黄铜前扣、长袖、腰线与蕾丝裙边均固定。
- Shoes and ground contact: 奶油色及膝袜、黑色玛丽珍鞋、两脚间距与鞋底接触点全程固定。
- Accessories and companion objects: 斜挎带路线、观者右侧挎包、单只白兔与橙色兔结保持数量、大小、侧别、连接和遮挡关系不变。
- Line, shading, texture, camera, and light: 细暗线、克制暖色软赛璐璐、平滑深色布料、固定正面相机和中性光；无条纹噪声、摩尔纹或逐帧色调漂移。

## Action arc

| Beat | Frame or range | Pose family | Motion and expression | Contact and occlusion |
|---|---:|---|---|---|
| neutral endpoint | 0 | standing | 中性站姿，作为动作起点 | 不绘制外部手；包带、包和兔子保持原有层级 |
| notice | 1-3 | standing | 视线略向上聚焦，眼睑与眉形轻微回应，头部仍接近中正 | 想象中的触点位于贝雷帽顶部，不出现任何外部物体 |
| accept approach | 4-7 | standing | 下巴微收，头部向观者左侧轻倾，肩线只做极小顺应 | 帽子不脱落、不变形；双手仍维持中性归属 |
| held soft reaction | 8-10 | standing | 眼睛柔和闭合，嘴角极小闭口放松，头倾达到峰值后稳定 | 用时长表达停留，不绘制手、爱心或特效 |
| reluctant release | 11-13 | standing | 眼睛半开，头部开始回正，神情有极轻的迟疑但不幼儿化撒娇 | 包与兔子仅允许极小随动，拓扑不变 |
| recovery | 14-16 | standing | 头、视线与表情回到同一中性站姿 | 最终端点与起点自然衔接，不循环 |

## Contact ledger

| Object | Count and side | Attachment or owner | Contact points | Occlusion order | Allowed secondary motion |
|---|---|---|---|---|---|
| invisible cursor pat | 不绘制 | 桌面交互输入，不属于画面对象 | 贝雷帽顶部的想象触点 | 无可见遮挡 | 仅驱动头倾、眼睑和微表情 |
| beret | 1，头顶 | 固定在头发上 | 随头部整体运动，不相对滑移 | 帽檐在刘海前，后结位于头后 | 极小整体倾斜，禁止变形或位移脱落 |
| cross-body strap | 1，斜跨胸前至观者右侧包 | 观者左侧手维持原有轻握 | 胸前、腰侧与包口连接连续 | 始终位于裙身前，手指自然覆盖一小段 | 仅允许随呼吸与头倾产生的极小响应 |
| satchel | 1，观者右侧 | 挂在斜挎带末端 | 贴近裙侧 | 在裙身前，兔子在包前 | 最多极小摆幅，禁止放大、镜像或脱离 |
| rabbit | 1，观者右侧包前 | 固定在包上 | 兔身与包前连接稳定 | 兔子在包前、手臂后或旁侧 | 耳朵可有极小滞后，禁止复制、变脸或脱落 |

## Motion boundary

- Allowed motion: 视线、眼睑、眉形、极小闭口微笑、下巴轻收、头部观者左倾不超过约 4°、肩部极小顺应，以及帽子、发梢、包和兔子的微弱次级响应。
- Forbidden changes: 外部人的手或手臂、挥手、双手离位、跨步、屈膝、身体弹跳、大幅撒娇、张嘴笑、夸张红晕、爱心/粒子；以及任何身份、比例、服装、配件、颜色、材质、相机和光照变化。
- Intentional holds and timing metadata: `frame_009` 为闭眼迎合峰值，可在引擎中延长显示；不以复制相似画面制造停留。
- Segment seams to inspect: `3→4` 察觉到迎合、`7→8` 进入闭眼停留、`10→11` 离开停留、`13→14` 进入恢复、`16→idle` 回到中性。

## Key approval gate

- Planned key poses: AUTH-neutral；K07 轻倾迎合；K09 闭眼停留峰值；AUTH-neutral-return。K03 察觉和 K13 迟疑恢复降级为关键姿势验收后、由两端约束生成的 direct slots。
- Key contact sheet: `key-poses/head_pat_accept-key-contact-sheet-v2.png`
- Automated key report: `key-qa-v2/automated/qa-report.json` — PASS；局部报告 `key-qa-v2/local-identity-report.json` — PASS。
- User verdict and date: 用户于 2026-07-30 回复“继续吧”，明确授权通过修正后的核心关键姿势门并进入 direct-frame 生产。
- Approved keys are frozen: `yes` — K07、K09 与两端 AUTH 不再重画。
- Selected sources: `k07_accept_chroma.png`、`k09_hold_chroma.png`。
- Revision audit: 用户指出接触表存在明显比例跳变后，K03 的全部候选与 K13 的全部候选均撤出关键参考链；它们被隔离在 `key-poses/rejected-candidates/`。K07/K09 作为同一站立动作族的比例母帧，K03/K13 只会在其两端都获准后以 direct-frame 方式重新生成。
- Source normalization note: 内置 image generation 返回 1254×1254 原图；完整画布先统一缩放为 1024×1024 production source，再以同一个 whole-drawing scale 输出 512×512。仅做整张 sprite 的脚底/pivot 平移，不做逐帧缩放、局部变换或部件合成。

## Full-sequence gate

- Generic QA report: `qa/qa-report.json`
- Local identity/material report: `qa/local-identity-report.json`
- Target-FPS preview: `qa/preview.gif`
- Slow preview: `qa/preview-slow.gif`
- Close-up identity/contact sheet: `qa/local-identity-contact-sheet.png`
- Automated result: 通用 QA `PASS`；局部身份/材质数值 QA `PASS`；人工语义预检 `PASS`。
- Revision audit: 首轮完整序列检查发现 F06 眼睑提前闭合并在 F07 反向睁开；该帧已隔离并以 `frame_006_v4` 重画。修正版在 F05→F06→F07→F08→F09 间保持单调收眼，同时继续满足固定比例阈值。
- User verdict and date: pending
- Ready for engine integration: `no`
