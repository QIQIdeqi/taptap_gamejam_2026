# 项目长期记忆（异视 · 黄昏事务所）

## 项目概况
- 游戏名：异视（副标题：黄昏事务所）；2D 横板推理（含 meta）；UrhoX Lua 引擎
- 案件：落晖之宴·严成峰坠亡案
- 美术：日系二次元动漫风格（08-25 定，干净线稿+赛璐璐+暖调低饱和）

## 设计文档（wolai）
- 基础设计 page_id `3uc1XCmBM6jmyyAnVePCsU`（v58，5章30节154block，最新更新集中在 5.2 笔记功能）
- 四大分类已落地：【物证档案/证言纪要/人物名录/现场痕迹】
- 已对齐规范：线索收录HUD提示框(5.2.5)、⭐标记+只看标记(5.2.4)、红点三级(5.2.6)、状态机(5.2.8)、特写图点击放大(5.2.7)、存档10槽+自动档置顶+二次确认+缩略图(5.1)
- 用 wolai MCP 读取：get_page_outline / get_section_content / get_page_blocks / get_doc

## 代码模块（scripts/）
- `main.lua`：主循环/模式/Tab笔记/ESC暂停/自动存档；`ShowClueCollectedToast`（新线索收录HUD）+ `tabHintWidget`（常驻笔记红点）
- `GameData.lua`：角色/章节/线索(四大分类)/对话/开场/场景物件；线索字段 `id/name/category/chapter/description/detail/image`
- `NoteSystem.lua`：笔记(Tab/Q/E/W/S/F/⭐/红点/状态机)；`ShowImagePreview` 全屏预览；`GetUnreadCount()` 供红点
- `SceneManager.lua` v3：整图切换多屏；`_onItemInteract` 优先级 `onInteract→dialogueId→interactText→misleading`；线索走 `GameData.CollectClue`
- `DialogueSystem.lua`：打字机；对话行支持 `line.clue`（播毕触发证言提取收录）
- `MenuSystem.lua`：菜单/存档/读档/设置；槽位按钮含缩略图+删除按钮
- `SaveSystem.lua`：10槽+自动存档；`GetSceneThumbnail` 场景→缩略图映射

## 关键约定（致命坑精简）
- 长度米、Y-up 左手坐标系
- `graphics`/`input` 是全局变量（勿 require）；无 SetMode；`GetKeyPress` 仅此、无鼠标坐标（滚动用方向键）
- UI 构造仅 `UI.Panel/Label/Button`，单参数 `UI.X({...})`；**双参数 `UI.X(parent,props)` 第二参被吞→黑屏**（最致命坑）
- 事件回调写 `widget.props.onX`（onClick/onPointerEnter/onPointerLeave），**非** `widget:onX()` **非** `widget.onX=`
- `SetStyle` 仅单 table 参数；颜色 table 或 `"rgba(...)"`
- `Widget:AddChild` 返回 **self**（非 child）；图片用 `backgroundImage`(项目相对路径)，**无 `UI.Image`**
- 主循环：`Start` + `SubscribeToEvent("Update","HandleUpdate")`；帧时间 `eventData["TimeStep"]:GetFloat()`
- 图片：`backgroundImage` + `backgroundFit`(fill/contain/cover) + `backgroundColor` 透明；`SetVisible(bool)` 存在

## 场景架构（模式 B 多图切换）
- 侧视横版；每关 N 张 1920×1080 全屏 Screen 翻页切换
- office(序章,3屏) / P2大堂(4屏环形) / P3庭院(3屏) / P4走廊(4屏) / P5案发现场(3屏)
- UI：小地图/翻页按钮/页码/新手引导/主角放大/全贴图覆盖

