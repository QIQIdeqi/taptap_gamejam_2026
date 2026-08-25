-- ============================================================================
-- SceneManager.lua - 视差横版场景管理器 v2
--
-- 核心机制：
--   三层视差 (BG慢 / MID基准 / FG快) + 人物固定站立
--   镜头控制：鼠标移到屏幕边缘 或 左右方向键 → 场景左右平移
--   点击物件交互（物件随中景层一起滚动）
--
-- 坐标系：
--   世界坐标：横向为绝对像素 (0 ~ worldWidth)，纵向为屏幕高比例 (0~1)
--   镜头：cameraX 表示 viewport 左边缘的世界坐标
--   屏幕坐标 = 世界坐标 - cameraX
-- ============================================================================

local UI = require("urhox-libs.UI")
-- 输入接口由引擎以全局变量 `input` 注入（提供 input:GetKeyPress(KEY_*) /
-- input:GetMouseButtonPress(MOUSEB_*)），以及全局按键常量 KEY_LEFT 等；
-- 不存在 "Input" 模块，不可 require。

local M = {}

-- ==================== 场景状态 ====================
M.currentScene = nil
M.currentSceneData = nil       -- GameData.GetSceneData 完整引用
M.currentObjects = {}
M.currentExits = {}

-- ==================== 镜头参数 ====================
M.cameraX = 0                   -- viewport 左边缘（世界像素）
M.screenW = 0                   -- 屏幕逻辑宽（帧刷新）
M.screenH = 0                   -- 屏幕逻辑高
M.scrollSpeed = 450             -- 像素/秒
M.edgeMargin = 80               -- 鼠标边缘触发距离（px）

-- ==================== 回调 ====================
M.onExit = nil
M.onSceneChanged = nil
M.onClueCollected = nil
M.onSpecialInteract = nil

-- ==================== UI 引用 ====================
M.ui = {
    root = nil,                 -- 全屏裁剪容器 overflow:hidden
    bgLayer = nil,              -- 背景层 (parallax ~0.35)
    midLayer = nil,             -- 中景层 (parallax 1.0) 含物件+出口+人物
    fgLayer = nil,              -- 前景层 (parallax ~1.4)
    charSprite = nil,           -- 人物立绘 Panel
    objectButtons = {},         -- [id] → Button widget
    exitButtons = {},           -- [id] → Button widget
    titleLabel = nil,           -- 场景名（HUD，不滚）
    clueBanner = nil,
    clueBannerText = nil,
    clueBannerTimer = 0,
    hoverNameLabel = nil,       -- 悬停名称（HUD）
    scrollHint = nil,           -- 滚动提示（HUD）
}

-- ============================================================================
-- 公开 API：进入场景
-- ============================================================================

function M.EnterScene(sceneId, onExit)
    local GameData = require("scripts.GameData")
    local sceneData = GameData.GetSceneData(sceneId)
    if not sceneData then return end

    -- 清理旧场景
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end

    M.currentScene = sceneId
    M.currentSceneData = sceneData
    M.currentObjects = sceneData.items or {}
    M.currentExits = sceneData.exits or {}
    M.onExit = onExit

    -- 取屏幕逻辑尺寸：
    -- 引擎以全局变量 `graphics` 注入（不存在 "Graphics" 模块，勿 require）。
    -- 若引擎未提供该全局，回退到默认 1280x720 以免崩溃。
    local sw, sh = 1280, 720
    if graphics then
        local dpr = graphics:GetDPR() or 1
        sw = math.floor(graphics:GetWidth() / dpr)
        sh = math.floor(graphics:GetHeight() / dpr)
    end
    M.screenW = sw
    M.screenH = sh

    -- 初始镜头：让角色位于画面左侧约 1/3 处
    local worldW = sceneData.worldWidth or M.screenW
    local spawnX = sceneData.spawnX or math.floor(worldW * 0.25)
    local idealCam = spawnX - math.floor(M.screenW * 0.30)
    M.cameraX = math.max(0, math.min(idealCam, worldW - M.screenW))

    M.BuildUI()

    if M.onSceneChanged then
        M.onSceneChanged(sceneId)
    end
end

-- ============================================================================
-- 构建完整场景 UI 树
-- ============================================================================

