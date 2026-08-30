# 《异视·黄昏事务所》配音 / CG视频 / 构建发布 流程规范

> **最后更新**：2026-08-30
> **适用**：TapTap Maker MCP + UrhoX Lua 引擎
> **配套文档**：图像生成见 `docs/ai-image-prompts.md`；引擎坑见 `.codebuddy/memory/MEMORY.md`

---

## 〇、三条链路总览

| 链路 | 产物 | 关键约束 |
|------|------|----------|
| **角色配音** | `.project/elevenlabs-voice-mapping.json` + `assets/audio/voice/*.ogg` | 一个角色走完 audition→confirm 才能做下一个；**不可并行** |
| **CG 视频** | `assets/image/cg2_shot*.png` → `assets/video/*.mp4` | Seedance **并发上限 1/1**，必须串行 |
| **构建发布** | 远端构建 + runtime.log | 构建前必须 `git pull --ff-only`，否则被 `needs_pull` 阻塞 |

---

## 一、角色配音流程（ElevenLabs Voice Design）

### 1.1 完整步骤

```
① 读立绘 → ② audition_voices_for_character → ③ 用户试听选音色
   → ④ confirm_character_voice → ⑤ text_to_dialogue 逐句渲染
   → ⑥ 登记进 VoiceSystem.voiceTable
```

### 1.2 各步硬性要求

**② audition 试听**

| 参数 | 要求 |
|------|------|
| `candidate_count` | **必须设 `1`**。设为 3（默认值）必定 MCP -32001 超时，且**超时≠已提交**（无任务、无产物） |
| `character_description` | 英文，覆盖 年龄/性别/音色/语速/情绪/风格/录音质量 |
| `audition_line` | **≥100 字符**，且必须贴合角色说话风格 |

**④ confirm 确认**

- 每调一次**消耗 1 个 ElevenLabs Voice Slot**，不可逆
- **不可并行**；`selected_index` 省略则用推荐候选
- 确认后音色持久化，`text_to_dialogue` 传 `character_name` 自动复用，**无需再传 voice_id**

**⑤ text_to_dialogue 渲染**

- 一次调用 = 一个音频文件；`inputs` 数组用于多角色对话合入同一文件
- 逐句调用（每句一个文件），游戏才能按打字机节奏逐句播
- 命名：`output_name` + `_1_` + voiceHash + `.ogg`

### 1.3 ⚠️ 安全审核拦截（已踩 2 次）

description 或 audition_line 含以下内容会被 **403 `blocked_generation`**：

- **未成年人具体年龄 + 疾病/脆弱/失语**等表述（陈雯音前两次失败）
- **窒息 / 喉咙 / 死亡**类字眼（周文初稿失败）

**解法**：改中性表述。

```diff
- A girl around 12 years old... fragile, breathy, barely used, childhood fever
+ A clear, light, gentle young female voice... calm and reserved
```

### 1.4 音频格式（重要）

- Maker 接口报 `ogg_opus`，但 **ffprobe 实测是 Vorbis / 44.1kHz / 单声道**
- Urho3D 的 `LoadOggVorbis` **可直接解码，不需要 ffmpeg 转码**
- 落盘路径：`assets/audio/voice/{output_name}_1_{voiceHash}.ogg`

### 1.5 已确认音色表

| 角色 | voiceId | 文件哈希 | 音色定位 |
|------|---------|----------|----------|
| LiZhi 李志 | `aGRdbNHXW05mMlCkLb2o` | `96d00e9b7ef61b68` | 暖中低音，微沙哑，松弛自嘲，转严肃压低 |
| ChenWenyin 陈雯音 | `J7xVlOIVntXu03bSpLxP` | — | 轻柔中高音，安静内向 |
| XuQinglan 许晴岚 | `z710sHcPP4Jz9mLxawYF` | — | 明亮中高音，语速快、毒舌干练 |
| YanChengfeng 严成峰 | `XQIYgL9ckUWh8X2r7dLQ` | — | 低沉胸腔共鸣，威严傲慢，带哮喘气声 |
| ZhaoHeng 赵恒 | `yP8bfZaoLUjuGPVpQeLM` | — | 圆滑油润，紧张时结巴 |
| ZhouWen 周文 | `FxiOGcqJEHkEcnpzFAFu` | — | 冷静克制平板，压抑怒意 |
| ZhangChengyu 张承宇 | `c3GmFOuRVKVLdm11f9Ru` | — | 粗粝爽朗低音，嘴硬心软刑警 |
| **LiZhiSister 姐姐** | `8Zkf7Sh9gZEve0ImTNit` | `75428c8194d8c22f` | 干练爽快，语速快 |
| **NewsAnchor 新闻** | `NUqzMfbW4Zw0zsDorHiC` | `377667b6ea69f8d7` | 标准机械播报女声 |

