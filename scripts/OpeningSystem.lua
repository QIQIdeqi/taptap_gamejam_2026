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
    backdrop = nil,   -- 对话阶段的暗色背景
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
    if M.ui.backdrop then
        M.ui.backdrop:Destroy()
        M.ui.backdrop = nil
    end
    M.ui.timeLabel = nil
    M.ui.locationLabel = nil
end

-- 创建带背景图与暗化遮罩的全屏面板（保证文字可读）
function M.CreateBackdropPanel(imagePath)
    local panel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 6, 5, 12, 255 },
        backgroundImage = imagePath,
        backgroundFit = "cover",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 150 },
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
    }
    panel:AddChild(overlay)
    return panel
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

-- 对话阶段背景：显示当前分镜的背景图（覆盖全屏，避免透出旧场景）
function M.BuildBackdrop()
    M.ui.backdrop = M.CreateBackdropPanel(M.GetCurrentDialogueBackground())
    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.backdrop) end
    M._skipBtn = _AddSkipButton()
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

    -- 切换到该分镜对应的背景图（pcall 防止背景图缺失导致崩溃）
    local dlg = GameData.GetDialogue(dialogueId)
    if M.ui.backdrop and dlg and dlg.background and dlg.background ~= "" then
        pcall(function() M.ui.backdrop:SetBackgroundImage(dlg.background) end)
    end

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