function M.BuildUI()
    local sd = M.currentSceneData          -- 场景数据简写
    local worldW = sd.worldWidth or M.screenW
    local layers = sd.layers or {}
    local bgP = (layers.background and layers.background.parallax) or 0.35
    local fgP = (layers.foreground and layers.foreground.parallax) or 1.4

    -- ── ① 全屏裁剪根容器 ──
    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 16, 14, 24, 255 },
        overflow = "hidden",
        position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
    }

    -- ── ② BG 层（最慢） ──
    M.ui.bgLayer = UI.Panel {
        width = worldW, height = "100%",
        backgroundImage = layers.background and layers.background.image or "",
        backgroundFit = "cover",
        backgroundColor = { 28, 24, 38, 255 },
        position = "absolute", top = 0,
        left = M._layerL(bgP),
    }
    M.ui.root:AddChild(M.ui.bgLayer)

    -- ── ③ MID 层（基准）── 含物件 + 出口 + 人物 ──
    M.ui.midLayer = UI.Panel {
        width = worldW, height = "100%",
        backgroundImage = layers.midground and layers.midground.image or "",
        backgroundFit = "cover",
        backgroundColor = { 22, 19, 32, 255 },
        position = "absolute", top = 0,
        left = M._layerL(1.0),
    }
    M.ui.root:AddChild(M.ui.midLayer)

    -- 人物立绘（固定在世界 spawnX，随 MID 一起滚）
    local spawnX = sd.spawnX or math.floor(worldW * 0.25)
    local groundY = sd.groundY or 0.78
    local charH = math.floor(M.screenH * 0.52)
    M.ui.charSprite = UI.Panel {
        width = math.floor(charH * 0.50), height = charH,
        backgroundImage = "assets/image/char_lizhi.png",
        backgroundFit = "contain",
        backgroundColor = { 0, 0, 0, 0 },
        position = "absolute",
        left = spawnX - M.cameraX,
        bottom = math.floor(M.screenH * (1.0 - groundY)),
    }
    M.ui.midLayer:AddChild(M.ui.charSprite)

    -- 物件按钮
    M.ui.objectButtons = {}
    for _, obj in ipairs(M.currentObjects) do
        local btn = M._makeObjBtn(obj)
        M.ui.midLayer:AddChild(btn)
        M.ui.objectButtons[obj.id] = btn
    end

    -- 出口按钮
    M.ui.exitButtons = {}
    for _, ex in ipairs(M.currentExits) do
        local btn = M._makeExitBtn(ex)
        M.ui.midLayer:AddChild(btn)
        M.ui.exitButtons[ex.id] = btn
    end

    -- ── ④ FG 层（最快） ──
    M.ui.fgLayer = UI.Panel {
        width = worldW, height = "100%",
        backgroundImage = layers.foreground and layers.foreground.image or "",
        backgroundFit = "cover",
        backgroundColor = { 0, 0, 0, 0 },
        position = "absolute", top = 0,
        left = M._layerL(fgP),
    }
    M.ui.root:AddChild(M.ui.fgLayer)

    -- ── ⑤ HUD（不随镜头滚动） ──
    M._buildHUD(sd)

    -- 挂载到渲染树
    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

-- ============================================================================
-- HUD 构建（标题 / 线索横幅 / 悬停名 / 滚动提示）
-- ============================================================================

