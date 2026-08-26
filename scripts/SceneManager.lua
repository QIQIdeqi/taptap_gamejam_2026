local M = {}
local GameData = require("GameData")
local UI = require("urhox-libs.UI")
-- 键盘输入：引擎以全局变量 `input` 注入（无 Input 模块，勿 require）。
-- 屏幕尺寸：引擎以全局变量 `graphics` 注入（无 Graphics 模块），无则用 1280x720 兜底。

-- 公开回调（由 main.lua 设置）
M.onSceneChanged = nil
M.onClueCollected = nil
M.onSpecialInteract = nil

-- 运行状态（screens 模式复用）
M.currentSceneId = nil
M.onExit = nil
M.ui = { root = nil }
M.bgFixed = {}
M.cameraX = 0
M.worldWidth = 0
M.screenW = 1280
M.screenH = 720
M.scrollSpeed = 450
M.edgeMargin = 80
M.groundY = 0.78
M.spawnX = 520
M.layers = {}
M.charSprite = nil
M.hoverNameLabel = nil
M.titleLabel = nil
M.scrollHint = nil
M.charNameLabel = nil
M._tutorial = { screens = false, minimap = false }
M._switchCD = 0
-- screens 模式状态
M._screens = nil
M._curScreenId = nil
M._screenPanel = nil
M._screenLayer = nil
M._btnLeft = nil
M._btnRight = nil
M._minimap = nil
M._mmNodes = {}
M._tutPanel = nil

local function _rgba(t)
    if not t then return "rgba(0,0,0,255)" end
    return string.format("rgba(%d,%d,%d,%d)", t[1] or 0, t[2] or 0, t[3] or 0, t[4] or 255)
end

-- ============================================================
-- 进入场景（根据 mode 分支）
-- ============================================================
function M.EnterScene(sceneId, onExit)
    local sceneData = GameData.SceneObjects[sceneId]
    if not sceneData then
        print("SceneManager.EnterScene: 未知场景 " .. tostring(sceneId))
        return
    end
    M.currentSceneId = sceneId
    M.onExit = onExit
    M.ui = { root = nil }
    M.bgFixed = {}
    M._switchCD = 0

    UI:Init()
    local root = UI.Panel(nil, {
        left = 0, top = 0, width = "100%", height = "100%",
        overflow = "hidden", backgroundColor = "rgba(0,0,0,255)",
    })
    M.ui.root = root

    -- 关键：挂载到 UI 渲染树。UI 仅在 UI.GetRoot() 渲染树中可见；
    -- 若不挂载，整场景游离不渲染，表现为纯黑屏（main.lua 总根背景为纯黑）。
    -- 注意 UI.Panel(nil,...) 不会自动成为根，必须显式 AddChild（OpenScene/Menu 同此约定）。
    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(root) end

    -- 屏幕尺寸
    local sw, sh = 1280, 720
    if graphics then
        local dpr = graphics:GetDPR() or 1
        sw = math.floor(graphics:GetWidth() / dpr)
        sh = math.floor(graphics:GetHeight() / dpr)
    end
    M.screenW = sw
    M.screenH = sh

    -- 公共 HUD：标题 + 悬停名称
    M.titleLabel = UI.Label(root, {
        left = 20, top = 16, width = sw - 180, height = 30,
        text = sceneData.title or sceneId, fontSize = 18, color = "rgba(255,255,255,230)",
        textAlign = "left",
    })
    M.hoverNameLabel = UI.Label(root, {
        left = 0, top = sh - 40, width = sw, height = 28,
        text = "", fontSize = 16, color = "rgba(255,255,255,240)", textAlign = "center",
    })
    M.hoverNameLabel:SetStyle({ visible = false })

    if sceneData.mode == "screens" then
        M:_EnterScreens(sceneData, root, sw, sh)
    else
        M:_EnterParallax(sceneData, root, sw, sh)
    end

    if M.onSceneChanged then M.onSceneChanged(sceneId) end