> 次要角色尚未配音：FrontDesk / PanganEmployee / PoliceA / Forensic / WaiterA / Guard

---

## 二、配音接入游戏（VoiceSystem）

### 2.1 架构

```
DialogueSystem.Start      → 记录 M.state.dialogueId（仅 string，table 时为 nil）
DialogueSystem.StartLine  → VoiceSystem.Play(dialogueId, lineIndex)
DialogueSystem.End / Stop → VoiceSystem.Stop()
```

播放实现（`scripts/VoiceSystem.lua`）：

```lua
M.node = Node()
M.source = M.node:CreateComponent("SoundSource")
M.source.soundType = SOUND_VOICE
M.source:Play(cache:GetResource("Sound", path))
```

**全部音频操作用 `pcall` 包裹** —— 配音失败最多没声音，绝不能让游戏崩。

### 2.2 扩展新台词配音

1. `text_to_dialogue` 生成音频，`output_name` 自定义（如 `c1_lobby_3`）
2. 在 `VoiceSystem.lua` 的 `HASH` 表登记新角色哈希（若新角色）
3. 在 `voiceTable` 按 `{ [行号] = v("output_name", HASH.角色) }` 追加
4. 行号 = CSV 的 `line_no`（**1-based**）

```lua
M.voiceTable = {
    ["c1_lobby_talk"] = {
        [3] = v("c1_lobby_3", HASH.LiZhi),
    },
}
```

未登记的行静默跳过，不影响对话。

### 2.3 ⚠️ 配音生效的前提

**该段对话必须经过 `DialogueSystem`**。

> **2026-08-30 决策 B**：序章曾改用 `VideoCGSystem` 播 CG 视频，导致 `opening_prologue_1~5`
> 绕过 `DialogueSystem`，19 句配音全部听不到。现改回 `OpeningSystem.Start("prologue", ...)`。
>
> 同理，若某段对话改用其他播放方式（CG / 旁白 / 直接播音频），配音会**静默失效**。

另一个前提：`DialogueSystem.Start` 必须收到 **id 字符串**。若传 table，
`M.state.dialogueId` 为 nil，配音不播（`OpeningSystem.lua:407` 目前传的是字符串 ✅）。

---

## 三、CG 视频生成流程（Seedance）

### 3.1 步骤

```
① 首帧图（image_gen 或 edit_image）
② create_video_task（mode="first_frame"，串行）
③ query_video_task 轮询（间隔 ≥120s）
④ ffmpeg concat -c copy 拼接
```

### 3.2 参数与坑

**① edit_image 重绘首帧**

- **prompt 要短**：长 prompt + `target_size 1935x1080` 会 MCP 超时
- 稳定配置：`resolution:"1K"` + `target_size:"1280x720"` + 一句话 prompt
- ⚠️ **超时≠失败**：`cg2_shot1` 首次超时但实际已落盘，重试产生第二份文件。**超时后先查目录再决定是否重试**

**② create_video_task**

| 项 | 值 |
|----|-----|
| `mode` | `first_frame`（1 张图） |
| `model` | `2.0`（4-15s） |
| `duration` | 明确整数秒，勿用 -1 |
| `resolution` / `ratio` | `720p` / `16:9` |
| 首帧图 | ≤ 30 MiB |
| 积分 | 约 1204 / 段（10s 720p） |

- **首次调用必超时，但任务已提交**；紧接着再调一次会报「并发超限 1/1」并**返回 task_id**
- **并发上限 1/1，多段必须串行**

**③ query_video_task**

- 间隔 **≥120 秒**才轮询，不要连续刷
- 查询已完成的任务会**释放配额**
- 成功后本地落盘到 `assets/video/`