## 待办（后续开发）
- ✅ 已完成：场景黑屏修复、跳过按钮、场景UI反馈(ShowClueBanner)、物件点击→角色独白+误导对话、线索收录HUD提示框(5.2.5)、证言提取Clue_Extract、笔记特写图放大(5.2.7)、常驻笔记红点(5.2.6)、存档缩略图+删除按钮(5.1)、ai-image-prompts.md 线索特写图+次要角色立绘章节
- ✅ 已完成（2026-08-27 晚）：次要角色立绘(char_receptionist/sister/technician.png, ui_news_anchor.png)与线索特写图(clue_inhaler/body/signbook/fountain.png)已生成并入 assets/image；线索特写图已替换 GameData 占位引用；DialogueSystem.portraitMap 接入 4 位次要角色立绘(LiZhiSister/FrontDesk/PanganEmployee/NewsAnchor)（注意：code-explorer 子代理为只读型，无法调用 maker 生成图片/写文件，故由主 agent 直接调度 maker 批量生成，等价于并行 worker 产出）
- ✅ 已核查实现：命案发现剧情触发(enter_crime→crime_found→张承宇登场)、第二阶段推理/结案(deduce→crime_deduction→ShowSuspectChoice→crime_ending_true)、开场动画(Openings prologue/chapter1→对应分镜对话) 流程与对话 id 均已齐备
- ✅ 已完成（2026-08-27 晚）：SceneManager 物件坐标静态优化——4个首屏左侧exit(lobby/corridor/courtyard/crime)避开翻页按钮与调查物件，courtyard plant上移；HUD(标题/翻页/小地图/hover名)加zIndex=2000防御。待办已清零，后续仅剩运行期观感微调。
- ✅ 已完成（2026-08-28）：wolai 二~四阶段缺失台词全部补入 `assets/data/dialogues.csv`（12 组 +52 行，crime_found 由 5 句扩为 10 句完整版）；GameData 加 WaiterA/WaiterB/PoliceA 三角色 + 庭院 4组NPC物件 + 走廊"门缝下的声响"偷听物件；main.lua 命案序列重构为完整链（闲聊→对讲机→张承宇→电梯→查房→登门→现场）。CSV 现为唯一台词编辑源。

## 文本数据 CSV 化（2026-08-28）
- 台词/线索已导出为可编辑 CSV，运行时由 Lua 直接读取（策划在 Excel/表格改完即生效）：
  - `assets/data/dialogues.csv`：列 `dialogue_id,line_no,speaker,portrait,clue,text,background`（一行=一句；**行数即句数**，增/删一行即增/删一句台词）
  - `assets/data/clues.csv`：列 `id,name,category,chapter,description,detail,image`
- 运行时加载：`scripts/CSVLoader.lua`（用 `File(path,FILE_READ):ReadString()` 读取并自写 CSV 解析，兼容 BOM/引号字段/字段内逗号/`""` 转义/字段内换行），`GameData.lua` 末尾 `require` 后覆盖 `M.Dialogues`/`M.Clues`。**优先读 CSV，找不到则回退内嵌兜底数据**（游戏永不崩）
- 已删除 `tools/gen_csv.js` 等一次性提取脚本，避免误用其以 GameData 兜底数据覆盖用户编辑后的 CSV（CSV 现为唯一编辑源）
- 顺带修复 bug：序章办公室 4 对话（of_bookshelf/of_desk/of_bed/of_lamp_mislead）原先被错误嵌套进 `crime_ending_true` 表内（缩进层级错），致 `M.Dialogues["of_bookshelf"]` 为 nil、办公室物件点击无反应；CSV 化按 id 扁平化到顶层已修复，内嵌兜底也已补为顶层条目
- Lua 文件 IO：`File(path,FILE_READ)` / `fileSystem:FileExists(path)` 用相对路径（引擎自动项目+用户隔离）；`io` 库已移除，禁用 `loadfile/dofile`，统一用 `require`

## 可拓展方向（用户授权"自行思考拓展"）
- 同样模式可把 场景物件交互文字(name/interactText/misleading) 与 角色介绍 也抽出 CSV，loader 按 item id 回填 SceneManager/Characters（当前未做，按需再扩）
