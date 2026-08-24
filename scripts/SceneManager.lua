-- ============================================================================
-- SceneManager.lua - 场景管理器
-- 管理场景切换、物件交互、悬停描边/名称提示、线索收集
-- ============================================================================

local UI = require("urhox-libs.UI")

local M = {}

M.sceneBackgrounds = {
    office = "assets/image/bg_office.png",
    hotel_lobby = "assets/image/bg_hotel_lobby.png",
    hotel_courtyard = "assets/image/bg_hotel_courtyard.png",
    hotel_corridor = "assets/image/bg_hotel_corridor.png",
    crime_scene = "assets/image/bg_crime_scene.png",
}

M.currentScene = nil
M.currentObjects = {}
M.currentExits = {}
M.onExit = nil                     -- 离开场景回调（可选）
M.onSceneChanged = nil             -- 场景切换回调 function(sceneId)
M.onClueCollected = nil            -- 线索收集回调 function(clueId)
M.onSpecialInteract = nil          -- 特殊交互回调 function(obj, onComplete)

M.ui = {
    root = nil,
    objectButtons = {},
    exitButtons = {},
    clueBanner = nil,
    clueBannerText = nil,
    clueBannerTimer = 0,
    hoverNameLabel = nil,
}

-- ============================================================================
-- 进入场景
-- ============================================================================

function M.EnterScene(sceneId, onExit)
    local GameData = require("scripts.GameData")
    local sceneData = GameData.GetSceneData(sceneId)
    if not sceneData then return end

    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end

    M.currentScene = sceneId
    M.currentObjects = sceneData.items or {}
    M.currentExits = sceneData.exits or {}
    M.onExit = onExit

    M.BuildUI()

    if M.onSceneChanged then
        M.onSceneChanged(sceneId)
    end
end

-- ============================================================================
-- 构建场景UI
-- ============================================================================

function M.BuildUI()
    M.ui.objectButtons = {}
    M.ui.exitButtons = {}

    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 0 },
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }

    -- ===== 场景标题 =====
    local GameData = require("scripts.GameData")
    local sceneData = GameData.GetSceneData(M.currentScene)
    M.ui.root:AddChild(UI.Label {
        text = sceneData.title or "",
        fontSize = 20,
        fontColor = { 240, 235, 225, 220 },
        position = "absolute",
        left = 24, top = 16,
    })

    -- ===== 可交互物件按钮 =====
    for _, obj in ipairs(M.currentObjects) do
        local btn = M.ui.root:AddChild(UI.Button {
            text = "",
            variant = "secondary",
            position = "absolute",
            left = (obj.x * 100) .. "%",
            top = (obj.y * 100) .. "%",
            width = (obj.w * 100) .. "%",
            height = (obj.h * 100) .. "%",
            backgroundColor = { 255, 255, 255, 0 },
            hoverBackgroundColor = { 255, 255, 100, 46 },
            borderWidth = 2,
            borderColor = { 255, 255, 255, 50 },
            onClick = function()
                M.OnObjectClick(obj)
            end,
            onPointerEnter = function(_, widget)
                M.OnObjectHover(obj, widget, true)
            end,
            onPointerLeave = function(_, widget)
                M.OnObjectHover(obj, widget, false)
            end,
        })

        M.ui.objectButtons[obj.id] = btn
    end

    -- ===== 场景出口（导航） =====
    for _, exit in ipairs(M.currentExits) do
        local btn = M.ui.root:AddChild(UI.Button {
            text = exit.label or "→",
            fontSize = 14,
            variant = "secondary",
            position = "absolute",
            left = (exit.x * 100) .. "%",
            top = (exit.y * 100) .. "%",
            width = (exit.w * 100) .. "%",
            height = (exit.h * 100) .. "%",
            backgroundColor = { 60, 120, 200, 40 },
            hoverBackgroundColor = { 60, 160, 255, 80 },
            borderWidth = 1,
            borderColor = { 120, 180, 255, 80 },
            onClick = function()
                M.EnterScene(exit.targetScene, nil)
            end,
        })

        M.ui.exitButtons[exit.id] = btn
    end

    -- ===== 线索收集提示横幅 =====
    M.ui.clueBanner = M.ui.root:AddChild(UI.Panel {
        position = "absolute",
        left = "25%", top = "12%",
        width = "50%",
        backgroundColor = { 30, 25, 15, 230 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 200, 180, 100, 200 },
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        padding = 10,
        visible = false,
    })

    M.ui.clueBannerText = M.ui.clueBanner:AddChild(UI.Label {
        text = "",
        fontSize = 20,
        fontColor = { 255, 230, 100, 255 },
        textAlign = "center",
    })

    -- ===== 悬停名称提示（右侧） =====
    M.ui.hoverNameLabel = M.ui.root:AddChild(UI.Label {
        text = "",
        fontSize = 18,
        fontColor = { 255, 240, 180, 255 },
        position = "absolute",
        right = 40, top = "45%",
        backgroundColor = { 20, 16, 30, 200 },
        borderRadius = 6,
        padding = 8,
        visible = false,
    })

    M.ui.root:Show()
