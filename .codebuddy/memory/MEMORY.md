# 项目长期记忆（异视 · 黄昏事务所）

## 项目概况
- **游戏名**：异视（副标题：黄昏事务所）
- **类型**：2D 横板推理游戏（含 meta 元游戏元素）
- **引擎**：UrhoX Lua（代码在 `scripts/`，UI 用 `urhox-libs/UI`）
- **案件**：落晖之宴·严成峰坠亡案

## 设计文档（wolai）
- 基础设计：https://www.wolai.com/3uc1XCmBM6jmyyAnVePCsU （page_id `3uc1XCmBM6jmyyAnVePCsU`）
- 父页面「TAP制造内容」page_id `f5e1DjK54NdmDQQf4HQytz`，含子页面：
  - 第一阶段 page_id `6mPKsvWmZMEikxNZYZDQo2`
  - 第二阶段 page_id `rq5a3Qq3iMv811cKjCET7Z`
- 用 wolai MCP 读取：get_page_outline / get_section_content / get_page_blocks / get_doc

## 剧情结构
- **序章**：黄昏事务所。开场动画（2036-08-12 12:59）→ 新手引导（书柜/衣柜/床铺3对象，点衣柜推进）
- **第一章**：万丽海湾大酒店。开场动画（2036-08-13 09:32）→ 4区域自由探索（1F大堂 / 1F露天庭院 / 25F走廊）
- 角色：李志（侦探）、陈雯音（外甥女，能看到屏幕外的人）、许晴岚、严成峰（死者）、赵恒、周文、张承宇（重案组队长）

## 代码模块（scripts/）
- `main.lua`：主循环、模式管理（Boot/MainMenu/Playing/Paused）、Tab键笔记、ESC暂停、自动存档
- `GameData.lua`：角色/章节/线索（四大分类）/对话/开场动画/场景物件
- `NoteSystem.lua`：侦探笔记（Tab呼出、四大分类、状态机、F标记、红点）
- `OpeningSystem.lua`：开场动画（黑屏时间地点3秒 + 分镜对话）
- `SceneManager.lua` v3：**整图切换多屏场景系统**（screens 模式：翻页按钮 + 小地图 + 新手引导 + 物件交互 + 主角放大站位；parallax 分支保留但已无场景使用）
- `DialogueSystem.lua`：打字机对话（Start 支持字符串id和table）
- `MenuSystem.lua`：主菜单/暂停/存档/读档/设置
- `SaveSystem.lua`：10槽+自动存档（含 readClues/starredClues 笔记状态）

## 关键约定
- 长度单位米、Y-up 左手坐标系
- 屏幕尺寸：`graphics` 是引擎**全局变量**（非模块，勿 `require("Graphics")`，否则 Module not found），可用 `graphics:GetWidth()/GetHeight()/GetDPR()`；`graphics:SetMode()` 已禁用。SceneManager 用它取逻辑分辨率，全局不存在时回退默认 1280x720。
- UI 组件支持 `onPointerEnter`/`onPointerLeave`（签名 `(event, widget)`）、`borderWidth`/`borderColor`、`SetStyle({...})`
- **`SetStyle` 只接受单个 table 参数**，必须写 `widget:SetStyle({ key = value })`，**绝不能**写 `SetStyle("key", value)`——后者会把第一个参数（字符串）当 props 传入 `NormalizeColorProps`，导致 `pairs(string)` 崩溃（`bad argument #1 to 'for iterator' (table expected, got string)`）。改字体颜色用 `SetStyle({ fontColor = {r,g,b,a} })`（table 值范围 0~255，或传 `"rgba(...)"` 字符串引擎会自动 ParseColor）；无 `SetFontColor`/`SetTextColor` 方法（只有 `SetBackgroundColor`/`SetBorderColor` 两个 alias）。颜色属性值既可传 table 也可传 `"rgba(...)"` 字符串。
- **`UI:Init()` 重复调用警告**：`EnterScene` 每次调用 `UI:Init()`，若之前未 `UI.Shutdown()` 会打印 `UI.Init() called twice ... ignored` 警告（非 ERROR，引擎忽略，不影响渲染）。保持现状即可，无需特意加 Shutdown。
- 键盘输入：引擎以**全局变量** `input` 注入（不是模块！勿 `require("Input")`，会报 Module not found 并连带 main.lua 解析失败）。可用方法只有 `input:GetKeyPress(KEY_*)`（按住时每帧返回 true，可当持续状态用）和 `input:GetMouseButtonPress(MOUSEB_*)`。**不存在** `GetKeyDown`、`GetMousePosition`，也没有鼠标移动事件（无 onMouseMove），故鼠标坐标不可得——场景镜头滚动只能用方向键 `KEY_LEFT/KEY_RIGHT`。按键常量 KEY_LEFT/RIGHT/UP/DOWN/ESCAPE/TAB/Q/W/S/F 等为全局。
- Button 文本始终居中（不支持 textAlign）
- **事件驱动主循环**：UrhoX 无 `engine:GetFrameTime()/IsExiting()/FrameNext()`，勿手写 while。用 `Start()` + `SubscribeToEvent("Update","HandleUpdate")`，帧时间取 `eventData["TimeStep"]:GetFloat()`
- **UI 渲染挂载**：必须 `UI.Init({ scale = UI.Scale.DEFAULT })` + `UI.SetRoot(root)` 才会渲染；`Widget:Show()` 仅 SetVisible(true)，需 `UI.GetRoot():AddChild(widget)` 挂到渲染树；`Destroy()` 自动从 parent 移除
- **`Widget:AddChild(child)` 返回 `self`（父节点）用于链式调用，不是 child**！要引用子节点必须 `local x = UI.xxx{...}; parent:AddChild(x)`，绝不能写 `local x = parent:AddChild(...)`（否则 x 指向父节点，缺子类方法如 SetText 会报 nil）
- **美术风格偏好**：用户于 08-25 明确要求**日系二次元动漫风格**（参考图为干净线条+赛璐璐上色+修长比例+暖调低饱和），而非 08-24 批次使用的"现代写实插画"。后续生成图片应统一为此风格。
- **AI图像Prompt文档**：`docs/ai-image-prompts.md`(v2.1 整图切换·多屏循环箱庭版) 含 17 张 Screen + 7 角色 + 5 UI 元素 + 开场背景的完整中文 prompt，可直接用于 `batch_generate_images`。
- **图片资源生成（taptap-maker）**：`batch_generate_images`（2-10张并行）/`generate_image` 下载到 `assets/image/`，文件名**自动加时间戳后缀**（如 `bg_office_20260824xxxx.png`），生成后需 `Rename-Item` 重命名为代码引用名（`bg_office.png` 等）；人物立绘传 `transparent:true` 得透明背景 PNG，`aspect_ratio`/`target_size`/`resolution` 控制画幅。
- **显示图片**：用 `Widget:SetBackgroundImage("assets/image/xxx.png")` 或构造 `backgroundImage = "assets/image/xxx.png"` + `backgroundFit`（"fill"/"contain"/"cover"）+ `backgroundImageOpacity`；**只接受项目相对路径**（如 `assets/image/...`），不接受绝对路径或 Texture 对象。
- **中文路径坑（execute_command）**：PowerShell 传入含中文的绝对路径会乱码（`Set-Location : 找不到路径…鐙珛娓告垙`）。规避：(a) 用通配符 `03_*` 匹配 `03_独立游戏` 目录；(b) git 命令不带 `-C` 直接用 cwd（shell 工作目录已是项目根）。

