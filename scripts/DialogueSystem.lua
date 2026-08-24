-- ============================================================================
-- DialogueSystem.lua - 对话系统
-- 打字机效果、角色名显示、点击继续
-- 使用 UrhoX 声明式 UI
-- ============================================================================

local UI = require("urhox-libs.UI")

local M = {}

M.state = {
    dialogue = nil,
    lineIndex = 1,
    isActive = false,
    displayText = "",
    fullText = "",
    charIndex = 0,
    timer = 0,
    charsPerSecond = 30,
    isLineComplete = false,
}

M.onComplete = nil
M.ui = { root = nil, textLabel = nil, nameLabel = nil, continueHint = nil }

-- ============================================================================
-- 开始对话
-- ============================================================================

function M.Start(dialogueId, onComplete)
    local GameData = require("scripts.GameData")
    local dialogue
    if type(dialogueId) == "table" then
        dialogue = dialogueId
    else
        dialogue = GameData.GetDialogue(dialogueId)
    end
    if not dialogue then
        if onComplete then onComplete() end
        return
    end

    -- 如果已有UI，先清理
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end

    M.state.dialogue = dialogue
    M.state.lineIndex = 1
    M.state.isActive = true
    M.state.charIndex = 0
    M.state.displayText = ""
    M.state.timer = 0
    M.state.isLineComplete = false
    M.onComplete = onComplete

    M.BuildUI()
    M.StartLine(1)
end

-- ============================================================================
-- 构建UI
-- ============================================================================

function M.BuildUI()
    M.ui.root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 0 },
        flexDirection = "column",
        justifyContent = "flex-end",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        pointerEvents = true,
    }

    -- 底部对话面板
    local panel = UI.Panel {
        width = "100%",
        height = 180,
        backgroundColor = { 15, 12, 25, 220 },
        borderTopWidth = 2,
        borderTopColor = { 180, 160, 120, 200 },
        flexDirection = "column",
        padding = { 30, 40, 30, 40 },
        gap = 10,
    }
    M.ui.root:AddChild(panel)

    -- 点击区域（整个面板可点击推进对话）
    panel.onClick = function()
        M.OnClick()
    end

    M.ui.nameLabel = UI.Label {
        text = "",
        fontSize = 22,
        fontColor = { 220, 200, 160, 255 },
        fontWeight = "bold",
    }
    panel:AddChild(M.ui.nameLabel)

    M.ui.textLabel = UI.Label {
        text = "",
        fontSize = 18,
        fontColor = { 240, 240, 240, 255 },
        whiteSpace = "normal",
        flexGrow = 1,
    }
    panel:AddChild(M.ui.textLabel)

    M.ui.continueHint = UI.Label {
        text = "▼ 点击继续",
        fontSize = 14,
        fontColor = { 180, 180, 180, 200 },
        textAlign = "right",
    }
    panel:AddChild(M.ui.continueHint)

    local uiRoot = UI.GetRoot()
    if uiRoot then uiRoot:AddChild(M.ui.root) end
end

-- ============================================================================
-- 开始显示某一行
-- ============================================================================

function M.StartLine(index)
    local lines = M.state.dialogue.lines
    if index > #lines then
        M.End()
        return
    end

    local line = lines[index]
    M.state.lineIndex = index
    M.state.fullText = line.text or ""
    M.state.displayText = ""
    M.state.charIndex = 0
    M.state.timer = 0
    M.state.isLineComplete = false

    local GameData = require("scripts.GameData")
    if line.speaker and line.speaker ~= "" then
        local char = GameData.GetCharacter(line.speaker)
        if char then
            M.ui.nameLabel:SetText(char.name)
            M.ui.nameLabel:SetStyle({ fontColor = { char.color[1], char.color[2], char.color[3], 255 } })
        else
            M.ui.nameLabel:SetText(line.speaker)
        end
    else
        M.ui.nameLabel:SetText("")
    end

    M.ui.continueHint:SetVisible(false)
    M.ui.textLabel:SetText("")
end

-- ============================================================================
-- 更新（打字机效果）
-- ============================================================================

function M.Update(deltaTime)
    if not M.state.isActive then return end

    if not M.state.isLineComplete then
        M.state.timer = M.state.timer + deltaTime
        local charInterval = 1.0 / M.state.charsPerSecond
        while M.state.timer >= charInterval and M.state.charIndex < #M.state.fullText do
            M.state.timer = M.state.timer - charInterval
            M.state.charIndex = M.state.charIndex + 1
            M.state.displayText = M.state.displayText .. string.sub(M.state.fullText, M.state.charIndex, M.state.charIndex)
        end

        if M.state.charIndex >= #M.state.fullText then
            M.state.isLineComplete = true
            M.ui.continueHint:SetVisible(true)
        end

        M.ui.textLabel:SetText(M.state.displayText)
    end
end

-- ============================================================================
-- 点击处理
-- ============================================================================

function M.OnClick()
    if not M.state.isActive then return false end

    if not M.state.isLineComplete then
        -- 快进当前行
        M.state.displayText = M.state.fullText
        M.state.charIndex = #M.state.fullText
        M.state.isLineComplete = true
        M.ui.textLabel:SetText(M.state.displayText)
        M.ui.continueHint:SetVisible(true)
    else
        -- 下一行
        M.StartLine(M.state.lineIndex + 1)
    end

    return true
end

-- ============================================================================
-- 结束对话
-- ============================================================================

function M.End()
    M.state.isActive = false
    M.state.dialogue = nil
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    if M.onComplete then
        local cb = M.onComplete
        M.onComplete = nil
        cb()
    end
end

function M.IsActive()
    return M.state.isActive
end

return M
