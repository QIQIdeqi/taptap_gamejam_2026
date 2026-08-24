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
- `SceneManager.lua`：场景UI、物件交互、悬停描边+名称提示、场景导航exits
- `DialogueSystem.lua`：打字机对话（Start 支持字符串id和table）
- `MenuSystem.lua`：主菜单/暂停/存档/读档/设置
- `SaveSystem.lua`：10槽+自动存档（含 readClues/starredClues 笔记状态）

## 关键约定
- 长度单位米、Y-up 左手坐标系
- `graphics:SetMode()` 已禁用，用 `graphics:GetWidth()/GetHeight()/GetDPR()`
- UI 组件支持 `onPointerEnter`/`onPointerLeave`（签名 `(event, widget)`）、`borderWidth`/`borderColor`、`SetStyle({...})`
- **改字体颜色用 `SetStyle({ fontColor = {r,g,b,a} })`**；无 `SetFontColor`/`SetTextColor` 方法（只有 `SetBackgroundColor`/`SetBorderColor` 两个 alias）
- 键盘：`input:GetKeyPress(KEY_*)` 单次按下，`input:GetKeyDown(KEY_*)` 持续按住
- Button 文本始终居中（不支持 textAlign）
- **事件驱动主循环**：UrhoX 无 `engine:GetFrameTime()/IsExiting()/FrameNext()`，勿手写 while。用 `Start()` + `SubscribeToEvent("Update","HandleUpdate")`，帧时间取 `eventData["TimeStep"]:GetFloat()`
- **UI 渲染挂载**：必须 `UI.Init({ scale = UI.Scale.DEFAULT })` + `UI.SetRoot(root)` 才会渲染；`Widget:Show()` 仅 SetVisible(true)，需 `UI.GetRoot():AddChild(widget)` 挂到渲染树；`Destroy()` 自动从 parent 移除
- **`Widget:AddChild(child)` 返回 `self`（父节点）用于链式调用，不是 child**！要引用子节点必须 `local x = UI.xxx{...}; parent:AddChild(x)`，绝不能写 `local x = parent:AddChild(...)`（否则 x 指向父节点，缺子类方法如 SetText 会报 nil）
- **图片资源生成（taptap-maker）**：`batch_generate_images`（2-10张并行）/`generate_image` 下载到 `assets/image/`，文件名**自动加时间戳后缀**（如 `bg_office_20260824xxxx.png`），生成后需 `Rename-Item` 重命名为代码引用名（`bg_office.png` 等）；人物立绘传 `transparent:true` 得透明背景 PNG，`aspect_ratio`/`target_size`/`resolution` 控制画幅。
- **显示图片**：用 `Widget:SetBackgroundImage("assets/image/xxx.png")` 或构造 `backgroundImage = "assets/image/xxx.png"` + `backgroundFit`（"fill"/"contain"/"cover"）+ `backgroundImageOpacity`；**只接受项目相对路径**（如 `assets/image/...`），不接受绝对路径或 Texture 对象。
- **中文路径坑（execute_command）**：PowerShell 传入含中文的绝对路径会乱码（`Set-Location : 找不到路径…鐙珛娓告垙`）。规避：(a) 用通配符 `03_*` 匹配 `03_独立游戏` 目录；(b) git 命令不带 `-C` 直接用 cwd（shell 工作目录已是项目根）。

## 待办（后续开发）
- 命案发现剧情触发（crime_scene 进入时机、张承宇登场）
- 第二阶段探索后的推理/结案流程
- 场景背景图 ✅ 已生成 5 张（office/lobby/courtyard/corridor/crime_scene）并接入
- 角色立绘 ✅ 7 主角已生成并接入对话系统；次要角色（姐姐/前台/磐安员工/平板新闻）立绘未生成
- 开场动画点击跳过、笔记图片放大等细节
