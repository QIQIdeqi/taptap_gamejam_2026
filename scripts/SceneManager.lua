local M = {}
local GameData = require("GameData")
local UI = require("urhox-libs.UI")

-- ⚠️ 引擎 Widget:new 只接受单参数 props；UI.X(parent, props) 的 parent 会被忽略！
-- 下面 wrapper 兼容 Panel/Label/Button 的 (parent, props) 双参数形式，并自动 parent:AddChild。
-- 之前 SceneManager 误用 UI.X(parent, props)，导致所有控件以空 props 创建 → 整屏黑屏（2026-08-27 修复）。
local UI_Panel = UI.Panel
local UI_Label = UI.Label
local UI_Button = UI.Button
local function _mk(parent, props, ctor)
    if props == nil then
        return ctor(parent or {})             -- 单参数形式 UI.X(props)
    end
    local w = ctor(props)
    if parent then parent:AddChild(w) end     -- 双参数：显式挂载到 parent（引擎不会自动挂载）
    return w
end
local Panel  = function(parent, props) return _mk(parent, props, UI_Panel) end
local Label  = function(parent, props) return _mk(parent, props, UI_Label) end
local Button = function(parent, props) return _mk(parent, props, UI_Button) end
-- 键盘输入：引擎以全局变量 `input` 注入（无 Input 模块，勿 require）。
-- 屏幕尺寸：引擎以全局变量 `graphics` 注入（无 Graphics 模块），无则用 1280x720 兜底。