## 待办（后续开发）
- **场景图片资源**：`docs/ai-image-prompts.md`(v2.1) 已定义 **17 张 Screen 整图 + 开场背景**，引用名 lobby/courtyard/corridor/crime_scene + office_screen1/2/3.png 等。**尚未生成**，当前以 backgroundColor 色块占位；生成后放入 `assets/image/`。视差三图(bg_office_bg/mid/fg)已弃用。
- 角色立绘 ⚠️ 7主角立绘仍是08-24"现代写实插画"风格，与背景的日系二次元风格**不一致**；待用户用 `docs/ai-image-prompts.md` 的 C1-C7 prompt 重生成并同名覆盖 `char_*.png`
- 场景物件坐标基于 prompt 构图推断（非逐像素视觉），出图后可能需微调
- 命案发现剧情触发（crime_scene 进入时机、张承宇登场）
- 第二阶段探索后的推理/结案流程
- 次要角色（姐姐/前台/磐安员工/平板新闻）立绘未生成
- 开场动画点击跳过、笔记图片放大等细节

## 场景架构（08-26 重构后：全模式 B 多图切换）
- **视角**：侧视横版 side-view（非等距俯视），类似视觉小说/Galgame 场景展示
- **统一模式 B · 解密关卡（整图切换 + 多屏循环箱庭）**：每个关卡由 N 张 1920×1080 全屏整图（Screen）组成，玩家通过左右翻页按钮在 Screen 间切换。交互物件分散隐藏。
  - **office 事务所（序章）**：3 屏线性（s1书柜区→s2办公桌区→s3衣柜地铺区），衣柜 `onInteract="wardrobe"` 触发序章推进
  - P2 大堂：4 屏环形（旋转门→假山→前台→闸机→循环）
  - P3 庭院：3 屏线性（入口→茶歇桌→喷泉海景）
  - P4 走廊：4 屏线性（电梯厅→2501→2502-03→2504-05+沙发）
  - P5 案发现场：3 屏线性（门廊→床头+衣柜→大床+坠落点）
- **模式 A · 视差三层（⚠️ 已弃用）**：原仅 office 使用，2026-08-26 office 已改模式B。bg_office_bg/mid/fg.png 不再被引用。
- **解密关卡 UI**：右上角小地图（140×100px 拓扑缩略图 + 当前位置高亮）、左右翻页按钮（48×48px 半透明箭头）、页码指示器
- **新手引导**：4 步渐进式非阻塞引导，首次进入 screens 场景触发（序章 office 即触发），一次性存档 `tutorial_completed`
- **主角比例放大**：占屏幕高度 55%~65%，每屏独立 charPos 站位
- **全贴图覆盖**：所有状态有贴图或纯色填充
- **资源总量**：17 张解密 Screen + 7 张角色立绘 + 5 张 UI 元素 + 1 张开场背景(bg_office.png) = 30 张有效（另 3 张视差图层弃用）
- **Prompt 文档**：`docs/ai-image-prompts.md` 已更新为 v2.1（整图切换·多屏循环箱庭版，office 归模式B、模式A 视差标注弃用）
