-- ============================================================================
-- DialogueSystem.lua - 对话系统
-- 打字机效果、角色名显示、点击继续
-- 使用 UrhoX 声明式 UI
-- ============================================================================

local UI = require("urhox-libs.UI")
local VoiceSystem = require("scripts.VoiceSystem")

local M = {}

M.state = {
    dialogue = nil,
    lineIndex = 1,
    isActive = false,
    displayText = "",
    fullText = "",
    charIndex = 0,
    timer = 0,
    charsPerSecond = 50,
    isLineComplete = false,
}

M.onComplete = nil
M.ui = { root = nil, textLabel = nil, nameLabel = nil, continueHint = nil, portrait = nil }

-- 角色立绘映射（对话 speaker key -> 图片资源路径）
M.portraitMap = {
    LiZhi = "assets/image/char_lizhi.png",
    ChenWenyin = "assets/image/char_wenyin.png",
    XuQinglan = "assets/image/char_xuqinglan.png",
    YanChengfeng = "assets/image/char_yanchengfeng.png",
    ZhaoHeng = "assets/image/char_zhaoheng.png",
    ZhouWen = "assets/image/char_zhouwen.png",
    ZhangChengyu = "assets/image/char_zhangchengyu.png",
    -- 次要角色立绘（2026-08-27 生成接入）
    LiZhiSister = "assets/image/char_sister.png",          -- 李志的姐姐
    FrontDesk = "assets/image/char_receptionist.png",       -- 酒店前台
    PanganEmployee = "assets/image/char_pangan_employee_a.png", -- 磐安员工甲
    PanganEmployeeA = "assets/image/char_pangan_employee_a.png",
    PanganEmployeeB = "assets/image/char_pangan_employee_b.png",
    NewsAnchor = "assets/image/ui_news_anchor.png",             -- 平板 AI 新闻播报
    -- 第四阶段新增（2026-08-29 生成接入）
    PoliceA = "assets/image/char_police.png",                   -- 执勤警察
    Forensic = "assets/image/char_doctor.png",                  -- 法医宋医生
    WaiterA = "assets/image/char_waiter.png",                   -- 服务员A
    WaiterB = "assets/image/char_waiter_b.png",                 -- 服务员B
    Guard = "assets/image/char_guard.png",                       -- 庭院入口保安
}

-- ============================================================================
-- 开始对话
-- ============================================================================