**④ ffmpeg 拼接**

```bash
# 列表放 assets/video/ 时，file 写纯文件名
# ⚠️ concat demuxer 的相对路径是相对【列表文件所在目录】，不是 cwd
ffmpeg -f concat -safe 0 -i list.txt -c copy assets/video/opening_cg.mp4
```

### 3.3 ⚠️ 角色一致性

首帧角色形象**必须对齐立绘**。本项目踩过：5 张首帧里李志穿条纹衬衫+牛仔裤，
而立绘 `char_lizhi.png` 是**黑短袖T恤+短裤+拖鞋**，全部重绘。

**检查清单**：出图后逐张比对 → 脸型 / 发色发型 / 服装 / 配色。

### 3.4 当前资产状态（2026-08-30）

- 首帧 `cg2_shot1~5_*.png`：李志已改为黑T恤+短裤 ✅
- 视频：**4/5 段**完成（第 5 段未生成）
- `opening_cg.mp4`：**仍是旧版，未重新拼接**（序章已不用 CG）
- `main.lua` 的 `openingSubtitles` 表保留未删，切回 CG 模式可直接复用

---

## 四、构建发布流程

### 4.1 标准步骤

```bash
git add -A
git commit -m "..."        # ⚠️ PowerShell 中文会乱码，用英文 message
git pull --rebase origin main
```

然后调用 `maker_build_current_directory`：

```jsonc
{
  "target_dir": "...",
  "entry": "main.lua",
  "scriptsPath": "scripts",
  "message": "...",
  "timeout_ms": 600000
}
```

**只传这 5 个字段**，不要塞 `maxOutputLength` 等额外参数（会 -32001 超时）。

### 4.2 ⚠️ 构建踩坑（高频）

| 现象 | 原因 | 处理 |
|------|------|------|
| MCP -32001 超时 | 构建耗时超客户端超时 | **push 通常已成功**。查 `git log origin/main` 确认，**不要盲目重试** |
| `needs_pull` 阻塞 / behind 1 | 远端回推了含 `.meta` 的同步提交 | `git pull --ff-only origin main` 后重新构建 |
| `409 Conflict` | 构建槽被占用 | 等待，勿重试 |
| 中文 commit 乱码 | PowerShell 编码 | 用英文 message，或用 `-m` 多行 |

### 4.3 验证

构建成功后读运行时日志：

```
d:\...\01_Project\.maker\logs\runtime\runtime.log
```

搜索 `VOICE` 确认配音触发，搜索 `attempt to` / `nil value` / `ERROR` 排查报错。

正常样例：

```
[VOICE] 播放 opening_prologue_1#2 -> assets/audio/voice/prologue_1_2_1_96d00e9b7ef61b68.ogg
```

`UI.Init() called twice` 是引擎既有 WARNING，可忽略。

---

## 五、踩坑速查（按出现频率）

1. **`audition_voices_for_character` 必须 `candidate_count=1`** —— 默认 3 必超时且未提交
2. **ElevenLabs 安全审核** —— 避开儿童年龄+病态、窒息/死亡表述
3. **`create_video_task` 首次必超时但已提交** —— 再调一次拿 task_id
4. **Seedance 并发 1/1** —— 串行，轮询间隔 ≥120s
5. **`edit_image` 超时≠失败** —— 先查目录再重试
6. **构建前必须 pull --ff-only** —— 否则 `needs_pull` 阻塞
7. **`maker_*` 系列别塞多余参数** —— 只传 schema 里声明的字段
8. **音频是 Vorbis 不是 Opus** —— 无需转码，`LoadOggVorbis` 直读
9. **配音必须走 DialogueSystem** —— CG/旁白模式会让配音静默失效

---

## 六、待办

- [ ] 第一~四章台词配音（序章已完成，第一~四章仍为纯文字）
  - 优先级：第一章大堂探索 > 询问环节 > 案发现场
- [ ] 6 位次要角色音色（FrontDesk / PanganEmployee / PoliceA / Forensic / WaiterA / Guard）
- [ ] CG 视频第 5 段 + 拼接（仅当恢复 CG 模式时才需要）
- [ ] 设置项接入 `VoiceSystem.SetEnabled`（开关配音）