function M._buildHUD(sd)
    -- 场景标题
    M.ui.titleLabel = UI.Label {
        text = sd.title or "",
        fontSize = 20,
        fontColor = { 240, 235, 225, 220 },
        position = "absolute", left = 24, top = 16,
    }
    M.ui.root:AddChild(M.ui.titleLabel)

    -- 线索横幅
    M.ui.clueBanner = UI.Panel {
        position = "absolute", left = "25%", top = "12%", width = "50%",
        backgroundColor = { 30, 25, 15, 230 },
        borderRadius = 8, borderWidth = 1,
        borderColor = { 200, 180, 100, 200 },
        flexDirection = "column", justifyContent = "center",
        alignItems = "center", padding = 10, visible = false,
    }
    M.ui.root:AddChild(M.ui.clueBanner)
    M.ui.clueBannerText = UI.Label {
        text = "", fontSize = 20,
        fontColor = { 255, 230, 100, 255 }, textAlign = "center",
    }
    M.ui.clueBanner:AddChild(M.ui.clueBannerText)

    -- 悬停名称
    M.ui.hoverNameLabel = UI.Label {
        text = "", fontSize = 18,
        fontColor = { 255, 240, 180, 255 },
        position = "absolute", right = 40, top = "45%",
        backgroundColor = { 20, 16, 30, 200 },
        borderRadius = 6, padding = 8, visible = false,
    }
    M.ui.root:AddChild(M.ui.hoverNameLabel)

    -- 滚动方向提示（仅当场景比屏宽时显示）
    M.ui.scrollHint = UI.Label {
        text = "◀ ← 移动视角 → ▶", fontSize = 13,
        fontColor = { 200, 200, 200, 100 },
        position = "absolute", bottom = 12,
        left = 0, right = 0, textAlign = "center",
        visible = (sd.worldWidth or 0) > M.screenW,
    }
    M.ui.root:AddChild(M.ui.scrollHint)
end

-- ============================================================================
-- 辅助：某层 left 值（= -cameraX × parallax）
-- ============================================================================

function M._layerL(p)
    return math.floor(-(M.cameraX * p))
end

-- ============================================================================
-- 创建物件按钮（世界坐标 → 初始屏幕坐标）
-- 坐标约定：x/w = 世界像素(px), y/h = 屏幕高比例(0~1)
-- ============================================================================

function M._makeObjBtn(obj)
    return UI.Button {
        text = "", variant = "secondary",
        position = "absolute",
        left = math.floor(obj.x - M.cameraX),
        top = (type(obj.y) == "number") and math.floor(obj.y * M.screenH) or obj.y,
        width = (type(obj.w) == "number") and obj.w or obj.w,
        height = (type(obj.h) == "number") and math.floor(obj.h * M.screenH) or obj.h,
        backgroundColor = { 255, 255, 255, 0 },
        hoverBackgroundColor = { 255, 255, 100, 46 },
        borderWidth = 2, borderColor = { 255, 255, 255, 50 },
        onClick = function() M.OnObjectClick(obj) end,
        onPointerEnter = function(_, w) M.OnObjectHover(obj, w, true) end,
        onPointerLeave = function(_, w) M.OnObjectHover(obj, w, false) end,
    }
end

-- ============================================================================
-- 创建出口按钮
-- ============================================================================

function M._makeExitBtn(ex)
    return UI.Button {
        text = ex.label or "→", fontSize = 14, variant = "secondary",
        position = "absolute",
        left = math.floor(ex.x - M.cameraX),
        top = (type(ex.y) == "number") and math.floor(ex.y * M.screenH) or ex.y,
        width = (type(ex.w) == "number") and ex.w or ex.w,
        height = (type(ex.h) == "number") and math.floor(ex.h * M.screenH) or ex.h,
        backgroundColor = { 60, 120, 200, 40 },
        hoverBackgroundColor = { 60, 160, 255, 80 },
        borderWidth = 1, borderColor = { 120, 180, 255, 80 },
        onClick = function() M.EnterScene(ex.targetScene, nil) end,
    }
end

-- ============================================================================
-- 每帧更新（由 main.lua 调用）
--   1. 读取输入（方向键 + 鼠标边缘）
--   2. clamp cameraX
--   3. 同步三层 left + 人物 + 物件/出口 left
--   4. 线索横幅倒计时
-- ============================================================================