end

-- ============================================================
-- 模式 A：视差三层（仅 office 序章场景）
-- ============================================================
function M:_EnterParallax(sceneData, root, sw, sh)
    M.worldWidth = sceneData.worldWidth
    M.groundY = sceneData.groundY or 0.78
    M.spawnX = sceneData.spawnX or 520

    local ldefs = sceneData.layers
    local layerDefs = {
        { key = "background", def = ldefs.background, z = 1 },
        { key = "midground",  def = ldefs.midground,  z = 2 },
        { key = "foreground", def = ldefs.foreground, z = 3 },
    }
    for _, ld in ipairs(layerDefs) do
        if ld.def and ld.def.image then
            local img = UI.Panel(root, {
                backgroundImage = ld.def.image,
                backgroundFit = "cover",
                left = 0, top = 0, width = M.worldWidth, height = sh,
                zorder = ld.z,
            })
            M.layers[ld.key] = { img = img, parallax = ld.def.parallax or 1.0, baseLeft = 0 }
            if M.bgFixed[ld.key] == nil then M.bgFixed[ld.key] = false end
        end
    end

    -- 主角
    local charH = sh * 0.52
    local charY = (1 - M.groundY) * sh - charH
    M.charSprite = UI.Panel(root, {
        backgroundImage = "assets/image/char_lizhi.png",
        backgroundFit = "contain",
        backgroundColor = "rgba(0,0,0,0)",
        left = M.spawnX, top = charY, width = charH * 0.5, height = charH,
        zorder = 5,
    })

    -- 交互物件
    if sceneData.items then
        for _, item in ipairs(sceneData.items) do
            M:_makeItemBtn(item, sw, sh, false)
        end
    end
    if sceneData.exits then
        for _, ex in ipairs(sceneData.exits) do
            M:_makeExitBtn(ex, sw, sh, false)
        end
    end

    -- 滚动提示
    M.scrollHint = UI.Label(root, {
        left = 0, top = sh - 40, width = sw, height = 24,
        text = "◀ ← 移动视角 → ▶", fontSize = 14, color = "rgba(255,255,255,170)", textAlign = "center",
    })

    M.cameraX = 0
    M:_ApplyCamera()
end

function M:_makeItemBtn(item, sw, sh, isScreenMode, parent)
    parent = parent or M.ui.root
    local left, top, w, h
    if isScreenMode then
        left, top, w, h = item.x * sw, item.y * sh, item.w * sw, item.h * sh
    else
        left, top, w, h = item.x, item.y * sh, item.w, item.h * sh
    end
    local btn = UI.Button(parent, {
        left = left, top = top, width = w, height = h,
        backgroundColor = "rgba(255,255,255,0)", borderWidth = 0,
    })
    btn.props.onPointerEnter = function(event, widget)
        if M.hoverNameLabel then
            M.hoverNameLabel:SetText(item.name)
            M.hoverNameLabel:SetStyle({ visible = true })
        end
    end
    btn.props.onPointerLeave = function(event, widget)
        if M.hoverNameLabel then M.hoverNameLabel:SetStyle({ visible = false }) end
    end
    btn.props.onClick = function() M:_onItemInteract(item) end
    return btn
end

function M:_makeExitBtn(ex, sw, sh, isScreenMode, parent)
    parent = parent or M.ui.root
    local left, top, w, h
    if isScreenMode then
        left, top, w, h = ex.x * sw, ex.y * sh, ex.w * sw, ex.h * sh
    else
        left, top, w, h = ex.x, ex.y * sh, ex.w, ex.h * sh
    end
    local btn = UI.Button(parent, {
        left = left, top = top, width = w, height = h,
        backgroundColor = "rgba(120,200,255,18)", borderWidth = 0,
    })
    btn.props.onPointerEnter = function(event, widget)
        if M.hoverNameLabel then
            M.hoverNameLabel:SetText(ex.label or "前往")
            M.hoverNameLabel:SetStyle({ visible = true })
        end
    end
    btn.props.onPointerLeave = function(event, widget)
        if M.hoverNameLabel then M.hoverNameLabel:SetStyle({ visible = false }) end
    end
    btn.props.onClick = function()
        if M.onExit then M.onExit(ex.targetScene) end
    end
    return btn
