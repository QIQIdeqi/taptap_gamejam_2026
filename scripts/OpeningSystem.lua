-- ============================================================================
-- OpeningSystem.lua - 开场动画系统
-- 文档 3.1 / 第二阶段 1.1
-- 流程：黑屏显示"时间 / 地点"3秒（淡出） -> 依次播放分镜对话 -> 完成回调
-- ============================================================================

local UI = require("urhox-libs.UI")

local M = {}

M.state = {
    active = false,
    phase = "location",     -- location(显示时间地点) / dialogue(播放对话) / done
    timer = 0,
    opening = nil,
    dialogueIndex = 1,
    onComplete = nil,
    transition = nil,       -- 镜头切换过渡 { t, dur, from, to }
}

M.ui = {
    root = nil,
    timeLabel = nil,
    locationLabel = nil,
    -- 分镜画面：双缓冲，切换时前后景交叉淡入淡出实现"镜头切换"
    shotA = nil,
    shotB = nil,
    shotFront = nil,
    shotBack = nil,
}

-- 默认镜头切换时长（秒）
local DEFAULT_SHOT_FADE = 0.6

-- ============================================================================
-- 启动开场动画
-- ============================================================================
function M.Start(openingId, onComplete)
    local GameData = require("scripts.GameData")
    local opening = GameData.GetOpening(openingId)
    if not opening then
        if onComplete then onComplete() end
        return
    end

    M.state.active = true
    M.state.phase = "location"
    M.state.timer = 0
    M.state.opening = opening
    M.state.dialogueIndex = 1
    M.state.onComplete = onComplete

    M.BuildLocationUI()
end

-- ============================================================================
-- 停止（清理）
-- ============================================================================
function M.Stop()
    M.state.active = false
    M.state.phase = "done"
    M.DestroyUI()
end

function M.IsActive()
    return M.state.active
end

-- 跳过按钮：挂到 UI.GetRoot() 最顶层，确保不被 DialogueSystem 全屏面板遮挡
local function _AddSkipButton()
    local uiRoot = UI.GetRoot()
    if not uiRoot then return nil end
    local btn = UI.Button {
        position = "absolute",
        top = 16, right = 16,
        width = 64, height = 34,
        backgroundColor = { 0, 0, 0, 130 },
        borderWidth = 1, borderColor = { 255, 255, 255, 100 },
        borderRadius = 6,
        text = "跳过 ›",
        fontColor = { 255, 255, 255, 230 },
        fontSize = 16,
        zIndex = 99999,
        onClick = function(self, event)
            M.Finish()
        end,
    }
    uiRoot:AddChild(btn)
    return btn
end

-- ============================================================================
-- 显示时间地点黑屏UI
-- ============================================================================
function M.BuildLocationUI()
    M.DestroyUI()

    local opening = M.state.opening or { time = "", location = "" }
    local firstBg = M.GetOpeningDialogueBackground(1)

    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 6, 5, 12, 255 },
        backgroundImage = firstBg,
        backgroundFit = "cover",
        flexDirection = "column",
        alignItems = "center",
        justifyContent = "center",
        gap = 18,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }

    -- 暗化遮罩：保证时间/地点文字可读
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 150 },
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }
    M.ui.root:AddChild(overlay)

    M.ui.timeLabel = UI.Label {
        text = opening.time or "",
        fontSize = 34,
        fontColor = { 230, 225, 215, 255 },
        fontWeight = "bold",
        textAlign = "center",
    }
    M.ui.root:AddChild(M.ui.timeLabel)

    M.ui.locationLabel = UI.Label {
        text = opening.location or "",
        fontSize = 22,
        fontColor = { 180, 175, 165, 255 },
        textAlign = "center",
    }
    M.ui.root:AddChild(M.ui.locationLabel)

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
    M._skipBtn = _AddSkipButton()
end

function M.DestroyUI()
    if M._skipBtn then
        M._skipBtn:Destroy()
        M._skipBtn = nil
    end
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    M.DestroyShotPanels()
    M.ui.timeLabel = nil
    M.ui.locationLabel = nil
end