function M.Update(dt)
    if not M.currentSceneData or not M.ui.root then return end

    local sd = M.currentSceneData
    local worldW = sd.worldWidth or M.screenW
    local maxCX = math.max(0, worldW - M.screenW)
    local layers = sd.layers or {}
    local bgP = (layers.background and layers.background.parallax) or 0.35
    local fgP = (layers.foreground and layers.foreground.parallax) or 1.4

    -- ── 1. 滚动输入（方向键；引擎全局 input:GetKeyPress）──
    local dir = 0
    if input:GetKeyPress(KEY_LEFT) then dir = dir - 1 end
    if input:GetKeyPress(KEY_RIGHT) then dir = dir + 1 end

    -- ── 2. 应用 & clamp ──
    if dir ~= 0 then
        M.cameraX = M.cameraX + dir * M.scrollSpeed * dt
        M.cameraX = math.max(0, math.min(M.cameraX, maxCX))
    end

    -- ── 3. 同步各层 left ──
    local bgL = M._layerL(bgP)
    local midL = M._layerL(1.0)
    local fgL = M._layerL(fgP)

    if M.ui.bgLayer then   M.ui.bgLayer:SetStyle({   left = bgL })  end
    if M.ui.midLayer then  M.ui.midLayer:SetStyle({  left = midL }) end
    if M.ui.fgLayer then  M.ui.fgLayer:SetStyle({  left = fgL })  end

    -- ── 4. 人物（随 MID） ──
    if M.ui.charSprite then
        local spawnX = sd.spawnX or 0
        local groundY = sd.groundY or 0.78
        M.ui.charSprite:SetStyle({
            left = math.floor(spawnX - M.cameraX),
            bottom = math.floor(M.screenH * (1.0 - groundY)),
        })
    end

    -- ── 5. 物件/出口按钮 left 同步 ──
    for _, obj in ipairs(M.currentObjects) do
        local b = M.ui.objectButtons[obj.id]
        if b then b:SetStyle({ left = math.floor(obj.x - M.cameraX) }) end
    end
    for _, ex in ipairs(M.currentExits) do
        local b = M.ui.exitButtons[ex.id]
        if b then b:SetStyle({ left = math.floor(ex.x - M.cameraX) }) end
    end

    -- ── 6. 线索横幅倒计时 ──
    if M.ui.clueBannerTimer and M.ui.clueBannerTimer > 0 then
        M.ui.clueBannerTimer = M.ui.clueBannerTimer - dt
        if M.ui.clueBannerTimer <= 0 and M.ui.clueBanner then
            M.ui.clueBanner:SetVisible(false)
        end
    end
end

-- ============================================================================
-- 物件悬停：描边高亮 + 名称标签
-- ============================================================================

function M.OnObjectHover(obj, widget, entering)
    if entering then
        widget:SetStyle({ borderColor = { 255, 255, 100, 255 } })
        if M.ui.hoverNameLabel then
            M.ui.hoverNameLabel:SetText("🔍 " .. (obj.name or ""))
            M.ui.hoverNameLabel:SetVisible(true)
        end
    else
        widget:SetStyle({ borderColor = { 255, 255, 255, 50 } })
        if M.ui.hoverNameLabel then
            M.ui.hoverNameLabel:SetVisible(false)
        end
    end
end

-- ============================================================================
-- 物件点击：线索收集 + 对话展示
-- ============================================================================

function M.OnObjectClick(obj)
    local GameData = require("scripts.GameData")
    local DialogueSystem = require("scripts.DialogueSystem")
    if DialogueSystem.IsActive() then return end

    local txt = obj.interactText or "..."

    -- 收集线索
    local newClue = false
    if obj.clueId then newClue = GameData.CollectClue(obj.clueId) end

    if newClue and obj.clueId then
        local clue = GameData.GetClue(obj.clueId)
        if clue then M.ShowClueBanner("获得线索：" .. clue.name) end
        if M.onClueCollected then M.onClueCollected(obj.clueId) end
    end

    -- 特殊交互回调
    if obj.onInteract and M.onSpecialInteract then
        M.onSpecialInteract(obj, function() M.ShowInteraction(txt) end)
    else
        M.ShowInteraction(txt)
    end
end

function M.ShowInteraction(txt)
    require("scripts.DialogueSystem").Start({
        id = "interaction",
        lines = { { speaker = "LiZhi", text = txt } },
    })
end

-- ============================================================================
-- 线索横幅
-- ============================================================================

function M.ShowClueBanner(text)
    if not M.ui.clueBanner then return end
    M.ui.clueBannerText:SetText(text)
    M.ui.clueBanner:SetVisible(true)
    M.ui.clueBannerTimer = 3.0
end

-- ============================================================================
-- 退出场景
-- ============================================================================

function M.ExitScene()
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    M.currentScene = nil
    M.currentSceneData = nil
    M.currentObjects = {}
    M.currentExits = {}
    M.cameraX = 0
end

return M