end

-- ============================================================
-- 模式 B：整图切换 · 多屏循环箱庭
-- ============================================================
function M:_EnterScreens(sceneData, root, sw, sh)
    M._screens = sceneData.screens
    M._curScreenId = sceneData.minimap and sceneData.minimap.start or sceneData.screens[1].id

    -- 整图背景面板（backgroundImage 若不存在则显示 backgroundColor 兜底，绝不黑屏）
    M._screenPanel = UI.Panel(root, {
        left = 0, top = 0, width = sw, height = sh,
        backgroundImage = "", backgroundColor = "rgba(20,20,30,255)", overflow = "hidden",
    })
    -- 承载当前 screen 的物件/出口/主角
    M._screenLayer = UI.Panel(M._screenPanel, {
        left = 0, top = 0, width = sw, height = sh, overflow = "hidden",
    })

    -- 翻页按钮（◀ ▶）
    M._btnLeft = UI.Button(root, {
        left = 24, top = sh / 2 - 24, width = 48, height = 48,
        text = "◀", fontSize = 22, color = "rgba(255,255,255,220)",
        backgroundColor = "rgba(0,0,0,90)", borderRadius = 8,
    })
    M._btnLeft.props.onClick = function() M:_SwitchScreen("left") end
    M._btnRight = UI.Button(root, {
        left = sw - 24 - 48, top = sh / 2 - 24, width = 48, height = 48,
        text = "▶", fontSize = 22, color = "rgba(255,255,255,220)",
        backgroundColor = "rgba(0,0,0,90)", borderRadius = 8,
    })
    M._btnRight.props.onClick = function() M:_SwitchScreen("right") end

    -- 小地图
    M:_BuildMinimap(sceneData, root, sw, sh)

    -- 构建首屏
    M:_BuildScreenContent(M._curScreenId)

    -- 新手引导 Step1
    if not M._tutorial.screens then
        M:_ShowTutorial(root, sw, sh,
            "点击场景中的物件进行调查  ◀ ▶ 翻页浏览",
            function() M._tutorial.screens = true end)
    end
end

function M:_GetScreen(id)
    for _, s in ipairs(M._screens) do
        if s.id == id then return s end
    end
    return nil
end

function M:_BuildScreenContent(screenId)
    local screen = M:_GetScreen(screenId)
    if not screen then return end
    M._curScreenId = screenId
    local sw, sh = M.screenW, M.screenH

    -- 整图背景（兜底底色 + 真实图若存在）
    M._screenPanel:SetStyle({ backgroundColor = _rgba(screen.bgColor) })
    M._screenPanel:SetStyle({ backgroundImage = screen.image or "" })

    -- 重建承载层
    if M._screenLayer then M._screenLayer:Destroy() end
    M._screenLayer = UI.Panel(M._screenPanel, {
        left = 0, top = 0, width = sw, height = sh, overflow = "hidden",
    })

    -- 主角（放大，按 charPos 站位）
    local cp = screen.charPos or { x = 0.5, y = 0.78, scale = 0.58 }
    local charH = sh * (cp.scale or 0.58)
    local charX = cp.x * sw - charH * 0.25
    local charY = (1 - cp.y) * sh - charH
    M.charSprite = UI.Panel(M._screenLayer, {
        backgroundImage = "assets/image/char_lizhi.png",
        backgroundFit = "contain",
        backgroundColor = "rgba(0,0,0,0)",
        left = charX, top = charY, width = charH * 0.5, height = charH,
        zorder = 5,
    })

    -- 物件
    if screen.items then
        for _, item in ipairs(screen.items) do
            M:_makeItemBtn(item, sw, sh, true, M._screenLayer)
        end
    end
    -- 出口（跨场景传送）
    if screen.exits then
        for _, ex in ipairs(screen.exits) do
            M:_makeExitBtn(ex, sw, sh, true, M._screenLayer)
        end
    end

    -- 标题
    if M.titleLabel then
        M.titleLabel:SetText((GameData.SceneObjects[M.currentSceneId].title or "") .. " · " .. (screen.title or ""))
    end

    -- 翻页按钮启用态
    M:_RefreshNavButtons(screen)
    -- 小地图高亮
    M:_RefreshMinimap(screenId)