-- ============================================================================
-- 分镜画面（镜头）
-- 一个"镜头" = 全屏背景图 + 暗化遮罩 + 角色立绘层
-- 双缓冲：切换时前后景交叉淡入淡出，做出真正的镜头切换，而不是瞬间换图
-- ============================================================================

function M.CreateShotPanel()
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 6, 5, 12, 255 },
        backgroundFit = "cover",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        pointerEvents = "none",
    }
    -- 暗化遮罩：保证对话文字可读
    panel:AddChild(UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 150 },
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    })
    return panel
end

-- 把某个分镜的内容（背景 + 角色站位）填进镜头面板
function M.FillShot(panel, dialogueId)
    if not panel then return end
    local GameData = require("scripts.GameData")

    local dlg = GameData.GetDialogue(dialogueId)
    local bg = (dlg and dlg.background and dlg.background ~= "") and dlg.background or ""
    pcall(function() panel:SetStyle({ backgroundImage = bg }) end)
    print(string.format("[OPEN DEBUG] FillShot: id=%s bg=%s", tostring(dialogueId), tostring(bg)))

    -- 清掉上一镜的角色层
    if panel._actorLayer then
        pcall(function() panel._actorLayer:Destroy() end)
        panel._actorLayer = nil
    end
    local actorLayer = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 0 },
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }
    panel:AddChild(actorLayer)
    panel._actorLayer = actorLayer

    local shot = GameData.OpeningShots and GameData.OpeningShots[dialogueId]
    if not (shot and shot.actors) then return end

    local sw, sh = graphics:GetWidth(), graphics:GetHeight()
    for _, a in ipairs(shot.actors) do
        -- 立绘按原始比例绘制，底部对齐 a.y、水平以 a.x 为中心
        local ph = (a.h or 0.5) * sh
        local pw = ph * (a.ratio or 0.671)
        actorLayer:AddChild(UI.Panel {
            position = "absolute",
            left = (a.x or 0.5) * sw - pw / 2,
            top = (a.y or 0.9) * sh - ph,
            width = pw, height = ph,
            backgroundImage = a.sprite,
            backgroundFit = "contain",
            backgroundColor = { 0, 0, 0, 0 },
        })
    end
end

-- 切到指定分镜：后景填好内容后与前景交叉淡入淡出
function M.TransitionToShot(dialogueId)
    local front, back = M.ui.shotFront, M.ui.shotBack
    if not (front and back) then return end
    local GameData = require("scripts.GameData")
    local shot = GameData.OpeningShots and GameData.OpeningShots[dialogueId]
    local dur = (shot and shot.transitionDur) or DEFAULT_SHOT_FADE

    M.FillShot(back, dialogueId)
    back:SetStyle({ opacity = 0 })
    front:SetStyle({ opacity = 1 })
    M.state.transition = { t = 0, dur = dur, from = front, to = back }
    print(string.format("[OPEN DEBUG] 镜头切换 -> %s (%.2fs)", tostring(dialogueId), dur))
end

function M.DestroyShotPanels()
    for _, k in ipairs({ "shotA", "shotB" }) do
        local p = M.ui[k]
        if p then
            if p._actorLayer then pcall(function() p._actorLayer:Destroy() end) end
            pcall(function() p:Destroy() end)
            M.ui[k] = nil
        end
    end
    M.ui.shotFront, M.ui.shotBack = nil, nil
    M.state.transition = nil
end

-- 读取当前过场分镜（按 dialogueIndex）对应的背景图
function M.GetCurrentDialogueBackground()
    local GameData = require("scripts.GameData")
    local dialogues = (M.state.opening and M.state.opening.dialogues) or {}
    local id = dialogues[M.state.dialogueIndex]
    if not id then return nil end
    local dlg = GameData.GetDialogue(id)
    if dlg and dlg.background and dlg.background ~= "" then
        return dlg.background
    end
    return nil
end

-- 读取指定序号过场分镜的背景图（用于 location 阶段显示首图）
function M.GetOpeningDialogueBackground(index)
    local GameData = require("scripts.GameData")
    local dialogues = (M.state.opening and M.state.opening.dialogues) or {}
    local id = dialogues[index]
    if not id then return nil end
    local dlg = GameData.GetDialogue(id)
    if dlg and dlg.background and dlg.background ~= "" then
        return dlg.background
    end
    return nil