end

-- ============================================================================
-- 物件悬停：描边 + 名称提示
-- ============================================================================

function M.OnObjectHover(obj, widget, entering)
    if entering then
        -- 描边高亮
        widget:SetStyle({ borderColor = { 255, 255, 100, 255 } })
        -- 显示名称提示
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
-- 物件点击处理
-- ============================================================================

function M.OnObjectClick(obj)
    local GameData = require("scripts.GameData")
    local DialogueSystem = require("scripts.DialogueSystem")

    if DialogueSystem.IsActive() then return end

    local interactText = obj.interactText or "..."

    -- 收集线索
    local newClue = false
    if obj.clueId then
        newClue = GameData.CollectClue(obj.clueId)
    end

    if newClue and obj.clueId then
        local clue = GameData.GetClue(obj.clueId)
        if clue then
            M.ShowClueBanner("获得线索：" .. clue.name)
        end
        if M.onClueCollected then
            M.onClueCollected(obj.clueId)
        end
    end

    -- 特殊交互（如衣柜触发剧情推进）
    if obj.onInteract and M.onSpecialInteract then
        M.onSpecialInteract(obj, function()
            M.ShowInteraction(interactText)
        end)
    else
        M.ShowInteraction(interactText)
    end
end

function M.ShowInteraction(interactText)
    local DialogueSystem = require("scripts.DialogueSystem")
    DialogueSystem.Start({
        id = "interaction",
        lines = {
            { speaker = "LiZhi", text = interactText },
        },
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
-- 更新
-- ============================================================================

function M.Update(deltaTime)
    if M.ui.clueBannerTimer and M.ui.clueBannerTimer > 0 then
        M.ui.clueBannerTimer = M.ui.clueBannerTimer - deltaTime
        if M.ui.clueBannerTimer <= 0 then
            if M.ui.clueBanner then
                M.ui.clueBanner:SetVisible(false)
            end
        end
    end
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
    M.currentObjects = {}
    M.currentExits = {}
end

-- ============================================================================
-- 场景背景渲染
-- ============================================================================

function M.DrawBackground()
    if not M.currentScene then return end

    local screenW = graphics:GetWidth()
    local screenH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local logicalW = screenW / dpr
    local logicalH = screenH / dpr

    local bgPath = M.sceneBackgrounds[M.currentScene]
    if bgPath then
        local texture = cache:GetTexture(bgPath)
        if texture then
            local sprite = Sprite()
            sprite:SetTexture(texture)
            sprite:Draw(Vector2(0, 0), Vector2(logicalW, logicalH))
            return
        end
    end

    local sceneColors = {
        office = { 45, 40, 55, 255 },
        hotel_lobby = { 35, 45, 65, 255 },
        hotel_courtyard = { 40, 55, 45, 255 },
        hotel_corridor = { 50, 45, 40, 255 },
        crime_scene = { 30, 25, 35, 255 },
    }
    local bgColor = sceneColors[M.currentScene] or { 40, 40, 40, 255 }

    nvgBeginFrame(logicalW, logicalH)
    nvgFillColor(bgColor)
    nvgRect(0, 0, logicalW, logicalH)
    nvgFill()
    nvgEndFrame()
end

return M