end

function M:_SwitchScreen(dir)
    local screen = M:_GetScreen(M._curScreenId)
    if not screen then return end
    local targetId = (dir == "left") and screen.left or screen.right
    if not targetId then return end
    M:_BuildScreenContent(targetId)
    -- 新手引导 Step2：首次翻页后小地图脉冲
    if not M._tutorial.minimap and M._minimap then
        M._tutorial.minimap = true
        M._minimap:SetStyle({ borderColor = "rgba(255,200,80,255)" })
        M._minimap:SetStyle({ borderWidth = 2 })
    end
end

function M:_RefreshNavButtons(screen)
    if M._btnLeft then
        if screen.left then
            M._btnLeft:SetStyle({ opacity = 1 })
        else
            M._btnLeft:SetStyle({ opacity = 0.2 })
        end
    end
    if M._btnRight then
        if screen.right then
            M._btnRight:SetStyle({ opacity = 1 })
        else
            M._btnRight:SetStyle({ opacity = 0.2 })
        end
    end
end

-- 小地图（右上角拓扑缩略图）
function M:_BuildMinimap(sceneData, root, sw, sh)
    local mmData = sceneData.minimap
    if not mmData then return end
    local mw, mh = 140, 100
    M._minimap = UI.Panel(root, {
        right = 16, top = 16, width = mw, height = mh,
        backgroundColor = "rgba(12,10,20,200)", borderRadius = 8,
        borderWidth = 1, borderColor = "rgba(255,255,255,38)", overflow = "hidden",
    })
    M._mmNodes = {}
    local pad = 12
    local innerW, innerH = mw - pad * 2, mh - pad * 2
    for _, node in ipairs(mmData.nodes) do
        local nx = pad + (node.nx or 0.5) * innerW
        local ny = pad + (node.ny or 0.5) * innerH
        local dot = UI.Panel(M._minimap, {
            left = nx - 5, top = ny - 5, width = 10, height = 10,
            borderRadius = 5, backgroundColor = "rgba(255,255,255,120)",
        })
        local lbl = UI.Label(M._minimap, {
            left = nx - 24, top = ny + 6, width = 48, height = 16,
            text = node.label or "", fontSize = 10, color = "rgba(255,255,255,160)", textAlign = "center",
        })
        M._mmNodes[node.id] = { dot = dot, lbl = lbl }
    end
end

function M:_RefreshMinimap(screenId)
    if not M._minimap then return end
    for id, n in pairs(M._mmNodes) do
        if id == screenId then
            n.dot:SetStyle({ backgroundColor = "rgba(255,180,60,255)" })
        else
            n.dot:SetStyle({ backgroundColor = "rgba(255,255,255,120)" })
        end
    end
end