-- 公开回调（由 main.lua 设置）
M.onSceneChanged = nil
M.onClueCollected = nil
M.onSpecialInteract = nil
M.showSceneCharacterSprites = false

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
M._frameCount = 0
M._lastSwitch = nil
-- screens 模式状态
M._screens = nil
M._curScreenId = nil
M._screenPanel = nil
M._screenLayer = nil
M._btnLeft = nil
M._btnRight = nil
M._minimap = nil
M._mmNodes = {}
M._worldLayer = nil
M._scrollTrack = nil
M._scrollMarker = nil
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
    -- 关键：必须先销毁旧场景 UI。UI:Init() 在重复调用时会被引擎忽略（不清理旧树），
    -- 若不显式销毁，每次切场景都会在 UI 树上叠加一层完整场景，历史按钮的 onClick 依旧有效，
    -- 表现为一次点击触发多次跳转/翻页。
    M.ExitScene()

    M.currentSceneId = sceneId
    M.onExit = onExit
    M.ui = { root = nil }
    M.bgFixed = {}
    M._switchCD = 0

    UI:Init()
    local root = Panel(nil, {
        left = 0, top = 0, width = "100%", height = "100%",
        overflow = "hidden", backgroundColor = "rgba(0,0,0,255)",
    })
    M.ui.root = root

    -- 关键：挂载到 UI 渲染树。UI 仅在 UI.GetRoot() 渲染树中可见；
    -- 若不挂载，整场景游离不渲染，表现为纯黑屏（main.lua 总根背景为纯黑）。
    -- 注意 Panel(nil,...) 不会自动成为根，必须显式 AddChild（OpenScene/Menu 同此约定）。
    local uiRoot = UI.GetRoot()
    print(string.format("[SM DEBUG] EnterScene: scene=%s uiRoot=%s", tostring(sceneId), tostring(uiRoot)))
    if uiRoot then
        uiRoot:AddChild(root)
    else
        print("[SM DEBUG] EnterScene: ERROR uiRoot 为 nil，场景未挂载 -> 必然黑屏")
    end

    -- 预加载本场景所有屏的背景图：图片是远程资源、按需异步下载，
    -- 若等到翻页时才加载会先显示 bgColor 兜底色块、过一会儿才出图。
    -- 这里把各屏图片贴到屏幕外的容器中触发提前下载，翻页时即可立刻显示。
    if sceneData.screens then
        local preload = Panel(root, {
            left = -4000, top = 0, width = 1, height = 1,
            backgroundColor = "rgba(0,0,0,0)", zIndex = 1,
        })
        for _, sc in ipairs(sceneData.screens) do
            if sc.image and sc.image ~= "" then
                Panel(preload, {
                    left = 0, top = 0, width = 1, height = 1,
                    backgroundImage = sc.image, backgroundColor = "rgba(0,0,0,0)",
                })
            end
        end
    end

    -- 屏幕尺寸
    local sw, sh = 1280, 720
    if graphics then
        local dpr = graphics:GetDPR() or 1
        sw = math.floor(graphics:GetWidth() / dpr)
        sh = math.floor(graphics:GetHeight() / dpr)
    end
    M.screenW = sw
    M.screenH = sh

    -- 公共 HUD：标题固定在左上，底部中央留给卷轴提示，避免遮挡右上角系统按钮
    M.titleLabel = Label(root, {
        left = 18, top = 12, width = math.min(sw * 0.55, 560), height = 34,
        text = sceneData.title or sceneId, fontSize = 16,
        fontColor = "rgba(255,255,255,230)",
        backgroundColor = "rgba(0,0,0,150)",
        borderRadius = 6,
        padding = { 6, 10, 4, 10 },
        textAlign = "left",
        zIndex = 2000,
    })
    M.hoverNameLabel = Label(UI.GetRoot(), {
        left = 0, bottom = 70, width = sw, height = 32,
        text = "", fontSize = 16, fontColor = "rgba(255,255,255,240)", textAlign = "center",
        zIndex = 99998,
        backgroundColor = "rgba(0,0,0,160)",
        borderRadius = 4,
        padding = { 4, 12, 4, 12 },
        pointerEvents = false,
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
-- 模式 A：连续横版卷轴（酒店大堂）
-- ============================================================
function M:_EnterParallax(sceneData, root, sw, sh)
    M.worldWidth = sceneData.worldWidth
    M.groundY = sceneData.groundY or 0.78
    M.spawnX = sceneData.spawnX or 520

    local ldefs = sceneData.layers or {}
    local layerDefs = {
        { key = "background", def = ldefs.background, z = 1 },
        { key = "midground",  def = ldefs.midground,  z = 2 },
        { key = "foreground", def = ldefs.foreground, z = 3 },
    }
    for _, ld in ipairs(layerDefs) do
        if ld.def and ld.def.image then
            local img = Panel(root, {
                backgroundImage = ld.def.image,
                backgroundFit = "cover",
                left = 0, top = 0, width = M.worldWidth, height = sh,
                zIndex = ld.z,
                overflow = "hidden",
            })
            M.layers[ld.key] = { img = img, parallax = ld.def.parallax or 1.0, baseLeft = 0 }
            if M.bgFixed[ld.key] == nil then M.bgFixed[ld.key] = false end
        end
    end

    -- 单独的世界层承载所有物件和出口；镜头只移动这一层，避免逐个修正热区坐标造成漂移。
    M._worldLayer = Panel(root, {
        position = "absolute",
        left = 0, top = 0, width = M.worldWidth, height = sh,
        overflow = "hidden", pointerEvents = "box-none", zIndex = 10,
    })

    -- 主角不显示立绘，保留世界层顺序供后续角色接入。
    M.charSprite = nil

    -- 交互物件与出口均使用世界坐标，随世界层一起移动。
    if sceneData.items then
        for _, item in ipairs(sceneData.items) do
            M:_makeItemBtn(item, sw, sh, false, M._worldLayer)
        end
    end
    if sceneData.exits then
        for _, ex in ipairs(sceneData.exits) do
            M:_makeExitBtn(ex, sw, sh, false, M._worldLayer)
        end
    end

    -- 固定 HUD：左下是卷轴进度，中央是操作提示，右下保留笔记入口。
    local trackW = math.min(300, math.max(220, sw * 0.26))
    M._scrollTrack = Panel(root, {
        position = "absolute",
        left = 18, bottom = 20, width = trackW, height = 8,
        backgroundColor = "rgba(0,0,0,170)", borderRadius = 4, zIndex = 2000,
    })
    M._scrollMarker = Panel(M._scrollTrack, {
        position = "absolute",
        left = 0, top = 0, width = 18, height = 8,
        backgroundColor = "rgba(255,200,90,255)", borderRadius = 4, zIndex = 2001,
    })
    M.scrollHint = Label(root, {
        position = "absolute",
        left = trackW + 34, right = 120, bottom = 12, height = 24,
        text = "◀ / ▶ 移动视角 · 点击高亮区域调查", fontSize = 14,
        fontColor = "rgba(255,255,255,185)", textAlign = "center", zIndex = 2000,
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
    local spriteRect = item.spriteRect
    local renderLeft = spriteRect and spriteRect.x * sw or left
    local renderTop = spriteRect and spriteRect.y * sh or top
    local renderW = spriteRect and spriteRect.w * sw or w
    local renderH = spriteRect and spriteRect.h * sh or h
    -- 独立交互贴图：物件本体单独渲染，按钮只负责命中点击，不再用框体代替物件。
    -- NPC 立绘仍受 showSceneCharacterSprites 开关控制。
    local spritePanel = nil
    local highlightPanel = nil
    local spriteLeft, spriteTop, spriteW, spriteH = renderLeft, renderTop, renderW, renderH
    local renderSprite = item.sprite
    local outlineSprite = nil
    if item.interactiveSprite == true and type(item.sprite) == "string" then
        local trimSprite = item.sprite:gsub("%.png$", "_trim.png")
        local candidateOutline = item.sprite:gsub("%.png$", "_outline.png")
        if item.spriteTrim and fileSystem and fileSystem:FileExists(trimSprite) then renderSprite = trimSprite end
        if item.spriteTrim and fileSystem and fileSystem:FileExists(candidateOutline) then outlineSprite = candidateOutline end
    end
    local hasSprite = ((item.interactiveSprite == true) or M.showSceneCharacterSprites)
        and (type(item.sprite) == "string") and (item.sprite ~= "")
    if hasSprite then
        if item.interactiveSprite == true then
            spriteLeft = renderLeft + (item.spriteOffsetX or 0) * sw
            spriteTop = renderTop + (item.spriteOffsetY or 0) * sh
            spriteW = renderW * (item.spriteScale or 1.0)
            spriteH = renderH * (item.spriteScale or 1.0)
            spritePanel = Panel(parent, {
                position = "absolute",
                left = spriteLeft, top = spriteTop, width = spriteW, height = spriteH,
                backgroundImage = renderSprite,
                backgroundFit = "contain",
                backgroundPosition = item.backgroundPosition or "center bottom",
                backgroundColor = "rgba(0,0,0,0)",
                zIndex = 50,
                pointerEvents = "none",
            })
            highlightPanel = Panel(parent, {
                position = "absolute",
                left = spriteLeft, top = spriteTop, width = spriteW, height = spriteH,
                backgroundImage = outlineSprite or "",
                backgroundFit = "contain",
                backgroundColor = "rgba(255,220,120,0)",
                borderWidth = 0, borderColor = "rgba(255,220,120,0)",
                zIndex = 55,
                pointerEvents = "none",
            })
        else
            local s = item.spriteScale or 1.0
            local ratio = item.spriteRatio or (2.0 / 3.0)
            local ph, pw = h * s, h * s * ratio
            if pw > w then pw, ph = w, w / ratio end
            spriteLeft, spriteTop, spriteW, spriteH = left + (w - pw) / 2, top + (h - ph), pw, ph
            spritePanel = Panel(parent, {
                position = "absolute",
                left = spriteLeft, top = spriteTop, width = spriteW, height = spriteH,
                backgroundImage = renderSprite,
                backgroundFit = "contain",
                backgroundPosition = item.backgroundPosition or "center bottom",
                backgroundColor = "rgba(0,0,0,0)",
                zIndex = 50,
                pointerEvents = "none",
            })
        end
    end

    -- Wolai 修改 5：交互物不再常驻框体；悬停时放大 20% 并显示边缘光，按下恢复原尺寸，松开再放大。
    local hoverScale = item.hoverScale or 1.2
    local hovered = false
    local btn
    local function setInteractionStyle(scale, active)
        local sw2, sh2 = w * scale, h * scale
        if spritePanel and item.interactiveSprite == true then
            local dx = (spriteW * scale - spriteW) / 2
            local dy = (spriteH * scale - spriteH) / 2
            local glowLeft = spriteLeft - dx
            local glowTop = spriteTop - dy
            local glowW = spriteW * scale
            local glowH = spriteH * scale
            spritePanel:SetStyle({ left = glowLeft, top = glowTop, width = glowW, height = glowH })
            if highlightPanel then
                highlightPanel:SetStyle({
                    left = glowLeft - 4, top = glowTop - 4, width = glowW + 8, height = glowH + 8,
                    visible = active and true or false,
                    backgroundColor = active and "rgba(255,220,120,18)" or "rgba(255,220,120,0)",
                })
            end
        end
        btn:SetStyle({
            left = left - (sw2 - w) / 2,
            top = top - (sh2 - h) / 2,
            width = sw2,
            height = sh2,
            borderWidth = active and 3 or 0,
            borderColor = active and "rgba(255,220,120,235)" or "rgba(255,255,255,0)",
            backgroundColor = active and "rgba(255,220,120,24)" or "rgba(255,255,255,0)",
        })
    end

    btn = Button(parent, {
        position = "absolute",
        left = left, top = top, width = w, height = h,
        backgroundColor = "rgba(255,255,255,0)",
        borderWidth = 0, borderColor = "rgba(255,255,255,0)",
        zIndex = 100,
    })
    btn.props.onPointerEnter = function(event, widget)
        hovered = true
        setInteractionStyle(hoverScale, true)
        if M.hoverNameLabel then
            M.hoverNameLabel:SetText(item.name)
            M.hoverNameLabel:SetStyle({ visible = true })
        end
    end
    btn.props.onPointerLeave = function(event, widget)
        hovered = false
        setInteractionStyle(1.0, false)
        if M.hoverNameLabel then M.hoverNameLabel:SetStyle({ visible = false }) end
    end
    btn.props.onPointerDown = function(event, widget)
        setInteractionStyle(1.0, false)
    end
    btn.props.onPointerUp = function(event, widget)
        if hovered then setInteractionStyle(hoverScale, true) end
    end
    btn.props.onClick = function()
        print(string.format("[SM DEBUG] item clicked: %s", tostring(item.id)))
        M:_onItemInteract(item)
    end
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
    local hoverScale = 1.12
    local hovered = false
    local btn = Button(parent, {
        position = "absolute",
        left = left, top = top, width = w, height = h,
        backgroundColor = "rgba(120,200,255,0)",
        borderWidth = 0, borderColor = "rgba(120,200,255,0)",
        zIndex = 100,
    })
    local function setExitStyle(scale, active)
        local sw2, sh2 = w * scale, h * scale
        btn:SetStyle({
            left = left - (sw2 - w) / 2,
            top = top - (sh2 - h) / 2,
            width = sw2,
            height = sh2,
            borderWidth = active and 3 or 0,
            borderColor = active and "rgba(120,200,255,235)" or "rgba(120,200,255,0)",
            backgroundColor = active and "rgba(120,200,255,28)" or "rgba(120,200,255,0)",
        })
    end
    btn.props.onPointerEnter = function(event, widget)
        hovered = true
        setExitStyle(hoverScale, true)
        if M.hoverNameLabel then
            M.hoverNameLabel:SetText(ex.label or "前往")
            M.hoverNameLabel:SetStyle({ visible = true })
        end
    end
    btn.props.onPointerLeave = function(event, widget)
        hovered = false
        setExitStyle(1.0, false)
        if M.hoverNameLabel then M.hoverNameLabel:SetStyle({ visible = false }) end
    end
    btn.props.onPointerDown = function(event, widget)
        setExitStyle(1.0, false)
    end
    btn.props.onPointerUp = function(event, widget)
        if hovered then setExitStyle(hoverScale, true) end
    end
    btn.props.onClick = function()
        print(string.format("[SM DEBUG] exit clicked: %s -> %s", tostring(ex.id), tostring(ex.targetScene)))
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
    M._screenPanel = Panel(root, {
        left = 0, top = 0, width = sw, height = sh,
        backgroundImage = "", backgroundColor = "rgba(20,20,30,255)",
        overflow = "hidden", backgroundPosition = "center center",
        pointerEvents = "box-none",
    })
    -- 承载当前 screen 的物件/出口/主角
    M._screenLayer = Panel(M._screenPanel, {
        left = 0, top = 0, width = sw, height = sh, overflow = "hidden",
        pointerEvents = "box-none",
    })

    -- 翻页按钮（◀ ▶）— 挂到 _screenPanel（与 _screenLayer 同容器，已验证可渲染且命中测试能穿透到其子节点）；
    -- position:absolute 脱离布局流，zIndex 高于物件层确保位于最上层可点击
    M._btnLeft = Button(M._screenPanel, {
        position = "absolute",
        left = 18, top = sh / 2 - 30, width = 56, height = 56,
        backgroundColor = "rgba(18,16,30,235)", borderRadius = 12,
        borderWidth = 2, borderColor = "rgba(255,210,120,230)",
        zIndex = 2001, hoverCursor = "pointer",
    })
    Label(M._btnLeft, {
        left = 0, top = 0, width = 56, height = 56,
        text = "◀", fontSize = 30, fontColor = "rgba(255,255,255,255)",
        textAlign = "center", alignItems = "center", justifyContent = "center",
    })
    M._btnLeft.props.onClick = function() print("[SM DEBUG] btnLeft clicked"); M:_SwitchScreen("left") end
    M._btnRight = Button(M._screenPanel, {
        position = "absolute",
        left = sw - 18 - 56, top = sh / 2 - 30, width = 56, height = 56,
        backgroundColor = "rgba(18,16,30,235)", borderRadius = 12,
        borderWidth = 2, borderColor = "rgba(255,210,120,230)",
        zIndex = 2001, hoverCursor = "pointer",
    })
    Label(M._btnRight, {
        left = 0, top = 0, width = 56, height = 56,
        text = "▶", fontSize = 30, fontColor = "rgba(255,255,255,255)",
        textAlign = "center", alignItems = "center", justifyContent = "center",
    })
    M._btnRight.props.onClick = function() print("[SM DEBUG] btnRight clicked"); M:_SwitchScreen("right") end

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
    print(string.format("[SM DEBUG] _EnterScreens done: navLayer=%s btnLeft=%s btnRight=%s",
        tostring(M._navLayer ~= nil), tostring(M._btnLeft ~= nil), tostring(M._btnRight ~= nil)))
end

function M:_GetScreen(id)
    for _, s in ipairs(M._screens) do
        if s.id == id then return s end
    end
    return nil
end

function M:_BuildScreenContent(screenId)
    local screen = M:_GetScreen(screenId)
    print(string.format("[SM DEBUG] _BuildScreenContent: id=%s found=%s",
        tostring(screenId), tostring(screen ~= nil)))
    if not screen then
        print("[SM DEBUG] _BuildScreenContent: screen NOT FOUND -> 保持兜底近黑色背景（黑屏）")
        return
    end
    print(string.format("[SM DEBUG] _BuildScreenContent: image=%s bgColor=%s",
        tostring(screen.image), tostring(screen.bgColor and screen.bgColor[1])))
    M._curScreenId = screenId
    local sw, sh = M.screenW, M.screenH

    -- 整图背景（兜底底色 + 真实图若存在）
    M._screenPanel:SetStyle({ backgroundColor = _rgba(screen.bgColor) })
    M._screenPanel:SetStyle({
        backgroundImage = screen.image or "",
        backgroundFit = screen.backgroundFit or "cover",
        backgroundPosition = screen.backgroundPosition or "center center",
    })

    -- 重建承载层
    if M._screenLayer then M._screenLayer:Destroy() end
    M._screenLayer = Panel(M._screenPanel, {
        left = 0, top = 0, width = sw, height = sh, overflow = "hidden",
        pointerEvents = "box-none",
    })

    -- 主角（默认隐藏；2D 横板推理探索模式不显示角色立绘，避免遮挡交互 UI）
    local cp = screen.charPos or { x = 0.5, y = 0.78, scale = 0.58 }
    local charH = sh * (cp.scale or 0.58)
    local charX = cp.x * sw - charH * 0.25
    local charY = sh * cp.y - charH
    M.charSprite = Panel(M._screenLayer, {
        backgroundImage = "assets/image/char_lizhi.png",
        backgroundFit = "contain",
        backgroundColor = "rgba(0,0,0,0)",
        left = charX, top = charY, width = charH * 0.5, height = charH,
        zIndex = 5,
        visible = false,
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
    -- 防抖：引擎会以约 100-180ms 周期反复派发 onClick（场景重建后按钮重新获得焦点）。
    -- 用 M._gameTime（Update 中按 dt 累加的真实墙钟时间）判断，不可用 os.clock()。
    -- 冷却 120ms：拦住引擎连锁（>100ms），但不影响人类连点（>200ms/次）。
    local now = M._gameTime or 0
    if M._lastSwitch and M._lastSwitch.dir == dir and (now - M._lastSwitch.t) < 0.12 then
        return
    end
    M._lastSwitch = { t = now, dir = dir }
    print(string.format("[SM DEBUG] _SwitchScreen dir=%s cur=%s", tostring(dir), tostring(M._curScreenId)))
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
    -- 首屏无左邻、末屏无右邻时完全禁用按钮：
    -- 用 opacity=0 完全透明替代 visible=false（此引擎 visible 属性可能不生效），
    -- 同时在 onClick 中检查方向有效性作为双重保险。
    if M._btnLeft then
        if screen.left then
            M._btnLeft:SetStyle({ opacity = 1 })
            M._btnLeft.props.onClick = function() print("[SM DEBUG] btnLeft clicked"); M:_SwitchScreen("left") end
        else
            M._btnLeft:SetStyle({ opacity = 0 })
            M._btnLeft.props.onClick = nil
        end
    end
    if M._btnRight then
        if screen.right then
            M._btnRight:SetStyle({ opacity = 1 })
            M._btnRight.props.onClick = function() print("[SM DEBUG] btnRight clicked"); M:_SwitchScreen("right") end
        else
            M._btnRight:SetStyle({ opacity = 0 })
            M._btnRight.props.onClick = nil
        end
    end
end

-- 小地图（右上角拓扑缩略图）
function M:_BuildMinimap(sceneData, root, sw, sh)
    local mmData = sceneData.minimap
    if not mmData then return end
    local mw, mh = 130, 90
    M._minimap = Panel(root, {
        right = 12, top = 48, width = mw, height = mh,
        backgroundColor = "rgba(12,10,20,200)", borderRadius = 8,
        borderWidth = 1, borderColor = "rgba(255,255,255,38)", overflow = "hidden",
        zIndex = 2000,
    })
    M._mmNodes = {}
    local pad = 12
    local innerW, innerH = mw - pad * 2, mh - pad * 2
    for _, node in ipairs(mmData.nodes) do
        local nx = pad + (node.nx or 0.5) * innerW
        local ny = pad + (node.ny or 0.5) * innerH
        local dot = Panel(M._minimap, {
            left = nx - 5, top = ny - 5, width = 10, height = 10,
            borderRadius = 5, backgroundColor = "rgba(255,255,255,120)",
        })
        local lbl = Label(M._minimap, {
            left = nx - 24, top = ny + 6, width = 48, height = 16,
            text = node.label or "", fontSize = 10, fontColor = "rgba(255,255,255,160)", textAlign = "center",
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
    M._tutPanel = Panel(root, {
        left = sw / 2 - 200, top = sh / 2 - 50, width = 400, height = 100,
        backgroundColor = "rgba(20,18,30,235)", borderRadius = 12,
        borderWidth = 1, borderColor = "rgba(255,255,255,30)", zIndex = 100,
    })
    local tip = Label(M._tutPanel, {
        left = 16, top = 16, width = 368, height = 68,
        text = text, fontSize = 15, fontColor = "rgba(255,255,255,235)", textAlign = "center",
    })
    local overlay = Button(root, {
        left = 0, top = 0, width = sw, height = sh,
        backgroundColor = "rgba(0,0,0,0)", zIndex = 5, borderWidth = 0,
        pointerEvents = "box-none",
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
    -- 引擎会周期性反复派发 onClick，用 M._gameTime（真实墙钟时间）做防抖，
    -- 同一物件 600ms 内只响应一次，避免重复弹横幅/重复收录（不可用 os.clock()）。
    local now = M._gameTime or 0
    if item.id == M._itemLastId and (now - (M._itemLastTime or 0)) < 0.6 then
        print(string.format("[SM DEBUG] _onItemInteract SKIPPED(debounce): id=%s dt=%.3f",
            tostring(item.id), now - (M._itemLastTime or 0)))
        return
    end
    print(string.format("[SM DEBUG] _onItemInteract RUN: id=%s clueId=%s dialogueId=%s onInteract=%s gt=%.2f",
        tostring(item.id), tostring(item.clueId), tostring(item.dialogueId),
        tostring(item.onInteract), now))
    M._itemLastId, M._itemLastTime = item.id, now
    if item.clueId then
        local isNew = GameData.CollectClue(item.clueId)
        GameData.SetFlag("clue_" .. item.clueId, true)
        local clueDef = GameData.Clues[item.clueId]
        local name = (clueDef and clueDef.name) or item.name or item.clueId
        -- 若该线索会触发对话/特殊交互，对话本身即反馈，不再弹冗余的"线索收录"提示框（避免黄框→延迟→对话的割裂感）
        local hasDialogue = item.dialogueId or item.onInteract
        if not hasDialogue and M.onClueCollected then
            print(string.format("[SM DEBUG] calling onClueCollected: %s isNew=%s", item.clueId, tostring(isNew)))
            M.onClueCollected(item.clueId, name, not isNew)
        end
    end
    if item.onInteract then
        if M.onSpecialInteract then M.onSpecialInteract(item) end
    elseif item.dialogueId then
        -- 普通/误导物件：弹出角色独白对话（替代金边横幅）
        local DialogueSystem = require("scripts.DialogueSystem")
        DialogueSystem.Start(item.dialogueId, nil)
    elseif item.interactText then
        print(string.format("[SM DEBUG] ShowClueBanner: %s", item.name))
        M:ShowClueBanner(item.name, item.interactText)
    end
end

function M:ShowClueBanner(name, text)
    -- 挂到绝对根，确保永远在 UI 最上层（不受 scene root 的 overflow 裁剪）
    local root = UI.GetRoot() or M.ui.root
    if not root then return end

    -- 若已有横幅在显示，先销毁旧的，避免多次点击后横幅叠加
    if M._activeBanner then
        pcall(function() M._activeBanner:Destroy() end)
        M._activeBanner = nil
    end

    local banner = UI.Panel({
        position = "absolute",
        left = "calc(50% - 260px)", top = "calc(50% - 80px)", width = 520, height = 160,
        backgroundColor = { 20, 16, 8, 245 }, borderRadius = 14,
        borderWidth = 3, borderColor = { 255, 200, 80, 255 }, zIndex = 99999,
    })
    banner:AddChild(UI.Label({
        position = "absolute",
        left = 0, top = 22, width = 520, height = 36,
        text = "【" .. (name or "") .. "】", fontSize = 22, fontColor = { 255, 200, 80, 255 }, textAlign = "center",
    }))
    banner:AddChild(UI.Label({
        position = "absolute",
        left = 24, top = 70, width = 472, height = 64,
        text = text or "", fontSize = 17, fontColor = { 255, 245, 225, 255 }, textAlign = "center",
    }))
    root:AddChild(banner)
    M._activeBanner = banner

    -- 3 秒后自动消失 + 淡出
    local ttl = 3.0
    local closeTimer = nil
    closeTimer = function()
        ttl = ttl - (1 / 60)
        if ttl <= 0 or not banner or not banner.props then
            if banner and banner.Destroy then banner:Destroy() end
            if M._activeBanner == banner then M._activeBanner = nil end
            return
        end
        if ttl < 0.6 then
            banner:SetStyle({ opacity = ttl / 0.6 })
        end
    end
    M._bannerTimers = M._bannerTimers or {}
    table.insert(M._bannerTimers, { fn = closeTimer, banner = banner })
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
    if M._worldLayer then
        M._worldLayer:SetStyle({ left = -M.cameraX })
    end
    if M._scrollTrack and M._scrollMarker and M.worldWidth > M.screenW then
        local maxCamera = M.worldWidth - M.screenW
        local trackW = M._scrollTrack.props and M._scrollTrack.props.width or 300
        local markerW = M._scrollMarker.props and M._scrollMarker.props.width or 18
        local maxLeft = math.max(0, trackW - markerW)
        M._scrollMarker:SetStyle({ left = maxLeft * (M.cameraX / maxCamera) })
    end
end

-- ============================================================
-- 每帧更新
-- ============================================================
function M.Update(dt)
    M._frameCount = (M._frameCount or 0) + 1
    -- 真实经过时间（秒）。注意：不能用 os.clock()——它返回 CPU 时间而非墙钟时间，
    -- Lua 脚本执行极快导致其增量远小于真实间隔，会使所有时间防抖误判为「短时间内重复」。
    M._gameTime = (M._gameTime or 0) + (dt or 0)
    if M._switchCD > 0 then M._switchCD = M._switchCD - (dt or 0) end

    -- 处理横幅自动消失定时器
    if M._bannerTimers then
        local alive = {}
        for _, t in ipairs(M._bannerTimers) do
            if t.banner and t.banner.props then
                t.fn()
                if t.banner.props then table.insert(alive, t) end
            end
        end
        M._bannerTimers = #alive > 0 and alive or nil
    end

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
    -- hoverNameLabel / 翻页按钮 挂到 UI.GetRoot()，需单独清理
    if M.hoverNameLabel then
        M.hoverNameLabel:Destroy()
        M.hoverNameLabel = nil
    end
    if M._btnLeft then
        M._btnLeft:Destroy()
        M._btnLeft = nil
    end
    if M._btnRight then
        M._btnRight:Destroy()
        M._btnRight = nil
    end
    -- 线索横幅挂在绝对根上、靠 _bannerTimers 中的定时器销毁。
    -- 若这里只清空列表而不销毁，正在显示的横幅会变成永不回收的孤儿 UI 残留在屏幕上。
    if M._bannerTimers then
        for _, t in ipairs(M._bannerTimers) do
            if t and t.banner and t.banner.Destroy then
                pcall(function() t.banner:Destroy() end)
            end
        end
    end
    if M._activeBanner and M._activeBanner.Destroy then
        pcall(function() M._activeBanner:Destroy() end)
    end
    M._activeBanner = nil
    M._bannerTimers = nil

    if M.ui and M.ui.root then
        M.ui.root:Destroy()
    end
    M.ui = { root = nil }
    M.bgFixed = {}
    M.layers = {}
    M._worldLayer = nil
    M._scrollTrack = nil
    M._scrollMarker = nil
    -- 重置防抖状态，避免切场景后残留导致新场景首次点击被误拦截
    M._itemLastId, M._itemLastTime = nil, nil
    M._lastSwitch = nil
    M.charSprite = nil
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
    M._bannerTimers = nil
end

return M
