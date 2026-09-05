# 异视 · 黄昏事务所 — 开发待办 (TODO)

> 最后更新：2026-08-26
> 当前进度：序章 + 第一章探索 + 命案发现触发 + 结案推理流程（task4）已完成并构建成功（commit dda9d67）。
> 美术：17 张解密 Screen + 7 张主角立绘 + 5 张 UI 元素 + 1 张开场背景已全部生成。

---

## ✅ 已完成（本轮）
- [x] 解密关卡架构：全部场景改为「整图切换 · 多屏循环箱庭」（模式 B）
- [x] 生成 17 张解密 Screen 整图 + 5 张 UI 元素 + 重生成 7 张主角立绘（日系二次元）
- [x] 序章 office 三屏 + 新手引导
- [x] 命案发现触发（task3）：集齐 5 探索线索后点 2501 → 张承宇登场 → 进入案发现场
- [x] 结案推理流程（task4）：三处现场线索齐 → 推理独白 → 自建 UI 选凶手 → 指认周文 → 真结局

---

## 🔍 阶段一：验证与稳定性（当前）
- [ ] **手动走通完整结局流程（验证 task4 交互无运行时错误）** — 你正在做
  - 序章 office 点衣柜 → 进入第一章
  - 酒店 4 区探索，收集 5 条探索线索
  - 25F 走廊点 2501 → 命案发现 → 进入案发现场
  - 案发现场查 3 处线索（温控面板 / 床头柜 / 尸体位置）
  - 点「整理线索 · 进行推理」→ 推理独白 → 选「周文」→ 真结局
  - 重点确认：UI 选择面板（覆盖层+面板+4 按钮）创建/选错重选/选对销毁无报错
  - 报错排查：`maker://status` 看 runtime.log；常见坑见 MEMORY.md（SetStyle 必传 table 等）

---

## 🎨 阶段二：美术补全
- [ ] 次要角色立绘生成（日系二次元 · 透明背景）
  - 角色：李志姐姐 (LiZhiSister) / 前台接待 (FrontDesk) / 磐安员工 (PanganEmployee) / 平板新闻 (NewsAnchor)
  - 规格：`batch_generate_images`，`transparent:true`，`aspect_ratio 2:3`，`target_size 800x1200`，`resolution 2K`
  - 命名：覆盖 `char_lizhisister.png` / `char_frontdesk.png` / `char_pangan.png` / `char_news.png`
  - ⚠️ 需确认：这些角色目前仅在对话文本里被引用，尚无立绘展示逻辑，生成后是否需要在某场景/对话中实际显示

---

## 🧩 阶段三：流程收尾
- [ ] 真结局收尾界面
  - 真结局对话播完后，弹出「返回主菜单 / 重新开始」选项，避免流程悬空
  - 实现位置：`main.lua` `crime_ending_true` 的 onComplete 回调里复用自建 UI 面板
- [ ] 开场动画点击跳过
  - `OpeningSystem` 支持点击 / 按键跳过黑屏时间地点 + 分镜对话
- [ ] 笔记图片放大
  - 侦探笔记 (Tab) 中线索含图时，点击放大查看细节

---

## 🛠 阶段四：打磨与清理
- [ ] 场景物件坐标微调
  - 按已出图实际构图，校正各屏交互物件 `x/y/w/h` 命中区（尤其房门、尸体、小物件等目标）
  - 重点屏：corridor_screen2 (2501 房门)、crime_scene_screen3 (deduce 推理入口、尸体)
- [ ] 资源清理（代码均未引用，可安全删除）
  - 旧视差背景：`bg_hotel_lobby.png` / `bg_hotel_courtyard.png` / `bg_hotel_corridor.png` / `bg_crime_scene.png`
  - 不规范命名遗留图：`日系二次元动漫风格_豪华酒店套房内部全景_2510客房_案发_*.png`
  - 远端残留：`ui_tooltip_bg_20260826150327.png`（U5 重试多落盘副本）

---

## 📦 阶段五：提交与构建
- [ ] 每项完成后 `git commit` + `maker_build_current_directory` 验证
- [ ] 远端常自动提交 `.meta` 致本地 behind 1，构建前按需 `git stash; git pull; git stash pop` 同步

---

## 备注
- 完整设计见 wolai（基础设计 page_id `3uc1XCmBM6jmyyAnVePCsU`）
- 美术 Prompt 见 `docs/ai-image-prompts.md` (v2.1)
- 引擎约定 / 已知坑见 `.codebuddy/memory/MEMORY.md`