end

-- 对话阶段：建立双缓冲镜头并显示第一镜
function M.BuildBackdrop()
    M.DestroyShotPanels()
    M.ui.shotA = M.CreateShotPanel()
    M.ui.shotB = M.CreateShotPanel()
    local uiRoot = UI.GetRoot()
    if uiRoot then
        uiRoot:AddChild(M.ui.shotA)
        uiRoot:AddChild(M.ui.shotB)
    end
    M.ui.shotFront = M.ui.shotA
    M.ui.shotBack = M.ui.shotB

    local firstId = (M.state.opening and M.state.opening.dialogues or {})[1]
    M.FillShot(M.ui.shotFront, firstId)
    M.ui.shotFront:SetStyle({ opacity = 1 })
    M.ui.shotBack:SetStyle({ opacity = 0 })
    M._skipBtn = _AddSkipButton()
end

-- ============================================================================
-- 更新
-- ============================================================================
function M.Update(deltaTime)
    if not M.state.active then return end

    -- 镜头切换过渡：前后景交叉淡入淡出
    local tr = M.state.transition
    if tr then
        tr.t = tr.t + deltaTime
        local k = (tr.dur > 0) and (tr.t / tr.dur) or 1
        if k > 1 then k = 1 end
        pcall(function() tr.to:SetStyle({ opacity = k }) end)
        pcall(function() tr.from:SetStyle({ opacity = 1 - k }) end)
        if k >= 1 then
            -- 刚淡入的成为新的前景，原前景转为待用的后景
            M.ui.shotFront, M.ui.shotBack = tr.to, tr.from
            M.state.transition = nil
        end
    end

    local GameData = require("scripts.GameData")
    local DialogueSystem = require("scripts.DialogueSystem")

    if M.state.phase == "location" then
        M.state.timer = M.state.timer + deltaTime
        local duration = M.state.opening.duration or 3.0
        local fadeStart = duration - 0.5

        -- 淡出效果
        if M.state.timer >= fadeStart and fadeStart > 0 then
            local alpha = 255 * (1 - (M.state.timer - fadeStart) / 0.5)
            if alpha < 0 then alpha = 0 end
            if alpha > 255 then alpha = 255 end
            if M.ui.timeLabel then
                M.ui.timeLabel:SetStyle({ fontColor = { 230, 225, 215, math.floor(alpha) } })
            end
            if M.ui.locationLabel then
                M.ui.locationLabel:SetStyle({ fontColor = { 180, 175, 165, math.floor(alpha) } })
            end
        end

        if M.state.timer >= duration then
            -- 进入对话阶段：显示暗色背景避免透出旧场景
            M.DestroyUI()
            M.BuildBackdrop()
            M.state.phase = "dialogue"
            M.PlayNextDialogue()
        end
        return
    end

    if M.state.phase == "dialogue" then
        -- 对话由 DialogueSystem 驱动，这里等待回调
        return
    end
end

-- ============================================================================
-- 播放下一个对话
-- ============================================================================
function M.PlayNextDialogue()
    local DialogueSystem = require("scripts.DialogueSystem")
    local GameData = require("scripts.GameData")

    local dialogues = M.state.opening.dialogues or {}
    if M.state.dialogueIndex > #dialogues then
        -- 全部播完
        M.Finish()
        return
    end

    local dialogueId = dialogues[M.state.dialogueIndex]
    M.state.dialogueIndex = M.state.dialogueIndex + 1

    -- 镜头切到该分镜：背景 + 角色站位，交叉淡入淡出
    M.TransitionToShot(dialogueId)

    DialogueSystem.Start(dialogueId, function()
        M.PlayNextDialogue()
    end, false)
end

-- ============================================================================
-- 完成
-- ============================================================================
function M.Finish()
    local onComplete = M.state.onComplete
    M.Stop()
    if onComplete then
        onComplete()
    end
end

return M
