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
}

M.ui = {
    root = nil,
    timeLabel = nil,
    locationLabel = nil,
}

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

-- ============================================================================
-- 显示时间地点黑屏UI
-- ============================================================================
function M.BuildLocationUI()
    M.DestroyUI()

    local opening = M.state.opening or { time = "", location = "" }

    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 255 },
        flexDirection = "column",
        alignItems = "center",
        justifyContent = "center",
        gap = 18,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }

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
end

function M.DestroyUI()
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    M.ui.timeLabel = nil
    M.ui.locationLabel = nil
end

-- ============================================================================
-- 更新
-- ============================================================================
function M.Update(deltaTime)
    if not M.state.active then return end

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
            -- 进入对话阶段
            M.DestroyUI()
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

    local dialogues = M.state.opening.dialogues or {}
    if M.state.dialogueIndex > #dialogues then
        -- 全部播完
        M.Finish()
        return
    end

    local dialogueId = dialogues[M.state.dialogueIndex]
    M.state.dialogueIndex = M.state.dialogueIndex + 1

    DialogueSystem.Start(dialogueId, function()
        M.PlayNextDialogue()
    end)
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