function M.Start(dialogueId, onComplete, showSkip, startLine)
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
    -- 记录对话 id 供 VoiceSystem 定位台词音频（table 形式传入时无 id，配音自动跳过）
    M.state.dialogueId = (type(dialogueId) == "string") and dialogueId or nil
    M.state.lineIndex = startLine or 1
    M.state.isActive = true
    M.state.portraitPosition = 1
    M.state.charIndex = 0
    M.state.displayText = ""
    M.state.timer = 0
    M.state.isLineComplete = false
    M.onComplete = onComplete

    M.BuildUI(showSkip ~= false)
    print(string.format("[DLG DEBUG] Start: id=%s lines=%d uiRoot=%s",
        tostring(type(dialogueId) == "string" and dialogueId or "<table>"),
        dialogue.lines and #dialogue.lines or -1, tostring(M.ui.root ~= nil)))
    M.StartLine(M.state.lineIndex)
end

-- ============================================================================
-- 构建UI
-- ============================================================================

function M.BuildUI(showSkip)
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
        height = 240,
        zIndex = 100,
        backgroundColor = { 15, 12, 25, 220 },
        borderTopWidth = 2,
        borderTopColor = { 180, 160, 120, 200 },
        flexDirection = "column",
        padding = { 24, 40, 20, 40 },
        gap = 8,
    }
    M.ui.root:AddChild(panel)

    -- 点击区域（整个面板可点击推进对话）
    panel.props.onClick = function(self, event)
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

    -- 对话立绘：放大 1.5 倍并下移半个增量；对话面板 zIndex 更高，始终盖在立绘上方。
    M.ui.portrait = UI.Panel {
        id = "dialoguePortrait",
        width = 480,
        height = 810,
        position = "absolute",
        left = 24,
        bottom = -135,
        zIndex = 10,
        backgroundColor = { 0, 0, 0, 0 },
        backgroundFit = "contain",
        backgroundImageOpacity = 1,
        visible = false,
        pointerEvents = false,
    }
    M.ui.root:AddChild(M.ui.portrait)

    -- 跳过按钮：点击直接结束整段对话并进入下一节点（showSkip=false 时不创建，避免与 OpeningSystem 跳过重复）
    if showSkip then
        local skipBtn = UI.Button {
            position = "absolute",
            top = 16, left = 16,
            width = 64, height = 34,
            backgroundColor = { 0, 0, 0, 130 },
            borderWidth = 1, borderColor = { 255, 255, 255, 100 },
            borderRadius = 6,
            text = "跳过 ›",
            fontColor = { 255, 255, 255, 230 },
            fontSize = 16,
            onClick = function(self, event)
                M.End()
            end,
        }
        M.ui.root:AddChild(skipBtn)
    end

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
    M.state.lineClueFired = false
    M.state.fullText = line.text or ""
    M.state.displayText = ""
    M.state.charIndex = 0
    M.state.timer = 0
    M.state.isLineComplete = false

    -- Wolai 修改 3：CSV 的 portrait_position=1 放左侧，=2 放右侧。
    local portraitPosition = tonumber(line.portraitPosition or line.position) == 2 and 2 or 1
    M.state.portraitPosition = portraitPosition
    if M.ui.portrait then
        local sw = graphics and graphics:GetWidth() or 1280
        local portraitW = 480
        local portraitLeft = portraitPosition == 2 and (sw - portraitW - 24) or 24
        M.ui.portrait:SetStyle({ left = portraitLeft, bottom = -135 })
    end

    -- 说话人处理包 pcall：此处报错会被 UI 事件系统静默吞掉，
    -- 表现为"对话框弹出来了但点不动、一片空白"，极难定位。
    local ok, err = pcall(function()
        local GameData = require("scripts.GameData")
        if line.speaker and line.speaker ~= "" then
            local char = GameData.GetCharacter(line.speaker)
            if char then
                M.ui.nameLabel:SetText(char.name)
                if char.color then
                    M.ui.nameLabel:SetStyle({
                        fontColor = { char.color[1], char.color[2], char.color[3], 255 }
                    })
                end
            else
                M.ui.nameLabel:SetText(line.speaker)
            end
            local portraitPath = M.portraitMap[line.speaker]
            if portraitPath and M.ui.portrait then
                M.ui.portrait:SetBackgroundImage(portraitPath)
                M.ui.portrait:SetVisible(true)
            elseif M.ui.portrait then
                M.ui.portrait:SetVisible(false)
            end
        else
            M.ui.nameLabel:SetText("")
            if M.ui.portrait then M.ui.portrait:SetVisible(false) end
        end
    end)
    if not ok then
        print(string.format("[DLG ERROR] StartLine(%d) speaker=%s 处理失败: %s",
            index, tostring(line.speaker), tostring(err)))
    end

    -- 行内镜头切换：本行配置了与所在分镜默认不同的背景时，交叉淡入换镜。
    -- 只有 OpeningSystem 过场正在进行时才真正执行，其余场景（探索/询问）自动忽略。
    local okShot, errShot = pcall(function()
        if line.background and line.background ~= "" then
            local OpeningSystem = require("scripts.OpeningSystem")
            if OpeningSystem and OpeningSystem.TransitionToLineShot then
                OpeningSystem.TransitionToLineShot(line.background)
            end
        end
    end)
    if not okShot then
        print("[DLG WARN] 行内切镜头异常: " .. tostring(errShot))
    end

    -- 播放本句角色配音（该句未配置音频则静默跳过，不影响对话进行）
    local okVoice, errVoice = pcall(function()
        VoiceSystem.Play(M.state.dialogueId, index)
    end)
    if not okVoice then
        print("[DLG WARN] 配音播放异常: " .. tostring(errVoice))
    end

    M.ui.continueHint:SetVisible(false)
    M.ui.textLabel:SetText("")
    print(string.format("[DLG DEBUG] StartLine: idx=%d speaker=%s len=%d",
        index, tostring(line.speaker), #M.state.fullText))
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

        -- 证言提取：关键句打字机播毕即触发线索收录（wolai 5.2.5）
        if M.state.isLineComplete and not M.state.lineClueFired then
            M.state.lineClueFired = true
            local line = M.state.dialogue.lines[M.state.lineIndex]
            if line and line.clue then
                local SceneManager = require("scripts.SceneManager")
                local GameData = require("scripts.GameData")
                local isNew = GameData.CollectClue(line.clue)
                GameData.SetFlag("clue_" .. line.clue, true)
                local clueDef = GameData.Clues[line.clue]
                local name = (clueDef and clueDef.name) or line.clue
                if SceneManager.onClueCollected then
                    SceneManager.onClueCollected(line.clue, name, not isNew)
                end
            end
        end
    end
end

-- ============================================================================
-- 点击处理
-- ============================================================================

function M.OnClick()
    print(string.format("[DLG DEBUG] OnClick: active=%s line=%d complete=%s",
        tostring(M.state.isActive), M.state.lineIndex or -1, tostring(M.state.isLineComplete)))
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
    VoiceSystem.Stop()
    M.state.isActive = false
    M.state.dialogue = nil
    M._CleanUI()
    if M.onComplete then
        local cb = M.onComplete
        M.onComplete = nil
        cb()
    end
end

-- Stop: 外部调用的安全停止接口（OpeningSystem.Finish 等使用）
function M.Stop()
    VoiceSystem.Stop()
    M.state.isActive = false
    M.state.dialogue = nil
    M._CleanUI()
    M.onComplete = nil
end

-- 内部：彻底销毁 UI 并清空所有引用
function M._CleanUI()
    if M.ui.root then
        M.ui.root:Destroy()
        M.ui.root = nil
    end
    -- 清空所有子控件引用，防止悬挂指针
    M.ui.textLabel = nil
    M.ui.nameLabel = nil
    M.ui.continueHint = nil
    M.ui.portrait = nil
    M.ui.skipBtn = nil
end

function M.IsActive()
    return M.state.isActive
end

return M