-- 新手引导浮窗（非阻塞，点击任意处关闭）
function M:_ShowTutorial(root, sw, sh, text, onClose)
    if M._tutPanel then M._tutPanel:Destroy() end
    M._tutPanel = UI.Panel(root, {
        left = sw / 2 - 200, top = sh / 2 - 50, width = 400, height = 100,
        backgroundColor = "rgba(20,18,30,235)", borderRadius = 12,
        borderWidth = 1, borderColor = "rgba(255,255,255,30)", zorder = 100,
    })
    local tip = UI.Label(M._tutPanel, {
        left = 16, top = 16, width = 368, height = 68,
        text = text, fontSize = 15, color = "rgba(255,255,255,235)", textAlign = "center",
    })
    local overlay = UI.Button(root, {
        left = 0, top = 0, width = sw, height = sh,
        backgroundColor = "rgba(0,0,0,0)", zorder = 99, borderWidth = 0,
    })
    overlay.props.onClick = function()
        overlay:Destroy()
        if M._tutPanel then M._tutPanel:Destroy() end
        M._tutPanel = nil
        if onClose then onClose() end
    end
end

-- ============================================================
-- 交互逻辑（两模式共用）
-- ============================================================
function M:_onItemInteract(item)
    if item.clueId then
        local gs = GameData.GameState or {}
        gs.collectedClues = gs.collectedClues or {}
        local already = gs.collectedClues[item.clueId]
        gs.collectedClues[item.clueId] = true
        GameData.GameState = gs
        GameData.SetFlag("clue_" .. item.clueId, true)
        if M.onClueCollected then M.onClueCollected(item.clueId, item.name, already) end
    end
    if item.onInteract then
        if M.onSpecialInteract then M.onSpecialInteract(item) end
    end
    if item.interactText then
        M:ShowClueBanner(item.name, item.interactText)
    end
end

function M:ShowClueBanner(name, text)
    if M.hoverNameLabel then
        M.hoverNameLabel:SetText(name .. "：" .. text)
        M.hoverNameLabel:SetStyle({ visible = true })
        M.hoverNameLabel:SetStyle({ opacity = 1 })
    end
end

function M:_ApplyCamera()
    for _, layer in pairs(M.layers) do
        if layer.img then
            local px = layer.parallax or 1.0
            layer.img:SetStyle({ left = -M.cameraX * px })
        end
    end
    if M.charSprite then
        M.charSprite:SetStyle({ left = M.spawnX - M.cameraX })
    end
end

-- ============================================================
-- 每帧更新
-- ============================================================
function M.Update(dt)
    if M._switchCD > 0 then M._switchCD = M._switchCD - (dt or 0) end

    local sceneData = GameData.SceneObjects[M.currentSceneId]
    if not sceneData then return end

    if sceneData.mode == "screens" then
        -- 模式 B：方向键翻页（带冷却）
        if M._switchCD <= 0 and input then
            if input:GetKeyPress(KEY_LEFT) then
                M:_SwitchScreen("left"); M._switchCD = 0.25
            elseif input:GetKeyPress(KEY_RIGHT) then
                M:_SwitchScreen("right"); M._switchCD = 0.25
            end
        end
    else
        -- 模式 A：方向键滚动
        local dir = 0
        if input and input:GetKeyPress(KEY_LEFT) then dir = dir - 1 end
        if input and input:GetKeyPress(KEY_RIGHT) then dir = dir + 1 end
        if dir ~= 0 then
            M.cameraX = M.cameraX + dir * M.scrollSpeed * (dt or 0)
            M.cameraX = math.max(0, math.min(M.cameraX, M.worldWidth - M.screenW))
            M:_ApplyCamera()
        end
    end
end

function M.ExitScene()
    if M.ui and M.ui.root then
        M.ui.root:Destroy()
    end
    M.ui = { root = nil }
    M.bgFixed = {}
    M.layers = {}
    M.charSprite = nil
    M.hoverNameLabel = nil
    M.titleLabel = nil
    M.scrollHint = nil
    M.charNameLabel = nil
    M._screenPanel = nil
    M._screenLayer = nil
    M._btnLeft = nil
    M._btnRight = nil
    M._minimap = nil
    M._mmNodes = {}
    M._tutPanel = nil
end

return M
